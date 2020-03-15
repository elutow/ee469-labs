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
        output logic [`BIT_WIDTH-1:0] Rd_value,
        // Forward output values to executor
        output logic fwd_has_Rd,
        output logic [`REG_COUNT_L2-1:0] fwd_Rd_addr,
        output logic [`BIT_WIDTH-1:0] fwd_Rd_value
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
    logic [`BIT_WIDTH-1:0] next_memaccessor_inst;
    logic next_update_pc;
    logic [`BIT_WIDTH-1:0] next_new_pc;
    logic next_update_Rd;
    always_comb begin
        next_memaccessor_inst = memaccessor_inst;
        next_update_pc = update_pc;
        next_new_pc = new_pc;
        next_update_Rd = update_Rd;
        if (next_ready) begin
            next_memaccessor_inst = executor_inst;
            next_update_pc = executor_update_pc;
            next_new_pc = executor_new_pc;
            next_update_Rd = executor_update_Rd;
        end
    end
    always_ff @(posedge clk) begin
        if (nreset) begin
            memaccessor_inst <= next_memaccessor_inst;
            update_pc <= next_update_pc;
            new_pc <= next_new_pc;
            update_Rd <= next_update_Rd;
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

    // Determine Rd value and forwarding
    // First clock cycle
    logic next_fwd_has_Rd;
    logic [`REG_COUNT_L2-1:0] next_fwd_Rd_addr;
    always_comb begin
        next_fwd_has_Rd = fwd_has_Rd;
        next_fwd_Rd_addr = fwd_Rd_addr;
        if (next_ready && next_update_Rd) begin
            next_fwd_has_Rd = 1'b1;
            if (decode_format(next_memaccessor_inst) == `FMT_BRANCH) begin
                next_fwd_has_Rd = 1'b0;
            end
            else begin
                next_fwd_Rd_addr = decode_Rd(next_memaccessor_inst);
            end
        end
    end // comb
    always_ff @(posedge clk) begin
        if (nreset) begin
            fwd_has_Rd <= next_fwd_has_Rd;
            fwd_Rd_addr <= next_fwd_Rd_addr;
        end
        else begin
            fwd_has_Rd <= 1'b0;
            fwd_Rd_addr <= `REG_COUNT_L2'b0;
        end
    end // ff
    // Second clock cycle
    logic [`BIT_WIDTH-1:0] prev_Rd_value;
    logic [`BIT_WIDTH-1:0] prev_databranch_Rd_value;
    assign fwd_Rd_value = Rd_value;
    always_comb begin
        Rd_value = prev_Rd_value;
        if (ready) begin
            Rd_value = prev_databranch_Rd_value;
            // NOTE: update_Rd can be 1 only if the instruction passes conditions
            if (decode_format(memaccessor_inst) == `FMT_MEMORY) begin
                `ifndef SYNTHESIS
                    assert(decode_mem_is_load(memaccessor_inst) == update_Rd) else begin
                        $error("Failed is_load (%b) == update_Rd (%b) for inst %h",
                            decode_mem_is_load(memaccessor_inst), update_Rd,
                            memaccessor_inst
                        );
                    end
                `endif // SYNTHESIS
                if (update_Rd) begin
                    Rd_value = read_value;
                end
            end
        end
    end // comb
    always_ff @(posedge clk) begin
        if (nreset) begin
            prev_Rd_value <= Rd_value;
            prev_databranch_Rd_value <= databranch_Rd_value;
        end
        else begin
            prev_Rd_value <= `BIT_WIDTH'b0;
            prev_databranch_Rd_value <= `BIT_WIDTH'b0;
        end
    end
endmodule
