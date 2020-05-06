#
# Makefile for RiscVToo project
#

# Name of Vivado project.
PROJNAME=RiscVToo
SRCDIR=$(PROJNAME).srcs

ifndef XILINX_VIVADO
$(error XILINX_VIVADO must be set to point to Xilinx tools)
endif

VIVADO=$(XILINX_VIVADO)/bin/vivado

.PHONY: default project runtests

default: project

PROJFILE=$(PROJNAME)/$(PROJNAME).xpr

# Mem files for small tests and simulation.
TESTS=test1 test2 test3 testcsr test_timer test_too
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

runtests: $(PROJFILE)
	$(VIVADO) -mode batch -source $(SRCDIR)/scripts/runtests.tcl
