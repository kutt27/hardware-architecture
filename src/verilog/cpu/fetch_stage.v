// =============================================================================
// Instruction Fetch Stage - ARM7 Pipeline
// =============================================================================
// Description:
//   First stage of the 5-stage ARM7 pipeline. Manages program counter (PC)
//   and fetches instructions from instruction memory.
//
// Learning Points:
//   - PC management and increment
//   - Branch target calculation
//   - Pipeline flush on branch
//   - Instruction memory interface
//
// Author: ARM7 Computer System Project
// Date: 2025-11-03
// =============================================================================

module fetch_stage #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    input  wire                     clk,
    input  wire                     rst_n,
    
    // Control signals
    input  wire                     stall,          // Stall fetch stage
    input  wire                     branch_taken,   // Branch taken signal
    input  wire [ADDR_WIDTH-1:0]    branch_target,  // Branch target address
    
    // Instruction memory interface
    output wire [ADDR_WIDTH-1:0]    imem_addr,      // Instruction address
    input  wire [DATA_WIDTH-1:0]    imem_data,      // Instruction data
    output wire                     imem_read,      // Read enable
    
    // Outputs to decode stage
    output reg  [DATA_WIDTH-1:0]    if_id_instruction,
    output reg  [ADDR_WIDTH-1:0]    if_id_pc,
    output reg  [ADDR_WIDTH-1:0]    if_id_pc_plus_4
);

    // Program Counter
    reg [ADDR_WIDTH-1:0] pc;
    wire [ADDR_WIDTH-1:0] pc_next;
    wire [ADDR_WIDTH-1:0] pc_plus_4;
    
    // PC increment
    assign pc_plus_4 = pc + 4;
    
    // PC next value selection
    assign pc_next = branch_taken ? branch_target : pc_plus_4;
    
    // PC update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc <= 32'h00000000;  // Reset vector
        end else if (!stall) begin
            pc <= pc_next;
        end
    end
    
    // Instruction memory interface
    assign imem_addr = pc;
    assign imem_read = 1'b1;  // Always reading
    
    // IF/ID pipeline register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            if_id_instruction <= 32'h00000000;  // NOP
            if_id_pc <= 32'h00000000;
            if_id_pc_plus_4 <= 32'h00000004;
        end else if (branch_taken) begin
            // Insert bubble (NOP) on branch
            if_id_instruction <= 32'hE1A00000;  // MOV R0, R0 (NOP)
            if_id_pc <= pc;
            if_id_pc_plus_4 <= pc_plus_4;
        end else if (!stall) begin
            if_id_instruction <= imem_data;
            if_id_pc <= pc;
            if_id_pc_plus_4 <= pc_plus_4;
        end
    end
    
endmodule

// Fetch Stage with Branch Prediction
module fetch_stage_predicted #(
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    input  wire                     clk,
    input  wire                     rst_n,
    
    // Control signals
    input  wire                     stall,
    input  wire                     branch_taken,
    input  wire [ADDR_WIDTH-1:0]    branch_target,
    input  wire                     branch_mispredict,  // Misprediction signal
    
    // Branch prediction
    input  wire                     predict_taken,      // Prediction
    input  wire [ADDR_WIDTH-1:0]    predict_target,     // Predicted target
    
    // Instruction memory interface
    output wire [ADDR_WIDTH-1:0]    imem_addr,
    input  wire [DATA_WIDTH-1:0]    imem_data,
    output wire                     imem_read,
    
    // Outputs
    output reg  [DATA_WIDTH-1:0]    if_id_instruction,
    output reg  [ADDR_WIDTH-1:0]    if_id_pc,
    output reg  [ADDR_WIDTH-1:0]    if_id_pc_plus_4,
    output reg                      if_id_predicted_taken
);

    reg [ADDR_WIDTH-1:0] pc;
    wire [ADDR_WIDTH-1:0] pc_next;
    wire [ADDR_WIDTH-1:0] pc_plus_4;
    
    assign pc_plus_4 = pc + 4;
    
    // PC selection with prediction
    assign pc_next = branch_mispredict ? branch_target :
                     predict_taken ? predict_target :
                     pc_plus_4;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc <= 32'h00000000;
        end else if (!stall) begin
            pc <= pc_next;
        end
    end
    
    assign imem_addr = pc;
    assign imem_read = 1'b1;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            if_id_instruction <= 32'h00000000;
            if_id_pc <= 32'h00000000;
            if_id_pc_plus_4 <= 32'h00000004;
            if_id_predicted_taken <= 1'b0;
        end else if (branch_mispredict) begin
            if_id_instruction <= 32'hE1A00000;  // NOP
            if_id_pc <= pc;
            if_id_pc_plus_4 <= pc_plus_4;
            if_id_predicted_taken <= 1'b0;
        end else if (!stall) begin
            if_id_instruction <= imem_data;
            if_id_pc <= pc;
            if_id_pc_plus_4 <= pc_plus_4;
            if_id_predicted_taken <= predict_taken;
        end
    end
    
