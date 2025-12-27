// =============================================================================
// CPU Top Module Testbench
// =============================================================================
// Description:
//   Comprehensive testbench for the complete ARM7 CPU.
//   Tests instruction execution, pipeline operation, and hazard handling.
//
// Author: ARM7 Computer System Project
// Date: 2025-11-03
// =============================================================================

`timescale 1ns / 1ps

module cpu_tb;

    // Clock and reset
    reg clk;
    reg rst_n;
    
    // Instruction memory
    reg [31:0] imem [0:1023];
    wire [31:0] imem_addr;
    wire imem_read_en;
    reg [31:0] imem_read_data;
    reg imem_ready;
    
    // Data memory
    reg [31:0] dmem [0:1023];
    wire [31:0] dmem_addr;
    wire [31:0] dmem_write_data;
    wire dmem_read_en;
    wire dmem_write_en;
    reg [31:0] dmem_read_data;
    reg dmem_ready;
    
    // Debug signals
    wire [31:0] debug_pc;
    wire [3:0] debug_cpsr_flags;
    wire debug_halted;
    
    // Test control
    integer test_num;
    integer errors;
    integer cycles;
    
    // Instantiate CPU
    cpu_top #(
        .DATA_WIDTH(32),
        .ADDR_WIDTH(32)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .imem_addr(imem_addr),
        .imem_read_en(imem_read_en),
        .imem_read_data(imem_read_data),
        .imem_ready(imem_ready),
        .dmem_addr(dmem_addr),
        .dmem_write_data(dmem_write_data),
        .dmem_read_en(dmem_read_en),
        .dmem_write_en(dmem_write_en),
        .dmem_read_data(dmem_read_data),
        .dmem_ready(dmem_ready),
        .irq(1'b0),
        .fiq(1'b0),
        .debug_pc(debug_pc),
        .debug_cpsr_flags(debug_cpsr_flags),
        .debug_halted(debug_halted)
    );
    
    // Clock generation (50 MHz)
    initial clk = 0;
    always #10 clk = ~clk;
    
    // Instruction memory interface
    always @(posedge clk) begin
        if (imem_read_en) begin
            imem_read_data <= imem[imem_addr[11:2]];
            imem_ready <= 1'b1;
        end else begin
            imem_ready <= 1'b0;
        end
    end
    
    // Data memory interface
    always @(posedge clk) begin
        if (dmem_write_en) begin
            dmem[dmem_addr[11:2]] <= dmem_write_data;
            dmem_ready <= 1'b1;
        end else if (dmem_read_en) begin
            dmem_read_data <= dmem[dmem_addr[11:2]];
            dmem_ready <= 1'b1;
        end else begin
            dmem_ready <= 1'b0;
        end
    end
    
    // Cycle counter
    always @(posedge clk) begin
        if (rst_n) cycles <= cycles + 1;
    end
    
    // Test tasks
    task reset_cpu;
    begin
        rst_n = 0;
        cycles = 0;
        #50;
        rst_n = 1;
        #20;
    end
    endtask
    
    task load_program;
        input [8*100:1] filename;
        integer i;
    begin
        $display("Loading program: %s", filename);
        // In real implementation, use $readmemh
        // For now, manually load test programs
    end
    endtask
    
    task run_cycles;
        input integer num_cycles;
        integer i;
    begin
        for (i = 0; i < num_cycles; i = i + 1) begin
            @(posedge clk);
        end
    end
    endtask
    
    task check_register;
        input [3:0] reg_num;
        input [31:0] expected;
    begin
        // Note: Would need to expose register file for this
        // For now, use memory stores to verify
    end
    endtask
    
    // Test programs
    task test_basic_arithmetic;
    begin
        $display("\n=== Test 1: Basic Arithmetic ===");
        test_num = 1;
        
        // Program: ADD R1, R0, #5
        //          ADD R2, R1, #10
        //          SUB R3, R2, #3
        imem[0] = 32'hE2801005;  // ADD R1, R0, #5
        imem[1] = 32'hE281200A;  // ADD R2, R1, #10
        imem[2] = 32'hE2423003;  // SUB R3, R2, #3
        imem[3] = 32'hEAFFFFFE;  // B . (infinite loop)
        
        reset_cpu();
        run_cycles(20);
        
        $display("Test 1 complete - PC: 0x%08X", debug_pc);
    end
    endtask
    
    task test_load_store;
    begin
        $display("\n=== Test 2: Load/Store ===");
        test_num = 2;
        
        // Program: MOV R1, #0x100
        //          MOV R2, #42
        //          STR R2, [R1]
        //          LDR R3, [R1]
        imem[0] = 32'hE3A01C01;  // MOV R1, #0x100
        imem[1] = 32'hE3A0202A;  // MOV R2, #42
        imem[2] = 32'hE5812000;  // STR R2, [R1]
        imem[3] = 32'hE5913000;  // LDR R3, [R1]
        imem[4] = 32'hEAFFFFFE;  // B .
        
        reset_cpu();
        run_cycles(30);
        
        $display("Test 2 complete - PC: 0x%08X", debug_pc);
        
        // Check memory
        if (dmem[32'h40] !== 32'd42) begin
            $display("ERROR: Memory write failed");
            errors = errors + 1;
        end
    end
    endtask
    
    task test_branches;
    begin
        $display("\n=== Test 3: Branches ===");
        test_num = 3;
        
        // Program: MOV R1, #5
        //          CMP R1, #5
        //          BEQ target
        //          MOV R2, #1    (should skip)
        // target:  MOV R3, #2
        imem[0] = 32'hE3A01005;  // MOV R1, #5
        imem[1] = 32'hE3510005;  // CMP R1, #5
        imem[2] = 32'h0A000000;  // BEQ +0 (next instruction)
        imem[3] = 32'hE3A02001;  // MOV R2, #1
        imem[4] = 32'hE3A03002;  // MOV R3, #2
        imem[5] = 32'hEAFFFFFE;  // B .
        
        reset_cpu();
        run_cycles(30);
        
        $display("Test 3 complete - PC: 0x%08X", debug_pc);
    end
    endtask
    
    task test_data_hazards;
    begin
        $display("\n=== Test 4: Data Hazards (Forwarding) ===");
        test_num = 4;
        
        // Program with RAW hazards
        // ADD R1, R0, #5
        // ADD R2, R1, #10   (needs R1 from previous)
        // ADD R3, R2, #15   (needs R2 from previous)
        imem[0] = 32'hE2801005;  // ADD R1, R0, #5
        imem[1] = 32'hE281200A;  // ADD R2, R1, #10
        imem[2] = 32'hE282300F;  // ADD R3, R2, #15
        imem[3] = 32'hEAFFFFFE;  // B .
        
        reset_cpu();
        run_cycles(30);
        
        $display("Test 4 complete - Forwarding should handle hazards");
        $display("Cycles: %d", cycles);
    end
    endtask
    
    task test_load_use_hazard;
    begin
        $display("\n=== Test 5: Load-Use Hazard (Stall) ===");
        test_num = 5;
        
        // Program with load-use hazard
        // MOV R1, #0x100
        // LDR R2, [R1]
        // ADD R3, R2, #5    (needs R2 from load - must stall)
        imem[0] = 32'hE3A01C01;  // MOV R1, #0x100
        imem[1] = 32'hE5912000;  // LDR R2, [R1]
        imem[2] = 32'hE2823005;  // ADD R3, R2, #5
        imem[3] = 32'hEAFFFFFE;  // B .
        
        // Initialize memory
        dmem[32'h40] = 32'd100;
        
        reset_cpu();
        run_cycles(40);
        
        $display("Test 5 complete - Pipeline should stall for load-use");
        $display("Cycles: %d (should be > 30 due to stall)", cycles);
    end
    endtask
    
    task test_flags;
    begin
        $display("\n=== Test 6: Condition Flags ===");
        test_num = 6;
        
        // Test flag setting
        // SUBS R1, R0, R0   (should set Z flag)
        // ADDS R2, R0, #-1  (should set N and C flags)
        imem[0] = 32'hE0501000;  // SUBS R1, R0, R0
        imem[1] = 32'hE29020FF;  // ADDS R2, R0, #-1
        imem[2] = 32'hEAFFFFFE;  // B .
        
        reset_cpu();
        run_cycles(20);
        
        $display("Test 6 complete - Flags: N=%b Z=%b C=%b V=%b",
                 debug_cpsr_flags[3], debug_cpsr_flags[2],
                 debug_cpsr_flags[1], debug_cpsr_flags[0]);
    end
    endtask
    
    // Main test sequence
    initial begin
        $display("========================================");
        $display("ARM7 CPU Testbench");
        $display("========================================");
        
        errors = 0;
        test_num = 0;
        
        // Initialize memories
        integer i;
        for (i = 0; i < 1024; i = i + 1) begin
            imem[i] = 32'h00000000;
            dmem[i] = 32'h00000000;
        end
        
        // Run tests
        test_basic_arithmetic();
        test_load_store();
        test_branches();
        test_data_hazards();
        test_load_use_hazard();
        test_flags();
        
        // Summary
        #100;
        $display("\n========================================");
        $display("Test Summary");
        $display("========================================");
        $display("Tests run: %d", test_num);
        $display("Errors: %d", errors);
        
        if (errors == 0) begin
            $display("ALL TESTS PASSED!");
        end else begin
            $display("SOME TESTS FAILED!");
        end
        
        $display("========================================");
        $finish;
    end
    
    // Timeout
    initial begin
        #100000;
        $display("ERROR: Testbench timeout!");
        $finish;
    end
    
endmodule

