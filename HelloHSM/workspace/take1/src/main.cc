#include <stdio.h>
#include "xparameters.h"
#include "xil_cache.h"
#include "xintc.h"
#include "xgpio.h"
#include "xtmrctr.h"
//#include "xenv_standalone.h"

#define UART_BAUD 9600

static XIntc intc;//This will be initialized in init_platform()

#define GPIO_CHANNEL 1
static XGpio led8, led5, button5;
volatile u32 button = 0;
volatile bool button_hot = false;

#define TICK_FREQ 1000 // Run the control loop at 1 kHz
#define TIMER_RESET_VAL ((~0 - XPAR_AXI_TIMER_0_CLOCK_FREQ_HZ/TICK_FREQ) + 1)
#define MY_TIMER_ID 0
static XTmrCtr timer;

void PushButtons_ISR(void* p) {
  button = XGpio_DiscreteRead((XGpio*)p, GPIO_CHANNEL);
  button_hot = true;
  XIntc_Acknowledge(&intc
                  , XPAR_MICROBLAZE_0_INTC_PUSH_BUTTONS_5BITS_IP2INTC_IRPT_INTR);
  XGpio_InterruptClear((XGpio*)p, GPIO_CHANNEL);
}
void Timer_ISR(void* p, u8 timerId) { //print(".");
  XGpio_DiscreteWrite(&led8, GPIO_CHANNEL, 1<<0);
  // Do work
  XGpio_DiscreteClear(&led8, GPIO_CHANNEL, 1<<0);
}

int init_platform() {
  int status = XST_SUCCESS;
  print("Begin init_platform\n\r");

  Xil_ICacheEnable();
  Xil_DCacheEnable();

  status = XGpio_Initialize(&led8, XPAR_LEDS_8BITS_DEVICE_ID);
  if(status != XST_SUCCESS) {
      print("XGpio_Initialize(LEDS_8BITS) failed");
      return status;
  }
  XGpio_SetDataDirection(&led8, GPIO_CHANNEL, 0x0);//output

  status = XGpio_Initialize(&led5, XPAR_LEDS_POSITIONS_DEVICE_ID);
  if(status != XST_SUCCESS) {
      print("XGpio_Initialize(LEDS_POSITIONS) failed");
      return status;
  }
  XGpio_SetDataDirection(&led5, GPIO_CHANNEL, 0x0);//output

  // Q: use interrupt for URT?
  // Not necessary for now since I don't read from console

  status = XIntc_Initialize(&intc, XPAR_INTC_0_DEVICE_ID);
  if(status != XST_SUCCESS) {
    print("XIntc_Initialize failed");
    return status;
  }
  microblaze_enable_interrupts();//uBlaze intr

  status = XGpio_Initialize(&button5, XPAR_PUSH_BUTTONS_5BITS_DEVICE_ID);
  if(status != XST_SUCCESS) {
      print("XGpio_Initialize(PUSH_BUTTONS) failed");
      return status;
  }
  // The hardware must be built for dual channels if this function is used
  // with any channel other than 1. If it is not, this function will assert.
  // After this call, I can, if I wish, poll the GPIO with
  // u32 val = XGpio_DiscreteRead(&button5, BUTTON5_CHANNEL)
  XGpio_SetDataDirection(&button5, GPIO_CHANNEL, 0xFFFFFFFF); //out: 0, in: 1

  XGpio_InterruptEnable(&button5, 0xFF);
  // Interrupts enabled through XGpio_InterruptEnable() will not be passed
  // through until the global enable bit is set by this function. This
  // function is designed to allow all interrupts to be
  // enabled easily for exiting a critical section.
  XGpio_InterruptGlobalEnable(&button5);

  status = XIntc_Connect(&intc
              , XPAR_MICROBLAZE_0_INTC_PUSH_BUTTONS_5BITS_IP2INTC_IRPT_INTR
              , PushButtons_ISR, &button5);
  if(status != XST_SUCCESS) {
    print("XIntc_Connect(GPIO_BUTTONS_5) failed");
    return status;
  }
  XIntc_Enable(&intc, XPAR_MICROBLAZE_0_INTC_PUSH_BUTTONS_5BITS_IP2INTC_IRPT_INTR);

  status = XTmrCtr_Initialize(&timer, XPAR_AXI_TIMER_0_DEVICE_ID);
  if(status != XST_SUCCESS) {
    print("XTmrCtr_Initialize failed");
    return status;
  }
  XTmrCtr_SetHandler(&timer, Timer_ISR//called when timer expires
		  , &timer);
  XTmrCtr_SetOptions(&timer, MY_TIMER_ID,
			XTC_INT_MODE_OPTION | XTC_AUTO_RELOAD_OPTION);
  XTmrCtr_SetResetValue(&timer, MY_TIMER_ID, TIMER_RESET_VAL);//count up (default) from this
  status = XIntc_Connect(&intc
              , XPAR_MICROBLAZE_0_INTC_AXI_TIMER_0_INTERRUPT_INTR
              , XTmrCtr_InterruptHandler, &timer);
  if(status != XST_SUCCESS) {
    print("XIntc_Connect(AXI_TIMER_0) failed");
    return status;
  }
  XTmrCtr_Start(&timer, MY_TIMER_ID);//can stop later with XTmrCtr_Stop()

  XIntc_Enable(&intc, XPAR_MICROBLAZE_0_INTC_AXI_TIMER_0_INTERRUPT_INTR);

#if 0
  status = XIntc_SelfTest(&intc);
  if(status != XST_SUCCESS) {
    print("XIntc_SelfTest failed");
    return status;
  }
#endif

  status = XIntc_Start(&intc, XIN_REAL_MODE);
  if(status != XST_SUCCESS) {
    print("XIntc_Start(XIN_REAL_MODE) failed");
    return status;
  }

  print("Finished platform_init\n\r");
  return status;
}
void shutdown_platform() {
  Xil_DCacheDisable();
  Xil_ICacheDisable();
}

int main() {
  if(init_platform() == XST_SUCCESS) {
    for(;;) {
      //Gpio_DiscreteRead(&button5, BUTTON5_CHANNEL);
      if(button_hot) {
        printf("%ld\n", button);
        button_hot = false;
      }
      //asm("nop");
    }
  }
  shutdown_platform();
  return 0;
}
