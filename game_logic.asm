	jmp RESET
	.dseg
		PLAYER_X_POS: .byte 1
		PLAYER_Y_POS: .byte 1
		TIME: .byte 4
		LCD_ADDR_PTR: .byte 1
		RANDOM_VAL: .byte 1
		WALL: .byte 4
	.cseg
	.org URXCaddr ; USART Receive
	jmp USART_Receive
	.org OC0addr ; Output Compare Timer0
	jmp RANDOM
	.org OC1Aaddr ; Output Compare Timer1
	jmp INT_COUNT
	.org INT_VECTORS_SIZE
	; Character codes
	.equ SHIP = 0x80
	.equ ALIEN = 0x81
WELCOME_MESSAGE:	
	.db "   WELCOME TO    ALIEN AVOIDER    ",
	"                PRESS KEY TO    ",
					"   START", 0x00, 0x00
GAME_OVER_MESSAGE:
	.db "   GAME OVER     ",
	"                 PRESS KEY TO   ",
					"   RESTART", 0x00
RESET:
; Set stack pointer to RAMEND
	ldi r16, HIGH(RAMEND)
	out SPH, r16
	ldi r16, LOW(RAMEND)
	out SPL, r16
	call INIT
	call INIT_DISPLAY
	call MENU
START_GAME:
	call LCD_CLEAR
	call GAME_START
; --------------------------------------------------------------------------------
INIT:
; Set PD0-PD5 to output
	ldi r16, 0b00111111
	out DDRA, r16
; Activate pull-up resistor on PD2
	ldi r16, (1 << PD2)
	out PORTD, r16
; Set player position to center of screen
	ldi r16, 7
	sts PLAYER_X_POS, r16
; Set USART character size to 8 bits
	ldi r16, (1 << UCSZ0) | (1 << UCSZ1)
	out UCSRC, r16
; Set USART baud rate to 0.5 Mbps
	clr r16
	out UBRRH, r16
	inc r16
	out UBRRL, r16
	
; Activate USART receiver and enable interrupt
	ldi r16, (1 << RXEN) | (1 << RXCIE)
	out UCSRB, r16
	ldi r16, (1 << URSEL)
	out UCSRC, r16
; Set even pairity mode for error checking
	ldi r16, (1 << URSEL) | (1 << UPM1)
	out UCSRC, r16
; Set Timer1 to CTC mode
	in r16, TCCR1B
	ori r16, (1 << WGM12)
	out TCCR1B, r16
; Enable Timer1 output compare A match interrupt
	in r16, TIMSK
	ori r16, (1 << OCIE1A)
	out TIMSK, r16 
; Set Timer1(A) output compare to 1 Hz @ 16 MHz w/ prescaler = 1024
	ldi r16, HIGH(15624)
	out OCR1AH, r16 ; High byte has to be written first
	ldi r16, LOW(15624)
	out OCR1AL, r16
; Load inital RANDOM_VAL
	ldi r16, 0b10011010
	sts RANDOM_VAL, r16
	sei
	ret
; DISPLAY PINS:
; !WR     = PA5
; !RD     = PA4
; !CE     = PA3
; C/D     = PA2
; !RES    = PA1
; FS1     = PA0
; DB0-DB7 = PB0-PB7
	.equ WR  = PA5
	.equ RD  = PA4
	.equ CE  = PA3
	.equ CD  = PA2
	.equ RES = PA1
	.equ FS1 = PA0
INIT_DISPLAY:
	call DELAY
	call DELAY
	call DELAY
	call DELAY
	call DELAY
	call DELAY
	call DELAY
	call DELAY
	call DELAY
	call DELAY
	sbi PORTA, RES
	call Delay
	sbi PORTA, WR
	sbi PORTA, RD
	
; OR mode
	ldi r16, 0x80
	call WRITE_COMMAND
; Text home = 0x0000
	ldi r16, 0x00
	call WRITE_DATA
	ldi r16, 0x00
	call WRITE_DATA
	ldi r16, 0x40
	call WRITE_COMMAND
; Text area start = 128 / 8 = 0x0010
	ldi r16, 0x10
	call WRITE_DATA
	clr r16
	call WRITE_DATA
	ldi r16, 0x41
	call WRITE_COMMAND
; Offset register start = 0x1000 (ends at 0x17FF)
	ldi r16, 0b00000010
	call WRITE_DATA
	clr r16
	call WRITE_DATA
	ldi r16, 0x22
	call WRITE_COMMAND
