CCP		EQU	0DC00H   ; was 2200H
BDOS	EQU CCP+806H
BIOS	EQU CCP+1600H
CDISK	EQU	0004H
IOBYTE	EQU 0003H

; WARNING: The following assumes that CPM_BASE%128 = 0
WB_NSECTS	EQU		(BIOS_BOOT-CCP)/128					; number of sectors to load
WB_TRK		EQU		0									; first track now at beginning of partition now
WB_SEC		EQU		(CCP/128)&03H						; first sector number

DEBUG	EQU 0

CR          EQU  0DH
LF          EQU  0AH
;**************************************************************
;*
;*        B I O S   J U M P   T A B L E
;*
;**************************************************************
		
		org 0F200H   ; was 3800H
	IF $ != CCP+1600H
		error "BIOS begins at wrong address!"
	ENDIF	
BIOS_BOOT:   JP      BIOS_BOOT_PROC
BIOS_WBOOT:  JP      BIOS_WBOOT_PROC
BIOS_CONST:  JP      BIOS_CONST_PROC
BIOS_CONIN:  JP      BIOS_CONIN_PROC
BIOS_CONOUT: JP      BIOS_CONOUT_PROC
BIOS_LIST:   JP      BIOS_LIST_PROC
BIOS_PUNCH:  JP      BIOS_PUNCH_PROC
BIOS_READER: JP      BIOS_READER_PROC
BIOS_HOME:   JP      BIOS_HOME_PROC
BIOS_SELDSK: JP      BIOS_SELDSK_PROC
BIOS_SETTRK: JP      BIOS_SETTRK_PROC
BIOS_SETSEC: JP      BIOS_SETSEC_PROC
BIOS_SETDMA: JP      BIOS_SETDMA_PROC
BIOS_READ:   JP      BIOS_READ_PROC
BIOS_WRITE:  JP      BIOS_WRITE_PROC
BIOS_PRSTAT: JP      BIOS_PRSTAT_PROC
BIOS_SECTRN: JP      BIOS_SECTRN_PROC	

BIOS_BOOT_PROC:
		DI
		LD SP, BIOS_STACK

        ; Turn on ROM shadowing
		LD  A, 084H
        OUT  (PORT_74237), A
        NOP
        NOP
        
        XOR A
        LD HL, 0000H
        LD BC, CCP
ZERO_LOOP:
        XOR A
        LD (HL), A
        INC HL
        DEC BC
        LD A, B
        OR C
        JP NZ, ZERO_LOOP
        CALL CFGETMBR
        OR A                     ; Check if MBR loaded properly
        JP Z, LD_PART_TABLE
        CALL IPUTS
        DB 'MBR load err. Reset required.'
        DB 00H
        CALL ENDLESS_LOOP
LD_PART_TABLE:
        CALL CFLDPARTADDR
CFVAR_INIT:
		XOR A
		LD (CFLBA3), A
		LD (CFLBA2), A
		LD (CFLBA1), A
		LD (CFLBA0), A
		LD (PCFLBA3), A
		LD (PCFLBA2), A
		LD (PCFLBA1), A
		LD (PCFLBA0), A
		LD (CFVAL), A
		CALL IPUTS
		DB 'Running CP/M 2.2'
		DB CR
		DB 00H
		CALL IPUTS
		DB 'CRC: '
		DB 00H
		LD DE, CCP
		LD BC, BIOS_STACK_END-CCP
		LD HL, 0000H
CPM_CRC_LOOP:
		LD A, (DE)
		PUSH BC
		CALL CRC16_ARC_F
		POP BC
		INC DE
		DEC BC
		LD A, B
		OR C
		JP NZ, CPM_CRC_LOOP
		CALL PRN_ZERO_EX
		LD A, H
		CALL HEXDUMP_A
		LD A, L
		CALL HEXDUMP_A
		CALL NEWLINE
		XOR A
		LD (IOBYTE), A
		LD (CDISK), A
		JP GOCPM
	
