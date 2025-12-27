// =============================================================================
// Register File - Multi-Port Register Array
// =============================================================================
// Description:
//   Implements a register file with multiple read and write ports. This is
//   the heart of the CPU datapath, storing general-purpose registers.
//
// Learning Points:
//   - Multi-port memory design
//   - Read-during-write behavior
//   - Register 0 hardwired to zero (ARM convention)
//   - Synchronous write, asynchronous read
//
// Author: ARM7 Computer System Project
// Date: 2025-11-03
// =============================================================================

// 2-Read, 1-Write Register File (Standard CPU configuration)
module register_file #(
    parameter DATA_WIDTH = 32,  // Width of each register
    parameter ADDR_WIDTH = 4,   // Number of address bits (16 registers for ARM)
    parameter NUM_REGS = 16     // Total number of registers
) (
    input  wire                     clk,
    input  wire                     rst_n,
    
    // Read port 1
    input  wire [ADDR_WIDTH-1:0]    rd_addr1,
    output wire [DATA_WIDTH-1:0]    rd_data1,
    
    // Read port 2
    input  wire [ADDR_WIDTH-1:0]    rd_addr2,
    output wire [DATA_WIDTH-1:0]    rd_data2,
    
    // Write port
    input  wire                     wr_en,
    input  wire [ADDR_WIDTH-1:0]    wr_addr,
    input  wire [DATA_WIDTH-1:0]    wr_data
);
    // Register array
    reg [DATA_WIDTH-1:0] registers [0:NUM_REGS-1];
    
    // Initialize registers to zero
    integer i;
    initial begin
        for (i = 0; i < NUM_REGS; i = i + 1) begin
            registers[i] = {DATA_WIDTH{1'b0}};
        end
    end
    
    // Asynchronous read (combinational)
    // Reads happen immediately without waiting for clock
    // Register 0 is hardwired to zero (ARM convention)
    assign rd_data1 = (rd_addr1 == 0) ? {DATA_WIDTH{1'b0}} : registers[rd_addr1];
    assign rd_data2 = (rd_addr2 == 0) ? {DATA_WIDTH{1'b0}} : registers[rd_addr2];
    
    // Synchronous write
    // Writes happen on rising clock edge
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            // Reset all registers to zero
            for (i = 0; i < NUM_REGS; i = i + 1) begin
                registers[i] <= {DATA_WIDTH{1'b0}};
            end
        end else if (wr_en && wr_addr != 0) begin
            // Write to register (except R0 which is always 0)
            registers[wr_addr] <= wr_data;
        end
    end
endmodule

// 3-Read, 1-Write Register File (For complex instructions)
module register_file_3r1w #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 4,
    parameter NUM_REGS = 16
) (
    input  wire                     clk,
    input  wire                     rst_n,
    
    // Read ports
    input  wire [ADDR_WIDTH-1:0]    rd_addr1,
    output wire [DATA_WIDTH-1:0]    rd_data1,
    
    input  wire [ADDR_WIDTH-1:0]    rd_addr2,
    output wire [DATA_WIDTH-1:0]    rd_data2,
    
    input  wire [ADDR_WIDTH-1:0]    rd_addr3,
    output wire [DATA_WIDTH-1:0]    rd_data3,
    
    // Write port
    input  wire                     wr_en,
    input  wire [ADDR_WIDTH-1:0]    wr_addr,
    input  wire [DATA_WIDTH-1:0]    wr_data
);
    reg [DATA_WIDTH-1:0] registers [0:NUM_REGS-1];
    
    integer i;
    initial begin
        for (i = 0; i < NUM_REGS; i = i + 1) begin
            registers[i] = {DATA_WIDTH{1'b0}};
        end
    end
    
    // Three asynchronous read ports
    assign rd_data1 = (rd_addr1 == 0) ? {DATA_WIDTH{1'b0}} : registers[rd_addr1];
    assign rd_data2 = (rd_addr2 == 0) ? {DATA_WIDTH{1'b0}} : registers[rd_addr2];
    assign rd_data3 = (rd_addr3 == 0) ? {DATA_WIDTH{1'b0}} : registers[rd_addr3];
    
    // Synchronous write
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < NUM_REGS; i = i + 1) begin
                registers[i] <= {DATA_WIDTH{1'b0}};
            end
        end else if (wr_en && wr_addr != 0) begin
            registers[wr_addr] <= wr_data;
        end
    end
endmodule

// Register File with Forwarding Support
// Handles read-during-write hazards by forwarding write data
module register_file_forwarding #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 4,
    parameter NUM_REGS = 16
) (
    input  wire                     clk,
    input  wire                     rst_n,
    
    // Read port 1
    input  wire [ADDR_WIDTH-1:0]    rd_addr1,
    output reg  [DATA_WIDTH-1:0]    rd_data1,
    
    // Read port 2
    input  wire [ADDR_WIDTH-1:0]    rd_addr2,
    output reg  [DATA_WIDTH-1:0]    rd_data2,
    
    // Write port
    input  wire                     wr_en,
    input  wire [ADDR_WIDTH-1:0]    wr_addr,
    input  wire [DATA_WIDTH-1:0]    wr_data
);
    reg [DATA_WIDTH-1:0] registers [0:NUM_REGS-1];
    
    integer i;
    initial begin
        for (i = 0; i < NUM_REGS; i = i + 1) begin
            registers[i] = {DATA_WIDTH{1'b0}};
        end
    end
    
    // Read with forwarding logic
    // If reading the same register being written, forward the write data
    always @(*) begin
        if (rd_addr1 == 0) begin
            rd_data1 = {DATA_WIDTH{1'b0}};
        end else if (wr_en && rd_addr1 == wr_addr) begin
            rd_data1 = wr_data;  // Forward write data
        end else begin
            rd_data1 = registers[rd_addr1];
        end
        
        if (rd_addr2 == 0) begin
            rd_data2 = {DATA_WIDTH{1'b0}};
        end else if (wr_en && rd_addr2 == wr_addr) begin
            rd_data2 = wr_data;  // Forward write data
        end else begin
            rd_data2 = registers[rd_addr2];
        end
    end
    
    // Synchronous write
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < NUM_REGS; i = i + 1) begin
                registers[i] <= {DATA_WIDTH{1'b0}};
            end
        end else if (wr_en && wr_addr != 0) begin
            registers[wr_addr] <= wr_data;
        end
    end
endmodule

// Dual-Port Register File (Separate read and write clocks)
module register_file_dual_clock #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 4,
    parameter NUM_REGS = 16
) (
    input  wire                     rd_clk,
    input  wire                     wr_clk,
    input  wire                     rst_n,
    
    // Read port
    input  wire [ADDR_WIDTH-1:0]    rd_addr,
    output reg  [DATA_WIDTH-1:0]    rd_data,
    
    // Write port
    input  wire                     wr_en,
    input  wire [ADDR_WIDTH-1:0]    wr_addr,
    input  wire [DATA_WIDTH-1:0]    wr_data
);
    reg [DATA_WIDTH-1:0] registers [0:NUM_REGS-1];
    
    integer i;
    initial begin
        for (i = 0; i < NUM_REGS; i = i + 1) begin
            registers[i] = {DATA_WIDTH{1'b0}};
        end
    end
    
    // Synchronous read on rd_clk
    always @(posedge rd_clk or negedge rst_n) begin
        if (!rst_n) begin
            rd_data <= {DATA_WIDTH{1'b0}};
        end else begin
            rd_data <= (rd_addr == 0) ? {DATA_WIDTH{1'b0}} : registers[rd_addr];
        end
    end
    
    // Synchronous write on wr_clk
    always @(posedge wr_clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < NUM_REGS; i = i + 1) begin
                registers[i] <= {DATA_WIDTH{1'b0}};
            end
        end else if (wr_en && wr_addr != 0) begin
            registers[wr_addr] <= wr_data;
        end
    end
endmodule

// =============================================================================
// Usage Examples:
// =============================================================================
//
// Example 1: Standard ARM7 register file
//   register_file #(
//       .DATA_WIDTH(32),
//       .ADDR_WIDTH(4),
//       .NUM_REGS(16)
//   ) cpu_regfile (
//       .clk(clk),
//       .rst_n(rst_n),
//       .rd_addr1(rs_addr),      // Source register 1
//       .rd_data1(rs_data),
//       .rd_addr2(rt_addr),      // Source register 2
//       .rd_data2(rt_data),
//       .wr_en(reg_write),
//       .wr_addr(rd_addr),       // Destination register
//       .wr_data(write_data)
//   );
//
// Example 2: Register file with forwarding for pipelined CPU
//   register_file_forwarding #(
//       .DATA_WIDTH(32),
//       .ADDR_WIDTH(4),
//       .NUM_REGS(16)
//   ) cpu_regfile_fwd (
//       .clk(clk),
//       .rst_n(rst_n),
//       .rd_addr1(decode_rs),
//       .rd_data1(rs_data),
//       .rd_addr2(decode_rt),
//       .rd_data2(rt_data),
//       .wr_en(writeback_en),
//       .wr_addr(writeback_rd),
//       .wr_data(writeback_data)
//   );
//
// =============================================================================

