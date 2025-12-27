// =============================================================================
// Memory Stage - ARM7 Pipeline
// =============================================================================
// Description:
//   Fourth stage of the 5-stage ARM7 pipeline. Handles memory access
//   (load/store operations) and passes results to writeback.
//
// Learning Points:
//   - Memory interface
//   - Load/store operations
//   - Data alignment
//   - Cache interface
//
// Author: ARM7 Computer System Project
// Date: 2025-11-03
// =============================================================================

module memory_stage #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter REG_ADDR_WIDTH = 4
) (
    input  wire                         clk,
    input  wire                         rst_n,
    
    // Control signals
    input  wire                         stall,
    input  wire                         flush,
    
    // From execute stage
    input  wire [DATA_WIDTH-1:0]        ex_mem_alu_result,
    input  wire [DATA_WIDTH-1:0]        ex_mem_write_data,
    input  wire [REG_ADDR_WIDTH-1:0]    ex_mem_rd,
    input  wire                         ex_mem_reg_write,
    input  wire                         ex_mem_mem_read,
    input  wire                         ex_mem_mem_write,
    
    // Data memory interface
    output wire [ADDR_WIDTH-1:0]        dmem_addr,
    output wire [DATA_WIDTH-1:0]        dmem_write_data,
    output wire                         dmem_read_en,
    output wire                         dmem_write_en,
    input  wire [DATA_WIDTH-1:0]        dmem_read_data,
    input  wire                         dmem_ready,
    
    // To writeback stage
    output reg  [DATA_WIDTH-1:0]        mem_wb_result,
    output reg  [REG_ADDR_WIDTH-1:0]    mem_wb_rd,
    output reg                          mem_wb_reg_write
);

    // Memory interface
    assign dmem_addr = ex_mem_alu_result;
    assign dmem_write_data = ex_mem_write_data;
    assign dmem_read_en = ex_mem_mem_read;
    assign dmem_write_en = ex_mem_mem_write;
    
    // Result selection (ALU result or memory data)
    wire [DATA_WIDTH-1:0] mem_result;
    assign mem_result = ex_mem_mem_read ? dmem_read_data : ex_mem_alu_result;
    
    // MEM/WB pipeline register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_wb_result <= 32'b0;
            mem_wb_rd <= 4'b0;
            mem_wb_reg_write <= 1'b0;
        end else if (flush) begin
            mem_wb_reg_write <= 1'b0;
        end else if (!stall && dmem_ready) begin
            mem_wb_result <= mem_result;
            mem_wb_rd <= ex_mem_rd;
            mem_wb_reg_write <= ex_mem_reg_write;
        end
    end
    
endmodule

