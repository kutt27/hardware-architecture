// =============================================================================
// Basic Logic Gates Testbench
// =============================================================================
// Description:
//   Comprehensive testbench for all basic logic gates. Tests single-bit and
//   multi-bit operations, verifies truth tables, and checks edge cases.
//
// Learning Points:
//   - Testbench structure and organization
//   - Initial blocks and test stimulus generation
//   - Self-checking testbenches with assertions
//   - Waveform generation for debugging
//
// Author: ARM7 Computer System Project
// Date: 2025-11-03
// =============================================================================

`timescale 1ns/1ps

module gates_tb;
    // Test signals
    reg  [7:0] a, b;
    wire [7:0] and_out, or_out, not_out, nand_out, nor_out, xor_out, xnor_out;
    wire [7:0] buf_out, tri_out;
    reg        tri_enable;
    
    // Test counters
    integer errors = 0;
    integer tests = 0;
    
    // Instantiate all gates with 8-bit width
    and_gate #(.WIDTH(8)) dut_and (
        .a(a), .b(b), .y(and_out)
    );
    
    or_gate #(.WIDTH(8)) dut_or (
        .a(a), .b(b), .y(or_out)
    );
    
    not_gate #(.WIDTH(8)) dut_not (
        .a(a), .y(not_out)
    );
    
    nand_gate #(.WIDTH(8)) dut_nand (
        .a(a), .b(b), .y(nand_out)
    );
    
    nor_gate #(.WIDTH(8)) dut_nor (
        .a(a), .b(b), .y(nor_out)
    );
    
    xor_gate #(.WIDTH(8)) dut_xor (
        .a(a), .b(b), .y(xor_out)
    );
    
    xnor_gate #(.WIDTH(8)) dut_xnor (
        .a(a), .b(b), .y(xnor_out)
    );
    
    buffer #(.WIDTH(8)) dut_buf (
        .a(a), .y(buf_out)
    );
    
    tri_buffer #(.WIDTH(8)) dut_tri (
        .a(a), .enable(tri_enable), .y(tri_out)
    );
    
    // Task to check a result and report errors
    task check_result;
        input [7:0] expected;
        input [7:0] actual;
        input [80*8-1:0] test_name;
        begin
            tests = tests + 1;
            if (expected !== actual) begin
                errors = errors + 1;
                $display("ERROR: %s", test_name);
                $display("  Expected: 0x%02h, Got: 0x%02h", expected, actual);
            end else begin
                $display("PASS: %s", test_name);
            end
        end
    endtask
    
    // Main test sequence
    initial begin
        $display("=================================================");
        $display("Basic Logic Gates Testbench");
        $display("=================================================");
        
        // Initialize signals
        a = 8'h00;
        b = 8'h00;
        tri_enable = 1'b0;
        #10;
        
        // Test 1: All zeros
        $display("\nTest 1: All zeros (0x00 & 0x00)");
        a = 8'h00; b = 8'h00; #10;
        check_result(8'h00, and_out,  "AND: 0x00 & 0x00 = 0x00");
        check_result(8'h00, or_out,   "OR:  0x00 | 0x00 = 0x00");
        check_result(8'hFF, not_out,  "NOT: ~0x00 = 0xFF");
        check_result(8'hFF, nand_out, "NAND: ~(0x00 & 0x00) = 0xFF");
        check_result(8'hFF, nor_out,  "NOR: ~(0x00 | 0x00) = 0xFF");
        check_result(8'h00, xor_out,  "XOR: 0x00 ^ 0x00 = 0x00");
        check_result(8'hFF, xnor_out, "XNOR: ~(0x00 ^ 0x00) = 0xFF");
        
        // Test 2: All ones
        $display("\nTest 2: All ones (0xFF & 0xFF)");
        a = 8'hFF; b = 8'hFF; #10;
        check_result(8'hFF, and_out,  "AND: 0xFF & 0xFF = 0xFF");
        check_result(8'hFF, or_out,   "OR:  0xFF | 0xFF = 0xFF");
        check_result(8'h00, not_out,  "NOT: ~0xFF = 0x00");
        check_result(8'h00, nand_out, "NAND: ~(0xFF & 0xFF) = 0x00");
        check_result(8'h00, nor_out,  "NOR: ~(0xFF | 0xFF) = 0x00");
        check_result(8'h00, xor_out,  "XOR: 0xFF ^ 0xFF = 0x00");
        check_result(8'hFF, xnor_out, "XNOR: ~(0xFF ^ 0xFF) = 0xFF");
        
        // Test 3: Mixed values
        $display("\nTest 3: Mixed values (0xAA & 0x55)");
        a = 8'hAA; b = 8'h55; #10;
        check_result(8'h00, and_out,  "AND: 0xAA & 0x55 = 0x00");
        check_result(8'hFF, or_out,   "OR:  0xAA | 0x55 = 0xFF");
        check_result(8'h55, not_out,  "NOT: ~0xAA = 0x55");
        check_result(8'hFF, nand_out, "NAND: ~(0xAA & 0x55) = 0xFF");
        check_result(8'h00, nor_out,  "NOR: ~(0xAA | 0x55) = 0x00");
        check_result(8'hFF, xor_out,  "XOR: 0xAA ^ 0x55 = 0xFF");
        check_result(8'h00, xnor_out, "XNOR: ~(0xAA ^ 0x55) = 0x00");
        
        // Test 4: Another mixed pattern
        $display("\nTest 4: Pattern (0xF0 & 0x0F)");
        a = 8'hF0; b = 8'h0F; #10;
        check_result(8'h00, and_out,  "AND: 0xF0 & 0x0F = 0x00");
        check_result(8'hFF, or_out,   "OR:  0xF0 | 0x0F = 0xFF");
        check_result(8'h0F, not_out,  "NOT: ~0xF0 = 0x0F");
        check_result(8'hFF, xor_out,  "XOR: 0xF0 ^ 0x0F = 0xFF");
        
        // Test 5: Partial overlap
        $display("\nTest 5: Partial overlap (0xCC & 0xAA)");
        a = 8'hCC; b = 8'hAA; #10;
        check_result(8'h88, and_out,  "AND: 0xCC & 0xAA = 0x88");
        check_result(8'hEE, or_out,   "OR:  0xCC | 0xAA = 0xEE");
        check_result(8'h66, xor_out,  "XOR: 0xCC ^ 0xAA = 0x66");
        
        // Test 6: Buffer
        $display("\nTest 6: Buffer");
        a = 8'h5A; #10;
        check_result(8'h5A, buf_out, "BUFFER: 0x5A -> 0x5A");
        a = 8'hA5; #10;
        check_result(8'hA5, buf_out, "BUFFER: 0xA5 -> 0xA5");
        
        // Test 7: Tri-state buffer
        $display("\nTest 7: Tri-state buffer");
        a = 8'h42;
        tri_enable = 1'b1; #10;
        check_result(8'h42, tri_out, "TRI-STATE (enabled): 0x42 -> 0x42");
        
        tri_enable = 1'b0; #10;
        if (tri_out === 8'hzz) begin
            $display("PASS: TRI-STATE (disabled): Output is high-Z");
            tests = tests + 1;
        end else begin
            $display("ERROR: TRI-STATE (disabled): Expected high-Z, got 0x%02h", tri_out);
            errors = errors + 1;
            tests = tests + 1;
        end
        
        // Test 8: Random patterns
        $display("\nTest 8: Random patterns");
        repeat (10) begin
            a = $random;
            b = $random;
            #10;
            // Verify basic properties
            if ((and_out & a) !== and_out) begin
                $display("ERROR: AND output not subset of input a");
                errors = errors + 1;
            end
            if ((or_out | a) !== or_out) begin
                $display("ERROR: OR output not superset of input a");
                errors = errors + 1;
            end
            if ((not_out ^ a) !== 8'hFF) begin
                $display("ERROR: NOT output incorrect");
                errors = errors + 1;
            end
            tests = tests + 3;
        end
        $display("Random pattern tests completed");
        
        // Test 9: Identity and complement laws
        $display("\nTest 9: Boolean algebra laws");
        a = 8'hA5; b = 8'h00; #10;
        check_result(8'h00, and_out, "Identity: A & 0 = 0");
        
        a = 8'hA5; b = 8'hFF; #10;
        check_result(8'hA5, and_out, "Identity: A & 1 = A");
        check_result(8'hFF, or_out,  "Identity: A | 1 = 1");
        
        a = 8'hA5; b = 8'hA5; #10;
        check_result(8'hA5, and_out, "Idempotent: A & A = A");
        check_result(8'hA5, or_out,  "Idempotent: A | A = A");
        check_result(8'h00, xor_out, "Complement: A ^ A = 0");
        
        // Summary
        $display("\n=================================================");
        $display("Test Summary");
        $display("=================================================");
        $display("Total tests: %0d", tests);
        $display("Passed:      %0d", tests - errors);
        $display("Failed:      %0d", errors);
        
        if (errors == 0) begin
            $display("\nALL TESTS PASSED!");
        end else begin
            $display("\nSOME TESTS FAILED!");
        end
        $display("=================================================");
        
        $finish;
    end
    
    // Waveform dump for debugging
    initial begin
        $dumpfile("gates_tb.vcd");
        $dumpvars(0, gates_tb);
    end
    
endmodule

