
; Linear congruential generator
; \1	target for random number
	MACRO lcg
	move.l	lcgSeed,\1
	mulu	#16807,\1
	andi.l	#$7FFFFFFF,\1
	move.l	\1,lcgSeed
	ENDM


; Linear-feedback shift register
; \1	target for random number
	MACRO lfsr
	move.w	lcgSeed,\1
	lsr.w	\1
	bcc	.end
	eor.w	#$B400,\1
.end	move.w	\1,lcgSeed
	ENDM

; initialize
	move.l	#1,lcgSeed
