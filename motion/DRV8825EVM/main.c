#define MOVE_STEPS 5000.f
#define SMAX_SEED 500.0f
#define AMAX_SEED 1000.0f
#define JMAX 5000.0f

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

#define N_STEPPER 4

/*..........................................................................*/
int main() {
	int i;
	hilo16_union timer_tick;
	uint32_t tick_start[N_STEPPER], tick_max[N_STEPPER], step[N_STEPPER];
	float Jmax[N_STEPPER], Amax[N_STEPPER], Smax[N_STEPPER], DP[N_STEPPER]
	    , T0[N_STEPPER], T1[N_STEPPER], T3[N_STEPPER]
	    , T01[N_STEPPER], T02[N_STEPPER], T03[N_STEPPER], T04[N_STEPPER]
	    , T05[N_STEPPER], T06[N_STEPPER]
		, T0P2T1[N_STEPPER], T0xT0_d3[N_STEPPER], T0xT0_d3_P_T01xT1[N_STEPPER]
		, Amax_d2[N_STEPPER], Jmax_d6[N_STEPPER], Amax_d2xT02xT01[N_STEPPER]
		, Amax_d2xT02xT01_T0xT0_d3_PSmax_xT3PT0[N_STEPPER];
	uint32_t Dstep[N_STEPPER];
	uint8_t moving[N_STEPPER], direction[N_STEPPER];

    BSP_init();      /* initialize the board */

    for(i=0; i < N_STEPPER; ++i) {
    	moving[i] = FALSE; //start at rest
    	direction[i] = FALSE;
    }

    DECAY_set(TRUE);
    Stepper_on();
    uStep8_on();

    while(1) { // Infinite loop to process message and generate trajectory
    	//pretend I received a move command here.  The command can be:
    	// * STOP
    	// * MOVE(direction, ustep, DP, Smax, Amax, Jmax)
        for(i=0; i < N_STEPPER; ++i) {
			float T_traj, dP;
			uint32_t step_r, tick_traj, t1, tick_elapsed;

			if(moving[i]) {
				// if STOP command => change times according to the STOP action
				Clock_read(); t1 = timer_tick.u32;//start stopwatch <----------
				/* Clock_read(); */	tick_traj = t1 - tick_start[i];
				T_traj = //((float)i + 0.5f) * (4.0f/16000.0f);//if debug periodic
						tick_traj * CLOCK_TICK_TO_FLOAT;

				if(T_traj > T06[i]) {
					//APPROACHING.  We had better be only 1 step from DP,
					//or else we will experience sudden acceleration and jerk
					assert((Dstep[i] - step[i]) < 2);
					if(step[i] == Dstep[i]) {
						moving[i] = FALSE;
						continue;//don't need to emit new pulse
					} else dP = DP[i];
				} else if(T_traj > T05[i]) {//DEC_JDEC, or DEC_J-: 2483 clocks on MSP430
					// s [DP -Jmax/6 (T06 - Ttraj)^3]
					float t = T06[i] - T_traj;
					dP = DP[i] - Jmax_d6[i] * t * t * t;
				} else if(T_traj > T04[i]) {//DEC_J0 Takes 2762 clocks
					float t = T_traj - T04[i];
					dP = Amax_d2xT02xT01_T0xT0_d3_PSmax_xT3PT0[i]
	                   - Amax_d2[i] * (T0[i] + t) * t + Smax[i] * t;
				} else if(T_traj > T03[i]) {//DEC_JACC, or DEC_J+ 3236 clocks
					float t = T_traj - T03[i];
					dP = Amax_d2xT02xT01[i] + Smax[i] * (T3[i] + t)
	                   - Jmax_d6[i] * t * t * t;
				} else if(T_traj > T02[i]) {//COASTING takes 1659 clocks
					float t = T_traj - T02[i];
					dP = Amax_d2xT02xT01[i] + Smax[i] * t;
				} else if(T_traj > T01[i]) {//ACC_JDEC, or ACC_J-: 3774 clocks
					float t = T_traj - T01[i];
					dP = Amax_d2[i] * (T0xT0_d3_P_T01xT1[i] + (T0P2T1[i] + t) * t)
					   - Jmax_d6[i] * t * t * t;
				} else if(T_traj > T0[i]) {//ACC_J0: 2558 clocks
					float t = T_traj - T0[i];
					dP = Amax_d2[i] * (T0xT0_d3[i] + (T0[i] + t) * t);
				} else { //ACC_JINC, or ACC_J+: 1809 clocks
					float t = T_traj;
					dP = Jmax_d6[i] * t * t * t;
				}

				step_r = (uint32_t)(dP + 0.5f); // step_r = ROUND(dP, 0)
				if(step_r > step[i]) { //emit a pulse
					if(i == 0) {
						STP_on();
						LED_on();
                        //#define MIN_PULSE 1
						//_delay_cycles(SYS_TICK * MIN_PULSE)/1000000);
						LED_off();
						STP_off();
					}
					++step[i];
				}
				Clock_read();//stop stopwatch ---------------------------------------->
				tick_elapsed = timer_tick.u32 - t1;
				//assert(tick_elapsed < 0x10000);
				if(tick_elapsed > tick_max[i]) {
					tick_max[i] = tick_elapsed;
				}
			} else { // at rest, so can start a new move
        		// TODO: parse from command
				direction[i] = !direction[i];
				if(i == 0) DIRECTION(direction[i]);
				DP[i] = MOVE_STEPS;
				Smax[i] = SMAX_SEED;//828.426f;
				Amax[i] = AMAX_SEED;//910.177f;
				Jmax[i] = JMAX;
				do {
					float Smax_new = Smax[i];
					T0[i] = Amax[i] / Jmax[i]; //0.910f;
					T1[i] = Smax[i] / Amax[i] - T0[i];//0.0f;
					T3[i] = DP[i] / Smax[i] - (2.0f * T0[i] + T1[i]); //0.594f;

					if(T3[i] < 0.0f) {
						Smax_new = (0.99999f/2.0f)
							 * ((sqrt(Amax[i]
                                      * (Amax[i] * Amax[i] * Amax[i]
									     + 4.0f * DP[i] * Jmax[i] * Jmax[i]))
								 - Amax[i] * Amax[i])
								/ Jmax[i]);
						Smax[i] = Smax_new;
					}
					if(T1[i] < 0.0f)
						Amax[i] = 0.99999f * sqrt(Smax_new * Jmax[i]);
				} while(T1[i] < 0.0f || T3[i] < 0.0f);

				T01[i] = T0[i] + T1[i];
				T02[i] = T01[i] + T0[i];
				T03[i] = T02[i] + T3[i];
				T04[i] = T03[i] + T0[i];
				T05[i] = T04[i] + T1[i];
				T06[i] = T05[i] + T0[i];
				T0P2T1[i] = T01[i] + T1[i];
				T0xT0_d3[i] = 0.333333333f * T0[i] * T0[i];
				T0xT0_d3_P_T01xT1[i] = T0xT0_d3[i] + T01[i] * T1[i];
				Amax_d2[i] = 0.5f * Amax[i];
				Jmax_d6[i] = 0.166666667f * Jmax[i];
				Amax_d2xT02xT01[i] = Amax_d2[i] * T02[i] * T01[i];
				Amax_d2xT02xT01_T0xT0_d3_PSmax_xT3PT0[i] = Amax_d2xT02xT01[i]
					- Amax_d2[i] * T0xT0_d3[i] + Smax[i] * (T3[i]+T0[i]);
				Dstep[i] = (uint32_t)(DP[i] + 0.5f);

				tick_max[i] = 0;
				timer_tick.u16[1] = 0;//reset the trajectory clock
				Clock_read(); tick_start[i] = timer_tick.u32;//begin new traj
				step[i] = 0;
				moving[i] = TRUE;
        	}
		}
    }

    //assert(0);//production code shouldn't get here!
}
