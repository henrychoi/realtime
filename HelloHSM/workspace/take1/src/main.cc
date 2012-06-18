#include <stdio.h>
#include "xparameters.h"
//#include "xil_cache.h"
#include "xintc.h"
#include "xgpio.h"
//#include "xenv_standalone.h"

#define UART_BAUD 9600

XIntc intc;//This will be initialized in init_platform()
XGpio button5;

void PushButtons_ISR(void* p) {
  print("*");
  XIntc_Acknowledge((XIntc*)p
                  , XPAR_MICROBLAZE_0_INTC_PUSH_BUTTONS_5BITS_IP2INTC_IRPT_INTR);
  XGpio_InterruptClear(&button5, 0xFF);
}
void Timer_ISR(void* p) {
  print(".");
  XIntc_Acknowledge((XIntc*)p
                  , XPAR_MICROBLAZE_0_INTC_AXI_TIMER_0_INTERRUPT_INTR);
}
int init_platform() {
  int status = XST_SUCCESS;
  microblaze_enable_icache();
  microblaze_enable_dcache();

  // Q: use interrupt for URT?
  status = XGpio_Initialize(&button5, XPAR_PUSH_BUTTONS_5BITS_DEVICE_ID);
  if(status != XST_SUCCESS) {
      print("Gpio_Initialize failed");
      return status;
  }
  // The hardware must be built for dual channels if this function is used
      // with any channel other than 1. If it is not, this function will assert.
  XGpio_SetDataDirection(&button5, 1 // channel
              , 0x0); //output: 0, input: 1
  XGpio_InterruptEnable(&button5, 0xFF);
  u32 mask = XGpio_InterruptGetEnabled(&button5);
  if(mask != 0x1F) {
      printf("GPIO INT mask %ld != 0x1F", mask);
      return status;
  }

  status = XIntc_Initialize(&intc, XPAR_INTC_0_DEVICE_ID);
  if(status != XST_SUCCESS) {
      print("XIntc_Initialize failed");
      return status;
  }

  status = XIntc_Connect(&intc
              , XPAR_MICROBLAZE_0_INTC_AXI_TIMER_0_INTERRUPT_INTR
              , Timer_ISR, &intc);
  if(status != XST_SUCCESS) {
    print("XIntc_Connect(AXI_TIMER_0) failed");
    return status;
  }

  status = XIntc_Connect(&intc
              , XPAR_MICROBLAZE_0_INTC_PUSH_BUTTONS_5BITS_IP2INTC_IRPT_INTR
              , PushButtons_ISR, &intc);
  if(status != XST_SUCCESS) {
    print("XIntc_Connect(GPIO_BUTTONS_5) failed");
    return status;
  }

  // Enable timer and GPIO interrupts in intc
  //XIntc_EnableIntr(XPAR_INTC_0_BASEADDR
  //		, XPAR_AXI_TIMER_0_INTERRUPT_MASK
  //		| XPAR_PUSH_BUTTONS_5BITS_IP2INTC_IRPT_MASK);

  microblaze_enable_interrupts();//uBlaze intr

  status = XIntc_Start(&intc, XIN_REAL_MODE);
  if(status != XST_SUCCESS) {
    print("XIntc_Start(XIN_REAL_MODE) failed");
    return status;
  }

  XIntc_Enable(&intc, XPAR_MICROBLAZE_0_INTC_AXI_TIMER_0_INTERRUPT_INTR);
  XIntc_Enable(&intc, XPAR_MICROBLAZE_0_INTC_PUSH_BUTTONS_5BITS_IP2INTC_IRPT_INTR);

  print("Finished platform_init\n");
  return status;
}
#ifdef CLEANUP
void cleanup_platform() {
  microblaze_disable_dcache();
  microblaze_disable_icache();
}
#endif//CLEANUP

int main() {
  if(init_platform() != XST_SUCCESS) return -1;

  print("Hello StandAlone C++!\n\r");
 noop_loop:
  asm("nop");
  goto noop_loop;
#ifdef CLEANUP
  cleanup_platform();
#endif
  return 0;
}
