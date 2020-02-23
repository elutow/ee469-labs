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
    // Decoder outputs
    logic [3:0] condition;
    logic [3:0] opcode;
    logic [1:0] format;
    logic [3:0] Rn;
    logic [3:0] Rd;
    logic [11:0] operand;
    logic [23:0] branch_offset;
    logic [11:0] mem_offset;
    logic branch_link;
    logic is_load;
    // CPU internal state
    logic ps, ns;

    // TODO: Remove these after stages are finished and attached
    logic [`BIT_WIDTH-1:0] Rn_out, Rd_out;

    // TODO: We should assert that only one stage's ready signal is on at a time
    // for the multicycle only

    // Turn on LED when reset is not on
    assign led = nreset;

    // TODO: We should move decoding to a seperate module that has a control
    // signal indicating when the decoding is completely done.
    // Also, have an input control signal that tells it to process the next instruction
    always_comb begin
        // Always go to next state
        ns = ~ps;
        next_inst_fetch = inst_fetch;
        next_inst_decode = inst_decode;
        case (ps)
            1'b0: begin // Fetch
                // Update program counter
                next_pc = pc + `BIT_WIDTH'd4;
                // TODO: Move instruction formats to constants
                if (format == 2'b10) begin
                    // TODO: Handle offset determined by register (i.e. non-immediate)
                    // TODO: Handle link register
                    next_pc = pc + 32'd4 + {{6{branch_offset[23]}}, branch_offset, 2'b0};
                end

                // Fetch
                next_inst_fetch = `BIT_WIDTH'b0;
            end
            1'b1: begin // Decode
                next_inst_decode = inst_fetch;
                //next_Rn_out = register_file[Rn];
               // //next_Rd_out = register_file[Rd];
            end//
        endcase
        // Output to debug port
        debug_port_vector[1*8:5*8-1] = pc;
        debug_port_vector[5*8:6*8-1] = instruction_stage;

        debug_port_vector[6*8:7*8-1] = regfile_read_addr1;
        debug_port_vector[7*8:11*8-1] = regfile_read_value1;
        debug_port_vector[11*8:12*8-1] = regfile_read_addr2;
        debug_port_vector[12*8:16*8-1] = regfile_read_value2;
        debug_port_vector[16*8:17*8-1] = regfile_write_addr1;
        debug_port_vector[17*8:21*8-1] = regfile_write_value1;
    end   // comb

    // TODO: Split into separate always_ff for different pipeline stages
    // Clocked values
    always_ff @(posedge clk) begin
        if (nreset) begin
            // Stages of instruction value
            // Every stage
            pc <= next_pc;
            inst_fetch <= next_inst_fetch;
            inst_decode <= next_inst_decode;
            // TODO: This output is one clock cycle behind instruction parsing
            //Rn_out <= register_file[Rn];
            //Rd_out <= register_file[Rd];

            // NEW
            ps <= ns;
        end
        else begin
            inst_fetch <= `BIT_WIDTH'b0;
            inst_decode <= `BIT_WIDTH'b0;
            pc <= `BIT_WIDTH'b0;
            //Rn_out <= `BIT_WIDTH'b0;
            //Rd_out <= `BIT_WIDTH'b0;

            ps <= 1'b0;
        end
    end

    // Instantiate modules
    //decoder inst_decoder(
    //    .inst(inst_decode),
    //    .condition(condition),
    //    .opcode(opcode), .format(format), .Rn(Rn), .Rd(Rd), .operand(operand),
    //    .branch_offset(branch_offset), .mem_offset(mem_offset),
    //    .branch_link(branch_link), .is_load(is_load)
    //);
endmodule
