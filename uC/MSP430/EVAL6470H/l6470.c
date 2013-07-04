#include "l6470.h"

uint8_t dSPIN_Write_Byte(uint8_t byte) {
	//volatile int i;
	uint8_t ret;
	USICTL0 &= ~USISWRST;//Pull down to RELEASE UART reset for operation
  	P1OUT &= ~BIT4;//Pull nCS down to select the IC
	//t_setCS > 350 ns
	//for(i = 0; i; --i);//This seems to flush the pipeline, and cause 2 us stall
	//ret = USISRL;//clear overrun error
	USISRL = byte;//load data
	//USISRH = byte;//load data
	USICNT = 8;//tell uC how many bits to send

	while(!(USICTL1 & USIIFG));
	ret = USISRL;

  	P1OUT |= BIT4;//Pull nCS up to deselect the IC
	USICTL0 |= USISWRST;//Pull up RELEASE UART reset to hold SPI in reset
	//for(i = 0; i ; --i);//t_disCS > 800 ns
	return ret;
}
/**
  * @brief  Issues dSPIN Get Param command.
  * @param  dSPIN register address
  * @retval Register value - 1 to 3 bytes (depends on register)
  */
uint32_t dSPIN_Get_Param(dSPIN_Registers_TypeDef param)
{
	uint32_t temp = 0;
	uint32_t rx = 0;

	/* Send GetParam operation code to dSPIN */
	temp = dSPIN_Write_Byte(dSPIN_GET_PARAM | param);
	/* MSB should be 0, because no parameter is 4 bytes */
	//temp = temp << 24; rx |= temp;
	switch (param)
	{
		case dSPIN_ABS_POS: ;
		case dSPIN_MARK: ;
		case dSPIN_SPEED:
		   	temp = dSPIN_Write_Byte((uint8_t)(0x00));
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
		   	temp = dSPIN_Write_Byte((uint8_t)(0x00));
			temp = temp << 8;
			rx |= temp;
		default:
		   	temp = dSPIN_Write_Byte((uint8_t)(0x00));
			rx |= temp;
	}
	return rx;
}
void dSPIN_Set_Param(dSPIN_Registers_TypeDef param, uint32_t value)
{
	uint32_t readback_val;

	/* Send SetParam operation code to dSPIN */
	dSPIN_Write_Byte(dSPIN_SET_PARAM | param);
	switch (param)
	{
		case dSPIN_ABS_POS: ;
		case dSPIN_MARK: ;
		case dSPIN_SPEED:
			/* Send parameter - byte 2 to dSPIN */
			dSPIN_Write_Byte((uint8_t)(value >> 16));
		case dSPIN_ACC: ;
		case dSPIN_DEC: ;
		case dSPIN_MAX_SPEED: ;
		case dSPIN_MIN_SPEED: ;
		case dSPIN_FS_SPD: ;
		case dSPIN_INT_SPD: ;
		case dSPIN_CONFIG: ;
		case dSPIN_STATUS:
			/* Send parameter - byte 1 to dSPIN */
		   	dSPIN_Write_Byte((uint8_t)(value >> 8));
		default:
			/* Send parameter - byte 0 to dSPIN */
		   	dSPIN_Write_Byte((uint8_t)(value));
	}
	readback_val = dSPIN_Get_Param(param);
	Q_ALLEGE(readback_val == value);
}

/**
  * @brief  Issues dSPIN Run command.
  * @param  Movement direction (FWD, REV), Speed - 3 bytes
  * @retval None
  */
void dSPIN_Run(dSPIN_Direction_TypeDef direction, uint32_t speed)
{
	/* Send RUN operation code to dSPIN */
	dSPIN_Write_Byte(dSPIN_RUN | direction);
	/* Send speed - byte 2 data dSPIN */
	dSPIN_Write_Byte((uint8_t)(speed >> 16));
	/* Send speed - byte 1 data dSPIN */
	dSPIN_Write_Byte((uint8_t)(speed >> 8));
	/* Send speed - byte 0 data dSPIN */
	dSPIN_Write_Byte((uint8_t)(speed));
}

/**
  * @brief  Issues dSPIN Step Clock command.
  * @param  Movement direction (FWD, REV)
  * @retval None
  */
