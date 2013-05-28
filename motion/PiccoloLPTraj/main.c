#include "qpn_port.h"                                       /* QP-nano port */
#include "bsp.h"                             /* Board Support Package (BSP) */
#include "traj.h"                               /* application interface */

/*..........................................................................*/
static QEvt l_trajQueue[N_TRAJ][4];

/* QF_active[] array defines all active object control blocks --------------*/
QActiveCB const Q_ROM Q_ROM_VAR QF_active[] = {
    { (QActive *)0,           (QEvt *)0,      0U                    }
  , { (QActive *)&AO_traj[0], l_trajQueue[0], Q_DIM(l_trajQueue[0]) }
  , { (QActive *)&AO_traj[1], l_trajQueue[1], Q_DIM(l_trajQueue[1]) }
  , { (QActive *)&AO_traj[2], l_trajQueue[2], Q_DIM(l_trajQueue[2]) }
};

/* make sure that the QF_active[] array matches QF_MAX_ACTIVE in qpn_port.h */
Q_ASSERT_COMPILE(QF_MAX_ACTIVE == Q_DIM(QF_active) - 1);

/*..........................................................................*/
int main (void) {
    Traj_init(); /* initialize the trajectory generators */
    BSP_init();                                     /* initialize the board */
    return QF_run();                         /* transfer control to QF-nano */
}
