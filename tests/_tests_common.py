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
    with open('cpu/lab3_data.hex') as data_hex:
        return bytearray.fromhex(data_hex.read())

def read_data_memory_word(addr, data_memory):
    assert addr >= 0
    assert addr < len(data_memory) + 4
    return int.from_bytes(data_memory[addr:addr+4], 'big')
    ## Assumptions:
    ## - data_memory is an array of words
    ## - Entries are in ascending order by address
    ## - CPU is operating in big-endian mode
    #private_addr = addr >> 2
    #word_offset = addr % 4
    #value1 = data_memory[private_addr]
    #value0 = data_memory[private_addr+1]
    ## Bit boundary index of words between bits to overwrite and bits to keep
    ## On word 1, this is exclusive (i.e. boundary - 1)
    ## On word 0, this is inclusive
    #word_boundary = (4-word_offset)*8
    #
    #if word_offset == 0:
    #    # word0_* are invalid values here
    #    return value1
    #result = (value1 % 2**word_boundary) << (32-word_boundary)
    #result += value0 >> word_boundary
    #assert result >= 0
    #assert result < 2**32
    #return result

def write_data_memory_word(addr, value, data_memory):
    assert addr >= 0
    assert addr < len(data_memory) + 4
    data_memory[addr:addr+4] = int.to_bytes(value, 4, 'big')
    ## Same assumptions as read_data_memory_word
    #assert value >= 0
    #assert value < 2**32
    #private_addr = addr >> 2
    #word_offset = addr % 4
    #value1 = data_memory[private_addr]
    #value0 = data_memory[private_addr+1]
    ## Bit boundary index of words between bits to overwrite and bits to keep
    ## On word 1, this is exclusive (i.e. boundary - 1)
    ## On word 0, this is inclusive
    #word_boundary = (4-word_offset)*8
    #
    #if word_offset == 0:
    #    data_memory[private_addr] = value
    #    return
    ## Clear out bits used to store new word
    #value1 ^= value1 % 2**word_boundary
    #value0 = value0 % 2**word_boundary
    ## Add value to value1 and value0
    #value1 |= value >> word_boundary
    #value0 |= value ^ (value % 2**word_boundary)
    #data_memory[private_addr] = value1
    #data_memory[private_addr+1] = value0
