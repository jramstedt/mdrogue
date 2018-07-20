	include 'init.asm'
	include 'timing.asm'
	include 'vram.asm'

	include 'font.asm'

	include 'objects/objecttable.asm'
	include 'objects/objects.asm'

	include 'objects/01player.asm'
	
__main
	move.l #$0, d6
	move.l #vdp_map_ant/sizePattern, d7
	jsr freeVRAM

	reserveVRAM	#0, #1	; keep first block empty
	reserveVRAM	#vdp_map_ant, #(64*32*sizeWord/sizePattern)
	;reserveVRAM	#vdp_map_wnt, #(32/sizePattern)
	reserveVRAM	#vdp_map_bnt, #(64*32*sizeWord/sizePattern)
	reserveVRAM	#vdp_map_sat, #(80*sizeSpriteDesc/sizePattern)
	;reserveVRAM	#vdp_map_hst, #(32*8*sizeWord*2/sizePattern)
	reserveVRAM	#vdp_map_hst, #1

	jsr initDMAQueue

	allocAndQueueDMA testLevelPatterns, testLevelPatternsEnd, levelVRAMAddress
	allocAndQueueDMA fontPatterns, fontTilemap, fontVRAMAddress

	queueDMATransfer #testLevelTilemap, #vdp_map_bnt, #(64*32)

	jsr findFreeObject
	move.b	#$10, obClass(a2)

	; We could check that DMA is finished here if needed. Currently initialization takes enough cycles for DMA to finish.
	jsr waitDMAOn

	loadPalette testPalette, 0
	loadPalette testPalette, 1
	
	;loadPatterns testPattern, $0, 1
	;loadPatterns fontPatterns, $0, fontStripe*fontRows

	setVDPRegister 11, %00000111	; scroll

	lea	testText, a6
	move.l #$00020002, d7
	jsr drawFont

gameLoop
	; do input processing

	; do game processing
	jsr	processObjects

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

	;jsr waitVBlankOn

	; do graphics commands
	setVDPAutoIncrement 2
	jsr processDMAQueue
	
	jsr waitVBlankOff
	jsr waitDMAOn

	bra gameLoop

	include 'assets/orc.asm'

	include 'assets/palettes.asm'
	include 'assets/patterns.asm'

testText	dc.b	'Aa Bb', $A,'Cc', $D, 'Dd', $A, $D, '!!!!!!!!!!!!', 0

__end