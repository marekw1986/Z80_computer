CFINIT:
		ld a,00H
		ld (CFLBA3),a
		ld a,00H
		ld (CFLBA2),a
		ld a,00H
		ld (CFLBA1),a
		ld a,00H
		ld (CFLBA0),a
        ld a,04H
        out (CFREG7),a
        call CFWAIT_TMOUT
        ld a,0E0H		                ;LBA3=0, MASTER, MODE=LBA
        out (CFREG6),a
        ld a,01H		                ;8-BIT TRANSFERS
        out (CFREG1),a
        ld a,0EFH		                ;SET FEATURE COMMAND
        out (CFREG7),a
        call CFWAIT_TMOUT
        cp a,00H							;Check if wait loop timeouted
        jp nz,CFINIT_RET					;If so there is no point in checking error code
        call CFCHERR
CFINIT_RET
        ret
CFWAIT:
        in a,(CFREG7)
        and a,80H                         ;MASK OUT BUSY FLAG
        jp nz,CFWAIT
        ret
        
CFWAIT_TMOUT:
		ld c,64
CFWAIT_TMOUT_LOOP_EXT:
		ld b,255
CFWAIT_TMOUT_LOOP_INT:
        in a,(CFREG7)
        and a,80H                  		;MASK OUT BUSY FLAG
        jp z,CFWAIT_TMOUT_OK
        dec b
        jp nz,CFWAIT_TMOUT_LOOP_INT
        dec c
        jp z,CFWAIT_TMOUT_NOK
         jp CFWAIT_TMOUT_LOOP_EXT
CFWAIT_TMOUT_OK:
        ld a,00H						;OK result
        ret
CFWAIT_TMOUT_NOK:
		ld a,01H						;CF card timeout
		ret
CFCHERR:	
        in a,(CFREG7)
        and a,01H		                    ;MASK OUT ERROR BIT
        jp z,CFNERR
        in a,(CFREG1)
		ret
CFNERR:
		ld a,00H
        ret    
            
CFREAD:
        call CFWAIT
        in a,(CFREG7)
        and a,08H	                    ;FILTER OUT DRQ
        jp z,CFREADE
        in a,(CFREG0)		            ;READ DATA BYTE
        ld (de),a
        inc de
         jp CFREAD
CFREADE:
        ret
        
CFWRITE:
        call CFWAIT
        in a,(CFREG7)
        and a,08H                     ;FILTER OUT DRQ
        jp z,CFWRITEE
        ld a,(de)
        out (CFREG0),a
        inc de
         jp CFWRITE
CFWRITEE:
        ret
        
CFSLBA:
        ld a,(CFLBA0)		                ;LBA 0
        out (CFREG3),a
        ld a,(CFLBA1)		                ;LBA 1
        out (CFREG4),a
        ld a,(CFLBA2)		                ;LBA 2
        out (CFREG5),a	
        ld a,(CFLBA3)		                ;LBA 3
        and a,0FH	                        ;FILTER OUT LBA BITS
        or a,0E0H	                    ;MODE LBA, MASTER DEV
        out (CFREG6),a
        ret
        
CFGETMBR:
		ld a,00H
		out (CFREG3),a						;LBA 0
		out (CFREG4),a						;LBA 1
		out (CFREG5),a						;LBA 2
		;ANI 0FH	                        ;FILTER OUT LBA BITS
		;ORI 0E0H	                    ;MODE LBA, MASTER DEV
		ld a,0E0H
        out (CFREG6),a
        ld a,01H
        out (CFREG2),a						;READ ONE SECTOR
		call CFWAIT
		ld a,20H						;READ SECTOR COMMAND
		out (CFREG7),a
		ld de,LOAD_BASE
		call CFREAD
		call CFCHERR
		ret        
  
CFINFO:	
        call CFWAIT
        ld a,0ECH	                    ;DRIVE ID COMMAND
        out (CFREG7),a
        ld de,LOAD_BASE
        call CFREAD
        ld de,LOAD_BASE+54
        ld b,20
        call SWPSTR
        ld de,LOAD_BASE+54
        ld b,40
        call PRNSTR
        call NEWLINE
        ret        
