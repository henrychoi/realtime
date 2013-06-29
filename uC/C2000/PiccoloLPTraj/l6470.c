#include "qpn_port.h" //To pick up N_TRAJ
#include "bsp.h"
#include "l6470.h"
Q_DEFINE_THIS_FILE

#pragma CODE_SECTION(dSPIN_Write_Byte, "ramfuncs");
uint8_t dSPIN_Write_Byte(uint8_t id, uint8_t byte) {
	volatile int i;
	//uint16_t tx = byte;
	uint8_t ret;
	switch(id) {/* nSS signal activation - low */
	case 0: GpioDataRegs.GPACLEAR.bit.GPIO19 = TRUE; break;
	default: Q_ERROR();
	}

	//t_setCS > 350 ns
	for(i = 0; i; --i);//This seems to flush the pipeline, and cause 2 us stall

	//SpiaRegs.SPIFFTX.bit.SPIRST = 1;//resume FIFOs; SPI FIFO config unchanged
	SpiaRegs.SPICCR.bit.SPISWRESET = TRUE;//Enable SPI
	/* SPI byte send */
	//tx <<= 8;
	//SpiaRegs.SPITXBUF = tx;
	SpiaRegs.SPIDAT = byte << 8;
	SpiaRegs.SPICTL.bit.TALK = TRUE;

	while(!SpiaRegs.SPISTS.bit.INT_FLAG);//while(!SpiaRegs.SPIFFRX.bit.RXFFST);
	ret = SpiaRegs.SPIDAT & 0x00FF;//ret = (uint8_t)(SpiaRegs.SPIRXBUF & 0x00FF);

	switch(id) {/* nSS signal deactivation - high */
	case 0: GpioDataRegs.GPASET.bit.GPIO19 = TRUE; break;
	default: Q_ERROR();
	}

	//SpiaRegs.SPIFFTX.bit.SPIRST = 0;//Disable FIFOs; SPI FIFO config unchanged
	SpiaRegs.SPICCR.bit.SPISWRESET = FALSE;//Disable SPI

	for(i = 0; i ; --i);//t_disCS > 800 ns

	//Q_ASSERT(!SpiaRegs.SPIFFRX.bit.RXFFOVF);//something really wrong!
	//SpiaRegs.SPIFFRX.bit.RXFFOVFCLR = 1;  // Clear Overflow flag
    //return SpiaRegs.SPIFFRX.bit.RXFFST ? SpiaRegs.SPIRXBUF : 0;
	return ret;
}
void dSPIN_Nop(uint8_t id) {
	dSPIN_Write_Byte(id, dSPIN_NOP);
}
/**
  * @brief  Issues dSPIN Get Param command.
  * @param  dSPIN register address
  * @retval Register value - 1 to 3 bytes (depends on register)
  */
uint32_t dSPIN_Get_Param(uint8_t id, dSPIN_Registers_TypeDef param)
{
	uint32_t temp = 0;
	uint32_t rx = 0;

	/* Send GetParam operation code to dSPIN */
	temp = dSPIN_Write_Byte(id, dSPIN_GET_PARAM | param);
	/* MSB should be 0, because no parameter is 4 bytes */
	//temp = temp << 24; rx |= temp;
	switch (param)
	{
		case dSPIN_ABS_POS: ;
		case dSPIN_MARK: ;
		case dSPIN_SPEED:
		   	temp = dSPIN_Write_Byte(id, (uint8_t)(0x00));
			temp = temp << 16;
			rx |= temp;
		case dSPIN_ACC: ;
		case dSPIN_DEC: ;
		case dSPIN_MAX_SPEED: ;
		case dSPIN_MIN_SPEED: ;
		case dSPIN_FS_SPD: ;
		case dSPIN_INT_SPD: ;
		case dSPIN_CONFIG: ;
		case dSPIN_STATUS:
		   	temp = dSPIN_Write_Byte(id, (uint8_t)(0x00));
			temp = temp << 8;
			rx |= temp;
		default:
		   	temp = dSPIN_Write_Byte(id, (uint8_t)(0x00));
			rx |= temp;
	}
	return rx;
}
void dSPIN_Set_Param(uint8_t id, dSPIN_Registers_TypeDef param, uint32_t value)
{
	uint32_t readback_val;

	/* Send SetParam operation code to dSPIN */
	dSPIN_Write_Byte(id, dSPIN_SET_PARAM | param);
	switch (param)
	{
		case dSPIN_ABS_POS: ;
		case dSPIN_MARK: ;
		case dSPIN_SPEED:
			/* Send parameter - byte 2 to dSPIN */
			dSPIN_Write_Byte(id, (uint8_t)(value >> 16));
		case dSPIN_ACC: ;
		case dSPIN_DEC: ;
		case dSPIN_MAX_SPEED: ;
		case dSPIN_MIN_SPEED: ;
		case dSPIN_FS_SPD: ;
		case dSPIN_INT_SPD: ;
		case dSPIN_CONFIG: ;
		case dSPIN_STATUS:
			/* Send parameter - byte 1 to dSPIN */
		   	dSPIN_Write_Byte(id, (uint8_t)(value >> 8));
		default:
			/* Send parameter - byte 0 to dSPIN */
		   	dSPIN_Write_Byte(id, (uint8_t)(value));
	}
	readback_val = dSPIN_Get_Param(id, param);
	Q_ALLEGE(readback_val == value);
}

