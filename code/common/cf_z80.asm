CFINIT:
		XOR A
		LD (CFLBA3), A
		XOR A
		LD (CFLBA2), A
		XOR A
		LD (CFLBA1), A
		XOR A
		LD (CFLBA0), A
        LD A, 04H
        OUT (CFREG7), A
        CALL CFWAIT_TMOUT
        LD A, 0E0H		                ;LBA3=0, MASTER, MODE=LBA
        OUT	(CFREG6), A
        LD A, 01H		                ;8-BIT TRANSFERS
        OUT (CFREG1), A
        LD A, 0EFH		                ;SET FEATURE COMMAND
        OUT (CFREG7), A
        CALL CFWAIT_TMOUT
        OR A							;Check if wait loop timeouted
        JP NZ, CFINIT_RET					;If so there is no point in checking error code
        CALL CFCHERR
CFINIT_RET
        RET

CFWAIT:
        IN A, (CFREG7)
        AND 80H                         ;MASK OUT BUSY FLAG
        JP NZ, CFWAIT
        RET
        
CFWAIT_TMOUT:
		LD C, 64
CFWAIT_TMOUT_LOOP_EXT:
		LD B, 255
CFWAIT_TMOUT_LOOP_INT:
        IN A, (CFREG7)
        AND 80H                  		;MASK OUT BUSY FLAG
        JP Z, CFWAIT_TMOUT_OK
        DEC B
        JP NZ, CFWAIT_TMOUT_LOOP_INT
        DEC C
        JP Z, CFWAIT_TMOUT_NOK
        JP CFWAIT_TMOUT_LOOP_EXT
CFWAIT_TMOUT_OK:
        XOR A						;OK result
        RET
CFWAIT_TMOUT_NOK:
		LD A, 01H						;CF card timeout
		RET

CFCHERR:	
        IN A, (CFREG7)
        AND	01H		                    ;MASK OUT ERROR BIT
        JP Z, CFNERR
        IN	A, (CFREG1)
		RET
CFNERR:
		XOR A
        RET    
            
CFREAD:
        CALL CFWAIT
        IN A, (CFREG7)
        AND	08H	                    ;FILTER OUT DRQ
        JP Z, CFREADE
        IN A, (CFREG0)		            ;READ DATA BYTE
        LD (DE), A
        INC DE
        JP	CFREAD
CFREADE:
        RET
        
CFWRITE:
        CALL CFWAIT
        IN A, (CFREG7)
        AND 08H                     ;FILTER OUT DRQ
        JP Z, CFWRITEE
        LD A, (DE)
        OUT (CFREG0), A
        INC DE
        JP CFWRITE
CFWRITEE:
        RET
        
CFSLBA:
        LD A, (CFLBA0)		                ;LBA 0
        OUT (CFREG3), A
        LD A, (CFLBA1)		                ;LBA 1
        OUT (CFREG4), A
        LD A, (CFLBA2)		                ;LBA 2
        OUT (CFREG5), A	
        LD A, (CFLBA3)		                ;LBA 3
        AND 0FH	                        ;FILTER OUT LBA BITS
        OR 0E0H	                    ;MODE LBA, MASTER DEV
        OUT (CFREG6), A
        RET
        
CFGETMBR:
		XOR A
		OUT (CFREG3), A						;LBA 0
		OUT (CFREG4), A						;LBA 1
		OUT (CFREG5), A						;LBA 2
		;AND 0FH	                        ;FILTER OUT LBA BITS
		;OR 0E0H	                    ;MODE LBA, MASTER DEV
		LD A, 0E0H
        OUT (CFREG6), A
        LD A, 01H
        OUT	(CFREG2), A						;READ ONE SECTOR
		CALL CFWAIT
		LD A, 20H						;READ SECTOR COMMAND
		OUT	(CFREG7), A
		LD DE, LOAD_BASE
		CALL CFREAD
		CALL CFCHERR
		RET        
  
CFINFO:	
        CALL CFWAIT
        LD	A, 0ECH	                    ;DRIVE ID COMMAND
        OUT	(CFREG7), A
        LD DE, LOAD_BASE
        CALL CFREAD
        LD DE, LOAD_BASE+54
        LD B, 20
        CALL SWPSTR
        LD DE, LOAD_BASE+54
        LD B, 40
        CALL PRNSTR
        CALL NEWLINE
        RET        

