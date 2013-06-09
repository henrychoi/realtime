#include "qpn_port.h"
#include "bsp.h"

/*Q_DEFINE_THIS_FILE*/
#define STP_toggle() (P4OUT ^= BIT3)
#define STP_on()     (P4OUT |= BIT3)
#define STP_off()    (P4OUT &= ~BIT3)

#define Stepper_on()   (P4OUT |= (BIT6 | BIT7))
#define Stepper_off()  (P4OUT &= ~(BIT6 | BIT7))

#define DIRECTION(bDir) if(bDir) P4OUT |= BIT4; else P4OUT &= ~BIT4

#define uStep8_on()   (P5OUT |= (BIT3 + BIT1))
#define uStep32_on()   (P5OUT |= (BIT3 + BIT1 + BIT0))
#define uStep_off()  (P5OUT &= ~(BIT3 + BIT1 + BIT0))

#define DECAY_set(bFast)  if(bFast) P4OUT |= BIT1; else P4OUT &= ~BIT1

typedef struct IlluminationTag {
/* protected: */
    QActive super;

/* private: */
    uint8_t direction;
    uint32_t traj_tick, step;
    float T06, Smax;
} Illumination;

/* protected: */
static QState Illumination_off(Illumination* const me);

/* Global objects ----------------------------------------------------------*/
Illumination AO_Illumination; //Illumination singleton

static QState Illumination_on(Illumination* const me) {
    switch(Q_SIG(me)) {
	case Q_ENTRY_SIG:
		me->direction = !me->direction;//Change direction
		DIRECTION(me->direction);
		QActive_arm(&me->super, 1);
		return Q_HANDLED();

	case Q_TIMEOUT_SIG: {
#define USE_FLOAT
#ifdef USE_FLOAT
		float T_traj, dP;
		uint32_t step_r;
		T_traj = (1.0f/TIMER_INT_HZ) * (++me->traj_tick);
		if(T_traj > me->T06)
			return Q_TRAN(&Illumination_off);
		else dP = me->Smax * T_traj;
		step_r = (uint32_t)(dP + 0.5f); // step_r = ROUND(dP, 0)
		if(step_r == me->step) {
			QActive_arm(&me->super, 1);//rearm timer to avoid logical deadlock
			return Q_HANDLED();
		}
#endif
		//Emit a pulse
		STP_on();
		LED_on();
		QActive_arm(&me->super, 1);//rearm timer to avoid logical deadlock
    	//_delay_cycles(10);
    	LED_off();
    	STP_off();
    	++me->step;
    	return Q_HANDLED();
	}
    default: return Q_SUPER(&QHsm_top);
    }
}
static QState Illumination_off(Illumination* const me) {
    switch(Q_SIG(me)) {
	case Q_ENTRY_SIG:
		QActive_arm(&me->super, 1);//start generating the new trajectory
		return Q_HANDLED();
    case Q_TIMEOUT_SIG:
#define DRIVE_TIME 1.0f
		me->Smax = 0.9f * TIMER_INT_HZ;
		me->T06 = DRIVE_TIME;
		me->traj_tick = 0;
		me->step = 0;
    	return Q_TRAN(&Illumination_on);
    default: return Q_SUPER(&QHsm_top);
    }
}
static QState Illumination_initial(Illumination* const me) {
    me->direction = FALSE; //DIRECTION(me->direction);
    //uStep_off();
    uStep8_on();
    DECAY_set(TRUE);
    DAC12_0DAT = 0x400;
    Stepper_on();
    return Q_TRAN(&Illumination_off);
}
void Illumination_ctor(void) {
    QActive_ctor(&AO_Illumination.super, Q_STATE_CAST(&Illumination_initial));
}
