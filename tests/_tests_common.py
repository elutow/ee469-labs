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

# Data memory helpers

def read_data_memory_init():
    with open('cpu/lab2_data.hex') as data_hex:
        data_str = data_hex.read().splitlines()
    data_int = [int(x, 16) for x in data_str if x]
    return data_int

def read_data_memory_word(addr, data_memory):
    # Assumptions:
    # - data_memory is an array of words
    # - Entries are in ascending order by address
    # - CPU is operating in big-endian mode
    private_addr = addr >> 2
    word_offset = addr % 4
    value1 = data_memory[private_addr]
    value0 = data_memory[private_addr+1]
    # Bits to keep
    word1_upper = (4-word_offset)*8 - 1
    #word1_lower = 0
    #word0_upper = 31
    word0_lower = (4-word_offset)*8

    if word_offset == 0:
        # word0_* are invalid values here
        return value1
    result = (value1 % (word1_upper+1)) << (31-word1_upper)
    result += value0 >> word0_lower
    return result