BIOS_WBOOT_PROC:
		DI
		; We can't just blindly set SP=bios_stack here because disk_read can overwrite it!
		; But we CAN set to use other areas that we KNOW are not currently in use!
		LD SP, BIOS_WBOOT_STACK		;
		LD C, 0
		CALL BIOS_SELDSK
		LD BC, WB_TRK
		CALL BIOS_SETTRK
		LD BC, WB_SEC
		CALL BIOS_SETSEC
		LD BC, CCP
		CALL BIOS_SETDMA
		LD BC, WB_NSECTS
BIOS_WBOOT_LOOP:
		PUSH BC	; Save remaining sector count
		CALL BIOS_READ
		OR A
		JR Z, BIOS_WBOOT_SEC_OK
		CALL IPUTS
		DB 'ERROR: WBOOT FAILED. HALTING.'
		DB CR
		DB '*** PRESS RESET TO REBOOT ***'
		DB CR
		DB 00H
		JP $
BIOS_WBOOT_SEC_OK:
		; Advance the DMA pointer by 128 bytes
		LD HL, (DISK_DMA)	; HL = last used DMA address
		LD DE, 128
        ADD HL, DE          ; HL += 128
        LD B, H
        LD C, L             ; BC = HL
		CALL BIOS_SETDMA
		LD A, (DISK_SECTOR)		; A = last used sector number (low byte only for 0..3)
		INC A
		AND 03H				; if A+1 = 4 then A=0
		JR NZ, BIOS_WBOOT_SEC	; if A+1 !=4 then do not advance the track number
		; Advance to the next track
        LD BC, (DISK_TRACK)
        INC BC
		CALL BIOS_SETTRK
		XOR A 			; sett A=0 for first sector on new track
BIOS_WBOOT_SEC:
		LD B, 00H
		LD C, A
		CALL BIOS_SETSEC
		POP BC				; BC = remaining sector counter value
		DEC BC				; BC--
		LD A, B
		OR C
		JR NZ, BIOS_WBOOT_LOOP
		; Fall through into GOCPM
GOCPM:
		LD A, 0C3H ;C3 is a jump instruction
		LD (0), A		;for JMP to wboot
		LD HL, BIOS_WBOOT	;WBOOT entry point
		LD (1), HL		;Set address field for jmp at 0
		
		LD (5), A		;For JMP to bdos
		LD HL, BDOS	;BDOS entry point
		LD (6), HL		;Address field of jump at 5 to bd
		
		; This is here because it is in example CBIOS (AG p. 52)
		LD HL, 0080H	;default DMA address is 80H (TODO! Check!)
		LD (DISK_DMA), HL
		
		; EI			;Enable interrupts
		LD A, (CDISK)	;Load current disk number
		LD C, A	;Send to the CCP
		JP CCP		;Go to the CP/M for further processing
	
BIOS_CONST_PROC:
        IN   A, (DART_A_CMD)
        NOP                             ;STATUS BIT FLIPPED?
        AND  RxRDY_MASK                 ;MASK STATUS BIT
		RET
	
BIOS_CONIN_PROC:
        IN   A, (DART_A_CMD)
        NOP
        AND  RxRDY_MASK
        JR Z, BIOS_CONIN_PROC
        IN   A, (DART_A_DATA)
		RET
	
BIOS_CONOUT_PROC:
		PUSH HL				; Save content  of HL on original stack, then switch to bios stack
		LD HL, 0000H
		ADD HL, SP	; HL = HL + SP
		LD (ORIGINAL_SP), HL
		LD SP, BIOS_STACK
		PUSH AF
		LD A, C			; Save A on BIOS stack
		CALL OUT_CHAR
		POP AF			; Restore A from new stack
		LD HL, (ORIGINAL_SP); Restore original stack
		LD SP, HL
		POP HL			; Restore original content of HL	
		RET
		
BIOS_LIST_PROC:
		RET
		  
BIOS_PUNCH_PROC:
		RET
		 
BIOS_READER_PROC:
		LD A, 1AH
		RET
		
BIOS_HOME_PROC:
		LD BC, 0000H
		;FALL INTO BIOS_SETTRK_PROC!!!
		
