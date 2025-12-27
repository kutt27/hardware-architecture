// =============================================================================
// Decoders and Encoders
// =============================================================================
// Description:
//   Implements binary decoders, encoders, and priority encoders. These are
//   essential for address decoding, instruction decoding, and interrupt
//   handling in computer systems.
//
// Learning Points:
//   - Binary to one-hot conversion (decoder)
//   - One-hot to binary conversion (encoder)
//   - Priority encoding for interrupt controllers
//   - Enable signals and output control
//
// Author: ARM7 Computer System Project
// Date: 2025-11-03
// =============================================================================

// 2-to-4 Decoder - Converts 2-bit binary to 4-bit one-hot
module decoder_2to4 (
    input  wire [1:0] in,      // 2-bit binary input
    input  wire       enable,  // Enable signal
    output reg  [3:0] out      // 4-bit one-hot output
);
    // Decoder truth table:
    // in=00 -> out=0001, in=01 -> out=0010
    // in=10 -> out=0100, in=11 -> out=1000
    // When enable=0, all outputs are 0
    
    always @(*) begin
        if (enable) begin
            case (in)
                2'b00: out = 4'b0001;
                2'b01: out = 4'b0010;
                2'b10: out = 4'b0100;
                2'b11: out = 4'b1000;
                default: out = 4'b0000;
            endcase
        end else begin
            out = 4'b0000;
        end
    end
endmodule

// 3-to-8 Decoder - Converts 3-bit binary to 8-bit one-hot
module decoder_3to8 (
    input  wire [2:0] in,
    input  wire       enable,
    output reg  [7:0] out
);
    always @(*) begin
        if (enable) begin
            case (in)
                3'b000: out = 8'b00000001;
                3'b001: out = 8'b00000010;
                3'b010: out = 8'b00000100;
                3'b011: out = 8'b00001000;
                3'b100: out = 8'b00010000;
                3'b101: out = 8'b00100000;
                3'b110: out = 8'b01000000;
                3'b111: out = 8'b10000000;
                default: out = 8'b00000000;
            endcase
        end else begin
            out = 8'b00000000;
        end
    end
endmodule

