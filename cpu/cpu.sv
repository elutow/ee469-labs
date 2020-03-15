// Top-level module for the ARM 32 CPU
// Responsibilities:
// - Controls the Program Counter state
// - Manages the state of all stages of instruction execution

`include "cpu/constants.svh"

module cpu(
        input wire clk,
        input wire nreset,
        output wire led,
        /* verilator lint_off LITENDIAN */
        output wire [8:`DEBUG_BYTES*8-1] debug_port_vector
        /* verilator lint_on LITENDIAN */
    );

    // Program Counter (managed by regfile)
    logic [`BIT_WIDTH-1:0] pc;

    // Turn on LED when reset is not on
    assign led = nreset;

    // Shared modules

    logic [`BIT_WIDTH-1:0] regfile_read_inst;
    logic [`REG_COUNT_L2-1:0] regfile_read_addr1, regfile_read_addr2;
    logic [`BIT_WIDTH-1:0] regfile_read_value1, regfile_read_value2;
    logic regfile_write_enable1;
    logic [`REG_COUNT_L2-1:0] regfile_write_addr1;
    logic [`BIT_WIDTH-1:0] regfile_write_value1;
    logic [`BIT_WIDTH-1:0] regfile_new_pc;
    logic regfile_update_pc;
    regfile the_regfile(
        .clk, .nreset, .read_inst(regfile_read_inst),
        .read_addr1(regfile_read_addr1), .read_addr2(regfile_read_addr2),
        .read_value1(regfile_read_value1), .read_value2(regfile_read_value2),
        .write_enable1(regfile_write_enable1),
        .write_addr1(regfile_write_addr1), .write_value1(regfile_write_value1),
        .pc, .new_pc(regfile_new_pc), .update_pc(regfile_update_pc)
    );

    // CPU stages

    logic fetcher_enable, fetcher_ready;
    logic [`BIT_WIDTH-1:0] fetcher_inst;
    fetcher the_fetcher(
        .clk, .nreset, .enable(fetcher_enable), .ready(fetcher_ready),
        .pc, .fetcher_inst
    );

    logic decoder_enable, decoder_ready;
    logic [`BIT_WIDTH-1:0] decoder_inst;
    logic [`BIT_WIDTH-1:0] decoder_Rn_value, decoder_Rd_Rm_value;
    logic stall_for_ldr;
    decoder the_decoder(
        .clk, .nreset, .enable(decoder_enable), .ready(decoder_ready),
        .stall_for_ldr,
        .fetcher_inst, .decoder_inst, .regfile_read_inst, .regfile_read_addr1,
        .regfile_read_addr2, .regfile_read_value1, .regfile_read_value2,
        .Rn_value(decoder_Rn_value), .Rd_Rm_value(decoder_Rd_Rm_value)
    );

    // Forwarding registers/wires from memaccessor to executor
    logic memaccessor_fwd_has_Rd;
    logic [`REG_COUNT_L2-1:0] memaccessor_fwd_Rd_addr;
    logic [`BIT_WIDTH-1:0] memaccessor_fwd_Rd_value;

    logic executor_enable, executor_ready;
    logic [`BIT_WIDTH-1:0] executor_inst;
    logic executor_update_pc;
    logic [`BIT_WIDTH-1:0] executor_new_pc;
    logic executor_update_Rd;
    logic [`BIT_WIDTH-1:0] databranch_Rd_value;
    logic [`CPSR_SIZE-1:0] cpsr;
    logic condition_passes;
    logic flush_for_pc;
    logic [`BIT_WIDTH-1:0] mem_read_addr;
    logic mem_write_enable;
    logic [`BIT_WIDTH-1:0] mem_write_addr;
    logic [`BIT_WIDTH-1:0] mem_write_value;
    executor the_executor(
        .clk, .nreset, .enable(executor_enable), .ready(executor_ready),
        .cpsr, .condition_passes, .executor_inst, .flush_for_pc,
        .update_pc(executor_update_pc), .pc, .new_pc(executor_new_pc),
        .update_Rd(executor_update_Rd), .databranch_Rd_value, .mem_read_addr,
        .mem_write_enable, .mem_write_addr, .mem_write_value, .decoder_inst,
        .decoder_Rn_value, .decoder_Rd_Rm_value, .memaccessor_fwd_has_Rd,
        .memaccessor_fwd_Rd_addr, .memaccessor_fwd_Rd_value
    );

    logic memaccessor_enable, memaccessor_ready;
    logic [`BIT_WIDTH-1:0] memaccessor_inst;
    logic memaccessor_update_pc;
    logic [`BIT_WIDTH-1:0] memaccessor_new_pc;
    logic memaccessor_update_Rd;
    logic [`BIT_WIDTH-1:0] memaccessor_Rd_value;
    memaccessor the_memaccessor(
        .clk, .nreset, .enable(memaccessor_enable), .ready(memaccessor_ready),
        .executor_inst, .memaccessor_inst,
        .read_addr(mem_read_addr), .write_enable(mem_write_enable),
        .write_addr(mem_write_addr), .write_value(mem_write_value),
        .executor_update_pc, .executor_new_pc, .executor_update_Rd,
        .databranch_Rd_value, .update_pc(memaccessor_update_pc),
        .new_pc(memaccessor_new_pc), .update_Rd(memaccessor_update_Rd),
        .Rd_value(memaccessor_Rd_value), .fwd_has_Rd(memaccessor_fwd_has_Rd),
        .fwd_Rd_addr(memaccessor_fwd_Rd_addr),
        .fwd_Rd_value(memaccessor_fwd_Rd_value)
    );

    logic regfilewriter_enable, regfilewriter_ready;
    logic [`BIT_WIDTH-1:0] regfilewriter_new_pc;
    logic regfilewriter_update_pc;
    regfilewriter the_regfilewriter(
        .clk, .nreset, .enable(regfilewriter_enable), .ready(regfilewriter_ready),
        .pc, .memaccessor_inst, .update_pc(memaccessor_update_pc),
        .new_pc(memaccessor_new_pc), .update_Rd(memaccessor_update_Rd),
        .Rd_value(memaccessor_Rd_value), .regfile_write_enable1,
        .regfile_write_addr1, .regfile_write_value1,
        .regfile_new_pc(regfilewriter_new_pc),
        .regfile_update_pc(regfilewriter_update_pc)
    );

    // CPU FSM to control pipelining
    enum { RUNNING, PC_FLUSH, LDR_STALL } ps, ns;
    logic stall_pc_advance;
    always_comb begin
        fetcher_enable = nreset;
        decoder_enable = fetcher_ready;
        executor_enable = decoder_ready;
        memaccessor_enable = executor_ready;
        regfilewriter_enable = memaccessor_ready;
        stall_pc_advance = 1'b0;
        case (ps)
            RUNNING: begin
                ns = RUNNING;
                if (executor_ready && flush_for_pc) begin
                    ns = PC_FLUSH;
                    fetcher_enable = 1'b0;
                    decoder_enable = 1'b0;
                    executor_enable = 1'b0;
                end
                if (decoder_ready && stall_for_ldr) begin
                    // Stall fetcher, decoder, executor
                    fetcher_enable = 1'b0;
                    decoder_enable = 1'b0;
                    executor_enable = 1'b0;
                    stall_pc_advance = 1'b1;
                    ns = LDR_STALL;
                end
            end
            PC_FLUSH: begin // Flush stages before executor for PC update
                `ifndef SYNTHESIS
                    // Because executor is disabled, its flush status persists
                    assert(flush_for_pc);
                    // However, the ready signal should turn off
                    assert(!executor_ready);
                    // Sanity check if memaccessor finished
                    assert(memaccessor_ready);
                `endif
                fetcher_enable = 1'b0;
                decoder_enable = 1'b0;
                executor_enable = 1'b0;
                // Since memaccessor is done, disable it
                memaccessor_enable = 1'b0;
                ns = RUNNING; // By next clock cycle, regfilewriter should be done
            end
            LDR_STALL: begin
                // Pipeline has been stalled for one cycle for memaccessor, now
                // resume flow of data in the pipeline
                ns = RUNNING;
                fetcher_enable = 1'b1;
                decoder_enable = 1'b1;
                executor_enable = 1'b1;
            end
        endcase
    end // comb
    always_ff @(posedge clk) begin
        if (nreset) begin
            ps <= ns;
        end
        else begin
            ps <= RUNNING;
        end
    end

    // PC-updating logic
    always_comb begin
        regfile_update_pc = regfilewriter_update_pc;
        regfile_new_pc = regfilewriter_new_pc;
        if (!(regfile_update_pc || regfile_write_enable1 && (regfile_write_addr1 == `REG_PC_INDEX))) begin
            // Update PC to next instruction
            if (!stall_pc_advance) begin
                regfile_update_pc = 1'b1;
                regfile_new_pc = pc + `BIT_WIDTH'd4;
            end
        end
    end // comb

    // Debug port outputs
    always_comb begin
        // Output to debug port
        debug_port_vector[1*8:5*8-1] = pc;
        debug_port_vector[5*8:6*8-1] = {
            3'b0, fetcher_ready, decoder_ready, executor_ready,
            memaccessor_ready, regfilewriter_ready
        };
        debug_port_vector[6*8:7*8-1] = {4'b0, regfile_read_addr1};
        debug_port_vector[7*8:11*8-1] = regfile_read_value1;
        debug_port_vector[11*8:12*8-1] = {4'b0, regfile_read_addr2};
        debug_port_vector[12*8:16*8-1] = regfile_read_value2;
        debug_port_vector[16*8:17*8-1] = {4'b0, regfile_write_addr1};
        debug_port_vector[17*8:21*8-1] = regfile_write_value1;
        debug_port_vector[21*8:22*8-1] = {
            1'b0, regfile_update_pc, regfile_write_enable1,
            condition_passes, cpsr
        };
        debug_port_vector[22*8:26*8-1] = fetcher_inst;
        debug_port_vector[26*8:30*8-1] = regfile_new_pc;
    end   // comb
endmodule
