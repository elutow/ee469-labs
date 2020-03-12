// Memory access stage
// Manages data memory for LDR/STR instructions
// Otherwise passes through commands from executor to regfilewriter

`include "cpu/constants.svh"

module memaccessor(
        input wire clk,
        // FSM control logic
        input wire nreset,
        input logic enable,
        output logic ready,
        // Instruction in pipeline
        input logic [`BIT_WIDTH-1:0] executor_inst,
        output logic [`BIT_WIDTH-1:0] memaccessor_inst,
        // Data memory I/O
        input logic [`BIT_WIDTH-1:0] read_addr,
        input logic write_enable,
        input logic [`BIT_WIDTH-1:0] write_addr,
        input logic [`BIT_WIDTH-1:0] write_value,
        // Passthrough from executor
        input logic executor_update_pc,
        input logic [`BIT_WIDTH-1:0] executor_new_pc,
        input logic executor_update_Rd,
        input logic [`BIT_WIDTH-1:0] databranch_Rd_value,
        output logic update_pc,
        output logic [`BIT_WIDTH-1:0] new_pc,
        output logic update_Rd,
        // Computed outputs
        output logic [`BIT_WIDTH-1:0] Rd_value
    );

    logic [`BIT_WIDTH-1:0] read_value;
    data_memory the_data_memory(
        .clk, .nreset, .read_addr, .read_value, .write_enable, .write_addr,
        .write_value
    );

    // Control logic
    // ---memaccessor FSM---
    // NOT READY
    // - !enable -> NOT READY
    // - enable -> READY
    // READY
    // - enable -> READY
    // - !enable -> NOT READY
    // NOTE: This FSM does not control its behavior
    logic next_ready;
    assign next_ready = enable;
    always_ff @(posedge clk) begin
        if (nreset) begin
            ready <= next_ready;
        end
        else begin
            ready <= 1'b0;
        end
        `ifndef SYNTHESIS
            // write_enable -> next_ready (implies operator)
            assert(!write_enable || next_ready);
        `endif // SYNTHESIS
    end // ff

    // Passthrough executor values
    always_ff @(posedge clk) begin
        if (nreset) begin
            memaccessor_inst <= executor_inst;
            update_pc <= executor_update_pc;
            new_pc <= executor_new_pc;
            update_Rd <= executor_update_Rd;
        end
        else begin
            memaccessor_inst <= `BIT_WIDTH'b0;
            update_pc <= 1'b0;
            new_pc <= `BIT_WIDTH'b0;
            update_Rd <= 1'b0;
        end
    end // ff

    // Validate inputs from executor
    `ifndef SYNTHESIS
    always_comb begin
        if (decode_format(executor_inst) != `FMT_MEMORY) begin
            // We should never write when we're not a memory instruction
            assert(!write_enable);
        end
        // write_enable imples !executor_update_Rd
        // Because: STR means enable write, but don't update Rd
        //          LDR means disable write, update Rd
        assert(!write_enable || !executor_update_Rd);
    end // comb
    `endif // SYNTHESIS

    // Determine Rd value
    always_comb begin
        Rd_value = databranch_Rd_value;
        // NOTE: update_Rd can be 1 only if the instruction passes conditions
        if (ready && decode_format(memaccessor_inst) == `FMT_MEMORY) begin
            `ifndef SYNTHESIS
                assert(decode_mem_is_load(memaccessor_inst) == update_Rd) else begin
                    $error("Failed is_load (%b) == update_Rd (%b) for inst %h",
                        decode_mem_is_load(memaccessor_inst), update_Rd,
                        memaccessor_inst
                    );
                end
            `endif // SYNTHESIS
            if (update_Rd) Rd_value = read_value;
        end
    end // comb
endmodule
