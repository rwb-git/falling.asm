.include "m328def.inc"

; defs used in adafruit code
.def hi = r16
.def lo = r17
.def next = r18
.def bit = r19
.def byet = r20

.equ fade_tail_length = 20       ; smaller value = longer tail

.cseg

.org $0000
	jmp RESET      ;Reset handle
	


;this looks wrong; spec says 0x0016. so I guess it puts 0xFF or 0x00 from 0x0016 to 0x0022, and somehow worked?

.org $0022
   jmp t1compa



.equ my_sram_start = SRAM_START     ; SRAM_SIZE


.DSEG



.org SRAM_START


color:                                             .BYTE 1

current_led:                                       .BYTE 1
current_led_cnt:                                   .BYTE 2
fade:                                              .BYTE 1
red:                                               .BYTE 1
green:                                             .BYTE 1
blue:                                              .BYTE 1

rgb_flag:                                          .BYTE 1   
led_cnt:                                           .BYTE 1   
rgb_led_bytes:                                     .BYTE 2   
last_sram:                                         .BYTE 1



.CSEG




;------------------------

init_ports:		;uses no regs

; 328 only has ports b c d

; atmel says set all unused pins input with pullups to avoid floating pins
;
;  ports are A B C D E F G H J K L = 11 x 8 = 88 
;            1 2 3 4 5 6 7 8 9 0 1

   clr r16                             ; input mode

   sts ddrb,r16
   sts ddrc,r16
   sts ddrd,r16
   
   ldi r16,0xFF                        ; enable pullup

   sts portb,r16
   sts portc,r16
   sts portd,r16
   
   sbi 	ddrd,pd2	                     ; pd2 is rgb_led pin = pin D2

   sbi ddrb,pb5                        ; pb7 is the led builtin to my mega (pb5 on uno) . if i don't do this it stays on
   cbi portb,pb5                       ; due to the pullup i enabled, i guess

   ret



;----------------------

t1compa:                               ; timer_1 timer_1_interrupt

   push r28

   in r28,sreg

   push r16

   ldi r16,1
   sts rgb_flag,r16

   pop r16

   out sreg,r28
   pop r28
   
   reti

;----------------------------

cycle_colors:

   lds r22,color
   inc r22
   cpi r22,3
   brlo line175

   ldi r22,0

line175:

   sts color,r22

   ret

;-------------------------

inc_r21:

   add r21,r22

   

   ret

   

;----------------------------

store_color:                           ; green = r22  red = r23   blue = r24


   ; see if this led is off

   cpi r22,0
   brne on_208

   cpi r23,0
   brne on_208

   cpi r24,0
   brne on_208

   rjmp off_208

on_208:

   ; r24 has the value

   mov r22,r24
   lsr r22
   lsr r22
   lsr r22

   mov r23,r24
   lsr r23
   lsr r23
   lsr r23

   rjmp line224

off_208:


line224:



   clr r25

   lds r21,color

   cpi r21,0
   brne line192

   st X+,r22                           ; green
   st X+,r23                           ; red
   st X+,r24                           ; blue

   ret

line192:
   
   cpi r21,1
   brne line1912

   st X+,r24                           ; green
   st X+,r22                           ; red
   st X+,r23                           ; blue

   ret

line1912:
   
   cpi r21,2
   brne line1922

   st X+,r23                           ; green
   st X+,r24                           ; red
   st X+,r22                           ; blue

   ret

line1922:
   
   ret

;----------------------------

load_rgb:
 
   lds r26,rgb_led_bytes
   lds r27,rgb_led_bytes+1

   ldi r20,0
   sts fade,r20                        ; fade will draw a tail behind the moving led
   
   ldi r16,36

   ldi r17,255
   clr r18

   lds r19,current_led

loop442:

   cp r16,r19                          ; led closest to nano end of string is #36
                                       ; led at far end is #1
                                       ;
                                       ; why not 0..35? bug? 

   brne line176

   mov r22,r18
   mov r23,r18
   mov r24,r17

   ;rcall store_color                   ; green = r22  red = r23   blue = r24

   ldi r20,255
   sts fade,r20                        ; fade will draw a tail behind the moving led
 
   rjmp line179

line176:

   mov r22,r18
   mov r23,r18

   lds r20,fade
   cpi r20,fade_tail_length                          ; change this smaller for longer tail ( 2 places)
   brlo line180

   ldi r21,fade_tail_length            ; change this smaller for longer tail ( 2 places)
   sub r20,r21
   sts fade,r20

   mov r24,r20                         ; this is the fading color
   ;st X+,r20                           ; blue

   rjmp line179

line180:
   
   mov r24,r18
   ;st X+,r18                           ; blue

line179:

   rcall store_color                   ; green = r22  red = r23   blue = r24

   dec r16
   brne loop442

   lds r19,current_led_cnt             ; this sets the falling speed. lower = faster
   inc r19
   cpi r19,8                           ; 9 is nice
   brlo line2088

   clr r19