BIOS_SETTRK_PROC:
		LD (DISK_TRACK), BC
		RET
		  
BIOS_SELDSK_PROC:
		LD A, C
        CP 04H     ; Only four partitions supported
        JR NC, BIOS_SELDSK_PROC_WRNDSK
        LD (DISK_DISK), A
		LD HL, DISKA_DPH	
		RET
BIOS_SELDSK_PROC_WRNDSK:
        LD HL, 0
        RET
		
BIOS_SETSEC_PROC:
		LD (DISK_SECTOR), BC	
		RET
		
BIOS_SETDMA_PROC:
		LD (DISK_DMA), BC
		RET
		
BIOS_READ_PROC:
		PUSH HL				; Save content  of HL on original stack, then switch to bios stack
		LD HL, 0000H
		ADD HL, SP	; HL = HL + SP
		LD (ORIGINAL_SP), HL
		LD SP, BIOS_STACK
	IF DEBUG > 0
        PUSH AF
        PUSH BC
		PUSH DE
		PUSH HL
		CALL IPUTS
		DB 'READ procedure entered: '
		DB 00H
		CALL PRINT_DISK_DEBUG
		POP HL
		POP DE
		POP BC
		POP AF
	ENDIF
		PUSH BC				; Now save remaining registers
		PUSH DE
        CALL CALC_CFLBA_FROM_PART_ADR
        OR A                            ; If 0 in A, no valid LBA calculated
        JP Z, BIOS_READ_PROC_RET_ERR          ; In that case return and report error
		CALL CFRSECT_WITH_CACHE
	IF DEBUG > 0
        PUSH AF
        PUSH BC
		PUSH DE
		PUSH HL
		CALL PRINT_CFLBA_DEBUG
		POP HL
		POP DE
		POP BC
		POP AF
	ENDIF
		; If no error there should be 0 in A
		OR A
		JP Z, BIOS_READ_PROC_GET_SECT		; No error, just read sector. Otherwise report error and return.
        JP BIOS_READ_PROC_RET_ERR		; Return
BIOS_READ_PROC_GET_SECT:
        CALL BIOS_CALC_SECT_IN_BUFFER
		; Now DE contains the 16-bit result of multiplying the original value by 128
		; D holds the high byte and E holds the low byte of the result
		; Calculate the address of the CP/M sector in the BLKDAT
		LD HL, BLKDAT
		LD A, E
		ADD A, L
		LD E, A
		LD A, D
		ADC A, H
		LD D, A
	IF DEBUG > 1
		PUSH DE	; Store DE (source address) in stack
		CALL IPUTS
		DB 'Calculated source address in CF bufffer = 0x'
		DB 00H
		POP DE	; Retrieve DE (source address)
		LD A, D
		CALL HEXDUMP_A
		LD A, E
		CALL HEXDUMP_A
		LD A, CR
		CALL OUT_CHAR
	IF 0
		PUSH DE
		CALL IPUTS
		DB 'Buffer before copy: '
		DB 00H
		POP DE
		PUSH DE
		LD B, 80H
		CALL HEXDUMP
		LD A, CR
		CALL OUT_CHAR
		POP DE
	ENDIF
	ENDIF
		; Source addres in DE
		LD HL, (DISK_DMA)	; Load target address to HL
		LD BC, 0080H	; How many bytes?
		CALL MEMCOPY
	IF 0 ;DEBUG > 0
		PUSH DE
		CALL IPUTS
		DB 'Buffer after copy: '
		DB 00H		
		POP DE
		LD HL, (DISK_DMA)
		LD D, H
		LD E, L
		LD B, 80H
		CALL HEXDUMP
		LD A, CR
		CALL OUT_CHAR
	ENDIF
BIOS_READ_PROC_RET_ERR
        LD A, 1
        JP BIOS_READ_PROC_RET
BIOS_READ_PROC_RET_OK    
        LD A, 0
