// =============================================================================
// ARM7 CPU Top Module - Complete Integration
// =============================================================================
// Description:
//   Top-level ARM7 CPU integrating all pipeline stages, hazard unit,
//   and memory interfaces.
//
// Learning Points:
//   - CPU integration
//   - Pipeline stage interconnection
//   - Memory-mapped I/O
//   - System bus interface
//
// Author: ARM7 Computer System Project
// Date: 2025-11-03
// =============================================================================

module cpu_top #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter REG_ADDR_WIDTH = 4
) (
    input  wire                         clk,
    input  wire                         rst_n,
    
    // Instruction memory interface
    output wire [ADDR_WIDTH-1:0]        imem_addr,
    output wire                         imem_read_en,
    input  wire [DATA_WIDTH-1:0]        imem_read_data,
    input  wire                         imem_ready,
    
    // Data memory interface
    output wire [ADDR_WIDTH-1:0]        dmem_addr,
    output wire [DATA_WIDTH-1:0]        dmem_write_data,
    output wire                         dmem_read_en,
    output wire                         dmem_write_en,
    input  wire [DATA_WIDTH-1:0]        dmem_read_data,
    input  wire                         dmem_ready,
    
    // Interrupt inputs
    input  wire                         irq,
    input  wire                         fiq,
    
    // Debug outputs
    output wire [DATA_WIDTH-1:0]        debug_pc,
    output wire [3:0]                   debug_cpsr_flags,
    output wire                         debug_halted
);

    // Pipeline control signals
    wire pipeline_stall;
    wire pipeline_flush;
    wire branch_taken;
    wire [DATA_WIDTH-1:0] branch_target;
    
    // IF/ID pipeline signals
    wire [DATA_WIDTH-1:0] if_id_pc;
    wire [DATA_WIDTH-1:0] if_id_pc_plus_4;
    wire [DATA_WIDTH-1:0] if_id_instruction;
    
    // ID/EX pipeline signals
    wire [DATA_WIDTH-1:0] id_ex_pc;
    wire [DATA_WIDTH-1:0] id_ex_pc_plus_4;
    wire [DATA_WIDTH-1:0] id_ex_reg_data_a;
    wire [DATA_WIDTH-1:0] id_ex_reg_data_b;
    wire [DATA_WIDTH-1:0] id_ex_immediate;
    wire [REG_ADDR_WIDTH-1:0] id_ex_rs;
    wire [REG_ADDR_WIDTH-1:0] id_ex_rt;
    wire [REG_ADDR_WIDTH-1:0] id_ex_rd;
    wire [3:0] id_ex_opcode;
    wire id_ex_alu_src;
    wire id_ex_reg_write;
    wire id_ex_mem_read;
    wire id_ex_mem_write;
    wire id_ex_branch;
    wire [1:0] id_ex_shift_type;
    wire [4:0] id_ex_shift_amt;
    
    // EX/MEM pipeline signals
    wire [DATA_WIDTH-1:0] ex_mem_alu_result;
    wire [DATA_WIDTH-1:0] ex_mem_write_data;
    wire [REG_ADDR_WIDTH-1:0] ex_mem_rd;
    wire ex_mem_reg_write;
    wire ex_mem_mem_read;
    wire ex_mem_mem_write;
    
    // MEM/WB pipeline signals
    wire [DATA_WIDTH-1:0] mem_wb_result;
    wire [REG_ADDR_WIDTH-1:0] mem_wb_rd;
    wire mem_wb_reg_write;
    
    // Writeback signals
    wire [DATA_WIDTH-1:0] wb_data;
    wire [REG_ADDR_WIDTH-1:0] wb_rd;
    wire wb_reg_write;
    
    // Forwarding signals
    wire [1:0] forward_a;
    wire [1:0] forward_b;
    
    // CPSR flags
    wire [3:0] cpsr_flags;
    
    // Fetch stage
    fetch_stage #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH)
    ) fetch (
        .clk(clk),
        .rst_n(rst_n),
        .stall(pipeline_stall),
        .flush(pipeline_flush),
        .branch_taken(branch_taken),
        .branch_target(branch_target),
        .imem_addr(imem_addr),
        .imem_read_en(imem_read_en),
        .imem_read_data(imem_read_data),
        .if_id_pc(if_id_pc),
        .if_id_pc_plus_4(if_id_pc_plus_4),
        .if_id_instruction(if_id_instruction)
    );
    
    // Decode stage
    decode_stage #(
        .DATA_WIDTH(DATA_WIDTH),
        .REG_ADDR_WIDTH(REG_ADDR_WIDTH)
    ) decode (
        .clk(clk),
        .rst_n(rst_n),
        .stall(pipeline_stall),
        .flush(pipeline_flush),
        .if_id_pc(if_id_pc),
        .if_id_pc_plus_4(if_id_pc_plus_4),
        .if_id_instruction(if_id_instruction),
        .cpsr_flags(cpsr_flags),
        .wb_data(wb_data),
        .wb_rd(wb_rd),
        .wb_reg_write(wb_reg_write),
        .id_ex_pc(id_ex_pc),
        .id_ex_pc_plus_4(id_ex_pc_plus_4),
        .id_ex_reg_data_a(id_ex_reg_data_a),
        .id_ex_reg_data_b(id_ex_reg_data_b),
        .id_ex_immediate(id_ex_immediate),
        .id_ex_rs(id_ex_rs),
        .id_ex_rt(id_ex_rt),
        .id_ex_rd(id_ex_rd),
        .id_ex_opcode(id_ex_opcode),
        .id_ex_alu_src(id_ex_alu_src),
        .id_ex_reg_write(id_ex_reg_write),
        .id_ex_mem_read(id_ex_mem_read),
        .id_ex_mem_write(id_ex_mem_write),
        .id_ex_branch(id_ex_branch),
        .id_ex_shift_type(id_ex_shift_type),
        .id_ex_shift_amt(id_ex_shift_amt)
    );
    
    // Execute stage
    execute_stage #(
        .DATA_WIDTH(DATA_WIDTH),
        .REG_ADDR_WIDTH(REG_ADDR_WIDTH)
    ) execute (
        .clk(clk),
        .rst_n(rst_n),
        .stall(pipeline_stall),
        .flush(pipeline_flush),
        .id_ex_pc(id_ex_pc),
        .id_ex_pc_plus_4(id_ex_pc_plus_4),
        .id_ex_reg_data_a(id_ex_reg_data_a),
        .id_ex_reg_data_b(id_ex_reg_data_b),
        .id_ex_immediate(id_ex_immediate),
        .id_ex_rs(id_ex_rs),
        .id_ex_rt(id_ex_rt),
        .id_ex_rd(id_ex_rd),
        .id_ex_opcode(id_ex_opcode),
        .id_ex_alu_src(id_ex_alu_src),
        .id_ex_reg_write(id_ex_reg_write),
        .id_ex_mem_read(id_ex_mem_read),
        .id_ex_mem_write(id_ex_mem_write),
        .id_ex_branch(id_ex_branch),
        .id_ex_shift_type(id_ex_shift_type),
        .id_ex_shift_amt(id_ex_shift_amt),
        .forward_a(forward_a),
        .forward_b(forward_b),
        .mem_forward_data(ex_mem_alu_result),
        .wb_forward_data(wb_data),
        .ex_mem_alu_result(ex_mem_alu_result),
        .ex_mem_write_data(ex_mem_write_data),
        .ex_mem_rd(ex_mem_rd),
        .ex_mem_reg_write(ex_mem_reg_write),
        .ex_mem_mem_read(ex_mem_mem_read),
        .ex_mem_mem_write(ex_mem_mem_write),
        .branch_taken(branch_taken),
        .branch_target(branch_target),
        .cpsr_flags(cpsr_flags)
    );
    
    // Memory stage
    memory_stage #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(ADDR_WIDTH),
        .REG_ADDR_WIDTH(REG_ADDR_WIDTH)
    ) memory (
        .clk(clk),
        .rst_n(rst_n),
        .stall(pipeline_stall),
        .flush(1'b0),  // No flush in memory stage
        .ex_mem_alu_result(ex_mem_alu_result),
        .ex_mem_write_data(ex_mem_write_data),
        .ex_mem_rd(ex_mem_rd),
        .ex_mem_reg_write(ex_mem_reg_write),
        .ex_mem_mem_read(ex_mem_mem_read),
        .ex_mem_mem_write(ex_mem_mem_write),
        .dmem_addr(dmem_addr),
        .dmem_write_data(dmem_write_data),
        .dmem_read_en(dmem_read_en),
        .dmem_write_en(dmem_write_en),
        .dmem_read_data(dmem_read_data),
        .dmem_ready(dmem_ready),
        .mem_wb_result(mem_wb_result),
        .mem_wb_rd(mem_wb_rd),
        .mem_wb_reg_write(mem_wb_reg_write)
    );
    
    // Writeback stage
    writeback_stage #(
        .DATA_WIDTH(DATA_WIDTH),
        .REG_ADDR_WIDTH(REG_ADDR_WIDTH)
    ) writeback (
        .mem_wb_result(mem_wb_result),
        .mem_wb_rd(mem_wb_rd),
        .mem_wb_reg_write(mem_wb_reg_write),
        .wb_data(wb_data),
        .wb_rd(wb_rd),
        .wb_reg_write(wb_reg_write)
    );
    
    // Hazard unit
    hazard_unit #(
        .REG_ADDR_WIDTH(REG_ADDR_WIDTH)
    ) hazard (
        .id_rs(id_ex_rs),
        .id_rt(id_ex_rt),
        .id_reg_read_rs(1'b1),  // Simplified - always reading
        .id_reg_read_rt(1'b1),
        .ex_rd(ex_mem_rd),
        .ex_reg_write(ex_mem_reg_write),
        .ex_mem_read(ex_mem_mem_read),
        .mem_rd(mem_wb_rd),
        .mem_reg_write(mem_wb_reg_write),
        .wb_rd(wb_rd),
        .wb_reg_write(wb_reg_write),
        .branch_taken(branch_taken),
        .forward_a(forward_a),
        .forward_b(forward_b),
        .stall(pipeline_stall),
        .flush(pipeline_flush)
    );
    
    // Debug outputs
    assign debug_pc = if_id_pc;
    assign debug_cpsr_flags = cpsr_flags;
    assign debug_halted = 1'b0;  // No halt implemented yet
    
endmodule

// =============================================================================
// Usage Example:
// =============================================================================
//
// cpu_top #(
//     .DATA_WIDTH(32),
//     .ADDR_WIDTH(32)
// ) cpu (
//     .clk(clk),
//     .rst_n(rst_n),
//     .imem_addr(instruction_addr),
//     .imem_read_en(instruction_read),
//     .imem_read_data(instruction_data),
//     .imem_ready(instruction_ready),
//     .dmem_addr(data_addr),
//     .dmem_write_data(data_write),
//     .dmem_read_en(data_read),
//     .dmem_write_en(data_write_en),
//     .dmem_read_data(data_read_data),
//     .dmem_ready(data_ready),
//     .debug_pc(current_pc),
//     .debug_cpsr_flags(flags)
// );
//
// =============================================================================

