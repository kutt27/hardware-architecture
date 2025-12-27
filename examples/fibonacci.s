; =============================================================================
; Fibonacci Sequence Calculator
; =============================================================================
; Description:
;   Calculates the first N Fibonacci numbers and stores them in memory.
;   Demonstrates loops, memory operations, and arithmetic.
;
; Author: ARM7 Computer System Project
; Date: 2025-11-03
; =============================================================================

.global _start

_start:
    ; Initialize
    MOV R0, ;0              ; F(0) = 0
    MOV R1, ;1              ; F(1) = 1
    MOV R2, ;10             ; Calculate 10 numbers
    MOV R3, ;0x1000         ; Memory base address
    MOV R4, ;0              ; Counter
    
    ; Store first two numbers
    STR R0, [R3], ;4        ; Store F(0), increment address
    STR R1, [R3], ;4        ; Store F(1), increment address
    ADD R4, R4, ;2          ; Counter = 2
    
fibonacci_loop:
    ; Check if done
    CMP R4, R2
    BGE fibonacci_done
    
    ; Calculate next Fibonacci number
    ADD R5, R0, R1          ; F(n) = F(n-1) + F(n-2)
    
    ; Store result
    STR R5, [R3], ;4
    
    ; Update for next iteration
    MOV R0, R1              ; F(n-2) = F(n-1)
    MOV R1, R5              ; F(n-1) = F(n)
    
    ; Increment counter
    ADD R4, R4, ;1
    
    ; Loop
    B fibonacci_loop

fibonacci_done:
    ; Infinite loop (halt)
    B fibonacci_done

; =============================================================================
; Expected Results (in memory at 0x1000):
; 0x1000: 0  (F0)
; 0x1004: 1  (F1)
; 0x1008: 1  (F2)
; 0x100C: 2  (F3)
; 0x1010: 3  (F4)
; 0x1014: 5  (F5)
; 0x1018: 8  (F6)
; 0x101C: 13 (F7)
; 0x1020: 21 (F8)
; 0x1024: 34 (F9)
; =============================================================================

