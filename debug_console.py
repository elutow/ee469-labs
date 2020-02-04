#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import io
import struct
import sys

import serial
import tinyprog
import usb

# Adjust this number to be the number of debug bytes
DEBUGBYTES = 32-1
# FPGA device USB ID
USB_ID = '1d50:6130'

def _align_serial_reads(port):
    """Ignore serial port values with 255 and align reads to DEBUGBYTES"""
    ch=port.read(1)
    while int(ch[0]) != 255:
        #sys.stdout.write(hex(ch[0]))
        #sys.stdout.write("\n")
        ch=port.read(1)
    for _ in range(DEBUGBYTES):
        ch=port.read(1)
        if int(ch[0]) != 255:
            break
    if int(ch[0]) == 255:
        ch=port.read(1)
    return ch

def _read_loop(port, verbose=True):
    lastcycle = None
    # Run loop once we know ch
    ch = yield None
    while True:
        thiscycle = int(ch[0])
        cycle_output = b''
        # cycle count
        if verbose and thiscycle != lastcycle:
            print(f'{ch.hex()} ', end='')
        # cycle debug data
        for _ in range(DEBUGBYTES):
            ch=port.read(1)
            if thiscycle != lastcycle:
                if verbose:
                    print(f'{ch.hex()} ', end='')
                cycle_output += ch
        # end of cycle data
        if verbose and thiscycle != lastcycle:
            print()
        if thiscycle == lastcycle:
            # we got no data; yield None
            cycle_output = None
        ch = yield thiscycle, cycle_output
        lastcycle = thiscycle


def _write_loop(port):
    wch = 0
    # Just demonstrate how to write stuff back, if you want
    while True:
        port.write([wch])
        wch=wch+1
        if (wch > 10):
            wch = 0
        # Done writing
        yield None

def _io_unpack(struct_format, buf):
    """Reads from io.BytesIO with format according to struct_format"""
    size = struct.calcsize(struct_format)
    data = buf.read(size)
    return struct.unpack(struct_format, data)

def parse_cycle_output(cycle_count, cycle_output):
    """Parse one cycle output"""
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
    if int.from_bytes(cycle_output, 'little') == 0:
        # Hack to wait for initialization
        print('Waiting...')
        return
    buf_io = io.BytesIO(cycle_output)
    # Decode instruction from USB debug port
    pc, condition, format = _io_unpack('>I2B', buf_io)
    print(f'pc={pc}', end=' ')
    if condition in _COND_CODES:
        print(f'{_COND_CODES[condition]}', end=' ')
    else:
        printf(f'unknown cond={condition}', end=' ')
    if format == 0:
        # Data processing
        struct_format = '>IIBB'
        (
            Rn_out, Rd_out,
            opcode, Rn, Rd,
            operand
        ) = _io_unpack('>2I3BH', buf_io)
        if opcode in _DATA_OPCODES:
            print(_DATA_OPCODES[opcode], end=' ')
        else:
            print(f'Unknown data op ({bin(opcode)})', end=' ')
        print(f'Rd[{Rd}]={Rd_out}, Rn[{Rn}]={Rn_out}, operand={operand}')
    elif format == 1:
        # Memory instruction
        (
            Rn_out, Rd_out,
            Rn, Rd, is_load,
            mem_offset
        ) = _io_unpack('>2I3BH', buf_io)
        mem_inst_name = 'LDR' if is_load else 'STR'
        print(f'{mem_inst_name} Rd[{Rd}]={Rd_out} Rn[{Rn}]={Rn_out} offset={mem_offset}')
    elif format == 2:
        # Branch instruction
        branch_offset, branch_link = _io_unpack('>IB', buf_io)
        branch_name = 'BL' if branch_link else 'B'
        print(f'{branch_name} offset={branch_offset}')
    else:
        print(f'ERROR: Unknown instruction format: {format}')

def main():
    ports = tinyprog.get_ports(USB_ID)
    print(f'Found {len(ports)} serial port(s)')
    if not ports:
        return
    if len(ports) > 1:
        print('NOTE: Using first port')
    port = ports[0]
    read_loop = _read_loop(port)
    # Initialize read loop to accept ch
    next(read_loop)
    write_loop = _write_loop(port)
    print('===BEGIN SERIAL OUTPUT===')
    with port:
        try:
            while True:
                next(write_loop)
                ch = _align_serial_reads(port)
                cycle_count, cycle_output = read_loop.send(ch)
                if cycle_output is not None:
                    # Cycle output is None if it is the same cycle as last time
                    parse_cycle_output(cycle_count, cycle_output)
        except KeyboardInterrupt:
            print('Got KeyboardInterrupt. Exiting...')
        except serial.serialutil.SerialException as exc:
            print(f'ERROR: Serial connection threw error: {exc}')

if __name__ == '__main__':
    main()
