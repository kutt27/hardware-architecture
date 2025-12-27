#!/usr/bin/env python3
"""
ARM7 Assembler - Main Module
=============================================================================
Description:
    Two-pass assembler for ARM7 instruction set. Converts assembly language
    to machine code with support for labels, directives, and macros.

Learning Points:
    - Two-pass assembly process
    - Symbol table management
    - Instruction encoding
    - Error handling and reporting

Author: ARM7 Computer System Project
Date: 2025-11-03
=============================================================================
"""

import sys
import re
from typing import Dict, List, Tuple, Optional

class SymbolTable:
    """Manages labels and their addresses"""
    
    def __init__(self):
        self.symbols: Dict[str, int] = {}
        
    def add(self, label: str, address: int) -> None:
        """Add a symbol to the table"""
        if label in self.symbols:
            raise ValueError(f"Duplicate label: {label}")
        self.symbols[label] = address
        
    def get(self, label: str) -> Optional[int]:
        """Get address of a label"""
        return self.symbols.get(label)
        
    def contains(self, label: str) -> bool:
        """Check if label exists"""
        return label in self.symbols


class ARM7Instruction:
    """Represents an ARM7 instruction encoding"""
    
    # Condition codes
    COND_EQ = 0b0000  # Equal
    COND_NE = 0b0001  # Not equal
    COND_CS = 0b0010  # Carry set
    COND_CC = 0b0011  # Carry clear
    COND_MI = 0b0100  # Minus/negative
    COND_PL = 0b0101  # Plus/positive
    COND_VS = 0b0110  # Overflow
    COND_VC = 0b0111  # No overflow
    COND_HI = 0b1000  # Unsigned higher
    COND_LS = 0b1001  # Unsigned lower or same
    COND_GE = 0b1010  # Signed greater or equal
    COND_LT = 0b1011  # Signed less than
    COND_GT = 0b1100  # Signed greater than
    COND_LE = 0b1101  # Signed less or equal
    COND_AL = 0b1110  # Always (default)
    
    # Data processing opcodes
    OP_AND = 0b0000
    OP_EOR = 0b0001
    OP_SUB = 0b0010
    OP_RSB = 0b0011
    OP_ADD = 0b0100
    OP_ADC = 0b0101
    OP_SBC = 0b0110
    OP_RSC = 0b0111
    OP_TST = 0b1000
    OP_TEQ = 0b1001
    OP_CMP = 0b1010
    OP_CMN = 0b1011
    OP_ORR = 0b1100
    OP_MOV = 0b1101
    OP_BIC = 0b1110
    OP_MVN = 0b1111
    
    @staticmethod
    def encode_data_processing(cond: int, opcode: int, s: int, rn: int, 
                               rd: int, operand2: int) -> int:
        """Encode data processing instruction"""
        # Format: [cond:4][00][I:1][opcode:4][S:1][Rn:4][Rd:4][operand2:12]
        instr = (cond << 28) | (0b00 << 26) | (opcode << 21) | (s << 20)
        instr |= (rn << 16) | (rd << 12) | operand2
        return instr
    
    @staticmethod
    def encode_branch(cond: int, link: int, offset: int) -> int:
        """Encode branch instruction"""
        # Format: [cond:4][101][L:1][offset:24]
        offset_24 = offset & 0xFFFFFF  # 24-bit signed offset
        instr = (cond << 28) | (0b101 << 25) | (link << 24) | offset_24
        return instr
    
    @staticmethod
    def encode_load_store(cond: int, p: int, u: int, b: int, w: int, l: int,
                          rn: int, rd: int, offset: int) -> int:
        """Encode load/store instruction"""
        # Format: [cond:4][01][I][P][U][B][W][L][Rn:4][Rd:4][offset:12]
        instr = (cond << 28) | (0b01 << 26) | (p << 24) | (u << 23)
        instr |= (b << 22) | (w << 21) | (l << 20)
        instr |= (rn << 16) | (rd << 12) | (offset & 0xFFF)
        return instr


