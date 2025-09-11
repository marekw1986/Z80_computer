IR_VECTORS_RAM EQU 0FFE0H
STACK          EQU IR_VECTORS_RAM-1

		include "../common/definitions.asm"

        ORG  0000H
START:  LXI  H,STACK                   ;*** COLD START ***
		SPHL
        MVI  A,0FFH
        JMP  INIT
;

		include "../common/cf.asm"
		;include "keyboard.asm"
		include "../common/utils.asm"
		include "../common/hexdump.asm"

        ;Set SYSTICK, RTCTICK and KBDDATA to 0x00
INIT:   LXI  H, 0000H
        SHLD SYSTICK
        LXI  H, 0000H
        SHLD RTCTICK
        XOR A
        STA  KBDDATA
        ;Initialize CTC
        MVI  A, 05H      ; Control word: Timer mode, prescaler 16, enable TO output
        OUT  CTC_CH1      ; Configure Channel 1
        MVI  A, 26        ; Time constant for 9600 baud
        OUT  CTC_CH1

        MVI  A, 05H      ; Same settings for Channel 2
        OUT  CTC_CH2
        MVI  A, 26        ; Time constant for 9600 baud
        OUT  CTC_CH2
        ;Initialize DART
        MVI A, 18H       ; Reset Channel A
        OUT DART_A_CMD
        MVI A, 1          ; Register 1
        OUT DART_A_CMD
        XOR A       ; WAIT/READY disabled, TX and RX interrupts disabled
        OUT DART_A_CMD
        MVI A, 3         ; Register 3
        OUT DART_A_CMD
        MVI A, 0E1H      ; 8 bits character, auto enables Rx enabled
        OUT DART_A_CMD
        MVI A, 4         ; Register 4
        OUT DART_A_CMD
        MVI A, 44H       ; x16 clock, 1 stop bit, no parity
        OUT DART_A_CMD
        MVI A, 5         ; Register 5
        OUT DART_A_CMD
        MVI A, 68H       ; 8 bits charactyer, tx enabled
        OUT DART_A_CMD

        MVI A, 18H       ; Reset Channel A
        OUT DART_B_CMD
        MVI A, 1          ; Register 1
        OUT DART_B_CMD
        XOR A       ; WAIT/READY disabled, TX and RX interrupts disabled
        OUT DART_B_CMD
        MVI A, 3         ; Register 3
        OUT DART_B_CMD
        MVI A, 0E1H      ; 8 bits character, auto enables Rx enabled
        OUT DART_B_CMD
        MVI A, 4         ; Register 4
        OUT DART_B_CMD
        MVI A, 44H       ; x16 clock, 1 stop bit, no parity
        OUT DART_B_CMD
        MVI A, 5         ; Register 5
        OUT DART_B_CMD
        MVI A, 68H       ; 8 bits charactyer, tx enabled
        OUT DART_B_CMD
        		
        LXI B, 32                       ;BYTES TO TRANSFER
        LXI D, IR_VECTORS_ROM           ;SOURCE
        LXI H, IR_VECTORS_RAM           ;DESTINATION
        CALL MEMCOPY

        ; Wait before initializing CF card
		MVI C, 255
		CALL DELAY
        MVI C, 255
		CALL DELAY
		MVI C, 255
		CALL DELAY
		MVI C, 255
		CALL DELAY
        
		CALL IPUTS
		DB 'CF CARD: '
		DB 00H
		CALL CFINIT
		CPI 00H								; Check if CF_WAIT during initialization timeouted
		JZ GET_CFINFO
		CALL IPUTS
		DB 'missing'
		DB 00H
		CALL NEWLINE
		JMP $
GET_CFINFO:
        CALL CFINFO
        CALL IPUTS
        DB 'Received MBR: '
        DB 00H
        CALL CFGETMBR
        ; HEXDUMP MBR - START
        ;LXI D, LOAD_BASE
        ;MVI B, 128
        ;CALL HEXDUMP
        ;LXI D, LOAD_BASE+128
        ;MVI B, 128
        ;CALL HEXDUMP
        ;LXI D, LOAD_BASE+256
        ;MVI B, 128
        ;CALL HEXDUMP
        ;LXI D, LOAD_BASE+384
        ;MVI B, 128
        ;CALL HEXDUMP
        ;CALL NEWLINE
        ; HEXDUMP MBR - END
        ; Check if MBR is proper
        LXI D, LOAD_BASE+510
        LDAX D
        CPI 55H
        JNZ LOG_FAULTY_MBR
        INX D
        LDAX D
        CPI 0AAH
        JNZ LOG_FAULTY_MBR
        JMP LOG_PARTITION_TABLE
