IR_VECTORS_RAM EQU 0FFE0H
STACK          EQU IR_VECTORS_RAM-1

		include "../common/definitions.asm"

        ORG  0000H    
START:  LD   SP, STACK                   ;*** COLD START ***
        LD   A, 0FFH
        JP  INIT


		include "../common/cf_z80.asm"
		;include "keyboard.asm"
		include "../common/utils_z80.asm"
		include "../common/hexdump_z80.asm"

        ;Set SYSTICK, RTCTICK and KBDDATA to 0x00
INIT:   LD   HL, 0000H
        LD   (SYSTICK), HL
        LD   (RTCTICK), HL
        XOR A
        LD  (KBDDATA), A
        ;Initialize CTC
        LD   A, 05H      		; Control word: Timer mode, prescaler 16, enable TO output
        OUT  (CTC_CH1), A       ; Configure Channel 1
        LD   A, 26        		; Time constant for 9600 baud
        OUT  (CTC_CH1), A

        LD   A, 05H      		; Same settings for Channel 2
        OUT  (CTC_CH2), A
        LD   A, 26        ; Time constant for 9600 baud
        OUT  (CTC_CH2), A
        ;Initialize DART
        LD  A, 18H       ; Reset Channel A
        OUT (DART_A_CMD), A
        LD  A, 1          ; Register 1
        OUT (DART_A_CMD), A
        LD  A, 00H       ; WAIT/READY disabled, TX and RX interrupts disabled
        OUT (DART_A_CMD), A
        LD  A, 3         ; Register 3
        OUT (DART_A_CMD), A
        LD  A, 0E1H      ; 8 bits character, auto enables Rx enabled
        OUT (DART_A_CMD), A
        LD  A, 4         ; Register 4
        OUT (DART_A_CMD), A
        LD  A, 44H       ; x16 clock, 1 stop bit, no parity
        OUT (DART_A_CMD), A
        LD  A, 5         ; Register 5
        OUT (DART_A_CMD), A
        LD  A, 68H       ; 8 bits charactyer, tx enabled
        OUT (DART_A_CMD), A

        LD  A, 18H       ; Reset Channel A
        OUT (DART_B_CMD), A
        LD  A, 1          ; Register 1
        OUT (DART_B_CMD), A
        LD  A, 00H       ; WAIT/READY disabled, TX and RX interrupts disabled
        OUT (DART_B_CMD), A
        LD  A, 3         ; Register 3
        OUT (DART_B_CMD), A
        LD  A, 0E1H      ; 8 bits character, auto enables Rx enabled
        OUT (DART_B_CMD), A
        LD  A, 4         ; Register 4
        OUT (DART_B_CMD), A
        LD  A, 44H       ; x16 clock, 1 stop bit, no parity
        OUT (DART_B_CMD), A
        LD  A, 5         ; Register 5
        OUT (DART_B_CMD), A
        LD  A, 68H       ; 8 bits charactyer, tx enabled
        OUT (DART_B_CMD), A
        		
        LD  BC, 32                       ;BYTES TO TRANSFER
        LD  DE, IR_VECTORS_ROM           ;SOURCE
        LD  HL, IR_VECTORS_RAM           ;DESTINATION
        LDIR

        ; Wait before initializing CF card
		LD  C, 255
		CALL DELAY
        LD  C, 255
		CALL DELAY
		LD  C, 255
		CALL DELAY
		LD  C, 255
		CALL DELAY
        
		CALL IPUTS
		DB 'CF CARD: '
		DB 00H
		CALL CFINIT
		CP 00H								; Check if CF_WAIT during initialization timeouted
		JP Z, GET_CFINFO
		CALL IPUTS
		DB 'missing'
		DB 00H
		CALL NEWLINE
		JP $
GET_CFINFO:
        CALL CFINFO
        CALL IPUTS
        DB 'Received MBR: '
        DB 00H
        CALL CFGETMBR
        ; HEXDUMP MBR - START
        ;LD DE, LOAD_BASE
        ;LD B, 128
        ;CALL HEXDUMP
        ;LD DE, LOAD_BASE+128
        ;LD B, 128
        ;CALL HEXDUMP
        ;LD DE, LOAD_BASE+256
        ;LD B, 128
        ;CALL HEXDUMP
        ;LD DE, LOAD_BASE+384
        ;LD B, 128
        ;CALL HEXDUMP
        ;CALL NEWLINE
        ; HEXDUMP MBR - END
        ; Check if MBR is proper
        LD DE, LOAD_BASE+510
        LD A, (DE)
        CP 55H
        JP NZ, LOG_FAULTY_MBR
        INC DE
        LD A, (DE)
        CP 0AAH
        JP NZ, LOG_FAULTY_MBR
        JP LOG_PARTITION_TABLE
LOG_FAULTY_MBR:
		CALL IPUTS
		DB 'ERROR: faulty MBR'
		DB 00H
		CALL NEWLINE
        JP $
LOG_PARTITION_TABLE:
		CALL IPUTS
		DB 'Partition table'
		DB 00H
        CALL NEWLINE
        CALL PRN_PARTITION_TABLE
        CALL NEWLINE
        ; Check if partition 1 is present
        LD DE, LOAD_BASE+446+8		; Address of first partition
        CALL ISZERO32BIT
        JP NZ, CHECK_PARTITION1_SIZE
        CALL IPUTS
		DB 'ERROR: partition 1 missing'
		DB 00H
        CALL NEWLINE
        JP $
