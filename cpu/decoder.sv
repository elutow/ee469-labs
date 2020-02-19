// Deocdes the instruction into separate signals
// Also reads the arguments from the regfile

`include "cpu/constants.svh"

module decoder(
		input wire clk,
		input wire nreset,
		input wire enable,
		/* Instruction from fetcher */
		input logic [`BIT_WIDTH-1:0] inst,
		/* Instruction decoding outputs */
		output logic [3:0] condition,
		output logic [3:0] opcode,
		output logic [1:0] format,
		/* NOTE: We need Rn and Rd because we send them over the debug port */
		output logic [`REG_COUNT_L2-1:0] Rn,
		output logic [`REG_COUNT_L2-1:0] Rd,
		output logic [3:0] rot,
		output logic [7:0] immediate_8,
		output logic [11:0] immediate_12,
		output logic [4:0] shift_len,
		output logic [1:0] shift_type,
		output logic [`REG_COUNT_L2-1:0] Rm,
		output logic is_immediate,	// remove after moving shifting logic to this module
		output logic [23:0] branch_offset,
		output logic [11:0] mem_offset,
		output logic branch_link,
		output logic is_load,
		output logic up_down,
		/* Regfile I/O */
		/* regfile_R* is determined directly from inst so we get the result
		   from regfile at the same clock cycle as cache_inst values */
		output logic [`REG_COUNT_L2-1:0] regfile_Rn,
		output logic [`REG_COUNT_L2-1:0] regfile_Rd,
		output logic [`REG_COUNT_L2:1:0] regfile_Rm,
		output logic [`BIT_WIDTH-1:0] Rn_value,
		output logic [`BIT_WIDTH-1:0] Rd_value,
		/* Whether decoder output is ready to be read */
		output logic ready
	);

    // For synchronous state registers
    logic next_ready;
	// Cache instruction to align with regfile
	logic cached_inst;

	always_ff @(posedge clk) begin
		if (nreset) begin
			ready <= next_ready;
			cached_inst <= inst;
		end
		else begin
			ready <= 1'b0;
			cached_inst <= `BIT_WIDTH'b0;
		end
	end

	// ---Decoding FSM---
	// NOT READY
	// - !enable: NOT READY
	// - enable: READY
	// READY
	// - *: NOT READY (because we wait or get new instruction in this cycle)
	assign next_ready = enable && !ready;

	// Decoding logic
	assign condition = inst[31:28];
	assign format = inst[27:26];
	always_comb begin
		opcode = 4'bX;
		Rn = 4'bX;
		Rd = 4'bX;
		regfile_Rn = 4'bX;
		regfile_Rd = 4'bX;
		rot = 4'bX;
		immediate_8 = 8'bX;
		immediate_12 = 12'bX;
		shift_len = 5'bX;
		shift_type = 2'bX;
		Rm = 4'bX;
		is_immediate_8 = 1'bX;
		is_immediate_12 = 1'bX;
		mem_offset = 12'bX;
		branch_offset = 24'bX;
		branch_link = 1'bX;
		is_load = 1'bX;
		up_down = 1'bX;
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
			`FMT_DATA: begin
				opcode = cached_inst[24:21];
				Rn = cached_inst[19:16];
				Rd = cached_inst[15:12];
				regfile_Rn = inst[19:16];
				regfile_Rd = inst[15:12];
				//operand = cached_inst[11:0]; superseded
				if (inst[25]) begin
					rot = cached_inst[11:8];
					immediate_8 = cached_isnt[7:0];
					is_immediate_8 = 1;
				end else begin
					shift_len = cached_inst[11:7];
					shift_type = cached_inst[6:5];
					Rm = cached_inst[3:0];
					regfile_Rm = inst[3:0];
					is_immediate_8 = 0;

				end
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
			// memory instuction (LDR/STR)
			`FMT_MEMORY: begin
				is_load = cached_inst[20];
				Rn = cached_inst[19:16];
				Rd = cached_inst[15:12];
				regfile_Rn = inst[19:16];
				regfile_Rd = inst[15:12];
				mem_offset = cached_inst[11:0];
				up_down = cached_inst[23];	// 1 is up, 0 is down
				if (inst[25])	begin
					shift_len = cached_inst[11:7];
					shift_type = cached_inst[6:5];
					Rm = cached_inst[3:0]
					is_immediate_12 = 0;
				end else begin
					immediate_12 = cached_inst[11:0];
					is_immediate_12 = 1;
				end
				// TODO: Handle mem_offset (operand2) values correctly
			end
			// branch instuction (B BL)
			`FMT_BRANCH: begin
				branch_link = cached_inst[24];
				branch_offset = cached_inst[23:0];
				`ifndef SYNTHESIS
					if (ready) begin
						assert(cached_inst[25]) else begin
							$error("cached_inst[25] should be 1 for branch instructions.");
						end
					end
				`endif
			end
			default: begin
				`ifndef SYNTHESIS
					if (ready) begin
						$error("Invalid instruction format");
					end
				`endif
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
