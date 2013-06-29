#include "qpn_port.h"                                       /* QP-nano port */
#include "bsp.h"                             /* Board Support Package (BSP) */
#include "stepper.h"                               /* application interface */

/*..........................................................................*/
static QEvt l_stepperQ[4], l_zrpQ[4];

/* QF_active[] array defines all active object control blocks --------------*/
QActiveCB const Q_ROM Q_ROM_VAR QF_active[] = {
    { (QActive*)0, (QEvt*)0, 0U}
	, { (QActive*)&AO_stepper, l_stepperQ, Q_DIM(l_stepperQ)}
    , { (QActive*)&AO_zrp, l_zrpQ, Q_DIM(l_zrpQ)}
};
/* make sure that the QF_active[] array matches QF_MAX_ACTIVE in qpn_port.h */
Q_ASSERT_COMPILE(QF_MAX_ACTIVE == Q_DIM(QF_active) - 1);

/*..........................................................................*/
int main (void) {
    //Traj_init(); /* initialize the S-curve generators */
	ZRP_init();//Initialize the stepper motors
    BSP_init();                                     /* initialize the board */
    return QF_run();                         /* transfer control to QF-nano */
}
