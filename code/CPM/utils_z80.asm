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
		
; CRC-16/ARC for Z80 only
; On entry HL = old CRC, A = byte
; On exit HL = new CRC, A,B undefined
CRC16_ARC_F:
        LD      B,0             
        XOR     L               
        JP      PO,BLUR80       
        AND     A               
BLUR80: JP      PE,BLUR81       
        SCF                     
BLUR81: RRA                     
        RR      B               
        LD      L,A             
        SRL     A               
        RR      B               
        XOR     L               
        LD      L,A             
        ADD     A,A             
        LD      A,B             
        RLA                     
        XOR     B               
        XOR     H               
        LD      H,L             
        LD      L,A             
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
        
