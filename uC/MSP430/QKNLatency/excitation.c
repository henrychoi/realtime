#include "qpn_port.h"
#include "bsp.h"
#include "excitation.h"

/*Q_DEFINE_THIS_FILE*/

//Assume nobody is going to change TBCCR0 while running
#define Clock_read() do { \
	uint16_t _tick_ = TBR; \
	tick = _tick_ < tick ? _tick_ + TBCCR0 : _tick_; \
} while(0)
uint16_t tick;//singleton clock

typedef struct Excitation {
/* protected: */
    QActive super;
    uint32_t t;
} Excitation;

/* protected: I only *forward* declare necessary methods */

Excitation AO_excitation;//excitation singleton

#pragma vector = TIMERB1_VECTOR
__interrupt void timerB1_ISR(void) {
    QK_ISR_ENTRY();                       /* inform QK-nano about ISR entry */
	//Clock_read();
    QActive_postISR((QActive*)&AO_excitation, TIMERB1_SIG, 0);
	TBCCTL1 = 0;//Enable timer B1 interrupt
    QK_ISR_EXIT();                         /* inform QK-nano about ISR exit */
}

static QState Excitation_off(Excitation* const me) { return Q_SUPER(&QHsm_top); }
static QState Excitation_on(Excitation* const me) {
#define DESIRED_DELAY 7872//(TBCCR0 - 4000)
	uint16_t t;
    switch(Q_SIG(me)) {
    case Q_ENTRY_SIG: //QActive_arm(&me->super, 1); return Q_HANDLED();
    //case Q_TIMEOUT_SIG:
    	Clock_read(); t = tick;
    	Clock_read(); t = tick + DESIRED_DELAY;
    	do {
    		Clock_read();
    	} while(tick < t);

    	Clock_read(); me->t = tick;
    	TBCCR1 = TBR + DESIRED_DELAY;
    	while(TBCCR1 > TBCCR0) TBCCR1 -= TBCCR0;
    	TBCCTL1 = CCIE;//Enable timer B1 interrupt
    	return Q_HANDLED();
    case Q_EXIT_SIG:
    	Clock_read();
    	return Q_HANDLED();
    case TIMERB1_SIG: return Q_TRAN(&Excitation_off);
    default: return Q_SUPER(&QHsm_top);
    }
}
static QState Excitation_initial(Excitation* const me) {
    return Q_TRAN(&Excitation_on);
}
void Excitation_init(void) {
    QActive_ctor(&AO_excitation.super, Q_STATE_CAST(&Excitation_initial));
}
