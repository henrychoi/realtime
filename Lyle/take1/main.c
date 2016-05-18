/* Copyright (c) 2014 Nordic Semiconductor. All Rights Reserved.
 *
 * The information contained herein is property of Nordic Semiconductor ASA.
 * Terms and conditions of usage are described in detail in NORDIC
 * SEMICONDUCTOR STANDARD SOFTWARE LICENSE AGREEMENT.
 *
 * Licensees are granted free, non-transferable use of the information. NO
 * WARRANTY of ANY KIND is provided. This heading must NOT be removed from
 * the file.
 *
 */

/** @file
 *
 * @defgroup ble_sdk_uart_over_ble_main main.c
 * @{
 * @ingroup  ble_sdk_app_nus_eval
 * @brief    UART over BLE application main file.
 *
 * This file contains the source code for a sample application that uses the Nordic UART service.
 * This application uses the @ref srvlib_conn_params module.
 */

#include "qpc.h"
#include <stdint.h>
#include <string.h>
#include "nordic_common.h"
#include "nrf.h"
#include "nrf51_bitfields.h"
#include "ble_hci.h"
#include "ble_advdata.h"
#include "ble_advertising.h"
#include "ble_conn_params.h"
#include "softdevice_handler.h"
#include "app_timer.h"
#include "app_button.h"
#include "ble_nus.h"
#include "app_uart.h"
#include "app_util_platform.h"
#include "bsp.h"
#include "bsp_btn_ble.h"
#include "nrf_drv_uart.h"

#if TIMER1_ENABLED
#include "nrf_drv_timer.h"
#else
#endif

#include "dpp.h"
#include "trace.h"
#include "msg.h"

Q_DEFINE_THIS_FILE

/*!!!!!!!!!!!!!!!!!!!!!!!!!!!!!! CAUTION !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
* Assign a priority to EVERY ISR explicitly by calling NVIC_SetPriority().
* DO NOT LEAVE THE ISR PRIORITIES AT THE DEFAULT VALUE!
*/
enum KernelAwareISRs {
	// On nRF51, only priorities 1 and 3 are available to application because
	// SoftDevice takes up 0 and 2.
    SYSTICK_PRIO = QF_AWARE_ISR_CMSIS_PRI, /* see NOTE00 */
    /* ... */
    MAX_KERNEL_AWARE_CMSIS_PRI /* keep always last */
};
/* "kernel-aware" interrupts should not overlap the PendSV priority */
Q_ASSERT_COMPILE(MAX_KERNEL_AWARE_CMSIS_PRI <= (0xFF >>(8-__NVIC_PRIO_BITS)));

#ifdef Q_SPY
QSTimeCtr QS_tickTime_;

/* event-source identifiers used for tracing */
static uint8_t const l_softdevice = 0U;

#endif

QSTimeCtr QS_i_getTime;

#if TIMER1_ENABLED
const nrf_drv_timer_t TIMER1 = NRF_DRV_TIMER_INSTANCE(1);
void Timer1_handler(nrf_timer_event_t event_type, void* p_context) {
    if (event_type != NRF_TIMER_EVENT_COMPARE0) return;

#ifdef Q_SPY
    QS_tickTime_ += 1000/BSP_TICKS_PER_SEC;
    QS_i_getTime = 0;//reset
#endif
    QF_TICK_X(0U, NULL); /* process time events for rate 0 */
}
#else
#endif

static ble_nus_t m_nus; /**< Handle for Nordic UART Service. */
/**< Handle of the current BLE connection. */
static uint16_t  m_conn_handle = BLE_CONN_HANDLE_INVALID;

void BSP_init(void) {
	uint32_t err_code;
#if TIMER1_ENABLED
    err_code = nrf_drv_timer_init(&TIMER1, NULL, Timer1_handler);
    APP_ERROR_CHECK(err_code);
    nrf_drv_timer_extended_compare(&TIMER1, NRF_TIMER_CC_CHANNEL0
    		, nrf_drv_timer_ms_to_ticks(&TIMER1, 1000/BSP_TICKS_PER_SEC)
			, NRF_TIMER_SHORT_COMPARE0_CLEAR_MASK, true);
#else
#endif

    /* initialize the QS software tracing... */
    if (QS_INIT((void *)0) == 0) {
        Q_ERROR();
    }
    if (!MSG_onStartup()) {// NUS message handler
        Q_ERROR();
    }
    QS_OBJ_DICTIONARY(&l_softdevice);
}