; Set address pointer to 0x1400
	ldi r16, 0x00
	ldi r17, 0x14
	call LCD_SET_ADDR_PTR
; Write custom icons to character table
; SHIP GRAPHICS (with character code 0x80)
	ldi r16, 0b00011000
	call WRITE_CHAR
	ldi r16, 0b00111100
	call WRITE_CHAR
	ldi r16, 0b01111110
	call WRITE_CHAR
	ldi r16, 0b11111111
	call WRITE_CHAR
	ldi r16, 0b11111111
	call WRITE_CHAR
	ldi r16, 0b11011011
	call WRITE_CHAR
	ldi r16, 0b10011001
	call WRITE_CHAR
	ldi r16, 0b10011001
	call WRITE_CHAR
; ALIEN GRAPHICS (with character code 0x81)
	ldi r16, 0b00011000
	call WRITE_CHAR
	ldi r16, 0b00111100
	call WRITE_CHAR
	ldi r16, 0b01111110
	call WRITE_CHAR
	ldi r16, 0b11011011
	call WRITE_CHAR
	ldi r16, 0b11111111
	call WRITE_CHAR
	ldi r16, 0b01011010
	call WRITE_CHAR
	ldi r16, 0b10000001
	call WRITE_CHAR
	ldi r16, 0b01000010
	call WRITE_CHAR
; Display mode: GRPH = 0, TEXT = 1, CUR = 1, BLK = 1
	ldi r16, 0b10010111
	call WRITE_COMMAND
; Address pointer = 0x0000
	ldi r16, 0x00
	clr r17
	call LCD_SET_ADDR_PTR
	call LCD_CLEAR
	
	ret
MENU:
; Print welcome message
	push r16
	ldi r16, 16 * 6
	call LCD_SET_ADDR_PTR
	ldi ZL, LOW(WELCOME_MESSAGE * 2)
	ldi ZH, HIGH(WELCOME_MESSAGE * 2)
	call PRINT_STRING
Menu_Loop:
	call RANDOM
; Wait for button press
	sbic PIND, PD2
	jmp Menu_Loop
	pop r16
	ret
GAME_START:
	ldi r19, 0x00
	lds r20, PLAYER_X_POS
	clr r16
	sts TIME, r16
	sts TIME+1, r16
	sts TIME+2, r16
	sts TIME+3, r16
	in r16, TCCR1B
	ori r16, (1 << CS12) | (1 << CS10)
	out TCCR1B, r16 ; Set prescaler = 1024 and activate Timer1
Game_loop:
	cpi r19, 0x0F
	brcc YPOS_NOT_ZERO ; This doesn't make sense but is = brmi
; Here we generate new sequences of random walls (aliens)
; if we've reached the bottom of the screen
; Load 4 new random walls of aliens
	call LOAD_RANDOM_WALL
; Ensure that wall has at least one hole wide enough for the ship
	call MAKE_HOLE_IN_WALL
YPOS_NOT_ZERO:
	call Delay ; ~10 ms
; Clear old aliens
	call CLEAR_ROW
	call CLEAR_ROW
; Address pointer = r19
	mov r16, r19
	ldi r17, 0x00
	call LCD_SET_ADDR_PTR
; Print aliens and increase address pointer
	call PRINT_WALL
; Print player and check for collision with alien wall
	call PRINT_PLAYER_AND_CHECK_HIT
; Print timer (score)
	call PRINT_TIMER
; Address pointer = r19
	mov r16, r19
	ldi r17, 0x00
	call LCD_SET_ADDR_PTR
	
; Go to next row, r19 += 16
	subi r19, -0x10
	jmp Game_loop
	ret
; Generate random wall of aliens and store to SRAM
LOAD_RANDOM_WALL:
	push r16
	call RANDOM
	lds r16, RANDOM_VAL
	sts WALL, r16
	call RANDOM
	lds r16, RANDOM_VAL
	sts WALL+1, r16
	call RANDOM
	lds r16, RANDOM_VAL
	sts WALL+2, r16
	call RANDOM
	lds r16, RANDOM_VAL
	sts WALL+3, r16
	pop r16
	ret
; Ensure at least one hole in the wall
MAKE_HOLE_IN_WALL:
	call RANDOM
	ldi r19, 0x10
	lds r16, RANDOM_VAL
	lds r18, WALL
	lds r21, WALL+2
	sbrs r16, 0
	lds r18, WALL+1
	sbrs r16, 0
	lds r21, WALL+3
	push r16
	lsr r16
	lsr r16
	lsr r16
	lsr r16
	lsr r16
	ldi r17, 0b00000001
	cpi r16, 0
	breq Shift_Done