/**
  * @brief  Issues dSPIN Run command.
  * @param  Movement direction (FWD, REV), Speed - 3 bytes
  * @retval None
  */
void dSPIN_Run(uint8_t id, dSPIN_Direction_TypeDef direction, uint32_t speed)
{
	/* Send RUN operation code to dSPIN */
	dSPIN_Write_Byte(id, dSPIN_RUN | direction);
	/* Send speed - byte 2 data dSPIN */
	dSPIN_Write_Byte(id, (uint8_t)(speed >> 16));
	/* Send speed - byte 1 data dSPIN */
	dSPIN_Write_Byte(id, (uint8_t)(speed >> 8));
	/* Send speed - byte 0 data dSPIN */
	dSPIN_Write_Byte(id, (uint8_t)(speed));
}

/**
  * @brief  Issues dSPIN Step Clock command.
  * @param  Movement direction (FWD, REV)
  * @retval None
  */
void dSPIN_Step_Clock(uint8_t id, dSPIN_Direction_TypeDef direction) {
	/* Send StepClock operation code to dSPIN */
	dSPIN_Write_Byte(id, dSPIN_STEP_CLOCK | direction);
}
void dSPIN_Move(uint8_t id, dSPIN_Direction_TypeDef direction, uint32_t n_step)
{
	/* Send Move operation code to dSPIN */
	dSPIN_Write_Byte(id, dSPIN_MOVE | direction);
	/* Send n_step - byte 2 data dSPIN */
	dSPIN_Write_Byte(id, (uint8_t)(n_step >> 16));
	/* Send n_step - byte 1 data dSPIN */
	dSPIN_Write_Byte(id, (uint8_t)(n_step >> 8));
	/* Send n_step - byte 0 data dSPIN */
	dSPIN_Write_Byte(id, (uint8_t)(n_step));
}
void dSPIN_Go_To(uint8_t id, uint32_t abs_pos) {
	/* Send GoTo operation code to dSPIN */
	dSPIN_Write_Byte(id, dSPIN_GO_TO);
	/* Send absolute position parameter - byte 2 data to dSPIN */
	dSPIN_Write_Byte(id, (uint8_t)(abs_pos >> 16));
	/* Send absolute position parameter - byte 1 data to dSPIN */
	dSPIN_Write_Byte(id, (uint8_t)(abs_pos >> 8));
	/* Send absolute position parameter - byte 0 data to dSPIN */
	dSPIN_Write_Byte(id, (uint8_t)(abs_pos));
}
void dSPIN_Go_To_Dir(uint8_t id
		, dSPIN_Direction_TypeDef direction, uint32_t abs_pos) {
	/* Send GoTo_DIR operation code to dSPIN */
	dSPIN_Write_Byte(id, dSPIN_GO_TO_DIR | direction);
	/* Send absolute position parameter - byte 2 data to dSPIN */
	dSPIN_Write_Byte(id, (uint8_t)(abs_pos >> 16));
	/* Send absolute position parameter - byte 1 data to dSPIN */
	dSPIN_Write_Byte(id, (uint8_t)(abs_pos >> 8));
	/* Send absolute position parameter - byte 0 data to dSPIN */
	dSPIN_Write_Byte(id, (uint8_t)(abs_pos));
}
void dSPIN_Go_Until(uint8_t id, dSPIN_Action_TypeDef action
		, dSPIN_Direction_TypeDef direction, uint32_t speed) {
	/* Send GoUntil operation code to dSPIN */
	dSPIN_Write_Byte(id, dSPIN_GO_UNTIL | action | direction);
	/* Send speed parameter - byte 2 data to dSPIN */
	dSPIN_Write_Byte(id, (uint8_t)(speed >> 16));
	/* Send speed parameter - byte 1 data to dSPIN */
	dSPIN_Write_Byte(id, (uint8_t)(speed >> 8));
	/* Send speed parameter - byte 0 data to dSPIN */
	dSPIN_Write_Byte(id, (uint8_t)(speed));
}
void dSPIN_Release_SW(uint8_t id
		, dSPIN_Action_TypeDef action, dSPIN_Direction_TypeDef direction) {
	dSPIN_Write_Byte(id, dSPIN_RELEASE_SW | action | direction);
}
void dSPIN_Go_Home(uint8_t id) {
	dSPIN_Write_Byte(id, dSPIN_GO_HOME);
}
void dSPIN_Go_Mark(uint8_t id) {
	dSPIN_Write_Byte(id, dSPIN_GO_MARK);
}
void dSPIN_Reset_Pos(uint8_t id) {
	dSPIN_Write_Byte(id, dSPIN_RESET_POS);
}
void dSPIN_Reset_Device(uint8_t id) {
	dSPIN_Write_Byte(id, dSPIN_RESET_DEVICE);
}
void dSPIN_Soft_Stop(uint8_t id) {
	dSPIN_Write_Byte(id, dSPIN_SOFT_STOP);
}
void dSPIN_Hard_Stop(uint8_t id) {
	dSPIN_Write_Byte(id, dSPIN_HARD_STOP);
}
void dSPIN_Soft_HiZ(uint8_t id) {
	dSPIN_Write_Byte(id, dSPIN_SOFT_HIZ);
}
void dSPIN_Hard_HiZ(uint8_t id) {
	dSPIN_Write_Byte(id, dSPIN_HARD_HIZ);
}
uint16_t dSPIN_Get_Status(uint8_t id) {
	uint16_t temp = 0;
	uint16_t rx = 0;

	/* Send GetStatus operation code to dSPIN */
	dSPIN_Write_Byte(id, dSPIN_GET_STATUS);
	/* Send zero byte / receive MSByte from dSPIN */
	temp = dSPIN_Write_Byte(id, (uint8_t)(0x00));
	temp = temp << 8;
	rx |= temp;
	/* Send zero byte / receive LSByte from dSPIN */
	temp = dSPIN_Write_Byte(id, (uint8_t)(0x00));
	rx |= temp;
	return rx;
}

