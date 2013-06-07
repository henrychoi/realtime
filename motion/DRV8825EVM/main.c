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

#define USE_IEEE754
#ifdef USE_IEEE754
#define MOVE_STEPS 5000.f
#define SMAX_SEED 2000.0f
#define AMAX_SEED 1000.0f
#define JMAX 5000.0f

int main() {
	hilo16_union timer_tick;
	uint32_t tick_start, tick_max, step;
	float Jmax, Amax, Smax, DP
	    , T0, T1, T3
	    , T01, T02, T03, T04
	    , T05, T06
		, T0P2T1, T0xT0_d3, T0xT0_d3_P_T01xT1
		, Amax_d2, Jmax_d6, Amax_d2xT02xT01
		, Amax_d2xT02xT01_T0xT0_d3_PSmax_xT3PT0;
	uint32_t Dstep;
	uint8_t moving, direction;

    BSP_init();      /* initialize the board */

	moving = FALSE; //start at rest
	direction = FALSE;

    uStep32_on();
    DECAY_set(FALSE);
    Stepper_on();

    while(1) { // Infinite loop to process message and generate trajectory
    	//pretend I received a move command here.  The command can be:
    	// * STOP
    	// * MOVE(direction, ustep, DP, Smax, Amax, Jmax)
		float T_traj, dP;
		uint32_t step_r, tick_traj, t1, tick_elapsed;

		if(moving) {
			// if STOP command => change times according to the STOP action
			Clock_read(); t1 = timer_tick.u32;//start stopwatch <----------
			/* Clock_read(); */	tick_traj = t1 - tick_start;
			T_traj = //((float)i + 0.5f) * (4.0f/16000.0f);//if debug periodic
					tick_traj * CLOCK_TICK_TO_FLOAT;

			if(T_traj > T06) {
				//APPROACHING.  We had better be only 1 step from DP,
				//or else we will experience sudden acceleration and jerk
				assert((Dstep - step) < 2);
				if(step == Dstep) {
					moving = FALSE;
					goto new_move;
				} else dP = DP;
			} else if(T_traj > T05) {//DEC_JDEC, or DEC_J-: 2483 clocks on MSP430
				// s [DP -Jmax/6 (T06 - Ttraj)^3]
				float t = T06 - T_traj;
				dP = DP - Jmax_d6 * t * t * t;
			} else if(T_traj > T04) {//DEC_J0 Takes 2762 clocks
				float t = T_traj - T04;
				dP = Amax_d2xT02xT01_T0xT0_d3_PSmax_xT3PT0
				   - Amax_d2 * (T0 + t) * t + Smax * t;
			} else if(T_traj > T03) {//DEC_JACC, or DEC_J+ 3236 clocks
				float t = T_traj - T03;
				dP = Amax_d2xT02xT01 + Smax * (T3 + t)
				   - Jmax_d6 * t * t * t;
			} else if(T_traj > T02) {//COASTING takes 1659 clocks
				float t = T_traj - T02;
				dP = Amax_d2xT02xT01 + Smax * t;
			} else if(T_traj > T01) {//ACC_JDEC, or ACC_J-: 3774 clocks
				float t = T_traj - T01;
				dP = Amax_d2 * (T0xT0_d3_P_T01xT1 + (T0P2T1 + t) * t)
				   - Jmax_d6 * t * t * t;
			} else if(T_traj > T0) {//ACC_J0: 2558 clocks
				float t = T_traj - T0;
				dP = Amax_d2 * (T0xT0_d3 + (T0 + t) * t);
			} else { //ACC_JINC, or ACC_J+: 1809 clocks
				float t = T_traj;
				dP = Jmax_d6 * t * t * t;
			}

			step_r = (uint32_t)(dP + 0.5f); // step_r = ROUND(dP, 0)
			if(step_r > step) { //emit a pulse
				STP_on();
				LED_on();
				//#define MIN_PULSE 1
				//_delay_cycles(SYS_TICK * MIN_PULSE)/1000000);
				LED_off();
				STP_off();
				++step;
			}
			Clock_read();//stop stopwatch ---------------------------------------->
			tick_elapsed = timer_tick.u32 - t1;
			//assert(tick_elapsed < 0x10000);
			if(tick_elapsed > tick_max) {
				tick_max = tick_elapsed;
			}
		} else { // at rest, so can start a new move
new_move:
			direction = !direction;
			DIRECTION(direction);
			DP = MOVE_STEPS;
			Smax = SMAX_SEED;//828.426f;
			Amax = AMAX_SEED;//910.177f;
			Jmax = JMAX;
			do {
				float Smax_new = Smax;
				T0 = Amax / Jmax; //0.910f;
				T1 = Smax / Amax - T0;//0.0f;
				T3 = DP / Smax - (2.0f * T0 + T1); //0.594f;

				if(T3 < 0.0f) {
					Smax_new = (0.99999f/2.0f)
						 * ((sqrt(Amax
								  * (Amax * Amax * Amax
									 + 4.0f * DP * Jmax * Jmax))
							 - Amax * Amax)
							/ Jmax);
					Smax = Smax_new;
				}
				if(T1 < 0.0f)
					Amax = 0.99999f * sqrt(Smax_new * Jmax);
			} while(T1 < 0.0f || T3 < 0.0f);
			T01 = T0 + T1;
			T02 = T01 + T0;
			T03 = T02 + T3;
			T04 = T03 + T0;
			T05 = T04 + T1;
			T06 = T05 + T0;
			T0P2T1 = T01 + T1;
			T0xT0_d3 = 0.333333333f * T0 * T0;
			T0xT0_d3_P_T01xT1 = T0xT0_d3 + T01 * T1;
			Amax_d2 = 0.5f * Amax;
			Jmax_d6 = 0.166666667f * Jmax;
			Amax_d2xT02xT01 = Amax_d2 * T02 * T01;
			Amax_d2xT02xT01_T0xT0_d3_PSmax_xT3PT0 = Amax_d2xT02xT01
				- Amax_d2 * T0xT0_d3 + Smax * (T3+T0);
			Dstep = (uint32_t)(DP + 0.5f);

			tick_max = 0;
			timer_tick.u16[1] = 0;//reset the trajectory clock
			Clock_read(); tick_start = timer_tick.u32;//begin new traj
			step = 0;
			moving = TRUE;
		}
    }

    //assert(0);//production code shouldn't get here!
}
#else //Use Q number

