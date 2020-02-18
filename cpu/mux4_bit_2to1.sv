// 4 bit 2 to 1 mux
module mux4_bit_2to1 (
	input logic [3:0] input_0, input_1,
	input logic selector,
	output logic [3:0] out
	);
	
	always_comb
		case (selector)
			1'b0: out = input_0;
			1'b1: out = input_1;
			default: out = 4'b0;
		endcase
	end	// comb
endmodule	