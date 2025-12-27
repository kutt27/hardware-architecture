// =============================================================================
// Basic Logic Gates - Fundamental Building Blocks
// =============================================================================
// Description:
//   This module implements fundamental logic gates (AND, OR, NOT, NAND, NOR, 
//   XOR, XNOR) with parameterized bit-widths. These are the atomic building 
//   blocks of all digital circuits.
//
// Learning Points:
//   - Verilog module syntax and parameters
//   - Continuous assignment with 'assign'
//   - Bitwise operators (&, |, ~, ^)
//   - Parameterized designs for reusability
//
// Author: ARM7 Computer System Project
// Date: 2025-11-03
// =============================================================================

// AND Gate - Output is 1 only when all inputs are 1
module and_gate #(
    parameter WIDTH = 1  // Bit-width of inputs/outputs
) (
    input  wire [WIDTH-1:0] a,    // First input
    input  wire [WIDTH-1:0] b,    // Second input
    output wire [WIDTH-1:0] y     // Output: a AND b
);
    // Bitwise AND operation
    // For each bit position i: y[i] = a[i] & b[i]
    assign y = a & b;
endmodule

// OR Gate - Output is 1 when at least one input is 1
module or_gate #(
    parameter WIDTH = 1
) (
    input  wire [WIDTH-1:0] a,
    input  wire [WIDTH-1:0] b,
    output wire [WIDTH-1:0] y     // Output: a OR b
);
    // Bitwise OR operation
    assign y = a | b;
endmodule

// NOT Gate (Inverter) - Output is the complement of input
module not_gate #(
    parameter WIDTH = 1
) (
    input  wire [WIDTH-1:0] a,
    output wire [WIDTH-1:0] y     // Output: NOT a
);
    // Bitwise NOT operation (inversion)
    assign y = ~a;
endmodule

// NAND Gate - NOT-AND, output is 0 only when all inputs are 1
module nand_gate #(
    parameter WIDTH = 1
) (
    input  wire [WIDTH-1:0] a,
    input  wire [WIDTH-1:0] b,
    output wire [WIDTH-1:0] y     // Output: NOT(a AND b)
);
    // NAND is universal gate - can build any logic function
    assign y = ~(a & b);
endmodule

// NOR Gate - NOT-OR, output is 1 only when all inputs are 0
module nor_gate #(
    parameter WIDTH = 1
) (
    input  wire [WIDTH-1:0] a,
    input  wire [WIDTH-1:0] b,
    output wire [WIDTH-1:0] y     // Output: NOT(a OR b)
);
    // NOR is also a universal gate
    assign y = ~(a | b);
endmodule

// XOR Gate - Exclusive OR, output is 1 when inputs differ
module xor_gate #(
    parameter WIDTH = 1
) (
    input  wire [WIDTH-1:0] a,
    input  wire [WIDTH-1:0] b,
    output wire [WIDTH-1:0] y     // Output: a XOR b
);
    // XOR is useful for parity, comparison, and arithmetic
    // Truth table: 0^0=0, 0^1=1, 1^0=1, 1^1=0
    assign y = a ^ b;
endmodule

// XNOR Gate - Exclusive NOR, output is 1 when inputs are equal
module xnor_gate #(
    parameter WIDTH = 1
) (
    input  wire [WIDTH-1:0] a,
    input  wire [WIDTH-1:0] b,
    output wire [WIDTH-1:0] y     // Output: NOT(a XOR b)
);
    // XNOR is an equality detector
    // Truth table: 0~^0=1, 0~^1=0, 1~^0=0, 1~^1=1
    assign y = ~(a ^ b);
endmodule

// Multi-input AND Gate - Output is 1 only when all inputs are 1
module and_n #(
    parameter WIDTH = 1,      // Bit-width of each input
    parameter NUM_INPUTS = 4  // Number of inputs
) (
    input  wire [NUM_INPUTS-1:0][WIDTH-1:0] inputs,  // Array of inputs
    output wire [WIDTH-1:0] y                         // Output
);
    // Reduction AND across all inputs
    // This demonstrates how to handle variable number of inputs
    wire [WIDTH-1:0] result [NUM_INPUTS-1:0];
    
    assign result[0] = inputs[0];
    
    genvar i;
    generate
        for (i = 1; i < NUM_INPUTS; i = i + 1) begin : and_chain
            assign result[i] = result[i-1] & inputs[i];
        end
    endgenerate
    
    assign y = result[NUM_INPUTS-1];
endmodule

// Multi-input OR Gate - Output is 1 when at least one input is 1
module or_n #(
    parameter WIDTH = 1,
    parameter NUM_INPUTS = 4
) (
    input  wire [NUM_INPUTS-1:0][WIDTH-1:0] inputs,
    output wire [WIDTH-1:0] y
);
    wire [WIDTH-1:0] result [NUM_INPUTS-1:0];
    
    assign result[0] = inputs[0];
    
    genvar i;
    generate
        for (i = 1; i < NUM_INPUTS; i = i + 1) begin : or_chain
            assign result[i] = result[i-1] | inputs[i];
        end
    endgenerate
    
    assign y = result[NUM_INPUTS-1];
endmodule

// Buffer - Passes input to output (useful for signal isolation)
module buffer #(
    parameter WIDTH = 1
) (
    input  wire [WIDTH-1:0] a,
    output wire [WIDTH-1:0] y
);
    // Simple pass-through
    // In real hardware, buffers provide drive strength and isolation
    assign y = a;
endmodule

// Tri-state Buffer - Output can be high-impedance (Z)
module tri_buffer #(
    parameter WIDTH = 1
) (
    input  wire [WIDTH-1:0] a,      // Data input
    input  wire             enable, // Enable signal
    output wire [WIDTH-1:0] y       // Output (Z when disabled)
);
    // When enable=1, output = input
    // When enable=0, output = high-impedance (Z)
    // Tri-state buffers are used for shared buses
    assign y = enable ? a : {WIDTH{1'bz}};
endmodule

// =============================================================================
// Usage Examples:
// =============================================================================
// 
// Example 1: 8-bit AND gate
//   and_gate #(.WIDTH(8)) my_and (
//       .a(8'b10101010),
//       .b(8'b11001100),
//       .y(result)  // result = 8'b10001000
//   );
//
// Example 2: Single-bit XOR (useful for parity)
//   xor_gate #(.WIDTH(1)) parity_gen (
//       .a(bit1),
//       .b(bit2),
//       .y(parity)
//   );
//
// Example 3: 4-input AND gate
//   and_n #(.WIDTH(1), .NUM_INPUTS(4)) multi_and (
//       .inputs({in0, in1, in2, in3}),
//       .y(all_high)
//   );
//
// =============================================================================

