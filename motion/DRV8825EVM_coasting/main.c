#define SMAX_SEED 2000.0f
#define DRIVE_TIME 10.0f

#include "bsp.h"        /* Board Support Package (BSP) */

typedef union hilo16 {
	uint32_t u32;
	uint16_t u16[2];
} hilo16_union;

#define Clock_read() do { \
	uint16_t _tick_ = TAB; \
	if(_tick_ < timer_tick.u16[0]) ++timer_tick.u16[1]; \
    timer_tick.u16[0] = _tick_; \
} while(0)

uint8_t moving, direction;
#ifdef USE_ALGO
hilo16_union timer_tick;
uint32_t tick_start, step;
float Smax, T06;
#endif

/*..........................................................................*/
#ifdef USE_TIMERB
#pragma vector = TIMERB0_VECTOR
__interrupt void timerB_ISR(void) {
}
#endif

/*..........................................................................*/
int main() {
    BSP_init();      /* initialize the board */

    moving = FALSE; //start at rest
    direction = FALSE;
    //uStep_off();
    uStep8_on();
    DECAY_set(TRUE);
    DAC12_0DAT = 0x400;
    Stepper_on();
    while(TRUE) {
//#define USE_ALGO
#ifdef USE_ALGO
		if(moving) {
			float T_traj, dP;
			uint32_t step_r, tick_traj;
			// if STOP command => change times according to the STOP action
			Clock_read(); tick_traj = timer_tick.u32 - tick_start;
			T_traj = //((float)i + 0.5f) * (4.0f/16000.0f);//if debug periodic
					tick_traj * CLOCK_TICK_TO_FLOAT;

			if(T_traj > T06) {
				//APPROACHING.  We had better be only 1 step from DP,
				//or else we will experience sudden acceleration and jerk
				moving = FALSE;
				goto new_move;//don't need to emit new pulse
			} else {
				dP = Smax * T_traj;
			}

			step_r = (uint32_t)(dP + 0.5f); // step_r = ROUND(dP, 0)
			if(step_r > step) { //emit a pulse
				//STP_toggle();
				STP_on();
				LED_on();
				//#define MIN_PULSE_USEC 1
				//_delay_cycles((SYS_TICK * MIN_PULSE_USEC)/1000000);
				//_delay_cycles(1);
				LED_off();
				STP_off();
				++step;
				//_delay_cycles(1000);
			}
			//assert(tick_elapsed < 0x10000);
		} else { // at rest, so can start a new move
	new_move:
			// TODO: parse from command
			direction = !direction;
			DIRECTION(direction);
			Smax = SMAX_SEED;
			T06 = DRIVE_TIME;

			timer_tick.u16[1] = 0;//reset the stop watch
			Clock_read(); tick_start = timer_tick.u32;//begin new traj
			step = 0;
			moving = TRUE;
		}
#else
		STP_on();
    	LED_on();
    	_delay_cycles(10);
    	LED_off();
    	STP_off();
    	_delay_cycles(10000);
#endif
    }
}
