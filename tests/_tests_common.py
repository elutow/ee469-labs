# -*- coding: utf-8 -*-

import cocotb
from cocotb.clock import Clock
from cocotb.triggers import RisingEdge

class DUTWrapper:
    """
    Wrapper around cocotb dut to access signals easier when using the DUT
    generated by generate_cocotb_dut.py
    """

    _WRAPPER_ATTR = ('_dut', '_name')

    def __init__(self, dut, module_name):
        assert not isinstance(dut, DUTWrapper)
        self._dut = dut
        self._name = module_name

    def __getattr__(self, k):
        try:
            return self.__dict__[k]
        except KeyError:
            pass
        try:
            return getattr(self._dut, f'{self._name}_{k}')
        except AttributeError:
            return getattr(self._dut, k)

    def __setattr__(self, k, v):
        if k in self._WRAPPER_ATTR:
            object.__setattr__(self, k, v)
            return
        new_key = f'{self._name}_{k}'
        if hasattr(self._dut, new_key):
            setattr(self._dut, new_key, v)
        else:
            setattr(self._dut, k, v)

def init_posedge_clk(dut_clk):
    # Start clock running in background
    cocotb.fork(Clock(dut_clk, 10, 'us').start(start_high=False))
    return RisingEdge(dut_clk)
