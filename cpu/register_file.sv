// 32x16 register file
module register_file (
	input logic clk, wr_en,
	input logic [3:0] rd_address_0, rd_address_1, wr_address, 
	input logic [31:0] data_in,
	
	output logic [31:0] data_out_0, data_out_1
	);
	
	logic [31:0] register [15:0] 
	
	assign data_out_0 = register[rd_address_0];
	assign data_out_1 = register[rd_address_1];
	
	always_ff @(posedge clk) begin
		if (wr_en) register[wr_address] <= data_in;	
	end	// ff
	
endmodule 

