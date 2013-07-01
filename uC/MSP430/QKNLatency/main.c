#include "qpn_port.h"   /* QP-nano port */
#include "bsp.h"        /* Board Support Package (BSP) */
#include "excitation.h"

/*..........................................................................*/
static QEvt l_excitationQ[4];

/* QF_active[] array defines all active object control blocks --------------*/
QActiveCB const Q_ROM Q_ROM_VAR QF_active[] = {
    { (QActive*)0, (QEvt*)0, 0U }
  , { (QActive*)&AO_excitation, l_excitationQ, Q_DIM(l_excitationQ) }
};

/* make sure that the QF_active[] array matches QF_MAX_ACTIVE in qpn_port.h */
Q_ASSERT_COMPILE(QF_MAX_ACTIVE == Q_DIM(QF_active) - 1);

/*..........................................................................*/
int main (void) {
    Excitation_init();
    BSP_init();                                     /* initialize the board */
    return QF_run();                         /* transfer control to QF-nano */
}
