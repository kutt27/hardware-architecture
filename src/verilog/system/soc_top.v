// =============================================================================
// System-on-Chip Top Module
// =============================================================================
// Description:
//   Complete SoC integrating CPU, memory, and peripherals.
//   Memory-mapped I/O with address decoding.
//
// Memory Map:
//   0x00000000 - 0x00000FFF : Boot ROM (4KB)
//   0x00001000 - 0x0000FFFF : Program RAM (60KB)
//   0x00010000 - 0x0001FFFF : Data RAM (64KB)
//   0xFFFF0000 - 0xFFFF00FF : UART
//   0xFFFF0100 - 0xFFFF01FF : GPIO
//
// Author: ARM7 Computer System Project
// Date: 2025-11-03
// =============================================================================

module soc_top #(
    parameter CLK_FREQ = 50_000_000,
    parameter UART_BAUD = 115200
) (
    input  wire         clk,
    input  wire         rst_n,
    
    // UART pins
    input  wire         uart_rx,
    output wire         uart_tx,
    
    // GPIO pins
    inout  wire [15:0]  gpio_pins,
    
    // Debug outputs
    output wire [31:0]  debug_pc,
    output wire [3:0]   debug_flags,
    output wire         debug_halted
);

    // CPU interfaces
    wire [31:0] imem_addr, dmem_addr;
    wire [31:0] imem_rdata, dmem_rdata, dmem_wdata;
    wire imem_ren, dmem_ren, dmem_wen;
    wire imem_ready, dmem_ready;
    
    // Memory interfaces
    wire [31:0] rom_addr, ram_prog_addr, ram_data_addr;
    wire [31:0] rom_rdata, ram_prog_rdata, ram_data_rdata;
    wire rom_ren, ram_prog_ren, ram_data_ren;
    wire [31:0] ram_data_wdata;
    wire ram_data_wen;
    
    // Peripheral interfaces
    wire [31:0] uart_addr, gpio_addr;
    wire [31:0] uart_rdata, gpio_rdata;
    wire [31:0] uart_wdata, gpio_wdata;
    wire uart_ren, uart_wen, gpio_ren, gpio_wen;
    
    // Address decode signals
    wire sel_rom, sel_ram_prog, sel_ram_data, sel_uart, sel_gpio;
    
    // =============================================================================
    // CPU Core
    // =============================================================================
    
    cpu_top cpu (
        .clk(clk),
        .rst_n(rst_n),
        .imem_addr(imem_addr),
        .imem_read_en(imem_ren),
        .imem_read_data(imem_rdata),
        .imem_ready(imem_ready),
        .dmem_addr(dmem_addr),
        .dmem_write_data(dmem_wdata),
        .dmem_read_en(dmem_ren),
        .dmem_write_en(dmem_wen),
        .dmem_read_data(dmem_rdata),
        .dmem_ready(dmem_ready),
        .irq(1'b0),
        .fiq(1'b0),
        .debug_pc(debug_pc),
        .debug_cpsr_flags(debug_flags),
        .debug_halted(debug_halted)
    );
    
    // =============================================================================
    // Instruction Memory Address Decode
    // =============================================================================
    
    assign sel_rom = (imem_addr[31:12] == 20'h00000);  // 0x00000000 - 0x00000FFF
    assign sel_ram_prog = (imem_addr[31:16] == 16'h0000) && !sel_rom;  // 0x00001000+
    
    assign imem_rdata = sel_rom ? rom_rdata : ram_prog_rdata;
    assign imem_ready = 1'b1;  // Synchronous memory, always ready
    
    // =============================================================================
    // Data Memory Address Decode
    // =============================================================================
    
    assign sel_ram_data = (dmem_addr[31:16] == 16'h0001);  // 0x00010000 - 0x0001FFFF
    assign sel_uart = (dmem_addr[31:8] == 24'hFFFF00);     // 0xFFFF0000 - 0xFFFF00FF
    assign sel_gpio = (dmem_addr[31:8] == 24'hFFFF01);     // 0xFFFF0100 - 0xFFFF01FF
    
    assign dmem_rdata = sel_ram_data ? ram_data_rdata :
                        sel_uart ? uart_rdata :
                        sel_gpio ? gpio_rdata :
                        32'h00000000;
    
    assign dmem_ready = 1'b1;  // All peripherals respond immediately
    
    // =============================================================================
    // Boot ROM (4KB)
    // =============================================================================
    
    rom #(
        .ADDR_WIDTH(10),
        .DATA_WIDTH(32),
        .INIT_FILE("boot.hex")
    ) boot_rom (
        .clk(clk),
        .addr(imem_addr[11:2]),
        .read_en(imem_ren && sel_rom),
        .read_data(rom_rdata)
    );
    
    // =============================================================================
    // Program RAM (60KB)
    // =============================================================================
    
    sp_ram #(
        .ADDR_WIDTH(14),
        .DATA_WIDTH(32)
    ) program_ram (
        .clk(clk),
        .addr(imem_addr[15:2]),
        .write_data(32'h00000000),
        .write_en(1'b0),  // Read-only for instruction fetch
        .read_en(imem_ren && sel_ram_prog),
        .read_data(ram_prog_rdata)
    );
    
    // =============================================================================
    // Data RAM (64KB)
    // =============================================================================
    
    sp_ram #(
        .ADDR_WIDTH(14),
        .DATA_WIDTH(32)
    ) data_ram (
        .clk(clk),
        .addr(dmem_addr[15:2]),
        .write_data(dmem_wdata),
        .write_en(dmem_wen && sel_ram_data),
        .read_en(dmem_ren && sel_ram_data),
        .read_data(ram_data_rdata)
    );
    
    // =============================================================================
    // UART Peripheral
    // =============================================================================
    
    uart #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(UART_BAUD)
    ) uart_peripheral (
        .clk(clk),
        .rst_n(rst_n),
        .addr(dmem_addr),
        .write_data(dmem_wdata),
        .write_en(dmem_wen && sel_uart),
        .read_en(dmem_ren && sel_uart),
        .read_data(uart_rdata),
        .rx(uart_rx),
        .tx(uart_tx),
        .rx_interrupt(),
        .tx_interrupt()
    );
    
    // =============================================================================
    // GPIO Peripheral
    // =============================================================================
    
    gpio #(
        .NUM_PINS(16)
    ) gpio_peripheral (
        .clk(clk),
        .rst_n(rst_n),
        .addr(dmem_addr),
        .write_data(dmem_wdata),
        .write_en(dmem_wen && sel_gpio),
        .read_en(dmem_ren && sel_gpio),
        .read_data(gpio_rdata),
        .gpio_pins(gpio_pins),
        .gpio_interrupt()
    );
    
endmodule

// =============================================================================
// SoC Testbench
// =============================================================================

module soc_tb;
    reg clk, rst_n;
    reg uart_rx;
    wire uart_tx;
    wire [15:0] gpio_pins;
    wire [31:0] debug_pc;
    wire [3:0] debug_flags;
    wire debug_halted;
    
    // Instantiate SoC
    soc_top #(
        .CLK_FREQ(50_000_000),
        .UART_BAUD(115200)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .uart_rx(uart_rx),
        .uart_tx(uart_tx),
        .gpio_pins(gpio_pins),
        .debug_pc(debug_pc),
        .debug_flags(debug_flags),
        .debug_halted(debug_halted)
    );
    
    // Clock generation
    initial clk = 0;
    always #10 clk = ~clk;
    
    // Test sequence
    initial begin
        $display("SoC Testbench Starting...");
        
        // Reset
        rst_n = 0;
        uart_rx = 1;
        #100;
        rst_n = 1;
        
        // Run for some cycles
        #10000;
        
        $display("PC: 0x%08X", debug_pc);
        $display("Flags: N=%b Z=%b C=%b V=%b",
                 debug_flags[3], debug_flags[2],
                 debug_flags[1], debug_flags[0]);
        
        $display("SoC Testbench Complete!");
        $finish;
    end
    
    // Timeout
    initial begin
        #1000000;
        $display("Timeout!");
        $finish;
    end
    
endmodule

// =============================================================================
// Usage:
//   This is the top-level module for FPGA synthesis or full system simulation.
//   Load program into program_ram and boot code into boot_rom.
// =============================================================================

