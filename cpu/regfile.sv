// Manages register file reads and writes, and pc (r15) semantics
// NOTE: All inputs are clocked

`include "cpu/constants.svh"

function automatic [`BIT_WIDTH-1:0] fix_pc_read_value;
    // Fix reading PC in multicycle CPU design
    input [`BIT_WIDTH-1:0] pc;
    input [`BIT_WIDTH-1:0] inst;

    fix_pc_read_value = pc + `BIT_WIDTH'd8;
    if (decode_format(inst) == `FMT_DATA) begin
        if (!decode_dataproc_operand2_is_immediate(inst)) begin
            fix_pc_read_value = pc + `BIT_WIDTH'd12;
        end
    end
endfunction

module regfile(
        input wire clk,
        input wire nreset,
        input logic [`BIT_WIDTH-1:0] read_inst,
        input logic [`REG_COUNT_L2-1:0] read_addr1,
        input logic [`REG_COUNT_L2-1:0] read_addr2,
        output logic [`BIT_WIDTH-1:0] read_value1,
        output logic [`BIT_WIDTH-1:0] read_value2,
        input logic write_enable1,
        input logic [`REG_COUNT_L2-1:0] write_addr1,
        input logic [`BIT_WIDTH-1:0] write_value1,
        output logic [`BIT_WIDTH-1:0] pc,
        input logic [`BIT_WIDTH-1:0] new_pc,
        input logic update_pc
    );

    // Synchronous values
    logic [`BIT_WIDTH-1:0] next_pc;
    logic [`REG_COUNT_L2-1:0] prev_read_addr1, prev_read_addr2, prev_write_addr1;
    logic [`BIT_WIDTH-1:0] prev_read_inst;

    // Register file and outputs
    // We do (`REG_COUNT-1)-1 because we store the PC separately
    reg [`BIT_WIDTH-1:0] register_file [0:`REG_COUNT-2];

    initial begin
        $readmemh("cpu/regfile_init.hex", register_file);
    end

    always_comb begin
        // TODO: Verify semantics are correct
        // Condition reads against PC
        if (prev_read_addr1 == `REG_PC_INDEX) begin
            read_value1 = fix_pc_read_value(pc, prev_read_inst);
        end
        else begin
            read_value1 = register_file[prev_read_addr1];
        end
        if (prev_read_addr2 == `REG_PC_INDEX) begin
            read_value2 = fix_pc_read_value(pc, prev_read_inst);
        end
        else begin
            read_value2 = register_file[prev_read_addr2];
        end
        next_pc = pc;
        if (update_pc) begin
            next_pc = new_pc;
        end
        if (write_enable1 && write_addr1 == `REG_PC_INDEX) begin
            `ifndef SYNTHESIS
                assert(!update_pc) else begin
                    $error("Cannot have update_pc with write on PC register simultaneously");
                end
            `endif
            next_pc = write_value1;
        end
    end

    always_ff @(posedge clk) begin
        if (nreset) begin
            pc <= next_pc;
            if (write_enable1 && write_addr1 != `REG_PC_INDEX) begin
                register_file[prev_write_addr1] <= write_value1;
            end
            prev_write_addr1 <= write_addr1;
            prev_read_addr1 <= read_addr1;
            prev_read_addr2 <= read_addr2;
            prev_read_inst <= read_inst;
        end
        else begin
            pc <= `BIT_WIDTH'b0;
            prev_write_addr1 <= `REG_COUNT_L2'b0;
            prev_read_addr1 <= `REG_COUNT_L2'b0;
            prev_read_addr2 <= `REG_COUNT_L2'b0;
            prev_read_inst <= `BIT_WIDTH'b0;
        end
    end
endmodule
