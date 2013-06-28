#include "qpn_port.h"
#include "bsp.h"
#include "stepper.h"

Q_DEFINE_THIS_FILE

/** @defgroup dSPIN register bits / masks
  * @{
  */

/* dSPIN electrical position register masks */
#define dSPIN_ELPOS_STEP_MASK			((uint8_t)0xC0)
#define dSPIN_ELPOS_MICROSTEP_MASK		((uint8_t)0x3F)

/* dSPIN min speed register bit / mask */
#define dSPIN_LSPD_OPT			((uint16_t)0x1000)
#define dSPIN_MIN_SPEED_MASK	((uint16_t)0x0FFF)


/* Exported types ------------------------------------------------------------*/

/**
  * @brief dSPIN Init structure definition
  */
typedef struct {
  uint32_t ABS_POS;
  uint16_t EL_POS;
  uint32_t MARK;
  uint32_t SPEED;
  uint16_t ACC;
  uint16_t DEC;
  uint16_t MAX_SPEED;
  uint16_t MIN_SPEED;
  uint16_t FS_SPD;
  uint8_t  KVAL_HOLD;
  uint8_t  KVAL_RUN;
  uint8_t  KVAL_ACC;
  uint8_t  KVAL_DEC;
  uint16_t INT_SPD;
  uint8_t  ST_SLP;
  uint8_t  FN_SLP_ACC;
  uint8_t  FN_SLP_DEC;
  uint8_t  K_THERM;
  uint8_t  ADC_OUT;
  uint8_t  OCD_TH;
  uint8_t  STALL_TH;
  uint8_t  STEP_MODE;
  uint8_t  ALARM_EN;
  uint16_t CONFIG;
} dSPIN_RegsStruct_TypeDef;

/* dSPIN overcurrent threshold options */
typedef enum {
	dSPIN_OCD_TH_375mA		=((uint8_t)0x00),
	dSPIN_OCD_TH_750mA		=((uint8_t)0x01),
	dSPIN_OCD_TH_1125mA		=((uint8_t)0x02),
	dSPIN_OCD_TH_1500mA		=((uint8_t)0x03),
	dSPIN_OCD_TH_1875mA		=((uint8_t)0x04),
	dSPIN_OCD_TH_2250mA		=((uint8_t)0x05),
	dSPIN_OCD_TH_2625mA		=((uint8_t)0x06),
	dSPIN_OCD_TH_3000mA		=((uint8_t)0x07),
	dSPIN_OCD_TH_3375mA		=((uint8_t)0x08),
	dSPIN_OCD_TH_3750mA		=((uint8_t)0x09),
	dSPIN_OCD_TH_4125mA		=((uint8_t)0x0A),
	dSPIN_OCD_TH_4500mA		=((uint8_t)0x0B),
	dSPIN_OCD_TH_4875mA		=((uint8_t)0x0C),
	dSPIN_OCD_TH_5250mA		=((uint8_t)0x0D),
	dSPIN_OCD_TH_5625mA		=((uint8_t)0x0E),
	dSPIN_OCD_TH_6000mA		=((uint8_t)0x0F)
} dSPIN_OCD_TH_TypeDef;

/* dSPIN STEP_MODE register masks */
typedef enum {
	dSPIN_STEP_MODE_STEP_SEL		=((uint8_t)0x07),
	dSPIN_STEP_MODE_SYNC_SEL		=((uint8_t)0x70),
	dSPIN_STEP_MODE_SYNC_EN			=((uint8_t)0x80)
} dSPIN_STEP_MODE_Masks_TypeDef;

 /* dSPIN STEP_MODE register options */
/* dSPIN STEP_SEL options */
typedef enum {
	dSPIN_STEP_SEL_1		=((uint8_t)0x00),
	dSPIN_STEP_SEL_1_2		=((uint8_t)0x01),
	dSPIN_STEP_SEL_1_4		=((uint8_t)0x02),
	dSPIN_STEP_SEL_1_8		=((uint8_t)0x03),
	dSPIN_STEP_SEL_1_16		=((uint8_t)0x04),
	dSPIN_STEP_SEL_1_32		=((uint8_t)0x05),
	dSPIN_STEP_SEL_1_64		=((uint8_t)0x06),
	dSPIN_STEP_SEL_1_128	=((uint8_t)0x07)
} dSPIN_STEP_SEL_TypeDef;