Shift_Loop:
	lsl r17
	dec r16
	brne Shift_Loop
Shift_Done:
	pop r16
	com r17
	and r18, r17
	and r21, r17
	sbrs r16, 0
	sts WALL+1, r18
	sbrs r16, 0
	sts WALL+3, r21
	sbrc r16, 0
	sts WALL, r18
	sbrc r16, 0
	sts WALL+2, r21
	ret
; Print the walls of aliens
PRINT_WALL:
	lds r17, WALL
	ldi r22, 4
Load_wall:
	ldi r21, 8
	cpi r22, 3
	brne Not_3
	lds r17, WALL+1
Not_3:
	cpi r22, 2
	brne Not_2
	lds r17, WALL+2
Not_2:
	cpi r22, 1
	brne Wall_loop
	lds r17, WALL+3
Wall_loop:
	rol r17
	brcc Write_blank
	ldi r16, ALIEN
	call WRITE_CHAR
	jmp Write_done
Write_blank:
	ldi r16, 0x00
	call WRITE_CHAR
Write_done:
	dec r21
	brne Wall_loop
	dec r22
	brne Load_wall
	ret
PRINT_PLAYER_AND_CHECK_HIT:
; Address pointer = 0xF0 + r20
	ldi r16, 0xF0
	add r16, r20
	ldi r17, 0x00
	call LCD_SET_ADDR_PTR
	call CHECK_HIT
; Write ''
	ldi r16, 0x00
	call WRITE_CHAR
	lds r20, PLAYER_X_POS
; Address pointer = 0xF0 + r20
	ldi r16, 0xF0
	add r16, r20
	ldi r17, 0x00
	call LCD_SET_ADDR_PTR
; Write ship and increase address pointer
	ldi r16, SHIP
	call WRITE_CHAR
	ret
; Erase previous row of wall (write 16 blank chars)
CLEAR_ROW:
	push r17
	push r16
	ldi r17, 16
	clr r16
WRITE_LOOP:
	call WRITE_CHAR
	dec r17
	brne WRITE_LOOP
	pop r16
	pop r17
	ret
; Check if player hit a wall of aliens
CHECK_HIT:
	push r16
	push r17
	call READ_CHAR
	cpi r16, 0x00
	breq NO_HIT
	cpi r16, SHIP
	breq NO_HIT
; If hit, display game over message
	ldi r16, 16 * 6
	call LCD_SET_ADDR_PTR
	ldi ZL, LOW(GAME_OVER_MESSAGE * 2)
	ldi ZH, HIGH(GAME_OVER_MESSAGE * 2)
	call PRINT_STRING
	in r16, TCCR1B
	ldi r17, (1 << CS12) | (1 << CS10)
	eor r16, r17
	out TCCR1B, r16 ; Deactivate Timer1
	clr r16
	out TCNT1H, r16
	out TCNT1L, r16
	jmp HIT
NO_HIT:
	pop r17
	pop r16
	ret
; Wait for press of button to start a new game
HIT:
	sbic PIND, PD2
	jmp HIT
	jmp START_GAME
; Read character from LCD
READ_CHAR:
	ldi r16, 0xC5
	call WRITE_COMMAND
	call STATUS_CHECK
	cbi PORTA, CD
	cbi PORTA, RD
	call NANO_DELAY
	in r16, PINB
	
	sbi PORTA, RD
	ret
	
; Get next position for the ship via USART
USART_Receive:
	push r16
	push r17
	sbis UCSRA, FE
	jmp FE_OK
	jmp USART_DONE
FE_OK:
	sbis UCSRA, PE
	jmp USART_OK
	jmp USART_DONE
USART_OK:
	in r16, UDR
	mov r17, r16
	andi r17, 0b00001111
	sts PLAYER_X_POS, r17
	andi r16, 0b11110000
	swap r16
	sts PLAYER_Y_POS, r16
USART_DONE:
	pop r17
	pop r16
	reti
NANO_DELAY: ; ~67 us
	push r16
	ldi r16, 0x0F
Nano_Delay_not_done:
	dec r16
	brne Nano_Delay_not_done
	pop r16
	ret
WRITE_LCD:
	push r19
	call NANO_DELAY
	ldi r19, 0b11111111
	out DDRB, r19
	out PORTB, r16
	call NANO_DELAY
	cbi PORTA, WR
	call NANO_DELAY
	sbi PORTA, WR
	ldi r19, 0b00000000
	out PORTB, r19
	pop r19
	ret
