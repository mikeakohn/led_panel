
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
; r5  = display buffer high
; r6  = display buffer low
; r7  = (interrupt) status register save
; r8  = 8
; r9  = flip flag
; r10 = draw buffer low
; r11 = draw buffer high
; r12 = display buffer low
; r13 = display buffer high
; r14 = used in send_byte
; r16 = (interrupt) temp
; r17 = temp
; r18 = (interrupt) temp
; r19 = (interrupt) temp
; r20 = input from UART
; r21 = pixel number low
; r22 = pixel number high
; r23 =
; r26 = X low - points to display buffer
; r27 = X high
; r28 = Y low - points to draw buffer
; r29 = Y high
; r30 = (interrupt) Z low - points to display buffer
; r31 = (interrupt) Z high

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
  ;; PB5-PB0 - R2,G2,B2,R1,G1,B1
  ;; PC2-PC0 - C,B,A
  ;; PC5     - CLK
  ;; PC4     - OE
  ;; PD2     - LAT
  ldi r17, 0x3f
  out DDRB, r17      ; PB0-PB5 of PORTB will be output
  out PORTB, r0      ; turn off all of port B
  out DDRC, r17      ; PC0-PC5 of PORTC will be output
  out PORTC, r0      ; turn off all of port C
  ldi r17, 0x04
  out DDRD, r17      ; PD2 is output
  out PORTD, r0      ; turn off all of port D

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
  sts UCSR0A, r0

  ;; Set up TIMER1
  lds r17, PRR
  andi r17, 255 ^ (1<<PRTIM1)    ; is this needed?
  sts PRR, r17                   ; turn of power management bit on TIM1

  ldi r17, (30000>>8)
  sts OCR1AH, r17
  ldi r17, (30000&0xff)          ; compare to 60000
  sts OCR1AL, r17

  ldi r17, (1<<OCIE1A)
  sts TIMSK1, r17                ; enable interrupt comare A 
  sts TCCR1C, r0
  sts TCCR1A, r0                 ; normal counting (0xffff is top, count up)
  ldi r17, (1<<CS10)|(1<<WGM12)  ; CTC OCR1A
  sts TCCR1B, r17                ; prescale = 1 from clock source

  ;; Set up variable registers
  mov r3, r0  ; current drawing row starts with 0
  mov r9, r0  ; do not flip buffers
  ldi r28, (SRAM_START)&0xff     ; Y register points to draw buffer
  ldi r29, (SRAM_START)>>8
  ldi r26, (SRAM_START+256)&0xff ; X register points to display buffer
  ldi r27, (SRAM_START+256)>>8
  movw r10, r28
  movw r12, r26

  rcall clear_draw_buffer
  rcall clear_display_buffer
 
  ; Interrupts enabled
  sei

main:
  rcall read_byte
  ;; DEBUG
  ;ldi r20, '*'
  ;rcall send_byte
  ;rjmp main
  ;; DEBUG

  cpi r20, 32            ; if byte sent is > 32 (unsigned) then parse_command
  brsh parse_command

  mov r22, r20           ; r22 is address high_byte
  rcall read_byte
  mov r21, r20           ; r21 is address low_byte
  rcall read_byte        ; r20 is color

  ;; Y = buffer + low_byte
  movw r28, r10          ; Y register points to draw buffer

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
  andi r17, 0x07
  or r17, r20
  st Y, r17 

back_to_main:
  ldi r20, '*'
  rcall send_byte
  rjmp main

parse_command:
  cpi r20, 0xff
  brne not_ff
  rcall page_flip
  rjmp parse_command_exit
not_ff:

  cpi r20, 0xfe
  brne not_fe
  rcall clear_draw_buffer
  rjmp parse_command_exit
not_fe:

  cpi r20, 0xfd
  brne not_fd
  rcall copy_display_buffer
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
  ldi r20, '*'          ; send '*'
  rcall send_byte
  rjmp main

page_flip:
  mov r9, r1
page_flip_wait:
  cp r9, r0
  brne page_flip_wait
  ret

clear_draw_buffer:
  movw r28, r10
  ldi r20, 0         ; for (r20 = 0; r20 < 256; r20++)
memset:              ; {
  st Y+, r0          ; [Y++] = 0
  dec r20
  brne memset        ; }
  ret

clear_display_buffer:
  movw r28, r12
  ldi r20, 0         ; for (r20 = 0; r20 < 256; r20++)
memset_display:      ; {
  st Y+, r0          ; [Y++] = 0
  dec r20
  brne memset_display; }
  ret

copy_display_buffer:
  movw r28, r10      ; X = display buffer
  movw r26, r12      ; Y = draw buffer
  ldi r20, 0         ; for (r20 = 0; r20 < 256; r20++)
memcpy:              ; {
  ld r21, X+         ; [Y++] = [X++]
  st Y+, r21
  dec r20
  brne memcpy        ; }
  ret

shift_left:
  movw r28, r10       ; Y = draw_buffer
  movw r26, r10
  adiw r26, 1         ; X = draw_buffer + 1
  ldi r20, 255        ; for (r20 = 0; r20 < 255; r20++)
shift_left_loop:      ; {
  ld r17, X+          ; r17 = [X++]
  st Y+, r17          ; [Y++] = r17
  dec r20
  brne shift_left_loop; }
  movw r28, r10
  adiw r28, 31        ; Y = draw_buffer + 31
  ldi r20, 8          ; for (r20 = 0; r20 < 8; r20++)
