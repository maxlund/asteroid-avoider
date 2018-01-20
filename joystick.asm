RESET:
; Set stack pointer to RAMEND
	ldi r16, HIGH(RAMEND)
	out SPH, r16
	ldi r16, LOW(RAMEND)
	out SPL, r16
	call INIT
START:
	call DELAY
; Set ADC reference to AVCC, enable left-adjust mode, and set ADC source to ADC0
	ldi r16, (1 << REFS0) | (1 << ADLAR)
	out ADMUX, r16
	call ADC_SC
; ADC ready if here
; Read ADC result
	in r16, ADCH
; Lower range from 0-255 to 0-15
	lsr r16
	lsr r16
	lsr r16
	lsr r16
; Set ADC source to ADC1
	ldi r17, (1 << REFS0) | (1 << ADLAR) | (1 << MUX0)
	out ADMUX, r17
	call ADC_SC
; Read ADC result
	in r17, ADCH
; Lower range from 0-255 to 0-15
	lsr r17
	lsr r17
	lsr r17
	lsr r17
; Combine results from ADC0 and ADC1
	swap r17
	
or r16, r17
	
Transmit_Not_Ready:
	sbis UCSRA, UDRE
	jmp Transmit_Not_Ready
; Transmit ready if here
	out UDR, r16 
	jmp START
INIT:
; Set ADC reference to AVCC, enable left-adjust mode
	ldi r16, (1 << REFS0) | (1 << ADLAR)
	out ADMUX, r16
; Activate ADC and set prescaler to 128
	ldi r16, (1 << ADEN) + 7
	out ADCSRA, r16
; Set USART character size to 8 bits
	ldi r16, (1 << UCSZ0) | (1 << UCSZ1)
	out UCSRC, r16
; Set USART baud rate to 0.5 Mbps
	clr r16
	out UBRRH, r16
	inc r16
	out UBRRL, r16
	
; Enable USART transmitter
	ldi r16, (1 << TXEN)
	out UCSRB, r16
	ldi r16, (1 << URSEL)
	out UCSRC, r16
; Set even pairity mode for error checking
	ldi r16, (1 << URSEL) | (1 << UPM1)
	out UCSRC, r16
; Start ADC conversion and wait for result
ADC_SC:
	sbi ADCSRA, ADSC
ADC_Not_Done:
	sbic ADCSRA, ADSC
	jmp ADC_Not_Done
	ret
DELAY: ; ~10 ms
	push r16
	push r17
	ldi r17, 210
Delay_Loop:
	ldi r16, 0xFF
Delay_not_done:
	dec r16
	brne Delay_not_done
	dec r17
	brne Delay_Loop
	pop r17
	pop r16
	ret
