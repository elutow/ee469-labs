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
async def test_cpu(dut):
    """Setup CPUtestbench and run a test."""

    # Start clock running in background
    cocotb.fork(Clock(dut.cpu_clk, 10, 'us').start(start_high=False))
    clkedge = RisingEdge(dut.cpu_clk)

    # Reset CPU
    dut.cpu_nreset <= 0
    await clkedge
    dut.cpu_nreset <= 1
    await clkedge

    # Wait 100 clock cycles
    for _ in range(100):
        await clkedge


# Register the test.
#factory = TestFactory(run_test)
#factory.generate_tests()
