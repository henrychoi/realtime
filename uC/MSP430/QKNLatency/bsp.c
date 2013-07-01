#include "qpn_port.h"
#include "bsp.h"

#define CPU_HZ (6000000U)//Why does it seem to be 6 Mhz? Supposed to be 8 MHz
#define TIMER_CLK_HZ (CPU_HZ/8U)
#define TIMER_VAL (TIMER_CLK_HZ/SYSTICK_HZ)

/*..........................................................................*/
#pragma vector = TIMERB0_VECTOR
__interrupt void timerB0_ISR(void) {
	#define DEBUG_INTERRUPT
	#ifdef DEBUG_INTERRUPT
	static uint16_t ctr = 0;
	if(++ctr > (SYSTICK_HZ/2U)) {
		ctr = 0;
		LED_toggle();
	}
	#endif

	//static uint16_t tickISRTime = 0;
    //uint16_t t1 = TBR;
	//__low_power_mode_off_on_exit();
    QK_ISR_ENTRY();                       /* inform QK-nano about ISR entry */

    QF_tickISR();
    //tickISRTime = TBR - t1;
    QK_ISR_EXIT();                         /* inform QK-nano about ISR exit */
}
/*..........................................................................*/
void BSP_init(void) {
	int i;
    WDTCTL = (WDTPW | WDTHOLD);                               /* Stop WDT */

    //P1DIR = 0; P2DIR = 0; P3DIR = 0; P4DIR = 0; P5DIR = 0;
    P6DIR = 0x20;
    //P1OUT = 0; P2OUT = 0; P3OUT = 0; P4OUT = 0; P5OUT = 0; P6OUT = 0;

    LED_on();//begin startup

    /* configure the Basic Clock Module */
#ifdef CALDCO_8MHZ//feature available on MSP430F2xxxx
    DCOCTL   = CALDCO_8MHZ;                              /* Set DCO to 8MHz */
    BCSCTL1  = CALBC1_8MHZ;
#else
    DCOCTL = 0x7 << 5 //frequency; looks like 8 MHz: the fastest for this chip
    	   + 0x00;// modulation; useless (set to 0) when DCO = 7
    BCSCTL1 = XT2OFF + XTS /* LFXTCLK 0:Low Freq. / 1: High Freq. */
    		+ DIVA_0 /* Auxiliary Clock Divider; ACLK Divider 0: /1 */
    		+ 0x7;//RSEL: the value of the resistor defines the nominal frequency
#endif
    do {
        IFG1 &= ~OFIFG;                           // Clear OSCFault flag
        for (i = 0xFF; i > 0; i--);               // Time for flag to set
    } while ((IFG1 & OFIFG)); // OSCFault flag still set?

    BCSCTL2 = SELM_3 + DIVM_0;//MCLK = LFXTCLK/1
    //Configure timer
    //The up mode is used if the timer period must be different from TBR(max)
    //counts. The timer repeatedly counts up to the value of compare latch
    //TBCL0, which defines the period.
    TBCTL = ID_3 | // DIV_8
    		TASSEL_2 | MC_1;//SMCLK, upmode
    TBCCR0 = TIMER_VAL;
    //TBCCR0 = ((BSP_SMCLK)//divide by 1 since we use ID_0 mode (DIV1)
    //          + BSP_TICKS_PER_SEC/2)
    //       / BSP_TICKS_PER_SEC;

    LED_off();//end startup
}
/*..........................................................................*/
void QF_onStartup(void) {
  //TACCTL0 = CCIE; /*Enable timer A0 interrupt*/
	TBCCTL0 = CCIE; /*Enable timer B0 interrupt*/
}
/*..........................................................................*/
#ifdef QK_PREEMPTIVE
void QK_onIdle(void) {
//    LED_on();LED_off();             /* switch LED1 on and off */
//__low_power_mode_1();                                     /* Enter LPM1 */
}
#else
void QF_onIdle(void) {
	//LED_on();//LED_toggle();
	//The low-power mode stops the CPU clock, so it can interfere with the debugger
    //__low_power_mode_1();                                     /* Enter LPM1 */
    QF_INT_ENABLE();//If not debug, just reenable the interrupts
    //LED_off();
}
#endif
/*..........................................................................*/
void Q_onAssert(char const Q_ROM * const Q_ROM_VAR file, int line) {
    (void)file;                                   /* avoid compiler warning */
    (void)line;                                   /* avoid compiler warning */
    QF_INT_DISABLE();             /* make sure that interrupts are disabled */
    LED_on();
    for(;;);
}
