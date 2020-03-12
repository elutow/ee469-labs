# -*- coding: utf-8 -*-
# ----------------------------------------------------------------------
# -- Generic Scons script for Sintesizing hardware on an FPGA and more.
# -- This file is part of the Apio project
# -- (C) 2016-2018 FPGAwars
# -- Authors Juan Gonzáles, Jesús Arroyo
# -- Licence GPLv2
# ----------------------------------------------------------------------

import os
import re
import sys
from platform import system

from SCons.Script import (Builder, Command, Clean, DefaultEnvironment, Default, AlwaysBuild,
                          GetOption, Exit, COMMAND_LINE_TARGETS, ARGUMENTS,
                          Variables, Help, Glob)

# -- Load arguments
PROG = ARGUMENTS.get('prog', '')
FPGA_SIZE = ARGUMENTS.get('fpga_size', '')
FPGA_TYPE = ARGUMENTS.get('fpga_type', '')
FPGA_PACK = ARGUMENTS.get('fpga_pack', '')
VERBOSE_ALL = ARGUMENTS.get('verbose_all', False)
VERBOSE_YOSYS = ARGUMENTS.get('verbose_yosys', False)
VERBOSE_NEXTPNR = ARGUMENTS.get('verbose_nextpnr', False)
VERILATOR_ALL = ARGUMENTS.get('all', False)
VERILATOR_NO_STYLE = ARGUMENTS.get('nostyle', False)
VERILATOR_NO_WARN = ARGUMENTS.get('nowarn', '').split(',')
VERILATOR_WARN = ARGUMENTS.get('warn', '').split(',')
VERILATOR_TOP = ARGUMENTS.get('top', 'cpu')
VERILATOR_PARAM_STR = ''
for warn in VERILATOR_NO_WARN:
    if warn != '':
        VERILATOR_PARAM_STR += ' -Wno-' + warn

for warn in VERILATOR_WARN:
    if warn != '':
        VERILATOR_PARAM_STR += ' -Wwarn-' + warn

# -- Size. Possible values: 1k, 8k
# -- Type. Possible values: hx, lp
# -- Package. Possible values: swg16tr, cm36, cm49, cm81, cm121, cm225, qn84,
# --   cb81, cb121, cb132, vq100, tq144, ct256

# -- Add the FPGA flags as variables to be shown with the -h scons option
vars = Variables()
vars.Add('fpga_size', 'Set the ICE40 FPGA size (1k/8k)', FPGA_SIZE)
vars.Add('fpga_type', 'Set the ICE40 FPGA type (hx/lp)', FPGA_TYPE)
vars.Add('fpga_pack', 'Set the ICE40 FPGA packages', FPGA_PACK)

# -- Create environment
env = DefaultEnvironment(ENV=os.environ,
                         tools=[],
                         variables=vars)

# -- Show all the flags defined, when scons is invoked with -h
Help(vars.GenerateHelpText(env))

# -- Just for debugging
if 'build' in COMMAND_LINE_TARGETS or \
   'upload' in COMMAND_LINE_TARGETS or \
   'time' in COMMAND_LINE_TARGETS:

    # print('FPGA_SIZE: {}'.format(FPGA_SIZE))
    # print('FPGA_TYPE: {}'.format(FPGA_TYPE))
    # print('FPGA_PACK: {}'.format(FPGA_PACK))

    if 'upload' in COMMAND_LINE_TARGETS:

        if PROG == '':
            print('Error: no programmer command found')
            Exit(1)

        # print('PROG: {}'.format(PROG))

# -- Resources paths
IVL_PATH = os.environ['IVL'] if 'IVL' in os.environ else ''
VLIB_PATH = os.environ['VLIB'] if 'VLIB' in os.environ else ''
VLIB_F_GLOB = Glob(os.path.join(VLIB_PATH, '*.v')) + Glob(os.path.join(VLIB_PATH, '*.sv'))
VLIB_F = ['"{}"'.format(f) for f in VLIB_F_GLOB]
VLIB_FILES = ' '.join(VLIB_F) if VLIB_PATH else ''
ICEBOX_PATH = os.environ['ICEBOX'] if 'ICEBOX' in os.environ else ''
CHIPDB_PATH = os.path.join(ICEBOX_PATH, 'chipdb-{0}.txt'.format(FPGA_SIZE))
VERILATOR_PATH = os.environ['VERLIB'] if 'VERLIB' in os.environ else ''
VERILATOR_TESTS = ','.join(map(
    lambda x: os.path.splitext(os.path.basename(str(x)))[0],
    Glob('tests/*_cocotb.py')))
