// =============================================================================
// ARM7 Computer System - FPGA Top-Level Wrapper
// =============================================================================
// Description:
//   Top-level module for FPGA deployment. Wraps the SoC and connects to
//   physical FPGA pins (clock, reset, UART, GPIO).
//
// Target: Xilinx 7-Series FPGAs (Artix-7, Spartan-7, Zynq-7000)
// Board Examples: Basys3, Arty A7, Nexys A7, Zybo Z7
// =============================================================================

module fpga_top (
    // Clock and Reset
    input  wire        clk,          // 100 MHz board clock
    input  wire        rst,          // Reset button (active high)
    
    // UART Interface
    output wire        uart_tx,      // UART transmit
    input  wire        uart_rx,      // UART receive
    
    // GPIO Interface
    output wire [15:0] gpio_out,     // GPIO outputs (LEDs)
    input  wire [15:0] gpio_in       // GPIO inputs (switches)
);

    // =========================================================================
    // Clock and Reset Management
    // =========================================================================
    
    // Synchronize reset to clock domain
    reg [2:0] rst_sync;
    always @(posedge clk) begin
        rst_sync <= {rst_sync[1:0], rst};
    end
    wire rst_n = ~rst_sync[2];  // Active-low synchronized reset
    
    // =========================================================================
    // SoC Instantiation
    // =========================================================================
    
    // Internal signals
    wire [31:0] gpio_data_out;
    wire [31:0] gpio_data_in;
    wire [31:0] gpio_dir;
    
    // Instantiate the ARM7 SoC
    soc_top soc (
        .clk(clk),
        .rst_n(rst_n),
        
        // UART
        .uart_tx(uart_tx),
        .uart_rx(uart_rx),
        
        // GPIO
        .gpio_in(gpio_data_in),
        .gpio_out(gpio_data_out),
        .gpio_dir(gpio_dir)
    );
    
    // =========================================================================
    // GPIO Mapping
    // =========================================================================
    
    // Map lower 16 bits of GPIO to physical pins
    assign gpio_out = gpio_data_out[15:0];
    assign gpio_data_in = {16'h0000, gpio_in};
    
    // =========================================================================
    // Debug: Heartbeat LED (optional)
    // =========================================================================
    
    // Uncomment to add a heartbeat on LED 15
    // reg [26:0] heartbeat_counter;
    // always @(posedge clk) begin
    //     if (!rst_n)
    //         heartbeat_counter <= 0;
    //     else
    //         heartbeat_counter <= heartbeat_counter + 1;
    // end
    // assign gpio_out[15] = heartbeat_counter[26];  // ~0.75 Hz blink

endmodule

