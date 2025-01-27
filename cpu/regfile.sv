// Manages register file reads and writes, and pc (r15) semantics
// NOTE: All inputs are clocked

`include "cpu/constants.svh"

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
    logic [`REG_COUNT_L2-1:0] prev_read_addr1, prev_read_addr2;

    // Register file and outputs
    // We do (`REG_COUNT-1)-1 because we store the PC separately
    reg [`BIT_WIDTH-1:0] register_file [0:`REG_COUNT-2];

    initial begin
        $readmemh("cpu/init/regfile.hex", register_file);
    end

    always_comb begin
        // Condition reads against PC
        // The modules reading from regfile via the read ports (currently decoder)
        // should fix the PC values themselves to conform to ARM spec
        if (prev_read_addr1 == `REG_PC_INDEX) begin
            read_value1 = pc;
        end
        else begin
            read_value1 = register_file[prev_read_addr1];
        end
        if (prev_read_addr2 == `REG_PC_INDEX) begin
            read_value2 = pc;
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
                register_file[write_addr1] <= write_value1;
            end
            `ifndef SYNTHESIS
                assert(32'(read_addr1) < `REG_COUNT) else begin
                    $error("Invalid read_addr1 %h with inst %h",
                           read_addr1, read_inst);
                end
                assert(32'(read_addr2) < `REG_COUNT) else begin
                    $error("Invalid read_addr2 %h with inst %h",
                           read_addr2, read_inst);
                end
                assert(32'(write_addr1) < `REG_COUNT) else begin
                    $error("Invalid write_addr1 %h", write_addr1);
                end
            `endif
            prev_read_addr1 <= read_addr1;
            prev_read_addr2 <= read_addr2;
        end
        else begin
            pc <= `BIT_WIDTH'b0;
            prev_read_addr1 <= `REG_COUNT_L2'b0;
            prev_read_addr2 <= `REG_COUNT_L2'b0;
        end
    end
endmodule
