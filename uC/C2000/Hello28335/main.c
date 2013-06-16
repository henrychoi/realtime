#include <DSP2833x_Device.h>

//#pragma DATA_SECTION(loop_ctr, "ramconst")
extern void BSP_init();

int main(void) {
	BSP_init();

	for(;;);
}
