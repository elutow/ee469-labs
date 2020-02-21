// Writes back the result of executor to the regfile
// Responsibilities:
// - Updates the PC register with value from executor
// - Stores result of executor into the indicated register in regfile

module regfilewriter(
        input wire clk,
        // FSM control logic
        input wire nreset,
        input logic enable,
        output logic ready,
        // From executor
        input logic [`BIT_WIDTH-1:0] executor_inst,
        input logic update_pc, // Whether we have a new PC
        input logic [`BIT_WIDTH-1:0] new_pc,
        input logic update_Rd, // Whether we should update Rd (result) in writeback
        input logic [`REG_COUNT_L2-1:0] Rd, // Result register to save
        input logic [`BIT_WIDTH-1:0] Rd_value,
    );
endmodule
