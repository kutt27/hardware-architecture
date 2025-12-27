// =============================================================================
// UART Testbench
// =============================================================================
// Description:
//   Comprehensive testbench for UART module. Tests TX, RX, and loopback.
//
// Author: ARM7 Computer System Project
// Date: 2025-11-03
// =============================================================================

`timescale 1ns/1ps

module uart_tb;

    // Parameters
    parameter CLK_FREQ = 50000000;
    parameter BAUD_RATE = 115200;
    parameter CLK_PERIOD = 20;  // 50 MHz = 20ns period
    parameter BIT_PERIOD = 1000000000 / BAUD_RATE;  // ns per bit
    
    // Signals
    reg         clk;
    reg         rst_n;
    reg         rx;
    wire        tx;
    reg  [2:0]  addr;
    reg         write_en;
    reg         read_en;
    reg  [7:0]  write_data;
    wire [7:0]  read_data;
    wire        rx_interrupt;
    wire        tx_interrupt;
    
    // Test variables
    integer errors = 0;
    integer tests = 0;
    
    // DUT instantiation
    uart #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .rx(rx),
        .tx(tx),
        .addr(addr),
        .write_en(write_en),
        .read_en(read_en),
        .write_data(write_data),
        .read_data(read_data),
        .rx_interrupt(rx_interrupt),
        .tx_interrupt(tx_interrupt)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #(CLK_PERIOD/2) clk = ~clk;
    end
    
    // Register addresses
    localparam ADDR_DATA   = 3'h0;
    localparam ADDR_STATUS = 3'h1;
    
    // Task: Write to UART register
    task uart_write;
        input [2:0] reg_addr;
        input [7:0] data;
    begin
        @(posedge clk);
        addr = reg_addr;
        write_data = data;
        write_en = 1'b1;
        @(posedge clk);
        write_en = 1'b0;
    end
    endtask
    
    // Task: Read from UART register
    task uart_read;
        input [2:0] reg_addr;
        output [7:0] data;
    begin
        @(posedge clk);
        addr = reg_addr;
        read_en = 1'b1;
        @(posedge clk);
        data = read_data;
        read_en = 1'b0;
    end
    endtask
    
    // Task: Send byte via RX line (simulate external device)
    task send_byte;
        input [7:0] data;
        integer i;
    begin
        // Start bit
        rx = 1'b0;
        #BIT_PERIOD;
        
        // Data bits (LSB first)
        for (i = 0; i < 8; i = i + 1) begin
            rx = data[i];
            #BIT_PERIOD;
        end
        
        // Stop bit
        rx = 1'b1;
        #BIT_PERIOD;
    end
    endtask
    
    // Task: Receive byte via TX line
    task receive_byte;
        output [7:0] data;
        integer i;
    begin
        // Wait for start bit
        wait (tx == 1'b0);
        #(BIT_PERIOD/2);  // Sample in middle of bit
        
        // Check start bit
        if (tx !== 1'b0) begin
            $display("ERROR: Invalid start bit");
            errors = errors + 1;
        end
        
        #BIT_PERIOD;
        
        // Receive data bits
        for (i = 0; i < 8; i = i + 1) begin
            data[i] = tx;
            #BIT_PERIOD;
        end
        
        // Check stop bit
        if (tx !== 1'b1) begin
            $display("ERROR: Invalid stop bit");
            errors = errors + 1;
        end
    end
    endtask
    
    // Main test sequence
    initial begin
        $display("=== UART Testbench ===");
        $display("Clock: %0d Hz, Baud: %0d", CLK_FREQ, BAUD_RATE);
        $display("Bit period: %0d ns", BIT_PERIOD);
        
        // Initialize
        rst_n = 0;
        rx = 1'b1;  // Idle high
        addr = 0;
        write_en = 0;
        read_en = 0;
        write_data = 0;
        
        // Reset
        #(CLK_PERIOD * 10);
        rst_n = 1;
        #(CLK_PERIOD * 10);
        
        // Test 1: Transmit single byte
        $display("\nTest 1: Transmit byte 0x55");
        tests = tests + 1;
        fork
            begin
                uart_write(ADDR_DATA, 8'h55);
            end
            begin
                reg [7:0] received;
                receive_byte(received);
                if (received !== 8'h55) begin
                    $display("ERROR: TX mismatch - Expected 0x55, Got 0x%02h", received);
                    errors = errors + 1;
                end else begin
                    $display("PASS: TX byte 0x55");
                end
            end
        join
        
        #(BIT_PERIOD * 20);
        
        // Test 2: Transmit multiple bytes
        $display("\nTest 2: Transmit multiple bytes");
        tests = tests + 1;
        fork
            begin
                uart_write(ADDR_DATA, 8'hAA);
                #(BIT_PERIOD * 12);
                uart_write(ADDR_DATA, 8'h55);
            end
            begin
                reg [7:0] rx1, rx2;
                receive_byte(rx1);
                receive_byte(rx2);
                if (rx1 !== 8'hAA || rx2 !== 8'h55) begin
                    $display("ERROR: Multi-byte TX failed");
                    errors = errors + 1;
                end else begin
                    $display("PASS: Multi-byte TX");
                end
            end
        join
        
        #(BIT_PERIOD * 20);
        
        // Test 3: Receive single byte
        $display("\nTest 3: Receive byte 0x33");
        tests = tests + 1;
        fork
            begin
                send_byte(8'h33);
            end
            begin
                reg [7:0] status, data;
                // Wait for RX ready
                repeat (1000) begin
                    uart_read(ADDR_STATUS, status);
                    if (status[1]) begin  // RX buffer full
                        uart_read(ADDR_DATA, data);
                        if (data !== 8'h33) begin
                            $display("ERROR: RX mismatch - Expected 0x33, Got 0x%02h", data);
                            errors = errors + 1;
                        end else begin
                            $display("PASS: RX byte 0x33");
                        end
                        disable fork;
                    end
                    #(CLK_PERIOD * 10);
                end
                $display("ERROR: RX timeout");
                errors = errors + 1;
            end
        join
        
        #(BIT_PERIOD * 20);
        
        // Test 4: Loopback test
        $display("\nTest 4: Loopback test");
        tests = tests + 1;
        fork
            begin
                // Connect TX to RX
                forever begin
                    @(tx);
                    rx = tx;
                end
            end
            begin
                reg [7:0] test_data, rx_data, status;
                test_data = 8'h5A;
                
                // Send byte
                uart_write(ADDR_DATA, test_data);
                
                // Wait for loopback
                #(BIT_PERIOD * 15);
                
                // Read received byte
                uart_read(ADDR_STATUS, status);
                if (status[1]) begin
                    uart_read(ADDR_DATA, rx_data);
                    if (rx_data !== test_data) begin
                        $display("ERROR: Loopback failed - Expected 0x%02h, Got 0x%02h", 
                                test_data, rx_data);
                        errors = errors + 1;
                    end else begin
                        $display("PASS: Loopback test");
                    end
                end else begin
                    $display("ERROR: Loopback - no data received");
                    errors = errors + 1;
                end
                
                disable fork;
            end
        join
        
        // Summary
        #(BIT_PERIOD * 20);
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
    
    // Timeout
    initial begin
        #(BIT_PERIOD * 1000);
        $display("ERROR: Testbench timeout");
        $finish;
    end
    
    // Waveform dump
    initial begin
        $dumpfile("uart_tb.vcd");
        $dumpvars(0, uart_tb);
    end
    
endmodule