/*..........................................................................*/
void BSP_displayPaused(uint8_t paused) {
    /* not enough LEDs to implement this feature */
    if (paused != (uint8_t)0) {
        //GPIOA->BSRR |= (LED_LD2);  /* turn LED[n] on  */
    }
    else {
        //GPIOA->BSRR |= (LED_LD2 << 16);  /* turn LED[n] off */
    }
}

/* QF callbacks ============================================================*/
void QF_onStartup(void) {
    /* set up the SysTick timer to fire at BSP_TICKS_PER_SEC rate */
    //SysTick_Config(SystemCoreClock / BSP_TICKS_PER_SEC);

    /* set priorities of ALL ISRs used in the system, see NOTE00
    *
    * !!!!!!!!!!!!!!!!!!!!!!!!!!!! CAUTION !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
    * Assign a priority to EVERY ISR explicitly by calling NVIC_SetPriority().
    * DO NOT LEAVE THE ISR PRIORITIES AT THE DEFAULT VALUE!
    */
    //NVIC_SetPriority(SysTick_IRQn,   SYSTICK_PRIO);
    /* ... */

    /* enable IRQs... */
#if TIMER1_ENABLED
    nrf_drv_timer_enable(&TIMER1);
#else
#endif
}
void QF_onCleanup(void) {
}
/*..........................................................................*/
void QV_onIdle(void) {  /* called with interrupts disabled, see NOTE01 */

    /* toggle an LED on and then off (not enough LEDs, see NOTE02) */
    //GPIOA->BSRR |= (LED_LD2);        /* turn LED[n] on  */
    //GPIOA->BSRR |= (LED_LD2 << 16);  /* turn LED[n] off */

#ifdef Q_SPY
    QF_INT_ENABLE();
    QS_rxParse();  /* parse all the received bytes */

    // Push out QS buffer to UART
    if (!nrf_drv_uart_tx_in_progress()) {  /* is TXE empty? */
        static uint16_t b;

        QF_INT_DISABLE();
        b = QS_getByte();
        QF_INT_ENABLE();

        if (b != QS_EOD) {  /* not End-Of-Data? */
            //static uint8_t byte;
        	//byte = b & 0xFF;
        	nrf_drv_uart_tx((const uint8_t*)&b, 1);
        }
    }

    //Give pending message to NUS service
    if (m_nus.conn_handle != BLE_CONN_HANDLE_INVALID
    		&& m_nus.is_notification_enabled) {
		uint16_t n = BLE_NUS_MAX_DATA_LEN;
		uint8_t* msg_buf = (uint8_t*)MSG_getBlock(&n);
		if (msg_buf) {
	    	QS_BEGIN(TRACE_MSG_OUT, (void *)0)
	    		QS_MEM(msg_buf, n);
	    	QS_END()

			uint32_t err_code = ble_nus_string_send(&m_nus, msg_buf, n);
			Q_ASSERT(err_code == NRF_SUCCESS);
		}
    }
#elif defined NDEBUG
    /* Put the CPU and peripherals to the low-power mode.
    * you might need to customize the clock management for your application,
    * see the datasheet for your particular Cortex-M MCU.
    */
    /* !!!CAUTION!!!
    * The QF_CPU_SLEEP() contains the WFI instruction, which stops the CPU
    * clock, which unfortunately disables the JTAG port, so the ST-Link
    * debugger can no longer connect to the board. For that reason, the call
    * to QF_CPU_SLEEP() has to be used with CAUTION.
    */
    /* NOTE: If you find your board "frozen" like this, strap BOOT0 to VDD and
    * reset the board, then connect with ST-Link Utilities and erase the part.
    * The trick with BOOT(0) is it gets the part to run the System Loader
    * instead of your broken code. When done disconnect BOOT0, and start over.
    */
    //QV_CPU_SLEEP();  /* atomically go to sleep and enable interrupts */
    //power_manage();
    QF_INT_ENABLE(); /* for now, just enable interrupts */
#else
    QF_INT_ENABLE(); /* just enable interrupts */
#endif
}

