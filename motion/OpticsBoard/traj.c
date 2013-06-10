#define MOVE_STEPS 10000.f
//Conservatively, the maximum step/s must be 1% less than the timer interrupt
//freq to avoid falling behind by more than 1 clock due to floating point
//quantization error
#define SMAX_SEED  1990.0f
#define AMAX_SEED  1000.0f
#define JMAX      10000.0f

#include "qpn_port.h"
#include "bsp.h"
#include "traj.h"

Q_DEFINE_THIS_FILE

typedef struct TrajTag {
/* protected: */
    QActive super;//must be the first element of the struct for inheritance

/* private: */
    uint8_t direction;
    uint32_t tickInState//strictly monotonically increasing, within a state
           , step//Where I am
           , Dstep; //Where I want to get to at the end of the move
    float t
    	, Jmax, Smax, Amax, DP, Amax_d2, Jmax_d6
    	, T0, T1, T3, T01, T02//, T03, T04, T05, T06
    	, T0P2T1, T0xT0_d3, T0xT0_d3_P_T01xT1
    	, Amax_d2xT02xT01, Amax_d2xT02xT01_T0xT0_d3_PSmax_xT3PT0
    	, Smax_Amax_d2_xT0P2T1, Amax_d2xT0x5T0_d3_P2T1_PSmax_xT3PT01;
// public:
} Traj;

//protected: //necessary forward declaration
static QState Traj_idle(Traj* const me);

//Global objects are placed in DRAML0 block.  See linker cmd file for headroom
Traj AO_traj;

#define STP_toggle() (P4OUT ^= BIT3)
#define STP_on()     (P4OUT |= BIT3)
#define STP_off()    (P4OUT &= ~BIT3)

#define Stepper_on()   (P4OUT |= (BIT6 | BIT7))
#define Stepper_off()  (P4OUT &= ~(BIT6 | BIT7))

#define DIRECTION(bDir) if(bDir) P4OUT |= BIT4; else P4OUT &= ~BIT4

#define MD0PIN BIT3
#define MD1PIN BIT1
#define MD2PIN BIT0
#define uStep_off()   (P5OUT &= ~(MD2PIN + MD2PIN + MD2PIN))
#define uStep2_on()   (P5OUT |= (MD0PIN))
#define uStep4_on()   (P5OUT |= (MD1PIN))
#define uStep8_on()   (P5OUT |= (MD1PIN + MD0PIN))
#define uStep16_on()  (P5OUT |= (MD2PIN))
#define uStep32_on()  (P5OUT |= (MD2PIN + MD1PIN + MD0PIN))

#define DECAY_set(bFast)  if(bFast) P4OUT |= BIT1; else P4OUT &= ~BIT1

