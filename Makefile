#
# Makefile for RiscVToo project
#

# Name of Vivado project.
PROJNAME=RiscVToo
SRCDIR=$(PROJNAME).srcs

ifndef XILINX_VIVADO
$(error XILINX_VIVADO must be set to point to Xilinx tools)
endif
ifndef RISCV
$(error RISCV must be set to point to RiscV toolchain)
endif

VIVADO=$(XILINX_VIVADO)/bin/vivado

.PHONY: default project 

default: project

PROJFILE=$(PROJNAME)/$(PROJNAME).xpr

# Mem files for small tests and simulation.
TESTS=test1
TESTMEMFILES=$(addprefix $(SRCDIR)/testsw_1/, $(TESTS:=.mem))

project: $(PROJFILE)

$(PROJFILE): $(TESTMEMFILES)
ifeq ("","$(wildcard $(PROJFILE))")
	$(VIVADO) -mode batch -source project.tcl
else
	@echo Project already exists.
endif

$(TESTMEMFILES):
	(cd $(SRCDIR)/testsw_1 ; $(MAKE))
