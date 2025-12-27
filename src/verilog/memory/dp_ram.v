// =============================================================================
// Dual-Port RAM
// =============================================================================
// Description:
//   True dual-port RAM with independent read and write ports.
//   Allows simultaneous access from two different addresses.
//
// Learning Points:
//   - Dual-port memory architecture
//   - Read-during-write conflicts and resolution
//   - Independent port operation
//   - Use cases in pipelined systems
//
// Author: ARM7 Computer System Project
// Date: 2025-11-03
// =============================================================================

// Simple Dual-Port RAM (1 write port, 1 read port)
module simple_dp_ram #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 10,
    parameter DEPTH = 1024
) (
    input  wire                     clk,
    
    // Write port
    input  wire                     we,
    input  wire [ADDR_WIDTH-1:0]    waddr,
    input  wire [DATA_WIDTH-1:0]    din,
    
    // Read port
    input  wire [ADDR_WIDTH-1:0]    raddr,
    output reg  [DATA_WIDTH-1:0]    dout
);
    // Memory array
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    
    integer i;
    initial begin
        for (i = 0; i < DEPTH; i = i + 1) begin
            mem[i] = {DATA_WIDTH{1'b0}};
        end
    end
    
    // Write port (synchronous)
    always @(posedge clk) begin
        if (we) begin
            mem[waddr] <= din;
        end
    end
    
    // Read port (synchronous)
    always @(posedge clk) begin
        dout <= mem[raddr];
    end
    
    // Note: If raddr == waddr and we=1, old data is read
    // (write happens after read in same cycle)
endmodule

// True Dual-Port RAM (2 independent read/write ports)
module true_dp_ram #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 10,
    parameter DEPTH = 1024
) (
    input  wire                     clk,
    
    // Port A
    input  wire                     we_a,
    input  wire [ADDR_WIDTH-1:0]    addr_a,
    input  wire [DATA_WIDTH-1:0]    din_a,
    output reg  [DATA_WIDTH-1:0]    dout_a,
    
    // Port B
    input  wire                     we_b,
    input  wire [ADDR_WIDTH-1:0]    addr_b,
    input  wire [DATA_WIDTH-1:0]    din_b,
    output reg  [DATA_WIDTH-1:0]    dout_b
);
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    
    integer i;
    initial begin
        for (i = 0; i < DEPTH; i = i + 1) begin
            mem[i] = {DATA_WIDTH{1'b0}};
        end
    end
    
    // Port A operations
    always @(posedge clk) begin
        if (we_a) begin
            mem[addr_a] <= din_a;
        end
        dout_a <= mem[addr_a];
    end
    
    // Port B operations
    always @(posedge clk) begin
        if (we_b) begin
            mem[addr_b] <= din_b;
        end
        dout_b <= mem[addr_b];
    end
    
    // Conflict resolution:
    // If both ports write to same address, port B wins (last write)
    // If one writes and other reads same address, behavior is undefined
endmodule

// Dual-Port RAM with Separate Clocks
module dp_ram_dual_clock #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 10,
    parameter DEPTH = 1024
) (
    // Port A (write port)
    input  wire                     clk_a,
    input  wire                     we_a,
    input  wire [ADDR_WIDTH-1:0]    addr_a,
    input  wire [DATA_WIDTH-1:0]    din_a,
    
    // Port B (read port)
    input  wire                     clk_b,
    input  wire [ADDR_WIDTH-1:0]    addr_b,
    output reg  [DATA_WIDTH-1:0]    dout_b
);
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    
    integer i;
    initial begin
        for (i = 0; i < DEPTH; i = i + 1) begin
            mem[i] = {DATA_WIDTH{1'b0}};
        end
    end
    
    // Write on clock A
    always @(posedge clk_a) begin
        if (we_a) begin
            mem[addr_a] <= din_a;
        end
    end
    
    // Read on clock B
    always @(posedge clk_b) begin
        dout_b <= mem[addr_b];
    end
    
    // Useful for clock domain crossing with proper synchronization
endmodule

// Dual-Port RAM with Collision Detection
module dp_ram_collision #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 10,
    parameter DEPTH = 1024
) (
    input  wire                     clk,
    
    // Port A
    input  wire                     we_a,
    input  wire [ADDR_WIDTH-1:0]    addr_a,
    input  wire [DATA_WIDTH-1:0]    din_a,
    output reg  [DATA_WIDTH-1:0]    dout_a,
    
    // Port B
    input  wire                     we_b,
    input  wire [ADDR_WIDTH-1:0]    addr_b,
    input  wire [DATA_WIDTH-1:0]    din_b,
    output reg  [DATA_WIDTH-1:0]    dout_b,
    
    // Collision detection
    output reg                      collision
);
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    
    integer i;
    initial begin
        for (i = 0; i < DEPTH; i = i + 1) begin
            mem[i] = {DATA_WIDTH{1'b0}};
        end
    end
    
    // Detect collision (both ports accessing same address)
    always @(posedge clk) begin
        collision <= (addr_a == addr_b) && (we_a || we_b);
    end
    
    // Port A
    always @(posedge clk) begin
        if (we_a) begin
            mem[addr_a] <= din_a;
        end
        dout_a <= mem[addr_a];
    end
    
    // Port B
    always @(posedge clk) begin
        if (we_b) begin
            mem[addr_b] <= din_b;
        end
        dout_b <= mem[addr_b];
    end
endmodule

// Dual-Port RAM with Read-During-Write Forwarding
module dp_ram_forwarding #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 10,
    parameter DEPTH = 1024
) (
    input  wire                     clk,
    
    // Write port
    input  wire                     we,
    input  wire [ADDR_WIDTH-1:0]    waddr,
    input  wire [DATA_WIDTH-1:0]    din,
    
    // Read port
    input  wire [ADDR_WIDTH-1:0]    raddr,
    output reg  [DATA_WIDTH-1:0]    dout
);
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    reg [DATA_WIDTH-1:0] mem_read;
    
    integer i;
    initial begin
        for (i = 0; i < DEPTH; i = i + 1) begin
            mem[i] = {DATA_WIDTH{1'b0}};
        end
    end
    
    // Write operation
    always @(posedge clk) begin
        if (we) begin
            mem[waddr] <= din;
        end
    end
    
    // Read operation with forwarding
    always @(posedge clk) begin
        mem_read <= mem[raddr];
    end
    
    // Forward write data if reading same address being written
    always @(*) begin
        if (we && (raddr == waddr)) begin
            dout = din;  // Forward write data
        end else begin
            dout = mem_read;
        end
    end
endmodule

// =============================================================================
// Usage Examples:
// =============================================================================
//
// Example 1: Register file implementation
//   simple_dp_ram #(
//       .DATA_WIDTH(32),
//       .ADDR_WIDTH(4),   // 16 registers
//       .DEPTH(16)
//   ) regfile_mem (
//       .clk(clk),
//       .we(reg_write),
//       .waddr(write_reg),
//       .din(write_data),
//       .raddr(read_reg),
//       .dout(read_data)
//   );
//
// Example 2: Dual-port cache memory
//   true_dp_ram #(
//       .DATA_WIDTH(32),
//       .ADDR_WIDTH(8),
//       .DEPTH(256)
//   ) cache_data (
//       .clk(clk),
//       .we_a(cache_write),
//       .addr_a(cache_addr),
//       .din_a(cache_din),
//       .dout_a(cache_dout),
//       .we_b(refill_write),
//       .addr_b(refill_addr),
//       .din_b(refill_data),
//       .dout_b()
//   );
//
// Example 3: FIFO buffer using dual-port RAM
//   simple_dp_ram #(
//       .DATA_WIDTH(8),
//       .ADDR_WIDTH(4),
//       .DEPTH(16)
//   ) fifo_mem (
//       .clk(clk),
//       .we(fifo_push),
//       .waddr(write_ptr),
//       .din(fifo_din),
//       .raddr(read_ptr),
//       .dout(fifo_dout)
//   );
//
// =============================================================================

