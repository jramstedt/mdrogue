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
	beq	\skip	; approxlen is zero, skip detection 
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
		swap	d4			; 13.3
		add.w	d4, obX(a1)

		; Y axis
		sub.w	obY(a1), d2		; d2 = dy = y1 - y2
		move.w	d2, d4			; d4 = dy
		
		muls	d6, d2			; d2 = sy 13.19
		swap	d2			; 13.3
		add.w	d2, obY(a0)

		muls	d7, d4			; d2 = ty 13.19
		swap	d4			; 13.3
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

	lea.l	objectCollisionHandlers-sizeWord.w, a4	; class start at 1, decrement address by one word

	; Source
	move.b	obClass(a0), d1
	andi.w	#$00F0, d1				; mask class
	lsr.b	#3, d1					; class to word pointer
	move.w	(a4, d1.w), a2				; load object code address

	; Target
	move.b	obClass(a1), d2
	andi.w	#$00F0, d2				; mask class
	lsr.b	#3, d2					; class to word pointer
	move.w	(a4, d2.w), a3				; load object code address

	movem	d0-d7/a0-a6, -(sp)
	jsr	(a2)					; jump to object code
	exg	a0, a1
	jsr	(a3)
	movem	(sp)+, d0-d7/a0-a6

	ENDM

; Checks collisions by starting outer iterator from second node (source).
; Inner iterator checks each node against source node until source node is reached.
processPhysicObjects	MODULE
	movem	a5-a6, -(sp)

	lea.l	hiGameObjectsFirst, a6
	tst.w	(a6)			; is empty?
	beq.s	.exit

	movea.w	llNext(a6), a6		; load first node, will be skipped

.sourceLoop
	tst.w	llNext(a6)		; is last?
	beq.s	.exit

	movea.w	llNext(a6), a6		; next node
	movea.l	llPtr(a6), a0		; a0 is game object

	tst.b	obClass(a0)
	beq.s	.sourceLoop

	move.w	obPhysics(a0), d0	; obPhysics on upper byte, obCollision on lower
	lsr.b	#4, d0			; object collision groups to masks

	lea.l	hiGameObjectsFirst, a5

.targetLoop
	movea.w	llNext(a5), a5		; next node

	cmpa.w	a6, a5			; reached source?
	beq.s	.sourceLoop

	movea.l	llPtr(a5), a1		; a1 is game object

	tst.b	obClass(a1)
	beq.s	.targetLoop

	move.w	obPhysics(a1), d3	; obPhysics on upper byte, obCollision on lower
	and.b	d0, d3			; test group against mask, if not matched skip.
	beq.s	.targetLoop

	andi.w	#$0100, d3		; mask kinematic only
	beq.s	.targetDynamic
	and.w	d0, d3			; test if both kinematic
	bne.s	.targetLoop

	bra	.targetKinematic

.exit
	movem	(sp)+, a5-a6
	rts

.targetDynamic
	btst	#8, d0
	beq	.dtod	; both dynamic

	; if target dynamic bounce target
	calculateCollision 'ktod', .targetLoop
	bra	.targetLoop
	
	; if both dynamic calculate bounce (radius ratio)
.dtod	calculateCollision 'dtod', .targetLoop
	bra	.targetLoop

.targetKinematic
	; if source dynamic bounce source
	calculateCollision 'dtok', .targetLoop
	bra	.targetLoop

	MODEND

;
; Checks if point is in tile with collision type set
;
; input
;  d0 X
;  d1 Y
; trashes
;  d0 d1 d2 a1
levelCollision	MODULE
	move.l	(loadedLevelAddress), a1
	movea.l	lvlCollision(a1), a2

	; Yp = y / 8
	; Yc = Yp / 32
	; Yi = Yp % 32

	; Y
	asr.w	#3+3-4, d1		; >>3 to pixels, >>3 to patterns, <<4 to 16 bytes per row
					; 32 nibbles = 16bytes in row

	; Y offset inside chunk
	move.w	#$01F0, d2
	and.w	d1, d2
	adda.w	d2, a2
	
	and.w	#$FE00, d1		; truncate to chunk start
	moveq	#0, d2
	move.b	lvlWidth(a1), d2
	mulu	d2, d1
	adda.w	d1, a2

	; Xp = x / 8
	; Xc = Xp / 32
	; Xi = Xp % 32

	moveq	#$70, d1

	; X
	asr.w	#3+3+1, d0		; to pixels, to patterns, to nibbles (two collision tiles per byte)
	bcc.s	*+4			; is X even, skip odd masking
	moveq	#$07, d1

	; X offset inside chunk
	moveq	#$0F, d2
	and.b	d0, d2
	
	and.w	#$FFF0, d0		; truncate to chunk start
	lsl.w	#9-4, d0
	adda.w	d0, a2
	
	; Check if collision
	move.b	(a2, d2.w), d0
	and.b	d1, d0
	rts
	MODEND

