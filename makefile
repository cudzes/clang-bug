#**********************************************************#
#file     makefile
#author   Rajmund Szymanski
#date     15.05.2017
#brief    STM32F4xx makefile.
#**********************************************************#

ARMCC      := c:/sys/arm/armclang/bin/
OPENOCD    := c:/sys/tools/openocd/bin-x64/openocd
STLINK     := c:/sys/tools/st-link/st-link_cli -Q -c SWD UR
QEMU       := c:/sys/qemu-arm/bin/qemu-system-gnuarmeclipse -semihosting -board STM32F4-Discovery

#----------------------------------------------------------#

PROJECT    ?= $(notdir $(CURDIR))
DEFS       ?= __MICROLIB
LIBS       ?=
DIRS       ?=
KEYS       ?=
INCS       ?=
OPTF       ?= z
SCRIPT     ?=

#----------------------------------------------------------#

DEFS       += STM32F407xx
KEYS       += .clang *

#----------------------------------------------------------#

AS         := $(ARMCC)armclang -x assembler-with-cpp
CC         := $(ARMCC)armclang
CXX        := $(ARMCC)armclang
COPY       := $(ARMCC)fromelf
DUMP       := $(ARMCC)fromelf
SIZE       := size
LD         := $(ARMCC)armlink
AR         := $(ARMCC)armar

RM         ?= rm -f

#----------------------------------------------------------#

DTREE       = $(foreach d,$(foreach k,$(KEYS),$(wildcard $1$k)),$(dir $d) $(call DTREE,$d/))

VPATH      := $(sort $(call DTREE,) $(foreach d,$(DIRS),$(call DTREE,$d/)))

#----------------------------------------------------------#

AS_EXT     := .S
C_EXT      := .c
CXX_EXT    := .cpp

INC_DIRS   := $(sort $(dir $(foreach d,$(VPATH),$(wildcard $d*.h $d*.hpp))))
LIB_DIRS   := $(sort $(dir $(foreach d,$(VPATH),$(wildcard $d*.lib))))
OBJ_SRCS   :=              $(foreach d,$(VPATH),$(wildcard $d*.o))
AS_SRCS    :=              $(foreach d,$(VPATH),$(wildcard $d*$(AS_EXT)))
C_SRCS     :=              $(foreach d,$(VPATH),$(wildcard $d*$(C_EXT)))
CXX_SRCS   :=              $(foreach d,$(VPATH),$(wildcard $d*$(CXX_EXT)))
LIB_SRCS   :=     $(notdir $(foreach d,$(VPATH),$(wildcard $d*.lib)))
ifeq ($(strip $(SCRIPT)),)
SCRIPT     :=  $(firstword $(foreach d,$(VPATH),$(wildcard $d*.sct)))
else
SCRIPT     :=  $(firstword $(foreach d,$(VPATH),$(wildcard $d$(SCRIPT))))
endif
ifeq ($(strip $(PROJECT)),)
PROJECT    :=     $(notdir $(CURDIR))
endif

AS_SRCS    := $(AS_SRCS:%.s=)

#----------------------------------------------------------#

BIN        := $(PROJECT).bin
ELF        := $(PROJECT).axf
HEX        := $(PROJECT).hex
HTM        := $(PROJECT).htm
LIB        := $(PROJECT).lib
LSS        := $(PROJECT).lss
MAP        := $(PROJECT).map

OBJS       := $(AS_SRCS:%$(AS_EXT)=%.o)
OBJS       += $(C_SRCS:%$(C_EXT)=%.o)
OBJS       += $(CXX_SRCS:%$(CXX_EXT)=%.o)
DEPS       := $(OBJS:.o=.d)
LSTS       := $(OBJS:.o=.lst)
TXTS       := $(OBJS:.o=.txt)

#----------------------------------------------------------#

COMMON_F    = --target=arm-arm-none-eabi -mthumb -mcpu=cortex-m4
ifneq ($(MAKECMDGOALS),qemu)
COMMON_F   += -mfpu=fpv4-sp-d16 -mfloat-abi=hard -ffast-math
endif
COMMON_F   += -O$(OPTF) -ffunction-sections -fdata-sections
ifneq ($(filter USE_LTO,$(DEFS)),)
COMMON_F   += -flto
endif
COMMON_F   += -Wall -Wextra # -Wpedantic
COMMON_F   += -MD -MP
COMMON_F   += # --debug

AS_FLAGS    =
C_FLAGS     = -std=gnu11
CXX_FLAGS   = -std=gnu++11 -fno-rtti -fno-exceptions
LD_FLAGS    = --strict --scatter=$(SCRIPT) --symbols --list_mapping_symbols
LD_FLAGS   += --map --info common,sizes,summarysizes,totals,veneers,unused --list=$(MAP) # --callgraph
ifneq ($(filter USE_LTO,$(DEFS)),)
LD_FLAGS   += --lto
endif

#----------------------------------------------------------#

