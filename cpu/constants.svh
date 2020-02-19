`ifndef _CPU_CONSTANTS_SVH_
`define _CPU_CONSTANTS_SVH_

// NOTE: Yosys currently does not support enums
// See https://github.com/YosysHQ/yosys/issues/248

// Register & instruction depths
`define BIT_WIDTH 32
// Size of register file
`define REG_COUNT 16
`define REG_COUNT_L2 $clog2(`REG_COUNT)
`define REG_PC_INDEX `REG_COUNT_L2'd15
// TODO: Change to correct number of instructions
`define INST_COUNT 64
// DEBUG_BYTES Must be power of 2
`define DEBUG_BYTES 32

// ARM32 instruction constants
// Instruction formats
`define FMT_DATA 2'b00
`define FMT_MEMORY 2'b01
`define FMT_BRANCH 2'b10
// Data processing opcodes
`define DATAOP_EOR 4'b0001
`define DATAOP_SUB 4'b0010
`define DATAOP_ADD 4'b0100
`define DATAOP_TST 4'b1000
`define DATAOP_TEQ 4'b1001
`define DATAOP_CMP 4'b1010
`define DATAOP_ORR 4'b1100
`define DATAOP_MOV 4'b1101
`define DATAOP_BIC 4'b1110
`define DATAOP_MVN 4'b1111
// Condition codes
`define COND_EQ 4'b0000
`define COND_NE 4'b0001
`define COND_CS_HS 4'b0010
`define COND_CC_LO 4'b0011
`define COND_MI 4'b0100
`define COND_PL 4'b0101
`define COND_VS 4'b0110
`define COND_VC 4'b0111
`define COND_HI 4'b1000
`define COND_GE 4'b1010
`define COND_LT 4'b1011
`define COND_GT 4'b1100
`define COND_LE 4'b1101
`define COND_AL 4'b1110

`endif
