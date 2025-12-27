// =============================================================================
// Arithmetic Logic Unit (ALU) - ARM7 CPU
// =============================================================================
// Description:
//   32-bit ALU implementing ARM7 data processing operations.
//   Performs arithmetic, logical, and shift operations with condition flags.
//
// Learning Points:
//   - ALU operation encoding
//   - Condition code flag generation (N, Z, C, V)
//   - Overflow and carry detection
//   - ARM7 instruction set operations
//
// Author: ARM7 Computer System Project
// Date: 2025-11-03
// =============================================================================

module alu #(
    parameter WIDTH = 32
) (
    // Inputs
    input  wire [WIDTH-1:0]     a,          // First operand
    input  wire [WIDTH-1:0]     b,          // Second operand
    input  wire [3:0]           alu_op,     // ALU operation select
    input  wire                 carry_in,   // Carry input for ADC/SBC
    
    // Outputs
    output reg  [WIDTH-1:0]     result,     // ALU result
    output reg                  carry_out,  // Carry output
    output reg                  overflow,   // Overflow flag
    output wire                 zero,       // Zero flag
    output wire                 negative    // Negative flag
);
    // ARM7 ALU Operation Encoding
    localparam OP_AND = 4'b0000;  // Logical AND
    localparam OP_EOR = 4'b0001;  // Logical XOR
    localparam OP_SUB = 4'b0010;  // Subtract
    localparam OP_RSB = 4'b0011;  // Reverse subtract
    localparam OP_ADD = 4'b0100;  // Add
    localparam OP_ADC = 4'b0101;  // Add with carry
    localparam OP_SBC = 4'b0110;  // Subtract with carry
    localparam OP_RSC = 4'b0111;  // Reverse subtract with carry
    localparam OP_TST = 4'b1000;  // Test (AND, update flags only)
    localparam OP_TEQ = 4'b1001;  // Test equivalence (XOR, flags only)
    localparam OP_CMP = 4'b1010;  // Compare (SUB, flags only)
    localparam OP_CMN = 4'b1011;  // Compare negative (ADD, flags only)
    localparam OP_ORR = 4'b1100;  // Logical OR
    localparam OP_MOV = 4'b1101;  // Move
    localparam OP_BIC = 4'b1110;  // Bit clear (AND NOT)
    localparam OP_MVN = 4'b1111;  // Move NOT
    
    // Internal signals
    wire [WIDTH:0] add_result;      // 33-bit for carry detection
    wire [WIDTH:0] sub_result;
    wire [WIDTH:0] adc_result;
    wire [WIDTH:0] sbc_result;
    
    // Addition with carry detection
    assign add_result = {1'b0, a} + {1'b0, b};
    assign adc_result = {1'b0, a} + {1'b0, b} + {{WIDTH{1'b0}}, carry_in};
    
    // Subtraction with borrow detection
    assign sub_result = {1'b0, a} - {1'b0, b};
    assign sbc_result = {1'b0, a} - {1'b0, b} - {{WIDTH{1'b0}}, ~carry_in};
    
    // ALU operation logic
    always @(*) begin
        // Default values
        result = {WIDTH{1'b0}};
        carry_out = 1'b0;
        overflow = 1'b0;
        
        case (alu_op)
            OP_AND, OP_TST: begin
                result = a & b;
                carry_out = 1'b0;
            end
            
            OP_EOR, OP_TEQ: begin
                result = a ^ b;
                carry_out = 1'b0;
            end
            
            OP_SUB, OP_CMP: begin
                result = sub_result[WIDTH-1:0];
                carry_out = ~sub_result[WIDTH];  // Borrow is inverted carry
                // Overflow: (a-b) overflows if signs differ and result sign != a sign
                overflow = (a[WIDTH-1] ^ b[WIDTH-1]) & (a[WIDTH-1] ^ result[WIDTH-1]);
            end
            
            OP_RSB: begin
                result = b - a;
                carry_out = (b >= a);
                overflow = (b[WIDTH-1] ^ a[WIDTH-1]) & (b[WIDTH-1] ^ result[WIDTH-1]);
            end
            
            OP_ADD, OP_CMN: begin
                result = add_result[WIDTH-1:0];
                carry_out = add_result[WIDTH];
                // Overflow: (a+b) overflows if signs same and result sign differs
                overflow = (~(a[WIDTH-1] ^ b[WIDTH-1])) & (a[WIDTH-1] ^ result[WIDTH-1]);
            end
            
            OP_ADC: begin
                result = adc_result[WIDTH-1:0];
                carry_out = adc_result[WIDTH];
                overflow = (~(a[WIDTH-1] ^ b[WIDTH-1])) & (a[WIDTH-1] ^ result[WIDTH-1]);
            end
            
            OP_SBC: begin
                result = sbc_result[WIDTH-1:0];
                carry_out = ~sbc_result[WIDTH];
                overflow = (a[WIDTH-1] ^ b[WIDTH-1]) & (a[WIDTH-1] ^ result[WIDTH-1]);
            end
            
            OP_RSC: begin
                result = b - a - ~carry_in;
                carry_out = (b >= (a + ~carry_in));
                overflow = (b[WIDTH-1] ^ a[WIDTH-1]) & (b[WIDTH-1] ^ result[WIDTH-1]);
            end
            
            OP_ORR: begin
                result = a | b;
                carry_out = 1'b0;
            end
            
            OP_MOV: begin
                result = b;
                carry_out = 1'b0;
            end
            
            OP_BIC: begin
                result = a & ~b;
                carry_out = 1'b0;
            end
            
            OP_MVN: begin
                result = ~b;
                carry_out = 1'b0;
            end
            
            default: begin
                result = {WIDTH{1'b0}};
                carry_out = 1'b0;
                overflow = 1'b0;
            end
        endcase
    end
    
    // Condition flags
    assign zero = (result == {WIDTH{1'b0}});
    assign negative = result[WIDTH-1];
    
endmodule

// ALU with Shifter Integration
module alu_with_shifter #(
    parameter WIDTH = 32
) (
    input  wire [WIDTH-1:0]     a,
    input  wire [WIDTH-1:0]     b,
    input  wire [3:0]           alu_op,
    input  wire                 carry_in,
    input  wire [1:0]           shift_type,  // 00=LSL, 01=LSR, 10=ASR, 11=ROR
    input  wire [4:0]           shift_amt,   // Shift amount (0-31)
    input  wire                 use_shifter, // Use shifted b
    
    output wire [WIDTH-1:0]     result,
    output wire                 carry_out,
    output wire                 overflow,
    output wire                 zero,
    output wire                 negative
);
    wire [WIDTH-1:0] b_shifted;
    wire shift_carry;
    
    // Instantiate barrel shifter
    barrel_shifter #(.WIDTH(WIDTH)) shifter (
        .data_in(b),
        .shift_type(shift_type),
        .shift_amt(shift_amt),
        .carry_in(carry_in),
        .data_out(b_shifted),
        .carry_out(shift_carry)
    );
    
    // Select shifted or unshifted b
    wire [WIDTH-1:0] b_operand;
    wire alu_carry_in;
    
    assign b_operand = use_shifter ? b_shifted : b;
    assign alu_carry_in = use_shifter ? shift_carry : carry_in;
    
    // Instantiate ALU
    alu #(.WIDTH(WIDTH)) alu_inst (
        .a(a),
        .b(b_operand),
        .alu_op(alu_op),
        .carry_in(alu_carry_in),
        .result(result),
        .carry_out(carry_out),
        .overflow(overflow),
        .zero(zero),
        .negative(negative)
    );
endmodule

// =============================================================================
// Usage Examples:
// =============================================================================
//
// Example 1: Simple ALU operation
//   alu #(.WIDTH(32)) cpu_alu (
//       .a(reg_a),
//       .b(reg_b),
//       .alu_op(OP_ADD),
//       .carry_in(1'b0),
//       .result(alu_result),
//       .carry_out(c_flag),
//       .overflow(v_flag),
//       .zero(z_flag),
//       .negative(n_flag)
//   );
//
// Example 2: ALU with barrel shifter for ARM instructions
//   alu_with_shifter #(.WIDTH(32)) cpu_alu_shift (
//       .a(operand_a),
//       .b(operand_b),
//       .alu_op(decoded_alu_op),
//       .carry_in(cpsr_c),
//       .shift_type(instr_shift_type),
//       .shift_amt(instr_shift_amt),
//       .use_shifter(instr_uses_shift),
//       .result(exec_result),
//       .carry_out(new_c_flag),
//       .overflow(new_v_flag),
//       .zero(new_z_flag),
//       .negative(new_n_flag)
//   );
//
// =============================================================================

