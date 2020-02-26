# -*- coding: utf-8 -*-

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

def init_posedge_clk(dut_clk):
    # Start clock running in background
    cocotb.fork(Clock(dut_clk, 10, 'us').start(start_high=False))
    return RisingEdge(dut_clk)

def read_regfile_init(mutable=False):
    with open('cpu/regfile_init.hex') as regfile_init_hex:
        hex_entries = regfile_init_hex.read().splitlines()
    result = tuple(int(line, 16) for line in hex_entries if line)
    if mutable:
        return list(result)
    return result
