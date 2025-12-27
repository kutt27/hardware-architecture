// =============================================================================
// Execute Stage - ARM7 Pipeline
// =============================================================================
// Description:
//   Third stage of the 5-stage ARM7 pipeline. Performs ALU operations,
//   address calculation, and branch resolution.
//
// Learning Points:
//   - ALU execution
//   - Data forwarding
//   - Branch target calculation
//   - Flag generation
//
// Author: ARM7 Computer System Project
// Date: 2025-11-03
// =============================================================================

module execute_stage #(
    parameter DATA_WIDTH = 32,
    parameter REG_ADDR_WIDTH = 4
) (
    input  wire                         clk,
    input  wire                         rst_n,
    
    // Control signals
    input  wire                         stall,
    input  wire                         flush,
    
    // From decode stage
    input  wire [DATA_WIDTH-1:0]        id_ex_pc,
    input  wire [DATA_WIDTH-1:0]        id_ex_pc_plus_4,
    input  wire [DATA_WIDTH-1:0]        id_ex_reg_data_a,
    input  wire [DATA_WIDTH-1:0]        id_ex_reg_data_b,
    input  wire [DATA_WIDTH-1:0]        id_ex_immediate,
    input  wire [REG_ADDR_WIDTH-1:0]    id_ex_rs,
    input  wire [REG_ADDR_WIDTH-1:0]    id_ex_rt,
    input  wire [REG_ADDR_WIDTH-1:0]    id_ex_rd,
    input  wire [3:0]                   id_ex_opcode,
    input  wire                         id_ex_alu_src,
    input  wire                         id_ex_reg_write,
    input  wire                         id_ex_mem_read,
    input  wire                         id_ex_mem_write,
    input  wire                         id_ex_branch,
    input  wire [1:0]                   id_ex_shift_type,
    input  wire [4:0]                   id_ex_shift_amt,
    
    // Forwarding inputs
    input  wire [1:0]                   forward_a,
    input  wire [1:0]                   forward_b,
    input  wire [DATA_WIDTH-1:0]        mem_forward_data,
    input  wire [DATA_WIDTH-1:0]        wb_forward_data,
    
    // To memory stage
    output reg  [DATA_WIDTH-1:0]        ex_mem_alu_result,
    output reg  [DATA_WIDTH-1:0]        ex_mem_write_data,
    output reg  [REG_ADDR_WIDTH-1:0]    ex_mem_rd,
    output reg                          ex_mem_reg_write,
    output reg                          ex_mem_mem_read,
    output reg                          ex_mem_mem_write,
    
    // Branch outputs
    output wire                         branch_taken,
    output wire [DATA_WIDTH-1:0]        branch_target,
    
    // Flag outputs
    output reg  [3:0]                   cpsr_flags  // N, Z, C, V
);

    // Forwarding multiplexers
    localparam FWD_NONE = 2'b00;
    localparam FWD_MEM  = 2'b01;
    localparam FWD_WB   = 2'b10;
    
    wire [DATA_WIDTH-1:0] alu_input_a;
    wire [DATA_WIDTH-1:0] alu_input_b_pre_shift;
    wire [DATA_WIDTH-1:0] alu_input_b;
    
    // Forward A multiplexer
    assign alu_input_a = (forward_a == FWD_MEM) ? mem_forward_data :
                         (forward_a == FWD_WB)  ? wb_forward_data :
                         id_ex_reg_data_a;
    
    // Forward B multiplexer (before ALU source selection)
    wire [DATA_WIDTH-1:0] forwarded_b;
    assign forwarded_b = (forward_b == FWD_MEM) ? mem_forward_data :
                         (forward_b == FWD_WB)  ? wb_forward_data :
                         id_ex_reg_data_b;
    
    // Barrel shifter
    wire [DATA_WIDTH-1:0] shifted_data;
    wire shift_carry_out;
    
    barrel_shifter #(
        .WIDTH(DATA_WIDTH)
    ) shifter (
        .data_in(forwarded_b),
        .shift_type(id_ex_shift_type),
        .shift_amt(id_ex_shift_amt),
        .carry_in(cpsr_flags[1]),  // C flag
        .data_out(shifted_data),
        .carry_out(shift_carry_out)
    );
    
    // ALU source B multiplexer (register/shifted or immediate)
    assign alu_input_b = id_ex_alu_src ? id_ex_immediate : shifted_data;
    
    // ALU
    wire [DATA_WIDTH-1:0] alu_result;
    wire alu_carry_out, alu_overflow, alu_zero, alu_negative;
    
    alu #(
        .WIDTH(DATA_WIDTH)
    ) alu_inst (
        .a(alu_input_a),
        .b(alu_input_b),
        .alu_op(id_ex_opcode),
        .carry_in(cpsr_flags[1]),  // C flag
        .result(alu_result),
        .carry_out(alu_carry_out),
        .overflow(alu_overflow),
        .zero(alu_zero),
        .negative(alu_negative)
    );
    
    // Branch target calculation
    assign branch_target = id_ex_pc + id_ex_immediate;
    assign branch_taken = id_ex_branch;
    
    // EX/MEM pipeline register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ex_mem_alu_result <= 32'b0;
            ex_mem_write_data <= 32'b0;
            ex_mem_rd <= 4'b0;
            ex_mem_reg_write <= 1'b0;
            ex_mem_mem_read <= 1'b0;
            ex_mem_mem_write <= 1'b0;
            cpsr_flags <= 4'b0;
        end else if (flush) begin
            // Insert NOP
            ex_mem_reg_write <= 1'b0;
            ex_mem_mem_read <= 1'b0;
            ex_mem_mem_write <= 1'b0;
        end else if (!stall) begin
            ex_mem_alu_result <= alu_result;
            ex_mem_write_data <= forwarded_b;  // For store instructions
            ex_mem_rd <= id_ex_rd;
            ex_mem_reg_write <= id_ex_reg_write;
            ex_mem_mem_read <= id_ex_mem_read;
            ex_mem_mem_write <= id_ex_mem_write;
            
            // Update flags (only for instructions that set flags)
            cpsr_flags <= {alu_negative, alu_zero, alu_carry_out, alu_overflow};
        end
    end
    
