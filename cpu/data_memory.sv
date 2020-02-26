// Data memory supporting word-length reads/writes at byte-aligned addresses

module data_memory(
	input logic clk, nreset, data_write_enable,
	input logic [31:0] data_read_addr, next_data_read_addr, data_write_addr,
	input logic [31:0] data_write_value,
	
	output logic [31:0] data_read_value
	);
	
	logic [31:0] memory_write_address, memory_read_address;
	logic [31:0] data_memory [0:63];	// each location from 0:63 contains 4 addresses that correspond to the input address value
	
	logic [31:0] memory_data, memory_data_next, memory_data_adjusted, memory_data_adjusted_next;	// temporary writing registers
	logic [31:0] read_data, read_data_next;	// temporary reading registers
	
	assign memory_write_address = data_write_addr >> 2;	// divide write address by 4 to figure out which memory location it is in
	
	always_ff @(posedge clk) begin
		if (nreset) begin
			// TODO: implement this logic, I can't think about this right now
			// data_read_addr <= next_data_read_addr;
			
			
			// MEMORY EXAMPLE DIAGRAM:			memory addr				memory (bytes)
			//													0					[03, 02, 01, 00]		=> 	[31:24], [23:16], [15:8], [7:0]	bits
			//													1					[07, 06, 05, 04]
			//													2					[11, 10, 09, 08]
			//
			//	input read/write address corresponds to the individual byte, not the memory address
			// memory address is found by dividing the input address by 4 (right shift by 2)
			// 
			// when writing to memory, the most significant bit of the value gets places into the higher memory address
			// EX. if 4 bytes (4, 3, 2, 1) are written to input address 03
				// then 03 <= 1, 04 <= 2, 05 <= 3, 06 <= 4
			if (data_write_enable) begin
				case (data_write_addr % 4) 
				
					0: begin		// write to all 4 bytes of memory location
						data_memory[memory_write_address] <= data_write_value;
					end
					
					1: begin		// write to 3 most significant bytes of memory location, then write to least significant byte of next memory location
						memory_data <= data_memory[memory_write_address];	// get original data inside memory location
						memory_data_adjusted <= {data_write_value[23:0], memory_data[7:0]};	// concatenate new data without overwriting unused bytes (in this case, the least significant byte)
						data_memory[memory_write_address] <= memory_data_adjusted;	// store new data into memory
						
						// data overlaps into next memory location, so do the same thing with the last byte of data
						memory_data_next <= data_memory[memory_write_address+1];
						memory_data_adjusted_next <= {memory_data_next[31:8], data_write_value[31:24]};
						data_memory[memory_write_address+1] <= memory_data_adjusted_next;
					end
					
					2: begin		// write to 2 most significant bytes of memory location, then write to 2 least significant bytes of next memory location
						memory_data <= data_memory[memory_write_address];	
						memory_data_adjusted <= {data_write_value[15:0], memory_data[15:0]};	
						data_memory[memory_write_address] <= memory_data_adjusted;
						
						memory_data_next <= data_memory[memory_write_address+1];
						memory_data_adjusted_next <= {memory_data_next[31:16], data_write_value[31:16]};
						data_memory[memory_write_address+1] <= memory_data_adjusted_next;
					end
					
					3: begin		// write to most significant byte of memory location, then write to 3 least significant bytes of next memory location
						memory_data <= data_memory[memory_write_address];	
						memory_data_adjusted <= {data_write_value[7:0], memory_data[23:0]};	
						data_memory[memory_write_address] <= memory_data_adjusted;
						
						memory_data_next <= data_memory[memory_write_address+1];
						memory_data_adjusted_next <= {memory_data_next[31:24], data_write_value[31:8]};
						data_memory[memory_write_address+1] <= memory_data_adjusted_next;
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
	end	// ff
	
	assign memory_read_address = data_read_addr >> 2;	// divide read address by 4 to get which memory location it is in
	assign read_data = data_memory[memory_read_address];
	assign read_data_next = data_memory[memory_read_address+1];
	
	always_comb begin
		case (data_read_addr % 4)
			0: data_read_value = data_memory[memory_read_address];

			1: data_read_value = {read_data_next[7:0], read_data[31:8]};
			
			2: data_read_value = {read_data_next[15:0], read_data[31:16]};
			
			3: data_read_value = {read_data_next[23:0], read_data[31:24]};
		
		endcase
	end
endmodule 
