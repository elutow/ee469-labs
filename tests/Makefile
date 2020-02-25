#!/usr/bin/make -f

SIM=verilator
export VERILATOR_ROOT=$(shell dirname $(shell dirname $(shell which verilator_bin)))/share/verilator
export VERILATOR_BIN=../../bin/verilator_bin
export VERILATOR_COVERAGE_BIN=../../bin/verilator_coverage
export VERILATOR_TRACE=1
export PYTHON_BIN?=python

ifeq ($(OS),Msys)
PYTHONPATH := $(CURDIR)/..;$(PYTHONPATH)
else
PYTHONPATH := $(CURDIR)/..:$(PYTHONPATH)
endif

# Set clock precision for Verilator to improve performance
COCOTB_HDL_TIMEPRECISION = 1us

VERILOG_SOURCES ?= $(CURDIR)/*.sv
# Verilog dut
TOPLEVEL ?= foo
# Python modules containing test functions
MODULE ?= foo_cocotb
# Extra Verilator options for testing code
EXTRA_ARGS += --x-assign unique --x-initial unique --assert
# NOTE: The following may iincrease tracing file size dramatically
#EXTRA_ARGS += --trace-coverage

include $(shell cocotb-config --makefiles)/Makefile.inc
include $(shell cocotb-config --makefiles)/Makefile.sim
