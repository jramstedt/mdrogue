objPlayer	MODULE
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
	addq.b	#1<<1, obState(a0)	; set object state to @input
	move.w	#$0800, obRender(a0)
	move.b	#8, obRadius(a0)
	move.b	#1, obPhysics(a0)
	move.b	#$1F, obCollision(a0)

	move.w	#160<<3, obX(a0)
	move.w	#120<<3, obY(a0)

	move.w	#$1000, obAnim(a0)
	move.b	#0, obFrameTime(a0)

	move.l	#4*4, d7 ; hard coded for one sprite
	jsr	allocVRAM
	lsr.w	#5, d6		; address to pattern number
	or.w	d6, obVRAM(a0)

	move.b	#0, obClassData(a0)

@input
	; TODO set velocity
	btst	#0, pad1State
	seq	d0
	andi	#1<<3|3, d0
	sub.w	d0, obY(a0)

	btst	#1, pad1State
	seq	d0
	andi	#1<<3|3, d0
	add.w	d0, obY(a0)

	btst	#2, pad1State
	seq	d0
	andi	#1<<3|3, d0
	sub.w	d0, obX(a0)

	btst	#3, pad1State
	seq	d0
	andi	#1<<3|3, d0
	add.w	d0, obX(a0)

	jsr collideWithLevel

	; can shoot?
	tst	obClassData(a0)
	beq	@shoot

	sub.b	#1, obClassData(a0)
	bne	@display

@shoot	btst	#6, pad1State
	bne	@display

	; shoot
	jsr	findFreeObject
	move.b	#(idBullet<<4)|0, obClass(a2)
	move.b	#8, obRadius(a2)
	move.b	#1, obPhysics(a2)
	move.b	#$42, obCollision(a2)

	move.w	obX(a0), d0
	move.w	d0, obX(a2)

	move.w	obY(a0), d0
	move.w	d0, obY(a2)

	move.w	#1<<3|3, obVelX(a2)
	move.w	#0, obVelY(a2)

	move.b	#10, obClassData(a0)

@display
	; update main camera to player coordinates!
	
	lea	obX(a0), a1
	;vrotate a1, #-1&$FF

	;varctan a1, d2
	;vcpsign	a1, a1

	;moveq	#126, d3
	;moveq	#67, d4
	;approxlen d3, d4

	lea.l	mainCamera, a2
	moveq.l	#0, d2

	move.w	obX(a0), d3
	asr.w	#3, d3
	addx.w	d2, d3
	sub.w	#160, d3	; move offset by half screen width
	move.w	d3, camX(a2)

	move.w	obY(a0), d3
	asr.w	#3, d3
	addx.w	d2, d3
	sub.w	#112, d3	; move offset by half screen height
	move.w	d3, camY(a2)

	;move.l	obX(a0), d1	; XXXX YYYY
	;and.l	#$FFF8FFF8, d1
	;lsr.l	#3, d1		; convert to full pixels
	;move.l	d1, camX(a2)

	move	#aniOrc, a6
	jsr	animateSprite

	move	#spritesOrc, a6
	jsr	displaySprite

	rts

@delete
	move.w	obVRAM(a0), d6
	lsl.w	#5, d6		; pattern number to address
	move.l	#4*4, d7
	jsr	freeVRAM

	jsr	deleteObject

	rts
	
	MODEND