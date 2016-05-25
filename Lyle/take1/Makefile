PROJECT_NAME := ble_app_uart_s130_pca10028

export OUTPUT_FILENAME
#MAKEFILE_NAME := $(CURDIR)/$(word $(words $(MAKEFILE_LIST)),$(MAKEFILE_LIST))
MAKEFILE_NAME := $(MAKEFILE_LIST)
MAKEFILE_DIR := $(dir $(MAKEFILE_NAME) ) 

SDK_PATH = /uC/Nordic/nRF5_SDK_11.0.0
QPC = /QP/qpc
QP_PORT_DIR = $(QPC)/ports/arm-cm/qv/nRF51SDgnu

TEMPLATE_PATH = $(SDK_PATH)/components/toolchain/gcc

ifeq ($(OS),Windows_NT)
include $(TEMPLATE_PATH)/Makefile.windows
else
include $(TEMPLATE_PATH)/Makefile.posix
endif

MK := mkdir
RM := rm -rf

#echo suspend
ifeq ("$(VERBOSE)","1")
NO_ECHO := 
else
NO_ECHO := @
endif

# Toolchain commands
CC              := '$(GNU_INSTALL_ROOT)/bin/$(GNU_PREFIX)-gcc'
AS              := '$(GNU_INSTALL_ROOT)/bin/$(GNU_PREFIX)-as'
AR              := '$(GNU_INSTALL_ROOT)/bin/$(GNU_PREFIX)-ar' -r
LD              := '$(GNU_INSTALL_ROOT)/bin/$(GNU_PREFIX)-ld'
NM              := '$(GNU_INSTALL_ROOT)/bin/$(GNU_PREFIX)-nm'
OBJDUMP         := '$(GNU_INSTALL_ROOT)/bin/$(GNU_PREFIX)-objdump'
OBJCOPY         := '$(GNU_INSTALL_ROOT)/bin/$(GNU_PREFIX)-objcopy'
SIZE            := '$(GNU_INSTALL_ROOT)/bin/$(GNU_PREFIX)-size'

#function for removing duplicates in a list
remduplicates = $(strip $(if $1,$(firstword $1) $(call remduplicates,$(filter-out $(firstword $1),$1))))

CFLAGS = -DQ_SPY
NRF_FLAGS = \
	-DBOARD_PCA10028 \
	-DSOFTDEVICE_PRESENT \
	-DNRF51 \
	-DS130 \
	-DBLE_STACK_SUPPORT_REQD \
	-DSWI_DISABLE0
	
INC_PATHS = -Imsg -I$(QPC)/include -I$(QPC)/source -I$(QP_PORT_DIR)
#	-I$(QPC)/3rd_party/CMSIS/Include \

C_SOURCE_FILES = main.c msg.c

C_SOURCE_FILES += $(QPC)/include/qstamp.c \
	$(QPC)/source/qv.c \
	$(QPC)/source/qep_hsm.c \
	$(QPC)/source/qf_act.c \
	$(QPC)/source/qf_actq.c \
	$(QPC)/source/qf_defer.c \
	$(QPC)/source/qf_dyn.c \
	$(QPC)/source/qf_mem.c \
	$(QPC)/source/qf_ps.c \
	$(QPC)/source/qf_qact.c \
	$(QPC)/source/qf_qeq.c \
	$(QPC)/source/qf_time.c \
	$(QPC)/source/qs.c \
	$(QPC)/source/qs_rx.c \
#	$(QPC)/source/qs_fp.c
#	$(QPC)/source/qf_qmact.c \
	
C_SOURCE_FILES += \
	$(SDK_PATH)/examples/bsp/bsp.c $(SDK_PATH)/examples/bsp/bsp_btn_ble.c \
	$(SDK_PATH)/components/libraries/button/app_button.c \
	$(SDK_PATH)/components/libraries/util/app_error.c \
	$(SDK_PATH)/components/libraries/util/app_error_weak.c \
	$(SDK_PATH)/components/libraries/fifo/app_fifo.c
