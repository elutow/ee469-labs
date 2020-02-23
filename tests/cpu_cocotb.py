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

from cpu_output import parse_cycle_output

# Module to test
_MODULE = "cpu"

# From cpu/constants.svh
DEBUG_BYTES = 32

@cocotb.test()
async def test_cpu(cocotb_dut):
    """Setup CPUtestbench and run a test."""
    dut = DUTWrapper(cocotb_dut, _MODULE)

    # Start clock running in background
    cocotb.fork(Clock(dut.clk, 10, 'us').start(start_high=False))
    clkedge = RisingEdge(dut.clk)

    # Reset CPU
    dut.nreset <= 0
    await clkedge
    dut.nreset <= 1
    dut._log.debug('Reset complete')

    for cycle_count in range(32):
        dut._log.debug(f'Running CPU cycle {cycle_count}')
        debug_port_bytes = dut.cpu_debug_port_vector.value.integer.to_bytes(DEBUG_BYTES-1, 'big')
        parse_cycle_output(cycle_count, debug_port_bytes)
        await clkedge


# Register the test.
#factory = TestFactory(run_test)
#factory.generate_tests()
