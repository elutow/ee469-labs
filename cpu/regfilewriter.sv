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
        input logic [`BIT_WIDTH-1:0] Rd_value,
        // Regfile I/O
        output logic regfile_write_enable1,
        output logic [`REG_COUNT_L2-1:0] regfile_write_addr1,
        output logic [`BIT_WIDTH-1:0] regfile_write_value1,
        output logic [`BIT_WIDTH-1:0] regfile_new_pc,
        output logic regfile_update_pc
    );

    // Control logic
    // ---Writeback FSM---
    // NOT READY
    // - !enable -> NOT READY
    // - enable -> READY
    //      - Write to regfile
    // READY
    // - enable -> READY (keep processing at 1 instruction / cycle)
    // - !enable -> NOT READY (transition to halt)
    logic next_ready;
    assign next_ready = enable && !ready;
    always_ff @(posedge clk) begin
        if (nreset) begin
            ready <= next_ready;
        end
        else begin
            ready <= 1'b0;
        end
    end // ff

    // Datapath logic
    assign regfile_update_pc = next_ready && update_pc;
    assign regfile_new_pc = new_pc;
    assign regfile_write_value1 = Rd_value;
    always_comb begin
        regfile_write_enable1 = 1'b0;
        regfile_write_addr1 = `REG_COUNT_L2'bX;
        if (next_ready && update_Rd) begin
            regfile_write_enable1 = 1'b1;
            if (decode_format(executor_inst) == `FMT_BRANCH
                && decode_branch_is_link(executor_inst)) begin
                    // NOTE: In executor, we set the write value to the new
                    // value for the link register
                    regfile_write_addr1 = `REG_LR_INDEX;
            end
            else begin
                regfile_write_addr1 = decode_Rd(executor_inst);
            end
        end
    end // comb
endmodule
