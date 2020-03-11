import random

import cocotb
from cocotb.triggers import Timer

from _tests_common import (
    init_posedge_clk, read_data_memory_init, read_data_memory_word,
    write_data_memory_word
)

async def _setup_memaccessor(dut):
    clkedge = init_posedge_clk(dut.memaccessor_clk)

    # Reset and enable
    dut.memaccessor_nreset <= 0
    await clkedge
    dut.memaccessor_nreset <= 1

    return clkedge

@cocotb.test()
async def test_memaccessor_read(dut):
    """Test data memory reads"""

    clkedge = await _setup_memaccessor(dut)

    data_memory_init = read_data_memory_init()

    async def _test_read_addr(read_addr):
        dut.memaccessor_read_addr <= read_addr
        await clkedge
        # We need to wait a little since the values just became available
        # at the last clkedge
        await Timer(1, 'us')
        assert dut.memaccessor_read_value == read_data_memory_word(read_addr, data_memory_init)

    await _test_read_addr(0)
    await _test_read_addr(1)
    await _test_read_addr(2)
    await _test_read_addr(3)

@cocotb.test()
async def test_memaccessor_write(dut):
    """Test memaccessor writes"""

    clkedge = await _setup_memaccessor(dut)

    data_memory = read_data_memory_init()

    async def _test_write(test_addr):
        test_value = 0xdeadbeef
        # 1. Read orig values
        orig_value = read_data_memory_word(test_addr, data_memory)
        dut.memaccessor_read_addr <= test_addr
        # 2. Write new value to same location
        dut.memaccessor_write_enable <= 1
        dut.memaccessor_write_addr <= test_addr
        dut.memaccessor_write_value <= test_value
        await clkedge
        write_data_memory_word(test_addr, test_value, data_memory)
        # We need to wait a little since the values just became available
        # at the last clkedge
        await Timer(1, 'us')
        # 3. See if read picks up value on next clock cycle
        print(hex(dut.memaccessor_read_value.value.integer), hex(test_value))
        assert dut.memaccessor_read_value == test_value

        # 4. Disable write enable, see if read still picks up value (i.e. value actually committed)
        dut.memaccessor_write_enable <= 0
        dut.memaccessor_write_value <= 0xAABBCCDD
        await clkedge
        # We need to wait a little since the values just became available
        # at the last clkedge
        await Timer(1, 'us')
        assert dut.memaccessor_read_value == test_value

        # 5. Try changing offset of value within word, see if that reflects on reads

        async def _test_read(read_addr):
            dut.memaccessor_read_addr <= read_addr
            await clkedge
            # We need to wait a little since the values just became available
            # at the last clkedge
            await Timer(1, 'us')
            assert dut.memaccessor_read_value == read_data_memory_word(read_addr, data_memory)

        await _test_read(test_addr+1)
        await _test_read(test_addr-1)
        await _test_read(test_addr+2)
        await _test_read(test_addr-2)
        await _test_read(test_addr+3)
        await _test_read(test_addr-3)

        # Reset original value
        dut.memaccessor_write_enable <= 1
        dut.memaccessor_write_addr <= test_addr
        dut.memaccessor_write_value <= orig_value
        await clkedge
        write_data_memory_word(test_addr, orig_value, data_memory)

    await _test_write(4)
    await _test_write(5)
    await _test_write(6)
    await _test_write(7)
