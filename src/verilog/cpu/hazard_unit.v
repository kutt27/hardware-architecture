// =============================================================================
// Hazard Detection and Forwarding Unit - ARM7 Pipeline
// =============================================================================
// Description:
//   Detects and resolves pipeline hazards including data hazards (RAW),
//   control hazards (branches), and structural hazards. Implements
//   forwarding and stalling logic.
//
// Learning Points:
//   - Data hazard detection (RAW - Read After Write)
//   - Forwarding paths (EX-to-EX, MEM-to-EX)
//   - Load-use hazards and stalling
//   - Branch hazard handling
//
// Author: ARM7 Computer System Project
// Date: 2025-11-03
// =============================================================================

module hazard_unit (
    // Decode stage inputs
    input  wire [3:0]   id_rs,          // Source register 1
    input  wire [3:0]   id_rt,          // Source register 2
    input  wire         id_reg_read_rs, // RS is read
    input  wire         id_reg_read_rt, // RT is read
    
    // Execute stage inputs
    input  wire [3:0]   ex_rd,          // Destination register
    input  wire         ex_reg_write,   // Register write enable
    input  wire         ex_mem_read,    // Memory read (load)
    
    // Memory stage inputs
    input  wire [3:0]   mem_rd,         // Destination register
    input  wire         mem_reg_write,  // Register write enable
    
    // Writeback stage inputs
    input  wire [3:0]   wb_rd,          // Destination register
    input  wire         wb_reg_write,   // Register write enable
    
    // Branch control
    input  wire         id_branch,      // Branch in decode
    input  wire         ex_branch,      // Branch in execute
    
    // Outputs
    output wire         stall_if,       // Stall fetch stage
    output wire         stall_id,       // Stall decode stage
    output wire         flush_id,       // Flush decode stage
    output wire         flush_ex,       // Flush execute stage
    
    // Forwarding control
    output wire [1:0]   forward_a,      // Forward source A
    output wire [1:0]   forward_b       // Forward source B
);

    // Forwarding selection
    localparam FWD_NONE = 2'b00;  // No forwarding
    localparam FWD_MEM  = 2'b01;  // Forward from MEM stage
    localparam FWD_WB   = 2'b10;  // Forward from WB stage
    
    // =========================================================================
    // Data Hazard Detection and Forwarding
    // =========================================================================
    
    // Forward A (for RS)
    wire ex_to_id_hazard_a = ex_reg_write && (ex_rd != 4'b0) && 
                             (ex_rd == id_rs) && id_reg_read_rs;
    wire mem_to_id_hazard_a = mem_reg_write && (mem_rd != 4'b0) && 
                              (mem_rd == id_rs) && id_reg_read_rs &&
                              !(ex_reg_write && (ex_rd == id_rs));
    wire wb_to_id_hazard_a = wb_reg_write && (wb_rd != 4'b0) && 
                             (wb_rd == id_rs) && id_reg_read_rs &&
                             !(ex_reg_write && (ex_rd == id_rs)) &&
                             !(mem_reg_write && (mem_rd == id_rs));
    
    assign forward_a = ex_to_id_hazard_a ? FWD_MEM :
                       mem_to_id_hazard_a ? FWD_MEM :
                       wb_to_id_hazard_a ? FWD_WB :
                       FWD_NONE;
    
    // Forward B (for RT)
    wire ex_to_id_hazard_b = ex_reg_write && (ex_rd != 4'b0) && 
                             (ex_rd == id_rt) && id_reg_read_rt;
    wire mem_to_id_hazard_b = mem_reg_write && (mem_rd != 4'b0) && 
                              (mem_rd == id_rt) && id_reg_read_rt &&
                              !(ex_reg_write && (ex_rd == id_rt));
    wire wb_to_id_hazard_b = wb_reg_write && (wb_rd != 4'b0) && 
                             (wb_rd == id_rt) && id_reg_read_rt &&
                             !(ex_reg_write && (ex_rd == id_rt)) &&
                             !(mem_reg_write && (mem_rd == id_rt));
    
    assign forward_b = ex_to_id_hazard_b ? FWD_MEM :
                       mem_to_id_hazard_b ? FWD_MEM :
                       wb_to_id_hazard_b ? FWD_WB :
                       FWD_NONE;
    
    // =========================================================================
    // Load-Use Hazard Detection (requires stall)
    // =========================================================================
    
    wire load_use_hazard = ex_mem_read && (
        ((ex_rd == id_rs) && id_reg_read_rs) ||
        ((ex_rd == id_rt) && id_reg_read_rt)
    );
    
    // =========================================================================
    // Branch Hazard Detection
    // =========================================================================
    
    wire branch_hazard = ex_branch;  // Branch resolved in EX stage
    
    // =========================================================================
    // Stall and Flush Control
    // =========================================================================
    
    assign stall_if = load_use_hazard;
    assign stall_id = load_use_hazard;
    assign flush_id = branch_hazard;
    assign flush_ex = load_use_hazard || branch_hazard;
    
endmodule

// Forwarding Unit (Separate Module)
module forwarding_unit (
    // Execute stage operands
    input  wire [3:0]   ex_rs,
    input  wire [3:0]   ex_rt,
    
    // Memory stage
    input  wire [3:0]   mem_rd,
    input  wire         mem_reg_write,
    
    // Writeback stage
    input  wire [3:0]   wb_rd,
    input  wire         wb_reg_write,
    
    // Forwarding control
    output wire [1:0]   forward_a,
    output wire [1:0]   forward_b
);

    localparam FWD_NONE = 2'b00;
    localparam FWD_MEM  = 2'b01;
    localparam FWD_WB   = 2'b10;
    
    // EX hazard (MEM-to-EX forwarding)
    wire ex_hazard_a = mem_reg_write && (mem_rd != 4'b0) && (mem_rd == ex_rs);
    wire ex_hazard_b = mem_reg_write && (mem_rd != 4'b0) && (mem_rd == ex_rt);
    
    // MEM hazard (WB-to-EX forwarding)
    wire mem_hazard_a = wb_reg_write && (wb_rd != 4'b0) && (wb_rd == ex_rs) &&
                        !(mem_reg_write && (mem_rd == ex_rs));
    wire mem_hazard_b = wb_reg_write && (wb_rd != 4'b0) && (wb_rd == ex_rt) &&
                        !(mem_reg_write && (mem_rd == ex_rt));
    
    assign forward_a = ex_hazard_a ? FWD_MEM :
                       mem_hazard_a ? FWD_WB :
                       FWD_NONE;
    
    assign forward_b = ex_hazard_b ? FWD_MEM :
                       mem_hazard_b ? FWD_WB :
                       FWD_NONE;
    
endmodule

// Stall Controller
module stall_controller (
    // Hazard signals
    input  wire load_use_hazard,
    input  wire branch_hazard,
    input  wire cache_miss,
    input  wire div_busy,
    
    // Stall outputs
    output wire stall_if,
    output wire stall_id,
    output wire stall_ex,
    output wire stall_mem
);

    // Stall all stages before the hazard
    assign stall_if = load_use_hazard || cache_miss || div_busy;
    assign stall_id = load_use_hazard || cache_miss || div_busy;
    assign stall_ex = cache_miss || div_busy;
    assign stall_mem = cache_miss;
    
endmodule

// Flush Controller
module flush_controller (
    // Hazard signals
    input  wire branch_taken,
    input  wire exception,
    input  wire interrupt,
    
    // Flush outputs
    output wire flush_if,
    output wire flush_id,
    output wire flush_ex,
    output wire flush_mem
);

    // Flush stages after branch/exception
    assign flush_if = branch_taken || exception || interrupt;
    assign flush_id = branch_taken || exception || interrupt;
    assign flush_ex = branch_taken || exception || interrupt;
    assign flush_mem = exception || interrupt;
    
endmodule

// Complete Hazard and Control Unit
module pipeline_control_unit (
    input  wire         clk,
    input  wire         rst_n,
    
    // Decode stage
    input  wire [3:0]   id_rs,
    input  wire [3:0]   id_rt,
    input  wire         id_reg_read_rs,
    input  wire         id_reg_read_rt,
    input  wire         id_branch,
    
    // Execute stage
    input  wire [3:0]   ex_rs,
    input  wire [3:0]   ex_rt,
    input  wire [3:0]   ex_rd,
    input  wire         ex_reg_write,
    input  wire         ex_mem_read,
    input  wire         ex_branch_taken,
    
    // Memory stage
    input  wire [3:0]   mem_rd,
    input  wire         mem_reg_write,
    input  wire         cache_miss,
    
    // Writeback stage
    input  wire [3:0]   wb_rd,
    input  wire         wb_reg_write,
    
    // Control outputs
    output wire         stall_if,
    output wire         stall_id,
    output wire         stall_ex,
    output wire         flush_if,
    output wire         flush_id,
    output wire         flush_ex,
    output wire [1:0]   forward_a,
    output wire [1:0]   forward_b
);

    // Hazard detection
    wire load_use = ex_mem_read && (
        ((ex_rd == id_rs) && id_reg_read_rs) ||
        ((ex_rd == id_rt) && id_reg_read_rt)
    );
    
    // Forwarding unit
    forwarding_unit fwd_unit (
        .ex_rs(ex_rs),
        .ex_rt(ex_rt),
        .mem_rd(mem_rd),
        .mem_reg_write(mem_reg_write),
        .wb_rd(wb_rd),
        .wb_reg_write(wb_reg_write),
        .forward_a(forward_a),
        .forward_b(forward_b)
    );
    
    // Stall control
    assign stall_if = load_use || cache_miss;
    assign stall_id = load_use || cache_miss;
    assign stall_ex = cache_miss;
    
    // Flush control
    assign flush_if = ex_branch_taken;
    assign flush_id = ex_branch_taken;
    assign flush_ex = load_use || ex_branch_taken;
    
endmodule

// =============================================================================
// Usage Examples:
// =============================================================================
//
// Example 1: Basic hazard unit
//   hazard_unit hazard (
//       .id_rs(decode_rs),
//       .id_rt(decode_rt),
//       .id_reg_read_rs(rs_used),
//       .id_reg_read_rt(rt_used),
//       .ex_rd(execute_rd),
//       .ex_reg_write(execute_wr),
//       .ex_mem_read(execute_load),
//       .mem_rd(memory_rd),
//       .mem_reg_write(memory_wr),
//       .wb_rd(writeback_rd),
//       .wb_reg_write(writeback_wr),
//       .stall_if(stall_fetch),
//       .stall_id(stall_decode),
//       .flush_ex(flush_execute),
//       .forward_a(fwd_a),
//       .forward_b(fwd_b)
//   );
//
// =============================================================================

