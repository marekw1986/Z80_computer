PARTADDR    DS   16                         ;PARTITION ADDR TABLE
BLKDAT:     DS   512                        ;BUFFER FOR SECTOR TRANSFER
BLKENDL     DS   1                          ;BUFFER ENDS
CFVAL       DS   1
CFLBA3	    DS	 1
CFLBA2	    DS	 1
CFLBA1	    DS	 1
CFLBA0	    DS	 1
PCFLBA3	    DS	 1
PCFLBA2	    DS	 1
PCFLBA1	    DS	 1
PCFLBA0	    DS	 1
DEFERREDWR  DS   1

CFWAIT:
        IN A, (CFREG7)
        AND 80H                         ;MASK OUT BUSY FLAG
        JR NZ, CFWAIT
        RET
        
CFCHERR:	
        IN A, (CFREG7)
        AND	01H		                    ;MASK OUT ERROR BIT
        JR Z, CFNERR
        IN	A, (CFREG1)
		RET
CFNERR:
		XOR A
        RET    
            
CFREAD:
        CALL CFWAIT
        IN A, (CFREG7)
        AND	08H	                    ;FILTER OUT DRQ
        JR Z, CFREADE
        IN A, (CFREG0)		            ;READ DATA BYTE
        LD (DE), A
        INC DE
        JR	CFREAD
CFREADE:
        RET
        
CFWRITE:
        CALL CFWAIT
        IN A, (CFREG7)
        AND 08H                     ;FILTER OUT DRQ
        JR Z, CFWRITEE
        LD A, (DE)
        OUT (CFREG0), A
        INC DE
        JR CFWRITE
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
		CALL CFREAD
		CALL CFCHERR
		RET
		
; Reads single sector
; Source in CFLBAx variables
; Destination address is BLKDAT     
CFRSECT_WITH_CACHE:
		LD A, (CFVAL)						; Check if we have valid data in buffer
		OR A
		JR Z, CFRSECT_WITH_CACHE_PERFORM  ; If not, read
		LD HL, CFLBA3					; Check if old and new LBA values are equal
		LD DE, PCFLBA3
		CALL IS32BIT_EQUAL
		OR A							; If not, new LBA. Read imediately
		JR Z, CFRSECT_WITH_CACHE_PERFORM
		; We already have valid data in buffer. No need to read it again
		XOR A						; Store 0 in A to signalize no err
		RET
CFRSECT_WITH_CACHE_PERFORM:
        ; Check if we had deferred write - if so, we need to write that data
        ; out of buffer before reading new ones
        LD A, (DEFERREDWR)
        OR A
        JR Z, CFRSECT_WITH_CACHE_PERFORM1       ; No deferred data to write in buffer - just read
        ; Otherwise write data in buffer to CF card first
        ; We need to use old LBA values for write!!!
        CALL CFSWAPLBA
        LD DE, BLKDAT
        CALL CFWSECT
        ; Check result of write operation
        OR A
        JR NZ, CFRSECT_WITH_CACHE_BAD
        XOR A
        LD (DEFERREDWR), A                      ; No longer defererred write - clear flag
        CALL CFSWAPLBA                          ; Restore original LBA values
CFRSECT_WITH_CACHE_PERFORM1:        
		CALL CFSLBA						;SET LBA
		LD A, 01H
		OUT (CFREG2), A						;READ ONE SECTOR
		CALL CFWAIT
		LD A, 20H						;READ SECTOR COMMAND
		OUT (CFREG7), A
		LD	DE, BLKDAT
		CALL CFREAD
		CALL CFCHERR
		OR A							; If A=0, no error, good read
		JR NZ, CFRSECT_WITH_CACHE_BAD
		PUSH AF
		LD A, 01H
		LD (CFVAL), A
		; copy CFLBAx toPCFLBAx
        CALL CFUPDPLBA
		POP AF 
		RET
