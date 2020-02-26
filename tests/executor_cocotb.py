import random

import cocotb
from cocotb.triggers import Timer

from _tests_common import init_posedge_clk, read_regfile_init

def _read_init_data_memory():
    with open('cpu/lab2_data.hex') as data_hex:
        data_str = data_hex.read().splitlines()
    data_int = [int(x, 16) for x in data_str if x]
    return data_int

def _read_word(addr, data_memory):
    # Assumptions:
    # - data_memory is an array of bytes (TODO: Make these words in the future)
    # - Entries are in ascending order by address
    # - CPU is operating in big-endian mode
    values = data_memory[addr:addr+4]
    result = 0
    for item in values:
        assert abs(item) < 256 # Necessary condition for data memory to be byte values
        result = (result << 8) + item
    return result

@cocotb.test()
async def test_executor_memory(dut):
    """Test executor on memory instructions"""

    clkedge = init_posedge_clk(dut.executor_clk)

    init_data_memory = _read_init_data_memory()

    # Reset and enable
    dut.executor_nreset <= 0
    await clkedge
    dut.executor_nreset <= 1
    dut.executor_enable <= 1

    dut._log.info("Test LDR")
    dut.executor_decoder_inst <= int('e79842a9', 16) # ldr r4, [r8, r9, lsr #5]
    Rn_value = 4 # r8
    Rd_Rm_value = 0b1100000 # r9, final value after LSR #5 should be 3
    dut.executor_Rn_value <= Rn_value
    dut.executor_Rd_Rm_value <= Rd_Rm_value
    await clkedge
    # We need to wait a little since the values just became available
    # at the last clkedge
    await Timer(1, 'us')
    assert dut.executor_ready.value.integer
    assert dut.executor_update_Rd.value.integer
    expected_value = _read_word(Rn_value+(Rd_Rm_value>>5), init_data_memory)
    assert dut.executor_Rd_value.value.integer == expected_value

    dut._log.info("Test STR")
    dut.executor_decoder_inst <= int('e5885000', 16) # str r5, [r8]
    Rd_Rm_value = 0xdeadbeef # r5
    Rn_value = 1 # r8
    dut.executor_Rn_value <= Rn_value
    dut.executor_Rd_Rm_value <= Rd_Rm_value
    await clkedge
    # We need to wait a little since the values just became available
    # at the last clkedge
    await Timer(1, 'us')
    # STR should not update Rd
    assert not dut.executor_update_Rd.value.integer

    dut._log.info("Verify STR with LDR")
    dut.executor_decoder_inst <= int('e5984000', 16) # ldr	r4, [r8]
    Rn_value = 1 # r8
    dut.executor_Rn_value <= Rn_value
    await clkedge
    # We need to wait a little since the values just became available
    # at the last clkedge
    await Timer(1, 'us')
    assert dut.executor_ready.value.integer
    assert dut.executor_update_Rd.value.integer
    assert dut.executor_Rd_value.value.integer == 0xdeadbeef

    # Reset dut to initial state
    dut.executor_enable.setimmediatevalue(0)

@cocotb.test()
async def test_executor_data(dut):
    """Test executor on data instructions"""

    clkedge = init_posedge_clk(dut.executor_clk)

    init_data_memory = _read_init_data_memory()
    init_regfile = read_regfile_init()

    # Reset and enable
    dut.executor_nreset <= 0
    await clkedge
    dut.executor_nreset <= 1
    dut.executor_enable <= 1

    # Test result of one data instruction

    dut.executor_decoder_inst <= int('e0864007', 16) # add	r4, r6, r7
    Rn_value = 3 # r6
    Rd_Rm_value = 5 # r7
    dut.executor_Rn_value <= Rn_value
    dut.executor_Rd_Rm_value <= Rd_Rm_value
    await clkedge
    # We need to wait a little since the values just became available
    # at the last clkedge
    await Timer(1, 'us')
    assert dut.executor_ready.value.integer
    assert dut.executor_update_Rd.value.integer
    assert dut.executor_Rd_value.value.integer == Rn_value + Rd_Rm_value

    # Test conditional execution

    # Set CPSR
    dut.executor_decoder_inst <= int('e1540005', 16) # cmp r4, r5
    Rn_value = 65535 # r4
    Rd_Rm_value = 65535 # r5
    dut.executor_Rn_value <= Rn_value
    dut.executor_Rd_Rm_value <= Rd_Rm_value
    await clkedge
    # We need to wait a little since the values just became available
    # at the last clkedge
    await Timer(1, 'us')
    assert dut.executor_ready.value.integer
    assert not dut.executor_update_Rd.value.integer

    # Test non-execution
    dut.executor_decoder_inst <= int('13a0e000', 16) # movne lr, #0
    await clkedge
    # We need to wait a little since the values just became available
    # at the last clkedge
    await Timer(1, 'us')
    assert dut.executor_ready.value.integer
    assert not dut.executor_update_Rd.value.integer

    # Test execution
    dut.executor_decoder_inst <= int('01a0f00e', 16) # moveq pc, lr
    Rd_Rm_value = 42 # r5
    dut.executor_Rd_Rm_value <= Rd_Rm_value
    await clkedge
    # We need to wait a little since the values just became available
    # at the last clkedge
    await Timer(1, 'us')
    assert dut.executor_ready.value.integer
    assert dut.executor_update_Rd.value.integer
    assert dut.executor_Rd_value.value.integer == Rd_Rm_value

    # Reset dut to initial state
    dut.executor_enable.setimmediatevalue(0)

@cocotb.test()
async def test_executor_branch(dut):
    """Test executor on branch instructions"""

    clkedge = init_posedge_clk(dut.executor_clk)

    init_data_memory = _read_init_data_memory()
    init_regfile = read_regfile_init()

    # Reset and enable
    dut.executor_nreset <= 0
    await clkedge
    dut.executor_nreset <= 1
    dut.executor_enable <= 1

    dut.executor_decoder_inst <= int('ebfffffb', 16) # bl 0x68 (relative to 0x74)
    pc_init = 16
    dut.executor_pc <= pc_init
    await clkedge
    # We need to wait a little since the values just became available
    # at the last clkedge
    await Timer(1, 'us')
    assert dut.executor_ready.value.integer
    assert dut.executor_update_Rd.value.integer
    assert dut.executor_Rd_value.value.integer == pc_init + 4
    assert dut.executor_update_pc.value.integer
    print('value:', dut.executor_new_pc.value.integer)
    assert dut.executor_new_pc.value.integer == pc_init + (0x68 - 0x74)

    # Reset dut to initial state
    dut.executor_enable.setimmediatevalue(0)
