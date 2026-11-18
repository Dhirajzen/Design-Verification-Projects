# SPI UVM verification - build and run
#
# Open-source flow: Verilator 5.x (--timing) + the UVM library from
# https://github.com/antmicro/uvm-verilator (a UVM 1800.2-2017 port for Verilator).
# Constraint solving in Verilator needs the z3 solver on PATH (pip install z3-solver).
#
#   make UVM_HOME=/path/to/uvm-verilator/src            # build + run the regression test
#   make run TEST=test SEED=7
#   make bug UVM_HOME=...                                # rebuild with an injected RTL bug, expect FAIL
#
# Commercial simulators (same file list, standard UVM):
#   vcs   -sverilog -ntb_opts uvm-1.2 -timescale=1ns/1ps $(SRCS) -top tb && ./simv +UVM_TESTNAME=test
#   xrun  -uvm -timescale 1ns/1ps $(SRCS) -top tb +UVM_TESTNAME=test
#   qrun  -uvm -timescale 1ns/1ps $(SRCS) -top tb +UVM_TESTNAME=test

UVM_HOME ?= $(HOME)/uvm-verilator/src
TEST     ?= test
SEED     ?= 1
DEFINES  ?=
VERILATOR ?= verilator

SRCS = tb_pkg.sv interface.sv checker.sv design.sv testbench.sv

VFLAGS = --main --exe -j 4 --output-groups 4 --timing --assert -Wno-fatal -Wno-lint -Wno-style \
         --top-module tb -o simv +define+UVM_NO_DPI +incdir+$(UVM_HOME) $(DEFINES)

# Verilator's pip build ships make flags for another compiler; these overrides
# make it build with the system g++ (no precompiled header, coroutines on).
MAKEFLAGS_VL = VK_PCH_I_FAST="-include Vtb__pch.h" VK_PCH_I_SLOW="-include Vtb__pch.h" \
               OPT="-fcoroutines" OPT_FAST=-O1 OPT_SLOW=-O0

.PHONY: all build run bug clean
all: run

build:
	$(VERILATOR) $(VFLAGS) $(UVM_HOME)/uvm_pkg.sv $(SRCS)
	$(MAKE) -C obj_dir -f Vtb.mk -j 4 $(MAKEFLAGS_VL)

run: build
	./obj_dir/simv +UVM_TESTNAME=$(TEST) +verilator+seed+$(SEED) +UVM_NO_RELNOTES | tee sim_$(TEST).log
	@grep -q "UVM_ERROR :    0" sim_$(TEST).log && grep -q "UVM_FATAL :    0" sim_$(TEST).log \
	  && echo "*** TEST $(TEST) PASSED ***" || (echo "*** TEST $(TEST) FAILED ***"; exit 1)

# Bug injection: the slave stores write data one address too high.
# The scoreboard must catch this; if this target "passes", the checker is broken.
bug:
	$(MAKE) clean
	$(MAKE) run DEFINES=+define+INJECT_ADDR_BUG || echo "Expected failure: injected bug was caught"

clean:
	rm -rf obj_dir sim_*.log