void Q_onAssert(char const *module, int loc) {
    /*
    * NOTE: add here your application-specific error handling
    */
    (void)module;
    (void)loc;
    QS_ASSERTION(module, loc, (uint32_t)10000U); /* report assertion to QS */
    NVIC_SystemReset();
}

#ifdef Q_SPY

void uart_event_handler(nrf_drv_uart_event_t * p_event, void* p_context)
{
	switch(p_event->type) {
	case NRF_DRV_UART_EVT_RX_DONE:
		for (uint8_t i=0; i < p_event->data.rxtx.bytes; ++i) {
			//p_event->data.rxtx.p_data[0];
			//(void)nrf_drv_uart_rx(&byte,1);
			QS_RX_PUT(p_event->data.rxtx.p_data[i]);
		}
    	break;
	case NRF_DRV_UART_EVT_ERROR:
		//p_event->data.error.error_mask;
        //(void)nrf_drv_uart_rx(&byte,1);
        break;
	case NRF_DRV_UART_EVT_TX_DONE:
       break;
    }
}

uint8_t QS_onStartup(void const *arg) {
    static uint8_t qsBuf[512]; /* buffer for Quantum Spy */

    (void)arg; /* avoid the "unused parameter" compiler warning */
    QS_initBuf(qsBuf, sizeof(qsBuf));

    //QS_tickTime_ = Timer1_period; /* to start the timestamp at zero */

    nrf_drv_uart_config_t config = NRF_DRV_UART_DEFAULT_CONFIG;
    config.baudrate = NRF_UART_BAUDRATE_1000000;
    uint32_t err_code = nrf_drv_uart_init(&config, uart_event_handler);
    APP_ERROR_CHECK(err_code);

    /* setup the QS filters... */
    QS_FILTER_ON(TRACE_MSG_ERROR);
    QS_FILTER_ON(TRACE_ADV_EVT);
    QS_FILTER_ON(TRACE_BLE_EVT);
    QS_FILTER_ON(TRACE_CONN_EVT);
    QS_FILTER_ON(TRACE_NUS_DATA);

    return (uint8_t)1; /* return success */
}
void QS_onCleanup(void) {
}
/*..........................................................................*/
QSTimeCtr QS_onGetTime(void) { /* NOTE: invoked with interrupts DISABLED */
#if TIMER1_ENABLED
    return QS_tickTime_ + ++QS_i_getTime;
#else
#endif
}
/*..........................................................................*/
void QS_onFlush(void) {
    static uint16_t b;

    QF_INT_DISABLE();
    while ((b = QS_getByte()) != QS_EOD) {    /* while not End-Of-Data... */
        QF_INT_ENABLE();
        while (nrf_drv_uart_tx_in_progress()) { /* while TXE not empty */
        }
        //static uint8_t byte;
        //byte = b & 0xFF;
    	nrf_drv_uart_tx((const uint8_t*)&b, 1);
    }
    QF_INT_ENABLE();
}
void QS_onReset(void) {
    NVIC_SystemReset();
}
/*..........................................................................*/
/*! callback function to execute a user command (to be implemented in BSP) */
void QS_onCommand(uint8_t cmdId, uint32_t param) {
    void assert_failed(char const *module, int loc);
    (void)cmdId;
    (void)param;
    QS_BEGIN(TRACE_QS_CMD, (void *)0) /* application-specific record begin */
        QS_U8(2, cmdId);
        QS_U32(8, param);
    QS_END()
}
#endif /* Q_SPY */

// RTC1 PRESCALER register = 0 means we are NOT dividing the 32 kHz LFCLK.
#define APP_TIMER_PRESCALER 0