/**
  * @brief  Checks if the dSPIN is Busy by hardware - active Busy signal.
  * @retval one if chip is busy, otherwise zero
  */
#pragma CODE_SECTION(dSPIN_Busy_HW, "ramfuncs");//place in RAM for speed
uint8_t dSPIN_Busy_HW(uint8_t id) {
	switch(id) {
	case 0:	return !GpioDataRegs.GPADAT.bit.GPIO0;
	default: Q_ERROR(); return 0;
	}
}

/**
  * @brief  Checks if the dSPIN is Busy by SPI - Busy flag bit in Status Register.
  * @param  None
  * @retval one if chip is busy, otherwise zero
  */
uint8_t dSPIN_Busy_SW(uint8_t id) {
	return !(dSPIN_Get_Status(id) & dSPIN_STATUS_BUSY);
}

/**
  * @brief  Checks dSPIN Flag signal.
  * @param  None
  * @retval one if Flag signal is active, otherwise zero
  */
uint8_t dSPIN_Alarm(uint8_t id) {
	switch(id) {
	case 0: return !GpioDataRegs.GPADAT.bit.GPIO1;
	default: Q_ERROR(); return 0;
	}
}

/**
  * @brief  Fills-in dSPIN configuration structure with default values.
  * @param  Structure address (pointer to struct)
  * @retval None
  */
