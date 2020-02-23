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

from _tests_common import DUTWrapper

# Module to test
_MODULE = "regfile"

@cocotb.test()
async def run_test(cocotb_dut):
    """Setup testbench and run a test."""
    dut = DUTWrapper(cocotb_dut, _MODULE)

    #cocotb.fork(Clock(dut.c, 10, 'us').start(start_high=False))

    # NOTE: This will cause the decoder Verilog to throw an exception,
    # which unfortunately crashes verilator and cocotb right now
    #dut.decoder_inst.setimmediatevalue(0xFFFFFFFF)

    # TODO: Verify single-cycle reads
    # TODO: Verify single-cycle writes
    # Read instruction hex
    with open('cpu/lab2_code.hex') as lab1_code:
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