#define Q 12
#define Q_HALF (1 << (Q-1))
#define Q12_5div3 6827
#define Q12_1div3 1365
#define Q12_1div6  683

#define MOVE_STEPS 5000U
#define SMAX 2000U
#define AMAX 1000U
#define JMAX 5000U

typedef uint16_t Q_t;
typedef uint32_t QSq_t;
QSq_t Qtemp_;

//#define DEBUG
#ifdef DEBUG

Q_t Qmult(Q_t a, Q_t b) {
	Qtemp_ = a;
	Qtemp_ *= b;
	Qtemp_ += Q_HALF;
	return (Q_t)(Qtemp_>> Q);
}
Q_t Qdiv(Q_t a, Q_t b) {
	Qtemp_ = a;
	Qtemp_ <<= Q;
	Qtemp_ += b/2;
	return (Q_t)(Qtemp_/b);
}
#else
#define Qmult(a, b) (Qtemp_ = (a), Qtemp_ *= (b), Qtemp_ += Q_HALF, Qtemp_>> Q)
#define Qdiv(a, b) (Qtemp_ = (a), Qtemp_ <<= Q, Qtemp_ += (b)/2, Qtemp_/(b))
#endif

int main() {
	hilo16_union timer_tick;
	uint32_t tick_start, tick_max;;
	Q_t step, Jmax, Amax, Smax//, DP
	    , T0, T1, T3
	    , T01, T02, T03, T04
	    , T05, T06
		, T0P2T1, T0xT0_d3, T0xT0_d3_P_T01xT1
		, Amax_d2, Jmax_d6, Amax_d2xT02xT01
		, Amax_d2xT02xT01_T0xT0_d3_PSmax_xT3PT0
		, Amax_d2xT0x5T0_d3_P2T1_Psmax_xT3PT01
		, Smax_Amax_d2_xT0P2T1;
	Q_t Dstep;
	uint8_t moving, direction;

    BSP_init();      /* initialize the board */

	moving = FALSE; //start at rest
	direction = FALSE;

    uStep_off();//uStep8_on();
    DECAY_set(TRUE);
    DAC12_0DAT = 0x200;
    Stepper_on();

    while(TRUE) { // Infinite loop to process message and generate trajectory
    	//pretend I received a move command here.  The command can be:
    	// * STOP
    	// * MOVE(direction, ustep, DP, Smax, Amax, Jmax)
    	Q_t T_traj, dP, step_r;
    	uint32_t tick_traj, t1, tick_elapsed;

		if(moving) {
			// if STOP command => change times according to the STOP action
			Clock_read(); t1 = timer_tick.u32;//start stopwatch <----------
			/* Clock_read(); */	tick_traj = t1 - tick_start;
			T_traj = tick_traj * CLOCK_TICK_TO_FLOAT;

			if(T_traj > T06) {
				//APPROACHING.  We had better be only 1 step from DP,
				//or else we will experience sudden acceleration and jerk
				assert((Dstep - step) < 2);
				if(step == Dstep) {
					moving = FALSE;//done with move
					goto new_move;
				} else dP = Dstep << Q;
			} else if(T_traj > T05) {//DEC_JDEC, or DEC_J-: 2483 clocks on MSP430
				Q_t t = T_traj - T05, t_sq = Qmult(t, t);
				dP = (Amax_d2xT0x5T0_d3_P2T1_Psmax_xT3PT01
                      + Qmult(Smax_Amax_d2_xT0P2T1, t) + Jmax_d6 * t * t_sq)
                   - Amax_d2 * t_sq;
			} else if(T_traj > T04) {//DEC_J0 Takes 2762 clocks
				Q_t t = T_traj - T04;
				dP = (Amax_d2xT02xT01_T0xT0_d3_PSmax_xT3PT0 + Qmult(Smax, t))
				   - Amax_d2 * (T0 + t) * t;
			} else if(T_traj > T03) {//DEC_JACC, or DEC_J+ 3236 clocks
				Q_t t = T_traj - T03;
				dP = (Amax_d2xT02xT01 + Qmult(Smax, T3 + t))
				   - Qmult(Qmult(Qmult(Jmax_d6, t), t), t);
			} else if(T_traj > T02) {//COASTING takes 1659 clocks
				Q_t t = T_traj - T02;
				dP = Amax_d2xT02xT01 + Qmult(Smax, t);
			} else if(T_traj > T01) {//ACC_JDEC, or ACC_J-: 3774 clocks
				Q_t t = T_traj - T01;
				dP = Qmult(Amax_d2, (T0xT0_d3_P_T01xT1 + Qmult(T0P2T1 + t, t)))
				   - Qmult(Qmult(Qmult(Jmax_d6, t), t), t);
			} else if(T_traj > T0) {//ACC_J0: 2558 clocks
				Q_t t = T_traj - T0;
				dP = Qmult(Amax_d2, (T0xT0_d3 + Qmult(T0 + t, t)));
			} else { //ACC_JINC, or ACC_J+: 1809 clocks
				Q_t t = T_traj;
				dP = Qmult(Qmult(Qmult(Jmax_d6, t), t), t);
			}

			step_r = (Q_t)((dP + Q_HALF) >> Q);//round it
			if(step_r > step) { //emit a pulse
				STP_on();
				LED_on();
				//#define MIN_PULSE 1
				//_delay_cycles(SYS_TICK * MIN_PULSE)/1000000);
				LED_off();
				STP_off();
				++step;
			}
			Clock_read();//stop stopwatch ---------------------------------------->
			tick_elapsed = timer_tick.u32 - t1;
			//assert(tick_elapsed < 0x10000);
			if(tick_elapsed > tick_max) {
				tick_max = tick_elapsed;
			}
		} else { // at rest, so can start a new move
new_move:   direction = !direction;
			DIRECTION(direction);
			Dstep = MOVE_STEPS;
			//DP = MOVE_STEPS << Q;
			Smax = (SMAX << Q);
			Amax = (AMAX << Q);
			Jmax = (JMAX << Q);
			T0 = Qdiv(Amax, Jmax);
			T1 = Qdiv(Smax, Amax) - T0;
			T3 = Qdiv(Dstep << Q, Smax) - 2*T0 + T1;
			T01 = T0 + T1;
			T02 = T01 + T0;
			T03 = T02 + T3;
			T04 = T03 + T0;
			T05 = T04 + T1;
			T06 = T05 + T0;
			T0P2T1 = T01 + T1;
			T0xT0_d3 = Qmult(Q12_1div3, Qmult(T0, T0));
			T0xT0_d3_P_T01xT1 = T0xT0_d3 + Qmult(T01, T1);
			Amax_d2 = Amax / 2;
			Jmax_d6 = Qmult(Q12_1div6, Jmax);
			Amax_d2xT02xT01 = Qmult(Qmult(Amax_d2, T02), T01);
			Amax_d2xT02xT01_T0xT0_d3_PSmax_xT3PT0 = Amax_d2xT02xT01
				- Qmult(Amax_d2, T0xT0_d3) + Qmult(Smax, (T3+T0));
			Amax_d2xT0x5T0_d3_P2T1_Psmax_xT3PT01 =
				Qmult(Qmult(Amax_d2, T0), (Qmult(Q12_5div3, T0) + 2 * T1))
				+ Qmult(Smax, T01 + T3);
			Smax_Amax_d2_xT0P2T1 = Smax - Qmult(Amax_d2, T0P2T1);
			tick_max = 0;
			timer_tick.u16[1] = 0;//reset the trajectory clock
			Clock_read(); tick_start = timer_tick.u32;//begin new traj
			step = 0;
			moving = TRUE;
		}
    }

    //assert(0);//production code shouldn't get here!
}
#endif
