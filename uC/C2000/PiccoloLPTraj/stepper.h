#ifndef stepper_h
#define stepper_h
#include "qpn_port.h"

#define N_STEPPER 1

//typedef enum AxisZone {//Keep getting "shift count is too large when using enum
#define AXIS_TOP    3
#define AXIS_ABOVE  2
#define AXIS_BELOW  1
#define AXIS_BOTTOM 0
//} AxisZone;
#define Axis_zone(top_, btm_) \
	((top_) ? ((btm_) ? AXIS_TOP : AXIS_ABOVE) \
			: ((btm_) ? AXIS_BOTTOM : AXIS_BELOW))

enum StepperSignals {
	Z_HOME_SIG = Q_USER_SIG
  , Z_GO_SIG, Z_STOP_SIG
  , Z_ABOVE_SIG, Z_TOP_SIG, Z_BOTTOM_SIG
  , Z_NBUSY_SIG
  , Z_STEP_LOSS_SIG, Z_ALARM_SIG
  , Z_IDLE_SIG//stepper reached IDLE
};

extern struct Stepper AO_stepper;
extern struct ZRP AO_zrp;

void ZRP_init(void);

#endif /* stepper_h */
