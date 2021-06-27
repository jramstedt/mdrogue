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
	lea.l	(a3, d6.w), a1

; load palette
	setVDPAutoIncrement 2
	setVDPWriteAddressCRAM 0

	move.l	lvlPalette(a1), a0
	bsr	copyPalette

; load patterns
	move.l	lvlPattern(a1), d5

	moveq	#0,	d7
	move.w	lvlPatternLen(a1), d7
	jsr	allocVRAM	; d6 vram address, d7 allocated bytes
	move.w	d6, levelVRAMAddress

	lsr.l	d7	; bytes to words
	jsr	_queueDMATransfer

	; TODO better filling. 
	lea.l	mainCamera, a0
	move.l	#0, camX(a0)		; clears x and y
	move.l	#0, camXprev(a0)	; clears x and y

lc = 0
	REPT 32
	copyRowToVram a1, a0, 0, lc
lc = lc+8
	ENDR

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
	move.w	lvlPatternLen(a3, d7.w), d7
	jsr	freeVRAM
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

@checkX
	move.w	camXprev(a0), d0
	and.w	#$FFF8, d0
	move.w	camX(a0), d2
	and.w	#$FFF8, d2
	cmp.w	d0, d2
	beq	@checkY	; no cell boundaries crossed
	bmi	@leftBorder

@rightBorder
	MODULE
	copyColumnToVram a1, a0, 320, 0
	MODEND

	bra	@checkY

@leftBorder
	MODULE
	copyColumnToVram a1, a0, 0, 0
	MODEND
	
	bra	@checkY

@checkY
	move.w	camYprev(a0), d1
	and.w	#$FFF8, d1
	move.w	camY(a0), d2
	and.w	#$FFF8, d2
	cmp.w	d1, d2
	beq	@exit	; no cell boundaries crossed
	bmi	@topBorder

@bottomBorder
	MODULE
	copyRowToVram a1, a0, 0, 224
	MODEND

	bra	@exit

@topBorder
	MODULE
	copyRowToVram a1, a0, 0, 0
	MODEND

	bra	@exit

@exit
	move.l	camX(a0), camXprev(a0)	; copies both x and y
	movem.l	(sp)+, d0-d7/a0-a6
	rts

updatePlaneScrollToCamera
	lea.l	mainCamera, a0

	; we are using fullscreen scroll, set both planes.
	setVDPAutoIncrement 2

	setVDPWriteAddressVSRAM 0
	move.w	#0, vdp_data
	move.w	camY(a0), vdp_data

	move.w	camX(a0), d7
	neg.w	d7
	and.w	#$1FF, d7

	setVDPWriteAddressVRAM vdp_map_hst
	move.w	#0, vdp_data
	move.w	d7, vdp_data
	rts