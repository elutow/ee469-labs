// Top-level module for the ARM 32 CPU
// Responsibilities:
// - Controls the Program Counter state
// - Manages the state of all stages of instruction execution

`include "cpu/constants.svh"

// NOTE: Yosys 0.9 doesn't support enums
`define CPU_STATE_WIDTH 2
`define CPU_STATE_RESET `CPU_STATE_WIDTH'd0
`define CPU_STATE_START `CPU_STATE_WIDTH'd1
`define CPU_STATE_RUN `CPU_STATE_WIDTH'd2

module cpu(
        input wire clk,
        input wire nreset,
        output wire led,
        /* verilator lint_off LITENDIAN */
        output wire [8:`DEBUG_BYTES*8-1] debug_port_vector
        /* verilator lint_on LITENDIAN */
    );

    // Program Counter
    // NOTE: In pipelined version, we want to update PC here.
    logic [`BIT_WIDTH-1:0] pc;

    // CPU state
    logic [`CPU_STATE_WIDTH-1:0] ps, ns;

    // Turn on LED when reset is not on
    assign led = nreset;

    // Shared modules

    logic [`BIT_WIDTH-1:0] regfile_read_inst;
    logic [`REG_COUNT_L2-1:0] regfile_read_addr1, regfile_read_addr2;
    logic [`BIT_WIDTH-1:0] regfile_read_value1, regfile_read_value2;
    logic regfile_write_enable1;
    logic [`REG_COUNT_L2-1:0] regfile_write_addr1;
    logic [`BIT_WIDTH-1:0] regfile_write_value1;
    logic [`BIT_WIDTH-1:0] regfile_new_pc;
    logic regfile_update_pc;
    regfile the_regfile(
        .clk(clk), .nreset(nreset), .read_inst(regfile_read_inst),
        .read_addr1(regfile_read_addr1), .read_addr2(regfile_read_addr2),
        .read_value1(regfile_read_value1), .read_value2(regfile_read_value2),
        .write_enable1(regfile_write_enable1),
        .write_addr1(regfile_write_addr1), .write_value1(regfile_write_value1),
        .pc(pc), .new_pc(regfile_new_pc), .update_pc(regfile_update_pc)
    );

    // CPU stages

    logic fetcher_enable;
    logic fetcher_ready;
    logic [`BIT_WIDTH-1:0] fetcher_inst;
    fetcher the_fetcher(
        .clk(clk), .nreset(nreset), .enable(fetcher_enable),
        .ready(fetcher_ready), .pc(pc), .fetcher_inst(fetcher_inst)
    );

    logic [`BIT_WIDTH-1:0] decoder_inst;
    logic [`BIT_WIDTH-1:0] decoder_Rn_value, decoder_Rd_Rm_value;
    logic decoder_ready;
    decoder the_decoder(
        .clk(clk), .nreset(nreset), .enable(fetcher_ready),
        .ready(decoder_ready), .fetcher_inst(fetcher_inst),
        .decoder_inst(decoder_inst), .regfile_read_inst(regfile_read_inst),
        .regfile_read_addr1(regfile_read_addr1),
        .regfile_read_addr2(regfile_read_addr2),
        .regfile_read_value1(regfile_read_value1),
        .regfile_read_value2(regfile_read_value2),
        .Rn_value(decoder_Rn_value), .Rd_Rm_value(decoder_Rd_Rm_value)
    );

    logic executor_ready;
    logic [`BIT_WIDTH-1:0] executor_inst;
    logic executor_update_pc;
    logic [`BIT_WIDTH-1:0] executor_new_pc;
    logic executor_update_Rd;
    logic [`BIT_WIDTH-1:0] executor_Rd_value;
    executor the_executor(
        .clk(clk), .nreset(nreset), .enable(decoder_ready),
        .ready(executor_ready), .executor_inst(executor_inst),
        .update_pc(executor_update_pc), .pc(pc), .new_pc(executor_new_pc),
        .update_Rd(executor_update_Rd), .Rd_value(executor_Rd_value),
        .decoder_inst(decoder_inst), .Rn_value(decoder_Rn_value),
        .Rd_Rm_value(decoder_Rd_Rm_value)
    );

    logic regfilewriter_ready;
    regfilewriter the_regfilewriter(
        .clk(clk), .nreset(nreset), .enable(executor_ready),
        .ready(regfilewriter_ready), .pc(pc), .executor_inst(executor_inst),
        .update_pc(executor_update_pc),
        .new_pc(executor_new_pc), .update_Rd(executor_update_Rd),
        .Rd_value(executor_Rd_value),
        .regfile_write_enable1(regfile_write_enable1),
        .regfile_write_addr1(regfile_write_addr1),
        .regfile_write_value1(regfile_write_value1),
        .regfile_new_pc(regfile_new_pc),
        .regfile_update_pc(regfile_update_pc)
    );

    // Ensure only one ready signal is asserted at a time
    `ifndef SYNTHESIS
    logic [2:0] ready_asserted_count;
    always_comb begin
        ready_asserted_count = 3'b0;
        if (fetcher_ready) ready_asserted_count = ready_asserted_count + 3'b1;
        if (decoder_ready) ready_asserted_count = ready_asserted_count + 3'b1;
        if (executor_ready) ready_asserted_count = ready_asserted_count + 3'b1;
        if (regfilewriter_ready) ready_asserted_count = ready_asserted_count + 3'b1;
        assert(ready_asserted_count <= 3'b1) else begin
            $error(
                "More than one ready signal asserted!: %b",
                {fetcher_ready, decoder_ready, executor_ready, regfilewriter_ready}
            );
        end
    end
    `endif // SYNTHESIS

    // CPU FSM
    always_comb begin
        ns = ps;
        case (ps)
            `CPU_STATE_RESET: begin
                ns = `CPU_STATE_START;
            end
            `CPU_STATE_START: begin
                ns = `CPU_STATE_RUN;
            end
            `CPU_STATE_RUN: begin
                // no-op
            end
            default: begin
                `ifndef SYNTHESIS
                    $error("Invalid CPU state: %d", ps);
                `endif
            end
        endcase
    end // comb
    always_ff @(posedge clk) begin
        if (nreset) begin
            ps <= ns;
        end
        else begin
            ps <= `CPU_STATE_RESET;
        end
    end // ff
    // Two situations to enable fetcher:
    // - The CPU just started
    // - Execution is done and PC is updated (regfilewriter_ready is asserted)
    assign fetcher_enable = (ps == `CPU_STATE_START) || regfilewriter_ready;
    // Debug port outputs
    always_comb begin
        // Output to debug port
        debug_port_vector[1*8:5*8-1] = pc;
        debug_port_vector[5*8:6*8-1] = {
            4'b0, fetcher_ready, decoder_ready, executor_ready, regfilewriter_ready};
        debug_port_vector[6*8:7*8-1] = {4'b0, regfile_read_addr1};
        debug_port_vector[7*8:11*8-1] = regfile_read_value1;
        debug_port_vector[11*8:12*8-1] = {4'b0, regfile_read_addr2};
        debug_port_vector[12*8:16*8-1] = regfile_read_value2;
        debug_port_vector[16*8:17*8-1] = {4'b0, regfile_write_addr1};
        debug_port_vector[17*8:21*8-1] = regfile_write_value1;
        debug_port_vector[21*8:22*8-1] = {7'b0, regfile_write_enable1};
        debug_port_vector[22*8:26*8-1] = fetcher_inst;
    end   // comb
endmodule
