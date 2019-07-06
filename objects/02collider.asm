objCollider
	moveq	#0, d0
	move.b	obState(a0), d0	; a0 is object address
	move.w	@routineJmpTable(pc,d0.w), d1
	jmp	@routineJmpTable(pc,d1.w)

@routineJmpTable
	dc.w	@main-@routineJmpTable
	dc.w	@display-@routineJmpTable

@main ; inits the object
	addq.b	#1<<1, obState(a0)	; set object state to @display
	move.w	#$0000, obRender(a0)

	move.w	#80<<3, obX(a0)
	move.w	#120<<3, obY(a0)

	moveq.l	#0, d6
	moveq.l	#0, d7
	move.b	obRadius(a0), d7
	lsr.b	#2, d7
	addx.b	d6, d7
	sub.b	#1, d7
	mulu.w	#$1000, d7

	move.w	d7, obAnim(a0)
	move.b	#0, obFrameTime(a0)


	move.l	#4*4, d7 ; hard coded for one sprite
	jsr	allocVRAM
	lsr.w	#5, d6		; address to pattern number
	or.w	d6, obVRAM(a0)

	rts

@input
	; TODO set velocity
	btst	#0, pad1State
	seq	d0
	andi	#1<<3|3, d0
	sub	d0, obY(a0)

	btst	#1, pad1State
	seq	d0
	andi	#1<<3|3, d0
	add	d0, obY(a0)

	btst	#2, pad1State
	seq	d0
	andi	#1<<3|3, d0
	sub	d0, obX(a0)

	btst	#3, pad1State
	seq	d0
	andi	#1<<3|3, d0
	add	d0, obX(a0)

@display
	;move	#aniOrc, a6
	;jsr	animateSprite

	move	#spritesCol, a6
	jsr	displaySprite

	rts

@delete
	move.w	obVRAM(a0), d6
	lsl.w	#5, d6		; pattern number to address
	move.l	#4*4, d7
	jsr	freeVRAM

	jsr	deleteObject

	rts