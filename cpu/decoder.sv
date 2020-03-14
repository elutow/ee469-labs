// Reads the regfile for the registers needed for execution
// Also reads the arguments from the regfile

`include "cpu/constants.svh"

function automatic [1:0] decode_format;
    input [`BIT_WIDTH-1:0] inst;

    logic [1:0] format;
    format = inst[27:26];

    `ifndef SYNTHESIS
        case (format)
            `FMT_DATA: begin end
            `FMT_MEMORY: begin end
            `FMT_BRANCH: begin
                assert(inst[25]) else begin
                    $error("cached_inst[25] should be 1 for branch instructions.");
                end
            end
            default: begin
                $error("Invalid instruction format");
            end
        endcase
    `endif

    decode_format = format;
endfunction

function automatic [3:0] decode_condition;
    input [`BIT_WIDTH-1:0] inst;

    decode_condition = inst[31:28];
endfunction

function automatic [3:0] decode_dataproc_opcode;
    input [`BIT_WIDTH-1:0] inst;

    `ifndef SYNTHESIS
        assert(decode_format(inst) == `FMT_DATA) else begin
            $error("decode_dataproc_opcode: inst is not in data format: %h", inst);
        end
    `endif

    decode_dataproc_opcode = inst[24:21];
endfunction

function automatic decode_dataproc_update_cpsr;
    input [`BIT_WIDTH-1:0] inst;

    `ifndef SYNTHESIS
        assert(decode_format(inst) == `FMT_DATA) else begin
            $error("decode_dataproc_update_cpsr: inst is not in data format: %h", inst);
        end
    `endif

    decode_dataproc_update_cpsr = inst[20];
endfunction

function automatic [`REG_COUNT_L2-1:0] decode_Rn;
    input [`BIT_WIDTH-1:0] inst;

    `ifndef SYNTHESIS
        logic [1:0] format;
        format = decode_format(inst);
        assert(format == `FMT_DATA || format == `FMT_MEMORY) else begin
            $error("decode_Rn: inst is not in data or memory formats: %h", inst);
        end
    `endif

    decode_Rn = inst[19:16];
endfunction

function automatic [`REG_COUNT_L2-1:0] decode_Rd;
    input [`BIT_WIDTH-1:0] inst;

    `ifndef SYNTHESIS
        logic [1:0] format;
        format = decode_format(inst);
        assert(format == `FMT_DATA || format == `FMT_MEMORY) else begin
            $error("decode_Rd: inst is not in data or memory formats: %h", inst);
        end
    `endif

    decode_Rd = inst[15:12];
endfunction

function automatic decode_dataproc_operand2_is_immediate;
    input [`BIT_WIDTH-1:0] inst;

    `ifndef SYNTHESIS
        assert(decode_format(inst) == `FMT_DATA) else begin
            $error("decode_dataproc_operand2_is_immediate: inst is not in data format: %h", inst);
        end
    `endif

    decode_dataproc_operand2_is_immediate = inst[25];
endfunction

function automatic decode_mem_offset_is_immediate;
    input [`BIT_WIDTH-1:0] inst;

    `ifndef SYNTHESIS
        assert(decode_format(inst) == `FMT_MEMORY) else begin
            $error("decode_mem_offset_is_immediate: inst is not in memory format: %h", inst);
        end
    `endif

    // NOTE: inst[25] == 0 if it is an immediate
    decode_mem_offset_is_immediate = !inst[25];
endfunction

function automatic [`REG_COUNT_L2-1:0] decode_Rm;
    input [`BIT_WIDTH-1:0] inst;

    `ifndef SYNTHESIS
        case (decode_format(inst))
            `FMT_DATA: begin
                assert(!decode_dataproc_operand2_is_immediate(inst)) else begin
                    $error("decode_Rm: inst is dataproc format but uses immediate");
                end
            end
            `FMT_MEMORY: begin
                assert(!decode_mem_offset_is_immediate(inst)) else begin
                    $error("decode_Rm: inst is mem format but uses immediate");
                end
            end
            default: begin
                $error("decode_Rm: inst is not in data or memory formats: %h", inst);
            end
        endcase
    `endif

    decode_Rm = inst[3:0];
endfunction

function automatic decode_mem_is_load;
    // 1 if LDR, 0 if STR
    input [`BIT_WIDTH-1:0] inst;

    `ifndef SYNTHESIS
        assert(decode_format(inst) == `FMT_MEMORY) else begin
            $error("decode_mem_is_load: inst is not in memory format: %h", inst);
        end
    `endif

    decode_mem_is_load = inst[20];
endfunction

function automatic decode_mem_up_down;
    // 1 is up, 0 is down
    input [`BIT_WIDTH-1:0] inst;

    `ifndef SYNTHESIS
        assert(decode_format(inst) == `FMT_MEMORY) else begin
            $error("decode_mem_up_down: inst is not in memory format: %h", inst);
        end
    `endif

    decode_mem_up_down = inst[23];
endfunction

function automatic decode_branch_is_link;
    // 1 is branch with link, 0 is just branch
    input [`BIT_WIDTH-1:0] inst;

    `ifndef SYNTHESIS
        assert(decode_format(inst) == `FMT_BRANCH) else begin
            $error("decode_branch_is_link: inst is not in branch format: %h", inst);
        end
    `endif

    decode_branch_is_link = inst[24];
endfunction

function automatic [`BIT_WIDTH-1:0] decode_branch_offset;
    input [`BIT_WIDTH-1:0] inst;

    `ifndef SYNTHESIS
        assert(decode_format(inst) == `FMT_BRANCH) else begin
            $error("decode_branch_offset: inst is not in branch format: %h", inst);
        end
    `endif

    // Extend two's complement to 32 bits
    decode_branch_offset = {{6{inst[23]}}, inst[23:0], 2'b0};
endfunction

function automatic [`BIT_WIDTH-1:0] fix_operand2_pc_read_value;
    // Fix reading PC in pipelined CPU design for operand2
    // This should be run after decoder is ready; i.e. pc = orig_pc+8
    // where orig_pc is the PC used to fetch inst
    input [`BIT_WIDTH-1:0] pc;
    input [`BIT_WIDTH-1:0] inst;

    fix_operand2_pc_read_value = pc; // orig_pc+8
    if (decode_format(inst) == `FMT_DATA) begin
        if (!decode_dataproc_operand2_is_immediate(inst)) begin
            fix_operand2_pc_read_value = pc + `BIT_WIDTH'd4; // orig_pc+12
        end
    end
endfunction

module decoder(
        input wire clk,
        input wire nreset,
        input logic enable,
        // Whether decoder output is ready to be read
        output logic ready,
        // Instruction from fetcher
        input logic [`BIT_WIDTH-1:0] fetcher_inst,
        // Instruction decoding outputs
        output logic [`BIT_WIDTH-1:0] decoder_inst,
        // Regfile I/O
        // regfile_read_addr* is determined directly from inst so we get the
        //   result from regfile at the same clock cycle as cache_inst values
        output logic [`BIT_WIDTH-1:0] regfile_read_inst,
        output logic [`REG_COUNT_L2-1:0] regfile_read_addr1,
        output logic [`REG_COUNT_L2-1:0] regfile_read_addr2,
        input logic [`BIT_WIDTH-1:0] regfile_read_value1,
        input logic [`BIT_WIDTH-1:0] regfile_read_value2,
        output logic [`BIT_WIDTH-1:0] Rn_value, // First operand
        output logic [`BIT_WIDTH-1:0] Rd_Rm_value // Rd for STR, otherwise Rm
    );

    // Control logic
    // ---Decoding FSM---
    // NOT READY
    // - !enable -> NOT READY
    // - enable -> READY
    //         - Tell regfile the new values to read
    // READY
    // - enable -> READY (keep processing at 1 instruction / cycle)
    // - !enable -> NOT READY (because we wait or get new instruction in this cycle)
    logic next_ready;
    assign next_ready = enable;
    always_ff @(posedge clk) begin
        if (nreset) begin
            ready <= next_ready;
        end
        else begin
            ready <= 1'b0;
        end
    end // ff

    // Datapath logic
    // Read regfile read data and fix PC values
    // NOTE: These addresses can be Xs, but that doesn't matter since later
    // stages will read these values if the instruction uses them.
    logic [`REG_COUNT_L2-1:0] prev_regfile_read_addr1, prev_regfile_read_addr2;
    always_ff @(posedge clk) begin
        prev_regfile_read_addr1 <= regfile_read_addr1;
        prev_regfile_read_addr2 <= regfile_read_addr2;
    end
    always_comb begin
        Rn_value = regfile_read_value1; // If this is pc, then it is already orig_pc+8
        Rd_Rm_value = regfile_read_value2;
        if (prev_regfile_read_addr2 == `REG_PC_INDEX) begin
            Rd_Rm_value = fix_operand2_pc_read_value(regfile_read_value2, decoder_inst);
        end
    end // comb
    // Determine instruction to output from decoder
    logic [`BIT_WIDTH-1:0] next_decoder_inst;
    assign next_decoder_inst = fetcher_inst;
    always_ff @(posedge clk) begin
        if (nreset) begin
            decoder_inst <= next_decoder_inst;
        end
        else begin
            decoder_inst <= `BIT_WIDTH'b0;
        end
    end
    // Determine registers to be read from regfile
    // NOTE: These operate on next_decoder_inst because we need the regfile to
    // output on the same clock cycle as decoder_inst is set
    assign regfile_read_inst = next_decoder_inst;
    always_comb begin
        regfile_read_addr1 = `REG_COUNT_L2'bX;
        regfile_read_addr2 = `REG_COUNT_L2'bX;
        if (next_ready) begin
            case (decode_format(next_decoder_inst))
                `FMT_DATA: begin
                    regfile_read_addr1 = decode_Rn(next_decoder_inst);
                    if (!decode_dataproc_operand2_is_immediate(next_decoder_inst)) begin
                        regfile_read_addr2 = decode_Rm(next_decoder_inst);
                    end
                end
                `FMT_MEMORY: begin
                    regfile_read_addr1 = decode_Rn(next_decoder_inst);
                    // We don't support three simultaneous regfile reads
                    // So we read Rd instead of Rm for STR only
                    if (!decode_mem_is_load(next_decoder_inst)) begin
                        regfile_read_addr2 = decode_Rd(next_decoder_inst);
                        `ifndef SYNTHESIS
                            assert(decode_mem_offset_is_immediate(next_decoder_inst)) else begin
                                $error("Using Rm on STR is not supported");
                            end
                        `endif
                    end
                    else if (!decode_mem_offset_is_immediate(next_decoder_inst)) begin
                        regfile_read_addr2 = decode_Rm(next_decoder_inst);
                    end
                end
                `FMT_BRANCH: begin
                    // No need to read registers
                end
                default: begin
                    `ifndef SYNTHESIS
                        $error("This should not run!");
                    `endif
                end
            endcase
        end
    end // comb
endmodule
