CFWAIT:
        IN CFREG7
        ANI 80H                         ;MASK OUT BUSY FLAG
        JNZ CFWAIT
        RET

CFCHERR:	
        IN CFREG7
        ANI	01H		                    ;MASK OUT ERROR BIT
        JZ	CFNERR
        IN	CFREG1
		RET
CFNERR:
		MVI A, 00H
        RET    
            
CFREAD:
        CALL CFWAIT
        IN CFREG7
        ANI	08H	                    ;FILTER OUT DRQ
        JZ CFREADE
        IN CFREG0		            ;READ DATA BYTE
        STAX D
        INX D
        JMP	CFREAD
CFREADE:
        RET
        
CFWRITE:
        CALL CFWAIT
        IN CFREG7
        ANI 08H                     ;FILTER OUT DRQ
        JZ CFWRITEE
        LDAX D
        OUT CFREG0
        INX D
        JMP CFWRITE
CFWRITEE:
        RET
        
CFSLBA:
        LDA CFLBA0		                ;LBA 0
        OUT CFREG3
        LDA CFLBA1		                ;LBA 1
        OUT CFREG4
        LDA CFLBA2		                ;LBA 2
        OUT CFREG5	
        LDA CFLBA3		                ;LBA 3
        ANI 0FH	                        ;FILTER OUT LBA BITS
        ORI 0E0H	                    ;MODE LBA, MASTER DEV
        OUT CFREG6
        RET

; Reads single sector
; Source in CFLBAx variables
; Destination address in DE        
CFRSECT:
		CALL CFSLBA						;SET LBA
		MVI A, 01H
		OUT	CFREG2						;READ ONE SECTOR
		CALL CFWAIT
		MVI A, 20H						;READ SECTOR COMMAND
		OUT	CFREG7
		;LXI	D, LOAD_BASE
		CALL CFREAD
		CALL CFCHERR
		RET
        
CFWSECT:
        CALL CFSLBA                     ;SET LBA
        MVI A, 01H
        OUT CFREG2                      ;WRITE ONE SECTOR
        CALL CFWAIT
        MVI A, 30H                      ;WRITE SECTOR COMMAND
        OUT CFREG7
        LXI D, LOAD_BASE
        CALL CFWRITE
        CALL CFCHERR
        RET
