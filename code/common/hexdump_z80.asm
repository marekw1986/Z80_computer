;Dumps number of bytes (passed in B) in hex
;Beginning in DE
HEXDUMP:
	ld a,b
	cp a,00H
	ret z
	ld a,(de)				;Get byte
	call HEXDUMP_A		;Print current byte as hex value
	ld a,32			;Print space
	call OUT_CHAR
	inc de
	dec b
	 jp HEXDUMP
;Print the value in A in hex
HEXDUMP_A:
	push af
	rrca
	rrca
	rrca
	rrca
	and a,00FH
	call HEXDUMP_NIB
	pop af
	push af
	and a,00FH
	call HEXDUMP_NIB
	pop af
	ret	
HEXDUMP_NIB:
	add a,48	;48 is 0 in ascii
	cp a,57+1	;57 is 9 in ascii
	jp c,HEXDUMP_NUM
	add a,65-57-1	;'A'-'9'-1
HEXDUMP_NUM:
	call OUT_CHAR
	ret
HEXDUMP32BITVAL:
	    ld a,(de)
        call HEXDUMP_A
        dec de
        ld a,(de)
        call HEXDUMP_A
        dec de
        ld a,(de)
        call HEXDUMP_A
        dec de
        ld a,(de)
        call HEXDUMP_A
        ret
HEXDUMP32BITVAL_PLUS_SPACE:
		call HEXDUMP32BITVAL
		ld a,32
		call OUT_CHAR
		ret
