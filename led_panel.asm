
;; LED Panel - Copyright 2014 by Michael Kohn
;; Email: mike@mikekohn.net
;;   Web: http://www.mikekohn.net/
;;
;; Control an RGB 32x16 LED panel.

.avr8
.include "tn2313def.inc"

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
;.org 0x008
;  rjmp service_interrupt
;.org 0x00a
;  rjmp service_interrupt

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
  out UBRRH, r0
  ldi r17, 129
  out UBRRL, r17           ; 129 @ 20MHz = 9600 baud
  ldi r17, (1<<UCSZ0)|(1<<UCSZ1)    ; sets up data as 8N1
  out UCSRC, r17
  ldi r17, (1<<TXEN)|(1<<RXEN)      ; enables send/receive
  out UCSRB, r17
  out UCSRA, r0

  ;; Set up TIMER1
  ;lds r17, PRR
  ;andi r17, 255 ^ (1<<PRTIM1)
  ;sts PRR, r17                   ; turn of power management bit on TIM1

  ;ldi r17, (1000>>8)
  ;out OCR1AH, r17
  ;ldi r17, (1000&0xff)            ; compare to 1000 clocks (0.05ms)
  ;out OCR1AL, r17

  ;ldi r17, (1<<OCIE1A)
  ;out TIMSK, r17                  ; enable interrupt comare A 
  ;out TCCR1C, r0
  ;out TCCR1A, r0                  ; normal counting (0xffff is top, count up)
  ;ldi r17, (1<<CS10)|(1<<WGM12)   ; CTC OCR1A
  ;out TCCR1B, r17                 ; prescale = 1 from clock source

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

;;;;; TEST


main:
  rcall read_byte

  cpi r20, 32            ; if byte sent is > 32 (unsigned) then parse_command
  brsh parse_command

  mov r21, r20           ; r21 is X
  rcall read_byte
  mov r22, r20           ; r22 is Y
  rcall read_byte        ; r20 is color
  lsl r22
  lsl r22                ; Y = Y * 4 (so we point to byte offset of row)
  mov r17, r21
  lsr r17
  lsr r17
  lsr r17                ; r17 = X / 8
  add r22, r17           ; r22 is now byte offset
  andi r21, 7            ; r21 is now bit offset

  ldi r28, (SRAM_START)&0xff ; Y register points to plane 0
  ldi r29, (SRAM_START)>>8

  add r28, r22           ; Y = Y + offset to byte
  adc r29, r0

  sbrc r20, 0            ; if ((color & 1) == 0) { clear_bit(); } else { set_bit(); }
  rcall set_bit
  sbrs r21, 0
  rcall clr_bit

  ldi r28, (SRAM_START+64)&0xff ; Z register points to plane 1 
  ldi r29, (SRAM_START+64)>>8

  add r28, r22           ; Y = Y + offset to byte
  adc r29, r0

  sbrc r20, 1            ; if ((color & 2) == 0) { clear_bit(); } else { set_bit(); }
  rcall set_bit
  sbrs r21, 1
  rcall clr_bit

  out UDR, r2            ; send a '*'
  rjmp main

set_bit:
  ldi r30, (bit_on_table * 2) & 0xff ; Z points to mask table
  ldi r31, (bit_on_table * 2) >> 8
  add r30, r21           ; NOTE: This could have been done with a 16 bit add
  adc r31, r0
  lpm r5, Z              ; r5 holds bit mask
  ld r6, Y               ; r6 holds current byte
  or r6, r5              ; r6 = r6 | r5
  st Y, r6               ; put r6 back into display RAM
  ret

clr_bit:
  ldi r30, (bit_on_table * 2) & 0xff ; Z points to mask table
  ldi r31, (bit_on_table * 2) >> 8
  add r30, r21           ; NOTE: This could have been done with a 16 bit add
  adc r31, r0
  lpm r5, Z              ; r5 holds bit mask
  ld r6, Y               ; r6 holds current byte
  and r6, r5             ; r6 = r6 & r5
  st Y, r6               ; put r6 back into display RAM
  ret

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
  out UDR, r2            ; send a '*'
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

; void send_byte(r24)
send_byte:
  sbis UCSRA, UDRE
  rjmp send_byte      ; if it's not okay, loop around :)
  out UDR, r24        ; output a char over rs232
  ret

read_byte:
  sbis UCSRA, RXC
  rjmp read_byte      ; while(no data);
  in r20, UDR
  ret

bit_on_table:
.db 128, 64, 32, 16, 8, 4, 2, 1

bit_off_table:
.db 128^0xff, 64^0xff, 32^0xff, 16^0xff, 8^0xff, 4^0xff, 2^0xff, 1^0xff

signature:
.db "LED Panel 2 - Copyright 2014 - Michael Kohn - Version 0.01",0

