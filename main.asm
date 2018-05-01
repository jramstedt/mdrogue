	include 'init.asm'
	include 'memorymap.asm'
	include 'megadrive.asm'
	include 'interrupts.asm'
	include 'timing.asm'
	include 'assets/font.asm'

	include 'objects/objects.asm'

__main
	jsr initDMAQueue

	loadPalette testPalette, 0
	loadPalette testPalette, 2
	
	;loadPatterns testPattern, $0, 1
	;loadPatterns fontPatterns, $0, fontStripe*fontRows

	move.l #fontPatterns, d5
	move.l #0, d6
	move.l #(fontTilemap-fontPatterns)/2, d7
	jsr queueDMATransfer

	setVDPRegister 11, %00000111	; scroll

	lea	testText, a6
	jsr drawFont

gameLoop
	; do input processing

	; do game processing
	jsr	processObjects

	; Test horizontal scrolling
	setVDPAutoIncrement 2
	setVDPWriteAddressVRAM vdp_map_hst

	move.l #255, d0
	move.l #0, d1
@setHScrollLoop
	move.l vblank_counter, d1
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

	jsr waitVBlankOn

	; do graphics commands
	setVDPAutoIncrement 2
	jsr processDMAQueue

	jsr waitVBlankOff
	
	bra gameLoop

	include 'assets/palettes.asm'
	include 'assets/patterns.asm'

testText	dc.b	'Aa Bb Cc', 0
	
	include 'objects/01player.asm'
__end