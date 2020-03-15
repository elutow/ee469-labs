import random

import cocotb
from cocotb.triggers import Timer

from _tests_common import assert_eq, init_posedge_clk

@cocotb.test()
async def test_executor_memory(dut):
    """Test executor on memory instructions"""

    clkedge = init_posedge_clk(dut.executor_clk)

    # Reset and enable
    dut.executor_nreset <= 0
    await clkedge
    dut.executor_nreset <= 1
    dut.executor_enable <= 1

    dut._log.info("Test LDR")
    dut.executor_decoder_inst <= int('e79842a9', 16) # ldr r4, [r8, r9, lsr #5]
    Rn_value = 4 # r8
    Rd_Rm_value = 0b1100000 # r9, final value after LSR #5 should be 3
    dut.executor_decoder_Rn_value <= Rn_value
    dut.executor_decoder_Rd_Rm_value <= Rd_Rm_value
    await clkedge
    # We need to wait a little since the values just became available
    # at the last clkedge
    await Timer(1, 'us')
    assert dut.executor_ready.value.integer
    assert dut.executor_update_Rd.value.integer
    assert not dut.executor_flush_for_pc.value.integer
    assert not dut.executor_mem_write_enable.value.integer
    assert dut.executor_mem_read_addr == Rn_value+(Rd_Rm_value>>5)

    dut._log.info("Test STR")
    dut.executor_decoder_inst <= int('e5885000', 16) # str r5, [r8]
    Rd_Rm_value = 0xdeadbeef # r5
    Rn_value = 1 # r8
    dut.executor_decoder_Rn_value <= Rn_value
    dut.executor_decoder_Rd_Rm_value <= Rd_Rm_value
    await clkedge
    # We need to wait a little since the values just became available
    # at the last clkedge
    await Timer(1, 'us')
    # STR should not update Rd
    assert not dut.executor_update_Rd.value.integer
    assert not dut.executor_flush_for_pc.value.integer
    assert dut.executor_mem_write_enable.value.integer
    assert dut.executor_mem_write_addr == Rn_value
    assert dut.executor_mem_write_value == Rd_Rm_value

    # Reset dut to initial state
    dut.executor_enable.setimmediatevalue(0)

@cocotb.test()
async def test_executor_data_single(dut):
    """Test executor on a single data instruction"""

    clkedge = init_posedge_clk(dut.executor_clk)

    # Reset and enable
    dut.executor_nreset <= 0
    await clkedge
    dut.executor_nreset <= 1
    dut.executor_enable <= 1

    # Test result of one data instruction

    dut.executor_decoder_inst <= int('e0864007', 16) # add	r4, r6, r7
    Rn_value = 3 # r6
    Rd_Rm_value = 5 # r7
    dut.executor_decoder_Rn_value <= Rn_value
    dut.executor_decoder_Rd_Rm_value <= Rd_Rm_value
    await clkedge
    # We need to wait a little since the values just became available
    # at the last clkedge
    await Timer(1, 'us')
    assert dut.executor_ready.value.integer
    assert dut.executor_update_Rd.value.integer
    assert not dut.executor_flush_for_pc.value.integer
    assert dut.executor_databranch_Rd_value == Rn_value + Rd_Rm_value

