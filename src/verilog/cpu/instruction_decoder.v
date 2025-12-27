// =============================================================================
// ARM7 Instruction Decoder
// =============================================================================
// Description:
//   Decodes ARM7 instructions and generates control signals for the datapath.
//   Supports data processing, branch, load/store, and multiply instructions.
//
// Learning Points:
//   - Instruction format decoding
//   - Control signal generation
//   - Condition code evaluation
//   - ARM7 instruction encoding
//
// Author: ARM7 Computer System Project
// Date: 2025-11-03
// =============================================================================

module instruction_decoder (
    input  wire [31:0]  instruction,    // Instruction to decode
    input  wire [3:0]   cpsr_flags,     // Current flags (N, Z, C, V)
    
    // Decoded instruction fields
    output wire [3:0]   cond,           // Condition code
    output wire [1:0]   op_type,        // Operation type
    output wire [3:0]   opcode,         // ALU opcode
    output wire         s_bit,          // Set flags
    output wire [3:0]   rn,             // First operand register
    output wire [3:0]   rd,             // Destination register
    output wire [3:0]   rm,             // Second operand register
    output wire [11:0]  imm12,          // 12-bit immediate
    output wire [23:0]  offset24,       // 24-bit branch offset
    
    // Control signals
    output wire         reg_write,      // Write to register file
    output wire         mem_read,       // Read from memory
    output wire         mem_write,      // Write to memory
    output wire         alu_src,        // ALU source (0=reg, 1=imm)
    output wire         branch,         // Branch instruction
    output wire         branch_link,    // Branch with link
    output wire         condition_pass, // Condition satisfied
    
    // Shift control
    output wire [1:0]   shift_type,     // Shift type
    output wire [4:0]   shift_amt       // Shift amount
);

    // Instruction format fields
    assign cond = instruction[31:28];
    assign op_type = instruction[27:26];
    assign s_bit = instruction[20];
    assign rn = instruction[19:16];
    assign rd = instruction[15:12];
    assign rm = instruction[3:0];
    assign imm12 = instruction[11:0];
    assign offset24 = instruction[23:0];
    
    // Data processing fields
    assign opcode = instruction[24:21];
    wire i_bit = instruction[25];  // Immediate operand
    
    // Shift fields
    assign shift_type = instruction[6:5];
    assign shift_amt = instruction[11:7];
    
    // Operation type encoding
    localparam OP_DATA_PROC = 2'b00;
    localparam OP_LOAD_STORE = 2'b01;
    localparam OP_BRANCH = 2'b10;
    localparam OP_COPROCESSOR = 2'b11;
    
    // Condition code evaluation
    wire n_flag = cpsr_flags[3];
    wire z_flag = cpsr_flags[2];
    wire c_flag = cpsr_flags[1];
    wire v_flag = cpsr_flags[0];
    
    reg cond_satisfied;
    always @(*) begin
        case (cond)
            4'b0000: cond_satisfied = z_flag;                    // EQ
            4'b0001: cond_satisfied = ~z_flag;                   // NE
            4'b0010: cond_satisfied = c_flag;                    // CS/HS
            4'b0011: cond_satisfied = ~c_flag;                   // CC/LO
            4'b0100: cond_satisfied = n_flag;                    // MI
            4'b0101: cond_satisfied = ~n_flag;                   // PL
            4'b0110: cond_satisfied = v_flag;                    // VS
            4'b0111: cond_satisfied = ~v_flag;                   // VC
            4'b1000: cond_satisfied = c_flag & ~z_flag;          // HI
            4'b1001: cond_satisfied = ~c_flag | z_flag;          // LS
            4'b1010: cond_satisfied = (n_flag == v_flag);        // GE
            4'b1011: cond_satisfied = (n_flag != v_flag);        // LT
            4'b1100: cond_satisfied = ~z_flag & (n_flag == v_flag); // GT
            4'b1101: cond_satisfied = z_flag | (n_flag != v_flag);  // LE
            4'b1110: cond_satisfied = 1'b1;                      // AL (always)
            4'b1111: cond_satisfied = 1'b0;                      // NV (never)
            default: cond_satisfied = 1'b0;
        endcase
    end
    
    assign condition_pass = cond_satisfied;
    
    // Control signal generation
    wire is_data_proc = (op_type == OP_DATA_PROC);
    wire is_load_store = (op_type == OP_LOAD_STORE);
    wire is_branch = (op_type == OP_BRANCH);
    
    wire l_bit = instruction[20];  // Load (1) or Store (0)
    wire link_bit = instruction[24];  // Branch with link
    
    // Data processing opcodes that don't write to Rd
    wire is_test_op = (opcode == 4'b1000) ||  // TST
                      (opcode == 4'b1001) ||  // TEQ
                      (opcode == 4'b1010) ||  // CMP
                      (opcode == 4'b1011);    // CMN
    
    // Register write control
    assign reg_write = condition_pass & (
        (is_data_proc & ~is_test_op) |  // Data proc (except test ops)
        (is_load_store & l_bit) |        // Load instruction
        (is_branch & link_bit)           // Branch with link (write LR)
    );
    
    // Memory control
    assign mem_read = condition_pass & is_load_store & l_bit;
    assign mem_write = condition_pass & is_load_store & ~l_bit;
    
    // ALU source (immediate or register)
    assign alu_src = is_data_proc & i_bit;
    
    // Branch control
    assign branch = condition_pass & is_branch;
    assign branch_link = link_bit;
    
endmodule

// Instruction Decoder with Pipeline Registers
module instruction_decoder_pipelined (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         stall,          // Pipeline stall
    input  wire         flush,          // Pipeline flush
    
    input  wire [31:0]  instruction_in,
    input  wire [3:0]   cpsr_flags,
    
    // Decoded outputs (registered)
    output reg  [3:0]   cond_out,
    output reg  [3:0]   opcode_out,
    output reg          s_bit_out,
    output reg  [3:0]   rn_out,
    output reg  [3:0]   rd_out,
    output reg  [3:0]   rm_out,
    output reg  [11:0]  imm12_out,
    
    // Control signals (registered)
    output reg          reg_write_out,
    output reg          mem_read_out,
    output reg          mem_write_out,
    output reg          alu_src_out,
    output reg          branch_out,
    output reg          condition_pass_out
);

    // Instantiate combinational decoder
    wire [3:0]  cond_comb;
    wire [1:0]  op_type_comb;
    wire [3:0]  opcode_comb;
    wire        s_bit_comb;
    wire [3:0]  rn_comb, rd_comb, rm_comb;
    wire [11:0] imm12_comb;
    wire [23:0] offset24_comb;
    wire        reg_write_comb, mem_read_comb, mem_write_comb;
    wire        alu_src_comb, branch_comb, branch_link_comb;
    wire        condition_pass_comb;
    wire [1:0]  shift_type_comb;
    wire [4:0]  shift_amt_comb;
    
    instruction_decoder decoder (
        .instruction(instruction_in),
        .cpsr_flags(cpsr_flags),
        .cond(cond_comb),
        .op_type(op_type_comb),
        .opcode(opcode_comb),
        .s_bit(s_bit_comb),
        .rn(rn_comb),
        .rd(rd_comb),
        .rm(rm_comb),
        .imm12(imm12_comb),
        .offset24(offset24_comb),
        .reg_write(reg_write_comb),
        .mem_read(mem_read_comb),
        .mem_write(mem_write_comb),
        .alu_src(alu_src_comb),
        .branch(branch_comb),
        .branch_link(branch_link_comb),
        .condition_pass(condition_pass_comb),
        .shift_type(shift_type_comb),
        .shift_amt(shift_amt_comb)
    );
    
    // Pipeline register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cond_out <= 4'b0;
            opcode_out <= 4'b0;
            s_bit_out <= 1'b0;
            rn_out <= 4'b0;
            rd_out <= 4'b0;
            rm_out <= 4'b0;
            imm12_out <= 12'b0;
            reg_write_out <= 1'b0;
            mem_read_out <= 1'b0;
            mem_write_out <= 1'b0;
            alu_src_out <= 1'b0;
            branch_out <= 1'b0;
            condition_pass_out <= 1'b0;
        end else if (flush) begin
            // Insert NOP on flush
            reg_write_out <= 1'b0;
            mem_read_out <= 1'b0;
            mem_write_out <= 1'b0;
            branch_out <= 1'b0;
        end else if (!stall) begin
            cond_out <= cond_comb;
            opcode_out <= opcode_comb;
            s_bit_out <= s_bit_comb;
            rn_out <= rn_comb;
            rd_out <= rd_comb;
            rm_out <= rm_comb;
            imm12_out <= imm12_comb;
            reg_write_out <= reg_write_comb;
            mem_read_out <= mem_read_comb;
            mem_write_out <= mem_write_comb;
            alu_src_out <= alu_src_comb;
            branch_out <= branch_comb;
            condition_pass_out <= condition_pass_comb;
        end
    end
    
endmodule

// =============================================================================
// Usage Examples:
// =============================================================================
//
// Example 1: Basic instruction decoder
//   instruction_decoder decoder (
//       .instruction(fetched_instruction),
//       .cpsr_flags({n_flag, z_flag, c_flag, v_flag}),
//       .opcode(alu_opcode),
//       .reg_write(write_enable),
//       .condition_pass(execute_instruction),
//       // ... other outputs
//   );
//
// Example 2: Pipelined decoder for CPU
//   instruction_decoder_pipelined decode_stage (
//       .clk(clk),
//       .rst_n(rst_n),
//       .stall(pipeline_stall),
//       .flush(branch_taken),
//       .instruction_in(if_id_instruction),
//       .cpsr_flags(current_flags),
//       .opcode_out(id_ex_opcode),
//       .reg_write_out(id_ex_reg_write),
//       // ... other outputs
//   );
//
// =============================================================================