line2088:

   sts current_led_cnt,r19
   brne line208

   lds r19,current_led

   inc r19
   sts current_led,r19

   cpi r19,67                          ; last led is 36, but allow tail plus a pause. note that this does not
                                       ; make it write past end of data block in sram
   brlo line208

   ldi r19,1
   sts current_led,r19

   rcall cycle_colors

line208:


   ret



;----------------------------

init_timer_1_interrupt:

   lds r16,tccr1b

   ori r16,(1<<cs12 | 1<<cs10 | 1<< wgm12)         ; 1024 prescale and ctc on A

   sts tccr1b,r16

   ldi r16,0x00
   sts ocr1ah,r16                      ; write high then low. read low then high

   ldi r16,42                          
  
   sts ocr1al,r16

   lds r16,timsk1

   ori r16,(1<<ocie1a)                 ; int on compare a

   sts timsk1,r16


   clr r16
   sts tcnt1h,r16                      ; write high then low. read low then high
   sts tcnt1l,r16

   ret



;--------------------------------------

adafruit:

   ; this awesome code is from adafruit's neo pixel code on github, I believe

;    // WS2811 and WS2812 have different hi/lo duty cycles; this is
;    // similar but NOT an exact copy of the prior 400-on-8 code.
;
;    // 20 inst. clocks per bit: HHHHHxxxxxxxxLLLLLLL
;    // ST instructions:         ^   ^        ^       (T=0,5,13)

;    volatile uint8_t next, bit;

   in hi,portd

   ori hi,0b00000100                   ; use this to raise line

   in lo,portd

   andi lo,0b11111011                  ; use this to lower line

   mov next,lo                           ; assume 1st bit is low


   lds r30,led_cnt
   ldi r31,3

   mul r31,r30                         ; mul result is in r1:r0

   mov r30,r0                          ; this section is ready for led cnt > 85 (255 / 3), but several other places
   mov r31,r1                          ; use one byte. 
   
   lds r26,rgb_led_bytes
   lds r27,rgb_led_bytes+1

   ld byet,X+

   ldi bit,8

   cli                                 ; led timing is critical and stream will be corrupted by interrupts

head20: 

   out  portd, hi 
   sbrc byet,7 
   mov next,hi 
   dec bit  
   out portd,next 
   mov next,lo 
   breq nextbyte20 
   rol byet 
   rjmp line2337  
line2337:
    nop 
    out portd,lo  
    nop  
    rjmp line2342  
line2342:
    rjmp head20  
nextbyte20:   
     ldi bit,8   
     ld byet, X+ 
     out portd,lo   
     nop   
     sbiw r30,1   
     brne head20   

   sei

   ret

;-----------------------------------

clear_sram:		;2560 sram is 0x0200 .. 0x21FF
			      ;
			      ; don't clear stack: stop at SP

   in r26,SPL
   in r27,SPH                          ; X = stack pointer

   ldi r30,low(SRAM_START)
   ldi r31,high(SRAM_START)
   
   ;ldi	r30,0x00
   ;ldi	r31,0x02                      ; this should use SRAM_START instead
	
	clr	r16
loop1287:
	st	z+,r16

   cp r30, r26
   cpc r31,r27

   brlo loop1287

   ret

;---------------------

init_wdr:  ;init_watchdog:

   cli

   wdr

   lds r16,wdtcsr

   ori r16, (1<<wdce | 1<<wde)

   sts wdtcsr, r16

   ldi r16, (1<<wde | 1<<wdp2 | 1<<wdp0 | 1<<wdp1)

                                       ;  wdp3     wdp2     wdp1     wdp0     timeout
                                       ;  0        1        0        1        0.5 seconds
                                       ;  0        0        0        0        0.016 seconds = default
                                       ;  0        1        1        1        2 sec
   sts wdtcsr, r16

   sei

   ret



;-------------------------

RESET:
	ldi	r16,high(RAMEND) 
	out	SPH,r16	         
	ldi	r16,low(RAMEND)	 
	out	SPL,r16

   rcall init_wdr

   rcall init_ports

   rcall clear_sram

   ldi r16,high(last_sram)
   sts rgb_led_bytes+1,r16

   ldi r16,low(last_sram)
   sts rgb_led_bytes,r16

   
   
   clr r17
   ldi r16, 0b10000000
   sts clkpr,r16                       ; pdf 640/1280/2560/2561 pg 48 this sets clock prescale to 1; this sets
   sts clkpr,r17                       ; a system prescale which is for power consumption. the ordinary prescales still work

   rcall	init_timer_1_interrupt

   sei

   ldi r16,36                          ; 36 leds
   sts led_cnt,r16
   

   clr r12                             ; why?

main_loop:

   wdr

   lds r16,rgb_flag
   cpi r16,1
   brne line1281

   clr r16
   sts rgb_flag,r16

   rcall load_rgb
   rcall adafruit
   
line1281:

  
   rjmp	main_loop

