; =============================================================================
; Bubble Sort Algorithm
; =============================================================================
; Description:
;   Sorts an array of integers using bubble sort.
;   Demonstrates nested loops, comparisons, and memory operations.
;
; Author: ARM7 Computer System Project
; Date: 2025-11-03
; =============================================================================

.global _start

_start:
    ; Initialize
    MOV R0, ;0x1000         ; Array base address
    MOV R1, ;8              ; Array length
    
    ; Initialize array with unsorted data
    MOV R2, ;42
    STR R2, [R0, ;0]
    MOV R2, ;17
    STR R2, [R0, ;4]
    MOV R2, ;93
    STR R2, [R0, ;8]
    MOV R2, ;8
    STR R2, [R0, ;12]
    MOV R2, ;56
    STR R2, [R0, ;16]
    MOV R2, ;23
    STR R2, [R0, ;20]
    MOV R2, ;71
    STR R2, [R0, ;24]
    MOV R2, ;5
    STR R2, [R0, ;28]
    
    ; Bubble sort
    MOV R2, R1              ; Outer loop counter (n)
    
outer_loop:
    CMP R2, ;1
    BLE sort_done           ; If n <= 1, done
    
    MOV R3, ;0              ; Inner loop index (i)
    SUB R4, R2, ;1          ; Inner loop limit (n-1)
    
inner_loop:
    CMP R3, R4
    BGE outer_loop_next     ; If i >= n-1, next outer iteration
    
    ; Load array[i] and array[i+1]
    LSL R5, R3, ;2          ; R5 = i * 4 (byte offset)
    ADD R6, R0, R5          ; R6 = &array[i]
    LDR R7, [R6]            ; R7 = array[i]
    LDR R8, [R6, ;4]        ; R8 = array[i+1]
    
    ; Compare
    CMP R7, R8
    BLE no_swap             ; If array[i] <= array[i+1], no swap
    
    ; Swap
    STR R8, [R6]            ; array[i] = array[i+1]
    STR R7, [R6, ;4]        ; array[i+1] = array[i]
    
no_swap:
    ADD R3, R3, ;1          ; i++
    B inner_loop
    
outer_loop_next:
    SUB R2, R2, ;1          ; n--
    B outer_loop

sort_done:
    ; Infinite loop (halt)
    B sort_done

; =============================================================================
; Expected Results (sorted array at 0x1000):
; 0x1000: 5
; 0x1004: 8
; 0x1008: 17
; 0x100C: 23
; 0x1010: 42
; 0x1014: 56
; 0x1018: 71
; 0x101C: 93
; =============================================================================