@cocotb.test()
async def test_executor_data_conditional(dut):
    """Test executor on conditional data instructions"""

    clkedge = init_posedge_clk(dut.executor_clk)

    # Reset and enable
    dut.executor_nreset <= 0
    await clkedge
    dut.executor_nreset <= 1
    dut.executor_enable <= 1

    # Set CPSR
    dut.executor_decoder_inst <= int('e1540005', 16) # cmp r4, r5
    Rn_value = 65535 # r4
    Rd_Rm_value = 65535 # r5
    dut.executor_decoder_Rn_value <= Rn_value
    dut.executor_decoder_Rd_Rm_value <= Rd_Rm_value
    await clkedge
    # We need to wait a little since the values just became available
    # at the last clkedge
    await Timer(1, 'us')
    assert dut.executor_ready.value.integer
    assert not dut.executor_update_Rd.value.integer
    assert not dut.executor_flush_for_pc.value.integer

    # Test non-execution
    dut.executor_decoder_inst <= int('13a0e000', 16) # movne lr, #0
    await clkedge
    # We need to wait a little since the values just became available
    # at the last clkedge
    await Timer(1, 'us')
    assert dut.executor_ready.value.integer
    assert not dut.executor_update_Rd.value.integer
    assert not dut.executor_flush_for_pc.value.integer

    # Test execution
    dut.executor_decoder_inst <= int('01a0f00e', 16) # moveq pc, lr
    Rd_Rm_value = 42 # r5
    dut.executor_decoder_Rd_Rm_value <= Rd_Rm_value
    await clkedge
    # We need to wait a little since the values just became available
    # at the last clkedge
    await Timer(1, 'us')
    assert dut.executor_ready.value.integer
    assert dut.executor_update_Rd.value.integer
    assert dut.executor_databranch_Rd_value == Rd_Rm_value
    assert dut.executor_flush_for_pc.value.integer

    # Reset dut to initial state
    dut.executor_enable.setimmediatevalue(0)

@cocotb.test()
async def test_executor_branch(dut):
    """Test executor on branch instructions"""

    clkedge = init_posedge_clk(dut.executor_clk)

    # Need to add PC offset when setting executor_pc due to pipelining
    executor_pc_offset = 8

    # Reset and enable
    dut.executor_nreset <= 0
    await clkedge
    dut.executor_nreset <= 1
    dut.executor_enable <= 1

    # Test regular branch
    dut.executor_decoder_inst <= int('eafffffa', 16) # b 0x68 (relative to 0x78)
    pc_init = 20
    dut.executor_pc <= pc_init + executor_pc_offset
    await clkedge
    # We need to wait a little since the values just became available
    # at the last clkedge
    await Timer(1, 'us')
    assert dut.executor_ready.value.integer
    assert not dut.executor_update_Rd.value.integer
    assert dut.executor_flush_for_pc.value.integer
    assert dut.executor_update_pc.value.integer
    assert_eq(dut.executor_new_pc, pc_init + (0x68 - 0x78))

    # Test branch with link
    dut.executor_decoder_inst <= int('ebfffffb', 16) # bl 0x68 (relative to 0x74)
    pc_init = 16
    dut.executor_pc <= pc_init + executor_pc_offset
    await clkedge
    # We need to wait a little since the values just became available
    # at the last clkedge
    await Timer(1, 'us')
    assert dut.executor_ready.value.integer
    assert dut.executor_update_Rd.value.integer
    assert dut.executor_flush_for_pc.value.integer
    assert dut.executor_databranch_Rd_value == pc_init + 4
    assert dut.executor_update_pc.value.integer
    assert_eq(dut.executor_new_pc, pc_init + (0x68 - 0x74))

    # Reset dut to initial state
    dut.executor_enable.setimmediatevalue(0)

