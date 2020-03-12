import random

import cocotb
from cocotb.triggers import Timer

from _tests_common import (
    assert_eq, init_posedge_clk, read_data_memory_init, read_data_memory_word,
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
    """Test memaccessor reads"""

    clkedge = await _setup_memaccessor(dut)

    data_memory = read_data_memory_init()

    databranch_Rd_value = 0xbeefdead
    dut.memaccessor_databranch_Rd_value <= databranch_Rd_value
    dut.memaccessor_executor_update_pc <= 0
    dut.memaccessor_enable <= 1

    dut.memaccessor_executor_inst <= int('e5984000', 16) # ldr r4, [r8]
    Rn_value = 6 # r8
    dut.memaccessor_read_addr <= Rn_value
    dut.memaccessor_executor_update_Rd <= 1
    await clkedge
    # We need to wait a little since the values just became available
    # at the last clkedge
    await Timer(1, 'us')
    assert dut.memaccessor_ready.value.integer
    assert dut.memaccessor_update_Rd.value.integer
    assert_eq(dut.memaccessor_Rd_value, read_data_memory_word(Rn_value, data_memory))

    dut.memaccessor_enable <= 0

@cocotb.test()
async def test_memaccessor_write(dut):
    """Test memaccessor writes"""

    clkedge = await _setup_memaccessor(dut)

    data_memory = read_data_memory_init()

    databranch_Rd_value = 0xbeefdead
    dut.memaccessor_databranch_Rd_value <= databranch_Rd_value
    dut.memaccessor_executor_update_pc <= 0
    dut.memaccessor_enable <= 1

    dut._log.info("Test STR")
    dut.memaccessor_executor_inst <= int('e5885000', 16) # str r5, [r8]
    Rd_Rm_value = 0xdeadbeef # r5
    Rn_value = 1 # r8
    dut.memaccessor_write_enable <= 1
    dut.memaccessor_write_addr <= Rn_value
    dut.memaccessor_write_value <= Rd_Rm_value
    dut.memaccessor_executor_update_Rd <= 0
    await clkedge
    write_data_memory_word(Rn_value, Rd_Rm_value, data_memory)
    # We need to wait a little since the values just became available
    # at the last clkedge
    await Timer(1, 'us')
    dut.memaccessor_write_enable <= 0
    # STR should not update Rd
    assert dut.memaccessor_ready.value.integer
    assert not dut.memaccessor_update_Rd.value.integer

    dut._log.info("Verify STR with LDR")
    dut.memaccessor_executor_inst <= int('e5984000', 16) # ldr r4, [r8]
    Rn_value = 1 # r8
    dut.memaccessor_read_addr <= Rn_value
    dut.memaccessor_executor_update_Rd <= 1
    await clkedge
    # We need to wait a little since the values just became available
    # at the last clkedge
    await Timer(1, 'us')
    assert dut.memaccessor_ready.value.integer
    assert dut.memaccessor_update_Rd.value.integer
    assert_eq(dut.memaccessor_Rd_value, Rd_Rm_value)

    dut.memaccessor_enable <= 0
