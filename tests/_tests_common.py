# -*- coding: utf-8 -*-

import cocotb
from cocotb.clock import Clock
from cocotb.handle import SimHandleBase
from cocotb.triggers import RisingEdge

def _get_hex(raw_obj):
    if isinstance(raw_obj, SimHandleBase):
        return hex(raw_obj.value.integer)
    return hex(raw_obj)

def _assert_base(first, second, compare_func):
    if compare_func(first, second):
        return
    raise AssertionError('{} != {}'.format(_get_hex(first), _get_hex(second)))

def assert_eq(first, second):
    _assert_base(first, second, lambda x, y: x == y)

def assert_neq(first, second):
    _assert_base(first, second, lambda x, y: x != y)

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
        hex_entries = data_hex.read().splitlines()
        return list(int(line, 16) for line in hex_entries if line)

def read_data_memory_word(addr, data_memory):
    # Trim to word
    addr >>= 2
    assert addr >= 0
    assert addr < len(data_memory)
    return data_memory[addr]

def write_data_memory_word(addr, value, data_memory):
    # Trim to word
    addr >>= 2
    assert addr >= 0
    assert addr < len(data_memory)
    data_memory[addr] = value
