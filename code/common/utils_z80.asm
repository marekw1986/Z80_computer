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
    
DELAY:
        LD B, 255
PETLA_DEL_WEWN:
        NOP
        NOP
        DEC B
        JP Z, PETLA_DEL_WEWN                          
        DEC C
        RET Z
        JP DELAY        
        

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
        
PRN_IND_DIGIT:
		ADD A, 48
		CALL OUT_CHAR
		LD A, 46						;46 is a dot in ASCII
		CALL OUT_CHAR
		LD A, 32						;32 is space in ASCII
		CALL OUT_CHAR
		RET
		
;PRINT_PART_START_ADDR:
;		PUSH DE
;		CALL PRN_ZERO_EX
;		LD DE, STARTADDRSTR
;		LD B, 12
;		CALL PRNSTR
;		POP DE
;		CALL HEXDUMP32BITVAL_PLUS_SPACE
;		RET
		
;PRINT_PART_SIZE:
;		PUSH DE
;		CALL PRN_ZERO_EX
;		LD DE, SIZESTR
;		LD B, 6
;		CALL PRNSTR
;		POP DE
;		CALL HEXDUMP32BITVAL
;		RET

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
		

;PRINTS STRING POINTED BY DE AND TERMINATED WITH CR OR NULL
;MAX NUMBER OF CHARACTERS IN B         
PRNSTR:	LD A, B
		CP 00H
		RET Z
		LD A, (DE)							;GET A CHARACTER
		CP CR
		RET Z
		CP 00H
		RET Z
		CALL OUT_CHAR
		INC DE							
		DEC B
		JP PRNSTR

;SAWPS PAIR IN STRING POINTED BY DE UNTIL B REACH 0
;B IS NUMBER OF PAIRS!!!
SWPSTR: LD A, B
		CP 00H
		RET Z
		LD A, (DE)
		LD H, A
		INC DE
		LD A, (DE)
		LD L, A
		LD A, H
		LD (DE), A
		DEC DE
		LD A, L
		LD (DE), A
		INC DE
		INC DE
		DEC B
		JP SWPSTR
		
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
		CP 00H
		RET Z					; If a is zero, return
		CALL OUT_CHAR
		INC HL
		JP PUTS_LOOP

; Checks if 32 variable pointed by DL is zero		
ISZERO32BIT:
		LD A, (DE)
		CP 00H
		RET NZ
		INC DE
		LD A, (DE)
		CP 00H
		RET NZ
		INC DE
		LD A, (DE)
		CP 00H
		RET NZ
		INC DE
		LD A, (DE)
		CP 00H
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
BLUR1:  RR		A
        AND     0E0H
        RL		A
        LD      B,A
        RL		A
        XOR     B
        XOR     H
        LD      B,A
        XOR     H
        RR		A
        LD      A,L
        RR		A
        LD	    L,A
        AND     A
        RR		A
        XOR     L
        LD      L,B
        LD      H,A
        RET

;THIS IS JUSY ENDLESS LOOP. Go here if something is wrong.		
ENDLESS_LOOP:
		NOP
		JP ENDLESS_LOOP
        