ifneq ($(strip $(CXX_SRCS)),)
DEFS       += __USES_CXX
endif
ifneq ($(filter __MICROLIB,$(DEFS)),)
LD_FLAGS   += --library_type=microlib
endif

#----------------------------------------------------------#

empty=
comma=,
space=$(empty) $(empty)
clist=$(subst $(space),$(comma),$(strip $1))

#----------------------------------------------------------#

ARM_INC    := $(ARMCC)../include
ARM_LIB    := $(ARMCC)../lib

DEFS_F     := $(DEFS:%=-D%)
LIBS_F     := $(LIBS:%=%.lib)
LIBS_F     += $(LIB_SRCS)
OBJS_ALL   := $(sort $(OBJ_SRCS) $(OBJS))
INC_DIRS   += $(INCS:%=%/)
INC_DIRS   += $(ARMCC)../../RV31/INC/
INC_DIRS_F := $(INC_DIRS:%=-I%)
LIB_DIRS   += $(ARMCC)../../RV31/LIB/
LIB_DIRS_F := --libpath=$(ARM_LIB)
LIB_DIRS_F += --userlibpath=$(call clist, $(LIB_DIRS))

LD_FLAGS   += $(DEFS_F:%=--pd=%) $(INC_DIRS_F:%=--pd=%)

AS_FLAGS   += $(COMMON_F) $(DEFS_F) $(INC_DIRS_F)
C_FLAGS    += $(COMMON_F) $(DEFS_F) $(INC_DIRS_F)
CXX_FLAGS  += $(COMMON_F) $(DEFS_F) $(INC_DIRS_F)

#----------------------------------------------------------#

#openocd command-line
#interface and board/target settings (using the OOCD target-library here)
OOCD_INIT  := -f board/stm32f4discovery.cfg
OOCD_INIT  += -c init
OOCD_INIT  += -c targets
#commands to enable semihosting
OOCD_DEBG  := -c "arm semihosting enable"
#commands to prepare flash-write
OOCD_SAVE  := -c "reset halt"
#flash-write and -verify
OOCD_SAVE  += -c "flash write_image erase $(ELF)"
OOCD_SAVE  += -c "verify_image $(ELF)"
#reset target
OOCD_EXEC  := -c "reset run"
#terminate OOCD after programming
OOCD_EXIT  := -c shutdown

#----------------------------------------------------------#

all : $(LSS) print_elf_size

lib : $(LIB) print_size

$(ELF) : $(OBJS_ALL) $(SCRIPT)
	$(info Linking target: $(ELF))
ifeq ($(strip $(SCRIPT)),)
	$(error No scatter file in project)
endif
	$(LD) $(LD_FLAGS) $(OBJS_ALL) $(LIBS_F) $(LIB_DIRS_F) -o $@

$(LIB) : $(OBJS_ALL)
	$(info Building library: $(LIB))
	$(AR) -r $@ $?

$(OBJS) : $(MAKEFILE_LIST)

%.o : %$(AS_EXT)
	$(info Assembling file: $<)
	$(AS) $(AS_FLAGS) -c $< -o $@

%.o : %$(C_EXT)
	$(info Compiling file: $<)
	$(CC) $(C_FLAGS) -c $< -o $@

%.o : %$(CXX_EXT)
	$(info Compiling file: $<)
	$(CXX) $(CXX_FLAGS) -c $< -o $@

$(BIN) : $(ELF)
	$(info Creating BIN image: $(BIN))
	$(COPY) $< --bincombined --output $@

$(HEX) : $(ELF)
	$(info Creating HEX image: $(HEX))
	$(COPY) $< --i32combined --output $@

$(LSS) : $(ELF)
	$(info Creating extended listing: $(LSS))
	$(DUMP) $< --text -c -z --output $@

print_size :
	$(info Size of modules:)
	$(SIZE) -B -t --common $(OBJS_ALL)

print_elf_size : print_size
	$(info Size of target file:)
	$(SIZE) -B $(ELF)

GENERATED = $(BIN) $(ELF) $(HEX) $(HTM) $(LIB) $(LSS) $(MAP) $(DEPS) $(LSTS) $(OBJS) $(TXTS)

clean :
	$(info Removing all generated output files)
	$(RM) $(GENERATED)

flash : all $(HEX)
	$(info Programing device...)
	$(STLINK) -P $(HEX) -V -Rst
#	$(OPENOCD) $(OOCD_INIT) $(OOCD_SAVE) $(OOCD_EXEC) $(OOCD_EXIT)

debug : all
	$(info Debugging device...)
	$(OPENOCD) $(OOCD_INIT) $(OOCD_SAVE) $(OOCD_DEBG) $(OOCD_EXEC)

qemu : all
	$(info Emulating device...)
	$(QEMU) -image $(ELF)

reset :
	$(info Reseting device...)
	$(STLINK) -HardRst
#	$(OPENOCD) $(OOCD_INIT) $(OOCD_EXEC) $(OOCD_EXIT)

.PHONY : all lib clean flash debug reset qemu

-include $(DEPS)
