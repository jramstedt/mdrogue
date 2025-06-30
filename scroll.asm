	include 'scrollutils.asm'

; handles map scrolling and loading when needed

initScrolling	MODULE
	setVDPRegister 11, %00000000, vdp_ctrl	; scroll
	rts
	MODEND

; input:
; d6 level index
; trash:
; a3, d5, d6, d7
loadLevel	MODULE
	mulu.w	#levelDesc, d6
	lea.l	levelDescriptions, a3
	lea.l	(a3, d6.w), a1
	move.l	a1, loadedLevelAddress

; load palette
	setVDPAutoIncrement 2, vdp_ctrl
	setVDPWriteAddressCRAM 0, vdp_ctrl

	move.l	lvlPalette(a1), a0
	bsr	copyPalette

; load patterns
	move.l	lvlPattern(a1), d5

	moveq	#0, d7
	move.w	lvlPatternLen(a1), d7
	jsr	allocVRAM	; d6 vram address, d7 allocated bytes
	move.w	d6, levelVRAMAddress

	lsr.w	d7	; bytes to words
	jsr	_queueDMATransfer

	; TODO better filling. 
	lea.l	mainCamera, a0
	move.l	#0, camX(a0)		; clears x and y
	move.l	#0, camXprev(a0)	; clears x and y

;lc = 0
;	REPT 32
;	; copyRowToVram a1, a0, 0, lc, 'a'
;	; copyRowToVram a1, a0, 0, lc, 'b'
;lc = lc+8
;	ENDR

	rts
	MODEND

; input:
; trash:
; a3, d6, d7
unloadLevel	MODULE
	move.l	levelVRAMAddress, d6
	move.l	(loadedLevelAddress), a3
	move.w	lvlPatternLen(a3), d7
	jsr	freeVRAM
	rts
	MODEND

;
updateLevel	MODULE
	movem.l	d0-d7/a0-a3, -(sp)

	lea.l	mainCamera, a0
	move.l	(loadedLevelAddress), a1

	moveq	#0, d0
	moveq	#0, d1

.checkX
	move.w	camXprev(a0), d0
	and.w	#$FFF8, d0
	move.w	camX(a0), d2
	and.w	#$FFF8, d2
	cmp.w	d0, d2
	beq	.checkY	; no cell boundaries crossed
	bmi	.leftBorder

.rightBorder
	copyColumnToVram a1, a0, 320, 0, 'a'
	copyColumnToVram a1, a0, 320, 0, 'b'

	bra	.checkY

.leftBorder
	copyColumnToVram a1, a0, 0, 0, 'a'
	copyColumnToVram a1, a0, 0, 0, 'b'
	
	bra	.checkY

.checkY
	move.w	camYprev(a0), d1
	and.w	#$FFF8, d1
	move.w	camY(a0), d2
	and.w	#$FFF8, d2
	cmp.w	d1, d2
	beq	.exit	; no cell boundaries crossed
	bmi	.topBorder

.bottomBorder
	moveq	#0, d3
	copyRowToVram a1, a0, 0, 224, 'a'
	copyRowToVram a1, a0, 0, 224, 'b'

	bra	.exit

.topBorder
	moveq	#0, d3
	copyRowToVram a1, a0, 0, 0, 'a'
	copyRowToVram a1, a0, 0, 0, 'b'

	bra	.exit

.exit
	move.l	camX(a0), camXprev(a0)	; copies both x and y
	movem.l	(sp)+, d0-d7/a0-a3
	rts
	MODEND

updatePlaneScrollToCamera	MODULE
	lea.l	mainCamera, a0
	
	lea.l	vdp_ctrl, a3
	lea.l	vdp_data, a4

	; we are using fullscreen scroll, set both planes.
	setVDPAutoIncrement 2, (a3)

	setVDPWriteAddressVSRAM 0, (a3)
	move.w	camY(a0), (a4)
	move.w	camY(a0), (a4)

	move.w	camX(a0), d7
	neg.w	d7
	and.w	#$1FF, d7

	setVDPWriteAddressVRAM vdp_map_hst, (a3)
	move.w	d7, (a4)
	move.w	d7, (a4)
	rts
	MODEND
