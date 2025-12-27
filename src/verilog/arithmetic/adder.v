// =============================================================================
// Adders and Arithmetic Units
// =============================================================================
// Description:
//   Implements various adder architectures including ripple-carry, carry-
//   lookahead, and full adders. These form the foundation of the ALU.
//
// Learning Points:
//   - Full adder logic and carry propagation
//   - Ripple-carry vs carry-lookahead tradeoffs
//   - Propagate and generate signals
//   - Overflow detection in two's complement arithmetic
//
// Author: ARM7 Computer System Project
// Date: 2025-11-03
// =============================================================================

// Half Adder - Adds two single bits
module half_adder (
    input  wire a,      // First input bit
    input  wire b,      // Second input bit
    output wire sum,    // Sum output
    output wire carry   // Carry output
);
    // Sum is XOR of inputs (1 when inputs differ)
    // Carry is AND of inputs (1 when both inputs are 1)
    assign sum = a ^ b;
    assign carry = a & b;
endmodule

// Full Adder - Adds three single bits (two inputs + carry-in)
module full_adder (
    input  wire a,       // First input bit
    input  wire b,       // Second input bit
    input  wire cin,     // Carry input
    output wire sum,     // Sum output
    output wire cout     // Carry output
);
    // Full adder can be built from two half adders
    // sum = a XOR b XOR cin
    // cout = (a AND b) OR (cin AND (a XOR b))
    
    wire sum_ab, carry_ab, carry_sum;
    
    // First half adder: add a and b
    half_adder ha1 (
        .a(a),
        .b(b),
        .sum(sum_ab),
        .carry(carry_ab)
    );
    
    // Second half adder: add result with carry-in
    half_adder ha2 (
        .a(sum_ab),
        .b(cin),
        .sum(sum),
        .carry(carry_sum)
    );
    
    // Carry out if either half adder generated a carry
    assign cout = carry_ab | carry_sum;
    
    // Alternative direct implementation:
    // assign sum = a ^ b ^ cin;
    // assign cout = (a & b) | (cin & (a ^ b));
endmodule

// Ripple-Carry Adder - Simple but slow for large widths
module ripple_carry_adder #(
    parameter WIDTH = 32
) (
    input  wire [WIDTH-1:0] a,      // First operand
    input  wire [WIDTH-1:0] b,      // Second operand
    input  wire             cin,    // Carry input
    output wire [WIDTH-1:0] sum,    // Sum output
    output wire             cout    // Carry output
);
    // Carry ripples from LSB to MSB
    // Delay = O(n) where n is the width
    // Simple but slow for large widths
    
    wire [WIDTH:0] carry;  // Carry chain
    
    assign carry[0] = cin;
    
    genvar i;
    generate
        for (i = 0; i < WIDTH; i = i + 1) begin : adder_chain
            full_adder fa (
                .a(a[i]),
                .b(b[i]),
                .cin(carry[i]),
                .sum(sum[i]),
                .cout(carry[i+1])
            );
        end
    endgenerate
    
    assign cout = carry[WIDTH];
endmodule

// 4-bit Carry-Lookahead Adder - Faster than ripple-carry
module cla_4bit (
    input  wire [3:0] a,
    input  wire [3:0] b,
    input  wire       cin,
    output wire [3:0] sum,
    output wire       cout,
    output wire       pg,    // Group propagate
    output wire       gg     // Group generate
);
    // Carry-lookahead uses propagate and generate signals
    // to compute all carries in parallel
    // Delay = O(log n) instead of O(n)
    
    wire [3:0] p, g;  // Propagate and generate for each bit
    wire [4:0] c;     // Carry chain
    
    assign c[0] = cin;
    
    // Compute propagate and generate for each bit
    // p[i] = a[i] XOR b[i]  (carry propagates through this bit)
    // g[i] = a[i] AND b[i]  (carry generated at this bit)
    assign p = a ^ b;
    assign g = a & b;
    
    // Compute carries using lookahead logic
    // c[i+1] = g[i] OR (p[i] AND c[i])
    assign c[1] = g[0] | (p[0] & c[0]);
    assign c[2] = g[1] | (p[1] & g[0]) | (p[1] & p[0] & c[0]);
    assign c[3] = g[2] | (p[2] & g[1]) | (p[2] & p[1] & g[0]) | 
                  (p[2] & p[1] & p[0] & c[0]);
    assign c[4] = g[3] | (p[3] & g[2]) | (p[3] & p[2] & g[1]) | 
                  (p[3] & p[2] & p[1] & g[0]) | (p[3] & p[2] & p[1] & p[0] & c[0]);
    
    // Sum is propagate XOR carry-in
    assign sum = p ^ c[3:0];
    assign cout = c[4];
    
    // Group propagate and generate for hierarchical CLA
    assign pg = &p;  // All bits propagate
    assign gg = g[3] | (p[3] & g[2]) | (p[3] & p[2] & g[1]) | 
                (p[3] & p[2] & p[1] & g[0]);
