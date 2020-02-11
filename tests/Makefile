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

include $(shell cocotb-config --makefiles)/Makefile.inc
include $(shell cocotb-config --makefiles)/Makefile.sim
