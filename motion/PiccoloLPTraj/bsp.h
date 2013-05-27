#ifndef bsp_h
#define bsp_h
#include "DSP2802x_Device.h"                   /* defines the C28027 device */

#define BSP_TICKS_PER_SEC   1U

void BSP_init(void);

#define STP_on() GpioDataRegs.GPBCLEAR.bit.GPIO33 = TRUE
#define STP_off() GpioDataRegs.GPBSET.bit.GPIO33 = TRUE
#define uStep_on()
#define uStep_off()
void Stepper_on(uint8_t i);

#define DECAY_set(bFast)

#endif                                                             /* bsp_h */
