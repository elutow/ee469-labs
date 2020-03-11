// Data memory module
// Implements a data memory supporting word-length reads/writes at byte-aligned addresses
// Reads take 1 clock cycle, writes take two clock cycles
// NOTE: We don't support simultaneous read and write to different address

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
    // Wires/registers
    // ---------------
    // See logic below for more details about these registers

    // Shared read/write wires/registers
    logic [`DATA_SIZE_L2-1:0] private_rs1, private_rs0; // ram read selects
    logic [`DATA_SIZE_L2-1:0] private_next_rs1, private_next_rs0; // ram read selects
    logic [`BIT_WIDTH-1:0] private_rd1, private_rd0; // ram read data: 1 is before 0 in address value

    // Read wires/registers

    logic [`BIT_WIDTH-1:0] prev_read_addr; // Used for comb logic on current clock cycle
    logic [`BIT_WIDTH-1:0] private_read1, private_read0; // read value resolved to either ram or values being written

    // Write wires/registers

    // Read selects for orig values
    logic [`BIT_WIDTH-1:0] prev_write_addr, prev_write_value;
    logic prev_write_enable;
    // Write select for reading orig values at first edge, and writing new values at second edge
    logic [`DATA_SIZE_L2-1:0] private_ws1, private_ws0;
    logic [`DATA_SIZE_L2-1:0] private_next_ws1, private_next_ws0;
    // Write data set at second clock edge
    logic [`BIT_WIDTH-1:0] private_wd1, private_wd0;

    // -------------------------------
    // Shared logic for read and write
    // -------------------------------

    // Because of limited read ports, we have to share the read ports

    // Compute shared read select
    always_comb begin
        if (write_enable) begin
            // We are in write mode; ignore read requests
            private_next_rs1 = private_next_ws1;
            private_next_rs0 = private_next_ws0;
        end
        else begin
            `ifndef SYNTHESIS
                assert(read_addr < 4*(`DATA_SIZE-1)) else begin
                    $error("read address is beyond data size: %h", read_addr);
                end
            `endif
            private_next_rs1 = read_addr[`DATA_SIZE_L2+1:2]; // Divide by 4 == LSR by 2
            private_next_rs0 = private_next_rs1 + `DATA_SIZE_L2'd1;
        end
    end // comb
    // Shared read data
    assign private_rd1 = data_memory_ram[private_rs1];
    assign private_rd0 = data_memory_ram[private_rs0];

    // -------------
    // Reading logic
    // -------------

    always_ff @(posedge clk) begin
        if (nreset) begin
            private_rs1 <= private_next_rs1;
            private_rs0 <= private_next_rs0;
            prev_read_addr <= read_addr;
        end
        else begin
            private_rs1 <= `DATA_SIZE_L2'b0;
            private_rs0 <= `DATA_SIZE_L2'b0;
            prev_read_addr <= `BIT_WIDTH'b0;
        end
    end // ff
    // Determine read data values based on values being written
    // Prevents data hazard when data is being written on the second write cycle
    always_comb begin
        private_read1 = private_rd1;
        private_read0 = private_rd0;
        if (prev_write_enable) begin
            if (private_rs1 == private_ws1) private_read1 = private_wd1;
            if (private_rs1 == private_ws0) private_read1 = private_wd0;
            if (private_rs0 == private_ws1) private_read0 = private_wd1;
            if (private_rs0 == private_ws0) private_read0 = private_wd0;
        end
    end
    // - Let [] denote a word boundary (i.e. read from data_memory_ram)
    // - Let wXbY denote the Xth word's Yth byte
    // Therefore arrangement of values is:
    // Values: [w1b3, w1b2, w1b1, w1b0], [w0b3, w0b2, w0b1, w0b0]
    // - read_addr points to w1b3
    // Process private read data (we are now on the next clock cycle)
    always_comb begin
        case (prev_read_addr[1:0]) // Byte offset within a word
            2'd0: read_value = private_read1;
            2'd1: read_value = {
                private_read1[`BYTE_2_UPPER:`BYTE_0_LOWER],
                private_read0[`BYTE_3_UPPER:`BYTE_3_LOWER]
            };
            2'd2: read_value = {
                private_read1[`BYTE_1_UPPER:`BYTE_0_LOWER],
                private_read0[`BYTE_3_UPPER:`BYTE_2_LOWER]
            };
            2'd3: read_value = {
                private_read1[`BYTE_0_UPPER:`BYTE_0_LOWER],
                private_read0[`BYTE_3_UPPER:`BYTE_1_LOWER]
            };
        endcase
    end // comb

    // -------------
    // Writing logic
    // -------------

    // There are two clock cycles here:
    // 1. Read the two original words overlapping write addr + word size (4 bytes)
    // 2. Write back the two words modified with the write value

    // First clock cycle: Read old value
    // Compute private orig value read selects
    // NOTE: These write selects will be used above in shared read/write code
    // when write is enabled
    always_comb begin
        `ifndef SYNTHESIS
            assert(write_addr < 4*(`DATA_SIZE-1)) else begin
                $error("write address is beyond data size: %h", read_addr);
            end
        `endif
        private_next_ws1 = write_addr[`DATA_SIZE_L2+1:2]; // Divide by 4 == LSR by 2
        private_next_ws0 = private_next_ws1 + `DATA_SIZE_L2'd1;
    end
    always_ff @(posedge clk) begin
        if (nreset) begin
            private_ws1 <= private_next_ws1;
            private_ws0 <= private_next_ws0;
        end
        else begin
            private_ws1 <= `DATA_SIZE_L2'b0;
            private_ws0 <= `DATA_SIZE_L2'b0;
        end
    end // comb

    // Second clock cycle: Write new values
    // Save important write information from first clock cycle
    always_ff @(posedge clk) begin
        if (nreset) begin
            prev_write_addr <= write_addr;
            prev_write_value <= write_value;
            prev_write_enable <= write_enable;
        end
        else begin
            prev_write_addr <= `BIT_WIDTH'b0;
            prev_write_value <= `BIT_WIDTH'b0;
            prev_write_enable <= 1'b0;
        end
    end // ff
    // Perform the writes
    always_comb begin
        // Compute write data
        private_wd1 = `BIT_WIDTH'bX;
        private_wd0 = `BIT_WIDTH'bX;
        case (prev_write_addr[1:0]) // Byte offset within a word
            2'd0: begin
                private_wd1 = prev_write_value;
            end
            2'd1: begin
                private_wd1 = {
                    private_rd1[`BYTE_3_UPPER:`BYTE_3_LOWER],
                    prev_write_value[`BYTE_3_UPPER:`BYTE_1_LOWER]
                };
                private_wd0 = {
                    prev_write_value[`BYTE_0_UPPER:`BYTE_0_LOWER],
                    private_rd0[`BYTE_2_UPPER:`BYTE_0_LOWER]
                };
            end
            2'd2: begin
                private_wd1 = {
                    private_rd1[`BYTE_3_UPPER:`BYTE_2_LOWER],
                    prev_write_value[`BYTE_3_UPPER:`BYTE_2_LOWER]
                };
                private_wd0 = {
                    prev_write_value[`BYTE_1_UPPER:`BYTE_0_LOWER],
                    private_rd0[`BYTE_1_UPPER:`BYTE_0_LOWER]
                };
            end
            2'd3: begin
                private_wd1 = {
                    private_rd1[`BYTE_3_UPPER:`BYTE_1_LOWER],
                    prev_write_value[`BYTE_3_UPPER:`BYTE_3_LOWER]
                };
                private_wd0 = {
                    prev_write_value[`BYTE_2_UPPER:`BYTE_0_LOWER],
                    private_rd0[`BYTE_0_UPPER:`BYTE_0_LOWER]
                };
            end
        endcase
    end // comb
    always_ff @(posedge clk) begin
        if (nreset && prev_write_enable) begin
            data_memory_ram[private_ws1] <= private_wd1;
            if (prev_write_addr[1:0] != 2'b0) begin
                // When not word-aligned, we need the second write port
                data_memory_ram[private_ws0] <= private_wd0;
            end
        end
    end // ff
endmodule
