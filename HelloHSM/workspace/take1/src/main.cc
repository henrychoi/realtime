#include <stdio.h>
#include "xparameters.h"
#include "xil_cache.h"
#include "xintc.h"
#include "xgpio.h"
#include "xtmrctr.h"
#include "xenv_standalone.h"

#define UART_BAUD 9600

static XIntc intc;//This will be initialized in init_platform()

#define GPIO_CHANNEL 1
static XGpio led8, led5, button5;
volatile u32 button = 0;

#define TICK_FREQ 1
#define TIMER_RESET_VAL ((~0 - XPAR_AXI_TIMER_0_CLOCK_FREQ_HZ/TICK_FREQ) + 1)
#define MY_TIMER_ID 0
static XTmrCtr timer;

#  define QF_INT_DISABLE microblaze_disable_interrupts
#  define QF_INT_ENABLE  microblaze_enable_interrupts

void PushButtons_ISR(void* p) {
  XGpio_InterruptClear((XGpio*)p, GPIO_CHANNEL);
  // XIntc interrupt handler acknowledges for me; this is unnecessary
  //XIntc_Acknowledge(&intc
  //                , XPAR_MICROBLAZE_0_INTC_PUSH_BUTTONS_5BITS_IP2INTC_IRPT_INTR);
  XIntc_Disable(&intc//prevent infinite loop when I enable the interrupt
		  , XPAR_MICROBLAZE_0_INTC_PUSH_BUTTONS_5BITS_IP2INTC_IRPT_INTR);
  QF_INT_ENABLE();
/*
  if(!button) {
	button = XGpio_DiscreteRead((XGpio*)p, GPIO_CHANNEL);
  }
*/
  QF_INT_DISABLE();
  XIntc_Enable(&intc//enable the button interrupt again
	  , XPAR_MICROBLAZE_0_INTC_PUSH_BUTTONS_5BITS_IP2INTC_IRPT_INTR);
}

u8 timerctr = 0;
void Timer_ISR(void* p, u8 timerId) { //print(".");
  XIntc_Disable(&intc//prevent infinite loop when I enable the interrupt
		  , XPAR_MICROBLAZE_0_INTC_AXI_TIMER_0_INTERRUPT_INTR);
  QF_INT_ENABLE();

  if(++timerctr & 0x1)XGpio_DiscreteWrite(&led5, GPIO_CHANNEL, 1<<0);
  else XGpio_DiscreteClear(&led5, GPIO_CHANNEL, 1<<0);

  QF_INT_DISABLE();
  XIntc_Enable(&intc//enable the timer interrupt again
		  , XPAR_MICROBLAZE_0_INTC_AXI_TIMER_0_INTERRUPT_INTR);
}

int init_platform() {
  int status = XST_SUCCESS;
  print("Begin init\n\r");

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
  //microblaze_enable_interrupts();//uBlaze intr

  status = XGpio_Initialize(&button5, XPAR_PUSH_BUTTONS_5BITS_DEVICE_ID);
  if(status != XST_SUCCESS) {
      print("XGpio_Initialize(PUSH_BUTTONS) failed");
      return status;
  }
  // The hardware must be built for dual channels if this function is used
  // with any channel other than 1. If it is not, this function will assert.
  // After this call, I can, if I wish, poll the GPIO with
  // u32 val = XGpio_DiscreteRead(&button5, BUTTON5_CHANNEL)
  XGpio_SetDataDirection(&button5, GPIO_CHANNEL, ~0); //out: 0, in: 1

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
#if 0
  status = XIntc_SetOptions(&intc,  XIN_SVC_SGL_ISR_OPTION);
  if(status != XST_SUCCESS) {
    print("XIntc_SetOptions(XIN_SVC_SGL_ISR_OPTION) failed");
    return status;
  }
#endif
  //Ack everything before calling ISR, because ISR will enable interrupt
  //intc.CfgPtr->AckBeforeService = ~0;//This is a hidden API
  XIntc_Enable(&intc, XPAR_MICROBLAZE_0_INTC_PUSH_BUTTONS_5BITS_IP2INTC_IRPT_INTR);
  XIntc_Enable(&intc, XPAR_MICROBLAZE_0_INTC_AXI_TIMER_0_INTERRUPT_INTR);

  status = XIntc_Start(&intc, XIN_REAL_MODE);
  if(status != XST_SUCCESS) {
    print("XIntc_Start(XIN_REAL_MODE) failed");
    return status;
  }

  microblaze_enable_interrupts();

  print("Finished init\n\r");
  return status;
}
void shutdown_platform() {
  Xil_DCacheDisable();
  Xil_ICacheDisable();
}

int main() {
  if(init_platform() == XST_SUCCESS) {
    for(;;) {
      QF_INT_DISABLE();
      //Gpio_DiscreteRead(&button5, BUTTON5_CHANNEL);
      if(button) {
		  //printf("%ld", button);
		  button = 0;
		  XIntc_Enable(&intc//enable the button interrupt again
			  , XPAR_MICROBLAZE_0_INTC_PUSH_BUTTONS_5BITS_IP2INTC_IRPT_INTR);
      }
  	  QF_INT_ENABLE();
    }
  }
  shutdown_platform();
  return 0;
}
