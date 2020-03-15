import random

import cocotb
from cocotb.triggers import Timer

from _tests_common import assert_eq, init_posedge_clk

@cocotb.test()
async def test_decoder_assert(dut):
    """Test decoder assertions against the lab test code"""

    clkedge = init_posedge_clk(dut.decoder_clk)

    # Reset and enable
    dut.decoder_nreset <= 0
    await clkedge
    dut.decoder_nreset <= 1
    dut.decoder_enable <= 1

    # Read instruction hex
    with open('cpu/init/code.hex') as code_hex:
        for inst_hexstr in code_hex.read().splitlines():
            dut._log.debug('Testing decoder instruction:', inst_hexstr)
            instr = int(inst_hexstr, 16)
            dut.decoder_fetcher_inst.setimmediatevalue(instr)
            assert dut.decoder_fetcher_inst == instr
            await clkedge
            # We need to wait a little since the values just became available
            # at the last clkedge
            await Timer(1, 'us')
            assert dut.decoder_ready.value.integer
            assert dut.decoder_fetcher_inst == instr
            assert dut.decoder_decoder_inst == instr

    # Reset dut to initial state
    dut.decoder_enable.setimmediatevalue(0)

@cocotb.test()
async def test_decoder_regfile(dut):
    """Test decoder regfile addresses"""

    clkedge = init_posedge_clk(dut.decoder_clk)

    # Reset and enable
    dut.decoder_nreset <= 0
    await clkedge
    dut.decoder_nreset.setimmediatevalue(1)
    dut.decoder_enable.setimmediatevalue(1)

    # Test data inst
    dut.decoder_fetcher_inst.setimmediatevalue(int('e0864007', 16)) # add r4, r6, r7
    # Make immediates take effect
    await Timer(1, 'us')
    assert dut.decoder_regfile_read_addr1 == 6
    assert dut.decoder_regfile_read_addr2 == 7

    # Test memory inst
    dut.decoder_fetcher_inst.setimmediatevalue(int('e79842a9', 16)) # ldr r4, [r8, r9, lsr #5]
    # Make immediates take effect
    await Timer(1, 'us')
    assert dut.decoder_regfile_read_addr1 == 8
    assert dut.decoder_regfile_read_addr2 == 9

    # Test PC read
    dut.decoder_fetcher_inst.setimmediatevalue(int('e08fe004', 16)) # add lr, pc, r4
    # Make immediates take effect
    await Timer(1, 'us')
    assert dut.decoder_regfile_read_addr1 == 15 # pc
    assert dut.decoder_regfile_read_addr2 == 4 # r4
    # Test that PC is not modified since Rn is PC
    # Need to await clkedge to simulate regfile read
    await clkedge
    dut.decoder_regfile_read_value1.setimmediatevalue(42)
    dut.decoder_regfile_read_value2.setimmediatevalue(24)
    # Make immediates take effect
    await Timer(1, 'us')
    assert dut.decoder_Rn_value == 42
    assert dut.decoder_Rd_Rm_value == 24

    # Test PC read with fix for operand2 pc value
    dut.decoder_fetcher_inst.setimmediatevalue(int('e084e00f', 16)) # add lr, r4, pc
    # Make immediates take effect
    await Timer(1, 'us')
    assert dut.decoder_regfile_read_addr1 == 4 # r4
    assert dut.decoder_regfile_read_addr2 == 15 # pc
    # Test that PC is not modified since Rn is PC
    # Need to await clkedge to simulate regfile read
    await clkedge
    dut.decoder_regfile_read_value1.setimmediatevalue(24)
    dut.decoder_regfile_read_value2.setimmediatevalue(42) # orig_pc + 8
    # Make immediates take effect
    await Timer(1, 'us')
    assert dut.decoder_Rn_value == 24
    assert dut.decoder_Rd_Rm_value == 42 + 4 # orig_pc + 12 = (orig_pc + 8) + 4

    # Reset dut to initial state
    dut.decoder_enable.setimmediatevalue(0)

@cocotb.test()
async def test_decoder_stall_for_ldr(dut):
    """Test decoder's stalling for LDR"""

    clkedge = init_posedge_clk(dut.decoder_clk)

    # Need to add PC offset when setting decoder_pc due to pipelining
    decoder_pc_offset = 8

    # Reset and enable
    dut.decoder_nreset <= 0
    await clkedge
    dut.decoder_nreset <= 1
    dut.decoder_enable <= 1

    dut.decoder_fetcher_inst <= 0xe79842a9 # ldr r4, [r8, r9, lsr #5]
    await clkedge
    # We need to wait a little since the values just became available
    # at the last clkedge
    await Timer(1, 'us')
    assert dut.decoder_ready.value.integer
    assert_eq(dut.decoder_regfile_read_addr1, 8)
    assert_eq(dut.decoder_regfile_read_addr2, 9)

    dut.decoder_fetcher_inst <= 0xe1a05004 # mov r5, r4
    await clkedge
    # We need to wait a little since the values just became available
    # at the last clkedge
    await Timer(1, 'us')
    assert dut.decoder_ready.value.integer
    assert_eq(dut.decoder_regfile_read_addr2, 4) # r4
    assert dut.decoder_stall_for_ldr.value.integer
