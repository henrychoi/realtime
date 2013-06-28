#ifndef stepper_h
#define stepper_h
#include "qpn_port.h" //To pick up N_TRAJ

enum StepperSignals {
    HOME_SIG = Q_USER_SIG
  , GO_SIG, STOP_SIG
  , ABOVE_SIG, TOP_SIG, BOTTOM_SIG
  , NBUSY_SIG
  , STEP_LOSS_SIG, ALARM_SIG
};

extern struct Stepper AO_stepper;

void Stepper_init(void);
uint8_t dSPIN_Busy_HW(uint8_t id);
uint8_t dSPIN_Alarm(uint8_t id);
uint16_t dSPIN_Get_Status(uint8_t id);
typedef enum {/* Status Register bit masks */
	dSPIN_STATUS_HIZ			=(((uint16_t)0x0001)),
	dSPIN_STATUS_BUSY			=(((uint16_t)0x0002)),
	dSPIN_STATUS_SW_F			=(((uint16_t)0x0004)),
	dSPIN_STATUS_SW_EVN			=(((uint16_t)0x0008)),
	dSPIN_STATUS_DIR			=(((uint16_t)0x0010)),
	dSPIN_STATUS_MOT_STATUS		=(((uint16_t)0x0060)),
	dSPIN_STATUS_NOTPERF_CMD	=(((uint16_t)0x0080)),
	dSPIN_STATUS_WRONG_CMD		=(((uint16_t)0x0100)),
	dSPIN_STATUS_UVLO			=(((uint16_t)0x0200)),
	dSPIN_STATUS_TH_WRN			=(((uint16_t)0x0400)),
	dSPIN_STATUS_TH_SD			=(((uint16_t)0x0800)),
	dSPIN_STATUS_OCD			=(((uint16_t)0x1000)),
	dSPIN_STATUS_STEP_LOSS_A	=(((uint16_t)0x2000)),
	dSPIN_STATUS_STEP_LOSS_B	=(((uint16_t)0x4000)),
	dSPIN_STATUS_SCK_MOD		=(((uint16_t)0x8000))
} dSPIN_STATUS_Masks_TypeDef;

#endif /* stepper_h */
