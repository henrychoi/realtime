#include "qpn_port.h"
#include "bsp.h"
#include "traj.h"

/*Q_DEFINE_THIS_FILE*/

/* protected: */
static QState Traj_initial(Traj* const me);
static QState Traj_idle(Traj* const me);

/* Global objects ----------------------------------------------------------*/
struct TrajTag AO_traj[N_TRAJ];

void Traj_init(void) {
	int i;
	for(i=0; i < N_TRAJ; ++i) { //take the initial transition
        QActive_ctor(&AO_traj[i].super, Q_STATE_CAST(&Traj_initial));
        AO_traj[i].id = i;
	}
}

static QState Traj_initial(Traj * const me) {
	//Energize the stepper
    DECAY_set(TRUE);
    Stepper_on(me->id);
    uStep_on();

    return Q_TRAN(&Traj_idle);
}

static QState Traj_idle(Traj * const me) {
    QState status;
    switch (Q_SIG(me)) {
        case Q_ENTRY_SIG: {
            status = Q_HANDLED();
            break;
        }
        case GO_SIG: {
            //status = Q_TRAN(&traj_offline);
            break;
        }
        default: {
            status = Q_SUPER(&QHsm_top);
            break;
        }
    }
    return status;
}

