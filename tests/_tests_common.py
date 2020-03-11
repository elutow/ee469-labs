# -*- coding: utf-8 -*-

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

def init_posedge_clk(dut_clk):
    # Start clock running in background
    cocotb.fork(Clock(dut_clk, 10, 'us').start(start_high=False))
    return RisingEdge(dut_clk)

def read_regfile_init(mutable=False):
    with open('cpu/init/regfile.hex') as regfile_init_hex:
        hex_entries = regfile_init_hex.read().splitlines()
    result = tuple(int(line, 16) for line in hex_entries if line)
    if mutable:
        return list(result)
    return result

# Data memory helpers

def read_data_memory_init():
    with open('cpu/init/data.hex') as data_hex:
        return bytearray.fromhex(data_hex.read())

def read_data_memory_word(addr, data_memory):
    assert addr >= 0
    assert addr < len(data_memory) + 4
    return int.from_bytes(data_memory[addr:addr+4], 'big')

def write_data_memory_word(addr, value, data_memory):
    assert addr >= 0
    assert addr < len(data_memory) + 4
    data_memory[addr:addr+4] = int.to_bytes(value, 4, 'big')
