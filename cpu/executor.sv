// Executes the instruction
// Responsibilities:
// - Computes the result of the data processing instruction, and sends result to writeback
// - Computes condition code and determines whether to execute instruction
// - Updates the Current Program State Register (CPSR) (at least the subset we support)
// - Computes new PC For branch instructions and sends new PC to regfile
// - Read and write data memory for processing instructions

`include "cpu/constants.svh"

module executor(
        input wire clk,
        input wire nreset,
        input logic enable,
        output logic ready,
    );
endmodule
