openInventory
	; Disable window plane
	setVDPRegister 17,%00000000,vdp_ctrl
	setVDPRegister 18,%00000000,vdp_ctrl

	jsr	initVRAM
	reserveVRAM #0,#16	; keep first block empty
	reserveVRAM #vdp_map_ant,#(64*32)
	reserveVRAM #vdp_map_sat,#(80*sizeSpriteDesc/sizeWord)
	reserveVRAM #vdp_map_bnt,#(64*32)
	reserveVRAM #vdp_map_hst,#1

	jsr	initDMAQueue

	loadPalette #testPalette,0
	;loadPalette #uiPal2,2
	;loadPalette #uiPal3,3
	allocAndQueueDMA uiPatterns,uiPatternsEnd,uiVRAMAddress

	jsr	processDMAQueue

	displayOn vdp_ctrl
	jsr	waitVBlankOff	; Wait for blanking to start (VBlank is off).
	jsr	waitVBlankOn	; Wait for blanking to stop.

.gameLoop
	readGamePads pad1State,pad2State

	lea	(inventoryTilemap+border2),a1
	move.l	#(2<<16)|2,d3

	; Neck
	calc32x64pos 1,2,vdp_map_ant,uiVRAMAddress,d2
	jsr	draw9Slice

	; Head
	calc32x64pos 14,2,vdp_map_ant,uiVRAMAddress,d2
	jsr	draw9Slice

	; Torso
	calc32x64pos 14,10,vdp_map_ant,uiVRAMAddress,d2
	jsr	draw9Slice

	; Finger Right hand
	calc32x64pos 1,14,vdp_map_ant,uiVRAMAddress,d2
	jsr	draw9Slice

	; Finger Left hand
	calc32x64pos 14,14,vdp_map_ant,uiVRAMAddress,d2
	jsr	draw9Slice

	; Legs
	calc32x64pos 14,18,vdp_map_ant,uiVRAMAddress,d2
	jsr	draw9Slice

	; Info
	move.l	#(6<<16)|12,d3
	calc32x64pos 18,2,vdp_map_ant,uiVRAMAddress,d2
	jsr	draw9Slice

	; Ground
	move.l	#(6<<16)|8,d3
	calc32x64pos 31,2,vdp_map_ant,uiVRAMAddress,d2
	jsr	draw9Slice

	; Backpack
	move.l	#(12<<16)|8,d3
	calc32x64pos 31,10,vdp_map_ant,uiVRAMAddress,d2
	jsr	draw9Slice

	; A
	move.l	#(3<<16)|3,d3
	calc32x64pos 1,24,vdp_map_ant,uiVRAMAddress,d2
	jsr	draw9Slice

	; B
	calc32x64pos 5,24,vdp_map_ant,uiVRAMAddress,d2
	jsr	draw9Slice

	; C
	calc32x64pos 9,24,vdp_map_ant,uiVRAMAddress,d2
	jsr	draw9Slice

	; Actions
	move.l	#(3<<16)|9,d3
	calc32x64pos 14,24,vdp_map_ant,uiVRAMAddress,d2
	jsr	draw9Slice

	; print vertical line of 224/240
	move.w	vdp_hvcnt,d0	; hi = vert, lo = hori
	lsr.w	#8,d0
	lea	textScrap,a0
	jsr	btos

	calc32x64pos 0,0,vdp_map_bnt,uiVRAMAddress,d2
	lea	parchmentTilemap,a1
	jsr	draw8x8Text

	jsr	waitVBlankOff	; Wait for blanking to start (VBlank is off).
	jsr	processDMAQueue
	jsr	waitVBlankOn	; Wait for blanking to stop.
	bra .gameLoop
