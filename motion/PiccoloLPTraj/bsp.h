#ifndef bsp_h
#define bsp_h
#include "DSP2802x_Device.h"                   /* defines the C28027 device */

#define BSP_TICKS_PER_SEC 15000U//see design doc for why this is sufficient
#define TICK2TIME (1.f/BSP_TICKS_PER_SEC)

void BSP_init(void);

#endif                                                             /* bsp_h */
