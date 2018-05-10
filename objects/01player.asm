objPlayer
	moveq	#0, d0
	move.b	obState(a0), d0	; a0 is object address
	move.w	@routineJmpTable(pc,d0.w), d1
	jmp	@routineJmpTable(pc,d1.w)

@routineJmpTable
	dc.w	@main-@routineJmpTable
	dc.w	@display-@routineJmpTable
	dc.w	@delete-@routineJmpTable

@main ; inits the object
	addq.b	#2, obState(a0)	; set object state to @display
	move.w	#1, obRender(a0)
	move.b	#32, obWidth(a0)
	move.b	#32, obHeight(a0)

	move.b	#0, obAnim(a0)
	move.b	#0, obFrame(a0)
	move.b	#0, obFrameTime(a0)
	move.l	#spritesOrc, obROM(a0)

	move.l	#16, d7 ; hard coded for one sprite
	jsr	allocVRAM
	move.w	d7, obVRAM(a0)

@display
	jsr	displaySprite

	rts

@delete
	move.l obVRAM(a0), d6
	move.l #16, d7
	jsr	freeVRAM

	jsr	deleteObject

	rts