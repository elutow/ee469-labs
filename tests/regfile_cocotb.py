import random

import cocotb
from cocotb.triggers import Timer

from _tests_common import init_posedge_clk, read_regfile_init

@cocotb.test()
async def test_regfile_read(dut):
    """Test regfile reads"""

    clkedge = init_posedge_clk(dut.regfile_clk)
    regfile_init = read_regfile_init()

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
    # Wait a little bit after clkedge to check immediate values
    await Timer(1, 'us')

    assert dut.regfile_read_value1 == regfile_init[4]
    assert dut.regfile_read_value2 == regfile_init[5]
    # Test new instruction right away
    dut.regfile_read_inst.setimmediatevalue(int('e08fe004', 16)) # add lr, pc, r4
    dut.regfile_read_addr1.setimmediatevalue(15) # pc
    dut.regfile_read_addr2.setimmediatevalue(4) # r4

    await clkedge
    # Wait a little bit after clkedge to check immediate values
    await Timer(1, 'us')

    # PC should be read directly out, which is zero
    assert dut.regfile_read_value1 == 0
    assert dut.regfile_read_value2 == regfile_init[4]

@cocotb.test()
async def test_regfile_write(dut):
    """Test regfile writes"""
    clkedge = init_posedge_clk(dut.regfile_clk)
    expected_regfile = read_regfile_init(mutable=True)

    async def _check_regfile_expected():
        # Set read to some instruction to not trigger PC-specific behavior
        dut._log.info('Checking regfile values')
        dut.regfile_read_inst.setimmediatevalue(int('e1540005', 16)) # cmp r4, r5
        for addr in range(len(expected_regfile)):
            dut.regfile_read_addr1.setimmediatevalue(addr)
            dut.regfile_read_addr2.setimmediatevalue(addr)
            await clkedge
            # Wait a little bit after clkedge to check immediate values
            await Timer(1, 'us')
            assert dut.regfile_read_value1 == expected_regfile[addr]
            assert dut.regfile_read_value2 == expected_regfile[addr]

    async def _write_and_check(new_addr, new_value):
        """Do a quick check of the value written"""
        dut._log.info(f"Start write and check for r{new_addr} = {hex(new_value)}")
        assert expected_regfile[new_addr] != new_value
        expected_regfile[new_addr] = new_value
        dut.regfile_write_addr1.setimmediatevalue(new_addr)
        dut.regfile_write_value1.setimmediatevalue(new_value)
        dut.regfile_write_enable1.setimmediatevalue(1)
        # Read out value as soon as we can
        dut.regfile_read_addr1.setimmediatevalue(new_addr)

        await clkedge
        # Wait a little bit after clkedge to check immediate values
        await Timer(1, 'us')

        assert dut.regfile_read_value1 == new_value

    # Reset
    dut.regfile_nreset <= 0
    await clkedge
    dut.regfile_nreset <= 1
    await clkedge
    dut._log.info('Reset complete')

    # Save original files so we can restore them at the end of the test
    orig_r4 = expected_regfile[4]
    orig_r5 = expected_regfile[5]

    await _check_regfile_expected()

    await _write_and_check(4, 0xdead)
    await _write_and_check(4, 0xdeadbeef)
    await _write_and_check(5, 0xbeef)

    await _check_regfile_expected()

    await _write_and_check(4, orig_r4)
    await _write_and_check(5, orig_r5)

@cocotb.test()
async def test_regfile_pc(dut):
    """Test regfile PC-specific updates"""

    clkedge = init_posedge_clk(dut.regfile_clk)

    # Reset
    dut.regfile_nreset <= 0
    await clkedge
    dut.regfile_nreset <= 1
    await clkedge
    dut._log.info('Reset complete')

    # PC should be initialized to zero
    assert dut.regfile_pc == 0

    # Try setting new value
    dut.regfile_update_pc.setimmediatevalue(1)
    dut.regfile_new_pc.setimmediatevalue(42)

    await clkedge
    # Wait a little bit after clkedge to check immediate values
    await Timer(1, 'us')

    assert dut.regfile_pc == 42

    # Stop modifying PC so other tests can reset the PC
    dut.regfile_update_pc.setimmediatevalue(0)
