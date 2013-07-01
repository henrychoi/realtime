#include "qpn_port.h"
#include "bsp.h"
#include "excitation.h"

/*Q_DEFINE_THIS_FILE*/

typedef union hilo16 {
	uint32_t u32;
	uint16_t u16[2];
} hilo16_union;

#define Clock_read() do { \
	uint16_t _tick_ = TBR; \
	if(_tick_ < timer_tick.u16[0]) ++timer_tick.u16[1]; \
    timer_tick.u16[0] = _tick_; \
} while(0)

typedef struct Excitation {
/* protected: */
    QActive super;
    uint32_t t;
} Excitation;

/* protected: I only *forward* declare necessary methods */

Excitation AO_excitation;//excitation singleton
hilo16_union timer_tick;//singleton clock

#pragma vector = TIMERB1_VECTOR
__interrupt void timerB1_ISR(void) {
    QK_ISR_ENTRY();                       /* inform QK-nano about ISR entry */
	Clock_read();
    QActive_postISR((QActive*)&AO_excitation, TIMERB1_SIG, timer_tick.u32);
	TBCCTL1 = 0;//Enable timer B1 interrupt
    QK_ISR_EXIT();                         /* inform QK-nano about ISR exit */
}

static QState Excitation_ready(Excitation* const me) {
	uint32_t t;
	//uint16_t future;
    switch(Q_SIG(me)) {
    case Q_ENTRY_SIG: //QActive_arm(&me->super, 1); return Q_HANDLED();
    //case Q_TIMEOUT_SIG:
    	Clock_read();
    	t = timer_tick.u32;
    	Clock_read();
    	me->t = timer_tick.u32 - t;//Learned from this a clock read = 9 clocks
    	//future = 10 + TBR;
    	TBCCR1 = TBR + 0;//Wake up right away
    	Clock_read();
    	me->t = timer_tick.u32;
    	TBCCTL1 = CCIE;//Enable timer B1 interrupt
    	return Q_HANDLED();
    case TIMERB1_SIG:
    	Clock_read();
    	timer_tick.u32 - me->t;
    	t = Q_PAR(me);
    	return Q_HANDLED();
    default: return Q_SUPER(&QHsm_top);
    }
}
static QState Excitation_initial(Excitation* const me) {
	timer_tick.u32 = 0;
    return Q_TRAN(&Excitation_ready);
}
void Excitation_init(void) {
    QActive_ctor(&AO_excitation.super, Q_STATE_CAST(&Excitation_initial));
}
