// NOTE: Yosys currently does not support enums
// See https://github.com/YosysHQ/yosys/issues/248

module decoder(
		input logic [31:0] inst,
		output logic [3:0] condition,
		output logic [3:0] opcode,
		output logic [1:0] format,
		output logic [3:0] Rn,
		output logic [3:0] Rd,
		output logic [11:0] operand,
		output logic [23:0] branch_offset,
		output logic [11:0] mem_offset,
		output logic branch_link,
		output logic is_load,
	);

	assign condition = inst[31:28];
	assign format = inst[27:26];

	// Decoding logic
	always_comb begin
		opcode = 4'bX;
		Rn = 4'bX;
		Rd = 4'bX;
		operand = 12'bX;
		mem_offset = 12'bX;
		branch_offset = 24'bX;
		branch_link = 1'bX;
		is_load = 1'bX;
		//case (condition)
		//	0000: // EQ
		//	0001: // NE
		//	0010: // CS/HS
		//	0011: // CC/LO
		//	0100: // MI
		//	0101: // PL
		//	0110: // VS
		//	0111: // VC
		//	1000: // HI
		//	1010: // GE
		//	1011: // LT
		//	1100: // GT
		//	1101: // LE
		//	1110: // AL
		//	default: // do nothing
		//endcase
		case (format)
			// data processing (EOR SUB ADD TST TEQ CMP ORR MOV MVN BIC)
			2'b00:	begin
				opcode = inst[24:21];
				Rn = inst[19:16];
				Rd = inst[15:12];
				operand = inst[11:0];
				//case (opcode)
				//	0001: // EOR
				//	0010: // SUB
				//	0100: // ADD
				//	1000: // TST
				//	1001: // TEQ
				//	1010: // CMP
				//	1100: // ORR
				//	1101: // MOV
				//	1110: // BIC
				//	1111: // MVN
				//	default: // do nothing
				//endcase
			end
			// memory instuction (LDR)
			2'b01:	begin
					is_load = inst[20];
					Rn = inst[19:16];
					Rd = inst[15:12];
					mem_offset = inst[11:0];
			end
			// branch instuction (B BL)
			2'b10:	begin
					branch_link = inst[24];
					branch_offset = inst[23:0];
					if (branch_link) begin
						// BL
					end else begin
						// B
					end // else
			end
		endcase
	end // comb

	// 31-28 always 4-bit condtition code

	// ADD R1 = R1 + #3 ex: 1110 0010 1000 0001 0001 0000 0000 0011

	// DATA PROCESSING FORMAT (EOR SUB ADD TST TEQ CMP ORR MOV MVN BIC)
		// 27-26 = 00
		// FIGURE OUT 25
		// 24-21 opcode (arithmetic/logic function)
		// 20 set condition codes
		// 19-16 Rn (first operand register)
		// 15-12 Rd (destination register)
		// 11-0 operand 2

			// OPCODES
				// 0001 EOR
				// 0010 SUB
				// 0100 ADD
				// 1000 TST
				// 1001 TEQ
				// 1010 CMP
				// 1100 ORR
				// 1101 MOV
				// 1110 BIC
				// 1111 MVN

	// MEMORY INSTRUCTION FORMAT (LDR)
		// 27-26 = 01
		// FIGURE OUT 25
		// 24 pre/post index
		// 23 up/down
		// 22 unsigned byte/word
		// 21 write-back (auto index)
		// 20 load/store
		// 19-16 Rn (base register)
		// 15-12 Rd (source/ destination register)
		// 11-0 offest


	// BRANCH INSTRUCTION FORMAT (B BL)
		// 27-25 = 101
		// 24 link bit
			// 0 = branch, 1 = brank with link
		// 23-0 offset
endmodule
