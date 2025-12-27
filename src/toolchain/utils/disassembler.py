#!/usr/bin/env python3
"""
ARM7 Disassembler - Converts machine code back to assembly

Features:
- Disassemble ARM7 instructions
- Symbol table support
- Address labels
- Formatted output

Author: ARM7 Computer System Project
Date: 2025-11-03
"""

import sys
import struct
import argparse
from typing import Dict, Optional

class ARM7Disassembler:
    """ARM7 instruction disassembler"""
    
    # Condition codes
    COND_CODES = {
        0b0000: 'EQ', 0b0001: 'NE', 0b0010: 'CS', 0b0011: 'CC',
        0b0100: 'MI', 0b0101: 'PL', 0b0110: 'VS', 0b0111: 'VC',
        0b1000: 'HI', 0b1001: 'LS', 0b1010: 'GE', 0b1011: 'LT',
        0b1100: 'GT', 0b1101: 'LE', 0b1110: '',   0b1111: 'NV'
    }
    
    # Data processing opcodes
    DP_OPCODES = {
        0b0000: 'AND', 0b0001: 'EOR', 0b0010: 'SUB', 0b0011: 'RSB',
        0b0100: 'ADD', 0b0101: 'ADC', 0b0110: 'SBC', 0b0111: 'RSC',
        0b1000: 'TST', 0b1001: 'TEQ', 0b1010: 'CMP', 0b1011: 'CMN',
        0b1100: 'ORR', 0b1101: 'MOV', 0b1110: 'BIC', 0b1111: 'MVN'
    }
    
    # Shift types
    SHIFT_TYPES = {
        0b00: 'LSL', 0b01: 'LSR', 0b10: 'ASR', 0b11: 'ROR'
    }
    
    def __init__(self, symbols: Dict[int, str] = None):
        self.symbols = symbols or {}
        self.base_addr = 0
    
    def disassemble_instruction(self, instr: int, addr: int) -> str:
        """Disassemble a single instruction"""
        # Extract condition code
        cond = (instr >> 28) & 0xF
        cond_str = self.COND_CODES.get(cond, '??')
        
        # Determine instruction type
        if (instr & 0x0C000000) == 0x00000000:
            # Data processing or multiply
            if (instr & 0x0FC000F0) == 0x00000090:
                return self.disasm_multiply(instr, cond_str)
            else:
                return self.disasm_data_processing(instr, cond_str)
        
        elif (instr & 0x0C000000) == 0x04000000:
            # Load/store
            return self.disasm_load_store(instr, cond_str)
        
        elif (instr & 0x0E000000) == 0x08000000:
            # Load/store multiple
            return self.disasm_ldm_stm(instr, cond_str)
        
        elif (instr & 0x0E000000) == 0x0A000000:
            # Branch
            return self.disasm_branch(instr, cond_str, addr)
        
        elif (instr & 0x0F000000) == 0x0F000000:
            # Software interrupt
            return self.disasm_swi(instr, cond_str)
        
        else:
            return f"UNKNOWN  0x{instr:08X}"
    
    def disasm_data_processing(self, instr: int, cond: str) -> str:
        """Disassemble data processing instruction"""
        opcode = (instr >> 21) & 0xF
        s_bit = (instr >> 20) & 1
        rn = (instr >> 16) & 0xF
        rd = (instr >> 12) & 0xF
        imm_flag = (instr >> 25) & 1
        
        mnemonic = self.DP_OPCODES.get(opcode, 'UNK')
        s_suffix = 'S' if s_bit else ''
        
        # Test operations don't have destination
        is_test = opcode in [0b1000, 0b1001, 0b1010, 0b1011]
        
        # MOV/MVN don't use first operand
        is_move = opcode in [0b1101, 0b1111]
        
        result = f"{mnemonic}{cond}{s_suffix}"
        
        if not is_test:
            result += f" R{rd},"
        
        if not is_move:
            result += f" R{rn},"
        
        # Second operand
        if imm_flag:
            # Immediate
            imm8 = instr & 0xFF
            rotate = ((instr >> 8) & 0xF) * 2
            value = self.rotate_right(imm8, rotate)
            result += f" #0x{value:X}"
        else:
            # Register
            rm = instr & 0xF
            shift_type = (instr >> 5) & 0x3
            shift_imm = (instr >> 7) & 0x1F
            
            result += f" R{rm}"
            
            if shift_imm != 0:
                shift_name = self.SHIFT_TYPES[shift_type]
                result += f", {shift_name} #{shift_imm}"
        
        return result
    
    def disasm_multiply(self, instr: int, cond: str) -> str:
        """Disassemble multiply instruction"""
        rd = (instr >> 16) & 0xF
        rn = (instr >> 12) & 0xF
        rs = (instr >> 8) & 0xF
        rm = instr & 0xF
        
        return f"MUL{cond} R{rd}, R{rm}, R{rs}"
    
    def disasm_load_store(self, instr: int, cond: str) -> str:
        """Disassemble load/store instruction"""
        is_load = (instr >> 20) & 1
        is_byte = (instr >> 22) & 1
        rn = (instr >> 16) & 0xF
        rd = (instr >> 12) & 0xF
        
        mnemonic = 'LDR' if is_load else 'STR'
        if is_byte:
            mnemonic += 'B'
        
        # Offset
        offset = instr & 0xFFF
        
        return f"{mnemonic}{cond} R{rd}, [R{rn}, #0x{offset:X}]"
    
    def disasm_ldm_stm(self, instr: int, cond: str) -> str:
        """Disassemble load/store multiple"""
        is_load = (instr >> 20) & 1
        rn = (instr >> 16) & 0xF
        reg_list = instr & 0xFFFF
        
        mnemonic = 'LDM' if is_load else 'STM'
        
        # Build register list
        regs = []
        for i in range(16):
            if reg_list & (1 << i):
                regs.append(f"R{i}")
        
        reg_str = '{' + ', '.join(regs) + '}'
        
        return f"{mnemonic}{cond} R{rn}, {reg_str}"
    
    def disasm_branch(self, instr: int, cond: str, addr: int) -> str:
        """Disassemble branch instruction"""
        is_link = (instr >> 24) & 1
        offset = instr & 0xFFFFFF
        
        # Sign extend
        if offset & 0x800000:
            offset |= 0xFF000000
        
        # Calculate target (PC+8 + offset*4)
        target = addr + 8 + (self.sign_extend_24(offset) << 2)
        
        mnemonic = 'BL' if is_link else 'B'
        
        # Check if we have a symbol for this address
        if target in self.symbols:
            return f"{mnemonic}{cond} {self.symbols[target]}"
        else:
            return f"{mnemonic}{cond} 0x{target:08X}"
    
    def disasm_swi(self, instr: int, cond: str) -> str:
        """Disassemble software interrupt"""
        comment = instr & 0xFFFFFF
        return f"SWI{cond} 0x{comment:X}"
    
    def sign_extend_24(self, value: int) -> int:
        """Sign extend 24-bit value to 32-bit"""
        if value & 0x800000:
            return value | 0xFF000000
        return value
    
    def rotate_right(self, value: int, amount: int) -> int:
        """Rotate right"""
        amount = amount % 32
        return ((value >> amount) | (value << (32 - amount))) & 0xFFFFFFFF
    
    def disassemble_file(self, filename: str, base_addr: int = 0):
        """Disassemble a binary file"""
        with open(filename, 'rb') as f:
            data = f.read()
        
        self.base_addr = base_addr
        addr = base_addr
        
        print(f"; Disassembly of {filename}")
        print(f"; Base address: 0x{base_addr:08X}")
        print()
        
        # Disassemble 4 bytes at a time
        for i in range(0, len(data), 4):
            if i + 4 > len(data):
                break
            
            instr = struct.unpack('<I', data[i:i+4])[0]
            
            # Check for symbol at this address
            if addr in self.symbols:
                print(f"\n{self.symbols[addr]}:")
            
            disasm = self.disassemble_instruction(instr, addr)
            print(f"  {addr:08X}:  {instr:08X}  {disasm}")
            
            addr += 4

def main():
    parser = argparse.ArgumentParser(description='ARM7 Disassembler')
    parser.add_argument('input_file', help='Binary file to disassemble')
    parser.add_argument('-b', '--base-addr', type=lambda x: int(x, 0), default=0,
                        help='Base address (default: 0x00000000)')
    parser.add_argument('-s', '--symbols', help='Symbol file')
    
    args = parser.parse_args()
    
    # Load symbols if provided
    symbols = {}
    if args.symbols:
        with open(args.symbols, 'r') as f:
            for line in f:
                parts = line.strip().split()
                if len(parts) >= 2:
                    addr = int(parts[0], 16)
                    name = parts[1]
                    symbols[addr] = name
    
    # Disassemble
    disasm = ARM7Disassembler(symbols)
    disasm.disassemble_file(args.input_file, args.base_addr)

if __name__ == '__main__':
    main()

