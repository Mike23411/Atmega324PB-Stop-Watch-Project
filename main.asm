
.INCLUDE "m324pbdef.inc"
.ORG 0
LDI R16, HIGH(RAMEND)
OUT SPH, R16
LDI R16, LOW(RAMEND)
OUT SPL, R16

LDI R16, 0x0F
LDI R17, 0x00
LDI R18, 0xFF
OUT DDRD, R16	;last 4 bits of portd on output (LEDs)
OUT PORTD, R16	;initialize LEDs to off
OUT DDRA, R17	;porta on input (switches)
OUT PORTA, R18	;porta pullup resistors on
SBI DDRE, 4		;PE4 on output (for buzzer)
;will use first two switches for increment/decrement
;switches are active low (0 when pressed)
;SW1 = PA0 => increment
;SW2 = PA1 => decrement
;SW3 = PA2 => stopwatch
;SW4 = PA3 => toggle buzz on every updated value
;SW7 = PA5 => increment scale
;SW8 = PA7 => decrement scale

LDI R23, 0xF0
LDI R31, 0x00	;holds the current count, initially 0
LDI R30, 15		;holds maximum
LDI R29, 0		;holds minimum

LDI R25, 0		;at startup, turn off buzz on every updated value
LDI R19, 1	;holds the current number to increment or decrement by (scale)


LISTEN: COM R31			;complement for the active low LEDs
CALL REVERSE			;reverse order of the last 4 bits so it displays correctly
OUT PORTD, R31			;display count in binary on LEDs
CALL REVERSE			;reverse the order back to normal
COM R31					;complement back to the normal count
SUB R31, R23			;subtract the 0xF0 from the front of the count (from complementing the 0)
SBIS PINA, 0
CALL INCREMENT
SBIS PINA, 1
CALL DECREMENT
SBIS PINA, 2			;check stopwatch switch
CALL STOPWATCH_BEGIN
SBIS PINA, 3			;if SW4 pressed, toggle buzz on updated value status
CALL TOGGLE_SHORT_BUZZ
SBIS PINA, 5			;if SW7 is pressed, increment the number the count is scaled by
CALL INCREMENT_SCALE
SBIS PINA, 6			;if SW8 is pressed, decrement the number the count is scaled by
CALL DECREMENT_SCALE
RJMP LISTEN

INCREMENT: SBIS PINA, 0 ;Waits for user to let go of SW1
RJMP INCREMENT
CPI R31, 15 ;Determines if overflow will occur
BRGE OVER_TO_ZERO ;Determines value from overflow
ADD R31, R19 ;Adds the current count and the scale
CALL SHORT_BUZZ	;Call buzz on every inc/dec option feature if toggle is set.
CALL DELAY ;Makes sure to not increment more than once
RETURN_INCREMENT: RET

;called when count overflows from 15 to 0
OVER_TO_ZERO: SUB R31, R30
CALL BUZZ
RJMP RETURN_INCREMENT

DECREMENT: SBIS PINA, 1 ;Waits for user to let go of SW2
RJMP DECREMENT
CP R31, R19 ;Determines if overflow will occur
BRLT OVER_TO_MAX ;Determines value from overflow
SUB R31, R19 ;Subtracts the scale from the current count
CALL SHORT_BUZZ ;Call buzz on every inc/dec option feature if toggle is set.
CALL DELAY ;Makes sure to not decrement more than once
RETURN_DECREMENT: RET

;called when count overflows from 0 to the max count (15)
OVER_TO_MAX: MOV R26,R31
LDI R31,16
SUB R31,R19
ADD R31,R26
CALL BUZZ
RJMP RETURN_DECREMENT

BUZZ: LDI R20, 0x3F		;loop buzz for this many times
LOOP:SBI PORTE, 4
CALL DELAY
CBI PORTE, 4
CALL DELAY
DEC R20
BRNE LOOP
RET

;fosc=16MHz 
;delay should last 0.002 seconds for 500Hz signal
;last 0.001 for 1000Hz, someone do the math for the exact
;delay to put here so I dont have to please
DELAY:LDI R16, 20
LOOP_1: LDI R17, 200
LOOP_2: DEC R17
BRNE LOOP_2
DEC R16
BRNE LOOP_1
RET

REVERSE: LDI R22, 4
LDI R21, 0
CLC
REVERSE_LOOP: ROR R31
ROL R21
DEC R22
BRNE REVERSE_LOOP
MOV R31, R21
RET

