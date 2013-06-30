#ifndef bsp_h
#define bsp_h
#include "DSP2802x_Device.h"                   /* defines the C28027 device */

#define BSP_TICKS_PER_SEC 10U
/*----------------------------------------------------------------------------
*  Target device (in DSP2802x_Device.h) determines CPU frequency
*      (for examples) - either 60 MHz (for 28026 and 28027) or 40 MHz
*      (for 28025, 28024, 28023, and 28022).
*      User does not have to change anything here.
*---------------------------------------------------------------------------*/
#if (DSP28_28026 || DSP28_28027) /* DSP28_28026 || DSP28_28027 devices only */
  #define CPU_FRQ_HZ    60000000
#else
  #define CPU_FRQ_HZ    40000000
#endif

void BSP_init(void);

#define LD_on()
#define LD_off()
#define LD_toggle()

#endif                                                             /* bsp_h */