/**< Universally unique service identifier. */
static ble_uuid_t m_adv_uuids[] = {{
		BLE_UUID_NUS_SERVICE
		, BLE_UUID_TYPE_VENDOR_BEGIN/**< UUID type for the Nordic UART Service (vendor specific). */
}};

/**@brief Function for assert macro callback.
 *
 * @details This function will be called in case of an assert in the SoftDevice.
 *
 * @warning This handler is an example only and does not fit a final product. You need to analyse 
 *          how your product is supposed to react in case of Assert.
 * @warning On assert from the SoftDevice, the system can only recover on reset.
 *
 * @param[in] line_num    Line number of the failing ASSERT call.
 * @param[in] p_file_name File name of the failing ASSERT call.
 */
void assert_nrf_callback(uint16_t line_num, const uint8_t * p_file_name)
{
	/**< Value used as error code on stack dump, can be used to identify stack
	 *  location on stack unwind. */
    //app_error_handler(0xDEADBEEF, line_num, p_file_name);
	Q_ERROR();
}


/**@brief Function for the GAP initialization.
 *
 * @details This function will set up all the necessary GAP (Generic Access Profile) parameters of 
 *          the device. It also sets the permissions and appearance.
 */
static void gap_params_init(void)
{
    uint32_t                err_code;
    ble_gap_conn_params_t   gap_conn_params;
    ble_gap_conn_sec_mode_t sec_mode;

    BLE_GAP_CONN_SEC_MODE_SET_OPEN(&sec_mode);
    
#define DEVICE_NAME "Lyle" /**< Name of device. Will be included in the advertising data. */
    err_code = sd_ble_gap_device_name_set(&sec_mode,
                                          (const uint8_t *) DEVICE_NAME,
                                          strlen(DEVICE_NAME));
    APP_ERROR_CHECK(err_code);

    memset(&gap_conn_params, 0, sizeof(gap_conn_params));

    gap_conn_params.min_conn_interval = MSEC_TO_UNITS(20, UNIT_1_25_MS);
    gap_conn_params.max_conn_interval = MSEC_TO_UNITS(75, UNIT_1_25_MS);
    gap_conn_params.slave_latency     = 0;
    gap_conn_params.conn_sup_timeout  = MSEC_TO_UNITS(4000, UNIT_10_MS);

    err_code = sd_ble_gap_ppcp_set(&gap_conn_params);
    APP_ERROR_CHECK(err_code);
}


/**@brief Function for handling the data from the Nordic UART Service.
 *
 * @details This function will process the data received from the Nordic UART BLE Service and send
 *          it to the UART module.
 *
 * @param[in] p_nus    Nordic UART Service structure.
 * @param[in] p_data   Data from NUS.
 * @param[in] length   Data length.
 */
static void nus_data_handler(ble_nus_t * p_nus, uint8_t * p_data, uint16_t length)
{
    QS_BEGIN(TRACE_NUS_DATA, &l_softdevice)
        QS_MEM(p_data, length);
    QS_END()
    MSG_parse(p_data, length);
    //char* greeting = "Hi there!";
    //uint32_t err_code = ble_nus_string_send(p_nus, (uint8_t*)greeting
    //		, strlen(greeting));
    //Q_ASSERT(err_code == NRF_SUCCESS);
}


static void services_init(void)
{
    uint32_t       err_code;
    ble_nus_init_t nus_init;
    
    memset(&nus_init, 0, sizeof(nus_init));
    nus_init.data_handler = nus_data_handler;
    err_code = ble_nus_init(&m_nus, &nus_init);
    APP_ERROR_CHECK(err_code);
}


/**@brief Function for handling an event from the Connection Parameters Module.
 *
 * @details This function will be called for all events in the Connection Parameters Module
 *          which are passed to the application.
 *
 * @note All this function does is to disconnect. This could have been done by simply setting
 *       the disconnect_on_fail config parameter, but instead we use the event handler
 *       mechanism to demonstrate its use.
 *
 * @param[in] p_evt  Event received from the Connection Parameters Module.
 */
