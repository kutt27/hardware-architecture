# ARM7 Assembly Examples

This directory contains example assembly programs for the ARM7 computer system.

## Available Examples

### hello.s
Simple program demonstrating:
- Register initialization with MOV
- Arithmetic operations (ADD, SUB)
- Loop structure
- Unconditional branch

**Expected Result:** R0 = 55 (sum of 1 to 10)

## How to Assemble

```bash
# From project root
python3 src/toolchain/assembler/assembler.py examples/hello.s -o examples/hello.bin

# View the binary
hexdump -C examples/hello.bin
```

## How to Simulate

Once the CPU is complete, you can load and execute these programs:

```bash
# Load program into instruction memory
# Run CPU simulation
# Observe register values
```

## Writing Your Own Programs

### Supported Instructions (Current)
- **Data Processing:** MOV, ADD, SUB, AND, ORR, EOR
- **Branch:** B, BL
- **Load/Store:** LDR, STR (basic addressing)

### Registers
- R0-R12: General purpose
- R13 (SP): Stack pointer
- R14 (LR): Link register
- R15 (PC): Program counter

### Example Template

```assembly
; Program description
start:
    MOV R0, #0          ; Initialize
    ; Your code here
    B start             ; Loop or end
```

## Notes

- All instructions are 32-bit (4 bytes)
- Immediate values are limited by ARM7 encoding
- Labels must be followed by colon (:)
- Comments start with semicolon (;)