BIOS_READ_PROC_RET
		POP DE
		POP BC
		LD HL, (ORIGINAL_SP); Restore original stack
		LD SP, HL
		POP HL			; Restore original content of HL
		LD A, 0
		RET
		  
BIOS_WRITE_PROC:
		PUSH HL				; Save content  of HL on original stack, then switch to bios stack
		LD HL, 0000H
		ADD HL, SP	; HL = HL + SP
		LD (ORIGINAL_SP), HL
		LD SP, BIOS_STACK
		
	IF DEBUG > 0
        PUSH AF
        PUSH BC
		PUSH DE
		PUSH HL
		CALL IPUTS
		DB 'WRITE procedure entered'
		DB CR
		DB 00H
		POP HL
		POP DE
		POP BC
		POP AF
	ENDIF
		PUSH BC				; Now save remaining registers
		PUSH DE
        ; Check content of C - deblocking code
        LD A, C
        CP 2               ; Is it first sector of new track?
        JP Z, BIOS_WRITE_NEW_TRACK
		; First read sector to have complete data in buffer
		CALL CFRSECT_WITH_CACHE
		OR A
		JP NZ, BIOS_WRITE_RET_ERR			; If we ae unable to read sector, it ends here. We would risk FS crash otherwise.
		CALL BIOS_CALC_SECT_IN_BUFFER
		; Now DE contains the 16-bit result of multiplying the original value by 128
		; D holds the high byte and E holds the low byte of the result
		; Calculate the address of the CP/M sector in the BLKDAT
		LD HL, BLKDAT
		LD A, E
		ADD A, L
		LD E, A
		LD A, D
		ADC A, H
		LD D, A
        JP BIOS_WRITE_PERFORM
        ; No need to calculate sector location in BLKDAT.
        ; Thanks to deblocking code = 2 we know it is first secor of new track
        ; Just fill remaining bytes of buffer with 0xE5 and copy secotr to the
        ; beginning of BLKDAT. Then write.
BIOS_WRITE_NEW_TRACK
        LD HL, BLKDAT+128
        LD BC, 384
BIOS_WRITE_E5_FILL_LOOP:
        LD A, 0E5H
        LD (HL), A
        INC HL
        DEC BC
        LD A, B
        OR C
        JP NZ, BIOS_WRITE_E5_FILL_LOOP
        LD DE, BLKDAT
BIOS_WRITE_PERFORM:
		; Addres of sector in BLKDAT is now in DE
		LD HL, (DISK_DMA)	; Load source address to HL
		; Replace HL and DE. HL will now contain address od sector in BLKDAT and DE will store source from DISK_DMA
		EX DE, HL
		LD BC, 0080H	; How many bytes to copy?
		CALL MEMCOPY
		; Buffer is updated with new sector data. Perform write.
        CALL CALC_CFLBA_FROM_PART_ADR
        OR A         ; If A=0, no valid LBA calculated
        JP Z, BIOS_WRITE_RET_ERR ; Return and report error
		LD DE, BLKDAT
		CALL CFWSECT
		OR A			; Check result
		JP NZ, BIOS_WRITE_RET_ERR
		JP BIOS_WRITE_RET_OK				
BIOS_WRITE_RET_ERR:
        XOR A
        LD (CFVAL), A
		LD A, 1
		JP BIOS_WRITE_RET
BIOS_WRITE_RET_OK:
        LD A, 01H
        LD (CFVAL), A
        CALL CFUPDPLBA
		LD A, 0
BIOS_WRITE_RET:
		POP DE
		POP BC	
		LD HL, (ORIGINAL_SP); Restore original stack
		LD SP, HL
		POP HL			; Restore original content of HL
		RET
		 
BIOS_PRSTAT_PROC:
		LD A, 0 ;Printer is never ready
		RET
		
