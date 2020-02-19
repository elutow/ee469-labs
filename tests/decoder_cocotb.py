import random

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, ReadOnly
from cocotb.monitors import Monitor
from cocotb.drivers import BitDriver
from cocotb.binary import BinaryValue
from cocotb.regression import TestFactory
from cocotb.scoreboard import Scoreboard
from cocotb.result import TestFailure, TestSuccess


@cocotb.test()
async def run_test(dut):
    """Setup testbench and run a test."""

    #cocotb.fork(Clock(dut.c, 10, 'us').start(start_high=False))

    # NOTE: This will cause the decoder Verilog to throw an exception,
    # which unfortunately crashes verilator and cocotb right now
    #dut.decoder_inst.setimmediatevalue(0xFFFFFFFF)

    # Read instruction hex
    with open('cpu/lab1_code.hex') as lab1_code:
        for inst_hexstr in lab1_code.read().splitlines():
            dut._log.debug('Testing decoder instruction:', inst_hexstr)
            instr = int(inst_hexstr, 16)
            dut.decoder_inst.setimmediatevalue(instr)
            assert dut.decoder_inst.value.integer == instr
            # Ensure values are set properly (and enable viewing in GTKwave)
            await Timer(1, 'us')


# Register the test.
#factory = TestFactory(run_test)
#factory.generate_tests()
