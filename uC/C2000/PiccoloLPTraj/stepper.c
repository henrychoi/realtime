#include "qpn_port.h"
#include "bsp.h"
#include "l6470.h"
#include "stepper.h"

Q_DEFINE_THIS_FILE

typedef struct Stepper {
/* protected: */
    QActive super;//must be the first element of the struct for inheritance

/* private: */
    uint32_t status;
// public:
} Stepper;
#define STEPPER_ID_MASK   0x00000003
#define Stepper_id(me_)   ((me_)->status & STEPPER_ID_MASK)
#define STEPPER_POS_MASK  0x00FFFFFC
#define Stepper_pos(me_)  (((me_)->status & STEPPER_POS_MASK) >> 2)
#define STEPPER_ZONE_MASK 0x03000000

#define STEPPER_Z         0x80000000
#define STEPPER_OVERC     0x40000000
#define STEPPER_UNDERV    0x20000000
#define STEPPER_TEMP      0x10000000
#define STEPPER_LOST      0x08000000
#define STEPPER_HOMED     0x04000000

//#pragma CODE_SECTION(Stepper_setPosZone, "ramfuncs");//place in RAM for speed
uint8_t Stepper_setPosZone(Stepper* const me) {
	uint8_t zone = Axis_zone(top_flag(Stepper_id(me)), btm_flag(Stepper_id(me)));
	me->status &= ~(STEPPER_ZONE_MASK | STEPPER_POS_MASK);
	me->status |= ((uint32_t)zone) << 24
				| dSPIN_Get_Param(Stepper_id(me), dSPIN_ABS_POS) << 2;
	return zone;
}

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
    	dSPIN_Soft_Stop(Stepper_id(me));
    	return Q_HANDLED();
    case Z_NBUSY_SIG: return Q_TRAN(&Stepper_idle);
	default: return Q_SUPER(&Stepper_on);
    }
}
static QState Stepper_homing(Stepper* const me) {
    switch (Q_SIG(me)) {
    case Q_INIT_SIG: return Q_TRAN(top_flag(Stepper_id(me)) ? &Stepper_homing_down
                                                    : &Stepper_homing_up);
    case Q_TIMEOUT_SIG://Give up homing on any of these events
    case Z_TOP_SIG:
    case Z_BOTTOM_SIG:
    case Z_STOP_SIG:
    	dSPIN_Soft_Stop(Stepper_id(me));
    	return Q_TRAN(&Stepper_moving);
	default: return Q_SUPER(&Stepper_moving);
    }
}
static QState Stepper_homing_down(Stepper* const me) {
    switch (Q_SIG(me)) {
    case Q_ENTRY_SIG:
    	//QActive_arm(&me->super, 2*BSP_TICKS_PER_SEC);//2 sec should be enough?
    	dSPIN_Go_Until(Stepper_id(me), ACTION_RESET, REV, HOMING_SPEED);
        return Q_HANDLED();
    case Z_NBUSY_SIG: me->status |= STEPPER_HOMED; return Q_TRAN(Stepper_idle);
	default: return Q_SUPER(&Stepper_homing);
    }
}
static QState Stepper_homing_up_stopping(Stepper* const me) {
    switch (Q_SIG(me)) {
    case Q_ENTRY_SIG:
        //QActive_arm(&me->super, 2*BSP_TICKS_PER_SEC);//2 sec should be enough?
        dSPIN_Soft_Stop(Stepper_id(me));
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
        dSPIN_Run(Stepper_id(me), FWD, HOMING_SPEED);
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
    //case Q_ENTRY_SIG: me->status &= ~STEPPER_HOMED; return Q_HANDLED();
    case Z_STEP_LOSS_SIG: me->status |= STEPPER_LOST; return Q_HANDLED();
    case Z_ALARM_SIG:
		if(Q_PAR(me) & dSPIN_STATUS_HIZ) me->status |= STEPPER_Z;
		if(Q_PAR(me) & dSPIN_STATUS_UVLO) me->status |= STEPPER_UNDERV;
		if(Q_PAR(me) & dSPIN_STATUS_OCD) me->status |= STEPPER_OVERC;
		if(Q_PAR(me) & (dSPIN_STATUS_TH_WRN | dSPIN_STATUS_TH_SD))
			me->status |= STEPPER_TEMP;
    	return Q_HANDLED();
	default: return Q_SUPER(&QHsm_top);
    }
}
static QState Stepper_idle(Stepper* const me) {
    switch (Q_SIG(me)) {
    case Q_ENTRY_SIG: {
    	uint8_t zone = Stepper_setPosZone(me);
		QActive_post((QActive*)&AO_zrp, Z_IDLE_SIG, me->status);
    	switch(zone) {
    	case Z_TOP_SIG: return Q_TRAN(&Stepper_top);
    	case Z_BOTTOM_SIG: return Q_TRAN(&Stepper_bottom);
    	default: return Q_HANDLED();
    	}
    }
    case Z_HOME_SIG: return Q_TRAN(&Stepper_homing);
    case Z_GO_SIG:
    	dSPIN_Go_To(Stepper_id(me), Q_PAR(me));
    	return Q_TRAN(&Stepper_moving);
	default: return Q_SUPER(&Stepper_on);
    }
}
static QState Stepper_top(Stepper* const me) {
    switch (Q_SIG(me)) {
    case Z_GO_SIG:
    	if(Q_PAR(me) < Stepper_pos(me)) {
			dSPIN_Go_To(Stepper_id(me), Q_PAR(me));
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
    	if(Q_PAR(me) > Stepper_pos(me)) {
			dSPIN_Go_To(Stepper_id(me), Q_PAR(me));
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

    status = dSPIN_Get_Status(Stepper_id(me));
	Q_ALLEGE(status == 0);//a sanity check on SPI loopback

	//SpiaRegs.SPIFFTX.bit.SPIRST = 0;//resume FIFOs; SPI FIFO config unchanged
	//SpiaRegs.SPICCR.bit.SPISWRESET = FALSE;//Enable SPI

	EALLOW;
	SpiaRegs.SPICCR.bit.SPILBK = FALSE;//Loopback mode; uncomment for test
    //Reset FIFO
    //SpiaRegs.SPIFFTX.bit.TXFIFO = 0;//Reset FIFO pointer to 0, and hold in reset
    //SpiaRegs.SPIFFTX.bit.TXFIFO = 1;//Reenable tx FIFO
    //SpiaRegs.SPIFFRX.bit.RXFIFORESET = 0;
    //SpiaRegs.SPIFFRX.bit.RXFIFORESET = 1;
	EDIS;

	dSPIN_Soft_Stop(Stepper_id(me));
	dSPIN_Reset_Device(Stepper_id(me));

    if(dSPIN_Busy_HW(Stepper_id(me))) return Q_TRAN(&Stepper_off);
    status = dSPIN_Get_Status(Stepper_id(me));

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
	dSPIN_Registers_Set(Stepper_id(me), &dSPIN_RegsStruct);

    status = dSPIN_Get_Status(Stepper_id(me));
    if(!(status & dSPIN_STATUS_HIZ)
    	|| !(status & dSPIN_STATUS_BUSY)
    	|| dSPIN_Busy_HW(Stepper_id(me)))
		return Q_TRAN(&Stepper_off);

	return Q_TRAN(&Stepper_idle);
}

#define AXIS_IS_OFF    0x0
#define AXIS_IS_ON     0x2
#define AXIS_IS_IDLE   AXIS_IS_ON
#define AXIS_IS_MOVING (AXIS_IS_ON | 0x1)
typedef struct ZRP {
/* protected: */
    QActive super;//must be the first element of the struct for inheritance
/* private: */
// public:
    uint32_t axis_status[N_STEPPER];
} ZRP;
//protected: //necessary forward declaration
ZRP AO_zrp;//ZRP singleton
static QState ZRP_allon(ZRP* const me) {
	int i;
    switch(Q_SIG(me)) {
	default: return Q_SUPER(&QHsm_top);
    }
}
static QState ZRP_someoff(ZRP* const me) {
	int i;
    switch(Q_SIG(me)) {
    case Q_ENTRY_SIG:
    	for(i=0; i < N_STEPPER; ++i) me->axis_status[i] = 0;
    	return Q_HANDLED();
    case Z_IDLE_SIG: {
    	uint8_t id = Q_PAR(me) & 0x3;
    	Q_ASSERT(id < N_STEPPER);
    	me->axis_status[id] = (Q_PAR(me) & 0xFFFFFFFC) | AXIS_IS_IDLE;
    	for(id = TRUE, i=0; i < N_STEPPER; ++i)
    		if(!(me->axis_status[i] & AXIS_IS_IDLE)) { id = FALSE; break; }
    	return id ? Q_TRAN(&ZRP_allon) : Q_HANDLED();
    }
	default: return Q_SUPER(&QHsm_top);
    }
}
static QState ZRP_initial(ZRP* const me) {
	return Q_SUPER(&ZRP_someoff);
}
void ZRP_init(void) {
    AO_stepper.status = 0;
    QActive_ctor(&AO_stepper.super, Q_STATE_CAST(&Stepper_initial));

    QActive_ctor(&AO_zrp.super, Q_STATE_CAST(&ZRP_initial));
}
