#ifndef stepper_h
#define stepper_h
#include "qpn_port.h" //To pick up N_TRAJ

enum StepperSignals {
    HOME_SIG = Q_USER_SIG
  , GO_SIG, STOP_SIG
  , ABOVE_SIG, TOP_SIG, BOTTOM_SIG
  , NBUSY_SIG
};


extern struct Stepper AO_stepper;

void Stepper_init(void);
uint8_t dSPIN_Busy_HW(uint8_t id);

#endif /* stepper_h */
