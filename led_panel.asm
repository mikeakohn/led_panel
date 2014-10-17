
;; LED Panel - Copyright 2014 by Michael Kohn
;; Email: mike@mikekohn.net
;;   Web: http://www.mikekohn.net/
;;
;; Control an RGB 32x16 LED panel.

.avr8
.include "m168def.inc"

;  cycles  time   @20MHz:
;   20000: 1ms
;   10000: 0.5ms
;    1000: 0.05ms

; interrupts  time   @0.05ms increments
;         20  1ms 
;         40  2ms 
;        400 20ms 

; r0  = 0
; r1  = 1
; r2  = '*'
; r3  =
; r4  =
; r5  =
; r6  =
; r7  =
; r8  = 8
; r10 = palette 0
; r11 = palette 1
; r12 = palette 2
; r13 = palette 3
; r17 = temp
; r18 =
; r19 =
; r20 = input from UART
; r21 = X
; r22 = Y
; r23 =
;

; note: With debugWire off
;  EXTENDED: 0xff
;      HIGH: 0xdf
;       LOW: 0xce

.org 0x000
  rjmp start
.org 0x016  ; TIMER1 COMPA
  rjmp service_interrupt

start:
  ;; Interrupts off
  cli

  ;; Set up some registers
  eor r0, r0
  eor r1, r1
  inc r1
  ldi r17, '*'
  mov r2, r17
  ldi r17, 8 
  mov r8, r17

  ;; Set up PORTB
  ;; PB5-PB0 - R2,G2,B2,R1,G1,B1
  ;; PD5-PD3 - C,B,A
  ;; PD2     - OE
  ;; PD6     - CLK
  ;; PB7     - LAT
  ldi r17, 0xff
  ldi r18, 0
  out DDRB, r17      ; all of PORTB will be output
  out PORTB, r18     ; turn off all of port B
  out DDRD, r17      ; all of PORTD will be output
  out PORTD, r18     ; turn off all of port D

  ;; Clear LED RAM (32 * 16 * 3 bytes / 8)
  ldi r28, (SRAM_START)&0xff
  ldi r29, (SRAM_START)>>8
  ldi r23, 128
memset:
  st Y+, r0
  dec r23
  brne memset

  ;; Set up stack ptr
  ;ldi r17, RAMEND>>8
  ;out SPH, r17
  ;ldi r17, RAMEND&255
  ;out SPL, r17

  ;; Setup UART - (fOSC / (baud * 16)) - 1 = UBRR
  sts UBRR0H, r0
  ldi r17, 129
  sts UBRR0L, r17           ; 129 @ 20MHz = 9600 baud
  ldi r17, (1<<UCSZ00)|(1<<UCSZ01)    ; sets up data as 8N1
  sts UCSR0C, r17
  ldi r17, (1<<TXEN0)|(1<<RXEN0)      ; enables send/receive
  sts UCSR0B, r17
  eor r17, r17
  sts UCSR0A, r17

  ;; Set up TIMER1
  lds r17, PRR
  andi r17, 255 ^ (1<<PRTIM1)    ; is this needed?
  sts PRR, r17                   ; turn of power management bit on TIM1

  ldi r17, (60000>>8)
  sts OCR1AH, r17
  ldi r17, (60000&0xff)          ; compare to 60000
  sts OCR1AL, r17

  ldi r17, (1<<OCIE1A)
  sts TIMSK1, r17                ; enable interrupt comare A 
  sts TCCR1C, r0
  sts TCCR1A, r0                 ; normal counting (0xffff is top, count up)
  ldi r17, (1<<CS10)|(1<<WGM12)  ; CTC OCR1A
  sts TCCR1B, r17                ; prescale = 1 from clock source

;; DEBUG
  ldi r24, '*'
  rcall send_byte
  
  ; Interrupts enabled
  sei


;;;;; TEST
  ;; PB5-PB0 - R2,G2,B2,R1,G1,B1
  ;; PD5-PD3 - C,B,A
  ;; PD2     - OE
  ;; PD6     - CLK
  ;; PB7     - LAT

