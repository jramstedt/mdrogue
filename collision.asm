calculateCollision MACRO type, skip
	movem.w	obX(a0), d1/d2
	movem.w	obX(a1), d3/d4

	moveq	#0, d5
	move.b	obRadius(a0), d5
	add.b	obRadius(a1), d5
	lsl.w	#3, d5	; 8.0 -> 13.3

	sub.w	d1, d3
	bpl.s	*+4	; skip neg
	neg.w	d3	; abs

	cmp.w	d5, d3	; if d3 >= radius+radius then skip
	bge	\skip

	sub.w	d2, d4
	bpl.s	*+4	; skip neg
	neg.w	d4	; abs

	cmp.w	d5, d4	; if d4 >= radius+radius then skip
	bge	\skip

	; check real distance
	
	approxlen d3, d4
	cmp.w	d5, d3	; if d3 >= radius+radius then skip
	bge	\skip

	; handle collision

	; d3 = delta vector length 13.3
	; d5 = radius+radius 13.3

	IF STRCMP(\type, 'dtod')
		
		; dx = x1 - x2
		; dy = y1 - y2

		; n = normalizing coefficient = displacement / radius+radius
		; f = target size ratio = obRadius(a1) / radius+radius
		; s = displacement scalar = n * f = displacement * obRadius(a1) / (radius+radius)^2

		; sx = source displacement x = s * dx
		; sy = source displacement y = s * dy
		; tx = target displacement x = (s-1) * dx
		; ty = target displacement y = (s-1) * dy

		move.l	d5, d6			; d6 = radius+radius
		move.l	d5, d7			; d7 = radius+radius
		sub.w	d3, d6			; d6 = d5 - d3, displacement

		moveq	#0, d5
		move.b	obRadius(a1), d5
		mulu	d5, d6			; d6 = displacement * obRadius(a1), 13.3
		swap	d6			; 13.19
		mulu	d7, d7			; d7 = (radius+radius)^2, 26.6
		asr.l	#3, d7			; 26.3

		divu	d7, d6			; 0.16
						; d6 = displacement * obRadius(a1) / (radius+radius)^2
		move.w	d6, d7
		not.w	d7			; d7 = s - 1

		; X axis
		sub.w	obX(a1), d1		; d1 = dx = x1 - x2
		move.w	d1, d4			; d4 = dx

		muls	d6, d1			; d1 = sx 13.19
		swap	d1			; 13.3
		add.w	d1, obX(a0)

		muls	d7, d4			; d1 = tx 13.19
		swap	d4
		add.w	d4, obX(a1)

		; Y axis
		sub.w	obY(a1), d2		; d2 = dy = y1 - y2
		move.w	d2, d4			; d4 = dy
		
		muls	d6, d2			; d2 = sy 13.19
		swap	d2			; 13.3
		add.w	d2, obY(a0)

		muls	d7, d4			; d2 = ty 13.19
		swap	d4
		add.w	d4, obY(a1)
		
	ELSE
		move.l	d5, d6			; d6 = radius+radius
		sub.w	d3, d6			; d6 = d5 - d3, displacement

		swap	d6			; 13.19

		divu	d3, d6			; 0.16
						; d6 = displacement / approxlen

		; X axis
		sub.w	obX(a1), d1		; d1 = dx = x1 - x2

		muls	d6, d1			; d1 = sx 13.19
		swap	d1			; 13.3

		; Y axis
		sub.w	obY(a1), d2		; d2 = dy = y1 - y2

		muls	d6, d2			; d2 = sy 13.19
		swap	d2			; 13.3
		
		IF STRCMP(\type, 'dtok')
			add.w	d1, obX(a0)
			add.w	d2, obY(a0)
		ELSEIF STRCMP(\type, 'ktod')
			sub.w	d1, obX(a1)
			sub.w	d2, obY(a1)
		ENDIF
	ENDIF

	ENDM

