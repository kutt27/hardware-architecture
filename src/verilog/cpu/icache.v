// =============================================================================
// Instruction Cache - Direct-Mapped
// =============================================================================
// Description:
//   Direct-mapped instruction cache with configurable size.
//   Implements write-through policy for simplicity.
//
// Learning Points:
//   - Cache organization (tag, index, offset)
//   - Cache hit/miss detection
//   - Valid bit management
//   - Direct-mapped addressing
//
// Author: ARM7 Computer System Project
// Date: 2025-11-03
// =============================================================================

module icache #(
    parameter CACHE_SIZE = 4096,      // 4KB cache
    parameter LINE_SIZE = 16,         // 16 bytes per line (4 words)
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    input  wire                         clk,
    input  wire                         rst_n,
    
    // CPU interface
    input  wire [ADDR_WIDTH-1:0]        cpu_addr,
    input  wire                         cpu_read_en,
    output reg  [DATA_WIDTH-1:0]        cpu_read_data,
    output wire                         cpu_ready,
    
    // Memory interface
    output reg  [ADDR_WIDTH-1:0]        mem_addr,
    output reg                          mem_read_en,
    input  wire [DATA_WIDTH-1:0]        mem_read_data,
    input  wire                         mem_ready,
    
    // Statistics
    output reg  [31:0]                  cache_hits,
    output reg  [31:0]                  cache_misses
);

    // Cache parameters
    localparam NUM_LINES = CACHE_SIZE / LINE_SIZE;
    localparam WORDS_PER_LINE = LINE_SIZE / (DATA_WIDTH / 8);
    localparam OFFSET_BITS = $clog2(LINE_SIZE);
    localparam INDEX_BITS = $clog2(NUM_LINES);
    localparam TAG_BITS = ADDR_WIDTH - INDEX_BITS - OFFSET_BITS;
    
    // Address breakdown
    wire [TAG_BITS-1:0] addr_tag = cpu_addr[ADDR_WIDTH-1:INDEX_BITS+OFFSET_BITS];
    wire [INDEX_BITS-1:0] addr_index = cpu_addr[INDEX_BITS+OFFSET_BITS-1:OFFSET_BITS];
    wire [OFFSET_BITS-1:0] addr_offset = cpu_addr[OFFSET_BITS-1:0];
    wire [1:0] word_offset = cpu_addr[OFFSET_BITS-1:2];
    
    // Cache storage
    reg [TAG_BITS-1:0] tag_array [0:NUM_LINES-1];
    reg valid_array [0:NUM_LINES-1];
    reg [DATA_WIDTH-1:0] data_array [0:NUM_LINES-1][0:WORDS_PER_LINE-1];
    
    // Cache state machine
    localparam STATE_IDLE = 2'b00;
    localparam STATE_COMPARE = 2'b01;
    localparam STATE_ALLOCATE = 2'b10;
    
    reg [1:0] state;
    reg [1:0] word_count;
    
    // Hit detection
    wire cache_hit = valid_array[addr_index] && 
                     (tag_array[addr_index] == addr_tag);
    wire cache_miss = cpu_read_en && !cache_hit;
    
    // Output ready signal
    assign cpu_ready = (state == STATE_IDLE && cache_hit) || 
                       (state == STATE_ALLOCATE && word_count == WORDS_PER_LINE-1 && mem_ready);
    
    // Cache read
    always @(*) begin
        if (cache_hit) begin
            cpu_read_data = data_array[addr_index][word_offset];
        end else begin
            cpu_read_data = 32'h00000000;
        end
    end
    
    // Cache state machine
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= STATE_IDLE;
            word_count <= 2'b00;
            mem_read_en <= 1'b0;
            mem_addr <= 32'h00000000;
            cache_hits <= 32'h00000000;
            cache_misses <= 32'h00000000;
        end else begin
            case (state)
                STATE_IDLE: begin
                    if (cpu_read_en) begin
                        if (cache_hit) begin
                            cache_hits <= cache_hits + 1;
                            state <= STATE_IDLE;
                        end else begin
                            cache_misses <= cache_misses + 1;
                            state <= STATE_ALLOCATE;
                            word_count <= 2'b00;
                            mem_addr <= {cpu_addr[ADDR_WIDTH-1:OFFSET_BITS], {OFFSET_BITS{1'b0}}};
                            mem_read_en <= 1'b1;
                        end
                    end
                end
                
                STATE_ALLOCATE: begin
                    if (mem_ready) begin
                        // Store word in cache
                        data_array[addr_index][word_count] <= mem_read_data;
                        
                        if (word_count == WORDS_PER_LINE-1) begin
                            // Last word - update tag and valid bit
                            tag_array[addr_index] <= addr_tag;
                            valid_array[addr_index] <= 1'b1;
                            mem_read_en <= 1'b0;
                            state <= STATE_IDLE;
                        end else begin
                            // Fetch next word
                            word_count <= word_count + 1;
                            mem_addr <= mem_addr + 4;
                        end
                    end
                end
                
                default: state <= STATE_IDLE;
            endcase
        end
    end
    
    // Initialize valid bits
    integer i;
    initial begin
        for (i = 0; i < NUM_LINES; i = i + 1) begin
            valid_array[i] = 1'b0;
        end
    end
    
endmodule

// Simple instruction cache (smaller, for testing)
module icache_simple #(
    parameter NUM_LINES = 64,
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    input  wire                         clk,
    input  wire                         rst_n,
    input  wire [ADDR_WIDTH-1:0]        addr,
    input  wire                         read_en,
    output reg  [DATA_WIDTH-1:0]        read_data,
    output wire                         hit,
    
    // Memory interface
    output wire [ADDR_WIDTH-1:0]        mem_addr,
    output wire                         mem_read_en,
    input  wire [DATA_WIDTH-1:0]        mem_read_data,
    input  wire                         mem_ready
);

    localparam INDEX_BITS = $clog2(NUM_LINES);
    localparam TAG_BITS = ADDR_WIDTH - INDEX_BITS - 2;  // -2 for word alignment
    
    wire [TAG_BITS-1:0] addr_tag = addr[ADDR_WIDTH-1:INDEX_BITS+2];
    wire [INDEX_BITS-1:0] addr_index = addr[INDEX_BITS+1:2];
    
    reg [TAG_BITS-1:0] tag_array [0:NUM_LINES-1];
    reg valid_array [0:NUM_LINES-1];
    reg [DATA_WIDTH-1:0] data_array [0:NUM_LINES-1];
    
    wire cache_hit = valid_array[addr_index] && (tag_array[addr_index] == addr_tag);
    assign hit = cache_hit && read_en;
    
    reg miss_pending;
    
    assign mem_addr = addr;
    assign mem_read_en = read_en && !cache_hit && !miss_pending;
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            miss_pending <= 1'b0;
        end else begin
            if (mem_read_en) begin
                miss_pending <= 1'b1;
            end else if (mem_ready && miss_pending) begin
                data_array[addr_index] <= mem_read_data;
                tag_array[addr_index] <= addr_tag;
                valid_array[addr_index] <= 1'b1;
                miss_pending <= 1'b0;
            end
        end
    end
    
    always @(*) begin
        if (cache_hit) begin
            read_data = data_array[addr_index];
        end else if (mem_ready && miss_pending) begin
            read_data = mem_read_data;
        end else begin
            read_data = 32'h00000000;
        end
    end
    
    integer i;
    initial begin
        for (i = 0; i < NUM_LINES; i = i + 1) begin
            valid_array[i] = 1'b0;
        end
    end
    
endmodule

// Data cache (write-through)
module dcache #(
    parameter NUM_LINES = 64,
    parameter ADDR_WIDTH = 32,
    parameter DATA_WIDTH = 32
) (
    input  wire                         clk,
    input  wire                         rst_n,
    
    // CPU interface
    input  wire [ADDR_WIDTH-1:0]        cpu_addr,
    input  wire [DATA_WIDTH-1:0]        cpu_write_data,
    input  wire                         cpu_read_en,
    input  wire                         cpu_write_en,
    output reg  [DATA_WIDTH-1:0]        cpu_read_data,
    output wire                         cpu_ready,
    
    // Memory interface
    output reg  [ADDR_WIDTH-1:0]        mem_addr,
    output reg  [DATA_WIDTH-1:0]        mem_write_data,
    output reg                          mem_read_en,
    output reg                          mem_write_en,
    input  wire [DATA_WIDTH-1:0]        mem_read_data,
    input  wire                         mem_ready
);

    localparam INDEX_BITS = $clog2(NUM_LINES);
    localparam TAG_BITS = ADDR_WIDTH - INDEX_BITS - 2;
    
    wire [TAG_BITS-1:0] addr_tag = cpu_addr[ADDR_WIDTH-1:INDEX_BITS+2];
    wire [INDEX_BITS-1:0] addr_index = cpu_addr[INDEX_BITS+1:2];
    
    reg [TAG_BITS-1:0] tag_array [0:NUM_LINES-1];
    reg valid_array [0:NUM_LINES-1];
    reg [DATA_WIDTH-1:0] data_array [0:NUM_LINES-1];
    
    wire cache_hit = valid_array[addr_index] && (tag_array[addr_index] == addr_tag);
    
    reg pending;
    
    assign cpu_ready = (cache_hit && !pending) || (mem_ready && pending);
    
    // Read logic
    always @(*) begin
        if (cache_hit && cpu_read_en) begin
            cpu_read_data = data_array[addr_index];
        end else if (mem_ready && pending) begin
            cpu_read_data = mem_read_data;
        end else begin
            cpu_read_data = 32'h00000000;
        end
    end
    
    // Cache control
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pending <= 1'b0;
            mem_read_en <= 1'b0;
            mem_write_en <= 1'b0;
        end else begin
            if (cpu_write_en) begin
                // Write-through: always write to memory
                mem_addr <= cpu_addr;
                mem_write_data <= cpu_write_data;
                mem_write_en <= 1'b1;
                pending <= 1'b1;
                
                // Update cache if hit
                if (cache_hit) begin
                    data_array[addr_index] <= cpu_write_data;
                end
            end else if (cpu_read_en && !cache_hit) begin
                // Read miss: fetch from memory
                mem_addr <= cpu_addr;
                mem_read_en <= 1'b1;
                pending <= 1'b1;
            end else if (mem_ready && pending) begin
                // Complete pending operation
                mem_read_en <= 1'b0;
                mem_write_en <= 1'b0;
                pending <= 1'b0;
                
                // On read miss, update cache
                if (mem_read_en) begin
                    data_array[addr_index] <= mem_read_data;
                    tag_array[addr_index] <= addr_tag;
                    valid_array[addr_index] <= 1'b1;
                end
            end
        end
    end
    
    integer i;
    initial begin
        for (i = 0; i < NUM_LINES; i = i + 1) begin
            valid_array[i] = 1'b0;
        end
    end
    
endmodule

// =============================================================================
// Usage Examples:
// =============================================================================
//
// icache #(.CACHE_SIZE(4096)) i_cache (
//     .clk(clk), .rst_n(rst_n),
//     .cpu_addr(pc), .cpu_read_en(fetch_en),
//     .cpu_read_data(instruction), .cpu_ready(i_ready),
//     .mem_addr(imem_addr), .mem_read_en(imem_rd),
//     .mem_read_data(imem_data), .mem_ready(imem_ready)
// );
//
// =============================================================================

