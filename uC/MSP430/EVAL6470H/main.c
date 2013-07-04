#include "bsp.h"
#include "l6470.h"

#pragma vector = TIMERA0_VECTOR
__interrupt void timerA_ISR(void) {
	static int ctr = 0;
	if(++ctr == SYSTICK_HZ/2) {
		ctr = 0;
		LED_toggle();
	}
}
//P1.0 is LED1
#define LED_init()   (P1DIR |= BIT0)
#define LED_on()     (P1OUT |= BIT0)
#define LED_off()    (P1OUT &= ~BIT0)
#define LED_toggle() (P1OUT ^= BIT0)
void Q_ERROR() {
    LED_on();
    for(;;);
}
int main(void) {
	uint16_t status;

	WDTCTL = WDTPW | WDTHOLD; // Stop watchdog timer
	LED_init();
	LED_on();
    /* configure the Basic Clock Module */
    DCOCTL = CALDCO_1MHZ;
    BCSCTL1 = CALBC1_1MHZ;

    BCSCTL2 = SELM_3 + DIVM_0;//MCLK = LFXTCLK/1
#ifdef NECESSARY
    do {
    	int i;
        IFG1 &= ~OFIFG;                           // Clear OSCFault flag
        for (i = 0xFF; i > 0; i--);               // Time for flag to set
    } while ((IFG1 & OFIFG)); // OSCFault flag still set?
#endif
    TACTL = TASSEL_2 | MC_1; /* SMCLK, upmode */
    TACCR0 = TIMER_CLK_HZ/SYSTICK_HZ;
	TACCTL0 = CCIE; /*Enable timer A0 interrupt*/

	//Enable SCLK, SDI, SDO, master
	USICTL0 |= USIPE7 | USIPE6 | USIPE5 | USIMST | USIOE;
	USICKCTL |= USIDIV_0 //this actually means divide by 1
			  | USISSEL_2//Use SMCLK to drive the SPI clk
			  //| USICKPL
			  ;
	USICTL1 |= USICKPH;//delay?
	//USICTL1 |= USIIE;//interrupt enable
	//		;
	P1OUT = BIT4;//Pull up nCS at first
	P1DIR |= BIT4;//nCS is P1.4
	//P1REN |= 0x10;?

	_enable_interrupts();//vs. _BIS_SR(LPM0_bits + GIE);
	LED_off();

	dSPIN_Soft_Stop();
	dSPIN_Reset_Device();

	status = dSPIN_Get_Status();
   	if(status & dSPIN_STATUS_SW_EVN
   		|| (status & dSPIN_STATUS_MOT_STATUS) != dSPIN_STATUS_MOT_STATUS_STOPPED
   		|| status & dSPIN_STATUS_NOTPERF_CMD
   		|| status & dSPIN_STATUS_WRONG_CMD
   		// !(status & dSPIN_STATUS_UVLO)
   		|| !(status & dSPIN_STATUS_TH_SD)
   		|| !(status & dSPIN_STATUS_OCD))
		Q_ERROR();
    if(dSPIN_Busy_HW()) Q_ERROR();
    return 0;
}