;
processPhysicObjects	MODULE
	lea.l	gameObjects, a0
	lea.l	obDataSize(a0), a0	; start from second object.

@sourceLoop
	tst.b	obClass(a0)
	beq.s	@skipSource

	move.w	obPhysics(a0), d0	; obPhysics on upper byte, obCollision on lower
	lsr.b	#4, d0			; object collision groups to masks

	lea.l	gameObjects, a1
@targetLoop
	tst.b	obClass(a1)
	beq.s	@skipTarget

	move.w	obPhysics(a1), d3	; obPhysics on upper byte, obCollision on lower
	and.b	d0, d3			; test group against mask, if not matched skip.
	beq.s	@skipTarget

	andi.w	#$0100, d3	; mask kinematic only
	beq.s	@targetDynamic
	and.w	d0, d3		; test if both kinematic
	bne.s	@skipTarget

	jmp	@targetKinematic

@skipTarget
	lea	obDataSize(a1), a1

	cmpa.w	a0, a1
	blo.s	@targetLoop

@skipSource
	lea	obDataSize(a0), a0
	cmpa.l	#(gameObjects+(obDataSize*gameObjectsLen)), a0
	blo.s	@sourceLoop

	rts

@targetDynamic
	btst	#8, d0
	beq.s	@dtod	; both dynamic

	; if target dynamic bounce target
	calculateCollision 'ktod', @skipTarget
	jmp @skipTarget
	
	; if both dynamic calculate bounce (radius ratio)
@dtod	calculateCollision 'dtod', @skipTarget
	jmp @skipTarget

@targetKinematic
	; if source dynamic bounce source
	calculateCollision 'dtok', @skipTarget
	jmp @skipTarget

	MODEND

; d0 X
; d1 Y
; trashes d0 d1 d2 d3 a1
levelCollision	MODULE
	move.l	(loadedLevelAddress), a1
	movea.l	lvlCollisionData(a1), a2	; a2 will be the address to collision data byte at d0,d1 (needs to be bittest with x position)

	; Yp = y / 8
	; Yc = Yp / 32
	; Yi = Yp % 32

	; Y
	asr.w	#6, d1		; to pixels, to patterns

	; Y offset inside chunk
	moveq	#$1F, d2
	and.w	d1, d2		; number of rows
	lsl.b	#2, d2		; 32bits = 4bytes in row, d2 is byte offset
	adda.w	d2, a2
	
	; >> 5 to chunks
	; lsr.w	#5, d1
	; lsl.w	#7, d1		; offset in bytes
	clr.l	d3
	and.w	#$FFE0, d1	; truncate to chunk start
	lsl.l	#2, d1		; 32bits = 4bytes in row, full chunks now
	move.b	lvlWidth(a1), d3
	mulu	d3, d1
	
	adda.w	d1, a2

	; Xp = x / 8
	; Xc = Xp / 32
	; Xi = Xp % 32

	; X
	asr.w	#6, d0		; to pixels, to patterns

	; X offset inside chunk
	moveq	#$1F, d2
	and.b	d0, d2	; d2 is x in patterns
	; We can use btst directly with d2 now.

	; >> 5 to chunks
	; collision data chunk is 32*32 bits = 32 longs, 128 bytes
	; lsr.w	#5, d0
	; lsl.w	#7, d0
	and.w	#$FFE0, d0	; truncate to chunk start
	lsl.w	#2, d0		; 
	adda.w	d0, a2

	move.l	(a2), d0
	btst.l	d2, d0		; bittest with x position

	rts
	MODEND

; clampToGrid
clampToGrid	MACRO	point, corner
	LOCAL clampMax, end
	cmp.\0	\corner, \point
	bgt	clampMax
	move.\0	\corner, \point
	bra	end

clampMax
	add.\0	#1<<6, \corner	; add one full pattern
	cmp.\0	\corner, \point
	blt	end
	move.\0	\corner, \point
end
	ENDM

