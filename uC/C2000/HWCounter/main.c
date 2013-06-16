#include <DSP2833x_Device.h>

#pragma DATA_SECTION(hw_ctr, "ramconst")
Uint32 hw_ctr;

extern void BSP_init();

int main(void) {
	BSP_init();

	for(;;) {
		hw_ctr = EQep1Regs.QPOSCNT;
	}
}
