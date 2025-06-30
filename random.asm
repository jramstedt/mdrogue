lcg MACRO dest
	move.l	lcgSeed, \dest
	mulu	#16807, \dest
	andi.l	#$7FFFFFFF, \dest
	move.l	\dest, lcgSeed
	ENDM

lfsr MACRO dest
	move.w	lcgSeed, \dest
	lsr.w	\dest
	bcc	.end
	eor.w	#$B400, \dest
.end	move.w	\dest, lcgSeed
	ENDM