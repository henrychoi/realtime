#define MOVE_STEPS 5000.f
#define SMAX_SEED 2000.0f
#define AMAX_SEED 1000.0f
#define JMAX 5000.0f

#include <math.h>
#include "qpn_port.h"
#include "bsp.h"
#include "traj.h"

Q_DEFINE_THIS_FILE

//protected: //necessary forward declaration
static QState Traj_idle(Traj* const me);

//Global objects are placed in DRAML0 block.  See linker cmd file for headroom
Traj AO_traj[N_TRAJ];

#define DECAY_set(on)
#define STP_on()
#define STP_off()
#define uStep_on()
#define uStep_off()
#define Stepper_on(id)
//Called from every state, at every TIMEOUT_SIG => speed it up
#pragma CODE_SECTION(Traj_fullfill_dP, "ramfuncs");//place in RAM for speed
void Traj_fullfill_dP(Traj* const me) {
	uint32_t step_r = (uint32_t)(me->dP + 0.5f); // step_r = ROUND(dP, 0)
	if(step_r > me->step) { //emit a pulse
		volatile uint16_t ctr = 10;
		switch(me->id) {
		case 0:
			STP_on();
			GpioDataRegs.GPACLEAR.bit.GPIO0 = TRUE;
			while(--ctr);
			GpioDataRegs.GPASET.bit.GPIO0 = TRUE;
			STP_off();
			break;
		case 1:
			GpioDataRegs.GPACLEAR.bit.GPIO1 = TRUE;
			while(--ctr);
			GpioDataRegs.GPASET.bit.GPIO1 = TRUE;
			break;
		case 2:
			GpioDataRegs.GPACLEAR.bit.GPIO2 = TRUE;
			while(--ctr);
			GpioDataRegs.GPASET.bit.GPIO2 = TRUE;
			break;
		case 3:
			GpioDataRegs.GPACLEAR.bit.GPIO3 = TRUE;
			while(--ctr);
			GpioDataRegs.GPASET.bit.GPIO3 = TRUE;
			break;
		default: Q_ERROR();
		}
		++me->step;
	}
}
static QState Traj_moving(Traj* const me) {
    //QState status;
    switch (Q_SIG(me)) {
	case Q_ENTRY_SIG: {
		QActive_arm(&me->super, 1);//start generating the new trajectory
		me->step = 0;
		return Q_HANDLED();
	}
    case Q_EXIT_SIG: {
        QActive_disarm(&me->super);
		return Q_HANDLED();
    }
	case GO_SIG: {//Already moving; should emit error
		return Q_SUPER(&QHsm_top);
	}
	case STOP_SIG:
	case GOSTOP_SIG: {
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
//This trajectory is the most math intensive
#pragma CODE_SECTION(Traj_dec_jdec, "ramfuncs");//place in RAM for speed
static QState Traj_dec_jdec(Traj* const me) {
    switch(Q_SIG(me)) {
	case Q_ENTRY_SIG: {
		float t_sq = me->t * me->t;
		me->tickInState = 0;
		me->dP = me->Amax_d2xT0x5T0_d3_P2T1_PSmax_xT3PT01
               + me->Smax_Amax_d2_xT0P2T1 * me->t
               - me->Amax_d2 * t_sq + me->Jmax_d6 * me->t * t_sq;
		Traj_fullfill_dP(me);
		return Q_HANDLED();
	}
    case Q_TIMEOUT_SIG: {
    	me->t = TICK2TIME * ++me->tickInState;
    	if(me->t > me->T0) {
    		if(me->step == me->Dstep) { //Move done!
    			return Q_TRAN(&Traj_idle);
    		} else {
    			Q_ASSERT((me->Dstep - me->step) < 2);
    			me->dP = me->step + 1;//just take the next step
    			//Take the next tick many clocks later
    			QActive_arm(&me->super, BSP_TICKS_PER_SEC/10);
    		}
    	} else {
        	float t_sq = me->t * me->t;
			me->dP = me->Amax_d2xT0x5T0_d3_P2T1_PSmax_xT3PT01
				   + me->Smax_Amax_d2_xT0P2T1 * me->t
				   - me->Amax_d2 * t_sq + me->Jmax_d6 * me->t * t_sq;
			QActive_arm(&me->super, 1);//Check again 1 tick later
    	}
		Traj_fullfill_dP(me);
		return Q_HANDLED();
    }
	default: return Q_SUPER(&Traj_moving);
    }
}
static QState Traj_dec_j0(Traj* const me) {
    switch(Q_SIG(me)) {
	case Q_ENTRY_SIG:
		me->tickInState = 0;
		me->dP = me->Amax_d2xT02xT01_T0xT0_d3_PSmax_xT3PT0
               - me->Amax_d2 * (me->T0 + me->t) * me->t + me->Smax * me->t;
		Traj_fullfill_dP(me);
		return Q_HANDLED();
    case Q_TIMEOUT_SIG: {
		QActive_arm(&me->super, 1);//Check again 1 tick later
    	me->t = TICK2TIME * ++me->tickInState;
    	if(me->t > me->T1) {
    		me->t -= me->T1;
    		return Q_TRAN(&Traj_dec_jdec);
    	}
		me->dP = me->Amax_d2xT02xT01_T0xT0_d3_PSmax_xT3PT0
               - me->Amax_d2 * (me->T0 + me->t) * me->t + me->Smax * me->t;
		Traj_fullfill_dP(me);
		return Q_HANDLED();
    }
	default: return Q_SUPER(&Traj_moving);
    }
}
static QState Traj_dec_jinc(Traj* const me) {
    switch(Q_SIG(me)) {
	case Q_ENTRY_SIG:
		me->tickInState = 0;
		me->dP = me->Amax_d2xT02xT01 + me->Smax * (me->T3 + me->t)
               - me->Jmax_d6 * me->t * me->t * me->t;
		Traj_fullfill_dP(me);
		return Q_HANDLED();
    case Q_TIMEOUT_SIG: {
		QActive_arm(&me->super, 1);//Check again 1 tick later
    	me->t = TICK2TIME * ++me->tickInState;
    	if(me->t > me->T0) {
    		me->t -= me->T0;
    		return Q_TRAN(&Traj_dec_j0);
    	}
    	me->dP = me->Amax_d2xT02xT01 + me->Smax * (me->T3 + me->t)
               - me->Jmax_d6 * me->t * me->t * me->t;
		Traj_fullfill_dP(me);
		return Q_HANDLED();
    }
	default: return Q_SUPER(&Traj_moving);
    }
}
static QState Traj_coasting(Traj* const me) {
    switch(Q_SIG(me)) {
	case Q_ENTRY_SIG:
		me->tickInState = 0;
		me->dP = me->Amax_d2xT02xT01 + me->Smax * me->t;
		Traj_fullfill_dP(me);
		return Q_HANDLED();
    case Q_TIMEOUT_SIG: {
		QActive_arm(&me->super, 1);//Check again 1 tick later
    	me->t = TICK2TIME * ++me->tickInState;
    	if(me->t > me->T3) {
    		me->t -= me->T3;
    		return Q_TRAN(&Traj_dec_jinc);
    	}
    	me->dP = me->Amax_d2xT02xT01 + me->Smax * me->t;
		Traj_fullfill_dP(me);
		return Q_HANDLED();
    }
	case STOP_SIG:
	case GOSTOP_SIG: {
		me->T3 = TICK2TIME * me->tickInState;
		Traj_deriveParams(me);
		me->t = 0;
		return Q_TRAN(&Traj_dec_jinc);
	}
	default: return Q_SUPER(&Traj_moving);
    }
}
static QState Traj_acc_jdec(Traj* const me) {
    switch(Q_SIG(me)) {
	case Q_ENTRY_SIG:
		me->tickInState = 0;
		me->dP = me->Amax_d2 * (me->T0xT0_d3_P_T01xT1
                                + (me->T0P2T1 + me->t) * me->t)
			   - me->Jmax_d6 * me->t * me->t * me->t;
		Traj_fullfill_dP(me);
		return Q_HANDLED();
    case Q_TIMEOUT_SIG: {
		QActive_arm(&me->super, 1);//Check again 1 tick later
    	me->t = TICK2TIME * ++me->tickInState;
    	if(me->t > me->T0) {
    		me->t -= me->T0;
    		return Q_TRAN(&Traj_coasting);
    	}
		me->dP = me->Amax_d2 * (me->T0xT0_d3_P_T01xT1
                                + (me->T0P2T1 + me->t) * me->t)
			   - me->Jmax_d6 * me->t * me->t * me->t;
		Traj_fullfill_dP(me);
		return Q_HANDLED();
    }
	case STOP_SIG:
	case GOSTOP_SIG: {//Don't abort this state
		me->T3 = 0;//Don't spend any time in const speed state
		Traj_deriveParams(me);
		me->t = 0;
		return Q_HANDLED();
	}
	default: return Q_SUPER(&Traj_moving);
    }
}
static QState Traj_acc_j0(Traj* const me) {
    switch(Q_SIG(me)) {
	case Q_ENTRY_SIG:
		me->tickInState = 0;
		me->dP = me->Amax_d2 * (me->T0xT0_d3 + (me->T0 + me->t) * me->t);
		Traj_fullfill_dP(me);
		return Q_HANDLED();
    case Q_TIMEOUT_SIG: {
		QActive_arm(&me->super, 1);//Check again 1 tick later
    	me->t = TICK2TIME * ++me->tickInState;
    	if(me->t > me->T1) {
    		me->t -= me->T1;
    		return Q_TRAN(&Traj_acc_jdec);
    	}
		me->dP = me->Amax_d2 * (me->T0xT0_d3 + (me->T0 + me->t) * me->t);
		Traj_fullfill_dP(me);
		return Q_HANDLED();
    }
	case STOP_SIG:
	case GOSTOP_SIG: {
		me->T1 = TICK2TIME * me->tickInState;
		me->T3 = 0;//Don't spend any time in const speed state
		me->Smax = me->Amax * (me->T0 + me->T1);
		Traj_deriveParams(me);
		me->t = 0;
		return Q_TRAN(&Traj_acc_jdec);
	}
	default: return Q_SUPER(&Traj_moving);
    }
}
static QState Traj_acc_jinc(Traj* const me) {
    //QState status;
    switch(Q_SIG(me)) {
	case Q_ENTRY_SIG:
		me->tickInState = 0;
		return Q_HANDLED();
    case Q_TIMEOUT_SIG: {
		QActive_arm(&me->super, 1);//Check again 1 tick later
    	me->t = TICK2TIME * ++me->tickInState;
    	if(me->t > me->T0) {
    		me->t -= me->T0;
    		return Q_TRAN(&Traj_acc_j0);
    	}
		me->dP = me->Jmax_d6 * me->t * me->t * me->t;
		Traj_fullfill_dP(me);
		return Q_HANDLED();
    }
	case STOP_SIG:
	case GOSTOP_SIG: {
		me->T0 = TICK2TIME * me->tickInState;
		me->T1 = me->T3 = 0;//Don't spend any time in const speed or acc
		me->Amax = me->Jmax * me->T0;
		me->Smax = me->Amax * me->T0;
		Traj_deriveParams(me);
		me->t = 0;
		return Q_TRAN(&Traj_acc_jdec);
	}
	default: return Q_SUPER(&Traj_moving);
    }
    //return status;
}
static QState Traj_idle(Traj* const me) {
    //QState status;
    switch (Q_SIG(me)) {
    case GO_SIG:
	case GOSTOP_SIG: { // can go; calculate new motion param
		me->DP = MOVE_STEPS;
		me->Smax = SMAX_SEED;
		me->Amax = AMAX_SEED;
		me->Jmax = JMAX;
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

		Traj_deriveParams(me);
		return Q_TRAN(&Traj_acc_jinc);
	}
	default: return Q_SUPER(&QHsm_top);
    }
    //return status;
}

static QState Traj_initial(Traj* const me) {
	switch(me->id) {
	case 0:
		DECAY_set(TRUE);//avoid excessive current
		Stepper_on(me->id);//Energize the stepper
		uStep_on();//TODO: use maximum uStep: 32
		break;
	case 1:
		DECAY_set(TRUE);//avoid excessive current
		Stepper_on(me->id);//Energize the stepper
		uStep_on();//TODO: use maximum uStep: 32
		break;
	case 2:
		DECAY_set(TRUE);//avoid excessive current
		Stepper_on(me->id);//Energize the stepper
		uStep_on();//TODO: use maximum uStep: 32
		break;
	default: Q_ERROR();
	}
    return Q_TRAN(&Traj_idle);
}

void Traj_init(void) {
	int i;
	for(i=0; i < N_TRAJ; ++i) { //take the initial transition
		QActive_ctor(&AO_traj[i].super, Q_STATE_CAST(&Traj_initial));
		AO_traj[i].id = i;
	}
}

