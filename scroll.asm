; handles map scrolling and loading when needed

initScrolling
	setVDPRegister 11, %00000000	; scroll

; input:
; d6 level index
; trash:
; a3, d5, d6, d7
loadLevel
	lea.l	levelDescriptions, a3
	mulu.w	#levelDesc, d6

	move.l	pattern(a3, d6.w), d5

	clr.l	d7
	move.w	patternLen(a3, d6.w), d7
	jsr allocVRAM	; d6 vram address, d7 allocated bytes
	move.w	d6, levelVRAMAddress
	
	lsr.l #1, d7	; bytes to words
	jsr _queueDMATransfer
	rts

updateLevel
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