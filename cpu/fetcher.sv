// Fetches the instruction from code memory based on the program counter
// Responsibilities:
// - Contains

`include "cpu/constants.svh"

module fetcher(
        input wire clk,
        // FSM control logic
        input wire nreset,
        input logic enable,
        output logic ready,
        // Datapath I/O
        input logic [`BIT_WIDTH-1:0] pc,
        output logic [`BIT_WIDTH-1:0] fetcher_inst
    );

    // Executable code
    reg [`BIT_WIDTH-1:0] code_memory [0:`INST_COUNT-1];
    initial begin
        //$readmemh("testcode/code.hex", code_memory);
        $readmemh("cpu/lab2_code.hex", code_memory);
    end

    // Control logic
	// ---Fetcher FSM---
	// NOT READY
	// - !enable -> NOT READY
	// - enable -> READY
    //      - Fetch instruction
	// READY
    // - enable -> READY (keep processing at 1 instruction / cycle)
	// - !enable -> NOT READY (transition to halt)
    logic next_ready;
    assign next_ready = enable;
    always_ff @(posedge clk) begin
        if (nreset) begin
            ready <= next_ready;
        end
        else begin
            ready <= 1'b0;
        end
    end // ff

    // Datapath logic
    // Clocked code memory read address
    // This is `BIT_WIDTH-1-2 to align to 4 bytes
    logic [`BIT_WIDTH-3:0] read_addr;
    // Contain pc >> 2
    logic [`BIT_WIDTH-3:0] pc_shifted;
    always_comb begin
        fetcher_inst = code_memory[read_addr[`INST_COUNT_L2-1:0]];
        pc_shifted = {2'b0, pc[`BIT_WIDTH-1:2]}; // pc >> 2
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
        end
        else begin
            read_addr <= 30'b0; // `BIT_WIDTH - 2
        end
    end
endmodule
