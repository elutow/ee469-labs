import cocotb

from _tests_common import init_posedge_clk

from cpu_output import DEBUG_BYTES, parse_cycle_output

# Padding to handle multiple cycles for startup, branching, other hazards
PIPELINE_PADDING = 15

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

    with open('cpu/init/code.hex') as code_file:
        num_instructions = len(code_file.read().splitlines())

    print("===========BEGIN PARSED DEBUG PORT OUTPUT===========")
    for cycle_count in range(num_instructions+PIPELINE_PADDING):
        dut._log.debug(f'Running CPU cycle {cycle_count}')
        debug_port_bytes = dut.cpu_debug_port_vector.value.integer.to_bytes(DEBUG_BYTES, 'big')
        parse_cycle_output(cycle_count, debug_port_bytes)
        await clkedge
    print("===========END PARSED DEBUG PORT OUTPUT===========")
