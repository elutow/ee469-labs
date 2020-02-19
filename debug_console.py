#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import serial
import tinyprog
import usb

from cpu_output import parse_cycle_output

# Adjust this number to be the number of debug bytes
DEBUGBYTES = 32-1
# FPGA device USB ID
USB_ID = '1d50:6130'

def _align_serial_reads(port):
    """Ignore serial port values with 255 and align reads to DEBUGBYTES"""
    ch=port.read(1)
    while int(ch[0]) != 255:
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
