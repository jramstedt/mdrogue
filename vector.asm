
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

; 0.16 FP
; input: |x| and |y|
; output: x as approximate length
approxlen MACRO x, y
	cmp.w	\y, \x
	bhi.s	*+4		; x bigger, skip exchange
	exg	\y, \x
	
	add.w	\x, \y
	mulu	#46341, \y	; sqrt(0.5) @ 0.16FP = 46340 (.2429046313)
	swap	\y		; >> 16, to original precision

	cmp.w	\y, \x
	bhi.s	*+4		; x bigger, skip exchange
	exg	\y, \x

	move.w	\x, \y

	mulu	#2700, \x	; ((1 + sqrt(4 - 2 * sqrt(2))) / 2) - 1 @ 0.16FP = 2699 (.78642308)
	swap	\x		; >> 16, to original precision
	add	\y, \x		; since we saved one bit of precision before (-1 from calculation), we need to add it back

	ENDM

;
vrotate MACRO vec, angle
	move.l	\angle, d2
	lea.l	sinCosTable, a2
	sinCos a2, d2, d0, d1

	moveq	#0, d5
	moveq	#15, d6	; sin and cos are s.15 fp

	movem.w	0(\vec), d2/d3
	muls.w	d1, d2	; x = x * cos()
	muls.w	d0, d3	; y = y * sin()
	sub.l	d3, d2	; x = x - y
	asr.l	d6, d2	; s.15 -> original vec fixed point
	subx.w	d5, d2	; round

	movem.w	0(\vec), d3/d4
	muls.w	d0, d3	; x = x * sin()
	muls.w	d1, d4	; y = y * cos()
	add.l	d4, d3	; y = x + y
	asr.l	d6, d3	; s.15 -> original vec fixed point
	addx.w	d5, d3	; round

	movem.w	d2/d3, 0(\vec)

	ENDM

;
varctan MACRO vec, angle
	movem.w	0(\vec), d2/d3
	moveq	#0, d4
	moveq	#0, d5

	tst.w	d2
	spl	d4
	bpl.s	*+4	; skip neg
	neg.w	d2	; abs
	and.b	#%100, d4
	or.b	d4, d5

	tst.w	d3
	spl	d4
	bpl.s	*+4	; skip neg
	neg.w	d3	; abs
	and.b	#%010, d4
	or.b	d4, d5

	cmp.w	d2, d3
	smi	d4
	bmi.s	*+4	; skip exchange
	exg	d2, d3	; 
	and.b	#%001, d4
	or.b	d4, d5

	moveq	#12, d4	; In division we lose fraction. We need 12 bits for octant fraction. 15 - 3, MS 3 bits mark the octant
	ext.l	d3
	asl.l	d4, d3

	divs	d2, d3

	lea	octantLookup, a2
	move.b	(a2, d5.w), d5
	bpl.s	@angle		; skip sub
	move	#$1000, d2	; 12 bit percision
	sub.w	d3, d2
	move.l	d2, d3

@angle
	asl.l	d4, d5	; s.15
	or.w	d5, d3

	move	d3, \angle

	ENDM

; vector cross product sign
vcpsign MACRO vec1, vec2
	move.w	0(\vec1), d2
	beq	@v1zero
	move.w	2(\vec1), d3
	beq	@v1zero

	move.w	d2, d0
	eor.w	d3, d0
	smi	d0
	bra.s	@v1end

@v1zero	moveq	#0, d0
@v1end

	move.w	0(\vec2), d4
	beq	@v2zero
	move.w	2(\vec2), d5
	beq	@v2zero

	move.w	d2, d1
	eor.w	d3, d1
	smi	d1
	bra.s	@v2end

@v2zero	moveq	#0, d1
@v2end

	cmp.b	d1, d0
	beq	@abs
	bmi	@posit

@negat	moveq	#-1, d0
	bra.s	@end

@posit	moveq	#1, d0
	bra.s	@end

@abs
	tst.w	d0
	bpl.s	@calc
	neg.w	d2
	neg.w	d3
	neg.w	d4
	neg.w	d5
	exg	d2, d4
	exg	d3, d5

@calc
	muls.w	d2, d3
	muls.w	d4, d5
	
	cmp.l	d5, d3
	bmi.s	@negat
	bpl.s	@posit

	moveq	#0, d0	; parallel?
@end
	ENDM
	
	cnop	0,2
; X Y Abs
octantLookup	dc.b	$85, $04, $02, $83, $06, $87, $81, $00