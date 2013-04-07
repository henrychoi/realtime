#include <math.h>//TODO: move this to HSMController active object
#include "qp_port.h"
#include "aquarium.h"
#include "bsp.h"

#include "hw_memmap.h"
#include "lm4f_cmsis.h"
#include "sysctl.h"
#include "gpio.h"
#include "rom.h"
#include "timer.h"//copied from StellrisWare/driverlib/
#include "pin_map.h"//copied from StellrisWare/driverlib/ for GPIO_PB6_T0CCP0
#include "adc.h"

Q_DEFINE_THIS_FILE

enum ISR_Priorities {   /* ISR priorities starting from the highest urgency */
    GPIOPORTA_PRIO,
    SYSTICK_PRIO,
    /* ... */
};

/* Local-scope objects -----------------------------------------------------*/
static unsigned  l_rnd;                                      /* random seed */

#define LED_RED     (1U << 1)
#define LED_GREEN   (1U << 3)
#define LED_BLUE    (1U << 2)

#define USR_SW1     (1U << 4)
#define USR_SW2     (1U << 0)

#ifdef Q_SPY

    QSTimeCtr QS_tickTime_;
    QSTimeCtr QS_tickPeriod_;
    static uint8_t l_SysTick_Handler;
    static uint8_t l_GPIOPortA_IRQHandler;

    #define UART_BAUD_RATE      115200U
    #define UART_FR_TXFE        0x80U
    #define UART_TXFIFO_DEPTH   16U

    enum AppRecords {                 /* application-specific trace records */
		APP_INIT_INFO = QS_USER
		, THERM_LOOP_STAT
    };

#endif

/*..........................................................................*/
void SysTick_Handler(void) {
    static uint32_t btn_debounced  = USR_SW1;
    static uint8_t  debounce_state = 0U;
    uint32_t btn;
#define Rref 10000.f
#define Vref 5.0f
    //Steinhart-Hart constants for NTC QTRL2Z-103C3-12
    //http://thermistor.com/calculators.php
#define QTRL2Z_SH_A 1.11E-3
#define QTRL2Z_SH_B 2.37E-4
#define QTRL2Z_SH_C 8.73E-8//0x33bb79af in IEEE 754
    float V1, R1, lnR1, den1, T1;
    static uint16_t duty = 0;

    QK_ISR_ENTRY();                      /* inform QK about entering an ISR */

    //TODO: move to in the HSMController's MEASURING state TICK event handler
    //Read sensor inputs
    V1 = 2.718f;
    R1 = Rref * V1 / (Vref - V1);
    lnR1 = log(R1);
    den1 = QTRL2Z_SH_A + QTRL2Z_SH_B * lnR1 + QTRL2Z_SH_C * lnR1 * lnR1 * lnR1;
    T1 = 1/den1;
#ifdef BLINK_BLUE
    //Write actuator output
    if(QS_tickCtr_ & 1U) { //Drive the GPIO out to the DC motor transistor
        GPIOF->DATA_Bits[LED_BLUE] =  LED_BLUE;
    } else {
        GPIOF->DATA_Bits[LED_BLUE] =  0;
    }
#endif//BLINK_BLUE

    ROM_TimerMatchSet(TIMER0_BASE, TIMER_B, duty);//red LED
    ROM_TimerMatchSet(TIMER1_BASE, TIMER_A, duty);//blue LED
    if((duty += 0x1000) >= 64000) duty = 0;

#ifdef Q_SPY
    {
        uint32_t dummy = SysTick->CTRL;     /* clear SysTick_CTRL_COUNTFLAG */
        QS_tickTime_ += QS_tickPeriod_;   /* account for the clock rollover */
    }
#endif

    QF_TICK(&l_SysTick_Handler);           /* process all armed time events */

                                              /* debounce the SW1 button... */
    btn = GPIOF->DATA_Bits[USR_SW1];                   /* read the push btn */
    switch (debounce_state) {
        case 0:
            if (btn != btn_debounced) {
                debounce_state = 1U;        /* transition to the next state */
            }
            break;
        case 1:
            if (btn != btn_debounced) {
                debounce_state = 2U;        /* transition to the next state */
            }
            else {
                debounce_state = 0U;          /* transition back to state 0 */
            }
            break;
        case 2:
            if (btn != btn_debounced) {
                debounce_state = 3U;        /* transition to the next state */
            }
            else {
                debounce_state = 0U;          /* transition back to state 0 */
            }
            break;
        case 3:
            if (btn != btn_debounced) {
                btn_debounced = btn;     /* save the debounced button value */

                if (btn == 0U) {                /* is the button depressed? */
                    static QEvt const pauseEvt = {PAUSE_SIG, 0U, 0U};
                    QF_PUBLISH(&pauseEvt, &l_SysTick_Handler);
                }
                else {
                    static QEvt const pauseEvt = {RESUME_SIG, 0U, 0U};
                    QF_PUBLISH(&pauseEvt, &l_SysTick_Handler);
                }
            }
            debounce_state = 0U;              /* transition back to state 0 */
            break;
    }

    QK_ISR_EXIT();                        /* infrom QK about exiting an ISR */
}
/*..........................................................................*/
void GPIOPortA_IRQHandler(void) {
    QK_ISR_ENTRY();                      /* infrom QK about entering an ISR */

    //QACTIVE_POST(AO_Table, Q_NEW(QEvt, MAX_PUB_SIG), /* for testing... */
    //             &l_GPIOPortA_IRQHandler);

    QK_ISR_EXIT();                        /* infrom QK about exiting an ISR */
}

