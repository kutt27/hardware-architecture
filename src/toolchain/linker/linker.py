#!/usr/bin/env python3
"""
ARM7 Linker - Links object files into executable binary

Features:
- Symbol resolution across multiple object files
- Relocation of addresses
- Section merging (.text, .data, .bss)
- Memory layout configuration
- Entry point specification

Author: ARM7 Computer System Project
Date: 2025-11-03
"""

import sys
import struct
import argparse
from pathlib import Path
from typing import Dict, List, Tuple

class Symbol:
    """Represents a symbol in an object file"""
    def __init__(self, name: str, value: int, section: str, is_global: bool = False):
        self.name = name
        self.value = value
        self.section = section
        self.is_global = is_global
        self.resolved_addr = None

class Relocation:
    """Represents a relocation entry"""
    def __init__(self, offset: int, symbol: str, rel_type: str, section: str):
        self.offset = offset
        self.symbol = symbol
        self.rel_type = rel_type  # 'abs32', 'rel24', etc.
        self.section = section

class Section:
    """Represents a section (.text, .data, .bss)"""
    def __init__(self, name: str, data: bytes = b'', base_addr: int = 0):
        self.name = name
        self.data = bytearray(data)
        self.base_addr = base_addr
        self.size = len(data)

class ObjectFile:
    """Represents an object file"""
    def __init__(self, filename: str):
        self.filename = filename
        self.sections = {}
        self.symbols = {}
        self.relocations = []