endmodule

// Simple Branch Predictor (Always Not Taken)
module branch_predictor_static (
    input  wire [31:0]  instruction,
    output wire         predict_taken,
    output wire [31:0]  predict_target
);
    // Static prediction: always not taken
    assign predict_taken = 1'b0;
    assign predict_target = 32'h00000000;
endmodule

// 1-bit Branch Predictor
module branch_predictor_1bit #(
    parameter TABLE_SIZE = 256
) (
    input  wire         clk,
    input  wire         rst_n,
    
    // Prediction request
    input  wire [31:0]  pc,
    output wire         predict_taken,
    
    // Update from execute stage
    input  wire         update_en,
    input  wire [31:0]  update_pc,
    input  wire         actual_taken
);

    // Branch history table
    reg [TABLE_SIZE-1:0] bht;
    
    // Index into table using PC
    wire [7:0] index = pc[9:2];
    wire [7:0] update_index = update_pc[9:2];
    
    // Prediction
    assign predict_taken = bht[index];
    
    // Update on branch resolution
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            bht <= {TABLE_SIZE{1'b0}};  // Initialize to not taken
        end else if (update_en) begin
            bht[update_index] <= actual_taken;
        end
    end
    
endmodule

// PC Management Unit
module pc_manager #(
    parameter ADDR_WIDTH = 32
) (
    input  wire                     clk,
    input  wire                     rst_n,
    input  wire [ADDR_WIDTH-1:0]    reset_vector,
    
    // Control
    input  wire                     stall,
    input  wire                     branch,
    input  wire [ADDR_WIDTH-1:0]    branch_target,
    input  wire                     exception,
    input  wire [ADDR_WIDTH-1:0]    exception_vector,
    
    // Output
    output reg  [ADDR_WIDTH-1:0]    pc,
    output wire [ADDR_WIDTH-1:0]    pc_plus_4,
    output wire [ADDR_WIDTH-1:0]    pc_plus_8
);

    assign pc_plus_4 = pc + 4;
    assign pc_plus_8 = pc + 8;
    
    wire [ADDR_WIDTH-1:0] pc_next;
    
    // PC selection priority: exception > branch > increment
    assign pc_next = exception ? exception_vector :
                     branch ? branch_target :
                     pc_plus_4;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc <= reset_vector;
        end else if (!stall) begin
            pc <= pc_next;
        end
    end
    
endmodule

// =============================================================================
// Usage Examples:
// =============================================================================
//
// Example 1: Basic fetch stage
//   fetch_stage #(
//       .ADDR_WIDTH(32),
//       .DATA_WIDTH(32)
//   ) if_stage (
//       .clk(clk),
//       .rst_n(rst_n),
//       .stall(pipeline_stall),
//       .branch_taken(ex_branch_taken),
//       .branch_target(ex_branch_target),
//       .imem_addr(instruction_addr),
//       .imem_data(instruction_data),
//       .imem_read(instruction_read),
//       .if_id_instruction(decoded_instruction),
//       .if_id_pc(current_pc),
//       .if_id_pc_plus_4(next_pc)
//   );
//
// Example 2: Fetch with branch prediction
//   fetch_stage_predicted if_stage_pred (
//       .clk(clk),
//       .rst_n(rst_n),
//       .stall(stall),
//       .branch_taken(branch_resolved),
//       .branch_target(resolved_target),
//       .branch_mispredict(mispredict),
//       .predict_taken(bp_predict),
//       .predict_target(bp_target),
//       .imem_addr(imem_addr),
//       .imem_data(imem_data),
//       .imem_read(imem_read),
//       .if_id_instruction(instruction),
//       .if_id_pc(pc),
//       .if_id_pc_plus_4(pc_plus_4),
//       .if_id_predicted_taken(predicted)
//   );
//
// =============================================================================

