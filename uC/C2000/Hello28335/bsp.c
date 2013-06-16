#include <DSP2833x_Device.h>
#include "DSP2833x_Examples.h"   // DSP2833x Examples Include File

#define DEBUG_LED_on()     (GpioDataRegs.GPACLEAR.bit.GPIO31  = 1)
#define DEBUG_LED_off()    (GpioDataRegs.GPASET.bit.GPIO31    = 1)
#define DEBUG_LED_toggle() (GpioDataRegs.GPATOGGLE.bit.GPIO31 = 1)

/* CPU Timer0 ISR is used for system clock tick */
//#pragma CODE_SECTION(cpu_timer0_isr, "ramfuncs"); /* place in RAM for speed */
static interrupt void cpu_timer0_isr(void) {
    /* Acknowledge this interrupt to receive more interrupts from group 1 */
    PieCtrlRegs.PIEACK.all = PIEACK_GROUP1;
    DEBUG_LED_toggle();
}
/*..........................................................................*/
// Illegal operation TRAP
static interrupt void illegal_isr(void) {
	DEBUG_LED_on();
    asm (" ESTOP0");
    for(;;) {}
}
/*..........................................................................*/
// This function initializes the PIE control registers to a known state.
//
void PieInit(void) {
    int16  i;
    Uint32 *dest = (Uint32 *)&PieVectTable;

    PieCtrlRegs.PIECTRL.bit.ENPIE = 0; // disable the PIE Vector Table
                                              // Clear all PIEIER registers...
    PieCtrlRegs.PIEIER1.all  = 0;
    PieCtrlRegs.PIEIER2.all  = 0;
    PieCtrlRegs.PIEIER3.all  = 0;
    PieCtrlRegs.PIEIER4.all  = 0;
    PieCtrlRegs.PIEIER5.all  = 0;
    PieCtrlRegs.PIEIER6.all  = 0;
    PieCtrlRegs.PIEIER7.all  = 0;
    PieCtrlRegs.PIEIER8.all  = 0;
    PieCtrlRegs.PIEIER9.all  = 0;
    PieCtrlRegs.PIEIER10.all = 0;
    PieCtrlRegs.PIEIER11.all = 0;
    PieCtrlRegs.PIEIER12.all = 0;

                                              // Clear all PIEIFR registers...
    PieCtrlRegs.PIEIFR1.all  = 0;
    PieCtrlRegs.PIEIFR2.all  = 0;
    PieCtrlRegs.PIEIFR3.all  = 0;
    PieCtrlRegs.PIEIFR4.all  = 0;
    PieCtrlRegs.PIEIFR5.all  = 0;
    PieCtrlRegs.PIEIFR6.all  = 0;
    PieCtrlRegs.PIEIFR7.all  = 0;
    PieCtrlRegs.PIEIFR8.all  = 0;
    PieCtrlRegs.PIEIFR9.all  = 0;
    PieCtrlRegs.PIEIFR10.all = 0;
    PieCtrlRegs.PIEIFR11.all = 0;
    PieCtrlRegs.PIEIFR12.all = 0;

    EALLOW;
    for (i = 0; i < 128; ++i) {
        *dest++ = (Uint32)&illegal_isr;
    }
    EDIS;

    PieCtrlRegs.PIECTRL.bit.ENPIE = 1;
}
//Defined in F28335_qkn.cmd to for global vars that should be in RAM
extern Uint16 RamconstLoadStart, RamconstLoadEnd, RamconstRunStart;