BIOS_SECTRN_PROC:
		; 1:1 translation (no skew factor)
		LD H, B
		LD L, C
	IF DEBUG > 1
		PUSH HL				; Save content  of HL on original stack, then switch to bios stack
		LD HL, 0000H
		ADD HL, SP	; HL = HL + SP
		LD (ORIGINAL_SP), HL
		LD SP, BIOS_STACK
        PUSH AF
        PUSH BC
		PUSH DE
		PUSH HL
		CALL IPUTS
		DB 'SECTRN procedure entered: '
		DB 00H
		CALL PRINT_DISK_DEBUG
		POP HL
		POP DE
		POP BC
		POP AF
		LD HL, (ORIGINAL_SP); Restore original stack
		LD SP, HL
		POP HL			; Restore original content of HL
	ENDIF		
		RET
		
;KBDINIT - initializes 8042/8242 PS/2 keyboard controller
;Affects: A, B, C, Z
;Returns result code in  B:
;0x00 - OK
;0x01 - Controller self test failed
;0x02 - CLK stuck low
;0x03 - CLK stuck high
;0x04 - KBD DATA stuck low
;0x05 - KBD DATA stuck high
;0x06 - Interface didn't pass the test
;0x07 - Keyboard reset failure/no keyboard present        
;BIOS_KBDINIT:
;        ;1. Disable devices
;        CALL KBDWAITINBUF           ;Send 0xAD command to the PS/2 controller
;        MVI A, 0ADH
;        OUT KBD_CMD
;        ;2. Flush The Output Buffer
;        IN KBD_STATUS
;        ANI 01H                     ;Check if there is data to flush
;        JZ BIOS_KBDCRTLSET              	;No? Next step then
;        IN KBD_DATA                 ;Yes? Get the data byte        
;BIOS_KBDCRTLSET:
;        ;3. Set the Controller Configuration Byte (temp)
;        CALL KBDWAITINBUF			;Send 0x60 command to the PS/2 controller
;        MVI A, 60H
;        OUT KBD_CMD
;        CALL KBDWAITINBUF			;Send actual configuration byte
;        MVI A, 08H					;Interrupts disabled, system flag set, first port clock enabled
;		OUT KBD_DATA				;second port clock disabled, first port translation disabled
;        ;4. Controller self test
;		CALL KBDWAITINBUF
;        MVI A, 0AAH                 ;Send 0xAA command to the PS/2 controller
;        OUT KBD_CMD
;		CALL KBDWAITOUTBUF          ;Wait for response
;        IN KBD_DATA                 ;Get byte
;        CPI 55H                     ;Is it 0x55?
;        MVI B, 01H					;Return result code if not
;        RNZ                          ;No? Return then
;        ;5. Interface test
;		CALL KBDWAITINBUF
;        MVI A, 0ABH                 ;Send 0xAB command
;       OUT KBD_CMD
;		CALL KBDWAITOUTBUF          ;Wait for response
;        IN KBD_DATA                 ;Get byte
;        CPI 01H                     ;Check if it is CLK stuck low error
;        MVI B, 02H                  ;Return result code if it is
;        RZ                         
;        CPI 02H                     ;Check if it is CLK stuck high error
;        MVI B, 03H                  ;Return result code if it is
;        RZ                         
;        CPI 03H                     ;Check if it is KBD DATA stuck low error
;        MVI B, 04H                  ;Return result code if it is
;        RZ
;        CPI 04H                     ;Check if it is KBD DATA stuck high error
;        MVI B, 05H                  ;Return result code if it is
;        RZ                         
;        CPI 00H                     ;Is it 0x00? Did it pass the test?
;        MVI B, 06H					;Return result code if not
;        RNZ                          ;No? Return then
;        ;6. Enable Devices
;        CALL KBDWAITINBUF
;        MVI A, 0AEH                 ;Send 0xAE command
;        OUT KBD_CMD
;        ;7. Reset Device
;        CALL KBDWAITINBUF           ;Wait untill ready to send
;        MVI A, 0FFH                 ;Send 0xFF to device
;        OUT KBD_DATA                ;Send it to device, not the controller
;        MVI C, 130                  ;Setup DELAY routine
;        CALL DELAY                  ;This is required to avoid freeze
;        CALL KBDWAITOUTBUF          ;Wait for response
;        IN KBD_DATA                 ;Get byte
;        CPI 0FAH                    ;Is it 0xFA? 0xFC means failure. No response means no device present.
;        MVI B, 07H					;Return result code if not
;        RNZ                          ;No? Return then
;        ;8. Set the Controller Configuration Byte (final)
;        CALL KBDWAITINBUF			;Send 0x60 command to the PS/2 controller
;        MVI A, 60H
;        OUT KBD_CMD
;        CALL KBDWAITINBUF			;Send actual configuration byte
;        MVI A, 08H					;Interrupts disabled, system flag set, first port clock enabled
;		OUT KBD_DATA				;second port clock disabled, first port translation disabled
;        ;9. Zero out buffer        
;        MVI A, 00H                  
;        STA KBDDATA					;Zero KBDDATA
;        STA KBDKRFL					;Zero key release flag
;        STA KBDSFFL					;Zero shift flag
;        STA KBDOLD					;Zero old data
;        STA KBDNEW					;Zero new data
;        MVI B, 00H					;Return result code
;        RET

