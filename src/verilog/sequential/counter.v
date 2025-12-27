// =============================================================================
// Counters and Timers
// =============================================================================
// Description:
//   Implements various counter configurations (up, down, up/down, ring) and
//   programmable timers. Essential for timing, sequencing, and control.
//
// Learning Points:
//   - Counter design patterns
//   - Load, enable, and direction control
//   - Terminal count detection
//   - Timer and prescaler design
//
// Author: ARM7 Computer System Project
// Date: 2025-11-03
// =============================================================================

// Binary Up Counter
module counter_up #(
    parameter WIDTH = 8
) (
    input  wire             clk,
    input  wire             rst_n,
    input  wire             en,        // Count enable
    output reg  [WIDTH-1:0] count,
    output wire             tc         // Terminal count (max value reached)
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= {WIDTH{1'b0}};
        end else if (en) begin
            count <= count + 1'b1;
        end
    end
    
    // Terminal count when all bits are 1
    assign tc = &count;
endmodule

// Binary Down Counter
module counter_down #(
    parameter WIDTH = 8
) (
    input  wire             clk,
    input  wire             rst_n,
    input  wire             en,
    output reg  [WIDTH-1:0] count,
    output wire             tc         // Terminal count (zero reached)
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= {WIDTH{1'b1}};  // Start at max value
        end else if (en) begin
            count <= count - 1'b1;
        end
    end
    
    // Terminal count when all bits are 0
    assign tc = ~(|count);
endmodule

// Up/Down Counter with Load
module counter_updown #(
    parameter WIDTH = 8
) (
    input  wire             clk,
    input  wire             rst_n,
    input  wire             en,
    input  wire             up,        // 1=count up, 0=count down
    input  wire             load,      // Load enable
    input  wire [WIDTH-1:0] load_val,  // Value to load
    output reg  [WIDTH-1:0] count,
    output wire             tc_up,     // Terminal count up (max)
    output wire             tc_down    // Terminal count down (zero)
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= {WIDTH{1'b0}};
        end else if (load) begin
            count <= load_val;
        end else if (en) begin
            if (up) begin
                count <= count + 1'b1;
            end else begin
                count <= count - 1'b1;
            end
        end
    end
    
    assign tc_up = &count;
    assign tc_down = ~(|count);
endmodule

// Modulo-N Counter (counts from 0 to N-1, then wraps)
module counter_mod_n #(
    parameter WIDTH = 8,
    parameter MODULO = 100  // Count from 0 to MODULO-1
) (
    input  wire             clk,
    input  wire             rst_n,
    input  wire             en,
    output reg  [WIDTH-1:0] count,
    output wire             tc
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= {WIDTH{1'b0}};
        end else if (en) begin
            if (count == MODULO - 1) begin
                count <= {WIDTH{1'b0}};  // Wrap to 0
            end else begin
                count <= count + 1'b1;
            end
        end
    end
    
    assign tc = (count == MODULO - 1);
endmodule

// Ring Counter - One-hot counter
module ring_counter #(
    parameter WIDTH = 8
) (
    input  wire             clk,
    input  wire             rst_n,
    input  wire             en,
    output reg  [WIDTH-1:0] count
);
    // Ring counter has exactly one bit set, rotating through positions
    // Useful for state machines and sequential control
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= {{(WIDTH-1){1'b0}}, 1'b1};  // Initialize to 0...01
        end else if (en) begin
            // Rotate left
            count <= {count[WIDTH-2:0], count[WIDTH-1]};
        end
    end
endmodule

// Johnson Counter - Modified ring counter
module johnson_counter #(
    parameter WIDTH = 4
) (
    input  wire             clk,
    input  wire             rst_n,
    input  wire             en,
    output reg  [WIDTH-1:0] count
);
    // Johnson counter rotates complement of MSB into LSB
    // Generates 2*WIDTH unique states
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= {WIDTH{1'b0}};
        end else if (en) begin
            count <= {count[WIDTH-2:0], ~count[WIDTH-1]};
        end
    end
endmodule

// Programmable Timer
module timer #(
    parameter WIDTH = 32
) (
    input  wire             clk,
    input  wire             rst_n,
    input  wire             en,        // Timer enable
    input  wire             load,      // Load compare value
    input  wire [WIDTH-1:0] compare,   // Compare value
    output reg  [WIDTH-1:0] count,
    output wire             match,     // Count matches compare value
    output reg              overflow   // Timer overflow flag
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= {WIDTH{1'b0}};
            overflow <= 1'b0;
        end else if (load) begin
            count <= {WIDTH{1'b0}};
            overflow <= 1'b0;
        end else if (en) begin
            if (count == compare) begin
                count <= {WIDTH{1'b0}};  // Reset on match
                overflow <= 1'b1;
            end else begin
                count <= count + 1'b1;
                overflow <= 1'b0;
            end
        end
    end
    
    assign match = (count == compare);
endmodule

// Prescaler - Clock divider for generating slower clocks
module prescaler #(
    parameter WIDTH = 16,
    parameter DIVIDE = 1000  // Divide ratio
) (
    input  wire clk,
    input  wire rst_n,
    input  wire en,
    output reg  clk_out
);
    reg [WIDTH-1:0] count;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= {WIDTH{1'b0}};
            clk_out <= 1'b0;
        end else if (en) begin
            if (count == DIVIDE - 1) begin
                count <= {WIDTH{1'b0}};
                clk_out <= ~clk_out;  // Toggle output
            end else begin
                count <= count + 1'b1;
            end
        end
    end
endmodule

// Watchdog Timer - Resets system if not periodically refreshed
module watchdog_timer #(
    parameter WIDTH = 16,
    parameter TIMEOUT = 65535
) (
    input  wire clk,
    input  wire rst_n,
    input  wire en,
    input  wire refresh,    // Refresh/kick the watchdog
    output reg  timeout     // Timeout occurred
);
    reg [WIDTH-1:0] count;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            count <= {WIDTH{1'b0}};
            timeout <= 1'b0;
        end else if (refresh) begin
            count <= {WIDTH{1'b0}};  // Reset counter
            timeout <= 1'b0;
        end else if (en) begin
            if (count == TIMEOUT) begin
                timeout <= 1'b1;  // Timeout!
            end else begin
                count <= count + 1'b1;
            end
        end
    end
endmodule

// =============================================================================
// Usage Examples:
// =============================================================================
//
// Example 1: Program counter increment
//   counter_updown #(.WIDTH(32)) pc_counter (
//       .clk(clk),
//       .rst_n(rst_n),
//       .en(pc_increment),
//       .up(1'b1),
//       .load(branch_taken),
//       .load_val(branch_target),
//       .count(pc),
//       .tc_up(),
//       .tc_down()
//   );
//
// Example 2: Baud rate generator
//   prescaler #(
//       .WIDTH(16),
//       .DIVIDE(868)  // 50MHz / 868 / 16 = 3606 baud
//   ) baud_gen (
//       .clk(clk),
//       .rst_n(rst_n),
//       .en(1'b1),
//       .clk_out(baud_tick)
//   );
//
// Example 3: Interrupt timer
//   timer #(.WIDTH(32)) int_timer (
//       .clk(clk),
//       .rst_n(rst_n),
//       .en(timer_enable),
//       .load(timer_load),
//       .compare(timer_period),
//       .count(timer_count),
//       .match(timer_interrupt),
//       .overflow()
//   );
//
// =============================================================================