WRITE_CHAR:
	call WRITE_DATA
	push r16
	ldi r16, 0xC0
	call WRITE_COMMAND
	pop r16
	ret
PRINT_STRING:
	push r16
Print_String_Loop:
	lpm r16, Z+
	cpi r16, 0x00
	breq Print_String_Done
	subi r16, 0x20
	call WRITE_CHAR
	jmp Print_String_Loop
Print_String_Done:
	pop r16
	ret
WRITE_DATA:
	call STATUS_CHECK
	cbi PORTA, CD
	call WRITE_LCD
	ret
WRITE_COMMAND:
	call STATUS_CHECK
	sbi PORTA, CD
	call WRITE_LCD
	ret
STATUS_CHECK:
	push r16
	push r20
	clr r20
	out DDRB,r20
	sbi PORTA, CD
	cbi PORTA, RD
Status_Loop:
	call NANO_DELAY
	in r16, PINB
	call NANO_DELAY
	andi r16, 0b00000011
	cpi r16, 0b00000011
	brne Status_Loop
	sbi PORTA, RD
	pop r20
	pop r16
	ret 
LCD_SET_ADDR_PTR:
	push r16
	call WRITE_DATA
	mov r16, r17
	call WRITE_DATA
	ldi r16, 0x24
	call WRITE_COMMAND
	pop r16
	ret
LCD_CLEAR:
; Clears whole screen
	push r16
	push r17
	push r18
	ldi r16, 0x00
	ldi r17, 0x00
	call LCD_SET_ADDR_PTR
	ldi r17, 16
LCD_CLEAR_Loop1:
	ldi r18, 128
LCD_CLEAR_Loop2:
; Write ''
	ldi r16, 0x00
	call WRITE_CHAR
	dec r18
	brne LCD_CLEAR_Loop2
	dec r17
	brne LCD_CLEAR_Loop1
	pop r18
	pop r17
	pop r16
	ret
DELAY: ; ~100 ms
	push r16
	push r17
	push r18
	ldi r18, 9
Delay_outer:
	ldi r17, 210
Delay_middle:
	ldi r16, 0xFF
Delay_inner:
	dec r16
	brne Delay_inner
	dec r17
	brne Delay_middle
	dec r18
	brne Delay_outer
	pop r18
	pop r17
	pop r16
	ret
; Count timer (score)
INT_COUNT:
	push r16
	in r16, SREG
	push r16
	lds r16, TIME
	inc r16
	cpi r16, 10
	sts TIME, r16
	brne No_Overflow
	clr r16
	sts TIME, r16
	lds r16, TIME+1
	inc r16
	cpi r16, 6
	sts TIME+1, r16
	brne No_Overflow
	clr r16
	sts TIME+1, r16
	lds r16, TIME+2
	inc r16
	cpi r16, 10
	sts TIME+2, r16
	brne No_Overflow
	clr r16
	sts TIME+2, r16
	lds r16, TIME+3
	inc r16
	cpi r16, 6
	sts TIME+3, r16
	brne No_Overflow
	clr r16
	sts TIME+3, r16
No_Overflow:
	
	pop r16
	out SREG, r16
	pop r16
	reti
; Print timer (score)
PRINT_TIMER:
	push r16
	push r17
; Address pointer = 5
	ldi r16, 5
	ldi r17, 0x00
	call LCD_SET_ADDR_PTR
; Write TIME
	lds r16, TIME+3
	subi r16, -0x10
	call WRITE_CHAR
	lds r16, TIME+2
	subi r16, -0x10
	call WRITE_CHAR
	ldi r16, 0x1A
	call WRITE_CHAR
	lds r16, TIME+1
	subi r16, -0x10
	call WRITE_CHAR
	lds r16, TIME
	subi r16, -0x10
	call WRITE_CHAR
	pop r17
	pop r16
	ret
; Generate random value using XOR-shift
; store value to RANDOM_VAL in SRAM
RANDOM:
.macro Rotate_right
	push r18
	ldi r18, @0
ROR_Loop:
	ror r16
	dec r18
	brne ROR_Loop
	pop r18
.endmacro
.macro Rotate_left
	push r18
	ldi r18, @0
ROL_Loop:
	rol r16
	dec r18
	brne ROL_Loop
	pop r18
.endmacro
	push r16
	push r17
	lds r16, RANDOM_VAL
	; r16 ^= r16 << 13
	mov r17, r16
	Rotate_left 13
	eor r16, r17
	; r16 ^= r16 >> 17
	mov r17, r16
	Rotate_right 17
