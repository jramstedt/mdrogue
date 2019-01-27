lcg MACRO dest
	move.l	lcgSeed, \dest
	mulu	#16807, \dest
	andi.l	#$7FFFFFFF, \dest
	move.l	\dest, lcgSeed
	ENDM