static void on_conn_params_evt(ble_conn_params_evt_t * p_evt)
{
    uint32_t err_code;
    
    QS_BEGIN(TRACE_BLE_EVT, &l_softdevice)
        QS_U16(1, p_evt->evt_type);
    QS_END()

    if(p_evt->evt_type == BLE_CONN_PARAMS_EVT_FAILED)
    {
        err_code = sd_ble_gap_disconnect(m_conn_handle
        		, BLE_HCI_CONN_INTERVAL_UNACCEPTABLE);
        APP_ERROR_CHECK(err_code);
    }
}


/**@brief Function for handling errors from the Connection Parameters module.
 *
 * @param[in] nrf_error  Error code containing information about what went wrong.
 */
static void conn_params_error_handler(uint32_t nrf_error)
{
    APP_ERROR_HANDLER(nrf_error);
}


/**@brief Function for initializing the Connection Parameters module.
 */
static void conn_params_init(void)
{
    uint32_t               err_code;
    ble_conn_params_init_t cp_init;
    
    memset(&cp_init, 0, sizeof(cp_init));

    cp_init.p_conn_params                  = NULL;
    /**< Time from initiating event (connect or start of notification) to
     *  first time sd_ble_gap_conn_param_update is called (5 seconds). */
    cp_init.first_conn_params_update_delay = APP_TIMER_TICKS(5000, APP_TIMER_PRESCALER);

    /**< Time between each call to sd_ble_gap_conn_param_update after the
     *  first call (30 seconds). */
    cp_init.next_conn_params_update_delay  = APP_TIMER_TICKS(30000, APP_TIMER_PRESCALER);
    cp_init.max_conn_params_update_count   = 3;
    cp_init.start_on_notify_cccd_handle    = BLE_GATT_HANDLE_INVALID;
    cp_init.disconnect_on_fail             = false;
    cp_init.evt_handler                    = on_conn_params_evt;
    cp_init.error_handler                  = conn_params_error_handler;
    
    err_code = ble_conn_params_init(&cp_init);
    APP_ERROR_CHECK(err_code);
}


/**@brief Function for putting the chip into sleep mode.
 *
 * @note This function will not return.
 */
static void sleep_mode_enter(void)
{
    uint32_t err_code = bsp_indication_set(BSP_INDICATE_IDLE);
    APP_ERROR_CHECK(err_code);

    // Prepare wakeup buttons.
    err_code = bsp_btn_ble_sleep_mode_prepare();
    APP_ERROR_CHECK(err_code);

    // Go to system-off mode (this function will not return; wakeup will cause a reset).
    err_code = sd_power_system_off();
    APP_ERROR_CHECK(err_code);
}


/**@brief Function for handling advertising events.
 *
 * @details This function will be called for advertising events which are passed to the application.
 *
 * @param[in] ble_adv_evt  Advertising event.
 */
static void on_adv_evt(ble_adv_evt_t ble_adv_evt)
{
    uint32_t err_code;

    QS_BEGIN(TRACE_ADV_EVT, &l_softdevice)
        QS_U8(1, ble_adv_evt);
    QS_END()

    switch (ble_adv_evt)
    {
        case BLE_ADV_EVT_FAST:
        case BLE_ADV_EVT_SLOW:
            err_code = bsp_indication_set(BSP_INDICATE_ADVERTISING);
            APP_ERROR_CHECK(err_code);
            break;
        case BLE_ADV_EVT_IDLE:
            sleep_mode_enter();
            break;
        default:
            break;
    }
}


/**@brief Function for the application's SoftDevice event handler.
 *
 * @param[in] p_ble_evt SoftDevice event.
 */
