#include <msp430g2231.h>
unsigned long count = 0;
#pragma vector = TIMERA0_VECTOR
__interrupt void timerA_ISR(void) {
	count += 0x10000;
	if(count & 0x10000) P1OUT ^= 0x40;
}

int main(void) {
	WDTCTL = WDTPW | WDTHOLD; // Stop watchdog timer
	P1SEL = 0x01;//P0.1 is TA0CLK
	P1DIR = 0x40;//P1.6 is LED2

	//Choices are between MC_1: count up to TACCR0, or MC_2: to 0xFFFF
	TACTL = (TASSEL_0 | MC_2);//TACLK, DIV1

	TACCTL0 = CCIE; /*Enable timer A0 interrupt*/
	_enable_interrupts();
	while(1) {
		unsigned long fine_count = count + TAR;
    }
}
