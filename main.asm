	include 'init.asm'
	include 'timing.asm'
	include 'vram.asm'

	include 'font.asm'
	
	include 'scroll.asm'

	include 'fixedpoint.asm'
	include 'vector.asm'
	include 'collision.asm'

	include 'objects/objects.asm'
	include 'objects/objecttable.asm'

__main
	move.l	#$0, d6
	move.l	#vdp_map_ant/sizePattern, d7
	jsr	freeVRAM

	; reserveVRAM #0, #1	; keep first block empty
	reserveVRAM #vdp_map_ant, #(64*32*sizeWord/sizePattern)
	reserveVRAM #vdp_map_wnt+(20*32/sizePattern), #(4*32/sizePattern)
	reserveVRAM #vdp_map_bnt, #(64*32*sizeWord/sizePattern)
	reserveVRAM #vdp_map_sat, #(80*sizeSpriteDesc/sizePattern)
	;reserveVRAM #vdp_map_hst, #(32*8*sizeWord*2/sizePattern)
	reserveVRAM #vdp_map_hst, #1

	jsr	initDMAQueue

	; TODO should be loaded later, after menus etc.
	move.l	#0, d6
	jsr	loadLevel

	allocAndQueueDMA fontPatterns, fontTilemap, fontVRAMAddress

	jsr	findFreeObject
	move.b	#$10, obClass(a2)

	jsr	findFreeObject
	move.b	#$20, obClass(a2)
	move.b	#16, obRadius(a2)
	move.b	#0, obPhysics(a2)
	move.b	#$1F, obCollision(a2)

	; loadPalette testPalette, 0
	loadPalette testPalette, 1

	lea	testText, a6
	move.l	#$00160003, d7
	jsr	drawFont

	; process initial DMA queue
	move.w	#vdp_w_reg+%100010100, vdp1rState
	jsr	processDMAQueue

	; start game
	move.w	#vdp_w_reg, d0
	move.b	vdp1r, d0
	or.w	#%101000000, d0	; #1 reg, display on
	move.w	d0, vdp1rState
	move.w	d0, vdp_ctrl

	jsr	initScrolling

	; wait this frame to finish before gameLoop start.
	jsr	waitVBlankOff	; Wait for blanking to start (VBlank is off).
	jsr	waitVBlankOn	; Wait for blanking to stop.

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

	lcg	d0

	; do game processing
	jsr	processObjects
	jsr	processPhysicObjects
	
	; print vertical line of 224/240
	clr.l	d0
	move.w	vdp_hvcnt, d0	; hi = vert, lo = hori
	lsr.w	#8, d0
	lea	textScrap, a0
	jsr	itos

	lea	textScrap, a6
	move.b	#0, 4(a6)
	move.l	#$00140000, d7
	jsr	drawFont

	jsr	waitVBlankOff	; Wait for blanking to start (VBlank is off).

	; do graphics commands
	jsr	updatePlaneScrollToCamera
	jsr	updateLevel
	jsr	processDMAQueue
	
	jsr	waitVBlankOn	; Wait for blanking to stop.

	bra	gameLoop

	include 'assets/orc.asm'
	include 'assets/col.asm'

	include 'assets/palettes.asm'
	include 'assets/patterns.asm'

	include 'levels/levels.asm'

testText	dc.b	'Aa Bb', $A,'Cc', $D, 'Dd', $A, $D, '!!!!!!!!!!!!', 0

; sin cos table in s.15 fp format. MSB is optional sign bit.
sinCosTableLen	equ	256
sinCosTable	incbin	'assets/sincos.bin'

__end