C_SOURCE_FILES += $(SDK_PATH)/components/libraries/timer/app_timer.c
C_SOURCE_FILES += $(SDK_PATH)/components/libraries/util/app_util_platform.c \
	$(SDK_PATH)/components/libraries/fstorage/fstorage.c
#	$(SDK_PATH)/components/libraries/util/nrf_assert.c
#	$(SDK_PATH)/components/libraries/util/nrf_log.c
# C_SOURCE_FILES += $(SDK_PATH)/components/libraries/uart/retarget.c
C_SOURCE_FILES += $(SDK_PATH)/components/drivers_nrf/delay/nrf_delay.c \
	$(SDK_PATH)/components/drivers_nrf/common/nrf_drv_common.c \
	$(SDK_PATH)/components/drivers_nrf/gpiote/nrf_drv_gpiote.c \
	$(SDK_PATH)/components/drivers_nrf/pstorage/pstorage.c \
	$(SDK_PATH)/components/drivers_nrf/uart/nrf_drv_uart.c
C_SOURCE_FILES += $(SDK_PATH)/components/drivers_nrf/spi_master/nrf_drv_spi.c
C_SOURCE_FILES += $(SDK_PATH)/components/drivers_nrf/timer/nrf_drv_timer.c
C_SOURCE_FILES += $(SDK_PATH)/components/ble/ble_services/ble_nus/ble_nus.c \
	$(SDK_PATH)/components/ble/ble_advertising/ble_advertising.c \
	$(SDK_PATH)/components/ble/common/ble_advdata.c \
	$(SDK_PATH)/components/ble/common/ble_conn_params.c \
	$(SDK_PATH)/components/ble/common/ble_srv_common.c \
	$(SDK_PATH)/components/toolchain/system_nrf51.c \
	$(SDK_PATH)/components/softdevice/common/softdevice_handler/softdevice_handler.c


#assembly files common to all targets
ASM_SOURCE_FILES  = $(SDK_PATH)/components/toolchain/gcc/gcc_startup_nrf51.s

#includes common to all targets
INC_PATHS += -Iconfig/ble_app_uart_s130_pca10028
INC_PATHS += -Iconfig
INC_PATHS += -I$(SDK_PATH)/examples/bsp
#INC_PATHS += -I$(SDK_PATH)/components/drivers_nrf/clock
#INC_PATHS += -I$(SDK_PATH)/components/drivers_nrf/rtc
INC_PATHS += -I$(SDK_PATH)/components/drivers_nrf/common
INC_PATHS += -I$(SDK_PATH)/components/drivers_nrf/config
INC_PATHS += -I$(SDK_PATH)/components/drivers_nrf/hal
INC_PATHS += -I$(SDK_PATH)/components/drivers_nrf/delay
INC_PATHS += -I$(SDK_PATH)/components/drivers_nrf/gpiote
INC_PATHS += -I$(SDK_PATH)/components/drivers_nrf/pstorage
INC_PATHS += -I$(SDK_PATH)/components/drivers_nrf/spi_master
INC_PATHS += -I$(SDK_PATH)/components/drivers_nrf/timer
INC_PATHS += -I$(SDK_PATH)/components/drivers_nrf/uart
INC_PATHS += -I$(SDK_PATH)/components/libraries/timer
INC_PATHS += -I$(SDK_PATH)/components/libraries/fifo
INC_PATHS += -I$(SDK_PATH)/components/libraries/fstorage/config
INC_PATHS += -I$(SDK_PATH)/components/libraries/util
INC_PATHS += -I$(SDK_PATH)/components/libraries/button
INC_PATHS += -I$(SDK_PATH)/components/libraries/fstorage
INC_PATHS += -I$(SDK_PATH)/components/libraries/uart
INC_PATHS += -I$(SDK_PATH)/components/libraries/experimental_section_vars
INC_PATHS += -I$(SDK_PATH)/components/softdevice/s130/headers
INC_PATHS += -I$(SDK_PATH)/components/softdevice/s130/headers/nrf51
INC_PATHS += -I$(SDK_PATH)/components/softdevice/common/softdevice_handler
INC_PATHS += -I$(SDK_PATH)/components/ble/common
INC_PATHS += -I$(SDK_PATH)/components/ble/ble_advertising
INC_PATHS += -I$(SDK_PATH)/components/device
INC_PATHS += -I$(SDK_PATH)/components/ble/ble_services/ble_nus
INC_PATHS += -I$(SDK_PATH)/components/toolchain/CMSIS/Include
INC_PATHS += -I$(SDK_PATH)/components/toolchain/gcc
INC_PATHS += -I$(SDK_PATH)/components/toolchain

