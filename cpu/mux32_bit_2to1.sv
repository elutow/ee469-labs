// 32 bit 2 to 1 mux
module mux32_bit_2to1 (
	input logic [31:0] input_0, input_1,
	input logic selector,
	output logic [31:0] out
	);
	
	always_comb
		case (selector)
			1'b0: out = input_0;
			1'b1: out = input_1;
			default: out = 32'b0;
		endcase
	end	// comb
endmodule	