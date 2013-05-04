#include "bsp.h"        /* Board Support Package (BSP) */

typedef union uint32_union {
	uint32_t u32;
	uint16_t u16[2];
} uint32_union;

#define Clock_read() do { \
	uint16_t _tick_ = TAR; \
	if(_tick_ < timer_tick.u16[0]) ++timer_tick.u16[1]; \
    timer_tick.u16[0] = _tick_; \
} while(0)

enum TrapezoidalTrajState { IDLE,
	ACC_JINC, ACC_J0, ACC_JDEC, COASTING, DEC_JINC, DEC_J0, DEC_JDEC,
	APPROACHING
};

#define N_STEPPER 4

/*..........................................................................*/
int main() {
	int i;
	uint32_union timer_tick = {0};
	uint32_t tick_start, tick_max = 0, step;
	float Jmax = 1000.0f, Amax = 910.177f, Smax = 828.426f, DP = 2000.0f
	    , T0 =  0.910f, T1 = 0.0f, T3 = 0.594f
	    , T01 = T0 + T1
		, T02 = T01 + T0
		, T03 = T02 + T3
		, T04 = T03 + T0
		, T05 = T04 + T1
		, T06 = T05 + T0
		, T0P2T1 = T01 + T1
		, T0xT0_d3 = 0.333333333f * T0 * T0
		, T0xT0_d3_P_T01xT1 = T0xT0_d3 + T01*T1
		, Amax_d2 = 0.5f * Amax
		, Jmax_d6 = 0.166666667f * Jmax
		//, Amax_d2_xT0P2T1 = Amax_d2 * T0P2T1
		, Amax_d2xT02xT01 = Amax_d2 * T02 * T01
		, Amax_d2xT02xT01_T0xT0_d3_PSmax_xT3PT0
			= Amax_d2xT02xT01 - Amax_d2 * T0xT0_d3 + Smax * (T3+T0);
	uint32_t Dstep = (uint32_t)(DP + 0.49999f);
	uint8_t state = IDLE;

    BSP_init();      /* initialize the board */

	Clock_read(); tick_start = timer_tick.u32;
    for(step = 0, i = 0; ; ++i) {
    	// Infinite loop to process message and generate trajectory
    	float T_traj, dP;
    	uint32_t step_r, tick_traj, t1, tick_elapsed;

    	Clock_read(); t1 = timer_tick.u32;//start stopwatch <--------------
    	//Clock_read();
    	tick_traj = t1 - tick_start;
    	T_traj = //((float)i + 0.5f) * (4.0f/16000.0f);
    			tick_traj * CLOCK_TICK_TO_FLOAT;

    	if(T_traj > T06) {//APPROACHING.  We had better be only 1 step from DP,
    		//or else we will experience sudden acceleration and jerk
    		assert((Dstep - step) < 2);
    		if(step >= Dstep) break;
    		dP = DP;
    		state = APPROACHING;
    	} else if(T_traj > T05) {//DEC_JDEC, or DEC_J-: 2483 clocks on MSP430
    		// s [DP -Jmax/6 (T06 - Ttraj)^3]
    		float t = T06 - T_traj;
    		dP = DP - Jmax_d6 * t * t * t;
    		state = DEC_JDEC;
    	} else if(T_traj > T04) {//DEC_J0 Takes 2762 clocks
    		// s Amax/2 [(2 T0 + T1) (T0 + T1) – T0^2/3 - (T0 t + t^2)]
    		// + s Smax (T3 + T0 + t)
    		float t = T_traj - T04;
    		dP = Amax_d2xT02xT01_T0xT0_d3_PSmax_xT3PT0 - Amax_d2 * (T0 + t) * t + Smax * t;
    		state = DEC_J0;
    	} else if(T_traj > T03) {//DEC_JACC, or DEC_J+ 3236 clocks
    		// s Amax/2 (2 T0 + T1) (T0 + T1) + s Smax (T3 + t) – s Jmax t^3/6
    		float t = T_traj - T03;
    		dP = Amax_d2xT02xT01 + Smax * (T3 + t) - Jmax_d6 * t * t * t;
    		state = DEC_JINC;
    	} else if(T_traj > T02) {//COASTING takes 1659 clocks
    		//s Amax/2 (2 T0 + T1) (T0 + T1) + s Smax t
    		float t = T_traj - T02;
    		dP = Amax_d2xT02xT01 + Smax * t;
    		state = COASTING;
    	} else if(T_traj > T01) {//ACC_JDEC, or ACC_J-: 3774 clocks
    		// s Amax/2 [ (T0^2/3 + T0 T1 + T1^2) + (T0 +2 T1) t + t^2] – s Jmax t3/6
    		float t = T_traj - T01;
    		dP = Amax_d2 * (T0xT0_d3_P_T01xT1 + (T0P2T1 + t) * t) - Jmax_d6 * t * t * t;
    		state = ACC_JDEC;
    	} else if(T_traj > T0) {//ACC_J0: 2558 clocks
    		//s Amax (T02/3 + T0 t + t2)/2
    		float t = T_traj - T0;
    		dP = Amax_d2 * (T0xT0_d3 + (T0 + t) * t);
    		state = ACC_J0;
    	} else { //ACC_JINC, or ACC_J+: 1809 clocks
    		//s Jmax × t3/6
    		float t = T_traj;
    		dP = Jmax_d6 * t * t * t;
    		state = ACC_JINC;
    	}

    	step_r = (uint32_t)(dP + 0.49999f); // round it
    	if(step_r > step) { //emit a pulse
    		LED_on();
#define MIN_PULSE_USEC 2 //min pulse width is 1 usec actually, but better safe
    		_delay_cycles((SYS_TICK * MIN_PULSE_USEC)/1000000);
    		// or prepare the next trajectory
    		LED_off();
    		++step;
    	}
    	Clock_read();//stop stopwatch ---------------------------------------->
#ifdef DEBUG_WRAP
    	{
    		uint16_t _tick_ = TAR;
    		if(_tick_ < timer_tick.u16[0]) {
    			++timer_tick.u16[1];
    		}
    		timer_tick.u16[0] = _tick_;
    	}
#endif//DEBUG_WRAP
    	tick_elapsed = timer_tick.u32 - t1;
    	//assert(tick_elapsed < 0x10000);
    	if(tick_elapsed > tick_max) {
    		tick_max = tick_elapsed;
    	}
    }

    assert(0);//production code shouldn't get here!
}
