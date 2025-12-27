// =============================================================================
// Testbench Utilities
// =============================================================================
// Description:
//   Common utilities and macros for testbenches.
//   Provides assertion checking, test reporting, and helper functions.
//
// Author: ARM7 Computer System Project
// Date: 2025-11-03
// =============================================================================

`timescale 1ns / 1ps

// =============================================================================
// Test Reporting Macros
// =============================================================================

`define TEST_START(test_name) \
    begin \
        $display(""); \
        $display("========================================"); \
        $display("TEST: %s", test_name); \
        $display("========================================"); \
        test_count = test_count + 1; \
    end

`define TEST_END \
    begin \
        $display("========================================"); \
        $display(""); \
    end

`define PASS(message) \
    begin \
        $display("✓ PASS: %s", message); \
        pass_count = pass_count + 1; \
    end

`define FAIL(message) \
    begin \
        $display("✗ FAIL: %s", message); \
        fail_count = fail_count + 1; \
    end

`define INFO(message) \
    $display("  INFO: %s", message)

`define WARN(message) \
    $display("  WARN: %s", message)

// =============================================================================
// Assertion Macros
// =============================================================================

`define ASSERT_EQ(actual, expected, message) \
    begin \
        if (actual === expected) begin \
            `PASS(message) \
        end else begin \
            $display("  Expected: 0x%0h (%0d)", expected, expected); \
            $display("  Actual:   0x%0h (%0d)", actual, actual); \
            `FAIL(message) \
        end \
    end

`define ASSERT_NE(actual, expected, message) \
    begin \
        if (actual !== expected) begin \
            `PASS(message) \
        end else begin \
            $display("  Value: 0x%0h (should not equal expected)", actual); \
            `FAIL(message) \
        end \
    end

`define ASSERT_TRUE(condition, message) \
    begin \
        if (condition) begin \
            `PASS(message) \
        end else begin \
            `FAIL(message) \
        end \
    end

`define ASSERT_FALSE(condition, message) \
    begin \
        if (!condition) begin \
            `PASS(message) \
        end else begin \
            `FAIL(message) \
        end \
    end

`define ASSERT_GT(actual, threshold, message) \
    begin \
        if (actual > threshold) begin \
            `PASS(message) \
        end else begin \
            $display("  Actual: %0d (should be > %0d)", actual, threshold); \
            `FAIL(message) \
        end \
    end

`define ASSERT_LT(actual, threshold, message) \
    begin \
        if (actual < threshold) begin \
            `PASS(message) \
        end else begin \
            $display("  Actual: %0d (should be < %0d)", actual, threshold); \
            `FAIL(message) \
        end \
    end

// =============================================================================
// Test Summary Macro
// =============================================================================

`define TEST_SUMMARY \
    begin \
        $display(""); \
        $display("========================================"); \
        $display("TEST SUMMARY"); \
        $display("========================================"); \
        $display("Total Tests:  %0d", test_count); \
        $display("Passed:       %0d", pass_count); \
        $display("Failed:       %0d", fail_count); \
        if (fail_count == 0) begin \
            $display("Result:       ✓✓✓ ALL TESTS PASSED ✓✓✓"); \
        end else begin \
            $display("Result:       ✗✗✗ SOME TESTS FAILED ✗✗✗"); \
        end \
        $display("========================================"); \
        $display(""); \
    end

// =============================================================================
// Helper Tasks Module
// =============================================================================

module testbench_utils;
    
    // Test counters (can be accessed from testbenches)
    integer test_count = 0;
    integer pass_count = 0;
    integer fail_count = 0;
    
    // =============================================================================
    // Clock Generation
    // =============================================================================
    
    task automatic generate_clock;
        input real period_ns;
        output reg clk;
        begin
            clk = 0;
            forever #(period_ns/2) clk = ~clk;
        end
    endtask
    
    // =============================================================================
    // Reset Generation
    // =============================================================================
    
    task automatic generate_reset;
        input integer cycles;
        output reg rst_n;
        input clk;
        integer i;
        begin
            rst_n = 0;
            for (i = 0; i < cycles; i = i + 1) begin
                @(posedge clk);
            end
            rst_n = 1;
        end
    endtask
    
    // =============================================================================
    // Wait Cycles
    // =============================================================================
    
    task automatic wait_cycles;
        input integer n;
        input clk;
        integer i;
        begin
            for (i = 0; i < n; i = i + 1) begin
                @(posedge clk);
            end
        end
    endtask
    
    // =============================================================================
    // Compare Values
    // =============================================================================
    
    function automatic integer compare_values;
        input [31:0] actual;
        input [31:0] expected;
        begin
            compare_values = (actual === expected) ? 1 : 0;
        end
    endfunction
    
    // =============================================================================
    // Hex Dump
    // =============================================================================
    
    task automatic hex_dump;
        input [31:0] addr;
        input [31:0] data;
        begin
            $display("  [0x%08h] = 0x%08h (%0d)", addr, data, data);
        end
    endtask
    
    // =============================================================================
    // Binary Display
    // =============================================================================
    
    task automatic display_binary;
        input [31:0] value;
        input [200*8:1] label;
        begin
            $display("  %s: %b", label, value);
        end
    endtask
    
    // =============================================================================
    // Timeout Watchdog
    // =============================================================================
    
    task automatic timeout_watchdog;
        input integer timeout_ns;
        begin
            #timeout_ns;
            $display("");
            $display("✗✗✗ TIMEOUT! ✗✗✗");
            $display("Test did not complete within %0d ns", timeout_ns);
            $finish;
        end
    endtask
    
endmodule

// =============================================================================
// Example Usage
// =============================================================================
/*

module my_testbench;
    `include "testbench_utils.v"
    
    reg clk, rst_n;
    wire [31:0] result;
    integer test_count, pass_count, fail_count;
    
    // DUT instantiation
    my_module dut (
        .clk(clk),
        .rst_n(rst_n),
        .result(result)
    );
    
    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;
    
    // Test sequence
    initial begin
        test_count = 0;
        pass_count = 0;
        fail_count = 0;
        
        `TEST_START("Reset Test")
        rst_n = 0;
        #100;
        rst_n = 1;
        #100;
        `ASSERT_EQ(result, 32'h0, "Result should be 0 after reset")
        `TEST_END
        
        `TEST_START("Basic Operation")
        // ... test code ...
        `ASSERT_EQ(result, 32'h42, "Result should be 42")
        `TEST_END
        
        `TEST_SUMMARY
        $finish;
    end
    
    // Timeout
    initial begin
        #1000000;
        $display("TIMEOUT!");
        $finish;
    end
    
endmodule

*/

// =============================================================================
// Notes:
//   - Include this file in your testbenches
//   - Initialize test_count, pass_count, fail_count in your testbench
//   - Use the macros for consistent test reporting
//   - Always call TEST_SUMMARY at the end
// =============================================================================