/* dSPIN SYNC_SEL options */
typedef enum {
	dSPIN_SYNC_SEL_1_2		=((uint8_t)0x00),
	dSPIN_SYNC_SEL_1		=((uint8_t)0x10),
	dSPIN_SYNC_SEL_2		=((uint8_t)0x20),
	dSPIN_SYNC_SEL_4		=((uint8_t)0x30),
	dSPIN_SYNC_SEL_8		=((uint8_t)0x40),
	dSPIN_SYNC_SEL_16		=((uint8_t)0x50),
	dSPIN_SYNC_SEL_32		=((uint8_t)0x60),
	dSPIN_SYNC_SEL_64		=((uint8_t)0x70)
} dSPIN_SYNC_SEL_TypeDef;

#define dSPIN_SYNC_EN		0x80

/* dSPIN ALARM_EN register options */
typedef enum {
	dSPIN_ALARM_EN_OVERCURRENT			=((uint8_t)0x01),
	dSPIN_ALARM_EN_THERMAL_SHUTDOWN		=((uint8_t)0x02),
	dSPIN_ALARM_EN_THERMAL_WARNING		=((uint8_t)0x04),
	dSPIN_ALARM_EN_UNDER_VOLTAGE		=((uint8_t)0x08),
	dSPIN_ALARM_EN_STALL_DET_A			=((uint8_t)0x10),
	dSPIN_ALARM_EN_STALL_DET_B			=((uint8_t)0x20),
	dSPIN_ALARM_EN_SW_TURN_ON			=((uint8_t)0x40),
	dSPIN_ALARM_EN_WRONG_NPERF_CMD		=((uint8_t)0x80)
} dSPIN_ALARM_EN_TypeDef;

/* dSPIN Config register masks */
typedef enum {
	dSPIN_CONFIG_OSC_SEL					=((uint16_t)0x0007),
	dSPIN_CONFIG_EXT_CLK					=((uint16_t)0x0008),
	dSPIN_CONFIG_SW_MODE					=((uint16_t)0x0010),
	dSPIN_CONFIG_EN_VSCOMP					=((uint16_t)0x0020),
	dSPIN_CONFIG_OC_SD						=((uint16_t)0x0080),
	dSPIN_CONFIG_POW_SR						=((uint16_t)0x0300),
	dSPIN_CONFIG_F_PWM_DEC					=((uint16_t)0x1C00),
	dSPIN_CONFIG_F_PWM_INT					=((uint16_t)0xE000)
} dSPIN_CONFIG_Masks_TypeDef;

/* dSPIN Config register options */
typedef enum {
	dSPIN_CONFIG_INT_16MHZ					=((uint16_t)0x0000),
	dSPIN_CONFIG_INT_16MHZ_OSCOUT_2MHZ		=((uint16_t)0x0008),
	dSPIN_CONFIG_INT_16MHZ_OSCOUT_4MHZ		=((uint16_t)0x0009),
	dSPIN_CONFIG_INT_16MHZ_OSCOUT_8MHZ		=((uint16_t)0x000A),
	dSPIN_CONFIG_INT_16MHZ_OSCOUT_16MHZ		=((uint16_t)0x000B),
	dSPIN_CONFIG_EXT_8MHZ_XTAL_DRIVE		=((uint16_t)0x0004),
	dSPIN_CONFIG_EXT_16MHZ_XTAL_DRIVE		=((uint16_t)0x0005),
	dSPIN_CONFIG_EXT_24MHZ_XTAL_DRIVE		=((uint16_t)0x0006),
	dSPIN_CONFIG_EXT_32MHZ_XTAL_DRIVE		=((uint16_t)0x0007),
	dSPIN_CONFIG_EXT_8MHZ_OSCOUT_INVERT		=((uint16_t)0x000C),
	dSPIN_CONFIG_EXT_16MHZ_OSCOUT_INVERT	=((uint16_t)0x000D),
	dSPIN_CONFIG_EXT_24MHZ_OSCOUT_INVERT	=((uint16_t)0x000E),
	dSPIN_CONFIG_EXT_32MHZ_OSCOUT_INVERT	=((uint16_t)0x000F)
} dSPIN_CONFIG_OSC_MGMT_TypeDef;

typedef enum {
	dSPIN_CONFIG_SW_HARD_STOP		=((uint16_t)0x0000),
	dSPIN_CONFIG_SW_USER			=((uint16_t)0x0010)
} dSPIN_CONFIG_SW_MODE_TypeDef;

