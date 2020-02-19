// Fetches the instruction from code memory based on the program counter
// Responsibilities:
// - Contains

`include "cpu/constants.svh"

module fetcher(
        input wire clk,
        input wire nreset,
        input logic [`BIT_WIDTH-1:0] pc,
        input wire enable,
        output logic [`BIT_WIDTH-1:0] inst,
        output logic ready
    );

    // Executable code
    reg [`BIT_WIDTH-1:0] code_memory [0:`INST_COUNT-1];
    // Clocked code memory read address
    // This is `BIT_WIDTH-1-2 to align to 4 bytes
    logic [`BIT_WIDTH-3:0] read_addr;
    // Contain pc >> 2
    logic [`BIT_WIDTH-3:0] pc_shifted;

    // ready should be set synchronously with inst
    logic next_ready;

    initial begin
        //$readmemh("testcode/code.hex", code_memory);
        $readmemh("cpu/lab1_code.hex", code_memory);
    end

    always_comb begin
        inst = code_memory[read_addr];
        next_ready = nreset & enable;
        pc_shifted = pc >> 2;
    end

    always_ff @(posedge clk) begin
        if (nreset) begin
            `ifndef SYNTHESIS
                assert(pc_shifted < `INST_COUNT) else begin
                    $error("pc out of range: %d", pc);
                end
                assert(pc[1:0] == 2'b00) else begin
                    $error("pc not aligned to 4 bytes: %d", pc);
                end
            `endif
            read_addr <= pc_shifted;
            ready <= next_ready;
        end
        else begin
            read_addr <= `BIT_WIDTH'b0;
            ready <= 0;
        end
    end
endmodule
