#!/usr/bin/env python3
# -*- coding: utf-8 -*-

"""Writes a flat DUT containing all CPU modules for cocotb testing"""

from pathlib import Path
import argparse
import re

TESTS_DIR = Path(__file__).resolve().parent
ROOT_DIR = TESTS_DIR.parent

# CPU source input files
CPU_SRC_DIR = ROOT_DIR / 'cpu'
CPU_SRC_GLOB = '**/*.sv'

# Verilog module parsing
# NOTE: We are using a dumb regex that assumes all I/O is defined within "module foo(...);"
MODULE_HEADER_REGEX = re.compile(
    r"module[ ]+?(?P<name>[a-zA-Z0-9_]+?)[ ]*?\((?P<io>.+?)\);", flags=(re.MULTILINE | re.DOTALL))
MODULE_IO_NAME_REGEX = re.compile(
    r"(?P<io_prefix>(input|inout|output)[ ]+?.+?[ ]+?)(?P<io_name>[a-zA-Z0-9_]+)", flags=(re.MULTILINE | re.DOTALL))

# cocotb dut file output
SV_TMPL = """// AUTOGENERATED BY {script_name}
// DO NOT EDIT MANUALLY

`include "cpu/constants.svh"

module cocotb_dut(
/* verilator lint_off LITENDIAN */
{submodule_io}
/* verilator lint_on LITENDIAN */
);

{submodules}

endmodule
"""

def _strip_verilog_comments(sv_content):
    """Strips SystemVerilog multi-line and single-line comments"""
    # Strip multi-line comments
    start_idx = 0
    end_idx = len(sv_content)
    while True:
        try:
            comment_start = sv_content.index("/*", start_idx, end_idx)
        except ValueError:
            break
        try:
            comment_end = sv_content.index("*/", start_idx, end_idx) + 1
        except ValueError:
            raise ValueError('Multi-line comment does not end!')
        sv_content = sv_content[:comment_start] + sv_content[comment_end+1:]
        start_idx = comment_start
        end_idx = len(sv_content)
    def _strip_single_line_comment(line):
        try:
            return line[:line.index('//')]
        except ValueError:
            # No single-line comment delimiter found
            return line
    # Strip single-line comments
    sv_lines = sv_content.splitlines()
    return '\n'.join(_strip_single_line_comment(x) for x in sv_lines)

def get_cpu_files():
    """Yields all source files for the CPU"""
    yield from CPU_SRC_DIR.glob(CPU_SRC_GLOB)

def parse_verilog_module(sv_path):
    """
    Reads a SystemVerilog file and returns:

    - module name
    - module signal names
    - module input and output specifications for cocotb's DUT
    """
    sv_content = sv_path.read_text()
    # Strip out comments to prevent confusing everything below
    try:
        sv_content = _strip_verilog_comments(sv_content)
    except ValueError:
        raise ValueError(f'Could not strip comments in {sv_path}')
    # Get module header details
    content_match = MODULE_HEADER_REGEX.search(sv_content)
    if not content_match:
        raise ValueError('Regex failed parsing: ' + str(sv_path))
    module_name, module_io_str = content_match.group('name', 'io')
    # Strip out spacing/newlines on right so we can add a comma if we need to
    module_io_str = module_io_str.rstrip()
    # Get module IO names
    module_io_sequence = tuple(map(str.strip, module_io_str.split(',')))
    module_io_names = list()
    for io_entry in module_io_sequence:
        entry_match = MODULE_IO_NAME_REGEX.search(io_entry)
        if not entry_match:
            raise ValueError(f'Regex failed parsing IO entry {io_entry} in file {sv_path}')
        entry_name = entry_match.group('io_name')
        if not entry_name:
            raise ValueError(f'Got empty entry name for {io_entry} in file {sv_path}')
        module_io_names.append(entry_name)
    # Prefix module IO symbols with module name
    io_name_repl =  r"\g<io_prefix>" + module_name + r"_\g<io_name>"
    module_io_str, sub_count = MODULE_IO_NAME_REGEX.subn(io_name_repl, module_io_str)
    if sub_count != len(module_io_names):
        raise ValueError(f'sub_count != len(module_io_names) for file {sv_path}')
    return module_name, module_io_names, module_io_str

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('output_sv', type=Path, help='cocotb DUT SystemVerilog file to write')
    args = parser.parse_args()
    dut_io = list()
    dut_submodules = list()
    for sv_path in get_cpu_files():
        mod_name, mod_io_names, module_io_str = parse_verilog_module(sv_path)
        # Update DUT IO list
        dut_io.append(f"// Module: {mod_name}\n{module_io_str}")
        # Update DUT submodule instantiations
        dut_submodules.append(
            f'{mod_name} dut_{mod_name}(\n    ' + ',\n    '.join(f'.{x}({mod_name}_{x})' for x in mod_io_names) + ');'
        )
    dut_sv = SV_TMPL.format(
        script_name=__file__,
        submodule_io=',\n'.join(dut_io),
        submodules='\n'.join(dut_submodules),
    )
    # Make one-level parent only
    args.output_sv.parent.mkdir(exist_ok=True)
    args.output_sv.write_text(dut_sv)

if __name__ == '__main__':
    main()