typedef enum {
	dSPIN_CONFIG_VS_COMP_DISABLE	=((uint16_t)0x0000),
	dSPIN_CONFIG_VS_COMP_ENABLE		=((uint16_t)0x0020)
} dSPIN_CONFIG_EN_VSCOMP_TypeDef;

typedef enum {
	dSPIN_CONFIG_OC_SD_DISABLE		=((uint16_t)0x0000),
	dSPIN_CONFIG_OC_SD_ENABLE		=((uint16_t)0x0080)
} dSPIN_CONFIG_OC_SD_TypeDef;

typedef enum {
	dSPIN_CONFIG_SR_180V_us		=((uint16_t)0x0000),
	dSPIN_CONFIG_SR_290V_us		=((uint16_t)0x0200),
	dSPIN_CONFIG_SR_530V_us		=((uint16_t)0x0300)
} dSPIN_CONFIG_POW_SR_TypeDef;

typedef enum {
	dSPIN_CONFIG_PWM_DIV_1		=(((uint16_t)0x00)<<13),
	dSPIN_CONFIG_PWM_DIV_2		=(((uint16_t)0x01)<<13),
	dSPIN_CONFIG_PWM_DIV_3		=(((uint16_t)0x02)<<13),
	dSPIN_CONFIG_PWM_DIV_4		=(((uint16_t)0x03)<<13),
	dSPIN_CONFIG_PWM_DIV_5		=(((uint16_t)0x04)<<13),
	dSPIN_CONFIG_PWM_DIV_6		=(((uint16_t)0x05)<<13),
	dSPIN_CONFIG_PWM_DIV_7		=(((uint16_t)0x06)<<13)
} dSPIN_CONFIG_F_PWM_INT_TypeDef;

typedef enum {
	dSPIN_CONFIG_PWM_MUL_0_625		=(((uint16_t)0x00)<<10),
	dSPIN_CONFIG_PWM_MUL_0_75		=(((uint16_t)0x01)<<10),
	dSPIN_CONFIG_PWM_MUL_0_875		=(((uint16_t)0x02)<<10),
	dSPIN_CONFIG_PWM_MUL_1			=(((uint16_t)0x03)<<10),
	dSPIN_CONFIG_PWM_MUL_1_25		=(((uint16_t)0x04)<<10),
	dSPIN_CONFIG_PWM_MUL_1_5		=(((uint16_t)0x05)<<10),
	dSPIN_CONFIG_PWM_MUL_1_75		=(((uint16_t)0x06)<<10),
	dSPIN_CONFIG_PWM_MUL_2			=(((uint16_t)0x07)<<10)
} dSPIN_CONFIG_F_PWM_DEC_TypeDef;

/* Status Register options */
typedef enum {
	dSPIN_STATUS_MOT_STATUS_STOPPED			=(((uint16_t)0x0000)<<13),
	dSPIN_STATUS_MOT_STATUS_ACCELERATION	=(((uint16_t)0x0001)<<13),
	dSPIN_STATUS_MOT_STATUS_DECELERATION	=(((uint16_t)0x0002)<<13),
	dSPIN_STATUS_MOT_STATUS_CONST_SPD		=(((uint16_t)0x0003)<<13)
} dSPIN_STATUS_TypeDef;

/* dSPIN internal register addresses */
typedef enum {
	dSPIN_ABS_POS			=((uint8_t)0x01),
	dSPIN_EL_POS			=((uint8_t)0x02),
	dSPIN_MARK				=((uint8_t)0x03),
	dSPIN_SPEED				=((uint8_t)0x04),
	dSPIN_ACC				=((uint8_t)0x05),
	dSPIN_DEC				=((uint8_t)0x06),
	dSPIN_MAX_SPEED			=((uint8_t)0x07),
	dSPIN_MIN_SPEED			=((uint8_t)0x08),
	dSPIN_FS_SPD			=((uint8_t)0x15),
	dSPIN_KVAL_HOLD			=((uint8_t)0x09),
	dSPIN_KVAL_RUN			=((uint8_t)0x0A),
	dSPIN_KVAL_ACC			=((uint8_t)0x0B),
	dSPIN_KVAL_DEC			=((uint8_t)0x0C),
	dSPIN_INT_SPD			=((uint8_t)0x0D),
	dSPIN_ST_SLP			=((uint8_t)0x0E),
	dSPIN_FN_SLP_ACC		=((uint8_t)0x0F),
	dSPIN_FN_SLP_DEC		=((uint8_t)0x10),
	dSPIN_K_THERM			=((uint8_t)0x11),
	dSPIN_ADC_OUT			=((uint8_t)0x12),
	dSPIN_OCD_TH			=((uint8_t)0x13),
	dSPIN_STALL_TH			=((uint8_t)0x14),
	dSPIN_STEP_MODE			=((uint8_t)0x16),
	dSPIN_ALARM_EN			=((uint8_t)0x17),
	dSPIN_CONFIG			=((uint8_t)0x18),
	dSPIN_STATUS			=((uint8_t)0x19),
	dSPIN_RESERVED_REG1		=((uint8_t)0x1A),
	dSPIN_RESERVED_REG2		=((uint8_t)0x1B)
} dSPIN_Registers_TypeDef;