class Assembler:
    """Main assembler class"""
    
    def __init__(self):
        self.symbol_table = SymbolTable()
        self.instructions: List[Tuple[int, str, str]] = []  # (address, line, original)
        self.machine_code: List[int] = []
        self.current_address = 0
        self.errors: List[str] = []
        
    def parse_register(self, reg_str: str) -> int:
        """Parse register name to number (R0-R15)"""
        reg_str = reg_str.upper().strip()
        
        # Handle special register names
        reg_map = {
            'SP': 13, 'LR': 14, 'PC': 15,
            'R13': 13, 'R14': 14, 'R15': 15
        }
        
        if reg_str in reg_map:
            return reg_map[reg_str]
        
        # Parse R0-R15
        match = re.match(r'R(\d+)', reg_str)
        if match:
            reg_num = int(match.group(1))
            if 0 <= reg_num <= 15:
                return reg_num
        
        raise ValueError(f"Invalid register: {reg_str}")
    
    def parse_immediate(self, imm_str: str) -> int:
        """Parse immediate value"""
        imm_str = imm_str.strip()
        
        # Handle #prefix
        if imm_str.startswith('#'):
            imm_str = imm_str[1:]
        
        # Parse hex, binary, or decimal
        if imm_str.startswith('0x') or imm_str.startswith('0X'):
            return int(imm_str, 16)
        elif imm_str.startswith('0b') or imm_str.startswith('0B'):
            return int(imm_str, 2)
        else:
            return int(imm_str)
    
    def parse_condition(self, mnemonic: str) -> Tuple[str, int]:
        """Extract condition code from mnemonic"""
        cond_map = {
            'EQ': ARM7Instruction.COND_EQ,
            'NE': ARM7Instruction.COND_NE,
            'CS': ARM7Instruction.COND_CS,
            'CC': ARM7Instruction.COND_CC,
            'MI': ARM7Instruction.COND_MI,
            'PL': ARM7Instruction.COND_PL,
            'VS': ARM7Instruction.COND_VS,
            'VC': ARM7Instruction.COND_VC,
            'HI': ARM7Instruction.COND_HI,
            'LS': ARM7Instruction.COND_LS,
            'GE': ARM7Instruction.COND_GE,
            'LT': ARM7Instruction.COND_LT,
            'GT': ARM7Instruction.COND_GT,
            'LE': ARM7Instruction.COND_LE,
        }
        
        # Check for condition suffix
        for suffix, code in cond_map.items():
            if mnemonic.upper().endswith(suffix):
                base = mnemonic[:-len(suffix)]
                return base, code
        
        # Default: always
        return mnemonic, ARM7Instruction.COND_AL
    
    def assemble_line(self, line: str, address: int) -> Optional[int]:
        """Assemble a single line of code"""
        # Remove comments
        if ';' in line:
            line = line[:line.index(';')]
        
        line = line.strip()
        if not line:
            return None
        
        # Parse instruction
        parts = re.split(r'[,\s]+', line)
        mnemonic = parts[0].upper()
        
        # Extract condition code
        base_mnemonic, cond = self.parse_condition(mnemonic)
        
        # Check for S suffix (update flags)
        s_flag = 0
        if base_mnemonic.endswith('S'):
            s_flag = 1
            base_mnemonic = base_mnemonic[:-1]
        
        try:
            # Data processing instructions
            if base_mnemonic in ['ADD', 'SUB', 'RSB', 'ADC', 'SBC', 'RSC',
                                 'AND', 'ORR', 'EOR', 'BIC', 'MOV', 'MVN',
                                 'TST', 'TEQ', 'CMP', 'CMN']:
                return self.assemble_data_processing(base_mnemonic, parts[1:],
                                                     cond, s_flag)

            # Branch instructions
            elif base_mnemonic in ['B', 'BL']:
                return self.assemble_branch(base_mnemonic, parts[1:],
                                           cond, address)

            # Load/Store instructions
            elif base_mnemonic in ['LDR', 'STR', 'LDRB', 'STRB']:
                return self.assemble_load_store(base_mnemonic, parts[1:], cond)

            else:
                self.errors.append(f"Unknown instruction: {mnemonic}")
                return 0
                
        except Exception as e:
            self.errors.append(f"Error assembling '{line}': {str(e)}")
            return 0
    
    def assemble_data_processing(self, mnemonic: str, operands: List[str],
                                 cond: int, s: int) -> int:
        """Assemble data processing instruction"""
        opcode_map = {
            'AND': ARM7Instruction.OP_AND,
            'EOR': ARM7Instruction.OP_EOR,
            'SUB': ARM7Instruction.OP_SUB,
            'RSB': 0b0011,  # Reverse subtract
            'ADD': ARM7Instruction.OP_ADD,
            'ADC': 0b0101,  # Add with carry
            'SBC': 0b0110,  # Subtract with carry
            'RSC': 0b0111,  # Reverse subtract with carry
            'TST': 0b1000,  # Test
            'TEQ': 0b1001,  # Test equivalence
            'CMP': 0b1010,  # Compare
            'CMN': 0b1011,  # Compare negative
            'ORR': ARM7Instruction.OP_ORR,
            'MOV': ARM7Instruction.OP_MOV,
            'BIC': 0b1110,  # Bit clear
            'MVN': 0b1111,  # Move not
        }

        opcode = opcode_map.get(mnemonic, 0)

        # MOV and MVN have different format: MOV Rd, operand2
        if mnemonic in ['MOV', 'MVN']:
            rd = self.parse_register(operands[0])
            # Check if operand2 is immediate or register
            if operands[1].startswith('#') or operands[1].isdigit():
                operand2 = self.parse_immediate(operands[1])
            else:
                # Register operand (encoded as shift by 0)
                rm = self.parse_register(operands[1])
                operand2 = rm  # Simple register, no shift
            return ARM7Instruction.encode_data_processing(cond, opcode, s,
                                                         0, rd, operand2)

        # CMP, CMN, TST, TEQ don't write to Rd
        if mnemonic in ['CMP', 'CMN', 'TST', 'TEQ']:
            rn = self.parse_register(operands[0])
            # Check if operand2 is immediate or register
            if operands[1].startswith('#') or operands[1].isdigit():
                operand2 = self.parse_immediate(operands[1])
            else:
                rm = self.parse_register(operands[1])
                operand2 = rm
            return ARM7Instruction.encode_data_processing(cond, opcode, 1,  # S=1 for compare
                                                         rn, 0, operand2)

        # Standard format: OP Rd, Rn, operand2
        rd = self.parse_register(operands[0])
        rn = self.parse_register(operands[1])

        # Check if operand2 is immediate or register
        if operands[2].startswith('#') or operands[2].isdigit():
            operand2 = self.parse_immediate(operands[2])
        else:
            # Register operand
            rm = self.parse_register(operands[2])
            operand2 = rm  # Simple register, no shift

        return ARM7Instruction.encode_data_processing(cond, opcode, s,
                                                     rn, rd, operand2)
    
    def assemble_branch(self, mnemonic: str, operands: List[str],
                       cond: int, current_addr: int) -> int:
        """Assemble branch instruction"""
        link = 1 if mnemonic == 'BL' else 0
        
        # Get target label
        target_label = operands[0]
        target_addr = self.symbol_table.get(target_label)
        
        if target_addr is None:
            # Forward reference - will be resolved in second pass
            offset = 0
        else:
            # Calculate offset (in words, PC+8 relative)
            offset = ((target_addr - current_addr - 8) >> 2) & 0xFFFFFF
        
        return ARM7Instruction.encode_branch(cond, link, offset)
    
    def assemble_load_store(self, mnemonic: str, operands: List[str],
                           cond: int) -> int:
        """Assemble load/store instruction"""
        l = 1 if mnemonic in ['LDR', 'LDRB'] else 0
        b = 1 if mnemonic in ['LDRB', 'STRB'] else 0  # Byte transfer
        rd = self.parse_register(operands[0])

        # Simple immediate offset: LDR Rd, [Rn, #offset]
        # Parse [Rn, #offset] or [Rn]
        addr_str = ' '.join(operands[1:]).replace('[', '').replace(']', '')
        addr_parts = addr_str.split(',')

        rn = self.parse_register(addr_parts[0])
        offset = 0 if len(addr_parts) == 1 else self.parse_immediate(addr_parts[1])

        # P=1 (pre-indexed), U=1 (add offset), W=0 (no writeback)
        return ARM7Instruction.encode_load_store(cond, 1, 1, b, 0, l,
                                                rn, rd, offset)
    
    def assemble(self, source_lines: List[str]) -> List[int]:
        """Two-pass assembly"""
        # Pass 1: Build symbol table
        address = 0
        for line in source_lines:
            # Remove comments
            if ';' in line:
                line = line[:line.index(';')]

            line = line.strip()
            if not line:
                continue

            # Skip directives
            if line.startswith('.'):
                continue

            # Check for label
            if ':' in line:
                label, rest = line.split(':', 1)
                self.symbol_table.add(label.strip(), address)
                line = rest.strip()

            # Store instruction for pass 2 only if there's content
            if line:
                self.instructions.append((address, line, line))
                address += 4

        # Pass 2: Generate machine code
        for address, line, original in self.instructions:
            machine_code = self.assemble_line(line, address)
            if machine_code is not None:
                self.machine_code.append(machine_code)

        return self.machine_code


def main():
    """Main entry point"""
    if len(sys.argv) < 2:
        print("Usage: assembler.py <input.s> [-o output.bin]")
        sys.exit(1)
    
    input_file = sys.argv[1]
    output_file = "output.bin"
    
    if '-o' in sys.argv:
        output_file = sys.argv[sys.argv.index('-o') + 1]
    
    # Read source file
    with open(input_file, 'r') as f:
        source_lines = f.readlines()
    
    # Assemble
    assembler = Assembler()
    machine_code = assembler.assemble(source_lines)
    
    # Report errors
    if assembler.errors:
        print("Assembly errors:")
        for error in assembler.errors:
            print(f"  {error}")
        sys.exit(1)
    
    # Write output
    with open(output_file, 'wb') as f:
        for instr in machine_code:
            f.write(instr.to_bytes(4, byteorder='little'))
    
    print(f"Assembly successful: {len(machine_code)} instructions")
    print(f"Output written to: {output_file}")


if __name__ == '__main__':
    main()

