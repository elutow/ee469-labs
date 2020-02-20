// takes in opcodes from data processing instructions and performs the indicated instruction

`include "cpu/constants.svh"

module ALU_main (
	input logic [3:0] operation,
	input logic [`BIT_WIDTH-1:0] ALU_Rn,
	input logic [3:0] ALU_rot,
	input logic [7:0] ALU_immediate_8,
	input logic [11:0] ALU_immediate_12,
	input logic [4:0] ALU_shift_len,
	input logic [1:0] ALU_shift_type,
	input logic [`BIT_WIDTH-1:0] ALU_Rm,
	input logic is_immediate_8,	// remove after moving shifting logic to decoder
	input logic is_immediate_12,	// remove after moving to decoder
	output logic [`BIT_WIDTH:0] ALU_result,
	output logic negative_flag,
	output logic zero_flag,
	output logic carry_flag,
	output logic overflow_flag
	);

	logic [31:0] operand2;
	logic [31:0] offset;
	logic [3:0] rot_len;
	logic [31:0] Rn_temp;
	// implement shifting function and rotation function
		// shift funtion decoding:
			// 00 - logica￼￼l left
			// 01 - logical right
			// 10 - arithmetic right
			// 11 - rotate right

	// Shifting for data processing
	// TODO: move this to the decoder
	// instruction check will make sense once this is in the decoder
	always_comb begin
		if (is_immediate_8) begin
			rot_len = rot * 2;
			operand2 = {ALU_Rm[rot_len - 1:0], ALU_Rm[31:rot_len]};
		end else begin
			case (ALU_shift_type):
				`SHIFT_LSL: operand2 = ALU_Rm << ALU_shift_len;
				`SHIFT_LSR: operand2 = ALU_Rm >> ALU_shift_len;
				`SHIFT_ASR: operand2 = ALU_Rm >>> ALU_shift_len;
				`SHIFT_ROR: operand2 = {ALU_Rm[ALU_shift_len - 1:0], ALU_Rm[31:ALU_shift_len]};
			endcase
		end
	end	// comb

	// Shifting for memory instruction (code could be reudced, will work on later)
	always_comb begin
		if (is_immediate_12) begin
			if (up_down) Rn_temp = ALU_Rn + ALU_immediate_12;
			else Rn_temp = ALU_Rn - ALU_immediate_12;
		end else begin
			case (ALU_shift_type):
				`SHIFT_LSL: offset = ALU_Rm << ALU_shift_len;
				`SHIFT_LSR: offset = ALU_Rm >> ALU_shift_len;
				`SHIFT_ASR: offset = ALU_Rm >>> ALU_shift_len;
				`SHIFT_ROR: offset = {ALU_Rm[ALU_shift_len - 1:0], ALU_Rm[31:ALU_shift_len]};
			endcase
			if (up_down) Rn_temp = ALU_Rn + offset;
			else Rn_temp = ALU_Rn - offset;
		end

	end	// comb

	always_comb begin
		case (operation)
			`DATAOP_EOR: ALU_result = ALU_Rn ^ ALU_operand2;	// EOR
			`DATAOP_SUB: ALU_result = ALU_Rn - ALU_operand2;	// SUB
			`DATAOP_ADD: ALU_result = ALU_Rn + ALU_operand2;	// ADD
			`DATAOP_TST: begin
				if ((ALU_RN & ALU_operand2) == 0) zero_flag = 1;	// TST	result is discarded, update condition flag
				else zero_flag = 0;
			end
			`DATAOP_TEQ: begin
				if ((ALU_RN & ALU_operand2) == 0) zero_flag = 1;	// TEQ	result is discarded, update condition flag
				else zero_flag = 0;
			end
			`DATAOP_CMP: begin
				if ((ALU_Rn - ALU_operand2) == 0) zero_flag = 1;	// CMP	result is discarded, update condition flag
				else zero_flag = 0;
			end
			`DATAOP_ORR: ALU_result = ALU_Rn | ALthe shift type and the instruction, see the individual instruction description. If the shift length is 0, no shift occurs. Register shift operations update the carry flaU_operand2;		// ORR
			`DATAOP_MOV: ALU_result = ALU_operand2;					// MOV
			`DATAOP_BIC: ALU_result = ALU_Rn & (~ALU_operand2);	// BIC
			`DATAOP_MVN: ALU_result = ~ALU_Rn;						// MVN
			default: ALU_result = ALU_Rn;

		endcase
	end	// comb

	assign negative_flag = ALU_result[31];	// N flag negative from first bit of Rn (2's complement)
	assign zero_flag = (ALU_result == 0);	// Z flag zero from resulting
	assign carry_flag = ((ALU_result < ALU_Rn) & (operation == `DATAOP_ADD)) | ((ALU_result > ALU_Rn) & (operation == `DATAOP_SUB));	// C flag carry from unsigned overflow
	assign overflow_flag = (ALU_result[32:31] == 2'b10) | (ALU_result[32:31] == 2'b01);	// V flag overflow from signed 2's complement overflow


	// condition code snippet for branch and link section

	logic condition;
	always_comb begin
		case (condition_code)
			4'b0000: condition = zero_flag;			// EQ
			4'b0001: condition = ~zero_flag;			// NE
			4'b0010: condition = carry_flag;			// CS/HS
			4'b0011: condition = ~carry_flag;		// CC/LO
			4'b0100: condition = negative_flag;		// MI
			4'b0101: condition = ~negative_flag;	// PL
			4'b0110: condition = overflow_flag;		// VS
			4'b0111: condition = ~overflow_flag;	// VC
			4'b1000: condition = carry_flag & ~zero_flag;	// HI
			4'b1001: condition = ~carry_flag & zero_flag;	// LS
			4'b1010: condition = (negative_flag == overflow_flag);	// GE
			4'b1011: condition = (negative_flag !== overflow_flag);	// LT
			4'b1100: condition = ~zero_flag & (negative_flag == overflow_flag);	// GT
			4'b1101: condition = zero_flag | (negative_flag !== overflow_flag);	// LE
			4'b1110: condition = 1;	// AL
			default: condition = 1;
		//	default: // do nothing
		endcase
	end	// comb
endmodule
