#ifndef stepper_h
#define stepper_h
#include "qpn_port.h" //To pick up N_TRAJ

enum StepperSignals {
    GO_SIG = Q_USER_SIG
  , STOP_SIG
};


extern struct Stepper AO_stepper;

void Stepper_init(void);

#endif /* stepper_h */