/* dSPIN command set */
typedef enum {
	dSPIN_NOP			=((uint8_t)0x00),
	dSPIN_SET_PARAM		=((uint8_t)0x00),
	dSPIN_GET_PARAM		=((uint8_t)0x20),
	dSPIN_RUN			=((uint8_t)0x50),
	dSPIN_STEP_CLOCK	=((uint8_t)0x58),
	dSPIN_MOVE			=((uint8_t)0x40),
	dSPIN_GO_TO			=((uint8_t)0x60),
	dSPIN_GO_TO_DIR		=((uint8_t)0x68),
	dSPIN_GO_UNTIL		=((uint8_t)0x82),
	dSPIN_RELEASE_SW	=((uint8_t)0x92),
	dSPIN_GO_HOME		=((uint8_t)0x70),
	dSPIN_GO_MARK		=((uint8_t)0x78),
	dSPIN_RESET_POS		=((uint8_t)0xD8),
	dSPIN_RESET_DEVICE	=((uint8_t)0xC0),
	dSPIN_SOFT_STOP		=((uint8_t)0xB0),
	dSPIN_HARD_STOP		=((uint8_t)0xB8),
	dSPIN_SOFT_HIZ		=((uint8_t)0xA0),
	dSPIN_HARD_HIZ		=((uint8_t)0xA8),
	dSPIN_GET_STATUS	=((uint8_t)0xD0),
	dSPIN_RESERVED_CMD1	=((uint8_t)0xEB),
	dSPIN_RESERVED_CMD2	=((uint8_t)0xF8)
} dSPIN_Commands_TypeDef;

/* dSPIN direction options */
typedef enum {
	FWD		=((uint8_t)0x01),
	REV		=((uint8_t)0x00)
} dSPIN_Direction_TypeDef;

/* dSPIN action options */
typedef enum {
	ACTION_RESET	=((uint8_t)0x00),
	ACTION_COPY		=((uint8_t)0x01)
} dSPIN_Action_TypeDef;
/**
  * @}
  */


/* Exported macro ------------------------------------------------------------*/
#define Speed_Steps_to_Par(steps) ((uint32_t)(((steps)*67.108864)+0.5))			/* Speed conversion, range 0 to 15625 steps/s */
#define AccDec_Steps_to_Par(steps) ((uint16_t)(((steps)*0.068719476736)+0.5))	/* Acc/Dec rates conversion, range 14.55 to 59590 steps/s2 */
#define MaxSpd_Steps_to_Par(steps) ((uint16_t)(((steps)*0.065536)+0.5))			/* Max Speed conversion, range 15.25 to 15610 steps/s */
#define MinSpd_Steps_to_Par(steps) ((uint16_t)(((steps)*4.194304)+0.5))			/* Min Speed conversion, range 0 to 976.3 steps/s */
#define FSSpd_Steps_to_Par(steps) ((uint16_t)((steps)*0.065536))				/* Full Step Speed conversion, range 7.63 to 15625 steps/s */
#define IntSpd_Steps_to_Par(steps) ((uint16_t)(((steps)*4.194304)+0.5))			/* Intersect Speed conversion, range 0 to 3906 steps/s */
#define Kval_Perc_to_Par(perc) ((uint8_t)(((perc)/0.390625)+0.5))				/* KVAL conversions, range 0.4% to 99.6% */
#define BEMF_Slope_Perc_to_Par(perc) ((uint8_t)(((perc)/0.00156862745098)+0.5))	/* BEMF compensation slopes, range 0 to 0.4% s/step */
#define KTherm_to_Par(KTherm) ((uint8_t)(((KTherm - 1)/0.03125)+0.5))			/* K_THERM compensation conversion, range 1 to 1.46875 */
#define StallTh_to_Par(StallTh) ((uint8_t)(((StallTh - 31.25)/31.25)+0.5))		/* Stall Threshold conversion, range 31.25mA to 4000mA */


