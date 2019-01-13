objPlayer
	moveq	#0, d0
	move.b	obState(a0), d0	; a0 is object address
	move.w	@routineJmpTable(pc,d0.w), d1
	jmp	@routineJmpTable(pc,d1.w)

@routineJmpTable
	dc.w	@main-@routineJmpTable
	dc.w	@input-@routineJmpTable
	dc.w	@display-@routineJmpTable
	dc.w	@delete-@routineJmpTable

@main ; inits the object
	addq.b	#2, obState(a0)	; set object state to @display
	move.w	#1, obRender(a0)
	move.b	#32, obWidth(a0)
	move.b	#32, obHeight(a0)

	move.w	#$0A0F, obX(a0)
	move.w	#$078F, obY(a0)

	move.w	#$0000, obAnim(a0)
	move.b	#0, obFrameTime(a0)

	move.l	#16, d7 ; hard coded for one sprite
	jsr	allocVRAM
	move.w	d6, obVRAM(a0)

@input
	btst	#0, pad1State
	seq	d0
	andi	#$0023, d0
	sub	d0, obY(a0)

	btst	#1, pad1State
	seq	d0
	andi	#$0023, d0
	add	d0, obY(a0)

	btst	#2, pad1State
	seq	d0
	andi	#$0023, d0
	sub	d0, obX(a0)

	btst	#3, pad1State
	seq	d0
	andi	#$0023, d0
	add	d0, obX(a0)

@display
	;add.w	#$000F, obY(a0) ; 1 / 15 pixel per frame
	; update main camera to player coordinates!
	lea.l	mainCamera, a2

	moveq.l	#0, d2

	move.w	obX(a0), d3
	sub.w	#$0A00, d3	; move offset by half screen width
	asr.w	#4, d3
	addx.w	d2, d3
	move.w	d3, camX(a2)

	move.w	obY(a0), d3
	sub.w	#$0700, d3	; move offset by half screen height
	asr.w	#4, d3
	addx.w	d2, d3
	move.w	d3, camY(a2)

	;move.l	obX(a0), d1	; XXXX YYYY
	;and.l	#$FFF0FFF0, d1
	;lsr.l	#4, d1		; convert to full pixels
	;move.l	d1, camX(a2)

	move	#aniOrc, a6
	jsr	animateSprite

	move	#spritesOrc, a6
	jsr	displaySprite

	rts

@delete
	move.l	obVRAM(a0), d6
	move.l	#16, d7
	jsr	freeVRAM

	jsr	deleteObject

	rts