COCOTB_DUT_PATH = 'tests/gen/cocotb_dut.sv'
COCOTB_DUT_NAME = 'cocotb_dut'

# Yosys modules to include for Verilator linting
YOSYS_LIBRARIES = (
    'ice40/cells_sim.v',
)
YOSYS_LIBRARIES = tuple(map(lambda x: os.path.join(ICEBOX_PATH, '..', 'yosys', x), YOSYS_LIBRARIES))

isWindows = 'Windows' == system()
VVP_PATH = '' if isWindows or not IVL_PATH else '-M "{0}"'.format(IVL_PATH)
IVER_PATH = '' if isWindows or not IVL_PATH else '-B "{0}"'.format(IVL_PATH)

# -- Target name
TARGET = 'hardware'

# -- Scan required .list files
list_files_re = re.compile(r'[\n|\s][^\/]?\"(.*\.list?)\"', re.M)


def list_files_scan(node, env, path):
    contents = node.get_text_contents()
    includes = list_files_re.findall(contents)
    return env.File(includes)


list_scanner = env.Scanner(function=list_files_scan)

# Get all cpu/ verilog files
cpu_verilog_nodes = Glob('cpu/*.v') + Glob('cpu/*.sv')
src_cpu = [str(f) for f in cpu_verilog_nodes]

# -- Get a list of all the verilog files in the src folfer, in ASCII, with
# -- the full path. All these files are used for the simulation
v_nodes = Glob('*.v') + Glob('usb/*.v') + cpu_verilog_nodes
src_sim = [str(f) for f in v_nodes]

# --------- Get the Testbench file (there should be only 1)
# -- Create a list with all the files finished in _tb.v. It should contain
# -- the test bench
list_tb = [f for f in src_sim if f[-5:].upper() in ['_TB.V', '_TB.SV']]

if len(list_tb) > 1:
    print('Warning: more than one testbenches used')

SIMULNAME = ''
TARGET_SIM = ''

# -- Target sim name
if SIMULNAME:
    TARGET_SIM = SIMULNAME  # .replace('\\', '\\\\')

# -------- Get the synthesis files.  They are ALL the files except the
# -------- testbench
src_synth = [f for f in src_sim if f not in list_tb]

if len(src_synth) == 0:
    print('Error: no (system)verilog files found (.v or .sv)')
    Exit(1)

# -- For debugging
# print('Testbench: {}'.format(testbench))
# print('SIM NAME: {}'.format(SIMULNAME))

# -- Get the PCF file
PCF = ''
PCF_list = Glob('*.pcf')

try:
    PCF = PCF_list[0]
except IndexError:
    print('\n---> WARNING: no PCF file found (.pcf)\n')

# -- Debug
# print('PCF Found: {}'.format(PCF))

# -- Define the Sintesizing Builder
synth = Builder(
    action='yosys -p \"read_verilog -sv -nolatches $SOURCES ; synth_ice40 -abc9 -json $TARGET\" {}'.format(
        '' if VERBOSE_ALL or VERBOSE_YOSYS else '-q'
    ),
    suffix='.json',
    src_suffix=['.v', '.sv'],
    source_scanner=list_scanner)

pnr = Builder(
    action='nextpnr-ice40 --freq 16 --randomize-seed --{0}{1} --package {2} --pcf {3} --asc $TARGET {4} --json $SOURCE'.format(
        FPGA_TYPE, FPGA_SIZE, FPGA_PACK, PCF,
        '' if VERBOSE_ALL or VERBOSE_NEXTPNR else '-q'),
    suffix='.asc',
    src_suffix='.json')

