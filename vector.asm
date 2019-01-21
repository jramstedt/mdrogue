
vadd MACRO src, dest
	add.w	0(\1), 0(\2)
	add.w	2(\1), 2(\2)
	ENDM

vsub MACRO src, dest
	sub.w	0(\1), 0(\2)
	sub.w	2(\1), 2(\2)
	ENDM

; scalar is in 16.0 fp
vscale MACRO src, dest
	muls.w	\1, 0(\2)
	muls.w	\1, 2(\2)
	ENDM

; angle i
vrotate MACRO vec, angle
	move.l	\angle, d2
	lea.l	sinCosTable, a2
	sinCos a2, d2, d0, d1

	moveq	#0, d5
	moveq	#15, d6

	movem.w	0(\vec), d2/d3
	muls.w	d1, d2	; x = x * cos()
	muls.w	d0, d3	; y = y * sin()
	sub.l	d3, d2	; 12.4 * s.15 = 12.19, needs shift 15 right to get 12.4
	asr.l	d6, d2	; -> 12.4
	addx.w	d5, d2	; round

	movem.w	0(\vec), d3/d4
	muls.w	d0, d3	; x = x * sin()
	muls.w	d1, d4	; y = y * cos()
	add.l	d4, d3	; 12.4 * s.15 = 12.19, needs shift 15 right to get 12.4
	asr.l	d6, d3	; -> 12.4
	addx.w	d5, d3	; round

	movem.w	d2/d3, 0(\vec)

	ENDM