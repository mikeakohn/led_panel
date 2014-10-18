
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
; r3  = (interrupt) current drawing row
; r4  =
; r5  =
; r6  =
; r7  =
; r8  = 8
; r10 =
; r11 =
; r12 =
; r13 =
; r16 = (interrupt) temp
; r17 = temp
; r18 = (interrupt) temp
; r19 =
; r20 = input from UART
; r21 =
; r22 =
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

  ;; Set up PORTB,PORTC,PORTD
  ;; PB2-PB0 - C,B,A
  ;; PC5-PC0 - R2,G2,B2,R1,G1,B1
  ;; PD5     - CLK
  ;; PD6     - LAT
  ;; PD7     - OE
  ldi r17, 0xff
  out DDRB, r17      ; all of PORTB will be output
  out PORTB, r0      ; turn off all of port B
  out DDRC, r17      ; all of PORTB will be output
  out PORTC, r0      ; turn off all of port C
  out DDRD, r17      ; all of PORTD will be output
  out PORTD, r0      ; turn off all of port D

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

  ;; Set up variable registers
  mov r3, r0  ; current drawing row starts with 0

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

  mov r22, r20           ; r22 is address high_byte
  rcall read_byte
  mov r21, r20           ; r21 is address low_byte
  rcall read_byte        ; r20 is color

  ;; Y = buffer + low_byte
  ldi r28, (SRAM_START)&0xff ; Y register points to buffer
  ldi r29, (SRAM_START)>>8

  add r28, r21
  adc r29, r0

  ;; since the lower and upper rows share the same bytes, figure out if
  ;; high byte is 0 or 1, or 2 (invalid)
  cpi r22, 1
  breq update_high_section
  cpi r22, 2
  breq back_to_main 

  ;; [Y] = ([Y] & 0xf8) | color
  ld r17, Y
  andi r17, 0xf8
  or r17, r20
  st Y, r17 
  rjmp back_to_main

update_high_section:
  ;; [Y] = ([Y] & 0x03) | (color << 3)
  lsl r20
  lsl r20
  lsl r20
  ld r17, Y
  andi r17, 0xf8
  or r17, r20
  st Y, r17 

back_to_main:
  sts UDR0, r2           ; send a '*'
  rjmp main

parse_command:
  cpi r20, 0xff
  brne not_ff
  rcall page_flip
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
  rcall shift_left
  rjmp parse_command_exit
not_fc:

  cpi r20, 0xfb
  brne not_fb
  rcall shift_right
  rjmp parse_command_exit
not_fb:

  cpi r20, 0xfa
  brne not_fa
  rcall shift_up
  rjmp parse_command_exit
not_fa:

  cpi r20, 0xf9
  brne not_f9
  rcall shift_down
  rjmp parse_command_exit
not_f9:

parse_command_exit:
  sts UDR0, r2            ; send a '*'
  rjmp main

page_flip:
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

  ldi r30, (SRAM_START)&0xff ; Z register points to buffer
  ldi r31, (SRAM_START)>>8
  mov r18, r3        ; r18 = (r3 & 0x07) * 32
  andi r18, 0x07
  swap r18
  lsl r18
  add r30, r18       ; Z = Z + r18
  adc r30, r0

  ldi r18, 32        ; for (r18 = 0; r18 < 32; r18++)
draw_loop:           ; {
  ld r16, Z+
  out PORTC, r16
  sbi PORTD, 5       ; CLK HIGH
  cbi PORTD, 5       ; CLK LOW
  dec r18
  brne draw_loop     ; }

  cbi PORTD, 7       ; Output Disable
  sbi PORTD, 6       ; Latch on
  out PORTB, r3      ; Move to current row
  cbi PORTD, 6       ; Latch off
  sbi PORTD, 7       ; Output Enable

  inc r3
  ;ldi r18, 0x07      
  ;and r3, r18

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

signature:
.db "LED Panel 2 - Copyright 2014 - Michael Kohn - Version 0.02",0