// Parameterized Decoder - N-bit input to 2^N-bit output
module decoder #(
    parameter N = 3  // Number of input bits
) (
    input  wire [N-1:0]         in,
    input  wire                 enable,
    output reg  [(1<<N)-1:0]    out    // 2^N output bits
);
    // 1<<N is equivalent to 2^N
    // For N=3, output is 8 bits; for N=4, output is 16 bits
    
    integer i;
    always @(*) begin
        out = {(1<<N){1'b0}};  // Initialize all outputs to 0
        if (enable) begin
            for (i = 0; i < (1<<N); i = i + 1) begin
                if (in == i) begin
                    out[i] = 1'b1;
                end
            end
        end
    end
endmodule

// 4-to-2 Encoder - Converts 4-bit one-hot to 2-bit binary
module encoder_4to2 (
    input  wire [3:0] in,      // 4-bit one-hot input
    output reg  [1:0] out,     // 2-bit binary output
    output reg        valid    // Valid output indicator
);
    // Encoder is the inverse of decoder
    // Assumes only one input bit is high (one-hot)
    // valid=0 if no bits or multiple bits are high
    
    always @(*) begin
        valid = 1'b1;
        case (in)
            4'b0001: out = 2'b00;
            4'b0010: out = 2'b01;
            4'b0100: out = 2'b10;
            4'b1000: out = 2'b11;
            default: begin
                out = 2'b00;
                valid = 1'b0;  // Invalid input
            end
        endcase
    end
endmodule

// 8-to-3 Encoder
module encoder_8to3 (
    input  wire [7:0] in,
    output reg  [2:0] out,
    output reg        valid
);
    always @(*) begin
        valid = 1'b1;
        case (in)
            8'b00000001: out = 3'b000;
            8'b00000010: out = 3'b001;
            8'b00000100: out = 3'b010;
            8'b00001000: out = 3'b011;
            8'b00010000: out = 3'b100;
            8'b00100000: out = 3'b101;
            8'b01000000: out = 3'b110;
            8'b10000000: out = 3'b111;
            default: begin
                out = 3'b000;
                valid = 1'b0;
            end
        endcase
    end
endmodule

// Priority Encoder - Encodes highest priority (MSB) active input
// Critical for interrupt controllers and arbitration
module priority_encoder_8to3 (
    input  wire [7:0] in,      // 8-bit input (bit 7 has highest priority)
    output reg  [2:0] out,     // 3-bit encoded output
    output reg        valid    // At least one input is active
);
    // Priority encoder finds the highest-priority (leftmost) '1' bit
    // Used in interrupt controllers to determine which interrupt to service
    
    always @(*) begin
        // Use casez to match with don't-care bits (?)
        casez (in)
            8'b1???????: begin out = 3'b111; valid = 1'b1; end  // Bit 7 highest priority
            8'b01??????: begin out = 3'b110; valid = 1'b1; end
            8'b001?????: begin out = 3'b101; valid = 1'b1; end
            8'b0001????: begin out = 3'b100; valid = 1'b1; end
            8'b00001???: begin out = 3'b011; valid = 1'b1; end
            8'b000001??: begin out = 3'b010; valid = 1'b1; end
            8'b0000001?: begin out = 3'b001; valid = 1'b1; end
            8'b00000001: begin out = 3'b000; valid = 1'b1; end
            default:     begin out = 3'b000; valid = 1'b0; end  // No active inputs
        endcase
    end
endmodule

// Parameterized Priority Encoder
module priority_encoder #(
    parameter WIDTH = 8  // Number of input bits
) (
    input  wire [WIDTH-1:0]           in,
    output reg  [$clog2(WIDTH)-1:0]   out,
    output reg                        valid
);
    // $clog2(WIDTH) gives the number of bits needed to encode WIDTH values
    
    integer i;
    always @(*) begin
        out = {$clog2(WIDTH){1'b0}};
        valid = 1'b0;
        
        // Scan from MSB to LSB (highest to lowest priority)
        for (i = WIDTH-1; i >= 0; i = i - 1) begin
            if (in[i]) begin
                out = i;
                valid = 1'b1;
            end
        end
    end
endmodule

// Leading Zero Counter - Counts leading zeros in a binary number
// Useful for normalization in floating-point units
module leading_zero_counter #(
    parameter WIDTH = 32
) (
    input  wire [WIDTH-1:0]           in,
    output reg  [$clog2(WIDTH):0]     count  // Can be 0 to WIDTH
);
    integer i;
    always @(*) begin
        count = WIDTH;  // Default: all zeros
        for (i = WIDTH-1; i >= 0; i = i - 1) begin
            if (in[i]) begin
                count = WIDTH - 1 - i;
            end
        end
    end
endmodule

// One-Hot Checker - Verifies that exactly one bit is set
module onehot_checker #(
    parameter WIDTH = 8
) (
    input  wire [WIDTH-1:0] in,
    output wire             is_onehot
);
    // A value is one-hot if it's non-zero and (value & (value-1)) == 0
    // This works because subtracting 1 flips all bits after the rightmost 1
    // Example: 0100 & 0011 = 0000 (one-hot)
    //          0110 & 0101 = 0100 (not one-hot)
    
    wire is_nonzero;
    wire [WIDTH-1:0] in_minus_1;
    
    assign is_nonzero = |in;  // Reduction OR
    assign in_minus_1 = in - 1'b1;
    assign is_onehot = is_nonzero && ((in & in_minus_1) == {WIDTH{1'b0}});
endmodule

// =============================================================================
// Usage Examples:
// =============================================================================
//
// Example 1: Address decoder for memory-mapped I/O
//   decoder_3to8 addr_decoder (
//       .in(address[2:0]),
//       .enable(io_select),
//       .out(peripheral_select)  // 8 peripherals
//   );
//
// Example 2: Priority encoder for interrupt controller
//   priority_encoder_8to3 int_priority (
//       .in(interrupt_requests),
//       .out(highest_priority_int),
//       .valid(interrupt_pending)
//   );
//
// Example 3: Register select decoder
//   decoder #(.N(4)) reg_decoder (
//       .in(reg_addr),
//       .enable(reg_write),
//       .out(reg_write_enable)  // 16 register write enables
//   );
//
// =============================================================================