endmodule

// 16-bit Carry-Lookahead Adder - Hierarchical design
module cla_16bit (
    input  wire [15:0] a,
    input  wire [15:0] b,
    input  wire        cin,
    output wire [15:0] sum,
    output wire        cout
);
    // Build 16-bit CLA from four 4-bit CLAs
    // Uses group propagate/generate for second level lookahead
    
    wire [3:0] pg, gg;  // Group propagate and generate
    wire [4:0] gc;      // Group carry chain
    
    assign gc[0] = cin;
    
    // Instantiate four 4-bit CLAs
    genvar i;
    generate
        for (i = 0; i < 4; i = i + 1) begin : cla_blocks
            cla_4bit cla (
                .a(a[i*4 +: 4]),
                .b(b[i*4 +: 4]),
                .cin(gc[i]),
                .sum(sum[i*4 +: 4]),
                .cout(),  // Not used, we use group carry instead
                .pg(pg[i]),
                .gg(gg[i])
            );
        end
    endgenerate
    
    // Second-level carry lookahead
    assign gc[1] = gg[0] | (pg[0] & gc[0]);
    assign gc[2] = gg[1] | (pg[1] & gg[0]) | (pg[1] & pg[0] & gc[0]);
    assign gc[3] = gg[2] | (pg[2] & gg[1]) | (pg[2] & pg[1] & gg[0]) | 
                   (pg[2] & pg[1] & pg[0] & gc[0]);
    assign gc[4] = gg[3] | (pg[3] & gg[2]) | (pg[3] & pg[2] & gg[1]) | 
                   (pg[3] & pg[2] & pg[1] & gg[0]) | 
                   (pg[3] & pg[2] & pg[1] & pg[0] & gc[0]);
    
    assign cout = gc[4];
endmodule

// 32-bit Adder - Uses carry-lookahead for speed
module adder_32bit (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire        cin,
    output wire [31:0] sum,
    output wire        cout,
    output wire        overflow  // Signed overflow flag
);
    // Build from two 16-bit CLAs
    wire carry_mid;
    
    cla_16bit cla_low (
        .a(a[15:0]),
        .b(b[15:0]),
        .cin(cin),
        .sum(sum[15:0]),
        .cout(carry_mid)
    );
    
    cla_16bit cla_high (
        .a(a[31:16]),
        .b(b[31:16]),
        .cin(carry_mid),
        .sum(sum[31:16]),
        .cout(cout)
    );
    
    // Overflow detection for signed arithmetic
    // Overflow occurs when:
    // - Adding two positive numbers gives negative result, OR
    // - Adding two negative numbers gives positive result
    // This happens when carry into MSB != carry out of MSB
    wire carry_into_msb = carry_mid;
    assign overflow = carry_into_msb ^ cout;
endmodule

// Subtractor - Performs a - b using two's complement
module subtractor #(
    parameter WIDTH = 32
) (
    input  wire [WIDTH-1:0] a,
    input  wire [WIDTH-1:0] b,
    output wire [WIDTH-1:0] diff,
    output wire             borrow,
    output wire             overflow
);
    // Subtraction: a - b = a + (~b) + 1 (two's complement)
    // Invert b and set carry-in to 1
    
    wire [WIDTH-1:0] b_inv;
    wire cout;
    
    assign b_inv = ~b;
    
    // Use adder with inverted b and cin=1
    generate
        if (WIDTH == 32) begin
            adder_32bit sub_adder (
                .a(a),
                .b(b_inv),
                .cin(1'b1),
                .sum(diff),
                .cout(cout),
                .overflow(overflow)
            );
        end else begin
            ripple_carry_adder #(.WIDTH(WIDTH)) sub_adder (
                .a(a),
                .b(b_inv),
                .cin(1'b1),
                .sum(diff),
                .cout(cout)
            );
            assign overflow = 1'b0;  // Simplified for non-32-bit
        end
    endgenerate
    
    // Borrow is inverse of carry out
    assign borrow = ~cout;
endmodule

// =============================================================================
// Usage Examples:
// =============================================================================
//
// Example 1: Simple 32-bit addition
//   adder_32bit alu_adder (
//       .a(operand_a),
//       .b(operand_b),
//       .cin(1'b0),
//       .sum(result),
//       .cout(carry_flag),
//       .overflow(overflow_flag)
//   );
//
// Example 2: Subtraction
//   subtractor #(.WIDTH(32)) alu_sub (
//       .a(operand_a),
//       .b(operand_b),
//       .diff(result),
//       .borrow(borrow_flag),
//       .overflow(overflow_flag)
//   );
//
// =============================================================================

