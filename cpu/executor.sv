// Executes the instruction
// Responsibilities:
// - Computes the result of the data processing instruction, and sends result to writeback
// - Computes condition code and determines whether to execute instruction
// - Updates the Current Program State Register (CPSR) (just the subset we support)
// - Computes new PC For branch instructions and sends new PC to writeback
// - Read and write data memory for processing instructions

`include "cpu/constants.svh"

// Shifting functions
function automatic [`BIT_WIDTH-1:0] shift_value_by_type;
    input [`BIT_WIDTH-1:0] inst;
    input [`BIT_WIDTH-1:0] Rm_value;

    logic [4:0] shift_len;
    logic [1:0] shift_type;
    logic [`BIT_WIDTH-1:0] result;

    shift_len = inst[11:7];
    shift_type = inst[6:5];
    case (shift_type)
        `SHIFT_LSL: result = Rm_value << shift_len;
        `SHIFT_LSR: result = Rm_value >> shift_len;
        `SHIFT_ASR: result = Rm_value >>> shift_len;
        `SHIFT_ROR: result = (Rm_value << (~shift_len + 1'b1)) | (Rm_value >> shift_len);
    endcase

    shift_value_by_type = result;
endfunction

function automatic [`BIT_WIDTH-1:0] shift_dataproc_operand2;
    // Shifting for data processing
    input [`BIT_WIDTH-1:0] inst;
    input [`BIT_WIDTH-1:0] Rm_value;

    logic [4:0] rot_len;
    logic [`BIT_WIDTH-1:0] result;
    logic [7:0] immediate_8;

    `ifndef SYNTHESIS
        assert (decode_format(inst) == `FMT_DATA) else begin
            $error("shift_dataproc_operand2: inst is not in data format: %h", inst);
        end
    `endif

    if (decode_dataproc_operand2_is_immediate(inst)) begin
        rot_len = {inst[11:8], 1'b0}; // Multiply rot by 2
        immediate_8 = {24'b0, inst[7:0]};
        result = (immediate_8 << (~rot_len + 1'b1) | (immediate_8 >> rot_len);
    end else begin
        result = shift_value_by_type(inst, Rm_value);
    end

    shift_dataproc_operand2 = result;
endfunction

function automatic [`BIT_WIDTH-1:0] shift_mem_offset;
    // Returns the offset for memory instructions (via shifting)
    // (The offset is applied to Rn)
    input [`BIT_WIDTH-1:0] inst;
    input [`BIT_WIDTH-1:0] Rm_value;

    logic [`BIT_WIDTH-1:0] offset;
    logic up_down;

    `ifndef SYNTHESIS
        assert(decode_format(inst) == `FMT_MEMORY) else begin
            $error("shift_mem_offset: inst is not in memory format: %h", inst);
        end
    `endif

    up_down = decode_mem_up_down(inst);

    if (decode_mem_offset_is_immediate(inst)) begin
        offset = {20'b0, inst[11:0]}; // 12-bit immediate
    end else begin
        offset = shift_value_by_type(inst, Rm_value);
    end

    if (up_down) shift_mem_offset = offset;
    else shift_mem_offset = -offset;
endfunction

function automatic [`BIT_WIDTH:0] run_dataproc_operation;
    // Return format:
    // MSB is 1 if result should be stored in Rd; otherwise discard result (for updating CPSR)
    // Remaining bits are the value to be stored in Rd
    input [3:0] operation;
    input [`BIT_WIDTH-1:0] Rn_value;
    input [`BIT_WIDTH-1:0] operand2;

    logic [`BIT_WIDTH-1:0] result;
    logic store_result;

    store_result = 1'b1;
    case (operation)
        `DATAOP_EOR: result = Rn_value ^ operand2;    // EOR
        `DATAOP_SUB: result = Rn_value - operand2;    // SUB
        `DATAOP_ADD: result = Rn_value + operand2;    // ADD
        `DATAOP_TST: begin
            // TST result is discarded, update condition flag
            store_result = 1'b0;
            result = Rn_value & operand2;
        end
        `DATAOP_TEQ: begin
            // TEQ result is discarded, update condition flag
            store_result = 1'b0;
            result = Rn_value & operand2;
        end
        `DATAOP_CMP: begin
            // CMP result is discarded, update condition flag
            store_result = 1'b0;
            result = Rn_value - operand2;
        end
        `DATAOP_ORR: result = Rn_value | operand2;        // ORR
        `DATAOP_MOV: result = operand2;                    // MOV
        `DATAOP_BIC: result = Rn_value & (~operand2);    // BIC
        `DATAOP_MVN: result = ~Rn_value;                        // MVN
        default: begin
            `ifndef SYNTHESIS
                $error("Unknown dataproc operation: %b", operation);
            `endif
            result = Rn_value;
        end
    endcase

    run_dataproc_operation = {store_result, result};
endfunction

function automatic [`CPSR_SIZE-1:0] compute_cpsr;
    input [`BIT_WIDTH-1:0] dataproc_result;
    input [`BIT_WIDTH-1:0] Rn_value;
    input [3:0] operation;

    logic [`CPSR_SIZE-1:0] cpsr;

    cpsr[`CPSR_NEGATIVE_IDX] = dataproc_result[31];    // N flag negative from first bit of Rn (2's complement)
    cpsr[`CPSR_ZERO_IDX] = (dataproc_result == 0);    // Z flag zero from resulting
    cpsr[`CPSR_CARRY_IDX] = ((dataproc_result < Rn_value) & (operation == `DATAOP_ADD))
        | ((dataproc_result > Rn_value) & (operation == `DATAOP_SUB));    // C flag carry from unsigned overflow
    // TODO: TST and TEQ shouldn't set overflow flag?
    cpsr[`CPSR_OVERFLOW_IDX] = (dataproc_result[31:30] == 2'b10) | (dataproc_result[31:30] == 2'b01);    // V flag overflow from signed 2's complement overflow

    compute_cpsr = cpsr;
endfunction

function automatic check_condition;
    input [`CPSR_SIZE-1:0] cpsr;
    input [3:0] condition_code;

    logic negative_flag;
    logic zero_flag;
    logic carry_flag;
    logic overflow_flag;

    logic condition;

    negative_flag = cpsr[`CPSR_NEGATIVE_IDX];
    zero_flag = cpsr[`CPSR_ZERO_IDX];
    carry_flag = cpsr[`CPSR_CARRY_IDX];
    overflow_flag = cpsr[`CPSR_OVERFLOW_IDX];

    case (condition_code)
        `COND_EQ: condition = zero_flag;            // EQ
        `COND_NE: condition = ~zero_flag;            // NE
        `COND_CS_HS: condition = carry_flag;            // CS/HS
        `COND_CC_LO: condition = ~carry_flag;        // CC/LO
        `COND_MI: condition = negative_flag;        // MI
        `COND_PL: condition = ~negative_flag;    // PL
        `COND_VS: condition = overflow_flag;        // VS
        `COND_VC: condition = ~overflow_flag;    // VC
        `COND_HI: condition = carry_flag & ~zero_flag;    // HI
        `COND_LS: condition = ~carry_flag & zero_flag;    // LS
        `COND_GE: condition = (negative_flag == overflow_flag);    // GE
        `COND_LT: condition = (negative_flag !== overflow_flag);    // LT
        `COND_GT: condition = ~zero_flag & (negative_flag == overflow_flag);    // GT
        `COND_LE: condition = zero_flag | (negative_flag !== overflow_flag);    // LE
        `COND_AL: condition = 1'b1;    // AL
        default: begin
            `ifndef SYNTHESIS
                $error("Unknown condition code: %b", condition_code);
            `endif
            condition = 1'b1;
        end
    //    default: // do nothing
    endcase
    check_condition = condition;
endfunction

module executor(
        input wire clk,
        // FSM control logic
        input wire nreset,
        input logic enable,
        output logic ready,
        // Datapath I/O
        output logic [`BIT_WIDTH-1:0] executor_inst,
        output logic update_pc, // Whether we have a new PC
        input logic [`BIT_WIDTH-1:0] pc,
        output logic [`BIT_WIDTH-1:0] new_pc,
        output logic update_Rd, // Whether we should update Rd (result) in writeback
        output logic [`BIT_WIDTH-1:0] Rd_value,
        // Datapath signals from decoder
        input logic [`BIT_WIDTH-1:0] decoder_inst,
        input logic [`BIT_WIDTH-1:0] Rn_value, // First operand
        input logic [`BIT_WIDTH-1:0] Rm_value // Second operand for operand2 or offset
    );

    // Currnet Program Status Register (CPSR)
    logic [`CPSR_SIZE-1:0] cpsr;

    // Data memory declaration
    // Data memory is a byte-addressable memory space for memory instructions
    reg [7:0] data_memory [0:`DATA_SIZE-1];
    initial begin
        $readmemh("cpu/lab2_data.hex", data_memory);
    end

    // Control logic
    // ---Execution FSM---
    // NOT READY
    // - !enable -> NOT READY
    // - enable -> READY
    //      - Execute instructions
    //      - Tell data memory the values to read/write
    // READY
    // - enable -> READY (keep processing at 1 instruction / cycle)
    // - !enable -> NOT READY (transition to halt)
    logic next_ready;
    assign next_ready = enable && !ready;
    always_ff @(posedge clk) begin
        if (nreset) begin
            ready <= next_ready;
        end
        else begin
            ready <= 1'b0;
        end
    end // ff

    // Datapath logic
    // Determine instruction to output from executor
    logic [`BIT_WIDTH-1:0] next_executor_inst;
    always_comb begin
        next_executor_inst = executor_inst;
        if (next_ready) begin
            next_executor_inst = decoder_inst;
        end
    end
    always_ff @(posedge clk) begin
        if (nreset) begin
            executor_inst <= next_executor_inst;
        end
        else begin
            executor_inst <= `BIT_WIDTH'b0;
        end
    end
    // Execute instructions
    // NOTE: This operates on next_executor_inst because we need the LDR/STR
    // operation to be done before we set ready == 1
    // So we might as well run all instructions and set values before next clock
    // cycle
    logic [`DATA_SIZE_L2-1:0] data_read_addr, next_data_read_addr;
    logic [`DATA_SIZE_L2-1:0] data_write_addr;
    logic [`BIT_WIDTH-1:0] data_read_value, data_write_value;
    logic data_write_enable;
    // Before current cycle
    // TODO: Add all execution logic here
    always_comb begin
        if (next_ready) begin
            case (decode_format(next_executor_inst))
                // TODO: Support halfword or byte-sized read/write?
                `FMT_MEMORY: begin
                    if (decode_mem_is_load(next_executor_inst)) begin
                        if (decode_mem_offset_is_immediate(next_executor_inst)) begin
                            //regfile_read_addr2 = decode_Rm(next_executor_inst);
                        end
                    end
                    else begin
                    end
                end
                `FMT_DATA: begin
                    // TODO
                end
                `FMT_BRANCH: begin
                    // TODO
                end
                default: begin end
            endcase
        end
    end // comb
    // Current cycle
    // TODO: Move all logic except determination of output values (Rd_value, new_pc)
    // to before current cycle
    always_comb begin
        Rd_value = `BIT_WIDTH'bX;
        update_Rd = 1'b0;
        if (ready) begin
            case (decode_format(executor_inst))
                `FMT_BRANCH: begin
                end
                `FMT_DATA: begin
                end
                `FMT_MEMORY: begin
                    if (!decode_mem_is_load(next_executor_inst)) begin
                        // STR
                        Rd_value = data_read_value;
                        update_Rd = 1'b1;
                    end
                end
                default: begin
                    // TODO: Do we need this?
                end
            endcase
        end
    end // comb
    assign data_read_value[31:24] = data_memory[data_read_addr+3];
    assign data_read_value[23:16] = data_memory[data_read_addr+2];
    assign data_read_value[15:8] = data_memory[data_read_addr+1];
    assign data_read_value[7:0] = data_memory[data_read_addr];
    always_ff @(posedge clk) begin
        if (nreset) begin
            data_read_addr <= next_data_read_addr;
            if (data_read_enable) begin
                data_memory[data_write_addr+3] <= data_write_value[31:24];
                data_memory[data_write_addr+2] <= data_write_value[23:16];
                data_memory[data_write_addr+1] <= data_write_value[15:8];
                data_memory[data_write_addr] <= data_write_value[7:0];
            end
        end
        else begin
            data_read_addr <= `DATA_SIZE_L2'b0;
            data_read_value <= `BIT_WIDTH'b0;
            data_write_addr <= `DATA_SIZE_L2'b0;
        end
    end
    // Determine new values for pc and Rd (execute instruction)
endmodule