void dSPIN_Step_Clock(dSPIN_Direction_TypeDef direction) {
	/* Send StepClock operation code to dSPIN */
	dSPIN_Write_Byte(dSPIN_STEP_CLOCK | direction);
}
void dSPIN_Move(dSPIN_Direction_TypeDef direction, uint32_t n_step)
{
	/* Send Move operation code to dSPIN */
	dSPIN_Write_Byte(dSPIN_MOVE | direction);
	/* Send n_step - byte 2 data dSPIN */
	dSPIN_Write_Byte((uint8_t)(n_step >> 16));
	/* Send n_step - byte 1 data dSPIN */
	dSPIN_Write_Byte((uint8_t)(n_step >> 8));
	/* Send n_step - byte 0 data dSPIN */
	dSPIN_Write_Byte((uint8_t)(n_step));
}
void dSPIN_Go_To(uint32_t abs_pos) {
	/* Send GoTo operation code to dSPIN */
	dSPIN_Write_Byte(dSPIN_GO_TO);
	/* Send absolute position parameter - byte 2 data to dSPIN */
	dSPIN_Write_Byte((uint8_t)(abs_pos >> 16));
	/* Send absolute position parameter - byte 1 data to dSPIN */
	dSPIN_Write_Byte((uint8_t)(abs_pos >> 8));
	/* Send absolute position parameter - byte 0 data to dSPIN */
	dSPIN_Write_Byte((uint8_t)(abs_pos));
}
void dSPIN_Go_To_Dir(uint8_t id
		, dSPIN_Direction_TypeDef direction, uint32_t abs_pos) {
	/* Send GoTo_DIR operation code to dSPIN */
	dSPIN_Write_Byte(dSPIN_GO_TO_DIR | direction);
	/* Send absolute position parameter - byte 2 data to dSPIN */
	dSPIN_Write_Byte((uint8_t)(abs_pos >> 16));
	/* Send absolute position parameter - byte 1 data to dSPIN */
	dSPIN_Write_Byte((uint8_t)(abs_pos >> 8));
	/* Send absolute position parameter - byte 0 data to dSPIN */
	dSPIN_Write_Byte((uint8_t)(abs_pos));
}
void dSPIN_Go_Until(dSPIN_Action_TypeDef action
		, dSPIN_Direction_TypeDef direction, uint32_t speed) {
	/* Send GoUntil operation code to dSPIN */
	dSPIN_Write_Byte(dSPIN_GO_UNTIL | action | direction);
	/* Send speed parameter - byte 2 data to dSPIN */
	dSPIN_Write_Byte((uint8_t)(speed >> 16));
	/* Send speed parameter - byte 1 data to dSPIN */
	dSPIN_Write_Byte((uint8_t)(speed >> 8));
	/* Send speed parameter - byte 0 data to dSPIN */
	dSPIN_Write_Byte((uint8_t)(speed));
}
uint16_t dSPIN_Get_Status() {
	uint16_t temp = 0;
	uint16_t rx = 0;

	/* Send GetStatus operation code to dSPIN */
	dSPIN_Write_Byte(dSPIN_GET_STATUS);
	/* Send zero byte / receive MSByte from dSPIN */
	temp = dSPIN_Write_Byte((uint8_t)(0x00));
	temp = temp << 8;
	rx |= temp;
	/* Send zero byte / receive LSByte from dSPIN */
	temp = dSPIN_Write_Byte((uint8_t)(0x00));
	rx |= temp;
	return rx;
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
void dSPIN_Registers_Set(dSPIN_RegsStruct_TypeDef* dSPIN_RegsStruct) {
	dSPIN_Set_Param(dSPIN_ABS_POS, dSPIN_RegsStruct->ABS_POS);
	dSPIN_Set_Param(dSPIN_EL_POS, dSPIN_RegsStruct->EL_POS);
	dSPIN_Set_Param(dSPIN_MARK, dSPIN_RegsStruct->MARK);
	dSPIN_Set_Param(dSPIN_SPEED, dSPIN_RegsStruct->SPEED);
	dSPIN_Set_Param(dSPIN_ACC, dSPIN_RegsStruct->ACC);
	dSPIN_Set_Param(dSPIN_DEC, dSPIN_RegsStruct->DEC);
	dSPIN_Set_Param(dSPIN_MAX_SPEED, dSPIN_RegsStruct->MAX_SPEED);
	dSPIN_Set_Param(dSPIN_MIN_SPEED, dSPIN_RegsStruct->MIN_SPEED);
	dSPIN_Set_Param(dSPIN_FS_SPD, dSPIN_RegsStruct->FS_SPD);
	dSPIN_Set_Param(dSPIN_KVAL_HOLD, dSPIN_RegsStruct->KVAL_HOLD);
	dSPIN_Set_Param(dSPIN_KVAL_RUN, dSPIN_RegsStruct->KVAL_RUN);
	dSPIN_Set_Param(dSPIN_KVAL_ACC, dSPIN_RegsStruct->KVAL_ACC);
	dSPIN_Set_Param(dSPIN_KVAL_DEC, dSPIN_RegsStruct->KVAL_DEC);
	dSPIN_Set_Param(dSPIN_INT_SPD, dSPIN_RegsStruct->INT_SPD);
	dSPIN_Set_Param(dSPIN_ST_SLP, dSPIN_RegsStruct->ST_SLP);
	dSPIN_Set_Param(dSPIN_FN_SLP_ACC, dSPIN_RegsStruct->FN_SLP_ACC);
	dSPIN_Set_Param(dSPIN_FN_SLP_DEC, dSPIN_RegsStruct->FN_SLP_DEC);
	dSPIN_Set_Param(dSPIN_K_THERM, dSPIN_RegsStruct->K_THERM);
	dSPIN_Set_Param(dSPIN_OCD_TH, dSPIN_RegsStruct->OCD_TH);
	dSPIN_Set_Param(dSPIN_STALL_TH, dSPIN_RegsStruct->STALL_TH);
	dSPIN_Set_Param(dSPIN_STEP_MODE, dSPIN_RegsStruct->STEP_MODE);
	dSPIN_Set_Param(dSPIN_ALARM_EN, dSPIN_RegsStruct->ALARM_EN);
	dSPIN_Set_Param(dSPIN_CONFIG, dSPIN_RegsStruct->CONFIG);
}
