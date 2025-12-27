// =============================================================================
// Decode Stage - ARM7 Pipeline
// =============================================================================
// Description:
//   Second stage of the 5-stage ARM7 pipeline. Decodes instructions,
//   reads registers, and generates control signals.
//
// Learning Points:
//   - Instruction decoding
//   - Register file access
//   - Control signal generation
//   - Immediate value extraction
//
// Author: ARM7 Computer System Project
// Date: 2025-11-03
// =============================================================================

module decode_stage #(
    parameter DATA_WIDTH = 32,
    parameter REG_ADDR_WIDTH = 4
) (
    input  wire                         clk,
    input  wire                         rst_n,
    
    // Control signals
    input  wire                         stall,
    input  wire                         flush,
    
    // From fetch stage
    input  wire [DATA_WIDTH-1:0]        if_id_instruction,
    input  wire [DATA_WIDTH-1:0]        if_id_pc,
    input  wire [DATA_WIDTH-1:0]        if_id_pc_plus_4,
    
    // From writeback stage (for register write)
    input  wire [REG_ADDR_WIDTH-1:0]    wb_rd,
    input  wire [DATA_WIDTH-1:0]        wb_data,
    input  wire                         wb_reg_write,
    
    // CPSR flags
    input  wire [3:0]                   cpsr_flags,
    
    // To execute stage
    output reg  [DATA_WIDTH-1:0]        id_ex_pc,
    output reg  [DATA_WIDTH-1:0]        id_ex_pc_plus_4,
    output reg  [DATA_WIDTH-1:0]        id_ex_reg_data_a,
    output reg  [DATA_WIDTH-1:0]        id_ex_reg_data_b,
    output reg  [DATA_WIDTH-1:0]        id_ex_immediate,
    output reg  [REG_ADDR_WIDTH-1:0]    id_ex_rs,
    output reg  [REG_ADDR_WIDTH-1:0]    id_ex_rt,
    output reg  [REG_ADDR_WIDTH-1:0]    id_ex_rd,
    output reg  [3:0]                   id_ex_opcode,
    output reg                          id_ex_alu_src,
    output reg                          id_ex_reg_write,
    output reg                          id_ex_mem_read,
    output reg                          id_ex_mem_write,
    output reg                          id_ex_branch,
    output reg  [1:0]                   id_ex_shift_type,
    output reg  [4:0]                   id_ex_shift_amt
);

    // Instruction fields
    wire [3:0] cond = if_id_instruction[31:28];
    wire [1:0] op_type = if_id_instruction[27:26];
    wire i_bit = if_id_instruction[25];
    wire [3:0] opcode = if_id_instruction[24:21];
    wire s_bit = if_id_instruction[20];
    wire [3:0] rn = if_id_instruction[19:16];
    wire [3:0] rd = if_id_instruction[15:12];
    wire [11:0] imm12 = if_id_instruction[11:0];
    wire [3:0] rm = if_id_instruction[3:0];
    wire [1:0] shift_type = if_id_instruction[6:5];
    wire [4:0] shift_amt = if_id_instruction[11:7];
    
    // Instruction decoder
    wire [3:0] dec_cond;
    wire [1:0] dec_op_type;
    wire [3:0] dec_opcode;
    wire dec_s_bit;
    wire [3:0] dec_rn, dec_rd, dec_rm;
    wire [11:0] dec_imm12;
    wire [23:0] dec_offset24;
    wire dec_reg_write, dec_mem_read, dec_mem_write;
    wire dec_alu_src, dec_branch, dec_branch_link;
    wire dec_condition_pass;
    wire [1:0] dec_shift_type;
    wire [4:0] dec_shift_amt;
    
    instruction_decoder decoder (
        .instruction(if_id_instruction),
        .cpsr_flags(cpsr_flags),
        .cond(dec_cond),
        .op_type(dec_op_type),
        .opcode(dec_opcode),
        .s_bit(dec_s_bit),
        .rn(dec_rn),
        .rd(dec_rd),
        .rm(dec_rm),
        .imm12(dec_imm12),
        .offset24(dec_offset24),
        .reg_write(dec_reg_write),
        .mem_read(dec_mem_read),
        .mem_write(dec_mem_write),
        .alu_src(dec_alu_src),
        .branch(dec_branch),
        .branch_link(dec_branch_link),
        .condition_pass(dec_condition_pass),
        .shift_type(dec_shift_type),
        .shift_amt(dec_shift_amt)
    );
    
    // Register file
    wire [DATA_WIDTH-1:0] reg_data_a, reg_data_b;
    
    register_file_3r1w #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(REG_ADDR_WIDTH),
        .NUM_REGS(16)
    ) regfile (
        .clk(clk),
        .rst_n(rst_n),
        .read_addr_a(dec_rn),
        .read_addr_b(dec_rm),
        .read_addr_c(4'b0),  // Not used
        .read_data_a(reg_data_a),
        .read_data_b(reg_data_b),
        .read_data_c(),
        .write_addr(wb_rd),
        .write_data(wb_data),
        .write_en(wb_reg_write)
    );
    
    // Immediate value extension
    wire [DATA_WIDTH-1:0] immediate_extended;
    
    // For data processing: rotate immediate
    wire [7:0] imm8 = dec_imm12[7:0];
    wire [3:0] rotate = dec_imm12[11:8];
    wire [DATA_WIDTH-1:0] rotated_imm = {imm8, 24'b0} >> (rotate * 2);
    
    // For branch: sign-extend 24-bit offset and shift left 2
    wire [DATA_WIDTH-1:0] branch_offset = {{6{dec_offset24[23]}}, dec_offset24, 2'b00};
    
    assign immediate_extended = dec_branch ? branch_offset : rotated_imm;
    
    // ID/EX pipeline register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            id_ex_pc <= 32'b0;
            id_ex_pc_plus_4 <= 32'b0;
            id_ex_reg_data_a <= 32'b0;
            id_ex_reg_data_b <= 32'b0;
            id_ex_immediate <= 32'b0;
            id_ex_rs <= 4'b0;
            id_ex_rt <= 4'b0;
            id_ex_rd <= 4'b0;
            id_ex_opcode <= 4'b0;
            id_ex_alu_src <= 1'b0;
            id_ex_reg_write <= 1'b0;
            id_ex_mem_read <= 1'b0;
            id_ex_mem_write <= 1'b0;
            id_ex_branch <= 1'b0;
            id_ex_shift_type <= 2'b0;
            id_ex_shift_amt <= 5'b0;
        end else if (flush) begin
            // Insert NOP
            id_ex_reg_write <= 1'b0;
            id_ex_mem_read <= 1'b0;
            id_ex_mem_write <= 1'b0;
            id_ex_branch <= 1'b0;
        end else if (!stall) begin
            id_ex_pc <= if_id_pc;
            id_ex_pc_plus_4 <= if_id_pc_plus_4;
            id_ex_reg_data_a <= reg_data_a;
            id_ex_reg_data_b <= reg_data_b;
            id_ex_immediate <= immediate_extended;
            id_ex_rs <= dec_rn;
            id_ex_rt <= dec_rm;
            id_ex_rd <= dec_rd;
            id_ex_opcode <= dec_opcode;
            id_ex_alu_src <= dec_alu_src;
            id_ex_reg_write <= dec_reg_write & dec_condition_pass;
            id_ex_mem_read <= dec_mem_read & dec_condition_pass;
            id_ex_mem_write <= dec_mem_write & dec_condition_pass;
            id_ex_branch <= dec_branch & dec_condition_pass;
            id_ex_shift_type <= dec_shift_type;
            id_ex_shift_amt <= dec_shift_amt;
        end
    end
    
endmodule

// Simplified Decode Stage (without pipeline register)
module decode_stage_comb #(
    parameter DATA_WIDTH = 32,
    parameter REG_ADDR_WIDTH = 4
) (
    input  wire                         clk,
    input  wire                         rst_n,
    
    // Instruction input
    input  wire [DATA_WIDTH-1:0]        instruction,
    input  wire [3:0]                   cpsr_flags,
    
    // Register file interface
    input  wire [REG_ADDR_WIDTH-1:0]    wb_rd,
    input  wire [DATA_WIDTH-1:0]        wb_data,
    input  wire                         wb_reg_write,
    
    // Decoded outputs
    output wire [DATA_WIDTH-1:0]        reg_data_a,
    output wire [DATA_WIDTH-1:0]        reg_data_b,
    output wire [DATA_WIDTH-1:0]        immediate,
    output wire [REG_ADDR_WIDTH-1:0]    rs,
    output wire [REG_ADDR_WIDTH-1:0]    rt,
    output wire [REG_ADDR_WIDTH-1:0]    rd,
    output wire [3:0]                   opcode,
    output wire                         alu_src,
    output wire                         reg_write,
    output wire                         mem_read,
    output wire                         mem_write,
    output wire                         branch
);

    // Instruction decoder
    wire [3:0] dec_cond;
    wire [1:0] dec_op_type;
    wire [11:0] dec_imm12;
    wire [23:0] dec_offset24;
    wire dec_branch_link, dec_condition_pass;
    wire [1:0] dec_shift_type;
    wire [4:0] dec_shift_amt;
    
    instruction_decoder decoder (
        .instruction(instruction),
        .cpsr_flags(cpsr_flags),
        .cond(dec_cond),
        .op_type(dec_op_type),
        .opcode(opcode),
        .s_bit(),
        .rn(rs),
        .rd(rd),
        .rm(rt),
        .imm12(dec_imm12),
        .offset24(dec_offset24),
        .reg_write(reg_write),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .alu_src(alu_src),
        .branch(branch),
        .branch_link(dec_branch_link),
        .condition_pass(dec_condition_pass),
        .shift_type(dec_shift_type),
        .shift_amt(dec_shift_amt)
    );
    
    // Register file
    register_file_3r1w #(
        .DATA_WIDTH(DATA_WIDTH),
        .ADDR_WIDTH(REG_ADDR_WIDTH),
        .NUM_REGS(16)
    ) regfile (
        .clk(clk),
        .rst_n(rst_n),
        .read_addr_a(rs),
        .read_addr_b(rt),
        .read_addr_c(4'b0),
        .read_data_a(reg_data_a),
        .read_data_b(reg_data_b),
        .read_data_c(),
        .write_addr(wb_rd),
        .write_data(wb_data),
        .write_en(wb_reg_write)
    );
    
    // Immediate extension
    wire [7:0] imm8 = dec_imm12[7:0];
    wire [3:0] rotate = dec_imm12[11:8];
    wire [DATA_WIDTH-1:0] rotated_imm = {imm8, 24'b0} >> (rotate * 2);
    wire [DATA_WIDTH-1:0] branch_offset = {{6{dec_offset24[23]}}, dec_offset24, 2'b00};
    
    assign immediate = branch ? branch_offset : rotated_imm;
    
endmodule

// =============================================================================
// Usage Examples:
// =============================================================================
//
// Example 1: Decode stage in pipeline
//   decode_stage #(
//       .DATA_WIDTH(32),
//       .REG_ADDR_WIDTH(4)
//   ) id_stage (
//       .clk(clk),
//       .rst_n(rst_n),
//       .stall(pipeline_stall),
//       .flush(branch_flush),
//       .if_id_instruction(fetched_instruction),
//       .if_id_pc(current_pc),
//       .if_id_pc_plus_4(next_pc),
//       .wb_rd(writeback_rd),
//       .wb_data(writeback_data),
//       .wb_reg_write(writeback_wr),
//       .cpsr_flags(current_flags),
//       .id_ex_reg_data_a(operand_a),
//       .id_ex_reg_data_b(operand_b),
//       // ... other outputs
//   );
//
// =============================================================================