/*..........................................................................*/
void BSP_init(void) {
	//uint32_t timera_prescale;
	//uC specific code////////////////////////////////////////////////////////
    SCB->CPACR |= (0xFU << 20);// Enable the floating-point unit

    /* Enable lazy stacking for interrupt handlers. This allows FPU
    * instructions to be used within interrupt handlers, but at the
    * expense of extra stack and CPU usage.
    */
    FPU->FPCCR |= (1U << FPU_FPCCR_ASPEN_Pos) | (1U << FPU_FPCCR_LSPEN_Pos);

    //Set the clocking to run directly from the crystal (main oscillator), vs. PLL
    ROM_SysCtlClockSet(SYSCTL_SYSDIV_1 | SYSCTL_USE_OSC | SYSCTL_OSC_MAIN
                     | SYSCTL_XTAL_16MHZ);

    /* enable clock to the peripherals used by the application */
    SYSCTL->RCGC2 |= (1U << 5);/* enable clock to GPIOF;
    * same as ROM_SysCtlPeripheralEnable(SYSCTL_PERIPH_GPIOF); */
    asm(" MOV R0,R0");                        /* wait after enabling clocks */
    asm(" MOV R0,R0");                        /* wait after enabling clocks */
    asm(" MOV R0,R0");                        /* wait after enabling clocks */

    /* configure the LEDs and push buttons */
    GPIOF->DIR |= (LED_RED | LED_GREEN | LED_BLUE);/* set direction: output */
    GPIOF->DEN |= (LED_RED | LED_GREEN | LED_BLUE);       /* digital enable */
    //GPIOF->DATA_Bits[LED_RED]   = 0;                    /* turn the LED off */
    //GPIOF->DATA_Bits[LED_BLUE]  = 0;                    /* turn the LED off */
    GPIOF->DATA_Bits[LED_GREEN] = 0;                    /* turn the LED off */

    /* configure the User Switches */
    GPIOF->DIR &= ~(USR_SW1 | USR_SW2);            /*  set direction: input */
    ROM_GPIOPadConfigSet(GPIO_PORTF_BASE, (USR_SW1 | USR_SW2),
                         GPIO_STRENGTH_2MA, GPIO_PIN_TYPE_STD_WPU);

    ROM_SysCtlPeripheralEnable(SYSCTL_PERIPH_ADC0);
    ROM_SysCtlADCSpeedSet(SYSCTL_ADCSPEED_250KSPS);
    ROM_ADCHardwareOversampleConfigure(ADC0_BASE, 64);
    ROM_ADCSequenceDisable(ADC0_BASE, 1U);
    ROM_ADCSequenceConfigure(ADC0_BASE, 1, ADC_TRIGGER_PROCESSOR, 0);
    ROM_ADCSequenceStepConfigure(ADC0_BASE, 1, 0, ADC_CTL_TS);
    ROM_ADCSequenceStepConfigure(ADC0_BASE, 1, 1, ADC_CTL_TS);
    ROM_ADCSequenceStepConfigure(ADC0_BASE, 1, 2, ADC_CTL_TS);
    ROM_ADCSequenceStepConfigure(ADC0_BASE, 1, 3, ADC_CTL_TS | ADC_CTL_IE | ADC_CTL_END);
    ROM_ADCSequenceEnable(ADC0_BASE, 1);

    //Configure PWM
#ifdef CONFIG_PB6_PWM
    //Configure PB6 as T0CCP0
    //ml4f120h5qr.pdf, Table 11-1: Timer 0A is connected to CCP in T0CCP0
    //Table 11-2: T0CCP0 is connected to either PB6 or PF0 (which is already
    //connected to SW2 on Stellaris Launchpad).
    ROM_SysCtlPeripheralEnable(SYSCTL_PERIPH_GPIOB);
    ROM_GPIOPinConfigure(GPIO_PB6_T0CCP0);
    ROM_GPIOPinTypeTimer(GPIO_PORTB_BASE, GPIO_PIN_6);

    ROM_SysCtlPeripheralEnable(SYSCTL_PERIPH_TIMER0);
    ROM_TimerConfigure(TIMER0_BASE
    		     , TIMER_CFG_PERIODIC| TIMER_CFG_SPLIT_PAIR| TIMER_CFG_A_PWM);
    timera_prescale = ROM_TimerPrescaleGet(TIMER0_BASE, TIMER_A);
    ROM_TimerControlLevel(TIMER0_BASE, TIMER_A, 1U);//Invert the output
    ROM_TimerLoadSet(TIMER0_BASE, TIMER_A, 64000);
    ROM_TimerMatchSet(TIMER0_BASE, TIMER_A, 64000-1);//Set initial PWM
#endif//CONFIG_PB6_PWM

    ROM_GPIOPinConfigure(GPIO_PF1_T0CCP1);
    ROM_GPIOPinTypeTimer(GPIO_PORTF_BASE, GPIO_PIN_1);
    ROM_SysCtlPeripheralEnable(SYSCTL_PERIPH_TIMER0);
    ROM_TimerConfigure(TIMER0_BASE
    		     , TIMER_CFG_PERIODIC| TIMER_CFG_SPLIT_PAIR| TIMER_CFG_B_PWM);
    ROM_TimerControlLevel(TIMER0_BASE, TIMER_B, 1U);//Invert the output
    ROM_TimerLoadSet(TIMER0_BASE, TIMER_B, 64000);
    ROM_TimerMatchSet(TIMER0_BASE, TIMER_B, 0);//Zero initial PWM
    ROM_TimerEnable(TIMER0_BASE, TIMER_B);

    ROM_GPIOPinConfigure(GPIO_PF2_T1CCP0);
    ROM_GPIOPinTypeTimer(GPIO_PORTF_BASE, GPIO_PIN_2);
    ROM_SysCtlPeripheralEnable(SYSCTL_PERIPH_TIMER1);
    ROM_TimerConfigure(TIMER1_BASE
    		     , TIMER_CFG_PERIODIC| TIMER_CFG_SPLIT_PAIR| TIMER_CFG_A_PWM);
    ROM_TimerControlLevel(TIMER1_BASE, TIMER_A, 1U);//Invert the output
    ROM_TimerLoadSet(TIMER1_BASE, TIMER_A, 64000);
    ROM_TimerMatchSet(TIMER1_BASE, TIMER_A, 0);//Zero initial PWM
    ROM_TimerEnable(TIMER1_BASE, TIMER_A);

    //uC independent code/////////////////////////////////////////////////////
    BSP_randomSeed(1234U);

    if (QS_INIT((void *)0) == 0) {    /* initialize the QS software tracing */
        Q_ERROR();
    }
    QS_RESET();
    QS_OBJ_DICTIONARY(&l_SysTick_Handler);
    QS_OBJ_DICTIONARY(&l_GPIOPortA_IRQHandler);\
}

