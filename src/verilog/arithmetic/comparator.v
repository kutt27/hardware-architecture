// =============================================================================
// Comparator - Magnitude and Equality Comparison
// =============================================================================
// Description:
//   Implements comparators for equality and magnitude comparison (signed and
//   unsigned). Essential for conditional branches and ALU operations.
//
// Learning Points:
//   - Equality vs magnitude comparison
//   - Signed vs unsigned comparison
//   - Efficient comparison using subtraction
//   - Condition code generation
//
// Author: ARM7 Computer System Project
// Date: 2025-11-03
// =============================================================================

// Equality Comparator - Checks if two values are equal
module comparator_eq #(
    parameter WIDTH = 32
) (
    input  wire [WIDTH-1:0] a,
    input  wire [WIDTH-1:0] b,
    output wire             eq,   // a == b
    output wire             ne    // a != b
);
    // Equality: all bits must match
    // Use XNOR for bit-wise equality, then AND all results
    wire [WIDTH-1:0] bit_eq;
    
    assign bit_eq = ~(a ^ b);  // XNOR: 1 when bits match
    assign eq = &bit_eq;       // Reduction AND: 1 when all bits match
    assign ne = ~eq;
endmodule

// Magnitude Comparator - Unsigned comparison
module comparator_unsigned #(
    parameter WIDTH = 32
) (
    input  wire [WIDTH-1:0] a,
    input  wire [WIDTH-1:0] b,
    output wire             eq,   // a == b
    output wire             ne,   // a != b
    output wire             lt,   // a < b (unsigned)
    output wire             le,   // a <= b (unsigned)
    output wire             gt,   // a > b (unsigned)
    output wire             ge    // a >= b (unsigned)
);
    // Use subtraction to determine relationship
    // If a - b generates borrow, then a < b
    wire [WIDTH-1:0] diff;
    wire borrow;
    
    // Subtract b from a
    assign {borrow, diff} = {1'b0, a} - {1'b0, b};
    
    // Equality check
    assign eq = (a == b);
    assign ne = ~eq;
    
    // Magnitude comparisons
    assign lt = borrow;           // a < b if subtraction borrows
    assign ge = ~borrow;          // a >= b if no borrow
    assign gt = ~borrow & ~eq;    // a > b if no borrow and not equal
    assign le = borrow | eq;      // a <= b if borrow or equal
endmodule

// Magnitude Comparator - Signed comparison
module comparator_signed #(
    parameter WIDTH = 32
) (
    input  wire [WIDTH-1:0] a,
    input  wire [WIDTH-1:0] b,
    output wire             eq,   // a == b
    output wire             ne,   // a != b
    output wire             lt,   // a < b (signed)
    output wire             le,   // a <= b (signed)
    output wire             gt,   // a > b (signed)
    output wire             ge    // a >= b (signed)
);
    // For signed comparison, need to consider sign bits
    // Use signed subtraction and check overflow
    
    wire [WIDTH-1:0] diff;
    wire borrow, overflow;
    wire sign_a, sign_b, sign_diff;
    
    // Extract sign bits (MSB)
    assign sign_a = a[WIDTH-1];
    assign sign_b = b[WIDTH-1];
    
    // Perform subtraction: a - b
    assign {borrow, diff} = {1'b0, a} - {1'b0, b};
    assign sign_diff = diff[WIDTH-1];
    
    // Overflow occurs when:
    // - Subtracting positive from negative gives positive (should be negative)
    // - Subtracting negative from positive gives negative (should be positive)
    assign overflow = (sign_a ^ sign_b) & (sign_a ^ sign_diff);
    
    // Equality
    assign eq = (a == b);
    assign ne = ~eq;
    
    // Signed less than: 
    // If overflow, result sign is wrong, so invert it
    // If no overflow, use result sign
    assign lt = overflow ? ~sign_diff : sign_diff;
    assign ge = ~lt;
    assign gt = ~lt & ~eq;
    assign le = lt | eq;
endmodule

// Combined Comparator - Both signed and unsigned
module comparator #(
    parameter WIDTH = 32
) (
    input  wire [WIDTH-1:0] a,
    input  wire [WIDTH-1:0] b,
    input  wire             is_signed,  // 1=signed, 0=unsigned comparison
    output wire             eq,
    output wire             ne,
    output wire             lt,
    output wire             le,
    output wire             gt,
    output wire             ge
);
    // Instantiate both signed and unsigned comparators
    wire eq_u, ne_u, lt_u, le_u, gt_u, ge_u;
    wire eq_s, ne_s, lt_s, le_s, gt_s, ge_s;
    
    comparator_unsigned #(.WIDTH(WIDTH)) cmp_u (
        .a(a), .b(b),
        .eq(eq_u), .ne(ne_u),
        .lt(lt_u), .le(le_u),
        .gt(gt_u), .ge(ge_u)
    );
    
    comparator_signed #(.WIDTH(WIDTH)) cmp_s (
        .a(a), .b(b),
        .eq(eq_s), .ne(ne_s),
        .lt(lt_s), .le(le_s),
        .gt(gt_s), .ge(ge_s)
    );
    
    // Select based on is_signed
    assign eq = is_signed ? eq_s : eq_u;
    assign ne = is_signed ? ne_s : ne_u;
    assign lt = is_signed ? lt_s : lt_u;
    assign le = is_signed ? le_s : le_u;
    assign gt = is_signed ? gt_s : gt_u;
    assign ge = is_signed ? ge_s : ge_u;
endmodule

// Min/Max Unit - Selects minimum or maximum of two values
module min_max #(
    parameter WIDTH = 32
) (
    input  wire [WIDTH-1:0] a,
    input  wire [WIDTH-1:0] b,
    input  wire             is_signed,
    output wire [WIDTH-1:0] min,
    output wire [WIDTH-1:0] max
);
    wire lt;
    
    // Use comparator to determine relationship
    comparator #(.WIDTH(WIDTH)) cmp (
        .a(a), .b(b),
        .is_signed(is_signed),
        .lt(lt),
        .eq(), .ne(), .le(), .gt(), .ge()
    );
    
    // Select min and max based on comparison
    assign min = lt ? a : b;
    assign max = lt ? b : a;
endmodule

// Zero Detector - Checks if value is zero
module zero_detector #(
    parameter WIDTH = 32
) (
    input  wire [WIDTH-1:0] value,
    output wire             is_zero,
    output wire             is_nonzero
);
    // Use reduction NOR for zero detection
    assign is_zero = ~(|value);  // NOR of all bits
    assign is_nonzero = |value;  // OR of all bits
endmodule

// =============================================================================
// Usage Examples:
// =============================================================================
//
// Example 1: Branch condition evaluation
//   comparator #(.WIDTH(32)) branch_cmp (
//       .a(reg_a),
//       .b(reg_b),
//       .is_signed(1'b1),
//       .eq(branch_eq),
//       .lt(branch_lt),
//       .le(branch_le),
//       .gt(branch_gt),
//       .ge(branch_ge),
//       .ne(branch_ne)
//   );
//
// Example 2: Zero flag generation
//   zero_detector #(.WIDTH(32)) zero_det (
//       .value(alu_result),
//       .is_zero(zero_flag),
//       .is_nonzero()
//   );
//
// Example 3: Min/max selection
//   min_max #(.WIDTH(32)) minmax (
//       .a(value1),
//       .b(value2),
//       .is_signed(1'b0),
//       .min(minimum),
//       .max(maximum)
//   );
//
// =============================================================================

