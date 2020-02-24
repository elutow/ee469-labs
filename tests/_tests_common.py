# -*- coding: utf-8 -*-

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

def init_posedge_clk(dut_clk):
    # Start clock running in background
    cocotb.fork(Clock(dut_clk, 10, 'us').start(start_high=False))
    return RisingEdge(dut_clk)
