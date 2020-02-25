import random

import cocotb
from cocotb.triggers import Timer

from _tests_common import init_posedge_clk

def _read_init_data_memory(filename):
    with open(filename) as data_hex:
        data_str = data_hex.read().splitlines()
    data_int = [int(x, 16) for x in data_str if x]
    return data_int

def _read_word(addr, data_memory):
    # NOTE: Assumes each entry is a byte
    # Also assumes entries are in ascending order by address
    values = data_memory[addr:addr+4]
    result = 0
    for item in reversed(values):
        result = (result << 8) + item
    return result

@cocotb.test()
async def test_executor_memory(dut):
    """Test executor on memory instructions"""

    clkedge = init_posedge_clk(dut.executor_clk)

    init_data_memory = _read_init_data_memory('cpu/lab2_data.hex')

    # Reset and enable
    dut.executor_nreset <= 0
    await clkedge
    dut.executor_nreset <= 1
    dut.executor_enable <= 1

    dut._log.info("Test LDR")
    dut.executor_decoder_inst <= int('e79842a9', 16) # ldr r4, [r8, r9, lsr #5]
    Rn_value = 4 # r8
    Rm_value = 0b1100000 # r9, final value after LSR #5 should be 3
    dut.executor_Rn_value <= Rn_value
    dut.executor_Rm_value <= Rm_value
    await clkedge
    # We need to wait a little since the values just became available
    # at the last clkedge
    await Timer(1, 'us')
    assert dut.executor_ready.value.integer
    assert dut.executor_update_Rd.value.integer
    expected_value = _read_word(Rn_value+(Rm_value>>5), init_data_memory)
    assert dut.executor_Rd_value.value.integer == expected_value

    #dut._log.info("Test STR")
    #dut.executor_decoder_inst <= int('e5885000', 16) # str r5, [r8]
    #Rn_value = 0xdeadbeef # r5
    #Rm_value = 1 # r8
    #dut.executor_Rn_value <= Rn_value
    #dut.executor_Rm_value <= Rm_value
    #await clkedge
    ## We need to wait a little since the values just became available
    ## at the last clkedge
    #await Timer(1, 'us')
    ## STR should not update Rd
    #assert not dut.executor_update_Rd

    #dut._log.info("Verify STR with LDR")
    #dut.executor_decoder_inst <= int('e5984000', 16) # ldr	r4, [r8]
    ## TODO

    # Reset dut to initial state
    dut.decoder_enable.setimmediatevalue(0)
