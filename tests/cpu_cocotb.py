import cocotb
from cocotb.clock import Clock
from cocotb.triggers import Timer, RisingEdge, ReadOnly
from cocotb.monitors import Monitor
from cocotb.drivers import BitDriver
from cocotb.binary import BinaryValue
from cocotb.regression import TestFactory
from cocotb.scoreboard import Scoreboard
from cocotb.result import TestFailure, TestSuccess

from cpu_output import parse_cycle_output

# From cpu/constants.svh
DEBUG_BYTES = 32

@cocotb.test()
async def test_cpu(dut):
    """Setup CPUtestbench and run a test."""

    # Start clock running in background
    cocotb.fork(Clock(dut.cpu_clk, 10, 'us').start(start_high=False))
    clkedge = RisingEdge(dut.cpu_clk)

    # Reset CPU
    dut.cpu_nreset <= 0
    await clkedge
    dut.cpu_nreset <= 1
    dut._log.debug('Reset complete')

    for cycle_count in range(32):
        dut._log.debug(f'Running CPU cycle {cycle_count}')
        debug_port_bytes = dut.cpu_debug_port_vector.value.integer.to_bytes(DEBUG_BYTES-1, 'big')
        parse_cycle_output(cycle_count, debug_port_bytes)
        await clkedge


# Register the test.
#factory = TestFactory(run_test)
#factory.generate_tests()