@cocotb.test()
async def test_executor_executor_forward(dut):
    """Test executor's data forwarding to itself"""

    clkedge = init_posedge_clk(dut.executor_clk)

    # Need to add PC offset when setting executor_pc due to pipelining
    executor_pc_offset = 8

    # Reset and enable
    dut.executor_nreset <= 0
    await clkedge
    dut.executor_nreset <= 1
    dut.executor_enable <= 1

    Rd_Rm_value = 0xdeadbeef # r4

    # Try mov, then str (memory forwarding)

    dut.executor_decoder_inst <= 0xe1a05004 # mov r5, r4
    dut.executor_decoder_Rn_value <= 42 # unused
    dut.executor_decoder_Rd_Rm_value <= Rd_Rm_value
    await clkedge
    # We need to wait a little since the values just became available
    # at the last clkedge
    await Timer(1, 'us')
    assert dut.executor_ready.value.integer
    assert dut.executor_update_Rd.value.integer
    assert not dut.executor_flush_for_pc.value.integer
    assert_eq(dut.executor_databranch_Rd_value, Rd_Rm_value)
    assert not dut.executor_update_pc.value.integer

    dut.executor_decoder_inst <= 0xe5885000 # str r5, [r8]
    Rd_Rm_value_unused = 0xbabafafa # r5, should not be used
    Rn_value = 1 # r8
    dut.executor_decoder_Rn_value <= Rn_value
    dut.executor_decoder_Rd_Rm_value <= Rd_Rm_value_unused
    await clkedge
    await Timer(1, 'us')
    assert dut.executor_ready.value.integer
    assert not dut.executor_update_Rd.value.integer
    assert not dut.executor_flush_for_pc.value.integer
    assert not dut.executor_update_pc.value.integer
    assert dut.executor_mem_write_enable.value.integer
    assert_eq(dut.executor_mem_write_value, Rd_Rm_value)

    # Try mov r5, r4, then mov r4, r5 (data forwarding)

    dut.executor_decoder_inst <= 0xe1a05004 # mov r5, r4
    dut.executor_decoder_Rn_value <= 42 # unused
    dut.executor_decoder_Rd_Rm_value <= Rd_Rm_value
    await clkedge
    # We need to wait a little since the values just became available
    # at the last clkedge
    await Timer(1, 'us')
    assert dut.executor_ready.value.integer
    assert dut.executor_update_Rd.value.integer
    assert not dut.executor_flush_for_pc.value.integer
    assert_eq(dut.executor_databranch_Rd_value, Rd_Rm_value)
    assert not dut.executor_update_pc.value.integer

    dut.executor_decoder_inst <= 0xe1a04005 # mov r4, r5
    Rd_Rm_value_unused = 0xbabafafa # r5, should not be used
    dut.executor_decoder_Rn_value <= 42 # unused
    dut.executor_decoder_Rd_Rm_value <= Rd_Rm_value_unused
    await clkedge
    await Timer(1, 'us')
    assert dut.executor_ready.value.integer
    assert dut.executor_update_Rd.value.integer
    assert not dut.executor_flush_for_pc.value.integer
    assert not dut.executor_update_pc.value.integer
    assert not dut.executor_mem_write_enable.value.integer
    assert_eq(dut.executor_databranch_Rd_value, Rd_Rm_value)