CHECK_PARTITION1_SIZE:
		; Check if partition 1 is larger than 16kB (32 sectors)
		LD DE, LOAD_BASE+446+12		; First partition size
		LD A, (DE)
		CP 32						; Check least significant byte
		JP Z, BOOT_CPM ;PRINT_BOOT_OPTIONS		; It is equal. Good enough.
		JP NC, BOOT_CPM ;PRINT_BOOT_OPTIONS		; It is bigger
		INC DE
		LD A, (DE)
		CP 00H
		JP NZ, BOOT_CPM ;PRINT_BOOT_OPTIONS
		INC DE
		LD A, (DE)
		CP 00H
		JP NZ, BOOT_CPM ;PRINT_BOOT_OPTIONS
		INC DE
		LD A, (DE)
		CP 00H
		JP NZ, BOOT_CPM ;PRINT_BOOT_OPTIONS
		CALL IPUTS
		DB 'ERROR: partition 1 < 16kB'
		DB 00H
		CALL NEWLINE
		JP $
        
BOOT_CPM:
		DI
        CALL LOAD_PARTITION1
        CP 00H
        JP Z, JUMP_TO_CPM
        CALL IPUTS
        DB 'CP/M load error. Reset.'
        DB 00H
        CALL ENDLESS_LOOP
JUMP_TO_CPM:
        CALL NEWLINE
        CALL IPUTS
        DB 'Load successfull.'
        DB 00H
        CALL NEWLINE
        JP BIOS_ADDR
        
CFERRM: DB   'CF ERROR: '
        DB   CR
STARTADDRSTR:
		DB	 'Addr: '
		DB	 CR
SIZESTR:
		DB	 'Size: '
		DB	 CR

		include "fonts1.asm"
		include "ps2_scancodes.asm"
        
;Interrupt vectors defined in rom
IR_VECTORS_ROM:
IR0_VECT_ROM:
		JP KBD_ISR
        NOP
        ;EI
        ;RET
        ;NOP
        ;NOP        
IR1_VECT_ROM:
		;JMP UART_TX_ISR
        ;NOP
        EI
        RET
        NOP
        NOP
IR2_VECT_ROM:
		;JMP UART_RX_ISR
        ;NOP
        EI
        RET
        NOP
        NOP
IR3_VECT_ROM:
		JP RTC_ISR
        NOP
IR4_VECT_ROM:
		JP TIMER_ISR
        NOP
IR5_VECT_ROM:
        EI	
        RET
        NOP
        NOP
IR6_VECT_ROM:
        EI	
        RET
        NOP
        NOP
IR7_VECT_ROM:
        EI	
        RET
        NOP
        NOP

;Interrupt routines
UART_RX_ISR:
		PUSH AF						;Save condition bits and accumulator
        PUSH HL
        PUSH DE
        POP DE
        POP HL        
		POP AF							;Restore machine status
        EI                              ;Re-enable interrupts
		RET								;Return to interrupted program

UART_TX_ISR:
		PUSH AF						;Save condition bits and accumulator
        PUSH HL
        PUSH DE
        POP DE
        POP HL        
		POP AF							;Restore machine status
        EI                              ;Re-enable interrupts
		RET								;Return to interrupted program

KBD_ISR:
		PUSH AF						;Save condition bits and accumulator
        PUSH HL
        PUSH DE
        ;IN A, (KBD_STATUS)                  ;NO NEED TO TEST, INTERRUPT MODE!
        ;AND 01H                         ;Check if output buffer full
        ;JZ KBD_ISR_RET                  ;Output buffer empty, end ISR
        IN A, (KBD_DATA)                     ;Get keyboard data
        LD (KBDDATA), A                     ;Save received code
KBD_ISR_RET:        
        POP DE
        POP HL        
		POP AF							;Restore machine status
        EI                              ;Re-enable interrupts
		RET								;Return to interrupted program

TIMER_ISR:
		PUSH AF						;Save condition bits and accumulator
        PUSH HL
        PUSH DE
        POP DE
        POP HL        
		POP AF							;Restore machine status
        EI                              ;Re-enable interrupts
		RET								;Return to interrupted program
		
RTC_ISR:
		PUSH AF						;Save condition bits and accumulator
        PUSH HL
        PUSH DE
        LD A, 00H                      ;Clear the RTC interrupt flag to change state of the line
        OUT (RTC_CTRLD_REG), A
        LD HL, (RTCTICK)                    ;Load RTCTICK variable to HL
        INC HL                           ;Increment HL
        LD (RTCTICK), HL                    ;Save HL in RTCTICK variable        
        POP DE
        POP HL        
		POP AF							;Restore machine status
        EI                              ;Re-enable interrupts
		RET								;Return to interrupted program

;       ORG  1366H
;       ORG  1F00H
		ORG	 0FBDFH
SYSTEM_VARIABLES:
BLKDAT: DS   512                        ;BUFFER FOR SECTOR TRANSFER
BLKENDL DS   1 ;0                          ;BUFFER ENDS
CFLBA3	DS	 1
CFLBA2	DS	 1
CFLBA1	DS	 1
CFLBA0	DS	 1                          
SYSTICK DS   2                          ;Systick timer
RTCTICK DS   2							;RTC tick timer/uptime
KBDDATA DS   1                          ;Keyboard last received code
KBDKRFL DS	 1							;Keyboard key release flag
KBDSFFL DS	 1							;Keyboard Shift flag
KBDOLD	DS	 1							;Keyboard old data
KBDNEW	DS	 1							;Keyboard new data
STKLMT: DS   1                          ;TOP LIMIT FOR STACK

CR      EQU  0DH
LF      EQU  0AH

        END