; a0 obj
; trashes a1, a2, d0, d1, d2, d3, d4, d5, d6, d7
collideWithLevel	MODULE
	move.l	(loadedLevelAddress), a1

	; ! note
	; d0, d1 loop counters
	; d2, d3 closest point in grid cell
	; d4, d5 diff of object to closest grid point

	moveq	#0, d2
	moveq	#0, d3

	; Y pixels to loop
	moveq	#0, d1
	move.b	obRadius(a0), d1
	asl.w	#1, d1		; to diameter; Y pixels, will be decremented in loop

@yLoop
	
	; X amount to loop
	moveq	#0, d0
	move.b	obRadius(a0), d0
	asl.w	#1, d0		; to diameter; X pixels, will be decremented in loop

@xLoop
	movea.l	lvlCollisionData(a1), a2

	; Y grid cell
	moveq	#0, d5
	move.b	obRadius(a0), d5
	sub.w	d1, d5
	asl.w	#3, d5		; to 13.3
	add.w	obY(a0), d5

	; Position to grid cell
	; Sets data address
	and.w	#$FFC0, d5	; truncate to grid cell

	; Chunk Y offset
	moveq	#0, d6
	move.b	lvlWidth(a1), d6

	move	#$F800, d7	; FFE0<<6
	and.w	d5, d7
	asr.w	#4, d7		; 6 - 2
	mulu	d6, d7
	adda.w	d7, a2

	; Y offset inside chunk
	move	#$7C0, d7	; 1F<<6
	and.w	d5, d7
	asr.w	#4, d7		; 6 - 2
	adda.w	d7, a2

	move.w	obY(a0), d3
	clampToGrid.w d3, d5	; d3 = closest point Y

	; Y diff
	sub.w	obY(a0), d3
	move.w	d3, d5		; d5 = Y diff
	bpl.s	*+4		; skip neg
	neg.w	d3		; abs

	; X grid cell
	moveq	#0, d4
	move.b	obRadius(a0), d4
	sub.w	d0, d4
	asl.w	#3, d4		; to 13.3
	add.w	obX(a0), d4

	and.w	#$FFC0, d4	; truncate to grid cell

	; Chunk X offset
	move	#$F800, d7	; FFE0<<6
	and.w	d4, d7
	asr.w	#4, d7		; 6 - 2
	adda.w	d7, a2

	; X offset inside chunk
	move	#$7C0, d7	; 1F<<6
	and.w	d4, d7
	asr.w	#6, d7		; to pixels, to patterns

	move.l	(a2), d6
	btst.l	d7, d6
	beq.s	@continue	; free tile, skip collision calculation

	; clamp to pattern
	move.w	obX(a0), d2
	clampToGrid.w d2, d4	; d2 = closest point X

				; free: d4, d6, d7

	; X diff
	sub.w	obX(a0), d2
	move.w	d2, d4		; d4 = X diff
	bpl.s	*+4		; skip neg
	neg.w	d2		; abs

	; Check if really collides
	; Calculate displacement

	approxlen d2, d3	; d2 is length now
	beq.s	@continue	; d2 is zero; avoid division by zero

				; free: d6, d7

	moveq	#0, d6
	move.b	obRadius(a0), d6
	asl.w	#3, d6		; to 13.3

	cmp.w	d6, d2		; if d2 >= radius then continue
	bge.s	@continue

	sub.w	d2, d6		; displacement
	swap	d6		; 13.19
	divu	d2, d6		; 0.16
				; d6 = displacement / approxlen

	; X
	muls	d6, d4		; 13.19
	swap	d4		; 13.3
	sub.w	d4, obX(a0)

	; Y
	muls	d6, d5		; 13.19
	swap	d5		; 13.3
	sub.w	d5, obY(a0)

@continue
	; loop
	subq.w	#1<<3, d0
	bpl	@xLoop

	subq.w	#1<<3, d1
	bpl	@yLoop

@end
	rts
	MODEND
