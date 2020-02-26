// Data memory supporting word-length reads/writes at byte-aligned addresses
// Reads take 1 clock cycle, writes take two clock cycles

`include "cpu/constants.svh"

// TODO: Finish refactoring and uncomment
/*
module data_memory(
        input logic clk,
        input logic nreset,
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

	// -------------
	// Reading logic
	// -------------

	logic [`BIT_WIDTH-1:0] prev_read_addr; // Used for comb logic on current clock cycle
    logic [`BIT_WIDTH-1:0] private_rd1, private_rd0; // read data: 1 is before 0 in address value
	logic [`DATA_SIZE_L2-1:0] private_rs1, private_rs0; // read selects
	logic [`DATA_SIZE_L2-1:0] private_next_rs1, private_next_rs0; // read selects

	// Compute private read selects
	always_comb begin
		`ifndef SYNTHESIS
			assert(read_addr < `DATA_SIZE - 4) else begin
				$error("read address is beyond data size: %h", read_addr);
			end
		`endif
		private_next_rs1 = read_addr[`DATA_SIZE_L2-1:2]; // Divide by 4 == LSR by 2
		private_next_rs0 = private_next_rs1 + `DATA_SIZE_L2'd1;
	end
	always_ff @(posedge clk) begin
		if (nreset) begin
			private_rs1 <= private_next_rs1;
			private_rs0 <= private_next_rs0;
		end
		else begin
			private_rs1 <= `DATA_SIZE_L2'b0;
			private_rs0 <= `DATA_SIZE_L2'b0;
		end
	end
	// Output private read data (data available on next clock cycle)
    assign private_rd1 = data_memory_ram[private_rs1];
    assign private_rd0 = data_memory_ram[private_rs0];
	// - Let [] denote a word boundary (i.e. read from data_memory_ram)
	// - Let wXbY denote the Xth word's Yth byte
	// Therefore arrangement of values is:
	// Values: [w1b3, w1b2, w1b1, w1b0], [w0b3, w0b2, w0b1, w0b0]
	// - read_addr points to w1b3
	// Process private read data (we are now on the next clock cycle)
    always_comb begin
        case (prev_read_addr[1:0]) // Byte offset within a word
            2'd0: read_value = private_rd1;
            2'd1: read_value = {
				private_rd1[`BYTE_2_UPPER:`BYTE_0_LOWER],
				private_rd0[`BYTE_3_UPPER:`BYTE_3_LOWER]
			};
            2'd2: read_value = {
				private_rd1[`BYTE_1_UPPER:`BYTE_0_LOWER],
				private_rd0[`BYTE_3_UPPER:`BYTE_2_LOWER]
			};
            2'd3: read_value = {
				private_rd1[`BYTE_0_UPPER:`BYTE_0_LOWER],
				private_rd0[`BYTE_3_UPPER:`BYTE_1_LOWER]
			};
        endcase
    end

	// -------------
	// Writing logic
	// -------------

	// TODO: This needs to be refactored heavily
	// Also, writing requires at least two cycles:
	// 1. Read existing values
	// 2. Write back existing values

    logic [`BIT_WIDTH-1:0] internal_write_addr;
    logic [`BIT_WIDTH-1:0] memory_data, memory_data_next, memory_data_adjusted, memory_data_adjusted_next;    // temporary writing registers

    assign internal_write_addr = write_addr >> 2;    // divide write address by 4 to figure out which memory location it is in
    always_ff @(posedge clk) begin
        if (nreset) begin
            // MEMORY EXAMPLE DIAGRAM:     memory addr       memory (bytes)
            //                                  0           [03, 02, 01, 00]   =>   [31:24], [23:16], [15:8], [7:0]  bits
            //                                  1           [07, 06, 05, 04]
            //                                  2           [11, 10, 09, 08]
            //
            //    input read/write address corresponds to the individual byte, not the memory address
            // memory address is found by dividing the input address by 4 (right shift by 2)
            //
            // when writing to memory, the most significant bit of the value gets places into the higher memory address
            // EX. if 4 bytes (4, 3, 2, 1) are written to input address 03
            // then 03 <= 1, 04 <= 2, 05 <= 3, 06 <= 4
            if (write_enable) begin
                case (write_addr % 4)

                    0: begin        // write to all 4 bytes of memory location
                        data_memory_ram[internal_write_addr] <= write_value;
                    end

                    1: begin        // write to 3 most significant bytes of memory location, then write to least significant byte of next memory location
                        memory_data <= data_memory_ram[internal_write_addr];    // get original data inside memory location
                        memory_data_adjusted <= {write_value[23:0], memory_data[7:0]};    // concatenate new data without overwriting unused bytes (in this case, the least significant byte)
                        data_memory_ram[internal_write_addr] <= memory_data_adjusted;    // store new data into memory

                        // data overlaps into next memory location, so do the same thing with the last byte of data
                        memory_data_next <= data_memory_ram[internal_write_addr+1];
                        memory_data_adjusted_next <= {memory_data_next[31:8], write_value[31:24]};
                        data_memory_ram[internal_write_addr+1] <= memory_data_adjusted_next;
                    end

                    2: begin        // write to 2 most significant bytes of memory location, then write to 2 least significant bytes of next memory location
                        memory_data <= data_memory_ram[internal_write_addr];
                        memory_data_adjusted <= {write_value[15:0], memory_data[15:0]};
                        data_memory_ram[internal_write_addr] <= memory_data_adjusted;

                        memory_data_next <= data_memory_ram[internal_write_addr+1];
                        memory_data_adjusted_next <= {memory_data_next[31:16], write_value[31:16]};
                        data_memory_ram[internal_write_addr+1] <= memory_data_adjusted_next;
                    end

                    3: begin        // write to most significant byte of memory location, then write to 3 least significant bytes of next memory location
                        memory_data <= data_memory_ram[internal_write_addr];
                        memory_data_adjusted <= {write_value[7:0], memory_data[23:0]};
                        data_memory_ram[internal_write_addr] <= memory_data_adjusted;

                        memory_data_next <= data_memory_ram[internal_write_addr+1];
                        memory_data_adjusted_next <= {memory_data_next[31:24], write_value[31:8]};
                        data_memory_ram[internal_write_addr+1] <= memory_data_adjusted_next;
                    end
                endcase

            end
        end
        else begin
            memory_data <= 32'b0;
            memory_data_next <= 32'b0;
            memory_data_adjusted <= 32'b0;
            memory_data_adjusted_next <= 32'b0;
        end
    end    // ff
endmodule
*/