endmodule

// Execute Stage with Multiply Support
module execute_stage_mult #(
    parameter DATA_WIDTH = 32,
    parameter REG_ADDR_WIDTH = 4
) (
    input  wire                         clk,
    input  wire                         rst_n,
    input  wire                         stall,
    input  wire                         flush,
    
    // From decode stage
    input  wire [DATA_WIDTH-1:0]        id_ex_pc,
    input  wire [DATA_WIDTH-1:0]        id_ex_reg_data_a,
    input  wire [DATA_WIDTH-1:0]        id_ex_reg_data_b,
    input  wire [DATA_WIDTH-1:0]        id_ex_immediate,
    input  wire [REG_ADDR_WIDTH-1:0]    id_ex_rd,
    input  wire [3:0]                   id_ex_opcode,
    input  wire                         id_ex_alu_src,
    input  wire                         id_ex_reg_write,
    input  wire                         id_ex_mem_read,
    input  wire                         id_ex_mem_write,
    input  wire                         id_ex_branch,
    input  wire                         id_ex_multiply,  // Multiply instruction
    
    // Forwarding
    input  wire [1:0]                   forward_a,
    input  wire [1:0]                   forward_b,
    input  wire [DATA_WIDTH-1:0]        mem_forward_data,
    input  wire [DATA_WIDTH-1:0]        wb_forward_data,
    
    // Outputs
    output reg  [DATA_WIDTH-1:0]        ex_mem_result,
    output reg  [DATA_WIDTH-1:0]        ex_mem_write_data,
    output reg  [REG_ADDR_WIDTH-1:0]    ex_mem_rd,
    output reg                          ex_mem_reg_write,
    output reg                          ex_mem_mem_read,
    output reg                          ex_mem_mem_write,
    output wire                         branch_taken,
    output wire [DATA_WIDTH-1:0]        branch_target,
    output wire                         mult_busy
);

    localparam FWD_NONE = 2'b00;
    localparam FWD_MEM  = 2'b01;
    localparam FWD_WB   = 2'b10;
    
    // Forwarding
    wire [DATA_WIDTH-1:0] alu_input_a;
    wire [DATA_WIDTH-1:0] alu_input_b;
    
    assign alu_input_a = (forward_a == FWD_MEM) ? mem_forward_data :
                         (forward_a == FWD_WB)  ? wb_forward_data :
                         id_ex_reg_data_a;
    
    wire [DATA_WIDTH-1:0] forwarded_b;
    assign forwarded_b = (forward_b == FWD_MEM) ? mem_forward_data :
                         (forward_b == FWD_WB)  ? wb_forward_data :
                         id_ex_reg_data_b;
    
    assign alu_input_b = id_ex_alu_src ? id_ex_immediate : forwarded_b;
    
    // ALU
    wire [DATA_WIDTH-1:0] alu_result;
    wire alu_carry, alu_overflow, alu_zero, alu_neg;
    
    alu #(.WIDTH(DATA_WIDTH)) alu_inst (
        .a(alu_input_a),
        .b(alu_input_b),
        .alu_op(id_ex_opcode),
        .carry_in(1'b0),
        .result(alu_result),
        .carry_out(alu_carry),
        .overflow(alu_overflow),
        .zero(alu_zero),
        .negative(alu_neg)
    );
    
    // Multiplier (simple combinational for now)
    wire [DATA_WIDTH*2-1:0] mult_result = alu_input_a * alu_input_b;
    assign mult_busy = 1'b0;  // Combinational multiplier
    
    // Result selection
    wire [DATA_WIDTH-1:0] final_result;
    assign final_result = id_ex_multiply ? mult_result[DATA_WIDTH-1:0] : alu_result;
    
    // Branch
    assign branch_target = id_ex_pc + id_ex_immediate;
    assign branch_taken = id_ex_branch;
    
    // Pipeline register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            ex_mem_result <= 32'b0;
            ex_mem_write_data <= 32'b0;
            ex_mem_rd <= 4'b0;
            ex_mem_reg_write <= 1'b0;
            ex_mem_mem_read <= 1'b0;
            ex_mem_mem_write <= 1'b0;
        end else if (flush) begin
            ex_mem_reg_write <= 1'b0;
            ex_mem_mem_read <= 1'b0;
            ex_mem_mem_write <= 1'b0;
        end else if (!stall) begin
            ex_mem_result <= final_result;
            ex_mem_write_data <= forwarded_b;
            ex_mem_rd <= id_ex_rd;
            ex_mem_reg_write <= id_ex_reg_write;
            ex_mem_mem_read <= id_ex_mem_read;
            ex_mem_mem_write <= id_ex_mem_write;
        end
    end
    
endmodule

// =============================================================================
// Usage Examples:
// =============================================================================
//
// Example 1: Basic execute stage
//   execute_stage #(
//       .DATA_WIDTH(32),
//       .REG_ADDR_WIDTH(4)
//   ) ex_stage (
//       .clk(clk),
//       .rst_n(rst_n),
//       .stall(pipeline_stall),
//       .flush(branch_flush),
//       .id_ex_reg_data_a(operand_a),
//       .id_ex_reg_data_b(operand_b),
//       .id_ex_opcode(alu_operation),
//       .forward_a(fwd_a_sel),
//       .forward_b(fwd_b_sel),
//       .mem_forward_data(mem_result),
//       .wb_forward_data(wb_result),
//       .ex_mem_alu_result(alu_out),
//       .branch_taken(take_branch),
//       .branch_target(branch_addr),
//       .cpsr_flags(flags)
//   );
//
// =============================================================================

