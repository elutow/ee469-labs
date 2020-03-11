// Data memory module
// Implements a data memory supporting word-length reads/writes at word-aligned addresses
// If the address is not word-aligned, it will be trimmed to a word
// Reads and writes both take one clock cycle
// Supports simultaneous reads/writes, regardless of addresses

`include "cpu/constants.svh"

module data_memory(
        input wire clk,
        input wire nreset,
        // Read ports
        input logic [`BIT_WIDTH-1:0] read_addr,
        output logic [`BIT_WIDTH-1:0] read_value,
        // Write ports
        input logic write_enable,
        input logic [`BIT_WIDTH-1:0] write_addr,
        input logic [`BIT_WIDTH-1:0] write_value
    );

    // Internal data memory representation
    // each location from 0:63 contains 4 addresses that correspond to the input address value
    logic [`BIT_WIDTH-1:0] data_memory_ram [0:`DATA_SIZE-1];
    initial begin
        $readmemh("cpu/init/data.hex", data_memory_ram);
    end

    // ---------------
    // Registers/wires
    // ---------------

    // Read select
    logic [`DATA_SIZE_L2-1:0] rsel, next_rsel;
    // Write select
    logic [`DATA_SIZE_L2-1:0] wsel;

    // -------------
    // Reading logic
    // -------------

    always_comb begin
        // Trim byte address to word
        next_rsel = read_addr[`DATA_SIZE_L2+1:2];
        `ifndef SYNTHESIS
            assert(32'(next_rsel) < `DATA_SIZE);
        `endif
    end // ff
    always_ff @(posedge clk) begin
        if (nreset) begin
            rsel <= next_rsel;
        end
        else begin
            rsel <= `DATA_SIZE_L2'b0;
        end
    end // ff

    // Data hazard: Writing to same address as reads
    logic [`DATA_SIZE_L2-1:0] prev_wsel;
    logic [`BIT_WIDTH-1:0] prev_write_value;
    logic prev_write_enable;
    always_ff @(posedge clk) begin
        if (nreset) begin
            prev_write_enable <= write_enable;
            prev_wsel <= wsel;
            prev_write_value <= write_value;
        end
        else begin
            prev_write_enable <= 1'b0;
            prev_wsel <= `DATA_SIZE_L2'b0;
            prev_write_value <= `BIT_WIDTH'b0;
        end
    end
    always_comb begin
        read_value = data_memory_ram[rsel];
        if (write_enable && rsel == prev_wsel) read_value = prev_write_value;
    end // comb

    // -------------
    // Writing logic
    // -------------

    always_comb begin
        // Trim byte address to word
        wsel = write_addr[`DATA_SIZE_L2+1:2];
        `ifndef SYNTHESIS
            assert(32'(wsel) < `DATA_SIZE);
        `endif
    end // comb
    always_ff @(posedge clk) begin
        if (nreset && write_enable) data_memory_ram[wsel] <= write_value;
    end // ff
endmodule
