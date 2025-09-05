IR_VECTORS_RAM EQU 0FFE0H
STACK          EQU IR_VECTORS_RAM-1
#include "../common/definitions.asm"
        ORG  0000H
START:  ld hl,STACK                   ;*** COLD START ***
		ld sp,hl
        ld a,0FFH
         jp INIT
;
#include "../common/cf_z80.asm"
		;#include "keyboard.asm"
#include "../common/utils_z80.asm"
#include "../common/hexdump_z80.asm"
        ;Set SYSTICK, RTCTICK and KBDDATA to 0x00
INIT:   ld hl,0000H
        ld (SYSTICK),hl
        ld hl,0000H
        ld (RTCTICK),hl
        ld a,00H
        ld (KBDDATA),a
        ;Initialize CTC
        ld a,05H      ; Control word: Timer mode, prescaler 16, enable TO output
        out (CTC_CH1),a      ; Configure Channel 1
        ld a,26        ; Time constant for 9600 baud
        out (CTC_CH1),a
        ld a,05H      ; Same settings for Channel 2
        out (CTC_CH2),a
        ld a,26        ; Time constant for 9600 baud
        out (CTC_CH2),a
        ;Initialize DART
        ld a,18H       ; Reset Channel A
        out (DART_A_CMD),a
        ld a,1          ; Register 1
        out (DART_A_CMD),a
        ld a,00H       ; WAIT/READY disabled, TX and RX interrupts disabled
        out (DART_A_CMD),a
        ld a,3         ; Register 3
        out (DART_A_CMD),a
        ld a,0E1H      ; 8 bits character, auto enables Rx enabled
        out (DART_A_CMD),a
        ld a,4         ; Register 4
        out (DART_A_CMD),a
        ld a,44H       ; x16 clock, 1 stop bit, no parity
        out (DART_A_CMD),a
        ld a,5         ; Register 5
        out (DART_A_CMD),a
        ld a,68H       ; 8 bits charactyer, tx enabled
        out (DART_A_CMD),a
        ld a,18H       ; Reset Channel A
        out (DART_B_CMD),a
        ld a,1          ; Register 1
        out (DART_B_CMD),a
        ld a,00H       ; WAIT/READY disabled, TX and RX interrupts disabled
        out (DART_B_CMD),a
        ld a,3         ; Register 3
        out (DART_B_CMD),a
        ld a,0E1H      ; 8 bits character, auto enables Rx enabled
        out (DART_B_CMD),a
        ld a,4         ; Register 4
        out (DART_B_CMD),a
        ld a,44H       ; x16 clock, 1 stop bit, no parity
        out (DART_B_CMD),a
        ld a,5         ; Register 5
        out (DART_B_CMD),a
        ld a,68H       ; 8 bits charactyer, tx enabled
        out (DART_B_CMD),a
        		
        ld bc,32                       ;BYTES TO TRANSFER
        ld de,IR_VECTORS_ROM           ;SOURCE
        ld hl,IR_VECTORS_RAM           ;DESTINATION
        call MEMCOPY
        ; Wait before initializing CF card
		ld c,255
		call DELAY
        ld c,255
		call DELAY
		ld c,255
		call DELAY
		ld c,255
		call DELAY
        
		call IPUTS
		DB 'CF CARD: '
		DB 00H
		call CFINIT
		cp a,00H								; Check if CF_WAIT during initialization timeouted
		jp z,GET_CFINFO
		call IPUTS
		DB 'missing'
		DB 00H
		call NEWLINE
		 jp $
GET_CFINFO:
        call CFINFO
        call IPUTS
        DB 'Received MBR: '
        DB 00H
        call CFGETMBR
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
        ld de,LOAD_BASE+510
        ld a,(de)
        cp a,55H
        jp nz,LOG_FAULTY_MBR
        inc de
        ld a,(de)
        cp a,0AAH
        jp nz,LOG_FAULTY_MBR
         jp LOG_PARTITION_TABLE
LOG_FAULTY_MBR:
		call IPUTS
		DB 'ERROR: faulty MBR'
		DB 00H
		call NEWLINE
         jp $
LOG_PARTITION_TABLE:
		call IPUTS
		DB 'Partition table'
		DB 00H
        call NEWLINE
        call PRN_PARTITION_TABLE
        call NEWLINE
        ; Check if partition 1 is present
        ld de,LOAD_BASE+446+8		; Address of first partition
        call ISZERO32BIT
        jp nz,CHECK_PARTITION1_SIZE
        call IPUTS
		DB 'ERROR: partition 1 missing'
		DB 00H
        call NEWLINE
         jp $
