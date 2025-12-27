// =============================================================================
// Read-Only Memory (ROM)
// =============================================================================
// Description:
//   ROM implementations with various initialization methods.
//   Used for boot code, lookup tables, and constant data.
//
// Learning Points:
//   - ROM vs RAM architecture
//   - Memory initialization from files
//   - Lookup table implementation
//   - Boot ROM design
//
// Author: ARM7 Computer System Project
// Date: 2025-11-03
// =============================================================================

// Basic ROM with File Initialization
module rom #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 10,
    parameter DEPTH = 1024,
    parameter INIT_FILE = "boot_rom.hex"
) (
    input  wire                     clk,
    input  wire [ADDR_WIDTH-1:0]    addr,
    output reg  [DATA_WIDTH-1:0]    dout
);
    // ROM storage
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    
    // Initialize from file
    initial begin
        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, mem);
        end else begin
            // Default initialization to zero
            integer i;
            for (i = 0; i < DEPTH; i = i + 1) begin
                mem[i] = {DATA_WIDTH{1'b0}};
            end
        end
    end
    
    // Synchronous read
    always @(posedge clk) begin
        dout <= mem[addr];
    end
endmodule

// Asynchronous ROM (Combinational Read)
module rom_async #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 10,
    parameter DEPTH = 1024,
    parameter INIT_FILE = ""
) (
    input  wire [ADDR_WIDTH-1:0]    addr,
    output wire [DATA_WIDTH-1:0]    dout
);
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    
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
    
    // Asynchronous (combinational) read
    assign dout = mem[addr];
endmodule

// ROM with Hardcoded Values (Small Lookup Tables)
module rom_lut_sin #(
    parameter ADDR_WIDTH = 4  // 16 entries
) (
    input  wire [ADDR_WIDTH-1:0]    addr,
    output reg  [7:0]               dout
);
    // Sine lookup table (0 to 90 degrees in 16 steps)
    // Values scaled to 0-255
    always @(*) begin
        case (addr)
            4'h0: dout = 8'd0;
            4'h1: dout = 8'd25;
            4'h2: dout = 8'd49;
            4'h3: dout = 8'd71;
            4'h4: dout = 8'd90;
            4'h5: dout = 8'd106;
            4'h6: dout = 8'd118;
            4'h7: dout = 8'd127;
            4'h8: dout = 8'd133;
            4'h9: dout = 8'd135;
            4'hA: dout = 8'd135;
            4'hB: dout = 8'd133;
            4'hC: dout = 8'd127;
            4'hD: dout = 8'd118;
            4'hE: dout = 8'd106;
            4'hF: dout = 8'd90;
            default: dout = 8'd0;
        endcase
    end
endmodule

// Boot ROM with Reset Vector
module boot_rom #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 12,  // 4KB boot ROM
    parameter DEPTH = 4096,
    parameter INIT_FILE = "boot.hex",
    parameter RESET_VECTOR = 32'h00000000
) (
    input  wire                     clk,
    input  wire                     rst_n,
    input  wire [ADDR_WIDTH-1:0]    addr,
    output reg  [DATA_WIDTH-1:0]    dout
);
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    
    initial begin
        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, mem);
        end else begin
            // Default: place a branch to reset vector at address 0
            mem[0] = RESET_VECTOR;
            integer i;
            for (i = 1; i < DEPTH; i = i + 1) begin
                mem[i] = 32'hE1A00000;  // NOP instruction (MOV R0, R0)
            end
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dout <= mem[0];  // Output reset vector on reset
        end else begin
            dout <= mem[addr];
        end
    end
endmodule

// Character ROM for Display (Example)
module char_rom (
    input  wire [7:0]  char_code,   // ASCII character code
    input  wire [2:0]  row,          // Row within character (0-7)
    output reg  [7:0]  pixel_data    // 8 pixels for this row
);
    // Simple 8x8 character ROM for a few characters
    // In practice, this would be much larger
    
    always @(*) begin
        case ({char_code, row})
            // Character 'A' (0x41)
            {8'h41, 3'd0}: pixel_data = 8'b00111100;
            {8'h41, 3'd1}: pixel_data = 8'b01000010;
            {8'h41, 3'd2}: pixel_data = 8'b01000010;
            {8'h41, 3'd3}: pixel_data = 8'b01111110;
            {8'h41, 3'd4}: pixel_data = 8'b01000010;
            {8'h41, 3'd5}: pixel_data = 8'b01000010;
            {8'h41, 3'd6}: pixel_data = 8'b01000010;
            {8'h41, 3'd7}: pixel_data = 8'b00000000;
            
            // Character '0' (0x30)
            {8'h30, 3'd0}: pixel_data = 8'b00111100;
            {8'h30, 3'd1}: pixel_data = 8'b01000010;
            {8'h30, 3'd2}: pixel_data = 8'b01000110;
            {8'h30, 3'd3}: pixel_data = 8'b01001010;
            {8'h30, 3'd4}: pixel_data = 8'b01010010;
            {8'h30, 3'd5}: pixel_data = 8'b01100010;
            {8'h30, 3'd6}: pixel_data = 8'b00111100;
            {8'h30, 3'd7}: pixel_data = 8'b00000000;
            
            // Default: blank
            default: pixel_data = 8'b00000000;
        endcase
    end
endmodule

// Dual-Port ROM (for simultaneous instruction and data access)
module dp_rom #(
    parameter DATA_WIDTH = 32,
    parameter ADDR_WIDTH = 10,
    parameter DEPTH = 1024,
    parameter INIT_FILE = ""
) (
    input  wire                     clk,
    
    // Port A
    input  wire [ADDR_WIDTH-1:0]    addr_a,
    output reg  [DATA_WIDTH-1:0]    dout_a,
    
    // Port B
    input  wire [ADDR_WIDTH-1:0]    addr_b,
    output reg  [DATA_WIDTH-1:0]    dout_b
);
    reg [DATA_WIDTH-1:0] mem [0:DEPTH-1];
    
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
    
    // Independent read ports
    always @(posedge clk) begin
        dout_a <= mem[addr_a];
    end
    
    always @(posedge clk) begin
        dout_b <= mem[addr_b];
    end
endmodule

// =============================================================================
// Usage Examples:
// =============================================================================
//
// Example 1: Boot ROM for system initialization
//   boot_rom #(
//       .DATA_WIDTH(32),
//       .ADDR_WIDTH(12),
//       .DEPTH(4096),
//       .INIT_FILE("boot_code.hex"),
//       .RESET_VECTOR(32'h00000000)
//   ) boot_memory (
//       .clk(clk),
//       .rst_n(rst_n),
//       .addr(boot_addr[13:2]),
//       .dout(boot_instruction)
//   );
//
// Example 2: Lookup table for trigonometric functions
//   rom_lut_sin sin_table (
//       .addr(angle[3:0]),
//       .dout(sin_value)
//   );
//
// Example 3: Instruction ROM for simple processor
//   rom #(
//       .DATA_WIDTH(32),
//       .ADDR_WIDTH(10),
//       .DEPTH(1024),
//       .INIT_FILE("program.hex")
//   ) instruction_rom (
//       .clk(clk),
//       .addr(pc[11:2]),
//       .dout(instruction)
//   );
//
// =============================================================================

