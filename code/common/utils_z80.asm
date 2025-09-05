; Various utils
OUT_CHAR:
		push af
OUT_CHAR_WAIT:    
		in a,(DART_A_CMD)                 ;COME HERE TO DO OUTPUT
        and a,TxRDY_MASK                 ;STATUS BIT
        jp z,OUT_CHAR_WAIT              ;NOT READY, WAIT
        pop af                        ;READY, GET OLD A BACK
        out (DART_A_DATA),a                ;AND SEND IT OUT
		ret
    
DELAY:
        ld b,255
PETLA_DEL_WEWN:
        nop
        nop
        dec b
        jp nz,PETLA_DEL_WEWN                          
        dec c
        ret z
         jp DELAY        
        
MEMCOPY:
        ld a,b                        ;Copy register B to register A
        or a,c                           ;Bitwise OR of register A and register C into register A
        ret z                              ;Return if the zero-flag is set high.
MC_LOOP:
        ld a,(de)                          ;Load A from the address pointed by DE
        ld (hl),a                        ;Store A into the address pointed by HL
        inc de                           ;Increment DE
        inc hl                           ;Increment HL
        dec bc                           ;Decrement BC   (does not affect Flags)
        ld a,b                        ;Copy B to A    (so as to compare BC with zero)
        or a,c                           ;A = A | C      (set zero)
        jp nz,MC_LOOP                     ;Jump to 'loop:' if the zero-flag is not set.   
        ret                             ;Return
        
PRN_IND_DIGIT:
		add a,48
		call OUT_CHAR
		ld a,46						;46 is a dot in ASCII
		call OUT_CHAR
		ld a,32						;32 is space in ASCII
		call OUT_CHAR
		ret
		
;PRINT_PART_START_ADDR:
;		PUSH D
;		CALL PRN_ZERO_EX
;		LXI D, STARTADDRSTR
;		MVI B, 12
;		CALL PRNSTR
;		POP D
;		CALL HEXDUMP32BITVAL_PLUS_SPACE
;		RET
		
;PRINT_PART_SIZE:
;		PUSH D
;		CALL PRN_ZERO_EX
;		LXI D, SIZESTR
;		MVI B, 6
;		CALL PRNSTR
;		POP D
;		CALL HEXDUMP32BITVAL
;		RET
NEWLINE:
		ld a,0DH
		call OUT_CHAR
		;MVI A, 0AH					; Comment out when LF implementation
		;CALL OUT_CHAR				; in VDP will be ready
		ret
		
PRN_ZERO_EX:
		ld a,48					;48 is 0 in ASCII
		call OUT_CHAR
		ld a,120					;120 is x in ASCII
		call OUT_CHAR
		ret
		
;PRINTS STRING POINTED BY DE AND TERMINATED WITH CR OR NULL
;MAX NUMBER OF CHARACTERS IN B         
PRNSTR:	ld a,b
		cp a,00H
		ret z
		ld a,(de)							;GET A CHARACTER
		cp a,CR
		ret z
		cp a,00H
		ret z
		call OUT_CHAR
		inc de							
		dec b
		 jp PRNSTR
;SAWPS PAIR IN STRING POINTED BY DE UNTIL B REACH 0
;B IS NUMBER OF PAIRS!!!
SWPSTR: ld a,b
		cp a,00H
		ret z
		ld a,(de)
		ld h,a
		inc de
		ld a,(de)
		ld l,a
		ld a,h
		ld (de),a
		dec de
		ld a,l
		ld (de),a
		inc de
		inc de
		dec b
		 jp SWPSTR
		
IPUTS:
		ex hl,(sp)
		call PUTS_LOOP
		inc hl
		ex hl,(sp)
		ret
		
PUTS:
		push hl
		push de
		call PUTS_LOOP
		pop de
		pop hl
		ret
PUTS_LOOP:
		ld d,h
		ld e,l
		ld a,(de)
		cp a,00H
		ret z					; If a is zero, return
		call OUT_CHAR
		inc hl
		 jp PUTS_LOOP
; Checks if 32 variable pointed by DL is zero		
ISZERO32BIT:
		ld a,(de)
		cp a,00H
		ret nz
		inc de
		ld a,(de)
		cp a,00H
		ret nz
		inc de
		ld a,(de)
		cp a,00H
		ret nz
		inc de
		ld a,(de)
		cp a,00H
		ret
		
; CRC-16/ARC for 8080/Z80
; On entry HL = old CRC, A = byte
; On exit HL = new CRC, A,B undefined
CRC16_ARC_F:
        xor a,l
        ld l,a
        rrca
        rrca
        jp po,BLUR
        and a,a
BLUR:   jp pe,BLUR1
        scf
BLUR1:  rra
        and a,0E0H
        rla
        ld b,a
        rla
        xor a,b
        xor a,h
        ld b,a
        xor a,h
        rra
        ld a,l
        rra
        ld l,a
        and a,a
        rra
        xor a,l
        ld l,b
        ld h,a
        ret
;THIS IS JUSY ENDLESS LOOP. Go here if something is wrong.		
ENDLESS_LOOP:
		nop
		 jp ENDLESS_LOOP
        
