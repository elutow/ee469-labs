# UW ECE/CSE 469 Labs and Final Project

This branch contains the code for Lab 2. The parent branch is `upstream`.

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

## Testing

Requirements:

1. Install dependencies for cocotb: https://cocotb.readthedocs.io/en/latest/quickstart.html#native-linux-installation
2. Install GTKwave. For Debian/Ubuntu: `# apt install gtkwave`

Tests are written in cocotb with the Verilator backend. To run the cocotb tests:

```sh
apio verify
```

To show the waveform from the tests (requires GTKwave to be installed):

```sh
apio sim
```

## Development Notes

To get verbose compilation & synthesis output during builds (and statistics of FPGA resources used), add the `--verbose-yosys` flag to `apio build`.

To get verbose place & route output during builds, add the `--verbose-nextpnr` flag to `apio build`.

Caveats of using Verilator under cocotb: https://cocotb.readthedocs.io/en/latest/simulator_support.html#verilator

* It does not support delayed assignments