bitstream = Builder(
    action='icepack $SOURCE $TARGET',
    suffix='.bin',
    src_suffix='.asc')

# -- Icetime builder
# https://github.com/cliffordwolf/icestorm/issues/57
time_rpt = Builder(
    action='icetime -d {0}{1} -P {2} -C "{3}" -mtr $TARGET $SOURCE'.format(
        FPGA_TYPE, FPGA_SIZE, FPGA_PACK, CHIPDB_PATH),
    suffix='.rpt',
    src_suffix='.asc')

# -- Build the environment
env.Append(BUILDERS={
    'Synth': synth, 'PnR': pnr, 'Bin': bitstream, 'Time': time_rpt})

# -- Generate the bitstream
synth_json = env.Synth(TARGET, [src_synth])
asc = env.PnR(TARGET, [synth_json, PCF])
bitstream = env.Bin(TARGET, asc)

build = env.Alias('build', bitstream)
AlwaysBuild(build)

# -- Upload the bitstream into FPGA
upload = env.Alias('upload', bitstream, '{0} $SOURCE'.format(PROG))
AlwaysBuild(upload)

# -- Target time: calculate the time
rpt = env.Time(asc)
t = env.Alias('time', rpt)
AlwaysBuild(t)

# -- Generate cocotb DUT module
cocotb_dut_builder = Command(
    File(COCOTB_DUT_PATH), src_cpu,
    f'{sys.executable} tests/generate_cocotb_dut.py $TARGET'
)
AlwaysBuild(cocotb_dut_builder)

# -- cocotb + verilator builder
src_cocotb = src_cpu.copy()
src_cocotb.append(COCOTB_DUT_PATH)
src_cocotb_abs = tuple(map(os.path.abspath, src_cocotb))
cocotb_out = [Dir('tests/build'), Dir('tests/sim_build'), File('tests/dump.vcd'), File('tests/results.xml')]
cocotb_builder = Command(
    cocotb_out, File(COCOTB_DUT_PATH),
    'make PYTHON_BIN={0} VERILOG_SOURCES="{1}" TOPLEVEL={2} MODULE="{3}"'.format(
        sys.executable, ' '.join(src_cocotb_abs), COCOTB_DUT_NAME, VERILATOR_TESTS),
    chdir='tests')
Clean(cocotb_builder, cocotb_out)
AlwaysBuild(cocotb_builder)

vcd_fst = Command(
    'tests/dump.vcd.fst', 'tests/dump.vcd',
    'vcd2fst -p $SOURCE $TARGET')

# --- Verify
# Check that we have cocotb test modules
if 'verify' in COMMAND_LINE_TARGETS:
    if not VERILATOR_TESTS:
        print('Error: no cocotb tests found under "tests" directory')
        Exit(1)

verify = env.Alias('verify', cocotb_builder)
AlwaysBuild(verify)

# --- Simulation
waves = env.Alias('sim', vcd_fst, 'gtkwave {0}'.format(
    vcd_fst[0]))
AlwaysBuild(waves)

# -- Verilator builder
verilator = Builder(
    action='verilator --lint-only -I{0} {1} {2} {3} {4} {5} $SOURCES'.format(
        VERILATOR_PATH,
        ' '.join(map('-v {}'.format, YOSYS_LIBRARIES)),
        '-Wall' if VERILATOR_ALL else '',
        '-Wno-style' if VERILATOR_NO_STYLE else '',
        VERILATOR_PARAM_STR if VERILATOR_PARAM_STR else '',
        '--top-module ' + VERILATOR_TOP if VERILATOR_TOP else ''),
    src_suffix=['.v', '.sv'],
    source_scanner=list_scanner)

env.Append(BUILDERS={'Verilator': verilator})

# --- Lint
lout = env.Verilator(TARGET, src_cpu)

lint = env.Alias('lint', lout)
AlwaysBuild(lint)

Default(bitstream)

# -- These is for cleaning the files generated using the alias targets
if GetOption('clean'):
    env.Default([t, cocotb_builder, vcd_fst])

# vim: set expandtab shiftwidth=4 softtabstop=4:
