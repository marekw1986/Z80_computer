;IRQ0 - KBD
;IRQ1 - UART_TX
;IRQ2 - UART_RX
;IRQ3 - RTC
;IRQ4 - TIMER
;IRQ5 - UNUSED
;IRQ6 - UNUSED
;IRQ7 - UNUSED

		INCL "../common/definitions.asm"
		
FULLSYS EQU 1

        ORG  0000H
START:  MVI  A, 80H
        OUT  PORT_74237
        LXI  H,STACK
		SPHL
		JMP INIT
		
		INCL "../common/utils.asm"
        INCL "../common/hexdump.asm"

INIT:
	IF FULLSYS
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
        MVI A, 00H       ; WAIT/READY disabled, TX and RX interrupts disabled
        OUT DART_A_CMD
        MVI A, 3         ; Register 3
        OUT DART_A_CMD
        MVI A, 0E1H      ; 8 bits character, auto enables Rx enabled
        OUT DART_A_CMD
        MVI A, 4         ; Register 4
        OUT DART_A_CMD
        MVI A, 04H       ; x1 clock, 1 stop bit, no parity
        OUT DART_A_CMD
        MVI A, 5         ; Register 5
        OUT DART_A_CMD
        MVI A, 68H       ; 8 bits charactyer, tx enabled
        OUT DART_A_CMD

        MVI A, 18H       ; Reset Channel A
        OUT DART_B_CMD
        MVI A, 1          ; Register 1
        OUT DART_B_CMD
        MVI A, 00H       ; WAIT/READY disabled, TX and RX interrupts disabled
        OUT DART_B_CMD
        MVI A, 3         ; Register 3
        OUT DART_B_CMD
        MVI A, 0E1H      ; 8 bits character, auto enables Rx enabled
        OUT DART_B_CMD
        MVI A, 4         ; Register 4
        OUT DART_B_CMD
        MVI A, 04H       ; x1 clock, 1 stop bit, no parity
        OUT DART_B_CMD
        MVI A, 5         ; Register 5
        OUT DART_B_CMD
        MVI A, 68H       ; 8 bits charactyer, tx enabled
        OUT DART_B_CMD
		;EI
	ENDIF
		
LOOP:
		MVI A, 40H
		OUT PORT_74237
		MVI C, 255
		CALL DELAY
		MVI A, 80H
		OUT PORT_74237
		MVI C, 255
		CALL DELAY
        
        MVI A, 0FAH
        CALL HEXDUMP_A
		JMP LOOP

        
;       ORG  1366H
;		ORG  1F00H
		ORG	 8000H
TXTEND: DS   0                          ;TEXT SAVE AREA ENDS
VARBGN: DS   55                         ;VARIABLE @(0)
BUFFER: DS   64                         ;INPUT BUFFER
BUFEND: DS   1
CFLBA3	DS	 1
CFLBA2	DS	 1
CFLBA1	DS	 1
CFLBA0	DS	 1                          ;BUFFER ENDS
BLKDAT: DS   512                        ;BUFFER FOR SECTOR TRANSFER
BLKENDL DS   1                          ;BUFFER ENDS
SYSTICK DS   2                          ;Systick timer
RTCTICK DS   2							;RTC tick timer/uptime
KBDDATA DS   1                          ;Keyboard last received code
KBDKRFL DS	 1							;Keyboard key release flag
KBDSFFL DS	 1							;Keyboard Shift flag
KBDOLD	DS	 1							;Keyboard old data
KBDNEW	DS	 1							;Keyboard new data
CURSOR  DS   2                          ;VDP cursor x position
STKLMT: DS   1                          ;TOP LIMIT FOR STACK
        
        ORG  0FFDFH
STACK:  DS   0                          ;STACK STARTS HERE
;

CR      EQU  0DH
LF      EQU  0AH

		END