BIOS_CALC_SECT_IN_BUFFER:
        LD A, (DISK_SECTOR)  ; Load sector number
        LD E, A         ; Store in E (low byte)
        LD D, 0         ; Clear D (high byte)
        LD B, 7         ; Loop counter (7 shifts)
CALC_SECTOR_SHIFT_LOOP:
        LD A, E  
        ADD A, A   ; Shift E left (×2)
        LD E, A  
        LD A, D  
        ADC A, A   ; Shift D left with carry
        LD D, A  
        DEC B   ; Decrement counter
        JP NZ, CALC_SECTOR_SHIFT_LOOP  ; Repeat until done		
		RET
        
CALC_CFLBA_FROM_PART_ADR:
        LD HL, PARTADDR
        LD A, (DISK_DISK)
CALC_CFLBA_LOOP_START
        OR A
        JP Z, CALC_CFLBA_LOOP_END
        DEC A
        INC HL
        INC HL
        INC HL
        INC HL
        JP CALC_CFLBA_LOOP_START
; Check if partition address is != 0
        LD D, H
        LD E, L
        CALL ISZERO32BIT
        JP Z, CALC_CFLBA_RET_ERR
CALC_CFLBA_LOOP_END:       
        LD B, (HL)
        INC HL
        LD C, (HL)
        INC HL
        LD D, (HL)
        INC HL
        LD E, (HL)
        LD HL, (DISK_TRACK)
        ; ADD lower 16 bits (HL + BC)
        LD   A, L
        ADD  A, B            ; A = L + B
        LD   B, A         ; Store result in C
        LD   A, H
        ADC  A, C            ; A = H + C + Carry
        LD   C, A         ; Store result in B
        ; ADD upper 16 bits (DE + Carry)
        LD   A, D
        LD   D, 00H
        ADC  A, D             ; D = D + Carry
        LD   D, A
        LD   A, E
        LD   E, 00H
        ADC  A, E             ; E = E + Carry
        LD   E, A
        ; Store the result back at LBA        
        LD A, B
        LD (CFLBA0), A
        LD A, C
        LD (CFLBA1), A
        LD A, D
        LD (CFLBA2), A
        LD A, E
        LD (CFLBA3), A
        LD A, 01H
        RET
CALC_CFLBA_RET_ERR
        XOR A
        RET
		
	IF DEBUG > 0
PRINT_DISK_DEBUG
		CALL IPUTS
		DB 'disk=0x'
		DB 00H
		LD A, (DISK_DISK)
		CALL HEXDUMP_A
		CALL PRINT_COLON
		CALL IPUTS
		DB 'track=0x'
		DB 00H
		LD A, (DISK_TRACK+1)
		CALL HEXDUMP_A
		LD A, DISK_TRACK
		CALL HEXDUMP_A
		CALL PRINT_COLON
		CALL IPUTS
		DB 'sector=0x'
		DB 00H
		LD A, (DISK_SECTOR+1)
		CALL HEXDUMP_A
		LD A, (DISK_SECTOR)
		CALL HEXDUMP_A
		CALL PRINT_COLON
		CALL IPUTS
		DB 'dma=0x'
		DB 00H
		LD A, (DISK_DMA+1)
		CALL HEXDUMP_A
		LD A, (DISK_DMA)
		CALL HEXDUMP_A
		CALL PRINT_COLON
		CALL PRINT_STACK_POINTER
		CALL IPUTS
		DB CR
		DB 00H
		RET
		
