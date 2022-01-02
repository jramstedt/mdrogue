objBullet	MODULE
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

	move.w	#$1000, obAnim(a0)
	move.b	#0, obFrameTime(a0)

	move.l	#4, d7 ; hard coded for one sprite
	jsr	allocVRAM
	lsr.w	#5, d6		; address to pattern number
	or.w	d6, obVRAM(a0)

	move.b	#50, obClassData(a0)

	rts

@display
	sub.b	#1, obClassData(a0)
	beq	@delete

	move.w	obVelX(a0), d0
	add.w	d0, obX(a0)

	move.w	obVelY(a0), d0
	add.w	d0, obY(a0)

	movem.w	obX(a0), d0/d1
	jsr	levelCollision
	bne	@delete

	move	#spritesCol, a6
	jsr	displaySprite

	rts

@delete
	move.w	obVRAM(a0), d6
	lsl.w	#5, d6		; pattern number to address
	move.l	#4, d7
	jsr	freeVRAM

	jsr	deleteObject

	rts

	MODEND