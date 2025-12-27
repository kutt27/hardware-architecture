; =============================================================================
; UART Echo Program
; =============================================================================
; Description:
;   Echoes characters received from UART back to UART.
;   Demonstrates I/O operations and polling.
;
; Memory Map:
;   0xFFFF0000 - UART Data Register
;   0xFFFF0004 - UART Status Register
;   0xFFFF0008 - UART Control Register
;
; Author: ARM7 Computer System Project
; Date: 2025-11-03
; =============================================================================

.global _start

; UART register offsets
.equ UART_BASE,    0xFFFF0000
.equ UART_DATA,    0x00
.equ UART_STATUS,  0x04
.equ UART_CTRL,    0x08

; Status bits
.equ TX_READY,     0x01
.equ RX_FULL,      0x02

_start:
    ; Initialize UART base address
    MOV R10, ;0xFF000000
    ORR R10, R10, ;0x00FF0000
    
    ; Enable UART
    MOV R0, ;0x01
    STR R0, [R10, ;UART_CTRL]
    
    ; Print welcome message
    BL print_welcome

echo_loop:
    ; Wait for RX data
    BL uart_getc
    MOV R1, R0              ; Save received character
    
    ; Check for exit character (ESC = 0x1B)
    CMP R1, ;0x1B
    BEQ exit_program
    
    ; Echo character back
    MOV R0, R1
    BL uart_putc
    
    ; Loop
    B echo_loop

exit_program:
    ; Print goodbye message
    BL print_goodbye
    
    ; Halt
    B exit_program

; =============================================================================
; UART Functions
; =============================================================================

; uart_getc - Read character from UART
; Returns: R0 = character
uart_getc:
    ; Wait for RX full
uart_getc_wait:
    LDR R0, [R10, ;UART_STATUS]
    AND R0, R0, ;RX_FULL
    CMP R0, ;0
    BEQ uart_getc_wait
    
    ; Read character
    LDR R0, [R10, ;UART_DATA]
    MOV PC, LR

; uart_putc - Write character to UART
; Input: R0 = character
uart_putc:
    MOV R2, R0              ; Save character
    
    ; Wait for TX ready
uart_putc_wait:
    LDR R0, [R10, ;UART_STATUS]
    AND R0, R0, ;TX_READY
    CMP R0, ;0
    BEQ uart_putc_wait
    
    ; Write character
    STR R2, [R10, ;UART_DATA]
    MOV PC, LR

; uart_puts - Print null-terminated string
; Input: R0 = pointer to string
uart_puts:
    MOV R4, LR              ; Save return address
    MOV R5, R0              ; Save string pointer
    
uart_puts_loop:
    LDRB R0, [R5]           ; Load character
    CMP R0, ;0              ; Check for null
    BEQ uart_puts_done
    
    BL uart_putc            ; Print character
    
    ADD R5, R5, ;1          ; Next character
    B uart_puts_loop
    
uart_puts_done:
    MOV PC, R4              ; Return

; =============================================================================
; Message Printing
; =============================================================================

print_welcome:
    MOV R4, LR
    MOV R0, msg_welcome
    BL uart_puts
    MOV PC, R4

print_goodbye:
    MOV R4, LR
    MOV R0, msg_goodbye
    BL uart_puts
    MOV PC, R4

; =============================================================================
; Data Section
; =============================================================================

.section .rodata

msg_welcome:
    .ascii "UART Echo Program\n\r"
    .ascii "Type characters to echo\n\r"
    .ascii "Press ESC to exit\n\r"
    .byte 0

msg_goodbye:
    .ascii "\n\rGoodbye!\n\r"
    .byte 0

; =============================================================================
; End of Program
; =============================================================================

