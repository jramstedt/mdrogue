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

		divu	d5, d6			; 0.16
						; d6 = displacement / (radius+radius)

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
processPhysicObjects
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
	bls.s	@sourceLoop

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