; clampToGrid
clampToGrid	MACRO	corner, point
	LOCAL clampMax, end
	cmp.\0	\corner, \point
	bgt	clampMax
	move.\0	\corner, \point
	bra	end

clampMax
	add.\0	#1<<6, \corner		; add one full pattern
	cmp.\0	\corner, \point
	blt	end
	move.\0	\corner, \point
end
	ENDM

; a0 obj
; trashes a1, a2, a3, d0, d1, d2, d3, d4, d5, d6, d7
collideWithLevel	MODULE
	movea.l	(loadedLevelAddress), a1

	; ! note
	; d0, d1 loop counters
	; d2, d3 closest point in grid cell
	; d4, d5 diff of object to closest grid point

	moveq	#0, d2
	moveq	#0, d3

	; Y pixels to loop
	moveq	#0, d1
	move.b	obRadius(a0), d1
	add.w	d1, d1			; (*2) to diameter; Y pixels, will be decremented in loop

.yLoop
	; X amount to loop
	moveq	#0, d0
	move.b	obRadius(a0), d0
	add.w	d0, d0			; (*2) to diameter; X pixels, will be decremented in loop

	movea.l	lvlCollision(a1), a2

	; Y grid cell
	moveq	#0, d5
	move.b	obRadius(a0), d5
	sub.w	d1, d5
	asl.w	#3, d5			; to 13.3
	add.w	obY(a0), d5

	; Position to grid cell
	; Sets data address
	and.w	#$FFC0, d5		; truncate to grid cell
	move.w	d5, d7

	; Y
	asr.w	#3+3-4, d7		; >>3 to pixels, >>3 to patterns, <<4 to 16 bytes per row
					; 32 nibbles = 16bytes in ro

	; Y offset inside chunk
	move.w	#$01F0, d6
	and.w	d7, d6
	adda.w	d6, a2

	; Chunk Y offset
	and.w	#$FE00, d7
	moveq	#0, d6
	move.b	lvlWidth(a1), d6
	mulu	d6, d7
	adda.w	d7, a2

.xLoop
	movea.l	a2, a3

	; X grid cell
	moveq	#0, d4
	move.b	obRadius(a0), d4
	sub.w	d0, d4
	asl.w	#3, d4			; to 13.3
	add.w	obX(a0), d4

	and.w	#$FFC0, d4		; truncate to grid cell
	move.w	d4, d7

	; Mask for collision type

	; X
	asr.w	#3+3+1, d7		; to pixels, to patterns, to nibbles
	scs	d2

	; X offset inside chunk
	moveq	#$0F, d6
	and.b	d7, d6

	; Chunk X offset
	and.w	#$FFF0, d7
	lsl.w	#9-4, d7
	adda.w	d7, a3

	move.b	(a3, d6.w), d6

	move.l	d5, d7			; save d5 to be restored

	tst	d2
	bne.s	.odd

.even	and.b	#$70, d6
	lsr.b	#3, d6
	move.w	.tileHandleTable(pc, d6.w), d6
	jmp	.tileHandleTable(pc, d6.w)

.odd	and.b	#$07, d6
	lsl.b	d6
	move.w	.tileHandleTable(pc, d6.w), d6
	jmp	.tileHandleTable(pc, d6.w)

.tileHandleTable
	dc.w	.continue-.tileHandleTable	; free tile, skip collision calculation
	dc.w	.square-.tileHandleTable
	dc.w	.nwSlope-.tileHandleTable
	dc.w	.neSlope-.tileHandleTable
	dc.w	.seSlope-.tileHandleTable
	dc.w	.swSlope-.tileHandleTable

