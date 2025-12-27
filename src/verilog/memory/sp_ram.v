// =============================================================================
// Single-Port RAM
// =============================================================================
// Description:
//   Synchronous single-port RAM with configurable width and depth.
//   One port for both read and write operations.
//
// Learning Points:
//   - Synchronous memory timing
//   - Read/write enable signals
//   - Memory initialization
//   - Inferred vs instantiated memory
//
// Author: ARM7 Computer System Project
// Date: 2025-11-03
// =============================================================================

module sp_ram #(
    parameter DATA_WIDTH = 32,      // Width of each memory word
    parameter ADDR_WIDTH = 10,      // Address width (2^10 = 1024 words)
    parameter DEPTH = 1024          // Number of memory locations
) (
    input  wire                     clk,
    input  wire                     rst_n,
    input  wire                     we,             // Write enable
    input  wire [ADDR_WIDTH-1:0]    addr,           // Address
    input  wire [DATA_WIDTH-1:0]    din,            // Data input
    output reg  [DATA_WIDTH-1:0]    dout            // Data output
);
    // Memory array
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    
    // Initialize memory to zero (for simulation)
    integer i;
    initial begin
        for (i = 0; i < DEPTH; i = i + 1) begin
            mem[i] = {DATA_WIDTH{1'b0}};
        end
    end
    
    // Synchronous read and write
    always @(posedge clk) begin
        if (we) begin
            mem[addr] <= din;  // Write operation
        end
        dout <= mem[addr];     // Read operation (always happens)
    end
    
    // Note: This implements "write-first" behavior
    // The newly written data appears on dout in the same cycle
    // For "read-first", move dout assignment before the if statement
endmodule

// Single-Port RAM with Byte Enable
module sp_ram_be #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 10,
    parameter DEPTH = 1024,
    parameter NUM_BYTES = 4         // Number of bytes per word
) (
    input  wire                     clk,
    input  wire [NUM_BYTES-1:0]     we,             // Byte write enables
    input  wire [ADDR_WIDTH-1:0]    addr,
    input  wire [DATA_WIDTH-1:0]    din,
    output reg  [DATA_WIDTH-1:0]    dout
);
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    
    integer i;
    initial begin
        for (i = 0; i < DEPTH; i = i + 1) begin
            mem[i] = {DATA_WIDTH{1'b0}};
        end
    end
    
    // Byte-wise write, word read
    always @(posedge clk) begin
        // Write individual bytes based on byte enables
        if (we[0]) mem[addr][7:0]   <= din[7:0];
        if (we[1]) mem[addr][15:8]  <= din[15:8];
        if (we[2]) mem[addr][23:16] <= din[23:16];
        if (we[3]) mem[addr][31:24] <= din[31:24];
        
        // Read entire word
        dout <= mem[addr];
    end
endmodule

// Single-Port RAM with Initialization from File
module sp_ram_init #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 10,
    parameter DEPTH = 1024,
    parameter INIT_FILE = "memory_init.hex"
) (
    input  wire                     clk,
    input  wire                     we,
    input  wire [ADDR_WIDTH-1:0]    addr,
    input  wire [DATA_WIDTH-1:0]    din,
    output reg  [DATA_WIDTH-1:0]    dout
);
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    
    // Initialize from file
    initial begin
        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, mem);
        end else begin
            integer i;
            for (i = 0; i < DEPTH; i = i + 1) begin
                mem[i] = {DATA_WIDTH{1'b0}};
            end
        end
    end
    
    always @(posedge clk) begin
        if (we) begin
            mem[addr] <= din;
        end
        dout <= mem[addr];
    end
endmodule

// Single-Port RAM with Separate Read Enable
module sp_ram_re #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 10,
    parameter DEPTH = 1024
) (
    input  wire                     clk,
    input  wire                     we,             // Write enable
    input  wire                     re,             // Read enable
    input  wire [ADDR_WIDTH-1:0]    addr,
    input  wire [DATA_WIDTH-1:0]    din,
    output reg  [DATA_WIDTH-1:0]    dout,
    output reg                      valid           // Data valid flag
);
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    
    integer i;
    initial begin
        for (i = 0; i < DEPTH; i = i + 1) begin
            mem[i] = {DATA_WIDTH{1'b0}};
        end
    end
    
    always @(posedge clk) begin
        valid <= 1'b0;
        
        if (we) begin
            mem[addr] <= din;
        end
        
        if (re) begin
            dout <= mem[addr];
            valid <= 1'b1;
        end
    end
endmodule

// Single-Port RAM with Output Register (Extra Pipeline Stage)
module sp_ram_pipelined #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 10,
    parameter DEPTH = 1024
) (
    input  wire                     clk,
    input  wire                     we,
    input  wire [ADDR_WIDTH-1:0]    addr,
    input  wire [DATA_WIDTH-1:0]    din,
    output reg  [DATA_WIDTH-1:0]    dout
);
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    reg [DATA_WIDTH-1:0] dout_reg;
    
    integer i;
    initial begin
        for (i = 0; i < DEPTH; i = i + 1) begin
            mem[i] = {DATA_WIDTH{1'b0}};
        end
    end
    
    // First stage: memory access
    always @(posedge clk) begin
        if (we) begin
            mem[addr] <= din;
        end
        dout_reg <= mem[addr];
    end
    
    // Second stage: output register
    always @(posedge clk) begin
        dout <= dout_reg;
    end
    
    // This adds one cycle of latency but can improve timing
endmodule

// =============================================================================
// Usage Examples:
// =============================================================================
//
// Example 1: Data memory for CPU
//   sp_ram #(
//       .DATA_WIDTH(32),
//       .ADDR_WIDTH(12),  // 4KB memory
//       .DEPTH(4096)
//   ) data_memory (
//       .clk(clk),
//       .rst_n(rst_n),
//       .we(mem_write),
//       .addr(mem_addr[13:2]),  // Word-aligned
//       .din(write_data),
//       .dout(read_data)
//   );
//
// Example 2: Instruction memory with initialization
//   sp_ram_init #(
//       .DATA_WIDTH(32),
//       .ADDR_WIDTH(10),
//       .DEPTH(1024),
//       .INIT_FILE("program.hex")
//   ) instruction_memory (
//       .clk(clk),
//       .we(1'b0),  // Read-only for instructions
//       .addr(pc[11:2]),
//       .din(32'h0),
//       .dout(instruction)
//   );
//
// Example 3: Memory with byte enables for partial writes
//   sp_ram_be #(
//       .DATA_WIDTH(32),
//       .ADDR_WIDTH(10),
//       .DEPTH(1024),
//       .NUM_BYTES(4)
//   ) byte_addressable_mem (
//       .clk(clk),
//       .we(byte_enables),  // 4-bit byte enable
//       .addr(addr[11:2]),
//       .din(write_data),
//       .dout(read_data)
//   );
//
// =============================================================================