void dSPIN_Regs_Struct_Reset(dSPIN_RegsStruct_TypeDef* dSPIN_RegsStruct) {
	dSPIN_RegsStruct->ABS_POS = 0;
	dSPIN_RegsStruct->EL_POS = 0;
	dSPIN_RegsStruct->MARK = 0;
	dSPIN_RegsStruct->SPEED = 0;
	dSPIN_RegsStruct->ACC = 0x08A;
	dSPIN_RegsStruct->DEC = 0x08A;
	dSPIN_RegsStruct->MAX_SPEED = 0x041;
	dSPIN_RegsStruct->MIN_SPEED = 0;
	dSPIN_RegsStruct->FS_SPD = 0x027;
	dSPIN_RegsStruct->KVAL_HOLD = 0x29;
	dSPIN_RegsStruct->KVAL_RUN = 0x29;
	dSPIN_RegsStruct->KVAL_ACC = 0x29;
	dSPIN_RegsStruct->KVAL_DEC = 0x29;
	dSPIN_RegsStruct->INT_SPD = 0x0408;
	dSPIN_RegsStruct->ST_SLP = 0x19;
	dSPIN_RegsStruct->FN_SLP_ACC = 0x29;
	dSPIN_RegsStruct->FN_SLP_DEC = 0x29;
	dSPIN_RegsStruct->K_THERM = 0;
	dSPIN_RegsStruct->OCD_TH = 0x8;
	dSPIN_RegsStruct->STALL_TH = 0x40;
	dSPIN_RegsStruct->STEP_MODE = 0x7;
	dSPIN_RegsStruct->ALARM_EN = 0xFF;
	dSPIN_RegsStruct->CONFIG = 0x2E88;
}

/**
  * @brief  Configures dSPIN internal registers with values in the config structure.
  * @param  Configuration structure address (pointer to configuration structure)
  * @retval None
  */
void dSPIN_Registers_Set(uint8_t id, dSPIN_RegsStruct_TypeDef* dSPIN_RegsStruct) {
	dSPIN_Set_Param(id, dSPIN_ABS_POS, dSPIN_RegsStruct->ABS_POS);
	dSPIN_Set_Param(id, dSPIN_EL_POS, dSPIN_RegsStruct->EL_POS);
	dSPIN_Set_Param(id, dSPIN_MARK, dSPIN_RegsStruct->MARK);
	dSPIN_Set_Param(id, dSPIN_SPEED, dSPIN_RegsStruct->SPEED);
	dSPIN_Set_Param(id, dSPIN_ACC, dSPIN_RegsStruct->ACC);
	dSPIN_Set_Param(id, dSPIN_DEC, dSPIN_RegsStruct->DEC);
	dSPIN_Set_Param(id, dSPIN_MAX_SPEED, dSPIN_RegsStruct->MAX_SPEED);
	dSPIN_Set_Param(id, dSPIN_MIN_SPEED, dSPIN_RegsStruct->MIN_SPEED);
	dSPIN_Set_Param(id, dSPIN_FS_SPD, dSPIN_RegsStruct->FS_SPD);
	dSPIN_Set_Param(id, dSPIN_KVAL_HOLD, dSPIN_RegsStruct->KVAL_HOLD);
	dSPIN_Set_Param(id, dSPIN_KVAL_RUN, dSPIN_RegsStruct->KVAL_RUN);
	dSPIN_Set_Param(id, dSPIN_KVAL_ACC, dSPIN_RegsStruct->KVAL_ACC);
	dSPIN_Set_Param(id, dSPIN_KVAL_DEC, dSPIN_RegsStruct->KVAL_DEC);
	dSPIN_Set_Param(id, dSPIN_INT_SPD, dSPIN_RegsStruct->INT_SPD);
	dSPIN_Set_Param(id, dSPIN_ST_SLP, dSPIN_RegsStruct->ST_SLP);
	dSPIN_Set_Param(id, dSPIN_FN_SLP_ACC, dSPIN_RegsStruct->FN_SLP_ACC);
	dSPIN_Set_Param(id, dSPIN_FN_SLP_DEC, dSPIN_RegsStruct->FN_SLP_DEC);
	dSPIN_Set_Param(id, dSPIN_K_THERM, dSPIN_RegsStruct->K_THERM);
	dSPIN_Set_Param(id, dSPIN_OCD_TH, dSPIN_RegsStruct->OCD_TH);
	dSPIN_Set_Param(id, dSPIN_STALL_TH, dSPIN_RegsStruct->STALL_TH);
	dSPIN_Set_Param(id, dSPIN_STEP_MODE, dSPIN_RegsStruct->STEP_MODE);
	dSPIN_Set_Param(id, dSPIN_ALARM_EN, dSPIN_RegsStruct->ALARM_EN);
	dSPIN_Set_Param(id, dSPIN_CONFIG, dSPIN_RegsStruct->CONFIG);
}
