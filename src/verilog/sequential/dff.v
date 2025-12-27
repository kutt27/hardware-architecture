// =============================================================================
// Flip-Flops and Basic Sequential Elements
// =============================================================================
// Description:
//   Implements D flip-flops with various reset and enable configurations.
//   These are the fundamental memory elements in synchronous digital design.
//
// Learning Points:
//   - Clock edge sensitivity (posedge/negedge)
//   - Asynchronous vs synchronous reset
//   - Enable signals for conditional updates
//   - Setup and hold time concepts
//
// Author: ARM7 Computer System Project
// Date: 2025-11-03
// =============================================================================

// D Flip-Flop with Asynchronous Reset
module dff_async_reset (
    input  wire clk,      // Clock signal
    input  wire rst_n,    // Active-low asynchronous reset
    input  wire d,        // Data input
    output reg  q         // Data output
);
    // Asynchronous reset: reset takes effect immediately, regardless of clock
    // Used when reset must be guaranteed to work even if clock is not running
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            q <= 1'b0;  // Reset to 0
        end else begin
            q <= d;     // Capture input on clock edge
        end
    end
endmodule

// D Flip-Flop with Synchronous Reset
module dff_sync_reset (
    input  wire clk,
    input  wire rst,      // Active-high synchronous reset
    input  wire d,
    output reg  q
);
    // Synchronous reset: reset only takes effect on clock edge
    // Preferred in most designs for better timing and testability
    
    always @(posedge clk) begin
        if (rst) begin
            q <= 1'b0;
        end else begin
            q <= d;
        end
    end
endmodule

// D Flip-Flop with Enable
module dff_enable (
    input  wire clk,
    input  wire rst_n,
    input  wire en,       // Enable signal
    input  wire d,
    output reg  q
);
    // Enable signal controls when flip-flop captures new data
    // When en=0, flip-flop holds its current value
    // Useful for conditional updates and clock gating
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            q <= 1'b0;
        end else if (en) begin
            q <= d;  // Only update when enabled
        end
        // else: hold current value
    end
endmodule

// D Flip-Flop with Set and Reset
module dff_set_reset (
    input  wire clk,
    input  wire rst_n,    // Asynchronous reset (priority)
    input  wire set_n,    // Asynchronous set
    input  wire d,
    output reg  q
);
    // Both set and reset are asynchronous
    // Reset has priority over set
    
    always @(posedge clk or negedge rst_n or negedge set_n) begin
        if (!rst_n) begin
            q <= 1'b0;  // Reset has highest priority
        end else if (!set_n) begin
            q <= 1'b1;  // Set to 1
        end else begin
            q <= d;
        end
    end
endmodule

// Parameterized Register - Multi-bit D flip-flop
module register #(
    parameter WIDTH = 32
) (
    input  wire             clk,
    input  wire             rst_n,
    input  wire             en,
    input  wire [WIDTH-1:0] d,
    output reg  [WIDTH-1:0] q
);
    // Multi-bit register with enable
    // All bits update simultaneously on clock edge
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            q <= {WIDTH{1'b0}};
        end else if (en) begin
            q <= d;
        end
    end
endmodule

// Register with Load Value
module register_load #(
    parameter WIDTH = 32,
    parameter RESET_VALUE = 32'h0
) (
    input  wire             clk,
    input  wire             rst_n,
    input  wire             en,
    input  wire [WIDTH-1:0] d,
    output reg  [WIDTH-1:0] q
);
    // Register with configurable reset value
    // Useful for PC (reset to entry point), SP (reset to stack top), etc.
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            q <= RESET_VALUE;
        end else if (en) begin
            q <= d;
        end
    end
endmodule

// Shift Register - Serial-in, parallel-out
module shift_register #(
    parameter WIDTH = 8
) (
    input  wire             clk,
    input  wire             rst_n,
    input  wire             en,
    input  wire             serial_in,   // Serial data input
    output wire [WIDTH-1:0] parallel_out // Parallel data output
);
    reg [WIDTH-1:0] shift_reg;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg <= {WIDTH{1'b0}};
        end else if (en) begin
            // Shift left, insert new bit at LSB
            shift_reg <= {shift_reg[WIDTH-2:0], serial_in};
        end
    end
    
    assign parallel_out = shift_reg;
endmodule

// Shift Register - Parallel-in, serial-out
module shift_register_piso #(
    parameter WIDTH = 8
) (
    input  wire             clk,
    input  wire             rst_n,
    input  wire             load,        // Load parallel data
    input  wire             shift,       // Shift enable
    input  wire [WIDTH-1:0] parallel_in,
    output wire             serial_out
);
    reg [WIDTH-1:0] shift_reg;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            shift_reg <= {WIDTH{1'b0}};
        end else if (load) begin
            shift_reg <= parallel_in;  // Load parallel data
        end else if (shift) begin
            shift_reg <= {shift_reg[WIDTH-2:0], 1'b0};  // Shift left
        end
    end
    
    assign serial_out = shift_reg[WIDTH-1];  // Output MSB
endmodule

// Universal Shift Register - Left, right, parallel load
module shift_register_universal #(
    parameter WIDTH = 8
) (
    input  wire             clk,
    input  wire             rst_n,
    input  wire [1:0]       mode,        // 00=hold, 01=left, 10=right, 11=load
    input  wire             serial_in_l, // Serial input for left shift
    input  wire             serial_in_r, // Serial input for right shift
    input  wire [WIDTH-1:0] parallel_in,
    output reg  [WIDTH-1:0] q
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            q <= {WIDTH{1'b0}};
        end else begin
            case (mode)
                2'b00: q <= q;  // Hold
                2'b01: q <= {q[WIDTH-2:0], serial_in_l};  // Shift left
                2'b10: q <= {serial_in_r, q[WIDTH-1:1]};  // Shift right
                2'b11: q <= parallel_in;  // Parallel load
            endcase
        end
    end
endmodule

// Edge Detector - Detects rising/falling edges
module edge_detector (
    input  wire clk,
    input  wire rst_n,
    input  wire signal,
    output wire rising_edge,
    output wire falling_edge,
    output wire any_edge
);
    reg signal_d;  // Delayed version of signal
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            signal_d <= 1'b0;
        end else begin
            signal_d <= signal;
        end
    end
    
    // Rising edge: signal=1 and signal_d=0
    assign rising_edge = signal & ~signal_d;
    
    // Falling edge: signal=0 and signal_d=1
    assign falling_edge = ~signal & signal_d;
    
    // Any edge
    assign any_edge = rising_edge | falling_edge;
endmodule

// =============================================================================
// Usage Examples:
// =============================================================================
//
// Example 1: Program Counter register
//   register_load #(
//       .WIDTH(32),
//       .RESET_VALUE(32'h00000000)  // Reset to address 0
//   ) pc_reg (
//       .clk(clk),
//       .rst_n(rst_n),
//       .en(pc_enable),
//       .d(pc_next),
//       .q(pc_current)
//   );
//
// Example 2: Pipeline register
//   register #(.WIDTH(64)) pipeline_reg (
//       .clk(clk),
//       .rst_n(rst_n),
//       .en(~stall),  // Don't update when stalled
//       .d(stage_input),
//       .q(stage_output)
//   );
//
// Example 3: Button debouncer using edge detector
//   edge_detector button_edge (
//       .clk(clk),
//       .rst_n(rst_n),
//       .signal(button_debounced),
//       .rising_edge(button_pressed),
//       .falling_edge(button_released),
//       .any_edge()
//   );
//
// =============================================================================

