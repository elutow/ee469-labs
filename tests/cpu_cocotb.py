import cocotb

from _tests_common import init_posedge_clk

from cpu_output import parse_cycle_output

# From cpu/constants.svh
DEBUG_BYTES = 32
# Number of instructions to run for in test code
NUM_INSTRUCTIONS = 26

@cocotb.test()
async def test_cpu(dut):
    """Run cpu normally and process debug port outputs"""

    clkedge = init_posedge_clk(dut.cpu_clk)

    # Reset CPU
    dut.cpu_nreset <= 0
    await clkedge
    dut.cpu_nreset <= 1
    await clkedge
    dut._log.debug('Reset complete')

    print("===========BEGIN PARSED DEBUG PORT OUTPUT===========")
    for cycle_count in range(4*NUM_INSTRUCTIONS+4):
        dut._log.debug(f'Running CPU cycle {cycle_count}')
        debug_port_bytes = dut.cpu_debug_port_vector.value.integer.to_bytes(DEBUG_BYTES-1, 'big')
        parse_cycle_output(cycle_count, debug_port_bytes)
        await clkedge
    print("===========END PARSED DEBUG PORT OUTPUT===========")