;stopwatch - starts a new count (separte from main count feature)
;starting at 0, counts up at regular increments while the button is pressed,
;will sound a buzz if the count exceeds 15 and will overflow back to 0.
;When the button is released, the count will show for about a second before
;returning to the main feature's count and function
STOPWATCH_BEGIN: LDI R28, 0		;outputs initial count, the same way as the main feature
COM R28
CALL STOPWATCH_REVERSE
OUT PORTD, R28
CALL STOPWATCH_REVERSE
COM R28
SUB R28, R23
CALL LONG_DELAY
STOPWATCH_TICK: SBIC PINA, 2	;checks if pin is still held, if not then stop the stopwatch
RJMP STOPWATCH_STOP
CALL STOPWATCH_INCREMENT		;if pin still held, increment count and output new count
COM R28
CALL STOPWATCH_REVERSE
OUT PORTD, R28
CALL STOPWATCH_REVERSE
COM R28
SUB R28, R23
CALL LONG_DELAY					;wait a little bit before incrementing again
RJMP STOPWATCH_TICK

;When the button is released, we want to display the count for a longer
;period of time, so we call long delay before retuning back to the main
;listen function
STOPWATCH_STOP: CALL LONG_DELAY
CALL LONG_DELAY
CALL LONG_DELAY
RJMP LISTEN

;same as INCREMENT but with a new register
STOPWATCH_INCREMENT: CP R30, R28
BREQ STOPWATCH_OVER_TO_ZERO
INC R28
RET

;same as before but new reegister
STOPWATCH_OVER_TO_ZERO: LDI R28, 0
CALL BUZZ
RET

;same as REVERSE but with new register
STOPWATCH_REVERSE: LDI R22, 4
LDI R21, 0
CLC
STOPWATCH_REVERSE_LOOP: ROR R28
ROL R21
DEC R22
BRNE STOPWATCH_REVERSE_LOOP
MOV R28, R21
RET

;loops the DELAY function several times to create a longer delay for this
;lasts about 1.2 seconds
LONG_DELAY: LDI R27, 3
LONG_DELAY_LOOP1: LDI R26, 100
LONG_DELAY_LOOP2: CALL DELAY
DEC R26
BRNE LONG_DELAY_LOOP2
DEC R27
BRNE LONG_DELAY_LOOP1
RET

;buzz on every inc/dec option
;toggle the flag for turning the buzz on every inc/dec option on/off
TOGGLE_SHORT_BUZZ: SBIS PINA, 3	;wait for user to release button
RJMP TOGGLE_SHORT_BUZZ
COM R25							;toggle flag for buzz on every updated value
RET

;generate the short buzz for this feature
SHORT_BUZZ: LDI R16, 0xFF		;only buzz if flag (R25) is set
CP R25, R16
BRNE RETURN_SHORT_BUZZ
LDI R18, 20						;num SHORT_DELAY cycles to run the buzzer for
SHORT_BUZZ_LOOP: SBI PORTE, 4	;turn on buzzer
CALL SHORT_DELAY				;active high
CBI PORTE, 4					;turn off buzzer
CALL SHORT_DELAY				;active low
DEC R18
BRNE SHORT_BUZZ_LOOP
RETURN_SHORT_BUZZ: RET

;delay used in short buzz feature
SHORT_DELAY: LDI R16, 20
LOOP1: LDI R17, 255
LOOP2: DEC R17
BRNE LOOP2
DEC R16
BRNE LOOP1
RET

;change scaling between 1 and 15
INCREMENT_SCALE: SBIS PINA, 5 ;Activates when switch 7 is pressed
RJMP INCREMENT_SCALE
CP R19,R30 ;Compares current scale to maximum scale value
BRGE SCALE_TO_ONE ;If current scale is greater than or equal to max value scale is set to one
INC R19
CALL BUZZ ;Buzzes to confirm completion of operation
RET

DECREMENT_SCALE: SBIS PINA, 6 ;Activates when switch 8 is pressed
RJMP DECREMENT_SCALE
CPI R19,1 ;Compares current scale to minimum scale value
BREQ SCALE_TO_FIFTEEN ;If current scale is equal to minimum value scale is set to fifteen
DEC R19
CALL BUZZ ;Buzzes to confirm completion of operation
RET

SCALE_TO_ONE: LDI R19,1
RET

SCALE_TO_FIFTEEN: LDI R19,15
RET