OBJECT_DIRECTORY = _build
LISTING_DIRECTORY = $(OBJECT_DIRECTORY)
OUTPUT_BINARY_DIRECTORY = $(OBJECT_DIRECTORY)

# Sorting removes duplicates
BUILD_DIRECTORIES := $(sort $(OBJECT_DIRECTORY) $(OUTPUT_BINARY_DIRECTORY) $(LISTING_DIRECTORY) )

CFLAGS += -mcpu=cortex-m0 -D__ARM_ARCH=6 -mfloat-abi=soft
CFLAGS += -mthumb -mabi=aapcs --std=gnu99
CFLAGS += -Werror -g #-Wall 
CFLAGS += $(NRF_FLAGS)
# keep every function in separate section. This will allow linker to dump unused functions
CFLAGS += -ffunction-sections -fdata-sections -fno-strict-aliasing
CFLAGS += -fno-builtin --short-enums

# keep every function in separate section. This will allow linker to dump unused functions
LDFLAGS += -Xlinker -Map=$(LISTING_DIRECTORY)/$(OUTPUT_FILENAME).map
LDFLAGS += -mthumb -mabi=aapcs -L $(TEMPLATE_PATH) -T$(LINKER_SCRIPT)
LDFLAGS += -mcpu=cortex-m0
# let linker to dump unused sections
LDFLAGS += -Wl,--gc-sections
# use newlib in nano version
LDFLAGS += --specs=nano.specs -lc -lnosys

# Assembler flags
ASMFLAGS += -x assembler-with-cpp -defsym=__ARM_ARCH=6
ASMFLAGS += $(NRF_FLAGS)

#default target - first one defined
default: clean nrf51422_xxac_s130

#building all targets
all: nrf51422_xxac_s130
#	$(NO_ECHO)$(MAKE) -f $(MAKEFILE_NAME) -C $(MAKEFILE_DIR) -e cleanobj
#	$(NO_ECHO)$(MAKE) -f $(MAKEFILE_NAME) -C $(MAKEFILE_DIR) -e nrf51422_xxac_s130

#target for printing all targets
help:
	@echo following targets are available:
	@echo 	nrf51422_xxac_s130
	@echo 	flash_softdevice

C_SOURCE_FILE_NAMES = $(notdir $(C_SOURCE_FILES))
C_PATHS = $(call remduplicates, $(dir $(C_SOURCE_FILES) ) )
C_OBJECTS = $(addprefix $(OBJECT_DIRECTORY)/, $(C_SOURCE_FILE_NAMES:.c=.o) )

ASM_SOURCE_FILE_NAMES = $(notdir $(ASM_SOURCE_FILES))
ASM_PATHS = $(call remduplicates, $(dir $(ASM_SOURCE_FILES) ))
ASM_OBJECTS = $(addprefix $(OBJECT_DIRECTORY)/, $(ASM_SOURCE_FILE_NAMES:.s=.o) )

vpath %.c $(C_PATHS)
vpath %.s $(ASM_PATHS)

OBJECTS = $(C_OBJECTS) $(ASM_OBJECTS)

nrf51422_xxac_s130: OUTPUT_FILENAME := nrf51422_xxac_s130
nrf51422_xxac_s130: LINKER_SCRIPT=ble_app_uart_gcc_nrf51.ld

nrf51422_xxac_s130: $(BUILD_DIRECTORIES) $(OBJECTS)
	@echo Linking target: $(OUTPUT_FILENAME).out
	$(NO_ECHO)$(CC) $(LDFLAGS) $(OBJECTS) $(LIBS) -lm -o $(OUTPUT_BINARY_DIRECTORY)/$(OUTPUT_FILENAME).out
	$(NO_ECHO)$(MAKE) -f $(MAKEFILE_NAME) -C $(MAKEFILE_DIR) -e finalize