LOG_FAULTY_MBR:
		CALL IPUTS
		DB 'ERROR: faulty MBR'
		DB 00H
		CALL NEWLINE
        JMP $
LOG_PARTITION_TABLE:
		CALL IPUTS
		DB 'Partition table'
		DB 00H
        CALL NEWLINE
        CALL PRN_PARTITION_TABLE
        CALL NEWLINE
        ; Check if partition 1 is present
        LXI D, LOAD_BASE+446+8		; Address of first partition
        CALL ISZERO32BIT
        JNZ CHECK_PARTITION1_SIZE
        CALL IPUTS
		DB 'ERROR: partition 1 missing'
		DB 00H
        CALL NEWLINE
        JMP $
CHECK_PARTITION1_SIZE:
		; Check if partition 1 is larger than 16kB (32 sectors)
		LXI D, LOAD_BASE+446+12		; First partition size
		LDAX D
		CPI 32						; Check least significant byte
		JZ BOOT_CPM ;PRINT_BOOT_OPTIONS		; It is equal. Good enough.
		JNC BOOT_CPM ;PRINT_BOOT_OPTIONS		; It is bigger
		INX D
		LDAX D
		CPI 00H
		JNZ BOOT_CPM ;PRINT_BOOT_OPTIONS
		INX D
		LDAX D
		CPI 00H
		JNZ BOOT_CPM ;PRINT_BOOT_OPTIONS
		INX D
		LDAX D
		CPI 00H
		JNZ BOOT_CPM ;PRINT_BOOT_OPTIONS
		CALL IPUTS
		DB 'ERROR: partition 1 < 16kB'
		DB 00H
		CALL NEWLINE
		JMP $
        
BOOT_CPM:
		DI
        CALL LOAD_PARTITION1
        CPI 00H
        JZ JUMP_TO_CPM
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
        JMP BIOS_ADDR

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
		JMP KBD_ISR
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
		JMP RTC_ISR
        NOP
IR4_VECT_ROM:
		JMP TIMER_ISR
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
		PUSH PSW						;Save condition bits and accumulator
        PUSH H
        PUSH D
        POP D
        POP H        
		POP PSW							;Restore machine status
        EI                              ;Re-enable interrupts
		RET								;Return to interrupted program

UART_TX_ISR:
		PUSH PSW						;Save condition bits and accumulator
        PUSH H
        PUSH D
        POP D
        POP H        
		POP PSW							;Restore machine status
        EI                              ;Re-enable interrupts
		RET								;Return to interrupted program

KBD_ISR:
		PUSH PSW						;Save condition bits and accumulator
        PUSH H
        PUSH D
        ;IN KBD_STATUS                  ;NO NEED TO TEST, INTERRUPT MODE!
        ;ANI 01H                         ;Check if output buffer full
        ;JZ KBD_ISR_RET                  ;Output buffer empty, end ISR
        IN KBD_DATA                     ;Get keyboard data
        STA KBDDATA                     ;Save received code
KBD_ISR_RET:        
        POP D
        POP H        
		POP PSW							;Restore machine status
        EI                              ;Re-enable interrupts
		RET								;Return to interrupted program

TIMER_ISR:
		PUSH PSW						;Save condition bits and accumulator
        PUSH H
        PUSH D
        POP D
        POP H        
		POP PSW							;Restore machine status
        EI                              ;Re-enable interrupts
		RET								;Return to interrupted program
		
RTC_ISR:
		PUSH PSW						;Save condition bits and accumulator
        PUSH H
        PUSH D
        XOR A                      ;Clear the RTC interrupt flag to change state of the line
        OUT RTC_CTRLD_REG
        LHLD RTCTICK                    ;Load RTCTICK variable to HL
        INX H                           ;Increment HL
        SHLD RTCTICK                    ;Save HL in RTCTICK variable        
        POP D
        POP H        
		POP PSW							;Restore machine status
        EI                              ;Re-enable interrupts
		RET								;Return to interrupted program

;       ORG  1366H
;       ORG  1F00H
		ORG	 0FBDFH
SYSTEM_VARIABLES:
BLKDAT: DS   512                        ;BUFFER FOR SECTOR TRANSFER
BLKENDL DS   1;0                          ;BUFFER ENDS
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