/*..........................................................................*/
void BSP_init(void) {
	// Step 1. Initialize System Control:
	// PLL, WatchDog, enable Peripheral Clocks
	InitSysCtrl();

	// Step 2. Initalize GPIO:
	// This example function is found in the DSP2833x_Gpio.c file and
	// illustrates how to set the GPIO to it's default state.
	//InitGpio();  // Skipped for this example
    EALLOW;
	GpioCtrlRegs.GPACTRL.all  = 0x00000000;		// QUALPRD = SYSCLKOUT for all group A GPIO
	GpioCtrlRegs.GPAQSEL1.all = 0x00000000;		// No qualification for all group A GPIO 0-15
	GpioCtrlRegs.GPAQSEL2.all = 0x00000000;		// No qualification for all group A GPIO 16-31
	GpioCtrlRegs.GPAQSEL2.bit.GPIO28 = 3;       //Async on serial receive
	GpioCtrlRegs.GPADIR.all   = 0xC0001BFE;		// All group A GPIO are inputs
	GpioCtrlRegs.GPAPUD.all   = 0xFFFFFFFF;		// All pullups disabled
	GpioCtrlRegs.GPAPUD.bit.GPIO29=0;//enable pullup on serial transmit
	GpioCtrlRegs.GPAMUX1.all  = 0x00000000;
	GpioCtrlRegs.GPAMUX2.all  = 0x00000000;
	GpioCtrlRegs.GPAMUX1.bit.GPIO0  = 1;		// 0=GPIO  1=EPWM1A     2=rsvd       3=rsvd  (Lines are commented out instead of deleted to make IO changes easy)
	GpioCtrlRegs.GPAMUX1.bit.GPIO10 = 1;		// 0=GPIO  1=EPWM6A     2=CANRXB     3=ADCSOCBO
	GpioCtrlRegs.GPAMUX2.bit.GPIO24 = 3;		// 0=GPIO  1=ECAP1      2=EQEP2A     3=MDXB
	GpioCtrlRegs.GPAMUX2.bit.GPIO26 = 3;		// 0=GPIO  1=ECAP3      2=EQEP2I     3=MCLKXB
	GpioCtrlRegs.GPAMUX2.bit.GPIO27 = 1;		// 0=GPIO  1=ECAP4      2=EQEP2S     3=MFSXB
	GpioCtrlRegs.GPAMUX2.bit.GPIO28 = 1;		// 0=GPIO  1=SCIRXDA    2=XZCS6      3=XZCS6
	GpioCtrlRegs.GPAMUX2.bit.GPIO29 = 1;		// 0=GPIO  1=SCITXDA    2=XA19       3=XA19

	//--- Group B pins
	GpioCtrlRegs.GPBCTRL.all  = 0x00000000;		// QUALPRD = SYSCLKOUT for all group B GPIO
	GpioCtrlRegs.GPBQSEL1.all = 0x00000000;		// No qualification for all group B GPIO 32-47
	GpioCtrlRegs.GPBQSEL2.all = 0x00000000;		// No qualification for all group B GPIO 48-63
	GpioCtrlRegs.GPBDIR.all   = 0x00000000;		// All group B GPIO are inputs
	GpioCtrlRegs.GPBDIR.bit.GPIO51=1; //Humidity clock
	GpioCtrlRegs.GPBDIR.bit.GPIO53=1; //EEPROM CS
	GpioCtrlRegs.GPBDIR.bit.GPIO57=1; //PLD select
	GpioCtrlRegs.GPBDIR.bit.GPIO58=1; //CS 1
	GpioCtrlRegs.GPBDIR.bit.GPIO59=1; //CS 2
	GpioCtrlRegs.GPBDIR.bit.GPIO45=1; //DSR A
	//GpioCtrlRegs.GPBDIR.bit.GPIO47=1; //DSR B
	GpioCtrlRegs.GPBPUD.all   = 0x00000000;		// All group B pullups enabled
	GpioCtrlRegs.GPBMUX1.all =  0x00000000;
	GpioCtrlRegs.GPBMUX2.all =  0x00000000;
	GpioCtrlRegs.GPBMUX2.bit.GPIO54 = 1;		// 0=GPIO  1=SPISIMOA  2=XD25       3=XD25
	GpioCtrlRegs.GPBMUX2.bit.GPIO55 = 1;		// 0=GPIO  1=SPISOMIA  2=XD24       3=XD24
	GpioCtrlRegs.GPBMUX2.bit.GPIO56 = 1;		// 0=GPIO  1=SPICLKA   2=XD23       3=XD23

	//--- Group C pins
	GpioCtrlRegs.GPCDIR.all = 0x00000000;		// All group C GPIO are inputs
	GpioCtrlRegs.GPCPUD.all = 0x00000000;		// All group C pullups enabled
	GpioCtrlRegs.GPCDIR.bit.GPIO64=1; //DOUT 10
	GpioCtrlRegs.GPCDIR.bit.GPIO65=1; //DOUT 11
	GpioCtrlRegs.GPCDIR.bit.GPIO66=1; //regulator dac ldac
	GpioCtrlRegs.GPCDIR.bit.GPIO67=1; //regulator dac sync
	GpioCtrlRegs.GPCDIR.bit.GPIO68=1; //motor mode 1
	GpioCtrlRegs.GPCDIR.bit.GPIO69=1; //motor mode 2
	GpioCtrlRegs.GPCDIR.bit.GPIO70=1; //motor sleep

	GpioCtrlRegs.GPCDIR.bit.GPIO72=1; //PS_CTRL_MCU1-> pump compresor power
	GpioCtrlRegs.GPCDIR.bit.GPIO73=1; //PS_CTRL_MCU2
	GpioCtrlRegs.GPCDIR.bit.GPIO74=1; //PS_CTRL_MCU3

	GpioCtrlRegs.GPCDIR.bit.GPIO75=1; //SLAVE BOARDS RESET
	GpioCtrlRegs.GPCDIR.bit.GPIO76=1; //SLAVE BOARDS CS
	GpioCtrlRegs.GPCDIR.bit.GPIO77=1; //Valve block RCK
	GpioCtrlRegs.GPCDIR.bit.GPIO78=1; //Pressure sensor chip select 1
	GpioCtrlRegs.GPCDIR.bit.GPIO79=1; //Pressure sensor chip select 2
	GpioCtrlRegs.GPCDIR.bit.GPIO80=1; //Pressure sensor chip select 3
	GpioCtrlRegs.GPCDIR.bit.GPIO81=1; //Pressure sensor chip select 4
	GpioCtrlRegs.GPCDIR.bit.GPIO82=1; //Pressure sensor chip select 5
	GpioCtrlRegs.GPCDIR.bit.GPIO83=1; //Pressure sensor chip select 6

	GpioCtrlRegs.GPCMUX1.all = 0x00000000;
	GpioCtrlRegs.GPCMUX2.all = 0x00000000;
	//--- Low-power mode selection
	GpioIntRegs.GPIOLPMSEL.all = 0x00000000;	// No pin selected for HALT and STANBY wakeup (reset default)
    EDIS;

    DEBUG_LED_on();

	// Step 3. Clear all interrupts and initialize PIE vector table:
	DINT;// Disable CPU interrupts

	// Initialize the PIE control registers to their default state.
	// The default state is all PIE interrupts disabled and flags
	// are cleared.
	// This function is found in the DSP2833x_PieCtrl.c file.
	InitPieCtrl();

	// Disable CPU interrupts and clear all CPU interrupt flags:
	IER = 0x0000;
	IFR = 0x0000;

	// Initialize the PIE vector table with pointers to the shell Interrupt
	// Service Routines (ISR).
	// This will populate the entire table, even if the interrupt
	// is not used in this example.  This is useful for debug purposes.
	// The shell ISR routines are found in DSP2833x_DefaultIsr.c.
	// This function is found in DSP2833x_PieVect.c.
	PieInit();
	// Step 5. User specific code, enable interrupts:
    EALLOW;
    PieVectTable.TINT0 = &cpu_timer0_isr;  // hook the CPU timer0 ISR
    /* ... and hook other ISRs */

    SysCtrlRegs.PCLKCR0.bit.ADCENCLK    = 0; // ADC

    SysCtrlRegs.PCLKCR0.bit.I2CAENCLK   = 0; // I2C
    SysCtrlRegs.PCLKCR0.bit.SPIAENCLK   = 0; // SPI-A
    SysCtrlRegs.PCLKCR0.bit.SCIAENCLK   = 0; // SCI-A
    SysCtrlRegs.PCLKCR1.bit.ECAP1ENCLK  = 0; // eCAP1

    SysCtrlRegs.PCLKCR1.bit.EPWM1ENCLK  = 0; // ePWM1
    SysCtrlRegs.PCLKCR1.bit.EPWM2ENCLK  = 0; // ePWM2
    SysCtrlRegs.PCLKCR1.bit.EPWM3ENCLK  = 0; // ePWM3
    SysCtrlRegs.PCLKCR1.bit.EPWM4ENCLK  = 0; // ePWM4

    SysCtrlRegs.PCLKCR0.bit.TBCLKSYNC   = 0; // Enable TBCLK
    EDIS;

	// Copy time critical code and Flash setup code to RAM
	// This includes the following ISR functions: epwm1_timer_isr(), epwm2_timer_isr()
	// epwm3_timer_isr and and InitFlash();
	// The  RamfuncsLoadStart, RamfuncsLoadEnd, and RamfuncsRunStart
	// symbols are created by the linker. Refer to the F28335_qkn.cmd file.
    MemCopy(&RamfuncsLoadStart, &RamfuncsLoadEnd, &RamfuncsRunStart);
	// Call Flash Initialization to setup flash waitstates
	InitFlash();// This function must reside in RAM

	MemCopy(&RamconstLoadStart, &RamconstLoadEnd, &RamconstRunStart);

    // initialize the CPU Timer used for system clock tick
    CpuTimer0Regs.PRD.all      = 150000000;
    CpuTimer0Regs.TPR.all      = 0;   // Initialize pre-scaler to div by 1
    CpuTimer0Regs.TPRH.all     = 0;
    CpuTimer0Regs.TCR.bit.TSS  = 1;   // 1 = Stop timer initially
    CpuTimer0Regs.TCR.bit.TRB  = 1;   // 1 = reload timer
    CpuTimer0Regs.TCR.bit.SOFT = 0;
    CpuTimer0Regs.TCR.bit.FREE = 0;   // 0 = Timer Free Run Disabled
    CpuTimer0Regs.TCR.bit.TIE  = 1;   // 1 = Enable Timer Interrupt
    CpuTimer0Regs.TCR.bit.TSS  = 0;   // 0 = Start timer
    IER |= M_INT1;

    // Enable PIE: Group 1 interrupt 7 which is connected to CPU-Timer 0:
    PieCtrlRegs.PIEIER1.bit.INTx7 = 1;

    ERTM;   // Enable Global realtime interrupt DBGM
    __enable_interrupts();
    DEBUG_LED_off();
}