shift_left_clear:     ; {
  st Y, r0            ; [Y] = 0
  adiw r28, 32        ; Y += 32
  dec r20
  brne shift_left_clear; }
  ret

shift_right:
  ldi r20, 255
  movw r28, r10       ; Y = draw_buffer + 256
  add r28, r20
  adc r29, r0
  movw r26, r28       ; X = Y - 1
  adiw r28, 1
  ldi r20, 255        ; for (r20 = 0; r20 < 255; r20++)
shift_right_loop:     ; {
  ld r17, -X          ; r17 = [--X]
  st -Y, r17          ; [--Y] = r17
  dec r20
  brne shift_right_loop; }
  movw r28, r10       ; Y = draw_buffer
  ldi r20, 8          ; for (r20 = 0; r20 < 8; r20++)
shift_right_clear:    ; {
  st Y, r0            ; [Y] = 0
  adiw r28, 32        ; Y += 32
  dec r20
  brne shift_right_clear; }
  ret

shift_up:
  ;; Copy row 8 (aka 0) so it can be copied to row 7 after
  movw r28, r10       ; Y = draw_buffer
  ldi r26, (SRAM_START+512)&0xff  ; X area of 32 spare bytes
  ldi r27, (SRAM_START+512)>>8
  ldi r20, 32         ; for (r20 = 0; r20 < 32; r20++)
shift_up_save_row:    ; {
  ld r17, Y+
  lsr r17
  lsr r17
  lsr r17
  st X+, r17
  dec r20
  brne shift_up_save_row  ; }

  movw r28, r10       ; Y = draw_buffer
  movw r26, r10
  adiw r26, 32        ; X = draw_buffer + 32
  ldi r20, 256-32     ; for (r20 = 0; r20 < 256-32; r20++)
shift_up_loop:        ; {
  ld r17, X+          ; r17 = [X++]
  st Y+, r17          ; [Y++] = r17
  dec r20
  brne shift_up_loop  ; }
  ldi r17, 224
  movw r28, r10
  add r28, r17        ; Y = draw_buffer + 224
  adc r29, r0
  ldi r26, (SRAM_START+512)&0xff  ; X area of 32 spare bytes
  ldi r27, (SRAM_START+512)>>8
  ldi r20, 32         ; for (r20 = 0; r20 < 32; r20++)
shift_up_clear:       ; {
  ld r17, X+
  ;andi r17, 0x07
  st Y+, r17          ; [Y++] = [X++]
  dec r20
  brne shift_up_clear;}
  ret

shift_down:
  ;; Copy row 7 so it can be copied to row 8 (aka 0) after
  movw r28, r10       ; Y = draw_buffer + 224
  ldi r20, 224
  add r28, r20
  adc r29, r0
  ldi r26, (SRAM_START+512)&0xff  ; X area of 32 spare bytes
  ldi r27, (SRAM_START+512)>>8
  ldi r20, 32         ; for (r20 = 0; r20 < 32; r20++)
shift_down_save_row:    ; {
  ld r17, Y+
  andi r17, 0x7       ; probably not needed
  lsl r17
  lsl r17
  lsl r17
  st X+, r17
  dec r20
  brne shift_down_save_row  ; }

  ;ldi r20, 255
  movw r28, r10       ; Y = draw_buffer + 256
  ;add r28, r20
  ;adc r29, r0
  ;adiw r28, 1
  add r29, r1
  movw r26, r28       ; X = Y - 32
  sbiw r26, 32
  ldi r20, 256-32     ; for (r20 = 0; r20 < 256-32; r20++)
shift_down_loop:        ; {
  ld r17, -X          ; r17 = [--X]
  st -Y, r17          ; [--Y] = r17
  dec r20
  brne shift_down_loop  ; }

  movw r28, r10       ; Y = draw_buffer
  ldi r26, (SRAM_START+512)&0xff  ; X area of 32 spare bytes
  ldi r27, (SRAM_START+512)>>8
  ldi r20, 32         ; for (r20 = 0; r20 < 32; r20++)
shift_down_clear:     ; {
  ld r17, X+
  st Y+, r17          ; [Y++] = [X++]
  dec r20
  brne shift_down_clear;}
  ret

service_interrupt:
  ; save status register
  in r7, SREG

  movw r30, r12      ; Z register points to display buffer
  mov r18, r3        ; r18 = r3 * 32
  swap r18
  lsl r18
  add r30, r18       ; Z = Z + r18
  adc r31, r0

  ldi r18, 32        ; for (r18 = 0; r18 < 32; r18++)
draw_loop:           ; {
  ld r16, Z+
  out PORTB, r16
  sbi PORTC, 5       ; CLK HIGH
  cbi PORTC, 5       ; CLK LOW
  dec r18
  brne draw_loop     ; }

  sbi PORTC, 4        ; Output Disable
  sbi PORTD, 2        ; Latch on
  cbi PORTD, 2        ; Latch off
  out PORTC, r3       ; Move to current row
  ;cbi PORTC, 4        ; Output Enable (the above line already does this)

  inc r3              ; r3 = (r3 + 1) & 0x07
  ldi r18, 0x07      
  and r3, r18
  brne exit_interrupt ; if r3 != 0 then exit_interrupt

  cp r9, r0           ; if r9 == 0 then exit_interrupt
  breq exit_interrupt

  movw r18, r10       ; temp = draw buffer
  movw r10, r12       ; draw buffer = display buffer
  movw r12, r18       ; display buffer = temp
  mov r9, r0          ; flip flag = 0

exit_interrupt:
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
.db "LED Panel 2 - Copyright 2014 - Michael Kohn - Version 0.03",0