#pragma CODE_SECTION(dSPIN_Write_Byte, "ramfuncs");
/**
  * @brief  Transmits/Receives one byte to/from dSPIN over SPI.
  * @param  Transmited byte
  * @retval Received byte
  */
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
	/* Send ReleaseSW operation code to dSPIN */
	dSPIN_Write_Byte(id, dSPIN_RELEASE_SW | action | direction);
}
void dSPIN_Go_Home(uint8_t id) {
	/* Send GoHome operation code to dSPIN */
	dSPIN_Write_Byte(id, dSPIN_GO_HOME);
}
void dSPIN_Go_Mark(uint8_t id) {
	/* Send GoMark operation code to dSPIN */
	dSPIN_Write_Byte(id, dSPIN_GO_MARK);
}
void dSPIN_Reset_Pos(uint8_t id) {
	/* Send ResetPos operation code to dSPIN */
	dSPIN_Write_Byte(id, dSPIN_RESET_POS);
}
void dSPIN_Reset_Device(uint8_t id) {
	/* Send ResetDevice operation code to dSPIN */
	dSPIN_Write_Byte(id, dSPIN_RESET_DEVICE);
}
void dSPIN_Soft_Stop(uint8_t id) {
	/* Send SoftStop operation code to dSPIN */
	dSPIN_Write_Byte(id, dSPIN_SOFT_STOP);
}
void dSPIN_Hard_Stop(uint8_t id) {
	/* Send HardStop operation code to dSPIN */
	dSPIN_Write_Byte(id, dSPIN_HARD_STOP);
}
void dSPIN_Soft_HiZ(uint8_t id) {
	/* Send SoftHiZ operation code to dSPIN */
	dSPIN_Write_Byte(id, dSPIN_SOFT_HIZ);
}
void dSPIN_Hard_HiZ(uint8_t id) {
	/* Send HardHiZ operation code to dSPIN */
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


//Normally, I hide the implementation; but if I arrange these active
//objects as an array in this application, I am forced to expose the
//struct detail
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
    case TOP_SIG:
    case BOTTOM_SIG:
    case STOP_SIG:
    	dSPIN_Soft_Stop(me->id);
    	return Q_HANDLED();
    case NBUSY_SIG: return Q_TRAN(&Stepper_idle);
	default: return Q_SUPER(&Stepper_on);
    }
}
static QState Stepper_homing(Stepper* const me) {
    switch (Q_SIG(me)) {
    case Q_INIT_SIG: return Q_TRAN(top_flag(me->id) ? &Stepper_homing_down
                                                    : &Stepper_homing_up);
    case Q_TIMEOUT_SIG://Give up homing on any of these events
    case TOP_SIG:
    case BOTTOM_SIG:
    case STOP_SIG:
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
    case NBUSY_SIG: me->lost = FALSE; return Q_TRAN(Stepper_idle);
	default: return Q_SUPER(&Stepper_homing);
    }
}
static QState Stepper_homing_up_stopping(Stepper* const me) {
    switch (Q_SIG(me)) {
    case Q_ENTRY_SIG:
        //QActive_arm(&me->super, 2*BSP_TICKS_PER_SEC);//2 sec should be enough?
        dSPIN_Soft_Stop(me->id);
        return Q_HANDLED();
    case NBUSY_SIG://begin the move downward
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
    case ABOVE_SIG: return Q_TRAN(Stepper_homing_up_stopping);
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
    case STEP_LOSS_SIG: me->lost = TRUE; return Q_HANDLED();
    case ALARM_SIG: me->alarm = Q_PAR(me); return Q_HANDLED();
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
    case HOME_SIG: return Q_TRAN(&Stepper_homing);
    case GO_SIG:
    	dSPIN_Go_To(me->id, Q_PAR(me));
    	return Q_TRAN(&Stepper_moving);
	default: return Q_SUPER(&Stepper_on);
    }
}
static QState Stepper_top(Stepper* const me) {
    switch (Q_SIG(me)) {
    case GO_SIG:
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
    case GO_SIG:
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
