; Various utils

OUT_CHAR:
		PUSH AF
OUT_CHAR_WAIT:    
		IN   A, (DART_A_CMD)                 ;COME HERE TO DO OUTPUT
        AND  TxRDY_MASK                 ;STATUS BIT
        JP Z, OUT_CHAR_WAIT              ;NOT READY, WAIT
        POP  AF                        ;READY, GET OLD A BACK
        OUT  (DART_A_DATA), A                ;AND SEND IT OUT
		RET        

MEMCOPY:
        LD A, B                        ;Copy register B to register A
        OR C                           ;Bitwise OR of register A and register C into register A
        RET Z                              ;Return if the zero-flag is set high.
MC_LOOP:
        LD A, (DE)                          ;Load A from the address pointed by DE
        LD (HL), A                        ;Store A into the address pointed by HL
        INC DE                           ;Increment DE
        INC HL                           ;Increment HL
        DEC BC                           ;Decrement BC   (does not affect Flags)
        LD A, B                        ;Copy B to A    (so as to compare BC with zero)
        OR C                           ;A = A | C      (set zero)
        JP NZ, MC_LOOP                     ;Jump to 'loop:' if the zero-flag is not set.   
        RET                             ;Return

NEWLINE:
		LD A, 0DH
		CALL OUT_CHAR
		;LD A, 0AH					; Comment out when LF implementation
		;CALL OUT_CHAR				; in VDP will be ready
		RET
		
PRN_ZERO_EX:
		LD A, 48					;48 is 0 in ASCII
		CALL OUT_CHAR
		LD A, 120					;120 is x in ASCII
		CALL OUT_CHAR
		RET
		
IPUTS:
		EX (SP),HL
		CALL PUTS_LOOP
		INC HL
		EX (SP),HL
		RET
		
PUTS:
		PUSH HL
		PUSH DE
		CALL PUTS_LOOP
		POP DE
		POP HL
		RET
PUTS_LOOP:
		LD D, H
		LD E, L
		LD A, (DE)
		OR A
		RET Z					; If a is zero, return
		CALL OUT_CHAR
		INC HL
		JP PUTS_LOOP

; Checks if 32 variable pointed by DL is zero		
ISZERO32BIT:
		LD A, (DE)
		OR A
		RET NZ
		INC DE
		LD A, (DE)
		OR A
		RET NZ
		INC DE
		LD A, (DE)
		OR A
		RET NZ
		INC DE
		LD A, (DE)
		OR A
		RET
		
; CRC-16/ARC for 8080/Z80
; On entry HL = old CRC, A = byte
; On exit HL = new CRC, A,B undefined
CRC16_ARC_F:
        XOR		L
        LD      L,A
        RRCA
        RRCA
        JP 		PO, BLUR
        AND     A
BLUR:   JP		PE, BLUR1
        SCF
BLUR1:  DB 01FH ;RAR
        AND     0E0H
        DB 017H ;RAL
        LD      B,A
        DB 017H ;RAL
        XOR     B
        XOR     H
        LD      B,A
        XOR     H
        DB 01FH ;RAR
        LD      A,L
        DB 01FH ;RAR
        LD	    L,A
        AND     A
        DB 01FH ;RAR
        XOR     L
        LD      L,B
        LD      H,A
        RET
        
; Checks if 32bit values pointed by HL and DE are equal        
IS32BIT_EQUAL:
    LD B, 4        		; Set counter for 4 bytes
    LD A, 1        		; Assume values are equal (flag set to 1)
IS32BIT_EQUAL_LOOP:
    LD A, (DE)          	; Load byte from second value (ADDR2)
    CP (HL)           		; Compare with byte at first value (ADDR1)
    JP NZ, IS32BIT_NOT_EQUAL   ; If not equal, jump to NOT_EQUAL
    INC HL           		; Move to next byte in ADDR1
    INC DE           		; Move to next byte in ADDR2
    DEC B           		; Decrement byte counter
    JP NZ, IS32BIT_EQUAL_LOOP  ; Repeat until all bytes are checked
    RET             		; Return with A = 1 (equal)
IS32BIT_NOT_EQUAL:
    LD A, 0        		; Set A = 0 (not equal)
    RET             		; Return

;THIS IS JUSY ENDLESS LOOP. Go here if something is wrong.		
ENDLESS_LOOP:
		NOP
		JP ENDLESS_LOOP
        
