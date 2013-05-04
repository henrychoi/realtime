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

// Port 1 Direction Configure
#define     P1DIR7          OUTPUT
#define     P1DIR6          OUTPUT
#define     P1DIR5          OUTPUT
#define     P1DIR4          OUTPUT
#define     P1DIR3          OUTPUT
#define     P1DIR2          OUTPUT
#define     P1DIR1          OUTPUT
#define     P1DIR0          OUTPUT

// Port 2 Direction Configure
#define     P2DIR7          INPUT
#define     P2DIR6          INPUT
#define     P2DIR5          INPUT
#define     P2DIR4          INPUT
#define     P2DIR3          INPUT
#define     P2DIR2          INPUT
#define     P2DIR1          INPUT
#define     P2DIR0          INPUT

// Port 3 Direction Configure
#define     P3DIR7          OUTPUT
#define     P3DIR6          OUTPUT
#define     P3DIR5          OUTPUT
#define     P3DIR4          OUTPUT
#define     P3DIR3          OUTPUT
#define     P3DIR2          OUTPUT
#define     P3DIR1          INPUT
#define     P3DIR0          INPUT

// Port 4 Direction Configure
#define     P4DIR7          OUTPUT
#define     P4DIR6          OUTPUT
#define     P4DIR5          OUTPUT
#define     P4DIR4          OUTPUT
#define     P4DIR3          OUTPUT
#define     P4DIR2          OUTPUT
#define     P4DIR1          OUTPUT
#define     P4DIR0          OUTPUT

// Port 5 Direction Configure
#define     P5DIR7          OUTPUT
#define     P5DIR6          OUTPUT
#define     P5DIR5          OUTPUT
#define     P5DIR4          OUTPUT
#define     P5DIR3          OUTPUT
#define     P5DIR2          INPUT
#define     P5DIR1          OUTPUT
#define     P5DIR0          OUTPUT

// Port 6 Direction Configure
#define     P6DIR7          OUTPUT
#define     P6DIR6          OUTPUT
#define     P6DIR5          OUTPUT
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
#define     P4SEL6          IO_FUNCTION
#define     P4SEL5          IO_FUNCTION
#define     P4SEL4          IO_FUNCTION
#define     P4SEL3          PERIPHERAL
#define     P4SEL2          PERIPHERAL
#define     P4SEL1          IO_FUNCTION
#define     P4SEL0          IO_FUNCTION

// Port 5 Alternate Function Select
#define     P5SEL7          IO_FUNCTION
#define     P5SEL6          IO_FUNCTION
#define     P5SEL5          IO_FUNCTION
#define     P5SEL4          IO_FUNCTION
#define     P5SEL3          PERIPHERAL
#define     P5SEL2          PERIPHERAL
#define     P5SEL1          PERIPHERAL
#define     P5SEL0          IO_FUNCTION

// Port 6 Alternate Function Select
#define     P6SEL7          PERIPHERAL
#define     P6SEL6          PERIPHERAL
#define     P6SEL5          IO_FUNCTION
#define     P6SEL4          IO_FUNCTION
#define     P6SEL3          PERIPHERAL
#define     P6SEL2          PERIPHERAL
#define     P6SEL1          PERIPHERAL
#define     P6SEL0          PERIPHERAL

// Port 1 Pin On Change Interrupt Enable
#define     P1IE7          DISABLE
#define     P1IE6          DISABLE
#define     P1IE5          DISABLE
#define     P1IE4          DISABLE
#define     P1IE2          DISABLE
#define     P1IE3          DISABLE
#define     P1IE1          DISABLE
#define     P1IE0          DISABLE

// Port 2 Pin On Change Interrupt Enable
#define     P2IE7          DISABLE
#define     P2IE6          DISABLE
#define     P2IE5          DISABLE
#define     P2IE4          DISABLE
#define     P2IE2          DISABLE
#define     P2IE3          DISABLE
#define     P2IE1          DISABLE
#define     P2IE0          DISABLE

// Port 1 Pin On Change Interrupt Edge Select
#define     P1IES7          RISING
#define     P1IES6          RISING
#define     P1IES5          RISING
#define     P1IES4          RISING
#define     P1IES2          RISING
#define     P1IES3          RISING
#define     P1IES1          RISING
#define     P1IES0          RISING