void Traj_fullfill_dP(Traj* const me, float dP) {
	uint32_t step_r = (uint32_t)(dP + 0.5f)// step_r = ROUND(dP, 0)
	       , step_diff = step_r - me->step;
	switch(step_diff) {
	case 0:
		QActive_arm(&me->super, 1);//rearm timer to avoid logical deadlock
		break;
	case 1: //behind by 1 => emit ONE pulse
		STP_on();
		//LED_on();
		QActive_arm(&me->super, 1);//rearm timer to avoid logical deadlock
    	//_delay_cycles(10);
    	//LED_off();
    	STP_off();
    	++me->step;
		break;
	default: Q_ERROR(); break;//fell behind by more than 1 count
	}
}
static QState Traj_moving(Traj* const me) {
    //QState status;
    switch (Q_SIG(me)) {
	case Q_ENTRY_SIG: {
		QActive_arm(&me->super, 1);//start generating the new trajectory
		DIRECTION(me->direction);//drive the IC's DIR pin
		me->step = 0;//reset my step count
		return Q_HANDLED();
	}
    case Q_EXIT_SIG: {
        QActive_disarm(&me->super);
		return Q_HANDLED();
    }
	case GO_SIG: //Q_ERROR();//Already moving; tell PC to wait
		return Q_SUPER(&QHsm_top);
	case STOP_SIG: {
		//TODO: Tell higher layer to wait till current move done
		return Q_HANDLED();
	}
	default: return Q_SUPER(&QHsm_top);
    }
    //return status;
}
//#pragma CODE_SECTION(Traj_deriveParams, "ramfuncs");//place in RAM for speed
void Traj_deriveParams(Traj* const me) {
	me->Amax_d2 = 0.5f * me->Amax;
	me->Jmax_d6 = 0.166666667f * me->Jmax;
	me->T01 = me->T0 + me->T1;
	me->T02 = me->T01 + me->T0;
	//me->T03 = me->T02 + me->T3;
	//me->T04 = me->T03 + me->T0;
	//me->T05 = me->T04 + me->T1;
	//me->T06 = me->T05 + me->T0;
	me->T0P2T1 = me->T01 + me->T1;
	me->Smax_Amax_d2_xT0P2T1 = me->Smax - me->Amax_d2 * me->T0P2T1;
	me->T0xT0_d3 = 0.333333333f * me->T0 * me->T0;
	me->T0xT0_d3_P_T01xT1 = me->T0xT0_d3 + me->T01 * me->T1;
	me->Amax_d2xT02xT01 = me->Amax_d2 * me->T02 * me->T01;
	me->Amax_d2xT02xT01_T0xT0_d3_PSmax_xT3PT0 = me->Amax_d2xT02xT01
		- me->Amax_d2 * me->T0xT0_d3 + me->Smax * (me->T3 + me->T0);
	me->Amax_d2xT0x5T0_d3_P2T1_PSmax_xT3PT01 =
			me->Amax_d2 * me->T0 * ((5.f/3.f) * me->T0 + 2.f*me->T1)
            + me->Smax * (me->T01 + me->T3);
	me->DP = me->Smax * (me->T02 + me->T3);
	me->Dstep = (uint32_t)(me->DP + 0.5f);
}
//This trajectory is the most math intensive.  Consider running from RAM
static QState Traj_dec_jdec(Traj* const me) {
	float dP;
    switch(Q_SIG(me)) {
	case Q_ENTRY_SIG: {
		float t_sq = me->t * me->t;
		me->tickInState = 0;
		dP = me->Amax_d2xT0x5T0_d3_P2T1_PSmax_xT3PT01
           + me->Smax_Amax_d2_xT0P2T1 * me->t
           - me->Amax_d2 * t_sq + me->Jmax_d6 * me->t * t_sq;
		Traj_fullfill_dP(me, dP);
		return Q_HANDLED();
	}
    case Q_TIMEOUT_SIG: {
    	me->t = (1.0f/TIMER_INT_HZ) * ++me->tickInState;
    	if(me->t > me->T0) {//deceleration should be complete
    		if(me->step == me->Dstep) return Q_TRAN(&Traj_idle);//Move done!
    		else dP = me->step + 1;//just take the next step
    	} else {
        	float t_sq = me->t * me->t;
			dP = me->Amax_d2xT0x5T0_d3_P2T1_PSmax_xT3PT01
			   + me->Smax_Amax_d2_xT0P2T1 * me->t
			   - me->Amax_d2 * t_sq + me->Jmax_d6 * me->t * t_sq;
			QActive_arm(&me->super, 1);//Check again 1 tick later
    	}
		Traj_fullfill_dP(me, dP);
		return Q_HANDLED();
    }
	default: return Q_SUPER(&Traj_moving);
    }
}
static QState Traj_dec_j0(Traj* const me) {
	float dP;
    switch(Q_SIG(me)) {
	case Q_ENTRY_SIG:
		me->tickInState = 0;
		dP = me->Amax_d2xT02xT01_T0xT0_d3_PSmax_xT3PT0
           - me->Amax_d2 * (me->T0 + me->t) * me->t + me->Smax * me->t;
		Traj_fullfill_dP(me, dP);
		return Q_HANDLED();
    case Q_TIMEOUT_SIG:
    	me->t = (1.0f/TIMER_INT_HZ) * ++me->tickInState;
    	if(me->t > me->T1) {
    		me->t -= me->T1;
    		return Q_TRAN(&Traj_dec_jdec);
    	}
		dP = me->Amax_d2xT02xT01_T0xT0_d3_PSmax_xT3PT0
           - me->Amax_d2 * (me->T0 + me->t) * me->t + me->Smax * me->t;
		Traj_fullfill_dP(me, dP);
		return Q_HANDLED();
	//NOTE: can't stop when already decelerating
	default: return Q_SUPER(&Traj_moving);
    }
}
static QState Traj_dec_jinc(Traj* const me) {
	float dP;
    switch(Q_SIG(me)) {
	case Q_ENTRY_SIG:
		me->tickInState = 0;
		dP = me->Amax_d2xT02xT01 + me->Smax * (me->T3 + me->t)
           - me->Jmax_d6 * me->t * me->t * me->t;
		Traj_fullfill_dP(me, dP);
		return Q_HANDLED();
    case Q_TIMEOUT_SIG:
    	me->t = (1.0f/TIMER_INT_HZ) * ++me->tickInState;
    	if(me->t > me->T0) {
    		me->t -= me->T0;
    		return Q_TRAN(&Traj_dec_j0);
    	}
    	dP = me->Amax_d2xT02xT01 + me->Smax * (me->T3 + me->t)
           - me->Jmax_d6 * me->t * me->t * me->t;
		Traj_fullfill_dP(me, dP);
		return Q_HANDLED();
	//NOTE: can't stop when already decelerating
	default: return Q_SUPER(&Traj_moving);
    }
}
static QState Traj_coasting(Traj* const me) {
	float dP;
    switch(Q_SIG(me)) {
	case Q_ENTRY_SIG:
		me->tickInState = 0;
		dP = me->Amax_d2xT02xT01 + me->Smax * me->t;
		Traj_fullfill_dP(me, dP);
		return Q_HANDLED();
    case Q_TIMEOUT_SIG:
    	me->t = (1.0f/TIMER_INT_HZ) * ++me->tickInState;
    	if(me->t > me->T3) {
    		me->t -= me->T3;
    		return Q_TRAN(&Traj_dec_jinc);
    	}
    	dP = me->Amax_d2xT02xT01 + me->Smax * me->t;
		Traj_fullfill_dP(me, dP);
		return Q_HANDLED();
	case STOP_SIG://stop coasting right away
		me->T3 = (1.0f/TIMER_INT_HZ) * me->tickInState;
		Traj_deriveParams(me);
		me->t = 0;//reset the time within trajectory
		return Q_TRAN(&Traj_dec_jinc);//start decelerating right away
	default: return Q_SUPER(&Traj_moving);
    }
}
static QState Traj_acc_jdec(Traj* const me) {
	float dP;
    switch(Q_SIG(me)) {
	case Q_ENTRY_SIG:
		me->tickInState = 0;
		dP = me->Amax_d2 * (me->T0xT0_d3_P_T01xT1 + (me->T0P2T1 + me->t) * me->t)
		   - me->Jmax_d6 * me->t * me->t * me->t;
		Traj_fullfill_dP(me, dP);
		return Q_HANDLED();
    case Q_TIMEOUT_SIG:
    	me->t = (1.0f/TIMER_INT_HZ) * ++me->tickInState;
    	if(me->t > me->T0) {
    		me->t -= me->T0;
    		return Q_TRAN(&Traj_coasting);
    	}
		dP = me->Amax_d2 * (me->T0xT0_d3_P_T01xT1 + (me->T0P2T1 + me->t) * me->t)
		   - me->Jmax_d6 * me->t * me->t * me->t;
		Traj_fullfill_dP(me, dP);
		return Q_HANDLED();
	case STOP_SIG: //Don't abort this state, but when done with this state,
		me->T3 = 0;//but don't spend any time in ACC_J0
		Traj_deriveParams(me);
		return Q_HANDLED();
	default: return Q_SUPER(&Traj_moving);
    }
}
static QState Traj_acc_j0(Traj* const me) {
	float dP;
    switch(Q_SIG(me)) {
	case Q_ENTRY_SIG:
		me->tickInState = 0;
		dP = me->Amax_d2 * (me->T0xT0_d3 + (me->T0 + me->t) * me->t);
		Traj_fullfill_dP(me, dP);
		return Q_HANDLED();
    case Q_TIMEOUT_SIG:
    	me->t = (1.0f/TIMER_INT_HZ) * ++me->tickInState;
    	if(me->t > me->T1) {
    		me->t -= me->T1;
    		return Q_TRAN(&Traj_acc_jdec);
    	}
		dP = me->Amax_d2 * (me->T0xT0_d3 + (me->T0 + me->t) * me->t);
		Traj_fullfill_dP(me, dP);
		return Q_HANDLED();
	case STOP_SIG:
		me->T1 = (1.0f/TIMER_INT_HZ) * me->tickInState;
		me->T3 = 0;//Don't spend any time in const speed state
		me->Smax = me->Amax * (me->T0 + me->T1);
		Traj_deriveParams(me);
		me->t = 0;//reset the time within trajectory
		return Q_TRAN(&Traj_acc_jdec);//Start ACC_J- right away
	default: return Q_SUPER(&Traj_moving);
    }
}
static QState Traj_acc_jinc(Traj* const me) {
    switch(Q_SIG(me)) {
	case Q_ENTRY_SIG:
		me->tickInState = 0;
		QActive_arm(&me->super, 1);//Check again 1 tick later
		return Q_HANDLED();
    case Q_TIMEOUT_SIG: {
    	float dP;
    	me->t = (1.0f/TIMER_INT_HZ) * ++me->tickInState;
    	if(me->t > me->T0) {
    		me->t -= me->T0;
    		return Q_TRAN(&Traj_acc_j0);
    	}
		dP = me->Jmax_d6 * me->t * me->t * me->t;
		Traj_fullfill_dP(me, dP);
		return Q_HANDLED();
    }
	case STOP_SIG:
		me->T0 = (1.0f/TIMER_INT_HZ) * me->tickInState;
		me->T1 = me->T3 = 0;//Don't spend any time in ACC_J0 or COASTING states
		me->Amax = me->Jmax * me->T0;
		me->Smax = me->Amax * me->T0;
		Traj_deriveParams(me);
		me->t = 0;//reset the time within trajectory
		return Q_TRAN(&Traj_acc_jdec);//skip straight to ACC_J-
	default: return Q_SUPER(&Traj_moving);
    }
}

