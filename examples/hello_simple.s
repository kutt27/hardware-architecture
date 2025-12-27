; Simple Hello World Program
; Tests basic ARM7 instructions

.text

_start:
    MOV R0, #5
    MOV R1, #10
    ADD R2, R0, R1
    SUB R3, R2, R0
    B halt

halt:
    B halt

