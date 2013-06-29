#ifndef stepper_h
#define stepper_h
#include "qpn_port.h" //To pick up N_TRAJ

#define N_STEPPER 1

enum StepperSignals {
	Z_HOME_SIG = Q_USER_SIG
  , Z_GO_SIG, Z_STOP_SIG
  , Z_ABOVE_SIG, Z_TOP_SIG, Z_BOTTOM_SIG
  , Z_NBUSY_SIG
  , Z_STEP_LOSS_SIG, Z_ALARM_SIG
};

extern struct Stepper AO_stepper;

void Stepper_init(void);

#endif /* stepper_h */