/*..........................................................................*/
void BSP_displayPaused(uint8_t paused) {
    GPIOF->DATA_Bits[LED_RED] = ((paused != 0U) ? LED_RED : 0U);
}
/*..........................................................................*/
uint32_t BSP_random(void) {  /* a very cheap pseudo-random-number generator */
    float volatile x = 3.1415926F;
    x = x + 2.7182818F;

    /* "Super-Duper" Linear Congruential Generator (LCG)
    * LCG(2^32, 3*7*11*13*23, 0, seed)
    */
    l_rnd = l_rnd * (3U*7U*11U*13U*23U);

    return l_rnd >> 8;
}
/*..........................................................................*/
void BSP_randomSeed(uint32_t seed) {
    l_rnd = seed;
}
/*..........................................................................*/
void BSP_terminate(int16_t result) {
    (void)result;
}

/*..........................................................................*/
void QF_onStartup(void) {
    //CMSIS lib: set up the SysTick timer to fire at BSP_TICKS_PER_SEC rate
	uint32_t uC_clock_rate = ROM_SysCtlClockGet();
    QS_BEGIN(APP_INIT_INFO, 0);
        QS_U32(9, uC_clock_rate);//I'm curious what the uC clock rate is
    QS_END();

    SysTick_Config(uC_clock_rate / BSP_TICKS_PER_SEC);

                       /* set priorities of all interrupts in the system... */
    NVIC_SetPriority(SysTick_IRQn,   SYSTICK_PRIO);
    NVIC_SetPriority(GPIOPortA_IRQn, GPIOPORTA_PRIO);

    NVIC_EnableIRQ(GPIOPortA_IRQn);
}
/*..........................................................................*/
void QF_onCleanup(void) {
}
/*..........................................................................*/
void QK_onIdle(void) {
#ifdef INDICATE_IDLE_WITH_LED
    QF_INT_DISABLE();
    GPIOF->DATA_Bits[LED_GREEN] = LED_GREEN;//0
    QF_INT_ENABLE();
#endif//INDICATE_IDLE_WITH_LED

#ifdef THIS_IS_RATHER_USELESS
    float volatile x = 3.1415926F;
    x = x + 2.7182818F;
#endif

#ifdef Q_SPY
    if ((UART0->FR & UART_FR_TXFE) != 0) {                      /* TX done? */
        uint16_t fifo = UART_TXFIFO_DEPTH;       /* max bytes we can accept */
        uint8_t const *block;

        QF_INT_DISABLE();
        block = QS_getBlock(&fifo);    /* try to get next block to transmit */
        QF_INT_ENABLE();

        while (fifo-- != 0) {                    /* any bytes in the block? */
            UART0->DR = *block++;                      /* put into the FIFO */
        }
    }
#elif defined NDEBUG
    /* Put the CPU and peripherals to the low-power mode.
    * you might need to customize the clock management for your application,
    * see the datasheet for your particular Cortex-M3 MCU.
    */
    asm(" WFI");                                      /* Wait-For-Interrupt */
#endif

#ifdef INDICATE_IDLE_WITH_LED
    QF_INT_DISABLE();
    GPIOF->DATA_Bits[LED_GREEN] = 0;//LED_GREEN
    QF_INT_ENABLE();
#endif//INDICATE_IDLE_WITH_LED
}