.nwSlope
	move.w	obX(a0), d2
	move.w	obY(a0), d3

	; p = d2,d3  v = 0,1  w = 1,0
	; t = dot(p - v, w - v) / ||w - v||^2
	; p' = p - v
	; t = p'x + (p'y*-1) >> 1  ==>  t = p'x - p'y >> 1
	; r = v + t*(w-v)

	; p'
	sub.w	d4, d2
	cmp.w	#1<<6, d2
	bgt	.square		; d3 is on right

	sub.w	d5, d3
	cmp.w	#1<<6, d3
	bgt	.square		; d3 is below

	; d5 should actually be bottom of the pattern, but .square wants upper left. Adjust vectors here.
	sub.w	#1<<6, d3
	add.w	#1<<6, d5

	; t
	sub.w	d3, d2
	asr.w	d2

	; r
	move.w	d2, d3		; (v-w)x is 1
	neg.w	d3		; (v-w)y is -1, so negate d3

	add.w	d4, d2
	add.w	d5, d3
	bra	.displace

.neSlope
	move.w	obX(a0), d2
	move.w	obY(a0), d3

	; p = d2,d3  v = 0,0  w = 1,1
	; t = dot(p - v, w - v) / ||w - v||^2
	; p' = p - v
	; t = p'x + p'y >> 1
	; r = v + t*(w-v)

	; p'
	sub.w	d4, d2
	blt.s	.square		; d3 is on left

	sub.w	d5, d3
	cmp.w	#1<<6, d3
	bgt.s	.square		; d3 is below

	; t
	add.w	d3, d2
	asr.w	d2

	; r
	move.w	d2, d3

	add.w	d4, d2
	add.w	d5, d3
	bra.s	.displace

.swSlope
	move.w	obX(a0), d2
	move.w	obY(a0), d3

	; p = d2,d3  v = 0,0  w = 1,1
	; t = dot(p - v, w - v) / ||w - v||^2
	; p' = p - v
	; t = p'x + p'y >> 1
	; r = v + t*(w-v)

	; p'
	sub.w	d5, d3
	blt.s	.square		; d3 is above

	sub.w	d4, d2
	cmp.w	#1<<6, d2
	bgt.s	.square		; d3 is on right

	; t
	add.w	d3, d2
	asr.w	d2

	; r
	move.w	d2, d3

	add.w	d4, d2
	add.w	d5, d3
	bra.s	.displace

.seSlope
	move.w	obX(a0), d2
	move.w	obY(a0), d3

	; p = d2,d3  v = 0,1  w = 1,0
	; t = dot(p - v, w - v) / ||w - v||^2
	; p' = p - v
	; t = p'x + (p'y*-1) >> 1  ==>  t = p'x - p'y >> 1
	; r = v + t*(w-v)

	; p'
	sub.w	d4, d2
	blt.s	.square		; d3 is on left

	sub.w	d5, d3
	blt.s	.square		; d3 is above
	
	; d5 should actually be bottom of the pattern, but .square wants upper left. Adjust vectors here.
	sub.w	#1<<6, d3
	add.w	#1<<6, d5

	; t
	sub.w	d3, d2
	asr.w	d2

	; r
	move.w	d2, d3		; (v-w)x is 1
	neg.w	d3		; (v-w)y is -1, so negate d3

	add.w	d4, d2
	add.w	d5, d3

	bra.s	.displace

.square						; clamp to pattern
	move.w	obY(a0), d3
	clampToGrid.w d5, d3 	; d3 = closest point Y

	move.w	obX(a0), d2
	clampToGrid.w d4, d2	; d2 = closest point X

.displace
	; Y diff
	sub.w	obY(a0), d3
	move.w	d3, d5		; d5 = Y diff
	bpl.s	*+4		; skip neg
	neg.w	d3		; abs

	; X diff
	sub.w	obX(a0), d2
	move.w	d2, d4		; d4 = X diff
	bpl.s	*+4		; skip neg
	neg.w	d2		; abs

	; Check if really collides
	; Calculate displacement

	approxlen d2, d3	; d2 is length now
	beq.s	.continue	; d2 is zero; avoid division by zero

				; free: d3, d6

	move.b	obRadius(a0), d6
	asl.w	#3, d6		; to 13.3

	sub.w	d2, d6		; displacement
	blt.s	.continue	; if d2 >= radius then continue

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

.continue
	move.l	d7, d5			; restore d5

	; loop
	subq.w	#1<<3, d0
	bpl	.xLoop

	subq.w	#1<<3, d1
	bpl	.yLoop

.end
	rts
	MODEND