static void on_ble_evt(ble_evt_t * p_ble_evt)
{
    uint32_t                         err_code;

    QS_BEGIN(TRACE_BLE_EVT, &l_softdevice)
        QS_U16(1, p_ble_evt->header.evt_id);
    QS_END()

    switch (p_ble_evt->header.evt_id)
    {
        case BLE_GAP_EVT_CONNECTED:
            err_code = bsp_indication_set(BSP_INDICATE_CONNECTED);
            APP_ERROR_CHECK(err_code);
            m_conn_handle = p_ble_evt->evt.gap_evt.conn_handle;
            break;
            
        case BLE_GAP_EVT_DISCONNECTED:
            err_code = bsp_indication_set(BSP_INDICATE_IDLE);
            APP_ERROR_CHECK(err_code);
            m_conn_handle = BLE_CONN_HANDLE_INVALID;
            break;

        case BLE_GAP_EVT_SEC_PARAMS_REQUEST:
            // Pairing not supported
            err_code = sd_ble_gap_sec_params_reply(m_conn_handle, BLE_GAP_SEC_STATUS_PAIRING_NOT_SUPP, NULL, NULL);
            APP_ERROR_CHECK(err_code);
            break;

        case BLE_GATTS_EVT_SYS_ATTR_MISSING:
            // No system attributes have been stored.
            err_code = sd_ble_gatts_sys_attr_set(m_conn_handle, NULL, 0, 0);
            APP_ERROR_CHECK(err_code);
            break;

        default:
            // No implementation needed.
            break;
    }
}


// All BLE events arrive at the ble_evt_dispatch()function
static void ble_evt_dispatch(ble_evt_t * p_ble_evt)
{
    ble_conn_params_on_ble_evt(p_ble_evt);
    ble_nus_on_ble_evt(&m_nus, p_ble_evt);
    on_ble_evt(p_ble_evt);
    ble_advertising_on_ble_evt(p_ble_evt);
    bsp_btn_ble_on_ble_evt(p_ble_evt);
}


/**@brief Function for the SoftDevice initialization.
 *
 * @details This function initializes the SoftDevice and the BLE event interrupt.
 */
static void ble_stack_init(void)
{
    uint32_t err_code;
    
    nrf_clock_lf_cfg_t clock_lf_cfg = NRF_CLOCK_LFCLKSRC;
    
    // Initialize SoftDevice.
    SOFTDEVICE_HANDLER_INIT(&clock_lf_cfg, NULL);

    ble_enable_params_t ble_enable_params;
    err_code = softdevice_enable_get_default_config(0, // Ncentral
                                                    1, // Nperipheral
                                                    &ble_enable_params);
    APP_ERROR_CHECK(err_code);
        
    //Check the ram settings against the used number of links
    CHECK_RAM_START_ADDR(0, 1); //check Ncentral/Nperipheral above
    // Enable BLE stack.
    err_code = softdevice_enable(&ble_enable_params);
    APP_ERROR_CHECK(err_code);
    
    // Subscribe for BLE events.
    err_code = softdevice_ble_evt_handler_set(ble_evt_dispatch);
    APP_ERROR_CHECK(err_code);
}


/**@brief Function for handling events from the BSP module.
 *
 * @param[in]   event   Event generated by button press.
 */
void bsp_event_handler(bsp_event_t event)
{
    uint32_t err_code;
    switch (event)
    {
        case BSP_EVENT_SLEEP:
            sleep_mode_enter();
            break;

        case BSP_EVENT_DISCONNECT:
            err_code = sd_ble_gap_disconnect(m_conn_handle, BLE_HCI_REMOTE_USER_TERMINATED_CONNECTION);
            if (err_code != NRF_ERROR_INVALID_STATE)
            {
                APP_ERROR_CHECK(err_code);
            }
            break;

        case BSP_EVENT_WHITELIST_OFF:
            err_code = ble_advertising_restart_without_whitelist();
            if (err_code != NRF_ERROR_INVALID_STATE)
            {
                APP_ERROR_CHECK(err_code);
            }
            break;

        default:
            break;
    }
}

