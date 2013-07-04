#ifndef bsp_h
#define bsp_h

#include <msp430g2231.h>

#define CPU_HZ (1000000U)//Why does it seem to be 6 Mhz? Supposed to be 8 MHz
#define TIMER_CLK_HZ (CPU_HZ/1U)
typedef unsigned char uint8_t;
typedef char int8_t;
typedef unsigned short uint16_t;
typedef short int16_t;
typedef unsigned long uint32_t;
typedef long int32_t;

#define TRUE 1
#define FALSE 0
#define SYSTICK_HZ 100U

#define LED_on()   (P1OUT |= BIT0)
#define LED_off()  (P1OUT &= ~BIT0)
#define LED_toggle() (P1OUT ^= BIT0)

void BSP_init(void);

#endif                                                             /* bsp_h */
