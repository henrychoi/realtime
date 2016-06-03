#include "app_util_platform.h"
#include <string.h>
#include "qpn.h"
#include "qs_trace.h"
#include "appsig.h"
#include "nrf_drv_spi.h"

Q_DEFINE_THIS_FILE

static const nrf_drv_spi_t spi = NRF_DRV_SPI_INSTANCE(SPI0_INSTANCE_INDEX);

struct Pixel { uint8_t brightness, b, g, r; } __attribute((packed));

#define N_L_LED 18
#define N_T_LED 8
#define N_R_LED N_L_LED
#define N_LED 48
#define N_B_LED (N_LED - N_L_LED - N_T_LED - N_R_LED) // = 4
#define N_END_CLK      (N_LED     >> 1) //# end frame CLK = N_LED / 2
#define N_END_CLK_BYTE (N_END_CLK >> 3)
struct Apa102Data {
	uint8_t start[4]; //all 0
	struct Pixel pixels[N_LED];
	uint8_t end[N_END_CLK_BYTE];
};

/* Active object class -----------------------------------------------------*/
typedef struct Apa102Array {
/* protected: */
    QActive super;

/* private: */
    //uint8_t cursor;
    uint8_t wavefront;
    struct Apa102Data buf[1];//double buffer?
} Array;

/* Local objects -----------------------------------------------------------*/
Array l_Array; /* the single instance of the Table active object */

/* Global-scope objects ----------------------------------------------------*/
QActive * const AO_array = &l_Array.super; /* "opaque" AO pointer */

static QState Array_normal(Array* const me);

static QState Array_normal(Array* const me) {
	switch(Q_SIG(me)) {
	case Q_ENTRY_SIG: {
		//QStateHandler target;
	    QActive_armX(&me->super, /* timer instance = */ 0U
	    		, 1, /* periodic = */ 1U);
	    me->wavefront = 0;

	    for (struct Pixel* pixel = me->buf[0].pixels;
	    		pixel < &me->buf[0].pixels[N_LED];
	    		++pixel) {
	    	pixel->brightness = 7<<5 | 0; //all dark
	    }
		return Q_HANDLED();//Q_TRAN(target);
	}
	case Q_TIMEOUT_SIG: {
        BSP_setTP();
		// Display the current screen
        Q_ASSERT(nrf_drv_spi_transfer(&spi
        		, (uint8_t*)&me->buf[0], sizeof(struct Apa102Data), NULL, 0)
        		== NRF_SUCCESS);
        BSP_clearTP();

        //calculate the next screen
        BSP_setTP();
		//uint8_t blit = !me->cursor;
	    for (uint8_t i=0; i < N_LED; ++i) {
	    	uint8_t distance = (me->wavefront + N_LED - i);
	    	if (distance > N_LED) distance -= N_LED;
	    	if (distance > 10) distance = 10;
	    	struct Pixel* pixel = &me->buf[0].pixels[i];
	    	pixel->brightness = 7<<5 | (10 - distance);
	    }
        BSP_clearTP();

	    if (++me->wavefront >= N_LED) me->wavefront = 0;
		//me->cursor = blit;//flip the ping-pong buffer
	}   return Q_HANDLED();
	//case DISPLAY_DONE_SIG:
	//	return Q_HANDLED();
	default:
		return Q_SUPER(&QHsm_top);
	}
}
#if 0
void spi_event_handler(nrf_drv_spi_evt_t const * p_event) {
    QACTIVE_POST_ISR(AO_array, DISPLAY_DONE_SIG, 0U);
}
#endif

static QState Array_initial(Array* const me) {
    nrf_drv_spi_config_t spi_config =
    		NRF_DRV_SPI_DEFAULT_CONFIG(SPI0_INSTANCE_INDEX);
    spi_config.frequency = NRF_DRV_SPI_FREQ_1M;//APA102 wants 1 MHz nominal
    Q_ASSERT(nrf_drv_spi_init(&spi, &spi_config, NULL//spi_event_handler
    		) == NRF_SUCCESS);
    return Q_TRAN(&Array_normal);
}

void Array_ctor(void) {
    Array* const me = &l_Array;

    QActive_ctor(&me->super, Q_STATE_CAST(&Array_initial));

    memset(me->buf[0].start, 0, 4);
    memset(me->buf[0].pixels, 1, sizeof(me->buf[0].pixels));
    memset(&me->buf[0].end, 0xFF, N_END_CLK_BYTE);//end frames is all 1s
}

