#include "bsp.h"

//***********************************************************************************
// Basic Enable Disable Definitions                                                 *
//***********************************************************************************
#define     ENABLE          (0xFF)
#define     DISABLE         (0x00)
#define     INPUT           (0x00)
#define     OUTPUT          (0x01)
#define     IO_FUNCTION     (0x00)
#define     PERIPHERAL      (0x01)
#define     RISING          (0x00)
#define     FALLING         (0x01)

#define     P3DIR7          OUTPUT
#define     P3DIR6          OUTPUT
#define     P3DIR5          OUTPUT
#define     P3DIR4          OUTPUT
#define     P3DIR3          OUTPUT
#define     P3DIR2          OUTPUT
#define     P3DIR1          INPUT
#define     P3DIR0          INPUT
#define     P4DIR7          OUTPUT
#define     P4DIR6          OUTPUT // <-- nRESET
#define     P4DIR5          OUTPUT
#define     P4DIR4          OUTPUT // <-- DIR
#define     P4DIR3          OUTPUT // <-- STP
#define     P4DIR2          OUTPUT // <-- nEN
#define     P4DIR1          OUTPUT
#define     P4DIR0          OUTPUT
#define     P5DIR7          OUTPUT
#define     P5DIR6          OUTPUT
#define     P5DIR5          OUTPUT
#define     P5DIR4          OUTPUT // <-- MD0
#define     P5DIR3          OUTPUT
#define     P5DIR2          INPUT
#define     P5DIR1          OUTPUT // <-- MD1
#define     P5DIR0          OUTPUT // <-- MD2
#define     P6DIR7          OUTPUT
#define     P6DIR6          OUTPUT
#define     P6DIR5          OUTPUT // <-- status LED
#define     P6DIR4          OUTPUT
#define     P6DIR3          INPUT
#define     P6DIR2          INPUT
#define     P6DIR1          INPUT
#define     P6DIR0          INPUT

// Port 1 Alternate Function Select
#define     P1SEL7          IO_FUNCTION
#define     P1SEL6          IO_FUNCTION
#define     P1SEL5          IO_FUNCTION
#define     P1SEL4          IO_FUNCTION
#define     P1SEL3          IO_FUNCTION
#define     P1SEL2          IO_FUNCTION
#define     P1SEL1          IO_FUNCTION
#define     P1SEL0          IO_FUNCTION

// Port 2 Alternate Function Select
#define     P2SEL7          IO_FUNCTION
#define     P2SEL6          IO_FUNCTION
#define     P2SEL5          IO_FUNCTION
#define     P2SEL4          IO_FUNCTION
#define     P2SEL3          IO_FUNCTION
#define     P2SEL2          IO_FUNCTION
#define     P2SEL1          IO_FUNCTION
#define     P2SEL0          IO_FUNCTION

// Port 3 Alternate Function Select
#define     P3SEL7          IO_FUNCTION
#define     P3SEL6          IO_FUNCTION
#define     P3SEL5          PERIPHERAL
#define     P3SEL4          PERIPHERAL
#define     P3SEL3          IO_FUNCTION
#define     P3SEL2          IO_FUNCTION
#define     P3SEL1          IO_FUNCTION
#define     P3SEL0          IO_FUNCTION

// Port 4 Alternate Function Select
#define     P4SEL7          IO_FUNCTION
#define     P4SEL6          IO_FUNCTION // <-- nRESET
#define     P4SEL5          IO_FUNCTION
#define     P4SEL4          IO_FUNCTION // <-- DIR
#define     P4SEL3          IO_FUNCTION // <-- STP; was PERIPHERAL
#define     P4SEL2          IO_FUNCTION // <-- nEN; was PERIPHERAL
#define     P4SEL1          IO_FUNCTION
#define     P4SEL0          IO_FUNCTION

// Port 5 Alternate Function Select
#define     P5SEL7          IO_FUNCTION
#define     P5SEL6          IO_FUNCTION
#define     P5SEL5          IO_FUNCTION
#define     P5SEL4          IO_FUNCTION // <-- MD0
#define     P5SEL3          PERIPHERAL
#define     P5SEL2          PERIPHERAL
#define     P5SEL1          IO_FUNCTION // <-- MD1; was PERIPHERAL
#define     P5SEL0          IO_FUNCTION // <-- MD2

// Port 6 Alternate Function Select
#define     P6SEL7          PERIPHERAL
#define     P6SEL6          PERIPHERAL
#define     P6SEL5          IO_FUNCTION // <-- status LED
#define     P6SEL4          IO_FUNCTION
#define     P6SEL3          PERIPHERAL
#define     P6SEL2          PERIPHERAL
#define     P6SEL1          PERIPHERAL
#define     P6SEL0          PERIPHERAL

#define     DAC12SREF_VREF  0x0000
#define     DAC12SREF_VEREF 0x6000//external Vref
#define     DAC12SREF0_CONF  DAC12SREF_VREF
#define     DAC12SREF1_CONF  DAC12SREF_VREF

#define     DAC12RES_12     0x0000//12 bit resolution
#define     DAC12RES_8      0x1000
#define     DAC12RES0_CONF   DAC12RES_12
#define     DAC12RES1_CONF   DAC12RES_12

#define     DAC12LSEL_AUTO  0x0000//DAT latch loads when DAC12_xDAT written
#define     DAC12LSEL_DATA  0x0400
#define     DAC12LSEL_RISEA 0x0800
#define     DAC12LSEL_RISEB 0x0C00
#define     DAC12LSEL0_CONF  DAC12LSEL_AUTO
#define     DAC12LSEL1_CONF  DAC12LSEL_AUTO