## Create build directories
$(BUILD_DIRECTORIES):
	echo $(MAKEFILE_NAME)
	$(MK) $@

# Create objects from C SRC files
$(OBJECT_DIRECTORY)/%.o: %.c
	@echo Compiling file: $(notdir $<)
	$(NO_ECHO)$(CC) $(CFLAGS) $(INC_PATHS) -c -o $@ $<

# Assemble files
$(OBJECT_DIRECTORY)/%.o: %.s
	@echo Assembly file: $(notdir $<)
	$(NO_ECHO)$(CC) $(ASMFLAGS) $(INC_PATHS) -c -o $@ $<
# Link
$(OUTPUT_BINARY_DIRECTORY)/$(OUTPUT_FILENAME).out: $(BUILD_DIRECTORIES) $(OBJECTS)
	@echo Linking target: $(OUTPUT_FILENAME).out
	$(NO_ECHO)$(CC) $(LDFLAGS) $(OBJECTS) $(LIBS) -lm -o $(OUTPUT_BINARY_DIRECTORY)/$(OUTPUT_FILENAME).out
## Create binary .bin file from the .out file
$(OUTPUT_BINARY_DIRECTORY)/$(OUTPUT_FILENAME).bin: $(OUTPUT_BINARY_DIRECTORY)/$(OUTPUT_FILENAME).out
	@echo Preparing: $(OUTPUT_FILENAME).bin
	$(NO_ECHO)$(OBJCOPY) -O binary $(OUTPUT_BINARY_DIRECTORY)/$(OUTPUT_FILENAME).out $(OUTPUT_BINARY_DIRECTORY)/$(OUTPUT_FILENAME).bin

## Create binary .hex file from the .out file
$(OUTPUT_BINARY_DIRECTORY)/$(OUTPUT_FILENAME).hex: $(OUTPUT_BINARY_DIRECTORY)/$(OUTPUT_FILENAME).out
	@echo Preparing: $(OUTPUT_FILENAME).hex
	$(NO_ECHO)$(OBJCOPY) -O ihex $(OUTPUT_BINARY_DIRECTORY)/$(OUTPUT_FILENAME).out $(OUTPUT_BINARY_DIRECTORY)/$(OUTPUT_FILENAME).hex

finalize: genbin genhex echosize

genbin:
	@echo Preparing: $(OUTPUT_FILENAME).bin
	$(NO_ECHO)$(OBJCOPY) -O binary $(OUTPUT_BINARY_DIRECTORY)/$(OUTPUT_FILENAME).out $(OUTPUT_BINARY_DIRECTORY)/$(OUTPUT_FILENAME).bin

## Create binary .hex file from the .out file
genhex: 
	@echo Preparing: $(OUTPUT_FILENAME).hex
	$(NO_ECHO)$(OBJCOPY) -O ihex $(OUTPUT_BINARY_DIRECTORY)/$(OUTPUT_FILENAME).out $(OUTPUT_BINARY_DIRECTORY)/$(OUTPUT_FILENAME).hex
echosize:
	-@echo ''
	$(NO_ECHO)$(SIZE) $(OUTPUT_BINARY_DIRECTORY)/$(OUTPUT_FILENAME).out
	-@echo ''

clean:
	$(RM) $(BUILD_DIRECTORIES)

cleanobj:
	$(RM) $(BUILD_DIRECTORIES)/*.o
flash: nrf51422_xxac_s130
	@echo Flashing: $(OUTPUT_BINARY_DIRECTORY)/$<.hex
	nrfjprog --program $(OUTPUT_BINARY_DIRECTORY)/$<.hex -f nrf51  --sectorerase
	nrfjprog --reset -f nrf51

## Flash softdevice
flash_softdevice:
	@echo Flashing: s130_nrf51_2.0.0_softdevice.hex
	nrfjprog --program $(SDK_PATH)/components/softdevice/s130/hex/s130_nrf51_2.0.0_softdevice.hex -f nrf51 --chiperase
	nrfjprog --reset -f nrf51