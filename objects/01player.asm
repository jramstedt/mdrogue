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
	move.b	#1, obRender(a0)
	move.b	#8, obWidth(a0)
	move.b	#8, obHeight(a0)

@display
	jsr	displaySprite

	rts

@delete
	jsr	deleteObject

	rts