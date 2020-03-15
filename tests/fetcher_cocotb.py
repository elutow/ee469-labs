import cocotb
from cocotb.triggers import Timer

from _tests_common import assert_eq, init_posedge_clk

def read_code_memory():
    with open('cpu/init/code.hex') as code_hex:
        hex_entries = code_hex.read().splitlines()
        return tuple(int(line, 16) for line in hex_entries if line)

@cocotb.test()
async def test_fetcher_disable(dut):
    """Test if fetcher persists outputs when disabled"""

    clkedge = init_posedge_clk(dut.fetcher_clk)

    code_memory = read_code_memory()

    # Need to add PC offset when setting fetcher_pc due to pipelining
    fetcher_pc_offset = 8

    # Reset and enable
    dut.fetcher_nreset <= 0
    await clkedge
    dut.fetcher_nreset <= 1
    dut.fetcher_enable <= 1

    initial_inputs = {
        dut.fetcher_pc: 64,
    }
    expected_outputs = {
        dut.fetcher_fetcher_inst: code_memory[initial_inputs[dut.fetcher_pc] >> 2],
    }
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

    # Set initial inputs
    for signal, value in initial_inputs.items():
        signal <= value

    await clkedge
    await Timer(1, 'us')
    assert dut.fetcher_ready.value.integer
    # Check expected_outputs
    _check_expected()

    # Disable module
    dut.fetcher_enable <= 0

    # Scramble inputs
    for signal in initial_inputs:
        signal <= 1
    await clkedge
    await Timer(1, 'us')
    assert not dut.fetcher_ready.value.integer
    # Check expected outputs
    _check_expected()
