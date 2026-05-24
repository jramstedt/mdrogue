	include 'init.asm'
	include 'timing.asm'
	include 'vram.asm'

	include 'string.asm'
	include 'planeutils.asm'

__main
	; Enable controllers
	haltZ80
	move.b	#$40,io_ctrl1  ; enable output
	move.b	#$40,io_data1  ; Select 00CBRLDU
	move.b	#$40,io_ctrl2  ; enable output
	move.b	#$40,io_data2  ; Select 00CBRLDU
	resumeZ80

	jmp	openInventory

	jsr	initVRAM
	; reserveVRAM #0,#1	; keep first block empty
	reserveVRAM #vdp_map_ant,#(64*32)
	reserveVRAM #vdp_map_sat,#(80*sizeSpriteDesc/sizeWord)
	reserveVRAM #vdp_map_wnt+(64*20*sizeWord),#(64*8)
	reserveVRAM #vdp_map_bnt,#(64*32)
	;reserveVRAM #vdp_map_hst,#(32*8*2)
	reserveVRAM #vdp_map_hst,#1

	jsr	initDMAQueue

	; Do init stuff
	loadPalette #testPalette,0
	allocAndQueueDMA uiPatterns,uiPatternsEnd,uiVRAMAddress

	calc32x64pos 0,0,vdp_map_ant,uiVRAMAddress,d2
	lea	testText,a0
	lea	(parchmentTilemap+Parchment_res_0_0),a1
	jsr	draw8x8Text

	calc32x64pos 0,3,vdp_map_ant,uiVRAMAddress,d2
	lea	(inventoryTilemap+border2),a1
	move.l	#(5<<16)|5,d3
	jsr	draw9Slice

	; start game
	displayOn vdp_ctrl

	; wait this frame to finish before gameLoop start.
	jsr	waitVBlankOff	; Wait for blanking to start (VBlank is off).
	jsr	waitVBlankOn	; Wait for blanking to stop.

.gameLoop
	; do input processing
	readGamePads pad1State,pad2State

	; step rng
	lcg	d0

	; do game pocessing
	;

	; print vertical line of 224/240
	move.w	vdp_hvcnt,d0	; hi = vert, lo = hori
	lsr.w	#8,d0
	lea	textScrap,a0
	jsr	btos

	calc32x64pos 4,20,vdp_map_wnt,uiVRAMAddress,d2
	lea	parchmentTilemap,a1
	jsr	draw8x8Text


	jsr	waitVBlankOff	; Wait for blanking to start (VBlank is off).

	; do graphics commands
	;
	jsr	processDMAQueue

	jsr	waitVBlankOn	; Wait for blanking to stop.

	bra	.gameLoop

	include 'inventory.asm'
	include 'player.asm'

	; include data here

; sin cos table in s.15 fp format. MSB is optional sign bit.
sinCosTableLen	equ	256
sinCosTable	incbin	'assets/sincos.bin'

testPalette
	dc.w	$0000	; Colour 0 - Transparent
	dc.w	$000E	; Colour 1 - Red
	dc.w	$00E0	; Colour 2 - Green
	dc.w	$0E00	; Colour 3 - Blue
	dc.w	$0000	; Colour 4 - Black
	dc.w	$0EEE	; Colour 5 - White
	dc.w	$00EE	; Colour 6 - Yellow
	dc.w	$008E	; Colour 7 - Orange
	dc.w	$0E0E	; Colour 8 - Pink
	dc.w	$0808	; Colour 9 - Purple
	dc.w	$0444	; Colour A - Dark grey
	dc.w	$0888	; Colour B - Light grey
	dc.w	$0EE0	; Colour C - Turquoise
	dc.w	$000A	; Colour D - Maroon
	dc.w	$0600	; Colour E - Navy blue
	dc.w	$0060	; Colour F - Dark green

; Font
			include	'assets/Parchment-res.asm'
parchmentTilemap	incbin	'assets/Parchment-tilemap.bin'

			include	'assets/Inventory-res.asm'
inventoryTilemap	incbin	'assets/Inventory-tilemap.bin'

			include	'assets/Items-res.asm'
itemsTilemap		incbin	'assets/Items-tilemap.bin'

; UI
uiPal2			incbin	'assets/UI-2.pal'
uiPal3			incbin	'assets/UI-3.pal'
uiPatterns		incbin	'assets/UI-patterns.bin'
uiPatternsEnd

;border1Patterns		incbin 'assets/ui/border1-patterns.bin'
;border1Tilemap		incbin	'assets/ui/border1-tilemap.bin'
;border2Patterns		incbin 'assets/ui/border2-patterns.bin'
;border2Tilemap		incbin	'assets/ui/border2-tilemap.bin'

testText	dc.b	'Aa(Bb)', $A,'Cc', $D, 'Dd', $A, $D, '!!!!!!!!!!!!!!', 0

	include	'itemdata.asm'

__end