PRINT_STACK_POINTER
		CALL IPUTS
		DB 'SP=0x'
		DB 00H
		LD HL, 0000H
		ADD HL, SP
		LD A, H
		CALL HEXDUMP_A
		LD A, L
		CALL HEXDUMP_A
		RET
		
PRINT_CFLBA_DEBUG
		CALL IPUTS
		DB 'LBA=0x'
		DB 00H
		LD A, (CFLBA3)
		CALL HEXDUMP_A
		LD A, (CFLBA2)
		CALL HEXDUMP_A
		LD A, (CFLBA1)
		CALL HEXDUMP_A
		LD A, (CFLBA0)
		CALL HEXDUMP_A
		CALL IPUTS
		DB CR
		DB 00H
		RET
		
PRINT_COLON:
		CALL IPUTS
		DB ', '
		DB 00H
		RET
	ENDIF

        include "cf_z80.asm"
        include "utils_z80.asm"
        include "../common/definitions.asm"
        include "../common/hexdump_z80.asm"
	
LAST_CHAR		DB	00H		; Last ASCII character from keyboard	
DISK_DISK:		DB	00H		; Should it be here?
DISK_TRACK:		DW	0000H	; Should it be here?
DISK_SECTOR: 	DW 	0000H	; Should it be here?
DISK_DMA:		DW 	0000H	; Should it be here?
ORIGINAL_SP:	DW	0000H

; Plan:
; - Put 4 128-byte CP/M sectors into each 512-byte CF card block
; - Treat each CF card block as a CP/M track
; 
; This filesystem has:
;	128 bytes/sector (CP/M requirement)
;	4 sectors/track (BIOS designer's choice)
;	65536 total sectors (CP/M limit)
; 	65536*128 = 8388608 gross bytes (max CP/M limit)
;	65536/4 = 16384 tracks
;	2048 allocation block size BLS (BIOS designer's choice)
;	8388608/2048 = 4096 totalal allocation blocks
;	512 directory entries (BIOS designer's choice)
;	512*32 = 16384 total bytes in the directory
;	ceiling(16384/2048) = 8 allocation blocks for the directory

;	BLS		BSH		BLM		------EXM------
;							DSM<256		DSM>255
;	1024	3		7		0			x
;	2048	4		15		1			0		<--------- This is what we are using
;	4096	5		31		3			1
;	8192	6		63		7			3
;	16384	7		127		15			7
;
; ** NOTE: 	This filesystem design is inefficient because it is unlikely
;			that ALL of the allocation blocks will ultimately get used! 

DISKA_DPH:
				DW	0000H		; XLT
				DW	0000H		; SCRPAD
				DW	0000H
				DW	0000H
				DW	DIRBUF		; DIRBUF
				DW	DISKA_DPB	; DPB
				DW	0000H		; CSV
				DW	DISKA_ALV	; ALV

DISKA_DPB:
				DW	4			; SPT (four 128 bytes per 512 byte track)
				DB	4			; BSH (for BLS 2048)
				DB	15			; BLM (for BLS 2048)
				DB	00H			; EXM
				DW	4063		; DSM (max allocation number)
				DW	511			; DRM
				DB	0FFH		; AL0
				DB	00H			; AL1
				DW	0000H		; CKS
				DW	0011H		; OFF
				
DISKA_ALV:
				DS	(4065/8)+1
DISKA_ALV_END

DIRBUF
				DS 	128
BIOS_WBOOT_STACK

BIOS_STACK_END
				DS 128
BIOS_STACK

	IF $ < BIOS_BOOT
		error "BIOS rolled over memory!"
	ENDIF
		END
