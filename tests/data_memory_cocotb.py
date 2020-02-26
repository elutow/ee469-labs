import random

import cocotb
from cocotb.triggers import Timer

from _tests_common import init_posedge_clk, read_data_memory_init, read_data_memory_word

async def _setup_data_memory(dut):
    clkedge = init_posedge_clk(dut.data_memory_clk)

    # Reset and enable
    dut.data_memory_nreset <= 0
    await clkedge
    dut.data_memory_nreset <= 1

    return clkedge

# TOOD: Uncomment
#@cocotb.test()
async def test_data_memory_read(dut):
    """Test data memory reads"""

    clkedge = await _setup_data_memory(dut)

    data_memory_init = read_data_memory_init()

    async def _test_read_addr(read_addr):
        dut.data_memory_read_addr <= read_addr
        await clkedge
        # We need to wait a little since the values just became available
        # at the last clkedge
        await Timer(1, 'us')
        assert dut.data_memory_read_value == read_data_memory_word(read_addr, data_memory_init)

    await _test_read_addr(0)
    await _test_read_addr(1)
    await _test_read_addr(2)
    await _test_read_addr(3)

# TODO: Uncomment
#@cocotb.test()
async def test_data_memory_write(dut):
    """Test data memory writes"""

    clkedge = await _setup_data_memory(dut)

    # TODO
