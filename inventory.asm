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

	jsr	calculateStats

	lea	playerStatus,a2
	lea	playerStats,a3
	lea	playerInventory,a4
	lea	items,a5
	lea	parchmentTilemap,a1

	; Build full string and draw it? btos can't add null chars!

	clr	d0

	; Health
	; Label
	calc32x64pos 18,9,vdp_map_bnt,uiVRAMAddress,d2
	lea	strHealth,a0
	jsr	draw8x8Text
	; current
	add32x64pos 5,0,d2
	move.b	plrHealth(a2),d0
	lea	textScrap,a0
	jsr	btos
	jsr	draw8x8Text
	; Max
	add32x64pos 4,0,d2
	move.b	plrMaxHealth(a3),d0
	jsr	btos
	jsr	draw8x8Text

	; Mana
	; Label
	calc32x64pos 18,10,vdp_map_bnt,uiVRAMAddress,d2
	lea	strMana,a0
	jsr	draw8x8Text
	; current
	add32x64pos 5,0,d2
	move.b	plrMana(a2),d0
	lea	textScrap,a0
	jsr	btos
	jsr	draw8x8Text
	; Max
	add32x64pos 4,0,d2
	move.b	plrMaxMana(a3),d0
	jsr	btos
	jsr	draw8x8Text

	; Load protection and then decrement slot protections
	clr.l	d3
	move.b	plrProtection(a3),d3

	; Armor
	; Head
	; Label
	calc32x64pos 18,11,vdp_map_bnt,uiVRAMAddress,d2
	lea	strHead,a0
	jsr	draw8x8Text
	; Value
	add32x64pos 9,0,d2
	move.b	slotHead(a4),d0
	lsl.w	#3,d0
	move.b	(priB,a5,d0.w),d0	; TODO what if this is not protect?
	asr.b	#3,d0
	sub.b	d0,d3			; Subs from total protection
	lea	textScrap,a0
	jsr	btos
	jsr	draw8x8Text

	; Chest
	; Label
	calc32x64pos 18,12,vdp_map_bnt,uiVRAMAddress,d2
	lea	strChest,a0
	jsr	draw8x8Text
	; Value
	add32x64pos 9,0,d2
	move.b	slotTorso(a4),d0
	lsl.w	#3,d0
	move.b	(priB,a5,d0.w),d0
	asr.b	#3,d0
	sub.b	d0,d3
	lea	textScrap,a0
	jsr	btos
	jsr	draw8x8Text

	; Legs
	; Label
	calc32x64pos 18,13,vdp_map_bnt,uiVRAMAddress,d2
	lea	strLegs,a0
	jsr	draw8x8Text
	; Value
	add32x64pos 9,0,d2
	move.b	slotLegs(a4),d0
	lsl.w	#3,d0
	move.b	(priB,a5,d0.w),d0
	asr.b	#3,d0
	sub.b	d0,d3
	lea	textScrap,a0
	jsr	btos
	jsr	draw8x8Text

	; Protection
	; Label
	calc32x64pos 18,14,vdp_map_bnt,uiVRAMAddress,d2
	lea	strProtection,a0
	jsr	draw8x8Text
	add32x64pos 9,0,d2
	move.b  d3,d0
	lea	textScrap,a0
	jsr	btos
	jsr	draw8x8Text

	; Restore
	; Label
	calc32x64pos 18,15,vdp_map_bnt,uiVRAMAddress,d2
	lea	strRestore,a0
	jsr	draw8x8Text
	add32x64pos 9,0,d2
	move.b	plrRestore(a3),d0
	lea	textScrap,a0
	jsr	btos
	jsr	draw8x8Text

	; Damage
	; Melee
	; Label
	calc32x64pos 18,16,vdp_map_bnt,uiVRAMAddress,d2
	lea	strDmgMelee,a0
	jsr	draw8x8Text
	add32x64pos 9,0,d2
	move.b	plrDmgMelee(a3),d0
	lea	textScrap,a0
	jsr	btos
	jsr	draw8x8Text

	; Melee
	; Label
	calc32x64pos 18,17,vdp_map_bnt,uiVRAMAddress,d2
	lea	strDmgMagic,a0
	jsr	draw8x8Text
	add32x64pos 9,0,d2
	move.b	plrDmgMagic(a3),d0
	lea	textScrap,a0
	jsr	btos
	jsr	draw8x8Text

	; Effect
	calc32x64pos 18,18,vdp_map_bnt,uiVRAMAddress,d2
	move.b	plrEffects(a3),d3
	beq	.fxEnd

	lea	strFx,a0
	move	#5,d4
	dbra	d4,.fxLoop

.nextStr
.char
	move.b	(a0)+,d0	; Read character
	bne	.char		; Until null
	dbra	d4,.fxLoop
	bra	.fxEnd

.fxLoop
	lsr.b	d3
	bcc	.nextStr
	jsr	draw8x8Text
	add32x64pos 0,1,d2
	dbra	d4,.fxLoop
	bra	.fxEnd

.fxEnd

	; Borders

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
	calc32x64pos 31,9,vdp_map_ant,uiVRAMAddress,d2
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

	; Help
	calc32x64pos 25,24,vdp_map_ant,uiVRAMAddress,d2
	lea	strHelp,a0
	lea	parchmentTilemap,a1
	jsr	draw8x8Text

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

strHealth	dc.b	'Life XXX/',0
strMana		dc.b	'Mana XXX/',0
strHead		dc.b	'AR Head  ',0
strChest	dc.b	'   Chest ',0
strLegs		dc.b	'   Legs  ',0
strProtection	dc.b	'Protect +',0
strRestore	dc.b	'Restore +',0
strDmgMelee	dc.b	'DR Melee ',0
strDmgMagic	dc.b	'   Magic ',0

strFx
strFxLevitation	dc.b	'Levitation',0
strFx1		dc.b	'Missing 1',0
strFx2		dc.b	'Missing 2',0
strFx3		dc.b	'Missing 3',0
strFx4		dc.b	'Missing 4',0

strHelp		dc.b	'A Switch / Use',$A,$D,'B Drop',$A,$D,'C Scrap',0

	even
