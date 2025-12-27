# =============================================================================
# ARM7 Boot ROM
# =============================================================================
# Description:
#   Boot ROM code that initializes the system and jumps to main program.
#   This code is stored in ROM at address 0x00000000.
#
# Memory Map:
#   0x00000000 - 0x00000FFF : Boot ROM (4KB)
#   0x00001000 - 0x0000FFFF : Program RAM (60KB)
#   0x00010000 - 0x0001FFFF : Data RAM (64KB)
#   0x00020000 - 0x0002FFFF : Stack (64KB)
#   0xFFFF0000 - 0xFFFF00FF : UART registers
#   0xFFFF0100 - 0xFFFF01FF : GPIO registers
#
# Author: ARM7 Computer System Project
# Date: 2025-11-03
# =============================================================================

.section .text
.global _start
.global _reset_handler

# =============================================================================
# Reset Vector
# =============================================================================
_start:
_reset_handler:
    # Initialize stack pointer
    MOV R0, #0x00030000      # Stack top at 192KB
    MOV SP, R0
    
    # Clear BSS section
    MOV R0, #0x00020000      # BSS start
    MOV R1, #0x00030000      # BSS end
    MOV R2, #0
clear_bss_loop:
    CMP R0, R1
    BEQ clear_bss_done
    STR R2, [R0]
    ADD R0, R0, #4
    B clear_bss_loop
clear_bss_done:
    
    # Initialize UART
    BL uart_init
    
    # Print boot message
    BL print_boot_message
    
    # Jump to main program
    MOV R0, #0x00001000      # Main program at 4KB
    MOV PC, R0

# =============================================================================
# UART Initialization
# =============================================================================
uart_init:
    # UART base address
    MOV R0, #0xFF000000
    ORR R0, R0, #0x00FF0000
    
    # Set baud rate (115200)
    MOV R1, #0x1B            # Divisor for 115200 @ 50MHz
    STR R1, [R0, #0x08]      # Baud rate register
    
    # Enable UART
    MOV R1, #0x01
    STR R1, [R0, #0x0C]      # Control register
    
    MOV PC, LR

# =============================================================================
# UART Character Output
# =============================================================================
uart_putc:
    # R0 = character to send
    # R1 = UART base address
    MOV R1, #0xFF000000
    ORR R1, R1, #0x00FF0000
    
uart_putc_wait:
    # Wait for TX ready
    LDR R2, [R1, #0x04]      # Status register
    AND R2, R2, #0x01        # TX ready bit
    CMP R2, #0
    BEQ uart_putc_wait
    
    # Send character
    STR R0, [R1, #0x00]      # Data register
    
    MOV PC, LR

# =============================================================================
# Print String
# =============================================================================
uart_puts:
    # R0 = pointer to null-terminated string
    MOV R4, LR               # Save return address
    MOV R5, R0               # Save string pointer
    
uart_puts_loop:
    LDRB R0, [R5]            # Load character
    CMP R0, #0               # Check for null terminator
    BEQ uart_puts_done
    
    BL uart_putc             # Print character
    
    ADD R5, R5, #1           # Next character
    B uart_puts_loop
    
uart_puts_done:
    MOV PC, R4               # Return

# =============================================================================
# Print Boot Message
# =============================================================================
print_boot_message:
    MOV R4, LR
    
    # Print banner
    MOV R0, boot_msg
    BL uart_puts
    
    # Print newline
    MOV R0, #0x0A
    BL uart_putc
    MOV R0, #0x0D
    BL uart_putc
    
    MOV PC, R4

# =============================================================================
# Exception Handlers
# =============================================================================
undefined_handler:
    # Print error message
    MOV R0, err_undefined
    BL uart_puts
    B halt

swi_handler:
    # Software interrupt handler
    # R0 = SWI number
    CMP R0, #0               # SWI 0 = exit
    BEQ halt
    
    CMP R0, #1               # SWI 1 = putc
    BEQ swi_putc
    
    CMP R0, #2               # SWI 2 = puts
    BEQ swi_puts
    
    # Unknown SWI
    B swi_return

swi_putc:
    # R1 = character
    MOV R0, R1
    BL uart_putc
    B swi_return

swi_puts:
    # R1 = string pointer
    MOV R0, R1
    BL uart_puts
    B swi_return

swi_return:
    # Return from SWI
    MOV PC, LR

prefetch_abort_handler:
    MOV R0, err_prefetch
    BL uart_puts
    B halt

data_abort_handler:
    MOV R0, err_data
    BL uart_puts
    B halt

irq_handler:
    # Save context
    SUB LR, LR, #4
    STMFD SP!, {R0-R3, R12, LR}
    
    # Handle interrupt (placeholder)
    
    # Restore context
    LDMFD SP!, {R0-R3, R12, PC}^

fiq_handler:
    # Fast interrupt handler (placeholder)
    SUBS PC, LR, #4

# =============================================================================
# Halt System
# =============================================================================
halt:
    # Infinite loop
    B halt

# =============================================================================
# Data Section
# =============================================================================
.section .rodata

boot_msg:
    .ascii "ARM7 Computer System v1.0\n\r"
    .ascii "Boot ROM initialized\n\r"
    .ascii "Jumping to main program...\n\r"
    .byte 0

err_undefined:
    .ascii "ERROR: Undefined instruction\n\r"
    .byte 0

err_prefetch:
    .ascii "ERROR: Prefetch abort\n\r"
    .byte 0

err_data:
    .ascii "ERROR: Data abort\n\r"
    .byte 0

# =============================================================================
# Vector Table (at 0x00000000)
# =============================================================================
.section .vectors
.global _vectors

_vectors:
    B _reset_handler         # 0x00: Reset
    B undefined_handler      # 0x04: Undefined instruction
    B swi_handler           # 0x08: Software interrupt
    B prefetch_abort_handler # 0x0C: Prefetch abort
    B data_abort_handler    # 0x10: Data abort
    NOP                     # 0x14: Reserved
    B irq_handler           # 0x18: IRQ
    B fiq_handler           # 0x1C: FIQ

# =============================================================================
# End of Boot ROM
# =============================================================================