#ifdef CHECK_CONSTRAINT
#  include <math.h>//<cmath.h>
#endif
static QState Traj_idle(Traj* const me) {
    //QState status;
    switch (Q_SIG(me)) {
	case Q_ENTRY_SIG:
	    QActive_post((QActive*)me, GO_SIG);//post a signal to myself
		return Q_HANDLED();
    case GO_SIG: { // can go; calculate new motion param
		//Note that the abort may change these parameters
		me->DP = MOVE_STEPS;
		me->Smax = SMAX_SEED;
		me->Amax = AMAX_SEED;
		me->Jmax = JMAX;
#ifdef CHECK_CONSTRAINT
		do {
			me->T0 = me->Amax / me->Jmax;
			me->T1 = me->Smax / me->Amax - me->T0;
			me->T3 = me->DP / me->Smax - (2.f * me->T0 + me->T1);
			if(me->T3 < 0)
				me->Smax = (0.999999f/2.f)
					 * ((sqrt(me->Amax * (me->Amax*me->Amax*me->Amax
										  + 4.f*me->DP*me->Jmax*me->Jmax))
						 - me->Amax * me->Amax)
						/ me->Jmax);
			if(me->T1 < 0) me->Amax = 0.999999f * sqrt(me->Smax * me->Jmax);
		} while(me->T1 < 0 || me->T3 < 0);
#else
		me->T0 = me->Amax / me->Jmax;
		me->T1 = me->Smax / me->Amax - me->T0;
		me->T3 = me->DP / me->Smax - (2.f * me->T0 + me->T1);
#endif
		Traj_deriveParams(me);

		me->direction = !me->direction;//reverse direction
		return Q_TRAN(&Traj_acc_jinc);
	}
	default: return Q_SUPER(&QHsm_top);
    }
    //return status;
}

static QState Traj_initial(Traj* const me) {
    me->direction = FALSE; //DIRECTION(me->direction);
    //uStep_off();
    uStep8_on();
    DECAY_set(TRUE);
    DAC12_0DAT = 0x400;
    Stepper_on();
    return Q_TRAN(&Traj_idle);
}

void Traj_init(void) {
	QActive_ctor(&AO_traj.super, Q_STATE_CAST(&Traj_initial));
}