.if 0
  ldi r17, 0x00
next_row:
  out PORTD, r17
  ldi r18, 0x19
  out PORTB, r18

  ;; clock out 2 bits
  sbi PORTD, 6
  cbi PORTD, 6
  sbi PORTD, 6
  cbi PORTD, 6
  out PORTB, r0
  ldi r18, 30
clock_next_bit:
  sbi PORTD, 6
  cbi PORTD, 6
  dec r18
  brne clock_next_bit

  sbi PORTD, 2
  sbi PORTB, 7
  cbi PORTB, 7
  cbi PORTD, 2

  add r17, r8
  cpi r17, 0x38
  brne next_row

never_ending_loop:
  sbi PORTD, 3
  cbi PORTD, 3
  sbi PORTD, 4
  sbi PORTD, 3
  cbi PORTD, 4
  cbi PORTD, 3
  rjmp never_ending_loop
.endif

;;;;; TEST


main:
  rcall read_byte

  cpi r20, 32            ; if byte sent is > 32 (unsigned) then parse_command
  brsh parse_command

  mov r22, r20           ; r22 is address high-byte
  rcall read_byte
  mov r21, r20           ; r21 is address low-byte
  rcall read_byte        ; r20 is color

  ldi r28, (SRAM_START)&0xff ; Y register points to plane 0
  ldi r29, (SRAM_START)>>8

  add r28, r21
  adc r29, r0

  cpi r22, 1
  breq update_high_section
  cpi r22, 2
  breq back_to_main 

  ld r17, Y
  andi r17, 0x03
  or r17, r20
  st Y, r17 

  rjmp back_to_main

update_high_section:

back_to_main:
  sts UDR0, r2           ; send a '*'
  rjmp main

parse_command:
  cpi r20, 0xff
  brne not_ff
  rcall send_led_data
  rjmp parse_command_exit
not_ff:

  cpi r20, 0xfe
  brne not_fe
  rcall read_byte
  mov r10, r20
  rjmp parse_command_exit
not_fe:

  cpi r20, 0xfd
  brne not_fd
  rcall read_byte
  mov r11, r20
  rjmp parse_command_exit
not_fd:

  cpi r20, 0xfc
  brne not_fc
  rcall read_byte
  mov r12, r20
  rjmp parse_command_exit
not_fc:

  cpi r20, 0xfb
  brne not_fb
  rcall read_byte
  mov r13, r20
  rjmp parse_command_exit
not_fb:

  cpi r20, 0xfa
  brne not_fa
  rcall shift_left
  rjmp parse_command_exit
not_fa:

parse_command_exit:
  sts UDR0, r2            ; send a '*'
  rjmp main

send_led_data:
  ;; PB5-PB0 - R2,G2,B2,R1,G1,B1
  ;; PD5-PD3 - C,B,A
  ;; PD2     - OE
  ;; PD6     - CLK
  ;; PB7     - LAT
  ret

shift_left:
  ret

shift_right:
  ret

shift_up:
  ret

shift_down:
  ret

service_interrupt:
  ; save status register
  in r7, SREG

  ; increment interrupt counter
  inc r23
  out SREG, r7
  reti

; void send_byte(r20)
send_byte:
  lds r14, UCSR0A
  sbrs r14, UDRE0
  rjmp send_byte      ; if it's not okay, loop around
  sts UDR0, r20       ; output a char over rs232
  ret

read_byte:
  lds r20, UCSR0A
  sbrs r20, RXC0
  rjmp read_byte      ; while(no data);
  lds r20, UDR0
  ret

bit_on_table:
.db 128, 64, 32, 16, 8, 4, 2, 1

bit_off_table:
.db 128^0xff, 64^0xff, 32^0xff, 16^0xff, 8^0xff, 4^0xff, 2^0xff, 1^0xff

signature:
.db "LED Panel 2 - Copyright 2014 - Michael Kohn - Version 0.01",0