CFRSECT_WITH_CACHE_BAD:
        PUSH AF
        XOR A
        LD (CFVAL), A
        POP AF
		RET
        
CFWSECT:
        CALL CFSLBA                     ;SET LBA
        LD A, 01H
        OUT (CFREG2), A                      ;WRITE ONE SECTOR
        CALL CFWAIT
        LD A, 30H                      ;WRITE SECTOR COMMAND
        OUT (CFREG7), A
        CALL CFWRITE
        CALL CFCHERR
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
		LD	DE, BLKDAT
		CALL CFREAD
		CALL CFCHERR
		RET
        
CFFLUSHDEFFERED:
		LD A, (CFVAL)						; Check if we have valid data in buffer
		OR A
		RET Z                               ; If not, return
        ; Check if we had deferred write
        LD A, (DEFERREDWR)
        OR A
        RET Z                               ; No deferred data to write in buffer - just return
        ; Otherwise write data in buffer to CF card
        ; We use current setting of LBAs (no swap)
        LD DE, BLKDAT
        CALL CFWSECT
        XOR A
        LD (DEFERREDWR), A
        RET

; This assumes that MBR is already in BLKDAT
; CALL CFGETMBR FIRST!
CFLDPARTADDR:
        LD A, (BLKDAT+446+8)
        LD (PARTADDR), A
        LD A, (BLKDAT+446+8+1)
        LD (PARTADDR+1), A
        LD A, (BLKDAT+446+8+2)
        LD (PARTADDR+2), A
        LD A, (BLKDAT+446+8+3)
        LD (PARTADDR+3), A
        
        LD A, (BLKDAT+462+8)
        LD (PARTADDR+4), A
        LD A, (BLKDAT+462+8+1)
        LD (PARTADDR+5), A
        LD A, (BLKDAT+462+8+2)
        LD (PARTADDR+6), A
        LD A, (BLKDAT+462+8+3)
        LD (PARTADDR+7), A
        
        LD A, (BLKDAT+478+8)
        LD (PARTADDR+8), A
        LD A, (BLKDAT+478+8+1)
        LD (PARTADDR+9), A
        LD A, (BLKDAT+478+8+2)
        LD (PARTADDR+10), A
        LD A, (BLKDAT+478+8+3)
        LD (PARTADDR+11), A

        LD A, (BLKDAT+494+8)
        LD (PARTADDR+12), A
        LD A, (BLKDAT+494+8+1)
        LD (PARTADDR+13), A
        LD A, (BLKDAT+494+8+2)
        LD (PARTADDR+14), A
        LD A, (BLKDAT+494+8+3)
        LD (PARTADDR+15), A
        RET

CFUPDPLBA:
        LD A, (CFLBA3)
        LD (PCFLBA3), A
        LD A, (CFLBA2)
        LD (PCFLBA2), A
        LD A, (CFLBA1)
        LD (PCFLBA1), A
        LD A, (CFLBA0)
        LD (PCFLBA0), A
        RET

CFSWAPLBA:
        ; Swap CFLBA0 <-> PCFLBA0
        LD A,(CFLBA0)
        LD B,A
        LD A,(PCFLBA0)
        LD (CFLBA0),A
        LD A,B
        LD (PCFLBA0),A
        ; Swap CFLBA1 <-> PCFLBA1
        LD A,(CFLBA1)
        LD B,A
        LD A,(PCFLBA1)
        LD (CFLBA1),A
        LD A,B
        LD (PCFLBA1),A
        ; Swap CFLBA2 <-> PCFLBA2
        LD A,(CFLBA2)
        LD B,A
        LD A,(PCFLBA2)
        LD (CFLBA2),A
        LD A,B
        LD (PCFLBA2),A
        ; Swap CFLBA3 <-> PCFLBA3
        LD A,(CFLBA3)
        LD B,A
        LD A,(PCFLBA3)
        LD (CFLBA3),A
        LD A,B
        LD (PCFLBA3),A
        RET