@cocotb.test()
async def test_executor_memaccessor_forward(dut):
    """Test executor's data forwarding from memaccessor"""

    clkedge = init_posedge_clk(dut.executor_clk)

    # Need to add PC offset when setting executor_pc due to pipelining
    executor_pc_offset = 8

    # Reset and enable
    dut.executor_nreset <= 0
    await clkedge
    dut.executor_nreset <= 1
    dut.executor_enable <= 1

    # Steps:
    # 1. Override r4 value in "mov r5, r4"
    # 2. Use executor forwarding to move r5 value from "mov r5, r4" to "str r5, [r8]"

    Rd_Rm_value_unused = 0xdeadbeef # r4, should not be used in STR below
    Rd_Rm_value = 0xbabafafa # r4

    dut.executor_decoder_inst <= 0xe1a05004 # mov r5, r4
    dut.executor_decoder_Rn_value <= 42 # unused
    dut.executor_decoder_Rd_Rm_value <= Rd_Rm_value_unused
    dut.executor_memaccessor_fwd_has_Rd <= 1
    dut.executor_memaccessor_fwd_Rd_addr <= 4 # r4
    dut.executor_memaccessor_fwd_Rd_value <= Rd_Rm_value
    await clkedge
    # We need to wait a little since the values just became available
    # at the last clkedge
    await Timer(1, 'us')
    assert dut.executor_ready.value.integer
    assert dut.executor_update_Rd.value.integer
    assert not dut.executor_flush_for_pc.value.integer
    assert_eq(dut.executor_databranch_Rd_value, Rd_Rm_value)
    assert not dut.executor_update_pc.value.integer

    dut.executor_decoder_inst <= 0xe5885000 # str r5, [r8]
    Rn_value = 1 # r8
    dut.executor_decoder_Rn_value <= Rn_value
    dut.executor_decoder_Rd_Rm_value <= Rd_Rm_value_unused
    await clkedge
    await Timer(1, 'us')
    assert dut.executor_ready.value.integer
    assert not dut.executor_update_Rd.value.integer
    assert not dut.executor_flush_for_pc.value.integer
    assert not dut.executor_update_pc.value.integer
    assert dut.executor_mem_write_enable.value.integer
    assert_eq(dut.executor_mem_write_value, Rd_Rm_value)

    # Repeat same as above, but replace STR with "mov r4, r5"

    dut.executor_decoder_inst <= 0xe1a05004 # mov r5, r4
    dut.executor_decoder_Rn_value <= 42 # unused
    dut.executor_decoder_Rd_Rm_value <= Rd_Rm_value_unused
    dut.executor_memaccessor_fwd_has_Rd <= 1
    dut.executor_memaccessor_fwd_Rd_addr <= 4 # r4
    dut.executor_memaccessor_fwd_Rd_value <= Rd_Rm_value
    await clkedge
    # We need to wait a little since the values just became available
    # at the last clkedge
    await Timer(1, 'us')
    assert dut.executor_ready.value.integer
    assert dut.executor_update_Rd.value.integer
    assert not dut.executor_flush_for_pc.value.integer
    assert_eq(dut.executor_databranch_Rd_value, Rd_Rm_value)
    assert not dut.executor_update_pc.value.integer

    dut.executor_decoder_inst <= 0xe1a04005 # mov r4, r5
    dut.executor_decoder_Rn_value <= 42 # unused
    dut.executor_decoder_Rd_Rm_value <= Rd_Rm_value_unused
    await clkedge
    await Timer(1, 'us')
    assert dut.executor_ready.value.integer
    assert dut.executor_update_Rd.value.integer
    assert not dut.executor_flush_for_pc.value.integer
    assert not dut.executor_update_pc.value.integer
    assert not dut.executor_mem_write_enable.value.integer
    assert_eq(dut.executor_databranch_Rd_value, Rd_Rm_value)