class Linker:
    """ARM7 Linker"""
    
    def __init__(self, memory_layout: Dict[str, int] = None):
        self.object_files = []
        self.global_symbols = {}
        self.sections = {
            '.text': Section('.text'),
            '.data': Section('.data'),
            '.bss': Section('.bss')
        }
        
        # Default memory layout
        self.memory_layout = memory_layout or {
            '.text': 0x00000000,
            '.data': 0x00010000,
            '.bss':  0x00020000
        }
        
        self.entry_point = 0x00000000
    
    def add_object_file(self, filename: str):
        """Add an object file to link"""
        obj = self.parse_object_file(filename)
        self.object_files.append(obj)
    
    def parse_object_file(self, filename: str) -> ObjectFile:
        """Parse object file (simplified format)"""
        obj = ObjectFile(filename)
        
        # For this implementation, we'll use a simple text-based format
        # Real implementation would use ELF or custom binary format
        with open(filename, 'r') as f:
            current_section = None
            
            for line in f:
                line = line.strip()
                if not line or line.startswith('#'):
                    continue
                
                parts = line.split()
                cmd = parts[0]
                
                if cmd == 'SECTION':
                    section_name = parts[1]
                    obj.sections[section_name] = Section(section_name)
                    current_section = section_name
                
                elif cmd == 'DATA':
                    # DATA <hex_bytes>
                    hex_data = parts[1]
                    data = bytes.fromhex(hex_data)
                    obj.sections[current_section].data.extend(data)
                    obj.sections[current_section].size = len(obj.sections[current_section].data)
                
                elif cmd == 'SYMBOL':
                    # SYMBOL <name> <value> <section> [GLOBAL]
                    name = parts[1]
                    value = int(parts[2], 0)
                    section = parts[3]
                    is_global = len(parts) > 4 and parts[4] == 'GLOBAL'
                    obj.symbols[name] = Symbol(name, value, section, is_global)
                
                elif cmd == 'RELOC':
                    # RELOC <offset> <symbol> <type> <section>
                    offset = int(parts[1], 0)
                    symbol = parts[2]
                    rel_type = parts[3]
                    section = parts[4]
                    obj.relocations.append(Relocation(offset, symbol, rel_type, section))
        
        return obj
    
    def merge_sections(self):
        """Merge sections from all object files"""
        for obj in self.object_files:
            for section_name, section in obj.sections.items():
                if section_name not in self.sections:
                    self.sections[section_name] = Section(section_name)
                
                # Record where this object's section starts in merged section
                obj_section_offset = len(self.sections[section_name].data)
                
                # Merge data
                self.sections[section_name].data.extend(section.data)
                self.sections[section_name].size = len(self.sections[section_name].data)
                
                # Update symbol addresses
                for sym_name, symbol in obj.symbols.items():
                    if symbol.section == section_name:
                        # Create global symbol with adjusted address
                        adjusted_value = symbol.value + obj_section_offset
                        global_sym = Symbol(sym_name, adjusted_value, section_name, symbol.is_global)
                        
                        if symbol.is_global:
                            if sym_name in self.global_symbols:
                                print(f"Warning: Duplicate global symbol '{sym_name}'")
                            self.global_symbols[sym_name] = global_sym
                        else:
                            # Local symbols get prefixed with filename
                            local_name = f"{obj.filename}:{sym_name}"
                            self.global_symbols[local_name] = global_sym
                
                # Adjust relocations
                for reloc in obj.relocations:
                    if reloc.section == section_name:
                        reloc.offset += obj_section_offset
    
    def assign_addresses(self):
        """Assign final addresses to sections"""
        for section_name, base_addr in self.memory_layout.items():
            if section_name in self.sections:
                self.sections[section_name].base_addr = base_addr
        
        # Resolve symbol addresses
        for sym_name, symbol in self.global_symbols.items():
            section = self.sections.get(symbol.section)
            if section:
                symbol.resolved_addr = section.base_addr + symbol.value
    
    def apply_relocations(self):
        """Apply relocations to resolve symbol references"""
        for obj in self.object_files:
            for reloc in obj.relocations:
                # Find symbol
                symbol = self.global_symbols.get(reloc.symbol)
                if not symbol:
                    # Try with filename prefix
                    symbol = self.global_symbols.get(f"{obj.filename}:{reloc.symbol}")
                
                if not symbol:
                    print(f"Error: Undefined symbol '{reloc.symbol}'")
                    continue
                
                # Get section
                section = self.sections.get(reloc.section)
                if not section:
                    continue
                
                # Apply relocation based on type
                if reloc.rel_type == 'abs32':
                    # Absolute 32-bit address
                    addr = symbol.resolved_addr
                    section.data[reloc.offset:reloc.offset+4] = struct.pack('<I', addr)
                
                elif reloc.rel_type == 'rel24':
                    # Relative 24-bit (for branches)
                    current_addr = section.base_addr + reloc.offset
                    target_addr = symbol.resolved_addr
                    offset = (target_addr - current_addr - 8) >> 2  # ARM PC+8, word offset
                    
                    # Read existing instruction
                    instr = struct.unpack('<I', section.data[reloc.offset:reloc.offset+4])[0]
                    # Update offset field (bits 0-23)
                    instr = (instr & 0xFF000000) | (offset & 0x00FFFFFF)
                    section.data[reloc.offset:reloc.offset+4] = struct.pack('<I', instr)
    
    def generate_output(self, output_file: str, format: str = 'bin'):
        """Generate output executable"""
        if format == 'bin':
            # Raw binary format
            with open(output_file, 'wb') as f:
                # Write .text section
                if '.text' in self.sections:
                    f.write(self.sections['.text'].data)
                
                # Write .data section (if contiguous)
                if '.data' in self.sections:
                    text_end = self.sections['.text'].base_addr + self.sections['.text'].size
                    data_start = self.sections['.data'].base_addr
                    
                    if data_start > text_end:
                        # Pad between sections
                        padding = data_start - text_end
                        f.write(b'\x00' * padding)
                    
                    f.write(self.sections['.data'].data)
        
        elif format == 'hex':
            # Intel HEX format
            self.write_hex_file(output_file)
    
    def write_hex_file(self, filename: str):
        """Write Intel HEX format"""
        with open(filename, 'w') as f:
            for section_name in ['.text', '.data']:
                if section_name not in self.sections:
                    continue
                
                section = self.sections[section_name]
                addr = section.base_addr
                data = section.data
                
                # Write in 16-byte records
                for i in range(0, len(data), 16):
                    chunk = data[i:i+16]
                    record = self.create_hex_record(addr + i, chunk)
                    f.write(record + '\n')
            
            # End of file record
            f.write(':00000001FF\n')
    
    def create_hex_record(self, addr: int, data: bytes) -> str:
        """Create Intel HEX record"""
        byte_count = len(data)
        addr_high = (addr >> 8) & 0xFF
        addr_low = addr & 0xFF
        record_type = 0x00
        
        record = f":{byte_count:02X}{addr_high:02X}{addr_low:02X}{record_type:02X}"
        checksum = byte_count + addr_high + addr_low + record_type
        
        for byte in data:
            record += f"{byte:02X}"
            checksum += byte
        
        checksum = (-checksum) & 0xFF
        record += f"{checksum:02X}"
        
        return record
    
    def link(self, output_file: str, format: str = 'bin'):
        """Perform linking"""
        print(f"Linking {len(self.object_files)} object files...")
        
        # Step 1: Merge sections
        self.merge_sections()
        print(f"  Merged sections: {', '.join(self.sections.keys())}")
        
        # Step 2: Assign addresses
        self.assign_addresses()
        print(f"  Assigned addresses:")
        for name, section in self.sections.items():
            print(f"    {name}: 0x{section.base_addr:08X} ({section.size} bytes)")
        
        # Step 3: Apply relocations
        self.apply_relocations()
        print(f"  Applied relocations")
        
        # Step 4: Generate output
        self.generate_output(output_file, format)
        print(f"  Generated {output_file}")
        
        print("Linking complete!")

def main():
    parser = argparse.ArgumentParser(description='ARM7 Linker')
    parser.add_argument('input_files', nargs='+', help='Object files to link')
    parser.add_argument('-o', '--output', required=True, help='Output file')
    parser.add_argument('-f', '--format', choices=['bin', 'hex'], default='bin',
                        help='Output format (default: bin)')
    parser.add_argument('--text-addr', type=lambda x: int(x, 0), default=0x00000000,
                        help='Text section base address')
    parser.add_argument('--data-addr', type=lambda x: int(x, 0), default=0x00010000,
                        help='Data section base address')
    
    args = parser.parse_args()
    
    # Create linker
    memory_layout = {
        '.text': args.text_addr,
        '.data': args.data_addr,
        '.bss': args.data_addr + 0x10000
    }
    
    linker = Linker(memory_layout)
    
    # Add object files
    for obj_file in args.input_files:
        linker.add_object_file(obj_file)
    
    # Link
    linker.link(args.output, args.format)

if __name__ == '__main__':
    main()

