import random

import cocotb
from cocotb.triggers import Timer

from _tests_common import init_posedge_clk

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
    with open('cpu/lab3_code.hex') as code_hex:
        for inst_hexstr in code_hex.read().splitlines():
            dut._log.debug('Testing decoder instruction:', inst_hexstr)
            instr = int(inst_hexstr, 16)
            dut.decoder_fetcher_inst.setimmediatevalue(instr)
            assert dut.decoder_fetcher_inst.value.integer == instr
            await clkedge
            # We need to wait a little since the values just became available
            # at the last clkedge
            await Timer(1, 'us')
            assert dut.decoder_ready.value.integer
            assert dut.decoder_fetcher_inst.value.integer == instr
            assert dut.decoder_decoder_inst.value.integer == instr

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
    assert dut.decoder_regfile_read_addr1.value.integer == 6
    assert dut.decoder_regfile_read_addr2.value.integer == 7

    # Test memory inst
    dut.decoder_fetcher_inst.setimmediatevalue(int('e79842a9', 16)) # ldr r4, [r8, r9, lsr #5]
    # Make immediates take effect
    await Timer(1, 'us')
    assert dut.decoder_regfile_read_addr1.value.integer == 8
    assert dut.decoder_regfile_read_addr2.value.integer == 9

    # Reset dut to initial state
    dut.decoder_enable.setimmediatevalue(0)