#define     DAC12IR_3X      0x0000//3x reference voltage
#define     DAC12IR_1X      0x0100//1x reference voltage
#define     DAC12IR0_CONF    DAC12IR_1X
#define     DAC12IR1_CONF    DAC12IR_1X

#define     DAC12AMP_OFFZ   0x0000
#define     DAC12AMP_OFF0   0x0020
#define     DAC12AMP_LOLO   0x0040
#define     DAC12AMP_LOMD   0x0030
#define     DAC12AMP_LOHI   0x0080
#define     DAC12AMP_MDMD   0x00A0
#define     DAC12AMP_MDHI   0x00C0
#define     DAC12AMP_HIHI   0x00E0
//When DAC12AMPx > 0, the DAC12 function is automatically selected
//for the pin, regardless of the state of the associated P6SELx and P6DIRx bits
#define     DAC12AMP0_CONF   DAC12AMP_LOLO
#define     DAC12AMP1_CONF   DAC12AMP_OFFZ

#define     DAC12DF_BIN     0x0000//straight binary
#define     DAC12DF_2SC     0x0010//2's complement
#define     DAC12DF0_CONF    DAC12DF_BIN
#define     DAC12DF1_CONF    DAC12DF_BIN

#define     DAC12ENC_DIS    0x0000//DACA12 disabled
#define     DAC12ENC_ENA    0x0002//Enable DAC when DAC12LSECx > 0.  Ignored otherwise
#define     DAC12ENC0_CONF   DAC12ENC_DIS
#define     DAC12ENC1_CONF   DAC12ENC_DIS

#define     DAC12GRP_NOT    0x0000//DAC not grouped
#define     DAC12GRP_GRP    0x0001//DAC grouped
#define     DAC12GRP0_CONF   DAC12GRP_NOT
#define     DAC12GRP1_CONF   DAC12GRP_NOT

#define StatusLEDPin 0x20//Q: is this mapped to STP pin on DRV8825EVM?


void BSP_init(void) {
	int i;
    WDTCTL = WDTPW | WDTHOLD;//Not going to use WDT

    ADC12CTL0 = REF2_5V + REFON;// Internal 2.5V ref on for DAC

    P6SEL = 0x40;//'b0100_0000.  P6.6 is a peripheral (DAC)

    //Use DAC0 to drive AVREF
    //DAC12_0CTL = DAC12SREF0_CONF + DAC12RES0_CONF + DAC12LSEL0_CONF + DAC12IR0_CONF
    //           + DAC12AMP0_CONF + DAC12DF0_CONF + DAC12ENC0_CONF + DAC12GRP0_CONF;
    DAC12_0CTL = DAC12IR + DAC12AMP_5 + DAC12ENC;

    // Ports 1 through 6 Direction Select
    P1DIR = 0xFF;
    P2DIR = 0x00;
    P3DIR = (P3DIR7 << 7) + (P3DIR6 << 6) + (P3DIR5 << 5) + (P3DIR4 << 4) + (P3DIR3 << 3) + (P3DIR2 << 2) + (P3DIR1 << 1) + P3DIR0;
    P4DIR = (P4DIR7 << 7) + (P4DIR6 << 6) + (P4DIR5 << 5) + (P4DIR4 << 4) + (P4DIR3 << 3) + (P4DIR2 << 2) + (P4DIR1 << 1) + P4DIR0;
    P5DIR = (P5DIR7 << 7) + (P5DIR6 << 6) + (P5DIR5 << 5) + (P5DIR4 << 4) + (P5DIR3 << 3) + (P5DIR2 << 2) + (P5DIR1 << 1) + P5DIR0;
    P6DIR = (P6DIR7 << 7) + (P6DIR6 << 6) + (P6DIR5 << 5) + (P6DIR4 << 4) + (P6DIR3 << 3) + (P6DIR2 << 2) + (P6DIR1 << 1) + P6DIR0;

    P1OUT = 0;
    P2OUT = 0;
    P3OUT = 0;
    P4OUT = 0;
    P5OUT = 0;
    P6OUT = 0;

    LED_on();//begin startup

    // Configure timer
    TBCTL = (ID_3 | TASSEL_2 | MC_1);       /* SMCLK, /8 divider, upmode */
#ifdef USE_TIMERA
    TACTL = TASSEL_2//MC_1; // timer A clk = SMCLK
          + MC_2; // MC_1: timer A in upmode, MC_2: continuous mode
          //+ ID_2 //divide by 4
#endif

    //Configure the basic clock module
    DCOCTL = 0x7 << 5 //frequency; looks like 8 MHz: the fastest for this chip
    	   + 0x00;// modulation; useless (set to 0) when DCO = 7
    BCSCTL1 = XT2OFF + XTS /* LFXTCLK 0:Low Freq. / 1: High Freq. */
    		+ DIVA_0 /* Auxiliary Clock Divider; ACLK Divider 0: /1 */
    		+ 0x7;//RSEL: the value of the resistor defines the nominal frequency
    do {
      IFG1 &= ~OFIFG;                           // Clear OSCFault flag
      for (i = 0xFF; i > 0; i--);               // Time for flag to set
    } while ((IFG1 & OFIFG)); // OSCFault flag still set?


    BCSCTL2 = SELM_3 + DIVM_0;//MCLK = LFXTCLK/1
#ifdef USE_TIMERB
	TBCCTL0 = CCIE; /*Enable timer B interrupt*/
    TBCCR0 = 0xFFFF;
#endif
	LED_off();//End of startup
}

void assert(uint8_t boolval) {
	while(!boolval) {
		LED_on();
	}
}