; Reads single sector
; Source in CFLBAx variables
; Destination address in DE        
CFRSECT:
		call CFSLBA						;SET LBA
		ld a,01H
		out (CFREG2),a						;READ ONE SECTOR
		call CFWAIT
		ld a,20H						;READ SECTOR COMMAND
		out (CFREG7),a
		;LXI	D, LOAD_BASE
		call CFREAD
		call CFCHERR
		ret
		
CFR32SECTORS:
		call CFSLBA
		ld a,20H						;Read 32 sectors
		out (CFREG2),a
		call CFWAIT
		ld a,20H
		out (CFREG7),a
		ld de,LOAD_BASE
		call CFREAD
		call CFCHERR
		ret
        
CFWSECT:
        call CFSLBA                     ;SET LBA
        ld a,01H
        out (CFREG2),a                      ;WRITE ONE SECTOR
        call CFWAIT
        ld a,30H                      ;WRITE SECTOR COMMAND
        out (CFREG7),a
        ld de,LOAD_BASE
        call CFWRITE
        call CFCHERR
        ret
PRN_PARTITION_TABLE:
        ;Print partition info
        ;Print partition 1 addres first
        ld a,1
        call PRN_IND_DIGIT
        ld de,STARTADDRSTR
        ld b,6
        call PRNSTR
        call PRN_ZERO_EX
        ld de,LOAD_BASE+446+8+3
		call HEXDUMP32BITVAL_PLUS_SPACE
        ;Print size then
        ld de,SIZESTR
        ld b,6
        call PRNSTR
        call PRN_ZERO_EX
        ld de,LOAD_BASE+446+12+3
        call HEXDUMP32BITVAL
        call NEWLINE
        ;Print partition 2 addres first    
        ld a,2;
        call PRN_IND_DIGIT
        ld de,STARTADDRSTR
        ld b,6
        call PRNSTR
        call PRN_ZERO_EX
        ld de,LOAD_BASE+462+8+3
		call HEXDUMP32BITVAL_PLUS_SPACE
		;Print size then
        ld de,SIZESTR
        ld b,6
        call PRNSTR
        call PRN_ZERO_EX
		ld de,LOAD_BASE+462+12+3
		call HEXDUMP32BITVAL
		call NEWLINE
        ;Print partition 3 addres first
        ld a,3;
        call PRN_IND_DIGIT
        ld de,STARTADDRSTR
        ld b,6
        call PRNSTR
        call PRN_ZERO_EX
        ld de,LOAD_BASE+478+8+3
        call HEXDUMP32BITVAL_PLUS_SPACE
		;Print size then
        ld de,SIZESTR
        ld b,6
        call PRNSTR
        call PRN_ZERO_EX
		ld de,LOAD_BASE+478+12+3
		call HEXDUMP32BITVAL
		call NEWLINE
        ;Print partition 4 addres first
        ld a,4;
        call PRN_IND_DIGIT
        ld de,STARTADDRSTR
        ld b,6
        call PRNSTR
        call PRN_ZERO_EX
        ld de,LOAD_BASE+494+8+3
        call HEXDUMP32BITVAL_PLUS_SPACE
		;Print size then
        ld de,SIZESTR
        ld b,6
        call PRNSTR
        call PRN_ZERO_EX
		ld de,LOAD_BASE+494+12+3
		call HEXDUMP32BITVAL
		call NEWLINE
		ret
LOAD_PARTITION1:
		ld de,LOAD_BASE+446+8
		ld a,(de)
		out (CFREG3),a						;LBA 0
		inc de
		ld a,(de)
		out (CFREG4),a						;LBA 1
		inc de
		ld a,(de)
		out (CFREG5),a						;LBA 2
		inc de
		ld a,(de)
		and a,0FH							;FILTER OUT LBA BITS
		or a,0E0H						;MODE LBA, MASTER DEV
		out (CFREG6),a						;LBA 3
		; MVI A, 01H					;READ ONE SECTOR
		ld a,17						;READ 17 SECTORS (13kB-512 bytes to preserve stack)
		out (CFREG2),a						
		call CFWAIT
		ld a,20H						;READ SECTOR COMMAND
		out (CFREG7),a
		ld de,LOAD_BASE
		call CFREAD
		call CFCHERR
		ret
