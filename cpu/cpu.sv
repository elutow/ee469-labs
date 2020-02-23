// Top-level module for the ARM 32 CPU
// Responsibilities:
// - Controls the Program Counter state
// - Manages the state of all stages of instruction execution

`include "cpu/constants.svh"

module cpu(
        input wire clk,
        input wire nreset,
        output wire led,
        /* verilator lint_off LITENDIAN */
        output wire [8:`DEBUG_BYTES*8-1] debug_port_vector
        /* verilator lint_on LITENDIAN */
    );

    // Current instruction
    logic [`BIT_WIDTH-1:0] inst_fetch, inst_decode, next_inst_fetch, next_inst_decode;
    // Program Counter
    logic [`BIT_WIDTH-1:0] pc, next_pc;

    // Turn on LED when reset is not on
    assign led = nreset;

    // TODO: Multicycle logic
    // TODO: We should assert that only one stage's ready signal is on at a time
    // for the multicycle only
    logic fetcher_enable;
    logic fetcher_ready;
    //fetcher the_fetcher(
    //    .clk(clk), .nreset(nreset), .enable(fetcher_enable),
    //    .ready(fetcher_ready))

    always_ff @(posedge clk) begin
        if (nreset) begin
            pc <= next_pc;
        end
        else begin
            pc <= `BIT_WIDTH'b0;
        end
    end

    // TODO: We should move decoding to a seperate module that has a control
    // signal indicating when the decoding is completely done.
    // Also, have an input control signal that tells it to process the next instruction
    always_comb begin
        next_pc = pc + `BIT_WIDTH'd4;
        // Output to debug port
        //debug_port_vector[1*8:5*8-1] = pc;
        //debug_port_vector[5*8:6*8-1] = instruction_stage;
//
        //debug_port_vector[6*8:7*8-1] = regfile_read_addr1;
        //debug_port_vector[7*8:11*8-1] = regfile_read_value1;
        //debug_port_vector[11*8:12*8-1] = regfile_read_addr2;
        //debug_port_vector[12*8:16*8-1] = regfile_read_value2;
        //debug_port_vector[16*8:17*8-1] = regfile_write_addr1;
        //debug_port_vector[17*8:21*8-1] = regfile_write_value1;
    end   // comb
endmodule
