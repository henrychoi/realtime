#include "app_util_platform.h"
#include "qpn.h"
#include "appsig.h"
#include "qs_trace.h"
#include "nrf_drv_timer.h"
#include "nrf_drv_uart.h"
#include "nrf_drv_gpiote.h"

Q_DEFINE_THIS_FILE

#define BSP_TICKS_PER_SEC 10

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
QSTimeCtr QS_i_getTime;
#endif

#define BTN_PIN 17
const nrf_drv_timer_t TIMER1 = NRF_DRV_TIMER_INSTANCE(1);
void Timer1_handler(nrf_timer_event_t event_type, void* p_context) {
    if (event_type != NRF_TIMER_EVENT_COMPARE0) return;

	//QS_BEGIN(TRACE_SDK_EVT, NULL)
	//	QS_U8(0, 0);
	//QS_END() QS_FLUSH();

#ifdef Q_SPY
    QS_tickTime_ += 1000/BSP_TICKS_PER_SEC;
    QS_i_getTime = 0;//reset
#endif
    QF_tickXISR(0U); /* process time events for rate 0 */
}

static void btn1_event_handler(nrf_drv_gpiote_pin_t pin
		, nrf_gpiote_polarity_t action) {
    QS_BEGIN(TRACE_SDK_EVT, NULL)
        QS_U8(0, 1);
        QS_U8(0, nrf_gpio_pin_read(BTN_PIN));
    QS_END() QS_FLUSH();
}
#define GPIO_OUT_PIN 21
void BSP_setTP()   { NRF_GPIO->OUTSET = 1 << GPIO_OUT_PIN; }
void BSP_clearTP() { NRF_GPIO->OUTCLR = 1 << GPIO_OUT_PIN; }

void BSP_init(void) {
	uint32_t err_code;
    err_code = nrf_drv_timer_init(&TIMER1, NULL, Timer1_handler);
    APP_ERROR_CHECK(err_code);
    nrf_drv_timer_extended_compare(&TIMER1, NRF_TIMER_CC_CHANNEL0
    		, nrf_drv_timer_ms_to_ticks(&TIMER1, 1000/BSP_TICKS_PER_SEC)
			, NRF_TIMER_SHORT_COMPARE0_CLEAR_MASK, true);
    //nrf_drv_timer_enable(&TIMER1);

    // Configure button 1 for low accuracy (why not high accuracy?)
    Q_ALLEGE(nrf_drv_gpiote_init() == NRF_SUCCESS);

    nrf_drv_gpiote_in_config_t config = GPIOTE_CONFIG_IN_SENSE_TOGGLE(true);
    config.pull = NRF_GPIO_PIN_PULLUP;

    Q_ALLEGE(nrf_drv_gpiote_in_init(BTN_PIN, &config, btn1_event_handler)
    		== NRF_SUCCESS);
    nrf_drv_gpiote_in_event_enable(BTN_PIN, /* int enable = */ true);

    NRF_GPIO->DIRSET = 1 << GPIO_OUT_PIN;

    /* initialize the QS software tracing... */
    if (QS_INIT((void *)0) == 0) {
        Q_ERROR();
    }
}

/* QF callbacks ============================================================*/
void QF_onStartup(void) {
    nrf_drv_timer_enable(&TIMER1);
}
void QF_onCleanup(void) {
}
/*..........................................................................*/
void QV_onIdle(void) {  /* called with interrupts disabled, see NOTE01 */
#ifdef Q_SPY
#  if 0
    QS_rxParse();  /* parse all the received bytes */

    // Push out QS buffer to UART
    if (!nrf_drv_uart_tx_in_progress()) {  /* is TXE empty? */
        static uint16_t b;

        QF_INT_DISABLE();
        b = QS_getByte();
        QF_INT_ENABLE();

        if (b != QS_EOD) {  /* not End-Of-Data? */
        	nrf_drv_uart_tx((const uint8_t*)&b, 1);
        }
    }
#  else
    QF_INT_ENABLE();
    //sd_app_evt_wait();
    __WFE(); //__SEV();  __WFE();
#  endif
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
    //QV_CPU_SLEEP(); //atomically go to SHALLOW sleep and enable interrupts
    __WFE();
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
    NVIC_SystemReset(); //reset the chip!
}

#ifdef Q_SPY

static void uart_tx1() {
	static uint16_t b;
    QF_INT_DISABLE(); {
    	b = QS_getByte();
    } QF_INT_ENABLE();
    if (b != QS_EOD) {  /* Have a byte to TX? */
    	nrf_drv_uart_tx((const uint8_t*)&b //This cast works only on LE
    			, 1);
    }
}
void uart_event_handler(nrf_drv_uart_event_t * p_event, void* p_context)
{
	switch(p_event->type) {
	case NRF_DRV_UART_EVT_RX_DONE:
		for (uint8_t i=0; i < p_event->data.rxtx.bytes; ++i) {
			//p_event->data.rxtx.p_data[0];
			//(void)nrf_drv_uart_rx(&byte,1);
			QS_RX_PUT(p_event->data.rxtx.p_data[i]);
		}
	    QS_rxParse();  /* parse all the received bytes */
    	break;
	case NRF_DRV_UART_EVT_ERROR:
		//p_event->data.error.error_mask;
	case NRF_DRV_UART_EVT_TX_DONE:
		uart_tx1();
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
    QS_FILTER_ON(TRACE_SDK_EVT);
    QS_FILTER_ON(TRACE_ADV_EVT);
    QS_FILTER_ON(TRACE_BLE_EVT);
    QS_FILTER_ON(TRACE_CONN_EVT);
    QS_FILTER_ON(TRACE_PEER_EVT);
    QS_FILTER_ON(TRACE_SEC_EVT);
    QS_FILTER_ON(TRACE_ALERT_SVC);

    return (uint8_t)1; /* return success */
}
void QS_onCleanup(void) {
}
/*..........................................................................*/
QSTimeCtr QS_onGetTime(void) { /* NOTE: invoked with interrupts DISABLED */
    return QS_tickTime_ + ++QS_i_getTime;
}
/*..........................................................................*/
void QS_onFlush(void) {
#if 0
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
#else
    if (!nrf_drv_uart_tx_in_progress()) {
    	uart_tx1();
    }
#endif
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
