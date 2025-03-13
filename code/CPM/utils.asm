; Various utils

OUT_CHAR:
		PUSH PSW
OUT_CHAR_WAIT:    
		IN   DART_A_CMD                 ;COME HERE TO DO OUTPUT
        ANI  TxRDY_MASK                 ;STATUS BIT
        JZ   OUT_CHAR_WAIT              ;NOT READY, WAIT
        POP  PSW                        ;READY, GET OLD A BACK
        OUT  DART_A_DATA                ;AND SEND IT OUT
		RET
        

MEMCOPY:
        MOV A, B                        ;Copy register B to register A
        ORA C                           ;Bitwise OR of register A and register C into register A
        RZ                              ;Return if the zero-flag is set high.
MC_LOOP:
        LDAX D                          ;Load A from the address pointed by DE
        MOV M, A                        ;Store A into the address pointed by HL
        INX D                           ;Increment DE
        INX H                           ;Increment HL
        DCX B                           ;Decrement BC   (does not affect Flags)
        MOV A, B                        ;Copy B to A    (so as to compare BC with zero)
        ORA C                           ;A = A | C      (set zero)
        JNZ MC_LOOP                     ;Jump to 'loop:' if the zero-flag is not set.   
        RET                             ;Return

NEWLINE:
		MVI A, 0DH
		CALL OUT_CHAR
		;MVI A, 0AH					; Comment out when LF implementation
		;CALL OUT_CHAR				; in VDP will be ready
		RET
		
PRN_ZERO_EX:
		MVI A, 48					;48 is 0 in ASCII
		CALL OUT_CHAR
		MVI A, 120					;120 is x in ASCII
		CALL OUT_CHAR
		RET
		
IPUTS:
		XTHL
		CALL PUTS_LOOP
		INX H
		XTHL
		RET
		
PUTS:
		PUSH H
		PUSH D
		CALL PUTS_LOOP
		POP D
		POP H
		RET
PUTS_LOOP:
		MOV D, H
		MOV E, L
		LDAX D
		CPI 00H
		RZ					; If a is zero, return
		CALL OUT_CHAR
		INX H
		JMP PUTS_LOOP

; Checks if 32 variable pointed by DL is zero		
ISZERO32BIT:
		LDAX D
		CPI 00H
		RNZ
		INX D
		LDAX D
		CPI 00H
		RNZ
		INX D
		LDAX D
		CPI 00H
		RNZ
		INX D
		LDAX D
		CPI 00H
		RET
		
; CRC-16/ARC for 8080/Z80
; On entry HL = old CRC, A = byte
; On exit HL = new CRC, A,B undefined
CRC16_ARC_F:
        XRA     L
        MOV     L,A
        RRC
        RRC
        JPO     BLUR
        ANA     A
BLUR:   JPE     BLUR1
        STC
BLUR1:  RAR
        ANI     0E0H
        RAL
        MOV     B,A
        RAL
        XRA     B
        XRA     H
        MOV     B,A
        XRA     H
        RAR
        MOV     A,L
        RAR
        MOV     L,A
        ANA     A
        RAR
        XRA     L
        MOV     L,B
        MOV     H,A
        RET

;THIS IS JUSY ENDLESS LOOP. Go here if something is wrong.		
ENDLESS_LOOP:
		NOP
		JMP ENDLESS_LOOP
        
