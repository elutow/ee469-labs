# UW ECE/CSE 469 Labs and Final Project

This branch contains the code for Lab 1. The parent branch is `upstream`.

This repository contains the code for the UW EE/CSE 469 Labs and Final Project.

## Setup

Requirements:

* Python 3
* Linux for x86-64 (amd64). Environment is tested on Debian 10 (buster) amd64.

1. Follow instructions for setting up apio for TinyFPGA BX here: https://tinyfpga.com/bx/guide.html
	* NOTE: Skip the `pip install` steps and use the below
	* We used Python 3 when installing Python modules, e.g. on Debian: `pip3 install ...`
2. `pip3 install -r requirements.txt`
3. If you are setting up Atom, install `apio-ide` by typing in `FPGAwars/apio-ide` and selecting to download from git. This will fix any `apio` version incompatibility warnings.

## Uploading to FPGA

For command-line:

```sh
apio build
apio upload
```

Alternatively, you can use Atom with `apio-ide`.

## Development Notes

To get verbose place & route output during builds, use the following:

```sh
apio build --verbose-arachne
```

## Lab 1 Notes

General notes:

- Support condition codes on all instructions
- No need to support pre/post indexing for instructions

## ARM Optional Bit Flags

- S - sets condition codes
- B - byte operation
- H - halfword operation
- T - forces address translation.

## ARM Instructions

- B
  - This one definitely needs to support condition codes
- BL
- LDR
- Data processing instructions (TODO: Reference)
  - ADD
  - SUB
  - CMP
  - TST
  - TEQ
  - EOR
  - BIC
  - ORR
  - MOV
  - MVN
