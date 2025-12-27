; =============================================================================
; Hello World Program for ARM7 Computer System
; =============================================================================
; Description:
;   Simple program demonstrating basic ARM7 instructions.
;   Calculates sum of numbers and stores result.
;
; Author: ARM7 Computer System Project
; Date: 2025-11-03
; =============================================================================

; Entry point
start:
    ; Initialize registers
    MOV R0, #0          ; R0 = 0 (accumulator)
    MOV R1, #1          ; R1 = 1 (counter)
    MOV R2, #10         ; R2 = 10 (limit)

; Sum loop: calculate 1+2+3+...+10
sum_loop:
    ADD R0, R0, R1      ; R0 = R0 + R1 (accumulate)
    ADD R1, R1, #1      ; R1 = R1 + 1 (increment counter)
    SUB R3, R1, R2      ; R3 = R1 - R2 (compare)
    ; TODO: Add conditional branch when decoder supports it
    ; BLE sum_loop      ; Branch if R1 <= R2
    
; Store result
    ; LDR R4, [R5]      ; Load base address
    ; STR R0, [R4]      ; Store result
    
; Infinite loop
done:
    B done              ; Loop forever

; =============================================================================
; Expected Result:
;   R0 should contain 55 (sum of 1 to 10)
; =============================================================================