// Memory Stage with Byte/Halfword Support
module memory_stage_aligned #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 32,
    parameter REG_ADDR_WIDTH = 4
) (
    input  wire                         clk,
    input  wire                         rst_n,
    input  wire                         stall,
    input  wire                         flush,
    
    // From execute stage
    input  wire [DATA_WIDTH-1:0]        ex_mem_alu_result,
    input  wire [DATA_WIDTH-1:0]        ex_mem_write_data,
    input  wire [REG_ADDR_WIDTH-1:0]    ex_mem_rd,
    input  wire                         ex_mem_reg_write,
    input  wire                         ex_mem_mem_read,
    input  wire                         ex_mem_mem_write,
    input  wire [1:0]                   ex_mem_mem_size,  // 00=byte, 01=half, 10=word
    input  wire                         ex_mem_mem_signed, // Sign extend
    
    // Data memory interface
    output wire [ADDR_WIDTH-1:0]        dmem_addr,
    output wire [DATA_WIDTH-1:0]        dmem_write_data,
    output wire [3:0]                   dmem_byte_en,
    output wire                         dmem_read_en,
    output wire                         dmem_write_en,
    input  wire [DATA_WIDTH-1:0]        dmem_read_data,
    
    // To writeback stage
    output reg  [DATA_WIDTH-1:0]        mem_wb_result,
    output reg  [REG_ADDR_WIDTH-1:0]    mem_wb_rd,
    output reg                          mem_wb_reg_write
);

    // Memory size encoding
    localparam SIZE_BYTE = 2'b00;
    localparam SIZE_HALF = 2'b01;
    localparam SIZE_WORD = 2'b10;
    
    // Address alignment
    wire [1:0] byte_offset = ex_mem_alu_result[1:0];
    assign dmem_addr = {ex_mem_alu_result[ADDR_WIDTH-1:2], 2'b00};  // Word-aligned
    
    // Byte enable generation
    reg [3:0] byte_enable;
    always @(*) begin
        case (ex_mem_mem_size)
            SIZE_BYTE: begin
                case (byte_offset)
                    2'b00: byte_enable = 4'b0001;
                    2'b01: byte_enable = 4'b0010;
                    2'b10: byte_enable = 4'b0100;
                    2'b11: byte_enable = 4'b1000;
                endcase
            end
            SIZE_HALF: begin
                case (byte_offset[1])
                    1'b0: byte_enable = 4'b0011;
                    1'b1: byte_enable = 4'b1100;
                endcase
            end
            SIZE_WORD: byte_enable = 4'b1111;
            default: byte_enable = 4'b1111;
        endcase
    end
    
    assign dmem_byte_en = byte_enable;
    
    // Write data alignment
    reg [DATA_WIDTH-1:0] aligned_write_data;
    always @(*) begin
        case (ex_mem_mem_size)
            SIZE_BYTE: begin
                case (byte_offset)
                    2'b00: aligned_write_data = {24'b0, ex_mem_write_data[7:0]};
                    2'b01: aligned_write_data = {16'b0, ex_mem_write_data[7:0], 8'b0};
                    2'b10: aligned_write_data = {8'b0, ex_mem_write_data[7:0], 16'b0};
                    2'b11: aligned_write_data = {ex_mem_write_data[7:0], 24'b0};
                endcase
            end
            SIZE_HALF: begin
                case (byte_offset[1])
                    1'b0: aligned_write_data = {16'b0, ex_mem_write_data[15:0]};
                    1'b1: aligned_write_data = {ex_mem_write_data[15:0], 16'b0};
                endcase
            end
            SIZE_WORD: aligned_write_data = ex_mem_write_data;
            default: aligned_write_data = ex_mem_write_data;
        endcase
    end
    
    assign dmem_write_data = aligned_write_data;
    assign dmem_read_en = ex_mem_mem_read;
    assign dmem_write_en = ex_mem_mem_write;
    
    // Read data alignment and sign extension
    reg [DATA_WIDTH-1:0] aligned_read_data;
    always @(*) begin
        case (ex_mem_mem_size)
            SIZE_BYTE: begin
                case (byte_offset)
                    2'b00: aligned_read_data = ex_mem_mem_signed ? 
                           {{24{dmem_read_data[7]}}, dmem_read_data[7:0]} :
                           {24'b0, dmem_read_data[7:0]};
                    2'b01: aligned_read_data = ex_mem_mem_signed ?
                           {{24{dmem_read_data[15]}}, dmem_read_data[15:8]} :
                           {24'b0, dmem_read_data[15:8]};
                    2'b10: aligned_read_data = ex_mem_mem_signed ?
                           {{24{dmem_read_data[23]}}, dmem_read_data[23:16]} :
                           {24'b0, dmem_read_data[23:16]};
                    2'b11: aligned_read_data = ex_mem_mem_signed ?
                           {{24{dmem_read_data[31]}}, dmem_read_data[31:24]} :
                           {24'b0, dmem_read_data[31:24]};
                endcase
            end
            SIZE_HALF: begin
                case (byte_offset[1])
                    1'b0: aligned_read_data = ex_mem_mem_signed ?
                          {{16{dmem_read_data[15]}}, dmem_read_data[15:0]} :
                          {16'b0, dmem_read_data[15:0]};
                    1'b1: aligned_read_data = ex_mem_mem_signed ?
                          {{16{dmem_read_data[31]}}, dmem_read_data[31:16]} :
                          {16'b0, dmem_read_data[31:16]};
                endcase
            end
            SIZE_WORD: aligned_read_data = dmem_read_data;
            default: aligned_read_data = dmem_read_data;
        endcase
    end
    
    // Result selection
    wire [DATA_WIDTH-1:0] mem_result;
    assign mem_result = ex_mem_mem_read ? aligned_read_data : ex_mem_alu_result;
    
    // Pipeline register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_wb_result <= 32'b0;
            mem_wb_rd <= 4'b0;
            mem_wb_reg_write <= 1'b0;
        end else if (flush) begin
            mem_wb_reg_write <= 1'b0;
        end else if (!stall) begin
            mem_wb_result <= mem_result;
            mem_wb_rd <= ex_mem_rd;
            mem_wb_reg_write <= ex_mem_reg_write;
        end
    end
    
endmodule

// Writeback Stage (simple pass-through)
module writeback_stage #(
    parameter DATA_WIDTH = 32,
    parameter REG_ADDR_WIDTH = 4
) (
    // From memory stage
    input  wire [DATA_WIDTH-1:0]        mem_wb_result,
    input  wire [REG_ADDR_WIDTH-1:0]    mem_wb_rd,
    input  wire                         mem_wb_reg_write,
    
    // To register file (in decode stage)
    output wire [DATA_WIDTH-1:0]        wb_data,
    output wire [REG_ADDR_WIDTH-1:0]    wb_rd,
    output wire                         wb_reg_write
);

    // Simple pass-through (no additional logic needed)
    assign wb_data = mem_wb_result;
    assign wb_rd = mem_wb_rd;
    assign wb_reg_write = mem_wb_reg_write;
    
endmodule

// =============================================================================
// Usage Examples:
// =============================================================================
//
// Example 1: Basic memory stage
//   memory_stage #(
//       .DATA_WIDTH(32),
//       .ADDR_WIDTH(32),
//       .REG_ADDR_WIDTH(4)
//   ) mem_stage (
//       .clk(clk),
//       .rst_n(rst_n),
//       .stall(pipeline_stall),
//       .flush(exception_flush),
//       .ex_mem_alu_result(alu_result),
//       .ex_mem_write_data(store_data),
//       .ex_mem_rd(dest_reg),
//       .ex_mem_reg_write(reg_wr_en),
//       .ex_mem_mem_read(load_en),
//       .ex_mem_mem_write(store_en),
//       .dmem_addr(data_addr),
//       .dmem_write_data(data_out),
//       .dmem_read_en(data_rd),
//       .dmem_write_en(data_wr),
//       .dmem_read_data(data_in),
//       .dmem_ready(mem_ready),
//       .mem_wb_result(wb_result),
//       .mem_wb_rd(wb_rd),
//       .mem_wb_reg_write(wb_wr_en)
//   );
//
// =============================================================================

