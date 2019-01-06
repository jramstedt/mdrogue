	include 'scrollutils.asm'

; handles map scrolling and loading when needed

initScrolling
	setVDPRegister 11, %00000000	; scroll
	rts

; input:
; d6 level index
; trash:
; a3, d5, d6, d7
loadLevel
	move.b	d6, loadedLevelIndex
	mulu.w	#levelDesc, d6

	lea.l	levelDescriptions, a3
	
	move.l	pattern(a3, d6.w), d5

	moveq	#0,	d7
	move.w	patternLen(a3, d6.w), d7
	jsr allocVRAM	; d6 vram address, d7 allocated bytes
	move.w	d6, levelVRAMAddress
	
	lsr.l #1, d7	; bytes to words
	jsr _queueDMATransfer

	lea.l	mainCamera, a0
	move.w	#1024, camX(a0)
	move.w	#512, camY(a0)

	rts

; input:
; trash:
; a3, d6, d7
unloadLevel
	move.l	levelVRAMAddress, d6

	lea.l	levelDescriptions, a3
	moveq	#0,	d7
	move.b	loadedLevelIndex, d7
	mulu.w	#levelDesc, d7
	move.w	patternLen(a3, d7.w), d7
	jsr freeVRAM
	rts

updateLevel
	movem.l	d0-d7/a0-a6, -(sp)

	lea.l	mainCamera, a0
	lea.l	levelDescriptions, a1

	clr.l	d0
	move.b	loadedLevelIndex, d0
	mulu.w	#levelDesc, d0
	adda.l	d0, a1	; a1 is now offset to correct level description

	clr.l	d0
	clr.l	d1
	move.w  camX(a0), d0
	move.w  camY(a0), d1
	bsr	updateCamera

@checkX
	move.w	d0, d6
	move.w  camX(a0), d7
	and.w	#$FFF8, d6
	and.w	#$FFF8, d7

	cmp.w	d6, d7
	beq		@checkY	; no cell boundaries crossed
	bmi		@leftBorder

@rightBorder
	MODULE
	copyColumnToVram a1, a0, 320, 0
	MODEND

	bra @checkY

@leftBorder
	MODULE
	copyColumnToVram a1, a0, 0, 0
	MODEND
	
	bra @checkY

@checkY
	move.w	d1, d6
	move.w  camY(a0), d7
	and.w	#$FFF8, d6
	and.w	#$FFF8, d7

	cmp.w	d6, d7
	beq		@exit	; no cell boundaries crossed
	bmi		@topBorder

@bottomBorder
	MODULE
	copyRowToVram a1, a0, 0, 224
	MODEND

	bra @exit

@topBorder
	MODULE
	copyRowToVram a1, a0, 0, 0
	MODEND

	bra @exit

@exit
	movem.l	(sp)+, d0-d7/a0-a6
	rts

updateCamera
	;sub.w	#160, d6	; half of H40 pixels
	;sub.w	#112, d7	; half of V28 pixels

	add.w	#-$0002, camX(a0) ; one pixel per frame
	;move.w	#320, camX(a0)
	add.w	#-$0001, camY(a0) ; one pixel per frame
	;move.w	#256, camY(a0)

	; we are using fullscreen scroll, set both planes.
	setVDPAutoIncrement 2
	setVDPWriteAddressVSRAM 0
	move.w #0, vdp_data
	move.w camY(a0), vdp_data

	move.l	#0, d7
	move	camX(a0), d7
	neg		d7
	and.l	#$1FF, d7

	setVDPAutoIncrement 2
	setVDPWriteAddressVRAM vdp_map_hst
	move.w #0, vdp_data
	move.w d7, vdp_data

	rts

; not used testcode
	; Test horizontal scrolling
	setVDPAutoIncrement 2
	setVDPWriteAddressVRAM vdp_map_hst

	move.l #255, d0
	move.l vblank_counter, d1
@setHScrollLoop
	
	move.l d1, vdp_data
	;addq.l #1, d1
	dbra d0, @setHScrollLoop

	; Test vertical scrolling
	setVDPAutoIncrement 4
	setVDPWriteAddressVSRAM 2

	move.l #19, d0
	move.l #0, d1
@setVScrollLoop
	move.l vblank_counter, d1
	move.w d1, vdp_data
	;addq.l #1, d1
	dbra d0, @setVScrollLoop

	rts