static void advertising_init(void)
{
    uint32_t      err_code;
    ble_advdata_t advdata;
    ble_advdata_t scanrsp;

    // Build advertising data struct to pass into @ref ble_advertising_init.
    memset(&advdata, 0, sizeof(advdata));
    advdata.name_type          = BLE_ADVDATA_FULL_NAME;
    advdata.include_appearance = false;
    advdata.flags              = BLE_GAP_ADV_FLAGS_LE_ONLY_LIMITED_DISC_MODE;

    memset(&scanrsp, 0, sizeof(scanrsp));
    scanrsp.uuids_complete.uuid_cnt = sizeof(m_adv_uuids) / sizeof(m_adv_uuids[0]);
    scanrsp.uuids_complete.p_uuids  = m_adv_uuids;

    ble_adv_modes_config_t options = {0};
    options.ble_adv_fast_enabled  = BLE_ADV_FAST_DISABLED;
    //options.ble_adv_fast_interval = APP_ADV_INTERVAL;
    //options.ble_adv_fast_timeout  = 180;

    options.ble_adv_slow_enabled  = BLE_ADV_SLOW_ENABLED;
    options.ble_adv_slow_interval = 1600;// The advertising interval (in units of 0.625 ms.).
    options.ble_adv_slow_timeout  = 180;//Can't be any longer than this

    err_code = ble_advertising_init(&advdata, &scanrsp, &options, on_adv_evt, NULL);
    APP_ERROR_CHECK(err_code);
}


/**@brief Function for initializing buttons and leds.
 *
 * @param[out] p_erase_bonds  Will be true if the clear bonding button was pressed to wake the application up.
 */
static void buttons_leds_init(bool * p_erase_bonds)
{
    bsp_event_t startup_event;

    uint32_t err_code = bsp_init(BSP_INIT_LED | BSP_INIT_BUTTONS,
                                 APP_TIMER_TICKS(100, APP_TIMER_PRESCALER),
                                 bsp_event_handler);
    APP_ERROR_CHECK(err_code);

    err_code = bsp_btn_ble_init(NULL, &startup_event);
    APP_ERROR_CHECK(err_code);

    *p_erase_bonds = (startup_event == BSP_EVENT_CLEAR_BONDING_DATA);
}

#if 0
static void power_manage(void)
{
    uint32_t err_code = sd_app_evt_wait();
    APP_ERROR_CHECK(err_code);
}
#endif

uint8_t MSG_onStartup() {
	static uint8_t in_char_buf[64];//IN characteristic: peripheral --> central
    MSG_initBuf(in_char_buf, sizeof(in_char_buf));

    return 1; /* return success */
}

int main(void)
{
    bool erase_bonds;

#define APP_TIMER_OP_QUEUE_SIZE 4  /**< Size of timer operation queues. */
    APP_TIMER_INIT(APP_TIMER_PRESCALER, APP_TIMER_OP_QUEUE_SIZE, false);
    buttons_leds_init(&erase_bonds);
    ble_stack_init();
    gap_params_init();
    services_init();
    advertising_init();
    conn_params_init();

    static QEvt const *tableQueueSto[4];
    static QSubscrList subscrSto[MAX_PUB_SIG];
    static QF_MPOOL_EL(NUSEvt) smlPoolSto[4]; /* small pool */

    extern void Table_ctor(void);
    Table_ctor(); /* instantiate the Table active object */

    QF_init();    /* initialize the framework and the underlying RT kernel */
    BSP_init();   /* initialize the Board Support Package */

    /* object dictionaries... */
    QS_USR_DICTIONARY(TRACE_MSG_ERROR);
    QS_USR_DICTIONARY(TRACE_ADV_EVT);
    QS_USR_DICTIONARY(TRACE_BLE_EVT);
    QS_USR_DICTIONARY(TRACE_CONN_EVT);
    QS_USR_DICTIONARY(TRACE_NUS_DATA);

    QF_psInit(subscrSto, Q_DIM(subscrSto));

    /* initialize event pools... */
    QF_poolInit(smlPoolSto, sizeof(smlPoolSto), sizeof(smlPoolSto[0]));

    QACTIVE_START(AO_Table,                  /* AO to start */
                  AO_TABLE, /* QP priority of the AO */
                  tableQueueSto,             /* event queue storage */
                  Q_DIM(tableQueueSto),      /* queue length [events] */
                  (void *)0,                 /* stack storage (not used) */
                  0U,                        /* size of the stack [bytes] */
                  (QEvt *)0);                /* initialization event */

    uint32_t err_code = ble_advertising_start(BLE_ADV_MODE_SLOW);
    APP_ERROR_CHECK(err_code);
    
    return QF_run(); /* run the QF application */
}
