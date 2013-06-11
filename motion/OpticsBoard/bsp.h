#ifndef bsp_h
#define bsp_h

#include <msp430f1612.h>//<msp430x16x.h>

#define TRUE 1
#define FALSE 0
//Trajectory gen on MSP430F1612 cannot seem to run faster than this rate
#define TIMER_INT_HZ 2000U

#define LED_on()   (P6OUT |= BIT5)
#define LED_off()  (P6OUT &= ~BIT5)
#define LED_toggle() (P6OUT ^= BIT5)

void BSP_init(void);

#endif                                                             /* bsp_h */
