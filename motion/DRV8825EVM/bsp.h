#ifndef bsp_h
#define bsp_h

#include <msp430f1612.h>//<msp430x16x.h>

typedef unsigned char uint8_t;
typedef unsigned short uint16_t;
typedef unsigned long uint32_t;

void BSP_init(void);
void assert(uint8_t boolval);
#define LED_on()   (P6OUT |= BIT5)
#define LED_off()  (P6OUT &= ~BIT5)
#define SYS_TICK (8 * 1000000)
#define SYS_TICKF (8.0f * 1000000.0f)
#define TIMER_A_CLK_DIV 1.0f //4
#define CLOCK_TICK_TO_FLOAT 0.000000125f//(TIMER_A_CLK_DIV/SYS_TICKF)

#endif                                                             /* bsp_h */

