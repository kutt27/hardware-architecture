// =============================================================================
// Finite State Machines (FSM)
// =============================================================================
// Description:
//   Implements Moore and Mealy state machine templates and examples.
//   State machines are essential for control logic in digital systems.
//
// Learning Points:
//   - Moore vs Mealy machine architectures
//   - State encoding strategies (binary, one-hot, Gray code)
//   - Next-state logic vs output logic separation
//   - Practical FSM design patterns
//
// Author: ARM7 Computer System Project
// Date: 2025-11-03
// =============================================================================

// Moore Machine Template
// Output depends only on current state
module moore_fsm #(
    parameter NUM_STATES = 4,
    parameter STATE_BITS = 2
) (
    input  wire                     clk,
    input  wire                     rst_n,
    input  wire                     input_signal,
    output reg  [STATE_BITS-1:0]    current_state,
    output wire                     output_signal
);
    // State encoding
    localparam STATE_IDLE  = 2'b00;
    localparam STATE_PROC1 = 2'b01;
    localparam STATE_PROC2 = 2'b10;
    localparam STATE_DONE  = 2'b11;
    
    reg [STATE_BITS-1:0] next_state;
    
    // State register (sequential logic)
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= STATE_IDLE;
        end else begin
            current_state <= next_state;
        end
    end
    
    // Next state logic (combinational)
    always @(*) begin
        case (current_state)
            STATE_IDLE: begin
                if (input_signal)
                    next_state = STATE_PROC1;
                else
                    next_state = STATE_IDLE;
            end
            
            STATE_PROC1: begin
                next_state = STATE_PROC2;
            end
            
            STATE_PROC2: begin
                next_state = STATE_DONE;
            end
            
            STATE_DONE: begin
                if (input_signal)
                    next_state = STATE_IDLE;
                else
                    next_state = STATE_DONE;
            end
            
            default: next_state = STATE_IDLE;
        endcase
    end
    
    // Output logic (depends only on state - Moore characteristic)
    assign output_signal = (current_state == STATE_DONE);
endmodule

// Mealy Machine Template
// Output depends on both current state and inputs
module mealy_fsm #(
    parameter STATE_BITS = 2
) (
    input  wire                     clk,
    input  wire                     rst_n,
    input  wire                     input_signal,
    output reg  [STATE_BITS-1:0]    current_state,
    output reg                      output_signal
);
    localparam STATE_IDLE  = 2'b00;
    localparam STATE_PROC1 = 2'b01;
    localparam STATE_PROC2 = 2'b10;
    localparam STATE_DONE  = 2'b11;
    
    reg [STATE_BITS-1:0] next_state;
    
    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_state <= STATE_IDLE;
        end else begin
            current_state <= next_state;
        end
    end
    
    // Next state and output logic (combinational)
    always @(*) begin
        // Default values
        next_state = current_state;
        output_signal = 1'b0;
        
        case (current_state)
            STATE_IDLE: begin
                if (input_signal) begin
                    next_state = STATE_PROC1;
                    output_signal = 1'b1;  // Output depends on input (Mealy)
                end
            end
            
            STATE_PROC1: begin
                next_state = STATE_PROC2;
                output_signal = input_signal;  // Output depends on input
            end
            
            STATE_PROC2: begin
                next_state = STATE_DONE;
            end
            
            STATE_DONE: begin
                if (input_signal) begin
                    next_state = STATE_IDLE;
                end
                output_signal = 1'b1;
            end
        endcase
    end
endmodule

