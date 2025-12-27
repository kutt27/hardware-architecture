// =============================================================================
// Multiplexers - Data Selectors
// =============================================================================
// Description:
//   Implements various multiplexer configurations (2:1, 4:1, 8:1) with
//   parameterized data widths. Multiplexers are fundamental for data routing
//   and selection in digital systems.
//
// Learning Points:
//   - Conditional operator (? :) for 2:1 mux
//   - Case statements for multi-way selection
//   - Parameterized module design
//   - Hierarchical design (building larger muxes from smaller ones)
//
// Author: ARM7 Computer System Project
// Date: 2025-11-03
// =============================================================================

// 2:1 Multiplexer - Selects between two inputs
module mux2 #(
    parameter WIDTH = 32  // Data width
) (
    input  wire [WIDTH-1:0] d0,   // Input 0
    input  wire [WIDTH-1:0] d1,   // Input 1
    input  wire             sel,  // Select signal (0=d0, 1=d1)
    output wire [WIDTH-1:0] y     // Output
);
    // Conditional operator: sel ? true_value : false_value
    // When sel=0, output d0; when sel=1, output d1
    assign y = sel ? d1 : d0;
    
    // Alternative implementation using case statement:
    // always @(*) begin
    //     case (sel)
    //         1'b0: y = d0;
    //         1'b1: y = d1;
    //     endcase
    // end
endmodule

// 4:1 Multiplexer - Selects one of four inputs
module mux4 #(
    parameter WIDTH = 32
) (
    input  wire [WIDTH-1:0] d0,      // Input 0
    input  wire [WIDTH-1:0] d1,      // Input 1
    input  wire [WIDTH-1:0] d2,      // Input 2
    input  wire [WIDTH-1:0] d3,      // Input 3
    input  wire [1:0]       sel,     // 2-bit select signal
    output reg  [WIDTH-1:0] y        // Output
);
    // Case statement for multi-way selection
    // sel=00 -> d0, sel=01 -> d1, sel=10 -> d2, sel=11 -> d3
    always @(*) begin
        case (sel)
            2'b00: y = d0;
            2'b01: y = d1;
            2'b10: y = d2;
            2'b11: y = d3;
            default: y = {WIDTH{1'bx}};  // X for undefined
        endcase
    end
endmodule

// 4:1 Multiplexer - Hierarchical implementation using 2:1 muxes
module mux4_hier #(
    parameter WIDTH = 32
) (
    input  wire [WIDTH-1:0] d0, d1, d2, d3,
    input  wire [1:0]       sel,
    output wire [WIDTH-1:0] y
);
    // Demonstrates hierarchical design
    // First level: select between (d0,d1) and (d2,d3)
    // Second level: select between the two first-level outputs
    
    wire [WIDTH-1:0] mux_low, mux_high;
    
    // Low mux: selects between d0 and d1
    mux2 #(.WIDTH(WIDTH)) mux_low_inst (
        .d0(d0), .d1(d1), .sel(sel[0]), .y(mux_low)
    );
    
    // High mux: selects between d2 and d3
    mux2 #(.WIDTH(WIDTH)) mux_high_inst (
        .d0(d2), .d1(d3), .sel(sel[0]), .y(mux_high)
    );
    
    // Final mux: selects between low and high results
    mux2 #(.WIDTH(WIDTH)) mux_final (
        .d0(mux_low), .d1(mux_high), .sel(sel[1]), .y(y)
    );
endmodule

