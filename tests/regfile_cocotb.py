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

from _tests_common import init_posedge_clk

def _read_regfile_init(init_hex_path):
    with open(init_hex_path) as regfile_init_hex:
        hex_entries = regfile_init_hex.read().splitlines()
    return tuple(int(line, 16) for line in hex_entries if line)

@cocotb.test()
async def test_regfile(dut):
    """Test regfile"""

    clkedge = init_posedge_clk(dut.regfile_clk)
    regfile_init = _read_regfile_init('cpu/regfile_init.hex')

    # Reset
    dut.regfile_nreset <= 0
    await clkedge
    dut.regfile_nreset <= 1
    await clkedge
    dut._log.debug('Reset complete')

    # Test reads
    # NOTE: All regfile reads are clocked, so we set immediates here and then
    # wait for clkedge
    dut.regfile_read_inst.setimmediatevalue(int('e1540005', 16)) # cmp r4, r5
    dut.regfile_read_addr1.setimmediatevalue(4) # r4
    dut.regfile_read_addr2.setimmediatevalue(5) # r5

    await clkedge

    assert dut.regfile_read_value1.value.integer == regfile_init[4]
    assert dut.regfile_read_value2.value.integer == regfile_init[5]
    # Test new instruction right away
    dut.regfile_read_inst.setimmediatevalue(int('e08fe004', 16)) # add lr, pc, r4
    dut.regfile_read_addr1.setimmediatevalue(15) # pc
    dut.regfile_read_addr2.setimmediatevalue(4) # r4

    await clkedge

    # Since we didn't increment PC, and operand2 is not an immediate,
    # we should get pc + 12 = 0 + 12 = 12
    assert dut.regfile_read_value1 == 12
    assert dut.regfile_read_value2 == regfile_init[4]

# Register the test.
#factory = TestFactory(run_test)
#factory.generate_tests()