/*..........................................................................*/
void Q_onAssert(char const Q_ROM * const Q_ROM_VAR file, int line) {
    (void)file;                                   /* avoid compiler warning */
    (void)line;                                   /* avoid compiler warning */
    QF_INT_DISABLE();         /* make sure that all interrupts are disabled */
    for (;;) {       /* NOTE: replace the loop with reset for final version */
    }
}
/*..........................................................................*/
/* error routine that is called if the CMSIS library encounters an error    */
void assert_failed(char const *file, int line) {
    Q_onAssert(file, line);
}

/*--------------------------------------------------------------------------*/
#ifdef Q_SPY
/*..........................................................................*/
uint8_t QS_onStartup(void const *arg) {
    static uint8_t qsBuf[2*1024];                 /* buffer for Quantum Spy */
    uint32_t tmp;
    QS_initBuf(qsBuf, sizeof(qsBuf));

                                /* enable the peripherals used by the UART0 */
    SYSCTL->RCGC1 |= (1U << 0);                    /* enable clock to UART0 */
    SYSCTL->RCGC2 |= (1U << 0);                    /* enable clock to GPIOA */
    asm("  MOV R0,R0");                       /* wait after enabling clocks */
    asm("  MOV R0,R0");                       /* wait after enabling clocks */
    asm("  MOV R0,R0");                       /* wait after enabling clocks */

    // UART pins are at GPIOA configure UART0 pins for UART operation
    tmp = (1U << 0) | (1U << 1);
    GPIOA->DIR   &= ~tmp;//bit 0 means input, 1 means output; compare w/ GPIOF
    GPIOA->AFSEL |= tmp;//mode control select register
    GPIOA->DR2R  |= tmp;        /* set 2mA drive, DR4R and DR8R are cleared */
    GPIOA->SLR   &= ~tmp;//slew-rate control enable register
    GPIOA->ODR   &= ~tmp;//open drain select register
    GPIOA->PUR   &= ~tmp;//pull-up register
    GPIOA->PDR   &= ~tmp;//pull-down register
    GPIOA->DEN   |= tmp; //digital input enable register

           /* configure the UART for the desired baud rate, 8-N-1 operation */
    tmp = (((ROM_SysCtlClockGet() * 8U) / UART_BAUD_RATE) + 1U) / 2U;
    UART0->IBRD   = tmp / 64U;
    UART0->FBRD   = tmp % 64U;
    UART0->LCRH   = 0x60U;                     /* configure 8-N-1 operation */
    UART0->LCRH  |= 0x10U;
    UART0->CTL   |= (1U << 0) | (1U << 8) | (1U << 9);

    QS_tickPeriod_ = ROM_SysCtlClockGet() / BSP_TICKS_PER_SEC;
    QS_tickTime_ = QS_tickPeriod_;        /* to start the timestamp at zero */

                                                 /* setup the QS filters... */
    QS_FILTER_ON(QS_ALL_RECORDS);

//    QS_FILTER_OFF(QS_QEP_STATE_EMPTY);
//    QS_FILTER_OFF(QS_QEP_STATE_ENTRY);
//    QS_FILTER_OFF(QS_QEP_STATE_EXIT);
//    QS_FILTER_OFF(QS_QEP_STATE_INIT);
//    QS_FILTER_OFF(QS_QEP_INIT_TRAN);
//    QS_FILTER_OFF(QS_QEP_INTERN_TRAN);
//    QS_FILTER_OFF(QS_QEP_TRAN);
//    QS_FILTER_OFF(QS_QEP_IGNORED);

//    QS_FILTER_OFF(QS_QF_ACTIVE_ADD);
//    QS_FILTER_OFF(QS_QF_ACTIVE_REMOVE);
//    QS_FILTER_OFF(QS_QF_ACTIVE_SUBSCRIBE);
//    QS_FILTER_OFF(QS_QF_ACTIVE_UNSUBSCRIBE);
//    QS_FILTER_OFF(QS_QF_ACTIVE_POST_FIFO);
//    QS_FILTER_OFF(QS_QF_ACTIVE_POST_LIFO);
//    QS_FILTER_OFF(QS_QF_ACTIVE_GET);
//    QS_FILTER_OFF(QS_QF_ACTIVE_GET_LAST);
//    QS_FILTER_OFF(QS_QF_EQUEUE_INIT);
//    QS_FILTER_OFF(QS_QF_EQUEUE_POST_FIFO);
//    QS_FILTER_OFF(QS_QF_EQUEUE_POST_LIFO);
//    QS_FILTER_OFF(QS_QF_EQUEUE_GET);
//    QS_FILTER_OFF(QS_QF_EQUEUE_GET_LAST);
//    QS_FILTER_OFF(QS_QF_MPOOL_INIT);
//    QS_FILTER_OFF(QS_QF_MPOOL_GET);
//    QS_FILTER_OFF(QS_QF_MPOOL_PUT);
//    QS_FILTER_OFF(QS_QF_PUBLISH);
//    QS_FILTER_OFF(QS_QF_NEW);
//    QS_FILTER_OFF(QS_QF_GC_ATTEMPT);
//    QS_FILTER_OFF(QS_QF_GC);
//    QS_FILTER_OFF(QS_QF_TICK);
//    QS_FILTER_OFF(QS_QF_TIMEEVT_ARM);
//    QS_FILTER_OFF(QS_QF_TIMEEVT_AUTO_DISARM);
//    QS_FILTER_OFF(QS_QF_TIMEEVT_DISARM_ATTEMPT);
//    QS_FILTER_OFF(QS_QF_TIMEEVT_DISARM);
//    QS_FILTER_OFF(QS_QF_TIMEEVT_REARM);
//    QS_FILTER_OFF(QS_QF_TIMEEVT_POST);
    QS_FILTER_OFF(QS_QF_CRIT_ENTRY);
    QS_FILTER_OFF(QS_QF_CRIT_EXIT);
    QS_FILTER_OFF(QS_QF_ISR_ENTRY);
    QS_FILTER_OFF(QS_QF_ISR_EXIT);

    return (uint8_t)1;                                    /* return success */
}
/*..........................................................................*/
void QS_onCleanup(void) {
}
/*..........................................................................*/
QSTimeCtr QS_onGetTime(void) {            /* invoked with interrupts locked */
    if ((SysTick->CTRL & SysTick_CTRL_COUNTFLAG_Msk) == 0) {    /* not set? */
        return QS_tickTime_ - (QSTimeCtr)SysTick->VAL;
    }
    else {     /* the rollover occured, but the SysTick_ISR did not run yet */
        return QS_tickTime_ + QS_tickPeriod_ - (QSTimeCtr)SysTick->VAL;
    }
}
/*..........................................................................*/
void QS_onFlush(void) {
    uint16_t fifo = UART_TXFIFO_DEPTH;                     /* Tx FIFO depth */
    uint8_t const *block;
    QF_INT_DISABLE();
    while ((block = QS_getBlock(&fifo)) != (uint8_t *)0) {
        QF_INT_ENABLE();
                                           /* busy-wait until TX FIFO empty */
        while ((UART0->FR & UART_FR_TXFE) == 0) {
        }

        while (fifo-- != 0) {                    /* any bytes in the block? */
            UART0->DR = *block++;                   /* put into the TX FIFO */
        }
        fifo = UART_TXFIFO_DEPTH;              /* re-load the Tx FIFO depth */
        QF_INT_DISABLE();
    }
    QF_INT_ENABLE();
}
#endif                                                             /* Q_SPY */
/*--------------------------------------------------------------------------*/

/*****************************************************************************
* NOTE02:
* The User LED is used to visualize the idle loop activity. The brightness
* of the LED is proportional to the frequency of invcations of the idle loop.
* Please note that the LED is toggled with interrupts locked, so no interrupt
* execution time contributes to the brightness of the User LED.
*/