// Traffic Light Controller - Practical Moore FSM Example
module traffic_light_controller (
    input  wire clk,
    input  wire rst_n,
    input  wire sensor,      // Car sensor on side street
    output reg  [1:0] main_light,   // 00=red, 01=yellow, 10=green
    output reg  [1:0] side_light
);
    // State encoding
    localparam MAIN_GREEN  = 3'b000;
    localparam MAIN_YELLOW = 3'b001;
    localparam SIDE_GREEN  = 3'b010;
    localparam SIDE_YELLOW = 3'b011;
    
    // Light encoding
    localparam RED    = 2'b00;
    localparam YELLOW = 2'b01;
    localparam GREEN  = 2'b10;
    
    reg [2:0] state, next_state;
    reg [7:0] timer;  // Simple timer for state duration
    
    // State register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= MAIN_GREEN;
            timer <= 8'd0;
        end else begin
            state <= next_state;
            if (state != next_state) begin
                timer <= 8'd0;  // Reset timer on state change
            end else begin
                timer <= timer + 1'b1;
            end
        end
    end
    
    // Next state logic
    always @(*) begin
        next_state = state;
        
        case (state)
            MAIN_GREEN: begin
                if (sensor && timer > 100) begin  // Min green time
                    next_state = MAIN_YELLOW;
                end
            end
            
            MAIN_YELLOW: begin
                if (timer > 20) begin  // Yellow duration
                    next_state = SIDE_GREEN;
                end
            end
            
            SIDE_GREEN: begin
                if (!sensor && timer > 50) begin  // Min green time
                    next_state = SIDE_YELLOW;
                end
            end
            
            SIDE_YELLOW: begin
                if (timer > 20) begin
                    next_state = MAIN_GREEN;
                end
            end
            
            default: next_state = MAIN_GREEN;
        endcase
    end
    
    // Output logic (Moore - depends only on state)
    always @(*) begin
        case (state)
            MAIN_GREEN: begin
                main_light = GREEN;
                side_light = RED;
            end
            
            MAIN_YELLOW: begin
                main_light = YELLOW;
                side_light = RED;
            end
            
            SIDE_GREEN: begin
                main_light = RED;
                side_light = GREEN;
            end
            
            SIDE_YELLOW: begin
                main_light = RED;
                side_light = YELLOW;
            end
            
            default: begin
                main_light = RED;
                side_light = RED;
            end
        endcase
    end
endmodule

// Sequence Detector - Detects pattern "1011"
module sequence_detector_1011 (
    input  wire clk,
    input  wire rst_n,
    input  wire data_in,
    output reg  pattern_detected
);
    // State encoding (one-hot for clarity)
    localparam S_IDLE = 4'b0001;  // Initial state
    localparam S_1    = 4'b0010;  // Seen "1"
    localparam S_10   = 4'b0100;  // Seen "10"
    localparam S_101  = 4'b1000;  // Seen "101"
    
    reg [3:0] state, next_state;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
        end else begin
            state <= next_state;
        end
    end
    
    always @(*) begin
        next_state = S_IDLE;
        pattern_detected = 1'b0;
        
        case (state)
            S_IDLE: begin
                if (data_in)
                    next_state = S_1;
                else
                    next_state = S_IDLE;
            end
            
            S_1: begin
                if (data_in)
                    next_state = S_1;  // Stay in S_1 for consecutive 1s
                else
                    next_state = S_10;
            end
            
            S_10: begin
                if (data_in)
                    next_state = S_101;
                else
                    next_state = S_IDLE;
            end
            
            S_101: begin
                if (data_in) begin
                    next_state = S_1;  // Pattern detected! Go back to S_1
                    pattern_detected = 1'b1;
                end else begin
                    next_state = S_10;
                end
            end
            
            default: next_state = S_IDLE;
        endcase
    end
endmodule

// =============================================================================
// Usage Examples:
// =============================================================================
//
// Example 1: UART state machine (simplified)
//   moore_fsm #(
//       .NUM_STATES(4),
//       .STATE_BITS(2)
//   ) uart_fsm (
//       .clk(clk),
//       .rst_n(rst_n),
//       .input_signal(rx_data_ready),
//       .current_state(uart_state),
//       .output_signal(tx_start)
//   );
//
// Example 2: Pattern detection for protocol decoding
//   sequence_detector_1011 protocol_detector (
//       .clk(clk),
//       .rst_n(rst_n),
//       .data_in(serial_data),
//       .pattern_detected(sync_found)
//   );
//
// =============================================================================

