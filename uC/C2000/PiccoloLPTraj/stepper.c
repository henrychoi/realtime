#include "qpn_port.h"
#include "bsp.h"
#include "l6470.h"
#include "stepper.h"

Q_DEFINE_THIS_FILE

typedef struct Stepper {
/* protected: */
    QActive super;//must be the first element of the struct for inheritance

/* private: */
    uint32_t step;
    uint16_t alarm;
    uint8_t id, lost;
// public:
} Stepper;

//protected: //necessary forward declaration
static QState Stepper_on(Stepper* const me);
static QState Stepper_idle(Stepper* const me);
static QState Stepper_top(Stepper* const me);
static QState Stepper_bottom(Stepper* const me);
static QState Stepper_homing_down(Stepper* const me);
static QState Stepper_homing_up(Stepper* const me);

//Global objects are placed in DRAML0 block.  See linker cmd file for headroom
Stepper AO_stepper;
#define HOMING_SPEED 10000
//.............................................................................
static QState Stepper_moving(Stepper* const me) {
    switch (Q_SIG(me)) {
    case Q_ENTRY_SIG:
        QActive_arm(&me->super, ~0);//TODO: adjust based on distance
        return Q_HANDLED();
    case Q_EXIT_SIG: QActive_disarm(&me->super); return Q_HANDLED();
    case Q_TIMEOUT_SIG:
    case Z_TOP_SIG:
    case Z_BOTTOM_SIG:
    case Z_STOP_SIG:
    	dSPIN_Soft_Stop(me->id);
    	return Q_HANDLED();
    case Z_NBUSY_SIG: return Q_TRAN(&Stepper_idle);
	default: return Q_SUPER(&Stepper_on);
    }
}
static QState Stepper_homing(Stepper* const me) {
    switch (Q_SIG(me)) {
    case Q_INIT_SIG: return Q_TRAN(top_flag(me->id) ? &Stepper_homing_down
                                                    : &Stepper_homing_up);
    case Q_TIMEOUT_SIG://Give up homing on any of these events
    case Z_TOP_SIG:
    case Z_BOTTOM_SIG:
    case Z_STOP_SIG:
    	dSPIN_Soft_Stop(me->id);
    	return Q_TRAN(&Stepper_moving);
	default: return Q_SUPER(&Stepper_moving);
    }
}
static QState Stepper_homing_down(Stepper* const me) {
    switch (Q_SIG(me)) {
    case Q_ENTRY_SIG:
    	//QActive_arm(&me->super, 2*BSP_TICKS_PER_SEC);//2 sec should be enough?
    	dSPIN_Go_Until(me->id, ACTION_RESET, REV, HOMING_SPEED);
        return Q_HANDLED();
    case Z_NBUSY_SIG: me->lost = FALSE; return Q_TRAN(Stepper_idle);
	default: return Q_SUPER(&Stepper_homing);
    }
}
static QState Stepper_homing_up_stopping(Stepper* const me) {
    switch (Q_SIG(me)) {
    case Q_ENTRY_SIG:
        //QActive_arm(&me->super, 2*BSP_TICKS_PER_SEC);//2 sec should be enough?
        dSPIN_Soft_Stop(me->id);
        return Q_HANDLED();
    case Z_NBUSY_SIG://begin the move downward
    	return Q_TRAN(Stepper_homing_down);
	default: return Q_SUPER(&Stepper_homing_up);
    }
}
static QState Stepper_homing_up(Stepper* const me) {
    switch (Q_SIG(me)) {
    case Q_ENTRY_SIG:
        //QActive_arm(&me->super, ~0);//Set to maximum QF_TIMEEVT_CTR_SIZE for now
        dSPIN_Run(me->id, FWD, HOMING_SPEED);
        return Q_HANDLED();
    case Z_ABOVE_SIG: return Q_TRAN(Stepper_homing_up_stopping);
	default: return Q_SUPER(&Stepper_homing);
    }
}
static QState Stepper_off(Stepper* const me) {
    switch (Q_SIG(me)) {
	default: return Q_SUPER(&QHsm_top);
    }
}
static QState Stepper_on(Stepper* const me) {
    switch (Q_SIG(me)) {
    case Q_ENTRY_SIG: me->lost = TRUE; me->alarm = 0; return Q_HANDLED();
    case Z_STEP_LOSS_SIG: me->lost = TRUE; return Q_HANDLED();
    case Z_ALARM_SIG: me->alarm = Q_PAR(me); return Q_HANDLED();
	default: return Q_SUPER(&QHsm_top);
    }
}
static QState Stepper_idle(Stepper* const me) {
    switch (Q_SIG(me)) {
    case Q_ENTRY_SIG:
    	me->step = dSPIN_Get_Param(me->id, dSPIN_ABS_POS);
    	return btm_flag(me->id)
    		? Q_TRAN(top_flag(me->id) ? &Stepper_top : &Stepper_bottom)
    		: Q_HANDLED();
    case Z_HOME_SIG: return Q_TRAN(&Stepper_homing);
    case Z_GO_SIG:
    	dSPIN_Go_To(me->id, Q_PAR(me));
    	return Q_TRAN(&Stepper_moving);
	default: return Q_SUPER(&Stepper_on);
    }
}
static QState Stepper_top(Stepper* const me) {
    switch (Q_SIG(me)) {
    case Z_GO_SIG:
    	if(Q_PAR(me) < me->step) {
			dSPIN_Go_To(me->id, Q_PAR(me));
			return Q_TRAN(&Stepper_moving);
    	} else { // illegal request
    		//TODO: return an error msg to the requester
    		return Q_HANDLED();
    	}
	default: return Q_SUPER(&Stepper_idle);
    }
}
static QState Stepper_bottom(Stepper* const me) {
    switch (Q_SIG(me)) {
    case Z_GO_SIG:
    	if(Q_PAR(me) > me->step) {
			dSPIN_Go_To(me->id, Q_PAR(me));
			return Q_TRAN(&Stepper_moving);
    	} else { // illegal request
    		//TODO: return an error msg to the requester
    		return Q_HANDLED();
    	}
	default: return Q_SUPER(&Stepper_idle);
    }
}
static QState Stepper_initial(Stepper* const me) {
	uint16_t status;
	dSPIN_RegsStruct_TypeDef dSPIN_RegsStruct;
	dSPIN_Regs_Struct_Reset(&dSPIN_RegsStruct);

	//SpiaRegs.SPIFFTX.bit.SPIRST = 0;
	//SpiaRegs.SPICCR.bit.SPISWRESET = FALSE;

    //status = dSPIN_Get_Status(id);
	//Q_ALLEGE(status == 0);//a sanity check on SPI loopback

	//SpiaRegs.SPIFFTX.bit.SPIRST = 0;//resume FIFOs; SPI FIFO config unchanged
	//SpiaRegs.SPICCR.bit.SPISWRESET = FALSE;//Enable SPI

	//EALLOW;
	//SpiaRegs.SPICCR.bit.SPILBK = FALSE;//Loopback mode; uncomment for test
    //Reset FIFO
    //SpiaRegs.SPIFFTX.bit.TXFIFO = 0;//Reset FIFO pointer to 0, and hold in reset
    //SpiaRegs.SPIFFTX.bit.TXFIFO = 1;//Reenable tx FIFO
    //SpiaRegs.SPIFFRX.bit.RXFIFORESET = 0;
    //SpiaRegs.SPIFFRX.bit.RXFIFORESET = 1;
	//EDIS;
	dSPIN_Soft_Stop(me->id);
	dSPIN_Reset_Device(me->id);

    if(dSPIN_Busy_HW(me->id)) return Q_TRAN(&Stepper_off);
    status = dSPIN_Get_Status(me->id);

   	if(status & dSPIN_STATUS_SW_EVN
   		|| (status & dSPIN_STATUS_MOT_STATUS) != dSPIN_STATUS_MOT_STATUS_STOPPED
   		|| status & dSPIN_STATUS_NOTPERF_CMD
   		|| status & dSPIN_STATUS_WRONG_CMD
   		// !(status & dSPIN_STATUS_UVLO)
   		|| !(status & dSPIN_STATUS_TH_SD)
   		|| !(status & dSPIN_STATUS_OCD))
		return Q_TRAN(&Stepper_off);

	dSPIN_RegsStruct.CONFIG = dSPIN_CONFIG_INT_16MHZ_OSCOUT_2MHZ
			| dSPIN_CONFIG_SW_USER//don't want to hard stop on home switch
			| dSPIN_CONFIG_VS_COMP_DISABLE//Motor supply voltage compensation OFF
			//IC does not seem to take this
			//| dSPIN_CONFIG_OC_SD_ENABLE//bridge does NOT shutdown on overcurrent
			| dSPIN_CONFIG_SR_290V_us//slew rate
			| dSPIN_CONFIG_PWM_DIV_2 | dSPIN_CONFIG_PWM_MUL_1;
	dSPIN_RegsStruct.ACC = dSPIN_RegsStruct.DEC = AccDec_Steps_to_Par(466);
	dSPIN_RegsStruct.MAX_SPEED = MaxSpd_Steps_to_Par(488);
	dSPIN_RegsStruct.MIN_SPEED = MinSpd_Steps_to_Par(0);
	dSPIN_RegsStruct.FS_SPD = FSSpd_Steps_to_Par(252);
	dSPIN_RegsStruct.KVAL_HOLD = Kval_Perc_to_Par(10);
	dSPIN_RegsStruct.KVAL_RUN = Kval_Perc_to_Par(10);
	dSPIN_RegsStruct.KVAL_ACC = dSPIN_RegsStruct.KVAL_DEC = Kval_Perc_to_Par(10);
	dSPIN_RegsStruct.INT_SPD = IntSpd_Steps_to_Par(200);
	dSPIN_RegsStruct.ST_SLP  = BEMF_Slope_Perc_to_Par(0.038);
	dSPIN_RegsStruct.FN_SLP_ACC = dSPIN_RegsStruct.FN_SLP_DEC
			= BEMF_Slope_Perc_to_Par(0.063);
	dSPIN_RegsStruct.K_THERM = KTherm_to_Par(1);
	dSPIN_RegsStruct.OCD_TH = dSPIN_OCD_TH_2250mA;
	dSPIN_RegsStruct.STALL_TH = StallTh_to_Par(1000);
	dSPIN_RegsStruct.STEP_MODE= dSPIN_STEP_SEL_1_2;
	dSPIN_RegsStruct.ALARM_EN = dSPIN_ALARM_EN_OVERCURRENT
			| dSPIN_ALARM_EN_THERMAL_SHUTDOWN| dSPIN_ALARM_EN_THERMAL_WARNING
			| dSPIN_ALARM_EN_UNDER_VOLTAGE
			| dSPIN_ALARM_EN_STALL_DET_A| dSPIN_ALARM_EN_STALL_DET_B
			//| dSPIN_ALARM_EN_SW_TURN_ON
			//| dSPIN_ALARM_EN_WRONG_NPERF_CMD//IC doesn't seem to take this
			;
	dSPIN_Registers_Set(me->id, &dSPIN_RegsStruct);

    status = dSPIN_Get_Status(me->id);
    if(!(status & dSPIN_STATUS_HIZ)
    	|| !(status & dSPIN_STATUS_BUSY)
    	|| dSPIN_Busy_HW(me->id))
		return Q_TRAN(&Stepper_off);

	return Q_TRAN(&Stepper_idle);
}

void Stepper_init(void) {
    AO_stepper.id = 0;
    QActive_ctor(&AO_stepper.super, Q_STATE_CAST(&Stepper_initial));
}
