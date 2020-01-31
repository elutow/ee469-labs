// TODO: Move macros to include
// Register & instruction depths
`define BIT_WIDTH 32
// Size of register file
`define REG_COUNT 16
// TODO: Change to correct number of instructions
`define INST_COUNT 64
// TODO: Combine with debug_bytes constant in top.v
`define DEBUG_BYTES 32

module cpu(
        input wire clk,
        input wire nreset,
        output wire led,
        output wire [8:`DEBUG_BYTES*8-1] debug_port_vector,
    );

    // Executable code
    reg [`BIT_WIDTH-1:0] code_memory [0:`INST_COUNT-1];
    // Register file and outputs
    reg [`BIT_WIDTH-1:0] register_file [0:`REG_COUNT-1];
    logic [`BIT_WIDTH-1:0] Rn_out, Rd_out;
    // Current instruction
    logic [`BIT_WIDTH-1:0] inst_fetch, inst_decode;
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

    initial begin
        //$readmemh("testcode/code.hex", code_memory);
        $readmemh("cpu/lab1_code.hex", code_memory);
        $readmemh("cpu/regfile_init.hex", register_file);
    end

    // Turn on LED when reset is not on
    assign led = nreset;

    // TODO: We should move decoding to a seperate module that has a control
    // signal indicating when the decoding is completely done.
    // Also, have an input control signal that tells it to process the next instruction
    always_comb begin
        // Update program counter
        next_pc = pc + `BIT_WIDTH'd4;
        // TODO: Move instruction formats to constants
        if (format == 2'b10) begin
            // TODO: Handle offset determined by register (i.e. non-immediate)
            // TODO: Handle link register
            next_pc = branch_offset;
        end
        // Output to debug port
        debug_port_vector[1*8:5*8-1] = pc;
        debug_port_vector[16*8:17*8-1] = {2'b0, condition, format};
        case (format)
            // data processing
            2'b00: begin
                debug_port_vector[5*8:9*8-1] = Rn_out;
                debug_port_vector[9*8:13*8-1] = Rd_out;
                debug_port_vector[13*8:14*8-1] = {opcode, Rn};
                debug_port_vector[14*8:16*8-1] = {Rd, operand};
            end
            // memory instruction
            2'b01: begin
                debug_port_vector[5*8:9*8-1] = Rn_out;
                debug_port_vector[9*8:13*8-1] = Rd_out;
                debug_port_vector[13*8:14*8-1] = {Rn, Rd};
                debug_port_vector[14*8:16*8-1] = {3'b0, is_load, mem_offset};
            end
            // branch instruction
            2'b10: begin
                debug_port_vector[5*8:8*8-1] = branch_offset;
                debug_port_vector[8*8:9*8-1] = {7'b0, branch_link};
            end
            default: begin
                debug_port_vector[8:`DEBUG_BYTES*8-1] = 256'b0;
            end
        endcase
    end

    // TODO: Split into separate always_ff for different pipeline stages
    // Clocked values
    always_ff @(posedge clk) begin
        if (nreset) begin
            // Stages of instruction value
            // Every stage
            pc <= next_pc;
            // Fetch
            inst_fetch <= code_memory[pc >> 2];
            // Decode
            inst_decode <= inst_fetch;
            // TODO: This output is one clock cycle behind instruction parsing
            Rn_out <= register_file[Rn];
            Rd_out <= register_file[Rd];
        end
        else begin
            inst_fetch <= `BIT_WIDTH'b0;
            inst_decode <= `BIT_WIDTH'b0;
            pc <= `BIT_WIDTH'b0;
            Rn_out <= `BIT_WIDTH'b0;
            Rd_out <= `BIT_WIDTH'b0;
        end
    end

    // Instantiate modules
    decoder inst_decoder(
        .inst(inst_decode),
        .condition(condition),
        .opcode(opcode), .format(format), .Rn(Rn), .Rd(Rd), .operand(operand),
        .branch_offset(branch_offset), .mem_offset(mem_offset),
        .branch_link(branch_link), .is_load(is_load),
        );
endmodule
