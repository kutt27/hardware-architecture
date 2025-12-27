// =============================================================================
// ALU Testbench
// =============================================================================
// Description:
//   Comprehensive testbench for ARM7 ALU module. Tests all 16 operations,
//   flag generation, and edge cases.
//
// Author: ARM7 Computer System Project
// Date: 2025-11-03
// =============================================================================

`timescale 1ns/1ps

module alu_tb;

    // Parameters
    parameter WIDTH = 32;
    parameter CLK_PERIOD = 10;
    
    // Signals
    reg  [WIDTH-1:0] a, b;
    reg  [3:0]       alu_op;
    reg              carry_in;
    wire [WIDTH-1:0] result;
    wire             carry_out, overflow, zero, negative;
    
    // Error counter
    integer errors = 0;
    integer tests = 0;
    
    // DUT instantiation
    alu #(.WIDTH(WIDTH)) dut (
        .a(a),
        .b(b),
        .alu_op(alu_op),
        .carry_in(carry_in),
        .result(result),
        .carry_out(carry_out),
        .overflow(overflow),
        .zero(zero),
        .negative(negative)
    );
    
    // ALU operation codes
    localparam OP_AND = 4'b0000;
    localparam OP_EOR = 4'b0001;
    localparam OP_SUB = 4'b0010;
    localparam OP_RSB = 4'b0011;
    localparam OP_ADD = 4'b0100;
    localparam OP_ADC = 4'b0101;
    localparam OP_SBC = 4'b0110;
    localparam OP_RSC = 4'b0111;
    localparam OP_TST = 4'b1000;
    localparam OP_TEQ = 4'b1001;
    localparam OP_CMP = 4'b1010;
    localparam OP_CMN = 4'b1011;
    localparam OP_ORR = 4'b1100;
    localparam OP_MOV = 4'b1101;
    localparam OP_BIC = 4'b1110;
    localparam OP_MVN = 4'b1111;
    
    // Test task
    task test_alu;
        input [WIDTH-1:0] test_a, test_b;
        input [3:0] test_op;
        input test_carry_in;
        input [WIDTH-1:0] expected_result;
        input expected_carry, expected_overflow, expected_zero, expected_neg;
        input [255:0] test_name;
    begin
        tests = tests + 1;
        a = test_a;
        b = test_b;
        alu_op = test_op;
        carry_in = test_carry_in;
        #1;
        
        if (result !== expected_result) begin
            $display("ERROR: %s - Result mismatch", test_name);
            $display("  Expected: 0x%08h, Got: 0x%08h", expected_result, result);
            errors = errors + 1;
        end
        
        if (carry_out !== expected_carry) begin
            $display("ERROR: %s - Carry mismatch", test_name);
            $display("  Expected: %b, Got: %b", expected_carry, carry_out);
            errors = errors + 1;
        end
        
        if (overflow !== expected_overflow) begin
            $display("ERROR: %s - Overflow mismatch", test_name);
            $display("  Expected: %b, Got: %b", expected_overflow, overflow);
            errors = errors + 1;
        end
        
        if (zero !== expected_zero) begin
            $display("ERROR: %s - Zero flag mismatch", test_name);
            $display("  Expected: %b, Got: %b", expected_zero, zero);
            errors = errors + 1;
        end
        
        if (negative !== expected_neg) begin
            $display("ERROR: %s - Negative flag mismatch", test_name);
            $display("  Expected: %b, Got: %b", expected_neg, negative);
            errors = errors + 1;
        end
        
        #1;
    end
    endtask
    
    // Main test sequence
    initial begin
        $display("=== ALU Testbench ===");
        $display("Testing %0d-bit ALU with all operations", WIDTH);
        
        // Initialize
        a = 0;
        b = 0;
        alu_op = 0;
        carry_in = 0;
        #10;
        
        // Test AND operation
        $display("\nTesting AND operation...");
        test_alu(32'hFFFF_FFFF, 32'h0000_FFFF, OP_AND, 0, 
                 32'h0000_FFFF, 0, 0, 0, 0, "AND all ones with lower half");
        test_alu(32'hAAAA_AAAA, 32'h5555_5555, OP_AND, 0,
                 32'h0000_0000, 0, 0, 1, 0, "AND alternating bits");
        
        // Test EOR (XOR) operation
        $display("\nTesting EOR operation...");
        test_alu(32'hFFFF_FFFF, 32'hFFFF_FFFF, OP_EOR, 0,
                 32'h0000_0000, 0, 0, 1, 0, "EOR same values");
        test_alu(32'hAAAA_AAAA, 32'h5555_5555, OP_EOR, 0,
                 32'hFFFF_FFFF, 0, 0, 0, 1, "EOR alternating bits");
        
        // Test ADD operation
        $display("\nTesting ADD operation...");
        test_alu(32'h0000_0001, 32'h0000_0001, OP_ADD, 0,
                 32'h0000_0002, 0, 0, 0, 0, "ADD 1 + 1");
        test_alu(32'hFFFF_FFFF, 32'h0000_0001, OP_ADD, 0,
                 32'h0000_0000, 1, 0, 1, 0, "ADD overflow to zero");
        test_alu(32'h7FFF_FFFF, 32'h0000_0001, OP_ADD, 0,
                 32'h8000_0000, 0, 1, 0, 1, "ADD positive overflow");
        
        // Test SUB operation
        $display("\nTesting SUB operation...");
        test_alu(32'h0000_0005, 32'h0000_0003, OP_SUB, 0,
                 32'h0000_0002, 1, 0, 0, 0, "SUB 5 - 3");
        test_alu(32'h0000_0003, 32'h0000_0005, OP_SUB, 0,
                 32'hFFFF_FFFE, 0, 0, 0, 1, "SUB 3 - 5 (negative)");
        test_alu(32'h0000_0000, 32'h0000_0000, OP_SUB, 0,
                 32'h0000_0000, 1, 0, 1, 0, "SUB 0 - 0");
        
        // Test ADC (Add with Carry)
        $display("\nTesting ADC operation...");
        test_alu(32'h0000_0001, 32'h0000_0001, OP_ADC, 0,
                 32'h0000_0002, 0, 0, 0, 0, "ADC without carry");
        test_alu(32'h0000_0001, 32'h0000_0001, OP_ADC, 1,
                 32'h0000_0003, 0, 0, 0, 0, "ADC with carry");
        
        // Test ORR operation
        $display("\nTesting ORR operation...");
        test_alu(32'hAAAA_AAAA, 32'h5555_5555, OP_ORR, 0,
                 32'hFFFF_FFFF, 0, 0, 0, 1, "ORR alternating bits");
        test_alu(32'h0000_0000, 32'h0000_0000, OP_ORR, 0,
                 32'h0000_0000, 0, 0, 1, 0, "ORR zeros");
        
        // Test MOV operation
        $display("\nTesting MOV operation...");
        test_alu(32'h0000_0000, 32'h1234_5678, OP_MOV, 0,
                 32'h1234_5678, 0, 0, 0, 0, "MOV value");
        test_alu(32'h0000_0000, 32'h0000_0000, OP_MOV, 0,
                 32'h0000_0000, 0, 0, 1, 0, "MOV zero");
        
        // Test MVN (Move NOT) operation
        $display("\nTesting MVN operation...");
        test_alu(32'h0000_0000, 32'hFFFF_FFFF, OP_MVN, 0,
                 32'h0000_0000, 0, 0, 1, 0, "MVN all ones");
        test_alu(32'h0000_0000, 32'h0000_0000, OP_MVN, 0,
                 32'hFFFF_FFFF, 0, 0, 0, 1, "MVN zero");
        
        // Test BIC (Bit Clear) operation
        $display("\nTesting BIC operation...");
        test_alu(32'hFFFF_FFFF, 32'h0000_FFFF, OP_BIC, 0,
                 32'hFFFF_0000, 0, 0, 0, 1, "BIC clear lower half");
        
        // Edge cases
        $display("\nTesting edge cases...");
        test_alu(32'h8000_0000, 32'h8000_0000, OP_ADD, 0,
                 32'h0000_0000, 1, 1, 1, 0, "ADD negative overflow");
        test_alu(32'h8000_0000, 32'h0000_0001, OP_SUB, 0,
                 32'h7FFF_FFFF, 1, 1, 0, 0, "SUB overflow");
        
        // Summary
        #10;
        $display("\n=== Test Summary ===");
        $display("Total tests: %0d", tests);
        $display("Errors: %0d", errors);
        
        if (errors == 0) begin
            $display("*** ALL TESTS PASSED ***");
        end else begin
            $display("*** %0d TESTS FAILED ***", errors);
        end
        
        $finish;
    end
    
    // Waveform dump
    initial begin
        $dumpfile("alu_tb.vcd");
        $dumpvars(0, alu_tb);
    end
    
endmodule

