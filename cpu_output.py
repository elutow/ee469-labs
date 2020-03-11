#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import io
import os
import struct
import subprocess

"""Functions to parse output from the TinyFPGA USB port"""

# Adjust this number to be the number of debug bytes
# i.e. cpu/constants.svh value minus one
DEBUG_BYTES = 31

_DATA_OPCODES = {
    0b0001: 'EOR',
    0b0010: 'SUB',
    0b0100: 'ADD',
    0b1000: 'TST',
    0b1001: 'TEQ',
    0b1010: 'CMP',
    0b1100: 'ORR',
    0b1101: 'MOV',
    0b1110: 'BIC',
    0b1111: 'MVN',
}
_COND_CODES = {
    0b0000: 'EQ',
    0b0001: 'NE',
    0b0010: 'CS/HS',
    0b0011: 'CC/LO',
    0b0100: 'MI',
    0b0101: 'PL',
    0b0110: 'VS',
    0b0111: 'VC',
    0b1000: 'HI',
    0b1010: 'GE',
    0b1011: 'LT',
    0b1100: 'GT',
    0b1101: 'LE',
    0b1110: 'AL',
}
_SHIFT_CODES = {
    0b00: 'LSL',
    0b01: 'LSR',
    0b10: 'ASR',
    0b11: 'ROR',
}
_INST_FORMAT = {
    0b00: 'DATA',
    0b01: 'MEMORY',
    0b10: 'BRANCH',
}

def _parse_code_objdump(filename):
    with open(filename) as file:
        contents = file.read()
    contents = contents.split('00000000 <.data>:')[1].strip().splitlines()
    contents = [line.split(':')[1].strip() for line in contents]
    contents = [line.split(' ', maxsplit=1) for line in contents]
    contents = {int(k.strip(), 16): v.strip().replace('\t', ' ') for k, v in contents}
    return contents

_INST_ASM = _parse_code_objdump('cpu/init/code.objdump')

def _decode_instruction(inst_int):
    return _INST_ASM.get(inst_int, f'(could not get asm for: {hex(inst_int)}')

def _parse_ready_flags(ready_flags):
    ready_codes = {
        0b00001: 'WB',
        0b00010: 'MEM',
        0b00100: 'EXE',
        0b01000: 'DEC',
        0b10000: 'FET',
    }
    asserted_ready = list()
    for code, short_name in ready_codes.items():
        if code & ready_flags:
            asserted_ready.append(short_name)
    if not asserted_ready:
        return '(none ready)'
    return f'({",".join(asserted_ready)})'

def _parse_cpsr(cpsr_int):
    assert cpsr_int >= 0
    assert cpsr_int < 2**4
    # Based on constants.svh
    cpsr_symbols = {
        1 << 3: 'N',
        1 << 2: 'Z',
        1 << 1: 'C',
        1 << 0: 'V',
    }
    result = ''
    for idx, sym_name in cpsr_symbols.items():
        if cpsr_int & idx:
            result += sym_name
        else:
            result += ' '
    return result

def _io_unpack(struct_format, buf):
    """Reads from io.BytesIO with format according to struct_format"""
    size = struct.calcsize(struct_format)
    data = buf.read(size)
    return struct.unpack(struct_format, data)

def _io_read_by_bitcount(struct_format, buf_io, *args):
    """
    Read multiple values from a single value and returns a tuple of those values

    args specifies a sequence of bit counts
    """
    assert args
    orig_value, = _io_unpack(struct_format, buf_io)
    results = list()
    for bitcount in reversed(args):
        results.append(orig_value % (1 << bitcount))
        orig_value >>= bitcount
    return tuple(reversed(results))

def parse_cycle_output(cycle_count, cycle_output):
    """Parse one cycle output"""
    if int.from_bytes(cycle_output, 'little') == 0:
        # Hack to wait for initialization
        print('Waiting...')
        return
    buf_io = io.BytesIO(cycle_output)
    # Decode instruction from USB debug port
    pc, ready_flags = _io_unpack('>IB', buf_io)
    regfile_read_addr1, regfile_read_value1 = _io_unpack('>BI', buf_io)
    regfile_read_addr2, regfile_read_value2 = _io_unpack('>BI', buf_io)
    regfile_write_addr1, regfile_write_value1 = _io_unpack('>BI', buf_io)
    (
        regfile_update_pc, regfile_write_enable1,
        executor_condition_passes, executor_cpsr
    ) = _io_read_by_bitcount('>B', buf_io, 1, 1, 1, 4)
    fetcher_inst, = _io_unpack('>I', buf_io)
    regfile_new_pc, = _io_unpack('>I', buf_io)

    print(f'pc={pc} {_parse_ready_flags(ready_flags)}', end='\t')
    print(f'r{regfile_read_addr1}->{regfile_read_value1:#0{10}x}', end=' ')
    print(f'r{regfile_read_addr2}->{regfile_read_value2:#0{10}x}', end=' ')
    regfile_write1_str = '<-' if regfile_write_enable1 else '//'
    print(f'r{regfile_write_addr1}{regfile_write1_str}{regfile_write_value1:#0{10}x}', end=' ')
    update_pc_str = '<-' if regfile_update_pc else '//'
    print(f'pc{update_pc_str}{regfile_new_pc}', end='\t')
    condition_passes_str = '' if executor_condition_passes else '->!exe'
    print(f'({_parse_cpsr(executor_cpsr)}){condition_passes_str}', end='\t')
    print(_decode_instruction(fetcher_inst))
