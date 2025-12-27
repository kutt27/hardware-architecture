// =============================================================================
// GPIO Controller - General Purpose I/O
// =============================================================================
// Description:
//   Configurable GPIO controller with direction control and memory-mapped
//   interface.
//
// Learning Points:
//   - Bidirectional I/O
//   - Tri-state buffers
//   - Memory-mapped registers
//   - Pull-up/pull-down configuration
//
// Author: ARM7 Computer System Project
// Date: 2025-11-03
// =============================================================================

module gpio #(
    parameter NUM_PINS = 16,
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    input  wire                         clk,
    input  wire                         rst_n,
    
    // Memory-mapped interface
    input  wire [ADDR_WIDTH-1:0]        addr,
    input  wire [DATA_WIDTH-1:0]        write_data,
    input  wire                         write_en,
    input  wire                         read_en,
    output reg  [DATA_WIDTH-1:0]        read_data,
    
    // GPIO pins (bidirectional)
    inout  wire [NUM_PINS-1:0]          gpio_pins,
    
    // Interrupt output
    output wire                         gpio_interrupt
);

    // Register map
    localparam REG_DATA_OUT  = 3'h0;  // Output data register
    localparam REG_DATA_IN   = 3'h1;  // Input data register (read-only)
    localparam REG_DIR       = 3'h2;  // Direction register (0=input, 1=output)
    localparam REG_INT_EN    = 3'h3;  // Interrupt enable
    localparam REG_INT_STAT  = 3'h4;  // Interrupt status
    localparam REG_PULL_EN   = 3'h5;  // Pull enable
    localparam REG_PULL_DIR  = 3'h6;  // Pull direction (0=down, 1=up)
    
    // Internal registers
    reg [NUM_PINS-1:0] data_out;      // Output data
    reg [NUM_PINS-1:0] data_in;       // Input data (synchronized)
    reg [NUM_PINS-1:0] direction;     // 0=input, 1=output
    reg [NUM_PINS-1:0] int_enable;    // Interrupt enable per pin
    reg [NUM_PINS-1:0] int_status;    // Interrupt status
    reg [NUM_PINS-1:0] pull_enable;   // Pull resistor enable
    reg [NUM_PINS-1:0] pull_dir;      // Pull direction
    
    // Synchronization registers for input
    reg [NUM_PINS-1:0] gpio_sync1;
    reg [NUM_PINS-1:0] gpio_sync2;
    reg [NUM_PINS-1:0] data_in_prev;
    
    // Tri-state buffer control
    genvar i;
    generate
        for (i = 0; i < NUM_PINS; i = i + 1) begin : gpio_tristate
            assign gpio_pins[i] = direction[i] ? data_out[i] : 1'bz;
        end
    endgenerate
    
    // Input synchronization (2-stage to prevent metastability)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gpio_sync1 <= {NUM_PINS{1'b0}};
            gpio_sync2 <= {NUM_PINS{1'b0}};
            data_in <= {NUM_PINS{1'b0}};
            data_in_prev <= {NUM_PINS{1'b0}};
        end else begin
            gpio_sync1 <= gpio_pins;
            gpio_sync2 <= gpio_sync1;
            data_in <= gpio_sync2;
            data_in_prev <= data_in;
        end
    end
    
    // Edge detection for interrupts
    wire [NUM_PINS-1:0] rising_edge = data_in & ~data_in_prev;
    wire [NUM_PINS-1:0] falling_edge = ~data_in & data_in_prev;
    wire [NUM_PINS-1:0] any_edge = rising_edge | falling_edge;
    
    // Interrupt status update
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            int_status <= {NUM_PINS{1'b0}};
        end else begin
            // Set interrupt on edge detection
            int_status <= int_status | (any_edge & int_enable);
            
            // Clear on write to interrupt status register
            if (write_en && addr[2:0] == REG_INT_STAT) begin
                int_status <= int_status & ~write_data[NUM_PINS-1:0];
            end
        end
    end
    
    // Interrupt output (any enabled interrupt pending)
    assign gpio_interrupt = |(int_status & int_enable);
    
    // Register writes
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            data_out <= {NUM_PINS{1'b0}};
            direction <= {NUM_PINS{1'b0}};  // All inputs by default
            int_enable <= {NUM_PINS{1'b0}};
            pull_enable <= {NUM_PINS{1'b0}};
            pull_dir <= {NUM_PINS{1'b0}};
        end else if (write_en) begin
            case (addr[2:0])
                REG_DATA_OUT: data_out <= write_data[NUM_PINS-1:0];
                REG_DIR:      direction <= write_data[NUM_PINS-1:0];
                REG_INT_EN:   int_enable <= write_data[NUM_PINS-1:0];
                REG_PULL_EN:  pull_enable <= write_data[NUM_PINS-1:0];
                REG_PULL_DIR: pull_dir <= write_data[NUM_PINS-1:0];
                default: ;
            endcase
        end
    end
    
    // Register reads
    always @(*) begin
        read_data = {DATA_WIDTH{1'b0}};
        if (read_en) begin
            case (addr[2:0])
                REG_DATA_OUT: read_data[NUM_PINS-1:0] = data_out;
                REG_DATA_IN:  read_data[NUM_PINS-1:0] = data_in;
                REG_DIR:      read_data[NUM_PINS-1:0] = direction;
                REG_INT_EN:   read_data[NUM_PINS-1:0] = int_enable;
                REG_INT_STAT: read_data[NUM_PINS-1:0] = int_status;
                REG_PULL_EN:  read_data[NUM_PINS-1:0] = pull_enable;
                REG_PULL_DIR: read_data[NUM_PINS-1:0] = pull_dir;
                default:      read_data = {DATA_WIDTH{1'b0}};
            endcase
        end
    end
    
endmodule

// Simple GPIO (output-only)
module gpio_simple #(
    parameter NUM_PINS = 8
) (
    input  wire                         clk,
    input  wire                         rst_n,
    input  wire [NUM_PINS-1:0]          data_in,
    input  wire                         write_en,
    output reg  [NUM_PINS-1:0]          gpio_out
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gpio_out <= {NUM_PINS{1'b0}};
        end else if (write_en) begin
            gpio_out <= data_in;
        end
    end
    
endmodule

// GPIO with individual pin control
module gpio_individual #(
    parameter NUM_PINS = 16
) (
    input  wire                         clk,
    input  wire                         rst_n,
    
    // Per-pin control
    input  wire [NUM_PINS-1:0]          pin_set,      // Set pin high
    input  wire [NUM_PINS-1:0]          pin_clear,    // Clear pin low
    input  wire [NUM_PINS-1:0]          pin_toggle,   // Toggle pin
    
    // GPIO output
    output reg  [NUM_PINS-1:0]          gpio_out
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            gpio_out <= {NUM_PINS{1'b0}};
        end else begin
            gpio_out <= (gpio_out | pin_set) & ~pin_clear;
            gpio_out <= gpio_out ^ pin_toggle;
        end
    end
    
endmodule

// GPIO Testbench
module gpio_tb;
    reg clk, rst_n;
    reg [31:0] addr, write_data;
    reg write_en, read_en;
    wire [31:0] read_data;
    wire [15:0] gpio_pins;
    wire gpio_interrupt;
    
    // Instantiate GPIO
    gpio #(.NUM_PINS(16)) dut (
        .clk(clk),
        .rst_n(rst_n),
        .addr(addr),
        .write_data(write_data),
        .write_en(write_en),
        .read_en(read_en),
        .read_data(read_data),
        .gpio_pins(gpio_pins),
        .gpio_interrupt(gpio_interrupt)
    );
    
    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;
    
    // Test stimulus
    initial begin
        $display("GPIO Testbench Starting...");
        
        // Reset
        rst_n = 0;
        addr = 0;
        write_data = 0;
        write_en = 0;
        read_en = 0;
        #20;
        rst_n = 1;
        #10;
        
        // Test 1: Configure pins as outputs
        $display("Test 1: Configure pins 0-7 as outputs");
        addr = 32'h2;  // DIR register
        write_data = 32'h00FF;
        write_en = 1;
        #10;
        write_en = 0;
        #10;
        
        // Test 2: Write output data
        $display("Test 2: Write 0xAA to output");
        addr = 32'h0;  // DATA_OUT register
        write_data = 32'h00AA;
        write_en = 1;
        #10;
        write_en = 0;
        #10;
        
        // Test 3: Read input data
        $display("Test 3: Read input data");
        addr = 32'h1;  // DATA_IN register
        read_en = 1;
        #10;
        $display("Input data: 0x%h", read_data);
        read_en = 0;
        #10;
        
        $display("GPIO Testbench Complete!");
        $finish;
    end
    
endmodule

// =============================================================================
// Usage Examples:
// =============================================================================
//
// Example 1: Basic GPIO
//   gpio #(.NUM_PINS(16)) gpio_ctrl (
//       .clk(clk),
//       .rst_n(rst_n),
//       .addr(gpio_addr),
//       .write_data(gpio_wdata),
//       .write_en(gpio_wr),
//       .read_en(gpio_rd),
//       .read_data(gpio_rdata),
//       .gpio_pins(gpio_io),
//       .gpio_interrupt(gpio_irq)
//   );
//
// =============================================================================

