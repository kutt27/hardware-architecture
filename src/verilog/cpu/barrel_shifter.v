// =============================================================================
// Barrel Shifter - ARM7 CPU
// =============================================================================
// Description:
//   32-bit barrel shifter implementing all ARM7 shift operations.
//   Performs multi-bit shifts in a single cycle using logarithmic design.
//
// Learning Points:
//   - Barrel shifter architecture
//   - Shift types: LSL, LSR, ASR, ROR, RRX
//   - Carry-out from shifts
//   - Logarithmic vs linear shifter design
//
// Author: ARM7 Computer System Project
// Date: 2025-11-03
// =============================================================================

module barrel_shifter #(
    parameter WIDTH = 32
) (
    input  wire [WIDTH-1:0]     data_in,     // Data to shift
    input  wire [1:0]           shift_type,  // Shift type
    input  wire [4:0]           shift_amt,   // Shift amount (0-31)
    input  wire                 carry_in,    // Carry input (for RRX)
    output reg  [WIDTH-1:0]     data_out,    // Shifted data
    output reg                  carry_out    // Carry output from shift
);
    // Shift type encoding
    localparam LSL = 2'b00;  // Logical shift left
    localparam LSR = 2'b01;  // Logical shift right
    localparam ASR = 2'b10;  // Arithmetic shift right (sign extend)
    localparam ROR = 2'b11;  // Rotate right
    
    // Internal signals for each shift type
    wire [WIDTH-1:0] lsl_result;
    wire [WIDTH-1:0] lsr_result;
    wire [WIDTH-1:0] asr_result;
    wire [WIDTH-1:0] ror_result;
    wire [WIDTH-1:0] rrx_result;
    
    wire lsl_carry, lsr_carry, asr_carry, ror_carry, rrx_carry;
    
    // Logical Shift Left (LSL)
    // Shifts left, fills with zeros
    assign lsl_result = (shift_amt == 0) ? data_in : (data_in << shift_amt);
    assign lsl_carry = (shift_amt == 0) ? carry_in : 
                       (shift_amt <= WIDTH) ? data_in[WIDTH - shift_amt] : 1'b0;
    
    // Logical Shift Right (LSR)
    // Shifts right, fills with zeros
    assign lsr_result = (shift_amt == 0) ? data_in : (data_in >> shift_amt);
    assign lsr_carry = (shift_amt == 0) ? carry_in :
                       (shift_amt <= WIDTH) ? data_in[shift_amt - 1] : 1'b0;
    
    // Arithmetic Shift Right (ASR)
    // Shifts right, fills with sign bit (preserves sign for signed numbers)
    assign asr_result = (shift_amt == 0) ? data_in :
                        (shift_amt >= WIDTH) ? {{WIDTH{data_in[WIDTH-1]}}} :
                        {{shift_amt{data_in[WIDTH-1]}}, data_in[WIDTH-1:shift_amt]};
    assign asr_carry = (shift_amt == 0) ? carry_in :
                       (shift_amt <= WIDTH) ? data_in[shift_amt - 1] : data_in[WIDTH-1];
    
    // Rotate Right (ROR)
    // Rotates bits to the right (bits shifted out appear on left)
    wire [4:0] ror_amt;
    assign ror_amt = shift_amt % WIDTH;  // Modulo WIDTH for rotation
    assign ror_result = (ror_amt == 0) ? data_in :
                        {data_in[ror_amt-1:0], data_in[WIDTH-1:ror_amt]};
    assign ror_carry = (shift_amt == 0) ? carry_in : data_in[ror_amt - 1];
    
    // Rotate Right Extended (RRX)
    // Rotates right by 1 bit through carry flag
    // [C, data_in] -> [data_in[0], C, data_in[31:1]]
    assign rrx_result = {carry_in, data_in[WIDTH-1:1]};
    assign rrx_carry = data_in[0];
    
    // Select output based on shift type
    always @(*) begin
        case (shift_type)
            LSL: begin
                data_out = lsl_result;
                carry_out = lsl_carry;
            end
            
            LSR: begin
                // Special case: LSR #0 is treated as LSR #32
                if (shift_amt == 5'b00000) begin
                    data_out = {WIDTH{1'b0}};
                    carry_out = data_in[WIDTH-1];
                end else begin
                    data_out = lsr_result;
                    carry_out = lsr_carry;
                end
            end
            
            ASR: begin
                // Special case: ASR #0 is treated as ASR #32
                if (shift_amt == 5'b00000) begin
                    data_out = {{WIDTH{data_in[WIDTH-1]}}};
                    carry_out = data_in[WIDTH-1];
                end else begin
                    data_out = asr_result;
                    carry_out = asr_carry;
                end
            end
            
            ROR: begin
                // Special case: ROR #0 is RRX (rotate through carry)
                if (shift_amt == 5'b00000) begin
                    data_out = rrx_result;
                    carry_out = rrx_carry;
                end else begin
                    data_out = ror_result;
                    carry_out = ror_carry;
                end
            end
            
            default: begin
                data_out = data_in;
                carry_out = carry_in;
            end
        endcase
    end
endmodule

// Logarithmic Barrel Shifter (More Efficient for Large Widths)
module barrel_shifter_log #(
    parameter WIDTH = 32
) (
    input  wire [WIDTH-1:0]     data_in,
    input  wire [1:0]           shift_type,
    input  wire [4:0]           shift_amt,
    input  wire                 carry_in,
    output wire [WIDTH-1:0]     data_out,
    output wire                 carry_out
);
    // Logarithmic shifter uses multiple stages
    // Each stage shifts by a power of 2 (1, 2, 4, 8, 16)
    // More efficient in hardware than direct shift
    
    wire [WIDTH-1:0] stage0, stage1, stage2, stage3, stage4;
    
    // Stage 0: shift by 1 if shift_amt[0] = 1
    assign stage0 = shift_amt[0] ? 
                    (shift_type == 2'b00 ? {data_in[WIDTH-2:0], 1'b0} :  // LSL
                     shift_type == 2'b01 ? {1'b0, data_in[WIDTH-1:1]} :  // LSR
                     shift_type == 2'b10 ? {data_in[WIDTH-1], data_in[WIDTH-1:1]} :  // ASR
                     {data_in[0], data_in[WIDTH-1:1]}) :  // ROR
                    data_in;
    
    // Stage 1: shift by 2 if shift_amt[1] = 1
    assign stage1 = shift_amt[1] ?
                    (shift_type == 2'b00 ? {stage0[WIDTH-3:0], 2'b00} :
                     shift_type == 2'b01 ? {2'b00, stage0[WIDTH-1:2]} :
                     shift_type == 2'b10 ? {{2{stage0[WIDTH-1]}}, stage0[WIDTH-1:2]} :
                     {stage0[1:0], stage0[WIDTH-1:2]}) :
                    stage0;
    
    // Stage 2: shift by 4 if shift_amt[2] = 1
    assign stage2 = shift_amt[2] ?
                    (shift_type == 2'b00 ? {stage1[WIDTH-5:0], 4'b0000} :
                     shift_type == 2'b01 ? {4'b0000, stage1[WIDTH-1:4]} :
                     shift_type == 2'b10 ? {{4{stage1[WIDTH-1]}}, stage1[WIDTH-1:4]} :
                     {stage1[3:0], stage1[WIDTH-1:4]}) :
                    stage1;
    
    // Stage 3: shift by 8 if shift_amt[3] = 1
    assign stage3 = shift_amt[3] ?
                    (shift_type == 2'b00 ? {stage2[WIDTH-9:0], 8'h00} :
                     shift_type == 2'b01 ? {8'h00, stage2[WIDTH-1:8]} :
                     shift_type == 2'b10 ? {{8{stage2[WIDTH-1]}}, stage2[WIDTH-1:8]} :
                     {stage2[7:0], stage2[WIDTH-1:8]}) :
                    stage2;
    
    // Stage 4: shift by 16 if shift_amt[4] = 1
    assign stage4 = shift_amt[4] ?
                    (shift_type == 2'b00 ? {stage3[WIDTH-17:0], 16'h0000} :
                     shift_type == 2'b01 ? {16'h0000, stage3[WIDTH-1:16]} :
                     shift_type == 2'b10 ? {{16{stage3[WIDTH-1]}}, stage3[WIDTH-1:16]} :
                     {stage3[15:0], stage3[WIDTH-1:16]}) :
                    stage3;
    
    assign data_out = stage4;
    
    // Simplified carry out (full implementation would track through stages)
    assign carry_out = carry_in;
endmodule

// =============================================================================
// Usage Examples:
// =============================================================================
//
// Example 1: Shift operand in ARM instruction
//   barrel_shifter #(.WIDTH(32)) operand_shifter (
//       .data_in(rm_value),
//       .shift_type(instr[6:5]),
//       .shift_amt(instr[11:7]),
//       .carry_in(cpsr_c),
//       .data_out(shifted_operand),
//       .carry_out(shift_carry)
//   );
//
// Example 2: Standalone shift instruction
//   barrel_shifter #(.WIDTH(32)) shift_unit (
//       .data_in(source_reg),
//       .shift_type(shift_op),
//       .shift_amt(shift_amount),
//       .carry_in(carry_flag),
//       .data_out(shift_result),
//       .carry_out(new_carry)
//   );
//
// =============================================================================