@cocotb.test()
async def test_executor_disable(dut):
    """Test if executor persists outputs when disabled"""

    clkedge = init_posedge_clk(dut.executor_clk)

    # Need to add PC offset when setting executor_pc due to pipelining
    executor_pc_offset = 8

    # Reset and enable
    dut.executor_nreset <= 0
    await clkedge
    dut.executor_nreset <= 1

    async def _test_disable(initial_inputs, expected_outputs, delay_scramble=tuple()):
        def _check_expected():
            for signal, value in expected_outputs.items():
                try:
                    assert_eq(signal, value)
                except AssertionError as exc:
                    raise AssertionError(
                        'Failed expected value on signal {} with error: {}'.format(
                            signal._name, str(exc)
                        )
                    )

        # Enable module
        dut.executor_enable <= 1

        # Set initial inputs
        for signal, value in initial_inputs.items():
            signal <= value

        await clkedge
        await Timer(1, 'us')
        assert dut.executor_ready.value.integer
        # Check expected_outputs
        _check_expected()

        # Disable module
        dut.executor_enable <= 0

        # Scramble inputs
        for signal in initial_inputs:
            if signal not in delay_scramble:
                signal <= 1 # set to non-zero to not conflate with Verilator's default value
        await clkedge
        await Timer(1, 'us')
        assert not dut.executor_ready.value.integer
        # Check expected outputs
        _check_expected()

        if delay_scramble:
            # Scramble inputs that need a delay to take effect
            for signal in delay_scramble:
                signal <= 1
            await clkedge
            await Timer(1, 'us')
            assert not dut.executor_ready.value.integer
            # Check expected outputs
            _check_expected()

    Rn_value = 4 # r8
    Rd_Rm_value = 0b1100000 # r9, final value after LSR #5 should be 3
    initial_inputs = {
        dut.executor_pc: 64,
        dut.executor_decoder_inst: 0xe79842a9, # ldr r4, [r8, r9, lsr #5]
        dut.executor_decoder_Rn_value: Rn_value,
        dut.executor_decoder_Rd_Rm_value: Rd_Rm_value,
        dut.executor_memaccessor_fwd_has_Rd: False,
        # Should be unused values
        dut.executor_memaccessor_fwd_Rd_addr: 5,
        dut.executor_memaccessor_fwd_Rd_value: 0xdedebeef,
    }
    # Inputs that need to be scrambled later since they're updated after ready
    # is asserted
    delay_scramble = set()
    expected_outputs = {
        dut.executor_cpsr: 0b0000,
        dut.executor_condition_passes: True,
        dut.executor_executor_inst: initial_inputs[dut.executor_decoder_inst],
        dut.executor_update_pc: False,
        dut.executor_update_Rd: True,
        dut.executor_flush_for_pc: False,
        dut.executor_mem_read_addr: Rn_value+(Rd_Rm_value>>5),
        dut.executor_mem_write_enable: False,
    }
    await _test_disable(
        initial_inputs, expected_outputs, delay_scramble=delay_scramble)

    Rd_Rm_value_unused = 0xdeadbeef # r4, should not be used in STR below
    Rd_Rm_value = 0xbabafafa # r4
    initial_inputs = {
        dut.executor_pc: 64,
        dut.executor_decoder_inst: 0xe1a05004, # mov r5, r4
        dut.executor_decoder_Rn_value: 42, # unused
        dut.executor_decoder_Rd_Rm_value: Rd_Rm_value_unused,
        dut.executor_memaccessor_fwd_has_Rd: True,
        dut.executor_memaccessor_fwd_Rd_addr: 4, # r4
        dut.executor_memaccessor_fwd_Rd_value: Rd_Rm_value,
    }
    delay_scramble = set()
    expected_outputs = {
        dut.executor_cpsr: 0b0000,
        dut.executor_condition_passes: True,
        dut.executor_executor_inst: initial_inputs[dut.executor_decoder_inst],
        dut.executor_update_pc: False,
        dut.executor_update_Rd: True,
        dut.executor_databranch_Rd_value: Rd_Rm_value,
        dut.executor_flush_for_pc: False,
        dut.executor_mem_write_enable: False,
    }
    await _test_disable(
        initial_inputs, expected_outputs, delay_scramble=delay_scramble)

    # Test branch with link
    # Need to add PC offset when setting executor_pc due to pipelining
    executor_pc_offset = 8
    pc_init = 16
    initial_inputs = {
        dut.executor_pc: pc_init + executor_pc_offset,
        dut.executor_decoder_inst: 0xebfffffb, # bl 0x68 (relative to 0x74)
        # Unused values
        dut.executor_decoder_Rn_value: 42,
        dut.executor_decoder_Rd_Rm_value: 0xbeef,
        dut.executor_memaccessor_fwd_has_Rd: True,
        dut.executor_memaccessor_fwd_Rd_addr: 4,
        dut.executor_memaccessor_fwd_Rd_value: 0xdead,
    }
    delay_scramble = set()
    expected_outputs = {
        dut.executor_cpsr: 0b0000,
        dut.executor_condition_passes: True,
        dut.executor_executor_inst: initial_inputs[dut.executor_decoder_inst],
        dut.executor_update_pc: True,
        dut.executor_new_pc: pc_init + (0x68 - 0x74),
        dut.executor_update_Rd: True,
        dut.executor_databranch_Rd_value: pc_init + 4,
        dut.executor_flush_for_pc: True,
        dut.executor_mem_write_enable: False,
    }
    await _test_disable(
        initial_inputs, expected_outputs, delay_scramble=delay_scramble)
