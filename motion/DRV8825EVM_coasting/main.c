#define SMAX_SEED 400.0f
#define DRIVE_TIME 10.0f

#include "bsp.h"        /* Board Support Package (BSP) */
#include <math.h>

typedef union hilo16 {
	uint32_t u32;
	uint16_t u16[2];
} hilo16_union;

#define Clock_read() do { \
	uint16_t _tick_ = TAR; \
	if(_tick_ < timer_tick.u16[0]) ++timer_tick.u16[1]; \
    timer_tick.u16[0] = _tick_; \
} while(0)

#define N_STEPPER 1

/*..........................................................................*/
int main() {
	int i;
	hilo16_union timer_tick;
	uint32_t tick_start[N_STEPPER], step[N_STEPPER];
	float Smax[N_STEPPER], T06[N_STEPPER];
	uint8_t moving[N_STEPPER], direction[N_STEPPER];

    BSP_init();      /* initialize the board */

    for(i=0; i < N_STEPPER; ++i) {
    	moving[i] = FALSE; //start at rest
    	direction[i] = FALSE;
    }

    DECAY_set(TRUE);
    Stepper_on();
    //uStep32_on();

    while(1) { // Infinite loop to process message and generate trajectory
    	//pretend I received a move command here.  The command can be:
    	// * STOP
    	// * MOVE(direction, ustep, DP, Smax, Amax, Jmax)
        for(i=0; i < N_STEPPER; ++i) {
			if(moving[i]) {
				float T_traj, dP;
				uint32_t step_r, tick_traj;
				// if STOP command => change times according to the STOP action
				Clock_read(); tick_traj = timer_tick.u32 - tick_start[i];
				T_traj = //((float)i + 0.5f) * (4.0f/16000.0f);//if debug periodic
						tick_traj * CLOCK_TICK_TO_FLOAT;

				if(T_traj > T06[i]) {
					//APPROACHING.  We had better be only 1 step from DP,
					//or else we will experience sudden acceleration and jerk
					moving[i] = FALSE;
					goto new_move;//don't need to emit new pulse
				} else {
					dP = Smax[i] * T_traj;
				}

				step_r = (uint32_t)(dP + 0.5f); // step_r = ROUND(dP, 0)
				if(step_r > step[i]) { //emit a pulse
					if(i == 0) {
						STP_on();
						LED_on();
                        //#define MIN_PULSE_USEC 1
						//_delay_cycles((SYS_TICK * MIN_PULSE_USEC)/1000000);
						LED_off();
						STP_off();
					}
					++step[i];
				}
				//assert(tick_elapsed < 0x10000);
			} else { // at rest, so can start a new move
new_move:
        		// TODO: parse from command
				direction[i] = !direction[i];
				if(i == 0) DIRECTION(direction[i]);
				Smax[i] = SMAX_SEED;
				T06[i] = DRIVE_TIME;

				timer_tick.u16[1] = 0;//reset the stop watch
				Clock_read(); tick_start[i] = timer_tick.u32;//begin new traj
				step[i] = 0;
				moving[i] = TRUE;
        	}
		}
    }

    //assert(0);//production code shouldn't get here!
}
