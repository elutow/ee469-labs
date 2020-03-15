import random

import cocotb
from cocotb.triggers import Timer

from _tests_common import init_posedge_clk

async def _setup_regfilewriter(dut):
    clkedge = init_posedge_clk(dut.regfilewriter_clk)

    # Reset and enable
    dut.regfilewriter_nreset <= 0
    await clkedge
    dut.regfilewriter_nreset <= 1
    dut.regfilewriter_enable <= 1

    # Set default pc value
    current_pc = 20
    dut.regfilewriter_pc <= current_pc

    return clkedge, current_pc


def _cleanup_regfilewriter(dut):
    # Reset dut to initial state
    dut.regfilewriter_update_pc.setimmediatevalue(0)
    dut.regfilewriter_update_Rd.setimmediatevalue(0)
    dut.regfilewriter_enable.setimmediatevalue(0)


@cocotb.test()
async def test_regfilewriter_branch(dut):
    """Test regfilewriter regular branch"""

    clkedge, current_pc = await _setup_regfilewriter(dut)

    # Test regular branch
    dut.regfilewriter_memaccessor_inst <= int('eafffffa', 16) # b 0x68 (relative to 0x78)
    new_pc = 0x68
    dut.regfilewriter_update_pc <= 1
    dut.regfilewriter_new_pc <= new_pc
    dut.regfilewriter_update_Rd <= 0
    await clkedge
    # We need to wait a little since the values just became available
    # at the last clkedge
    await Timer(1, 'us')
    assert dut.regfilewriter_ready.value.integer
    assert not dut.regfilewriter_regfile_write_enable1.value.integer
    assert dut.regfilewriter_regfile_update_pc.value.integer
    assert dut.regfilewriter_regfile_new_pc == new_pc

    _cleanup_regfilewriter(dut)


@cocotb.test()
async def test_regfilewriter_branchlink(dut):
    """Test regfilewriter branch with link"""

    clkedge, current_pc = await _setup_regfilewriter(dut)

    # Test branch with link
    dut.regfilewriter_memaccessor_inst <= int('ebfffffb', 16) # bl 0x68 (relative to 0x74)
    dut.regfilewriter_update_Rd <= 1
    lr_init = 16
    dut.regfilewriter_Rd_value <= lr_init
    dut.regfilewriter_update_pc <= 1
    new_pc = 0x68
    dut.regfilewriter_new_pc <= new_pc
    await clkedge
    # We need to wait a little since the values just became available
    # at the last clkedge
    await Timer(1, 'us')
    assert dut.regfilewriter_ready.value.integer
    assert dut.regfilewriter_regfile_write_enable1.value.integer
    assert dut.regfilewriter_regfile_write_addr1 == 14 # link register
    assert dut.regfilewriter_regfile_write_value1 == lr_init
    assert dut.regfilewriter_regfile_update_pc.value.integer
    assert dut.regfilewriter_regfile_new_pc == new_pc

    _cleanup_regfilewriter(dut)


@cocotb.test()
async def test_regfilewriter_nonbranch_nonpc(dut):
    """Test regfilewriter non-branch instruction updating non-PC register"""

    clkedge, current_pc = await _setup_regfilewriter(dut)

    # Test non-branch instruction
    dut.regfilewriter_memaccessor_inst <= int('e79842a9', 16) # ldr r4, [r8, r9, lsr #5]
    Rd_value = 42 # r4
    dut.regfilewriter_update_Rd <= 1
    dut.regfilewriter_Rd_value <= Rd_value
    await clkedge
    # We need to wait a little since the values just became available
    # at the last clkedge
    await Timer(1, 'us')
    assert dut.regfilewriter_ready.value.integer
    assert not dut.regfilewriter_regfile_update_pc.value.integer
    assert dut.regfilewriter_regfile_write_enable1.value.integer
    assert dut.regfilewriter_regfile_write_addr1 == 4 # r4
    assert dut.regfilewriter_regfile_write_value1 == Rd_value

    _cleanup_regfilewriter(dut)


@cocotb.test()
async def test_regfilewriter_nonbranch_pc(dut):
    """Test regfilewriter non-branch instruction updating PC register"""

    clkedge, current_pc = await _setup_regfilewriter(dut)

    # Test write addr overriding PC logic
    dut.regfilewriter_memaccessor_inst <= int('e1a0f00e', 16) # mov pc, lr
    dut.regfilewriter_update_pc <= 0
    Rd_value = 20 # pc
    dut.regfilewriter_update_Rd <= 1
    dut.regfilewriter_Rd_value <= Rd_value
    await clkedge
    # We need to wait a little since the values just became available
    # at the last clkedge
    await Timer(1, 'us')
    assert dut.regfilewriter_ready.value.integer
    assert not dut.regfilewriter_regfile_update_pc.value.integer
    assert dut.regfilewriter_regfile_write_enable1.value.integer
    assert dut.regfilewriter_regfile_write_addr1 == 15 # pc
    assert dut.regfilewriter_regfile_write_value1 == Rd_value

    _cleanup_regfilewriter(dut)

@cocotb.test()
async def test_regfilewriter_pc_nonexe(dut):
    """Test regfilewriter pc updates on non-executing instruction"""

    # NOTE: This test does not really help because Verilator simply sets
    # 1'bX logic to zeroes

    clkedge, current_pc = await _setup_regfilewriter(dut)

    # Test write addr overriding PC logic
    dut.regfilewriter_memaccessor_inst <= int('01a0f00e', 16) # moveq	pc, lr
    dut.regfilewriter_update_pc <= 0
    Rd_value = 24 # pc, but it should not be written
    assert current_pc != Rd_value
    # update_Rd = 0 when it is not executed
    dut.regfilewriter_update_Rd <= 0
    dut.regfilewriter_Rd_value <= Rd_value
    await clkedge
    # We need to wait a little since the values just became available
    # at the last clkedge
    await Timer(1, 'us')
    assert dut.regfilewriter_ready.value.integer
    assert not dut.regfilewriter_regfile_update_pc.value.integer
    assert not dut.regfilewriter_regfile_write_enable1.value.integer

    _cleanup_regfilewriter(dut)
