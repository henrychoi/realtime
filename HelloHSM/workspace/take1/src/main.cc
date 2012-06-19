#include <stdio.h>
#include "xparameters.h"
#include "xil_cache.h"
#include "xintc.h"
#include "xgpio.h"
//#include "xenv_standalone.h"

#define UART_BAUD 9600

static XIntc intc;//This will be initialized in init_platform()
static XGpio button5;
#define BUTTON5_CHANNEL 1
//static XTmr timer;
static u32 button = 0;

void PushButtons_ISR(void* p) {
  button = XGpio_DiscreteRead((XGpio*)p, BUTTON5_CHANNEL);
  //printf("%ld", val);
  XIntc_Acknowledge(&intc
                  , XPAR_MICROBLAZE_0_INTC_PUSH_BUTTONS_5BITS_IP2INTC_IRPT_INTR);
  XGpio_InterruptClear((XGpio*)p, BUTTON5_CHANNEL);
}
void Timer_ISR(void* p) {
  print(".");
  XIntc_Acknowledge(&intc
                  , XPAR_MICROBLAZE_0_INTC_AXI_TIMER_0_INTERRUPT_INTR);
}
int init_platform() {
  int status = XST_SUCCESS;
  print("Begin init_platform\n\r");

  Xil_ICacheEnable();
  Xil_DCacheEnable();

  // Q: use interrupt for URT?

  status = XIntc_Initialize(&intc, XPAR_INTC_0_DEVICE_ID);
  if(status != XST_SUCCESS) {
    print("XIntc_Initialize failed");
    return status;
  }
  microblaze_enable_interrupts();//uBlaze intr

  status = XGpio_Initialize(&button5, XPAR_PUSH_BUTTONS_5BITS_DEVICE_ID);
  if(status != XST_SUCCESS) {
      print("Gpio_Initialize failed");
      return status;
  }
  // The hardware must be built for dual channels if this function is used
  // with any channel other than 1. If it is not, this function will assert.
  // After this call, I can, if I wish, poll the GPIO with
  // u32 val = XGpio_DiscreteRead(&button5, BUTTON5_CHANNEL)
  XGpio_SetDataDirection(&button5, BUTTON5_CHANNEL, 0xFFFFFFFF); //output: 0, input: 1

  XGpio_InterruptEnable(&button5, 0xFF);
  // Interrupts enabled through XGpio_InterruptEnable() will not be passed
  // through until the global enable bit is set by this function. This
  // function is designed to allow all interrupts (both channels) to be
  // enabled easily for exiting a critical section.
  XGpio_InterruptGlobalEnable(&button5);

#if 0
  u32 mask = XGpio_InterruptGetEnabled(&button5);
  if(mask != 0x1F) {
    printf("GPIO INT mask %ld != 0x1F", mask);
    return -mask;
  }
#endif

  status = XIntc_Connect(&intc
              , XPAR_MICROBLAZE_0_INTC_PUSH_BUTTONS_5BITS_IP2INTC_IRPT_INTR
              , PushButtons_ISR, &button5);
  if(status != XST_SUCCESS) {
    print("XIntc_Connect(GPIO_BUTTONS_5) failed");
    return status;
  }
  XIntc_Enable(&intc, XPAR_MICROBLAZE_0_INTC_PUSH_BUTTONS_5BITS_IP2INTC_IRPT_INTR);

#if 0
  status = XIntc_Connect(&intc
              , XPAR_MICROBLAZE_0_INTC_AXI_TIMER_0_INTERRUPT_INTR
              , Timer_ISR, &timer);
  if(status != XST_SUCCESS) {
    print("XIntc_Connect(AXI_TIMER_0) failed");
    return status;
  }
  XIntc_Enable(&intc, XPAR_MICROBLAZE_0_INTC_AXI_TIMER_0_INTERRUPT_INTR);
#endif
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
void cleanup_platform() {
  Xil_DCacheDisable();
  Xil_ICacheDisable();
}

int main() {
  if(init_platform() == XST_SUCCESS) {
    for(;;) {
      if(button) {
        printf("%ld", button);
        button = 0;
      }
      asm("nop");
    }
  }
  cleanup_platform();
  return 0;
}
