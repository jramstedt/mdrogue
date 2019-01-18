	include 'init.asm'
	include 'timing.asm'
	include 'vram.asm'

	include 'font.asm'
	
	include 'scroll.asm'

	include 'fixedpoint.asm'

	include 'objects/objecttable.asm'
	include 'objects/objects.asm'

	include 'objects/01player.asm'

__main
	move.l	#$0, d6
	move.l	#vdp_map_ant/sizePattern, d7
	jsr	freeVRAM

	reserveVRAM #0, #1	; keep first block empty
	reserveVRAM #vdp_map_ant, #(64*32*sizeWord/sizePattern)
	;reserveVRAM #vdp_map_wnt, #(32/sizePattern)
	reserveVRAM #vdp_map_bnt, #(64*32*sizeWord/sizePattern)
	reserveVRAM #vdp_map_sat, #(80*sizeSpriteDesc/sizePattern)
	;reserveVRAM #vdp_map_hst, #(32*8*sizeWord*2/sizePattern)
	reserveVRAM #vdp_map_hst, #1

	jsr	initDMAQueue

	move.l	#0, d6
	jsr	loadLevel

	allocAndQueueDMA fontPatterns, fontTilemap, fontVRAMAddress

	;queueDMATransfer #testLevelTilemap, #vdp_map_bnt, #(64*32)

	jsr	findFreeObject
	move.b	#$10, obClass(a2)
	
	jsr	waitDMAOn

	loadPalette testPalette, 0
	loadPalette testPalette, 1

	lea	testText, a6
	move.l	#$00020002, d7
	jsr	drawFont

	move.w	#vdp_w_reg, d0
	move.b	vdp1r, d0
	or.w	#%101000000, d0	; #1 reg, display on
	move.w	d0, vdp_ctrl

	jsr	initScrolling

gameLoop
	; do input processing
	clr.l	d0
	clr.l	d1

	haltZ80
	move.b	#$40, io_ctrl1  ; enable output
	move.b	#$40, io_data1  ; Select 00CBRLDU
	move.b	#$40, io_ctrl2  ; enable output
	move.b	#$40, io_data2  ; Select 00CBRLDU
	move.b	io_data1, d0    ; Read 00CBRLDU
	swap	d0
	move.b	io_data2, d0    ; Read 00CBRLDU
	move.b	#$00, io_data1  ; select 00SA00DU
	move.b	#$00, io_data2  ; select 00SA00DU
	move.b	io_data1, d1    ; Read 00SA00DU
	swap	d1
	move.b	io_data2, d1    ; Read 00SA00DU
	resumeZ80
	andi.l	#$003F003F, d0	; 00CBRLDU
	andi.l	#$00300030, d1	; 00SA0000
	lsl.l	#2, d1
	or.l	d1, d0
	move.b	d0, pad2State
	swap	d0
	move.b	d0, pad1State

	; do game processing
	jsr	processObjects

	jsr	updateLevel

	jsr	waitVBlankOn	; Wait for blanking to start. Otherwise we will run two or more gameLoops in one frame..

	; do graphics commands
	jsr	processDMAQueue
	
	jsr	waitVBlankOff

	bra	gameLoop

	include 'assets/orc.asm'

	include 'assets/palettes.asm'
	include 'assets/patterns.asm'

	include 'levels/levels.asm'

testText	dc.b	'Aa Bb', $A,'Cc', $D, 'Dd', $A, $D, '!!!!!!!!!!!!', 0

__end
