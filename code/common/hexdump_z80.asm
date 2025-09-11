;Dumps number of bytes (passed in B) in hex
;Beginning in DE
HEXDUMP:
	LD A, B
	OR A
	RET Z
	LD A, (DE)				;Get byte
	CALL HEXDUMP_A		;Print current byte as hex value
	LD A, 32			;Print space
	CALL OUT_CHAR
	INC DE
	DEC B
	JP HEXDUMP

;Print the value in A in hex
HEXDUMP_A:
	PUSH AF
	RRCA
	RRCA
	RRCA
	RRCA
	AND 00FH
	CALL HEXDUMP_NIB
	POP AF
	PUSH AF
	AND 00FH
	CALL HEXDUMP_NIB
	POP AF
	RET	
HEXDUMP_NIB:
	ADD A, 48	;48 is 0 in ascii
	CP 57+1	;57 is 9 in ascii
	JP C, HEXDUMP_NUM
	ADD A, 65-57-1	;'A'-'9'-1
HEXDUMP_NUM:
	CALL OUT_CHAR
	RET

HEXDUMP32BITVAL:
	    LD A, (DE)
        CALL HEXDUMP_A
        DEC DE
        LD A, (DE)
        CALL HEXDUMP_A
        DEC DE
        LD A, (DE)
        CALL HEXDUMP_A
        DEC DE
        LD A, (DE)
        CALL HEXDUMP_A
        RET

HEXDUMP32BITVAL_PLUS_SPACE:
		CALL HEXDUMP32BITVAL
		LD A, 32
		CALL OUT_CHAR
		RET