; Reads single sector
; Source in CFLBAx variables
; Destination address in DE        
CFRSECT:
		CALL CFSLBA						;SET LBA
		LD A, 01H
		OUT	(CFREG2), A						;READ ONE SECTOR
		CALL CFWAIT
		LD A, 20H						;READ SECTOR COMMAND
		OUT	(CFREG7), A
		;LD	DE, LOAD_BASE
		CALL CFREAD
		CALL CFCHERR
		RET
		
CFR32SECTORS:
		CALL CFSLBA
		LD A, 20H						;Read 32 sectors
		OUT (CFREG2), A
		CALL CFWAIT
		LD A, 20H
		OUT (CFREG7), A
		LD DE, LOAD_BASE
		CALL CFREAD
		CALL CFCHERR
		RET
        
CFWSECT:
        CALL CFSLBA                     ;SET LBA
        LD A, 01H
        OUT (CFREG2), A                      ;WRITE ONE SECTOR
        CALL CFWAIT
        LD A, 30H                      ;WRITE SECTOR COMMAND
        OUT (CFREG7), A
        LD DE, LOAD_BASE
        CALL CFWRITE
        CALL CFCHERR
        RET

PRN_PARTITION_TABLE:
        ;Print partition info
        ;Print partition 1 addres first
        LD A, 1
        CALL PRN_IND_DIGIT
        LD DE, STARTADDRSTR
        LD B, 6
        CALL PRNSTR
        CALL PRN_ZERO_EX
        LD DE, LOAD_BASE+446+8+3
		CALL HEXDUMP32BITVAL_PLUS_SPACE
        ;Print size then
        LD DE, SIZESTR
        LD B, 6
        CALL PRNSTR
        CALL PRN_ZERO_EX
        LD DE, LOAD_BASE+446+12+3
        CALL HEXDUMP32BITVAL
        CALL NEWLINE
        ;Print partition 2 addres first    
        LD A, 2;
        CALL PRN_IND_DIGIT
        LD DE, STARTADDRSTR
        LD B, 6
        CALL PRNSTR
        CALL PRN_ZERO_EX
        LD DE, LOAD_BASE+462+8+3
		CALL HEXDUMP32BITVAL_PLUS_SPACE
		;Print size then
        LD DE, SIZESTR
        LD B, 6
        CALL PRNSTR
        CALL PRN_ZERO_EX
		LD DE, LOAD_BASE+462+12+3
		CALL HEXDUMP32BITVAL
		CALL NEWLINE
        ;Print partition 3 addres first
        LD A, 3;
        CALL PRN_IND_DIGIT
        LD DE, STARTADDRSTR
        LD B, 6
        CALL PRNSTR
        CALL PRN_ZERO_EX
        LD DE, LOAD_BASE+478+8+3
        CALL HEXDUMP32BITVAL_PLUS_SPACE
		;Print size then
        LD DE, SIZESTR
        LD B, 6
        CALL PRNSTR
        CALL PRN_ZERO_EX
		LD DE, LOAD_BASE+478+12+3
		CALL HEXDUMP32BITVAL
		CALL NEWLINE
        ;Print partition 4 addres first
        LD A, 4;
        CALL PRN_IND_DIGIT
        LD DE, STARTADDRSTR
        LD B, 6
        CALL PRNSTR
        CALL PRN_ZERO_EX
        LD DE, LOAD_BASE+494+8+3
        CALL HEXDUMP32BITVAL_PLUS_SPACE
		;Print size then
        LD DE, SIZESTR
        LD B, 6
        CALL PRNSTR
        CALL PRN_ZERO_EX
		LD DE, LOAD_BASE+494+12+3
		CALL HEXDUMP32BITVAL
		CALL NEWLINE
		RET

LOAD_PARTITION1:
		LD DE, LOAD_BASE+446+8
		LD A, (DE)
		OUT (CFREG3), A						;LBA 0
		INC DE
		LD A, (DE)
		OUT (CFREG4), A						;LBA 1
		INC DE
		LD A, (DE)
		OUT (CFREG5), A						;LBA 2
		INC DE
		LD A, (DE)
		AND 0FH							;FILTER OUT LBA BITS
		OR 0E0H						;MODE LBA, MASTER DEV
		OUT (CFREG6), A						;LBA 3
		; LD A, 01H					;READ ONE SECTOR
		LD A, 17						;READ 17 SECTORS (13kB-512 bytes to preserve stack)
		OUT	(CFREG2), A						
		CALL CFWAIT
		LD A, 20H						;READ SECTOR COMMAND
		OUT	(CFREG7), A
		LD DE, LOAD_BASE
		CALL CFREAD
		CALL CFCHERR
		RET