// 8:1 Multiplexer - Selects one of eight inputs
module mux8 #(
    parameter WIDTH = 32
) (
    input  wire [WIDTH-1:0] d0, d1, d2, d3, d4, d5, d6, d7,
    input  wire [2:0]       sel,     // 3-bit select signal
    output reg  [WIDTH-1:0] y
);
    // 8-way selection using case statement
    always @(*) begin
        case (sel)
            3'b000: y = d0;
            3'b001: y = d1;
            3'b010: y = d2;
            3'b011: y = d3;
            3'b100: y = d4;
            3'b101: y = d5;
            3'b110: y = d6;
            3'b111: y = d7;
            default: y = {WIDTH{1'bx}};
        endcase
    end
endmodule

// Parameterized N:1 Multiplexer using generate
module mux_n #(
    parameter WIDTH = 32,      // Data width
    parameter N = 4            // Number of inputs (must be power of 2)
) (
    input  wire [N-1:0][WIDTH-1:0] d,    // Array of N inputs
    input  wire [$clog2(N)-1:0] sel,     // Select signal
    output reg  [WIDTH-1:0] y            // Output
);
    // $clog2(N) calculates ceiling(log2(N)) - number of select bits needed
    // For N=4, need 2 select bits; for N=8, need 3 select bits
    
    integer i;
    always @(*) begin
        y = {WIDTH{1'bx}};  // Default to X
        for (i = 0; i < N; i = i + 1) begin
            if (sel == i) begin
                y = d[i];
            end
        end
    end
endmodule

// One-Hot Multiplexer - Select signal is one-hot encoded
// More efficient when select is already one-hot (common in state machines)
module mux_onehot #(
    parameter WIDTH = 32,
    parameter N = 4
) (
    input  wire [N-1:0][WIDTH-1:0] d,      // Array of N inputs
    input  wire [N-1:0]            sel,    // One-hot select (only one bit set)
    output wire [WIDTH-1:0]        y       // Output
);
    // One-hot mux using OR reduction
    // If sel[i]=1, include d[i] in the OR; otherwise contribute 0
    // Since only one sel bit is high, only one input contributes
    
    wire [WIDTH-1:0] masked [N-1:0];
    
    genvar i;
    generate
        for (i = 0; i < N; i = i + 1) begin : mask_gen
            // Replicate sel[i] across all WIDTH bits and AND with d[i]
            assign masked[i] = {WIDTH{sel[i]}} & d[i];
        end
    endgenerate
    
    // OR all masked values together
    wire [WIDTH-1:0] or_tree [N-1:0];
    assign or_tree[0] = masked[0];
    
    generate
        for (i = 1; i < N; i = i + 1) begin : or_gen
            assign or_tree[i] = or_tree[i-1] | masked[i];
        end
    endgenerate
    
    assign y = or_tree[N-1];
endmodule

// Demultiplexer - Routes one input to one of N outputs
module demux_1to4 #(
    parameter WIDTH = 32
) (
    input  wire [WIDTH-1:0] d,       // Input data
    input  wire [1:0]       sel,     // Select which output gets the data
    output reg  [WIDTH-1:0] y0,      // Output 0
    output reg  [WIDTH-1:0] y1,      // Output 1
    output reg  [WIDTH-1:0] y2,      // Output 2
    output reg  [WIDTH-1:0] y3       // Output 3
);
    // Demux is the inverse of mux
    // Routes input to selected output, others get 0
    always @(*) begin
        y0 = {WIDTH{1'b0}};
        y1 = {WIDTH{1'b0}};
        y2 = {WIDTH{1'b0}};
        y3 = {WIDTH{1'b0}};
        
        case (sel)
            2'b00: y0 = d;
            2'b01: y1 = d;
            2'b10: y2 = d;
            2'b11: y3 = d;
        endcase
    end
endmodule

// =============================================================================
// Usage Examples:
// =============================================================================
//
// Example 1: Simple 2:1 mux for register write data
//   mux2 #(.WIDTH(32)) alu_result_mux (
//       .d0(alu_output),
//       .d1(memory_data),
//       .sel(mem_to_reg),
//       .y(write_data)
//   );
//
// Example 2: 4:1 mux for ALU source selection
//   mux4 #(.WIDTH(32)) alu_src_mux (
//       .d0(reg_data),
//       .d1(immediate),
//       .d2(pc_value),
//       .d3(32'h0),
//       .sel(alu_src_sel),
//       .y(alu_input)
//   );
//
// Example 3: One-hot mux for state machine outputs
//   mux_onehot #(.WIDTH(8), .N(4)) state_output_mux (
//       .d({state3_out, state2_out, state1_out, state0_out}),
//       .sel(current_state),  // One-hot encoded
//       .y(output_signals)
//   );
//
// =============================================================================

