// Executes the instruction
// Responsibilities:
// - Computes the result of the data processing instruction, and sends result to writeback
// - Computes condition code and determines whether to execute instruction
// - Updates the Current Program State Register (CPSR) (at least the subset we support)
// - Computes new PC For branch instructions and sends new PC to writeback
// - Read and write data memory for processing instructions

`include "cpu/constants.svh"

module executor(
        input wire clk,
        // FSM control logic
        input wire nreset,
        input logic enable,
        output logic ready,
        // Datapath I/O
        output logic [`REG_COUNT_L2-1:0] Rd, // Result register to save
        output logic [`BIT_WIDTH-1:0] Rd_value,
        output logic [`BIT_WIDTH-1:0] new_pc,
        output logic update_pc, // Whether we have a new PC
        // Datapath values from decoder
		input logic [3:0] condition,
		input logic [3:0] opcode,
		input logic [1:0] format,
		input logic [`REG_COUNT_L2-1:0] decoder_Rd,
		input logic [11:0] operand,
		input logic [23:0] branch_offset,
		input logic [11:0] mem_offset,
		input logic branch_link,
		input logic is_load,
		input logic [`BIT_WIDTH-1:0] Rn_value,
		input logic [`BIT_WIDTH-1:0] operand2reg_value
    );

    // Data memory definition
    reg [7:0] data_memory [0:`DATA_SIZE-1];
    initial begin
        $readmemh("cpu/lab2_data.hex", data_memory);
    end

    // CPSR values
    // TODO

    // Read/write data memory
    always_comb begin
        if (format == `FMT_MEMORY) begin
        end
        else begin
        end
    end
    always_ff @(posedge clk) begin
        if (nreset) begin
        end
        else begin
        end
    end
endmodule