// Port 2 Pin On Change Interrupt Edge Select
#define     P2IES7          RISING
#define     P2IES6          RISING
#define     P2IES5          RISING
#define     P2IES4          RISING
#define     P2IES2          RISING
#define     P2IES3          RISING
#define     P2IES1          RISING
#define     P2IES0          RISING

#define StatusLEDPin 0x20//Q: is this mapped to STP pin on DRV8825EVM?

/*..........................................................................*/
void BSP_init(void) {
	int i;
    WDTCTL = WDTPW | WDTHOLD;//Not going to use WDT
    // Ports 1 through 6 Direction Select
    P1DIR = (P1DIR7 << 7) + (P1DIR6 << 6) + (P1DIR5 << 5) + (P1DIR4 << 4) + (P1DIR3 << 3) + (P1DIR2 << 2) + (P1DIR1 << 1) + P1DIR0;
    P2DIR = (P2DIR7 << 7) + (P2DIR6 << 6) + (P2DIR5 << 5) + (P2DIR4 << 4) + (P2DIR3 << 3) + (P2DIR2 << 2) + (P2DIR1 << 1) + P2DIR0;
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

#ifdef NECESSARY
    // Ports 1 through 6 Alternate Peripheral Function Enable
    P1SEL = (P1SEL7 << 7) + (P1SEL6 << 6) + (P1SEL5 << 5) + (P1SEL4 << 4) + (P1SEL3 << 3) + (P1SEL2 << 2) + (P1SEL1 << 1) + P1SEL0;
    P2SEL = (P2SEL7 << 7) + (P2SEL6 << 6) + (P2SEL5 << 5) + (P2SEL4 << 4) + (P2SEL3 << 3) + (P2SEL2 << 2) + (P2SEL1 << 1) + P2SEL0;
    P3SEL = (P3SEL7 << 7) + (P3SEL6 << 6) + (P3SEL5 << 5) + (P3SEL4 << 4) + (P3SEL3 << 3) + (P3SEL2 << 2) + (P3SEL1 << 1) + P3SEL0;
    P4SEL = (P4SEL7 << 7) + (P4SEL6 << 6) + (P4SEL5 << 5) + (P4SEL4 << 4) + (P4SEL3 << 3) + (P4SEL2 << 2) + (P4SEL1 << 1) + P4SEL0;
    P5SEL = (P5SEL7 << 7) + (P5SEL6 << 6) + (P5SEL5 << 5) + (P5SEL4 << 4) + (P5SEL3 << 3) + (P5SEL2 << 2) + (P5SEL1 << 1) + P5SEL0;
    P6SEL = (P6SEL7 << 7) + (P6SEL6 << 6) + (P6SEL5 << 5) + (P6SEL4 << 4) + (P6SEL3 << 3) + (P6SEL2 << 2) + (P6SEL1 << 1) + P6SEL0;

    // Ports 1 and 2 Pin On Change Interrupt Enable
    P1IE = (P1IE7 << 7) + (P1IE6 << 6) + (P1IE5 << 5) + (P1IE4 << 4) + (P1IE3 << 3) + (P1IE2 << 2) + (P1IE1 << 1) + P1IE0;
    P2IE = (P2IE7 << 7) + (P2IE6 << 6) + (P2IE5 << 5) + (P2IE4 << 4) + (P2IE3 << 3) + (P2IE2 << 2) + (P2IE1 << 1) + P2IE0;
    P1IES = (P1IES7 << 7) + (P1IES6 << 6) + (P1IES5 << 5) + (P1IES4 << 4) + (P1IES3 << 3) + (P1IES2 << 2) + (P1IES1 << 1) + P1IES0;
    P2IES = (P2IES7 << 7) + (P2IES6 << 6) + (P2IES5 << 5) + (P2IES4 << 4) + (P2IES3 << 3) + (P2IES2 << 2) + (P2IES1 << 1) + P2IES0;
#endif//NECESSARY

    LED_on();//begin startup

    // Configure timer
    TACTL = TASSEL_2//MC_1; // timer A clk = SMCLK
          + MC_2; // MC_1: timer A in upmode, MC_2: continuous mode
          //+ ID_2 //divide by 4

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

    LED_off();//End of startup
}

void assert(uint8_t boolval) {
	while(!boolval) {
		LED_on();
	}
}


