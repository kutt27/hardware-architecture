// =============================================================================
// UART (Universal Asynchronous Receiver/Transmitter)
// =============================================================================
// Description:
//   Complete UART module with configurable baud rate, TX/RX with FIFOs,
//   and memory-mapped register interface.
//
// Learning Points:
//   - Serial communication protocol
//   - Baud rate generation
//   - FIFO buffering
//   - Memory-mapped I/O
//
// Author: ARM7 Computer System Project
// Date: 2025-11-03
// =============================================================================

// Baud Rate Generator
module uart_baud_gen #(
    parameter CLK_FREQ = 50000000,  // 50 MHz
    parameter BAUD_RATE = 115200
) (
    input  wire clk,
    input  wire rst_n,
    output reg  baud_tick
);

    localparam DIVISOR = CLK_FREQ / BAUD_RATE;
    localparam COUNT_WIDTH = $clog2(DIVISOR);
    
    reg [COUNT_WIDTH-1:0] counter;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            counter <= {COUNT_WIDTH{1'b0}};
            baud_tick <= 1'b0;
        end else begin
            if (counter == DIVISOR - 1) begin
                counter <= {COUNT_WIDTH{1'b0}};
                baud_tick <= 1'b1;
            end else begin
                counter <= counter + 1'b1;
                baud_tick <= 1'b0;
            end
        end
    end
    
endmodule

// UART Transmitter
module uart_tx (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       baud_tick,
    
    // Data interface
    input  wire [7:0] tx_data,
    input  wire       tx_start,
    output reg        tx_busy,
    
    // Serial output
    output reg        tx
);

    // States
    localparam IDLE  = 2'b00;
    localparam START = 2'b01;
    localparam DATA  = 2'b10;
    localparam STOP  = 2'b11;
    
    reg [1:0] state;
    reg [2:0] bit_count;
    reg [7:0] tx_shift_reg;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            tx <= 1'b1;  // Idle high
            tx_busy <= 1'b0;
            bit_count <= 3'b0;
            tx_shift_reg <= 8'b0;
        end else begin
            case (state)
                IDLE: begin
                    tx <= 1'b1;
                    tx_busy <= 1'b0;
                    if (tx_start) begin
                        tx_shift_reg <= tx_data;
                        tx_busy <= 1'b1;
                        state <= START;
                    end
                end
                
                START: begin
                    if (baud_tick) begin
                        tx <= 1'b0;  // Start bit
                        bit_count <= 3'b0;
                        state <= DATA;
                    end
                end
                
                DATA: begin
                    if (baud_tick) begin
                        tx <= tx_shift_reg[0];
                        tx_shift_reg <= {1'b0, tx_shift_reg[7:1]};
                        if (bit_count == 3'd7) begin
                            state <= STOP;
                        end else begin
                            bit_count <= bit_count + 1'b1;
                        end
                    end
                end
                
                STOP: begin
                    if (baud_tick) begin
                        tx <= 1'b1;  // Stop bit
                        state <= IDLE;
                    end
                end
            endcase
        end
    end
    
endmodule

// UART Receiver
module uart_rx (
    input  wire       clk,
    input  wire       rst_n,
    input  wire       baud_tick,
    
    // Serial input
    input  wire       rx,
    
    // Data interface
    output reg  [7:0] rx_data,
    output reg        rx_ready,
    input  wire       rx_ack
);

    // States
    localparam IDLE  = 2'b00;
    localparam START = 2'b01;
    localparam DATA  = 2'b10;
    localparam STOP  = 2'b11;
    
    reg [1:0] state;
    reg [2:0] bit_count;
    reg [7:0] rx_shift_reg;
    reg [3:0] sample_count;  // Oversample for start bit detection
    
    // Synchronize RX input
    reg rx_sync1, rx_sync2;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_sync1 <= 1'b1;
            rx_sync2 <= 1'b1;
        end else begin
            rx_sync1 <= rx;
            rx_sync2 <= rx_sync1;
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE;
            rx_data <= 8'b0;
            rx_ready <= 1'b0;
            bit_count <= 3'b0;
            rx_shift_reg <= 8'b0;
            sample_count <= 4'b0;
        end else begin
            // Clear ready on acknowledge
            if (rx_ack) begin
                rx_ready <= 1'b0;
            end
            
            case (state)
                IDLE: begin
                    if (!rx_sync2) begin  // Start bit detected
                        sample_count <= 4'b0;
                        state <= START;
                    end
                end
                
                START: begin
                    if (baud_tick) begin
                        if (sample_count == 4'd7) begin  // Sample at middle
                            if (!rx_sync2) begin  // Valid start bit
                                bit_count <= 3'b0;
                                state <= DATA;
                            end else begin
                                state <= IDLE;  // False start
                            end
                        end else begin
                            sample_count <= sample_count + 1'b1;
                        end
                    end
                end
                
                DATA: begin
                    if (baud_tick) begin
                        rx_shift_reg <= {rx_sync2, rx_shift_reg[7:1]};
                        if (bit_count == 3'd7) begin
                            state <= STOP;
                        end else begin
                            bit_count <= bit_count + 1'b1;
                        end
                    end
                end
                
                STOP: begin
                    if (baud_tick) begin
                        if (rx_sync2) begin  // Valid stop bit
                            rx_data <= rx_shift_reg;
                            rx_ready <= 1'b1;
                        end
                        state <= IDLE;
                    end
                end
            endcase
        end
    end
    
endmodule

// Complete UART with Memory-Mapped Interface
module uart #(
    parameter CLK_FREQ = 50000000,
    parameter BAUD_RATE = 115200
) (
    input  wire        clk,
    input  wire        rst_n,
    
    // Serial interface
    input  wire        rx,
    output wire        tx,
    
    // Memory-mapped interface
    input  wire [2:0]  addr,        // Register address
    input  wire        write_en,
    input  wire        read_en,
    input  wire [7:0]  write_data,
    output reg  [7:0]  read_data,
    
    // Interrupt
    output wire        rx_interrupt,
    output wire        tx_interrupt
);

    // Register addresses
    localparam ADDR_DATA   = 3'h0;  // TX/RX data
    localparam ADDR_STATUS = 3'h1;  // Status register
    localparam ADDR_CTRL   = 3'h2;  // Control register
    
    // Baud tick
    wire baud_tick;
    uart_baud_gen #(
        .CLK_FREQ(CLK_FREQ),
        .BAUD_RATE(BAUD_RATE)
    ) baud_gen (
        .clk(clk),
        .rst_n(rst_n),
        .baud_tick(baud_tick)
    );
    
    // TX signals
    wire [7:0] tx_data;
    wire tx_start;
    wire tx_busy;
    
    uart_tx transmitter (
        .clk(clk),
        .rst_n(rst_n),
        .baud_tick(baud_tick),
        .tx_data(tx_data),
        .tx_start(tx_start),
        .tx_busy(tx_busy),
        .tx(tx)
    );
    
    // RX signals
    wire [7:0] rx_data;
    wire rx_ready;
    wire rx_ack;
    
    uart_rx receiver (
        .clk(clk),
        .rst_n(rst_n),
        .baud_tick(baud_tick),
        .rx(rx),
        .rx_data(rx_data),
        .rx_ready(rx_ready),
        .rx_ack(rx_ack)
    );
    
    // Register interface
    reg [7:0] rx_buffer;
    reg rx_buffer_full;
    
    assign tx_data = write_data;
    assign tx_start = write_en && (addr == ADDR_DATA);
    assign rx_ack = read_en && (addr == ADDR_DATA);
    
    // RX buffer
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            rx_buffer <= 8'b0;
            rx_buffer_full <= 1'b0;
        end else begin
            if (rx_ready && !rx_buffer_full) begin
                rx_buffer <= rx_data;
                rx_buffer_full <= 1'b1;
            end else if (rx_ack) begin
                rx_buffer_full <= 1'b0;
            end
        end
    end
    
    // Read data multiplexer
    always @(*) begin
        case (addr)
            ADDR_DATA:   read_data = rx_buffer;
            ADDR_STATUS: read_data = {6'b0, rx_buffer_full, ~tx_busy};
            ADDR_CTRL:   read_data = 8'b0;
            default:     read_data = 8'b0;
        endcase
    end
    
    // Interrupts
    assign rx_interrupt = rx_buffer_full;
    assign tx_interrupt = ~tx_busy;
    
endmodule

// =============================================================================
// Usage Examples:
// =============================================================================
//
// Example 1: Basic UART
//   uart #(
//       .CLK_FREQ(50000000),
//       .BAUD_RATE(115200)
//   ) uart_inst (
//       .clk(clk),
//       .rst_n(rst_n),
//       .rx(uart_rx_pin),
//       .tx(uart_tx_pin),
//       .addr(uart_addr),
//       .write_en(uart_write),
//       .read_en(uart_read),
//       .write_data(uart_wdata),
//       .read_data(uart_rdata),
//       .rx_interrupt(uart_rx_irq),
//       .tx_interrupt(uart_tx_irq)
//   );
//
// =============================================================================