CHECK_PARTITION1_SIZE:
		; Check if partition 1 is larger than 16kB (32 sectors)
		ld de,LOAD_BASE+446+12		; First partition size
		ld a,(de)
		cp a,32						; Check least significant byte
		jp z,BOOT_CPM ;PRINT_BOOT_OPTIONS		; It is equal. Good enough.
		jp nc,BOOT_CPM ;PRINT_BOOT_OPTIONS		; It is bigger
		inc de
		ld a,(de)
		cp a,00H
		jp nz,BOOT_CPM ;PRINT_BOOT_OPTIONS
		inc de
		ld a,(de)
		cp a,00H
		jp nz,BOOT_CPM ;PRINT_BOOT_OPTIONS
		inc de
		ld a,(de)
		cp a,00H
		jp nz,BOOT_CPM ;PRINT_BOOT_OPTIONS
		call IPUTS
		DB 'ERROR: partition 1 < 16kB'
		DB 00H
		call NEWLINE
		 jp $
        
BOOT_CPM:
		di
        call LOAD_PARTITION1
        cp a,00H
        jp z,JUMP_TO_CPM
        call IPUTS
        DB 'CP/M load error. Reset.'
        DB 00H
        call ENDLESS_LOOP
JUMP_TO_CPM:
        call NEWLINE
        call IPUTS
        DB 'Load successfull.'
        DB 00H
        call NEWLINE
         jp BIOS_ADDR
        
MSG1:   DB   'TINY '
        DB   'BASIC'
        DB   CR
CFERRM: DB   'CF ERROR: '
        DB   CR
STARTADDRSTR:
		DB	 'Addr: '
		DB	 CR
SIZESTR:
		DB	 'Size: '
		DB	 CR
		;#include "fonts1.asm"
		;#include "ps2_scancodes.asm"
        
;Interrupt vectors defined in rom
IR_VECTORS_ROM:
IR0_VECT_ROM:
		 jp KBD_ISR
        nop
        ;EI
        ;RET
        ;NOP
        ;NOP        
IR1_VECT_ROM:
		;JMP UART_TX_ISR
        ;NOP
        ei
        ret
        nop
        nop
IR2_VECT_ROM:
		;JMP UART_RX_ISR
        ;NOP
        ei
        ret
        nop
        nop
IR3_VECT_ROM:
		 jp RTC_ISR
        nop
IR4_VECT_ROM:
		 jp TIMER_ISR
        nop
IR5_VECT_ROM:
        ei	
        ret
        nop
        nop
IR6_VECT_ROM:
        ei	
        ret
        nop
        nop
IR7_VECT_ROM:
        ei	
        ret
        nop
        nop
;Interrupt routines
UART_RX_ISR:
		push af						;Save condition bits and accumulator
        push hl
        push de
        pop de
        pop hl        
		pop af							;Restore machine status
        ei                              ;Re-enable interrupts
		ret								;Return to interrupted program
UART_TX_ISR:
		push af						;Save condition bits and accumulator
        push hl
        push de
        pop de
        pop hl        
		pop af							;Restore machine status
        ei                              ;Re-enable interrupts
		ret								;Return to interrupted program
KBD_ISR:
		push af						;Save condition bits and accumulator
        push hl
        push de
        ;IN KBD_STATUS                  ;NO NEED TO TEST, INTERRUPT MODE!
        ;ANI 01H                         ;Check if output buffer full
        ;JZ KBD_ISR_RET                  ;Output buffer empty, end ISR
        in a,(KBD_DATA)                     ;Get keyboard data
        ld (KBDDATA),a                     ;Save received code
KBD_ISR_RET:        
        pop de
        pop hl        
		pop af							;Restore machine status
        ei                              ;Re-enable interrupts
		ret								;Return to interrupted program
TIMER_ISR:
		push af						;Save condition bits and accumulator
        push hl
        push de
        pop de
        pop hl        
		pop af							;Restore machine status
        ei                              ;Re-enable interrupts
		ret								;Return to interrupted program
		
RTC_ISR:
		push af						;Save condition bits and accumulator
        push hl
        push de
        ld a,00H                      ;Clear the RTC interrupt flag to change state of the line
        out (RTC_CTRLD_REG),a
        ld hl,(RTCTICK)                    ;Load RTCTICK variable to HL
        inc hl                           ;Increment HL
        ld (RTCTICK),hl                    ;Save HL in RTCTICK variable        
        pop de
        pop hl        
		pop af							;Restore machine status
        ei                              ;Re-enable interrupts
		ret								;Return to interrupted program
;       ORG  1366H
;       ORG  1F00H
		ORG	 0FBDFH
SYSTEM_VARIABLES:
BLKDAT: DS   512                        ;BUFFER FOR SECTOR TRANSFER
BLKENDL DS   0                          ;BUFFER ENDS
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
