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

	; Stats
	jsr	calculateStats

	lea	playerStatus,a2
	lea	playerStats,a3
	lea	playerInventory,a4
	lea	items,a5
	lea	itemsTilemap,a6

	clr.l	d0

	; Slot items

	; \1 slot
	MACRO drawIcon
	move.b	\1(a4),d0
	lsl.w	#3,d0			; Slot descriptor is 8 bytes
	move.w	(gfx,a5,d0.w),d0
	lea	(a6,d0.w),a1
	jsr	draw2x2
	ENDM

	calc32x64pos 1,2,vdp_map_bnt,uiVRAMAddress,d2
	drawIcon slotNeck

	calc32x64pos 14,2,vdp_map_bnt,uiVRAMAddress,d2
	drawIcon slotHead

	calc32x64pos 14,10,vdp_map_bnt,uiVRAMAddress,d2
	drawIcon slotTorso

	calc32x64pos 1,14,vdp_map_bnt,uiVRAMAddress,d2
	drawIcon slotFingerRight

	calc32x64pos 14,14,vdp_map_bnt,uiVRAMAddress,d2
	drawIcon slotFingerLeft

	calc32x64pos 14,18,vdp_map_bnt,uiVRAMAddress,d2
	drawIcon slotLegs

	; TODO Build full string and draw it? btos can't add null chars!

	lea	parchmentTilemap,a1

	; \1 X offset
	; \2 value source, if not set defaults to d0
	MACRO writeValue
	add32x64pos \1,0,d2
	IF NARG>1
	move.b	\2,d0
	ENDIF
	jsr	btos
	jsr	draw8x8Text
	ENDM

	; \1 label address
	; repeat:
	; \+ first value X offset
	; \+ value source
	MACRO writeLabelAndValues
	lea	\+,a0
	jsr	draw8x8Text
	lea	textScrap,a0
	REPT (NARG-1)/2
	writeValue \+,\+
	ENDR
	ENDM

	; Health
	; Label
	calc32x64pos 18,9,vdp_map_bnt,uiVRAMAddress,d2
	writeLabelAndValues strHealth,5,plrHealth(a2),4,plrMaxHealth(a3)

	; Mana
	; Label
	calc32x64pos 18,10,vdp_map_bnt,uiVRAMAddress,d2
	writeLabelAndValues strMana,5,plrMana(a2),4,plrMaxMana(a3)

	; Load protection and then decrement slot protections
	clr.l	d3
	move.b	plrProtection(a3),d3

	; \1 label address
	; \2 value X offset
	; \3 slot
	MACRO writeLabelAndSlotProtection
	lea	\1,a0
	jsr	draw8x8Text

	move.b	\3(a4),d0
	lsl.w	#3,d0			; Slot descriptor is 8 bytes
	move.b	(priB,a5,d0.w),d0	; TODO what if this is not protect?
	asr.b	#3,d0
	sub.b	d0,d3			; Subs from total protection

	lea	textScrap,a0
	writeValue \2
	ENDM

	; Head Armor Rating
	calc32x64pos 18,11,vdp_map_bnt,uiVRAMAddress,d2
	writeLabelAndSlotProtection strHead,9,slotHead
	; Chest Armor Rating
	calc32x64pos 18,12,vdp_map_bnt,uiVRAMAddress,d2
	writeLabelAndSlotProtection strChest,9,slotTorso
	; Legs Armor Rating
	calc32x64pos 18,13,vdp_map_bnt,uiVRAMAddress,d2
	writeLabelAndSlotProtection strLegs,9,slotLegs

	; Protection
	calc32x64pos 18,14,vdp_map_bnt,uiVRAMAddress,d2
	writeLabelAndValues strProtection,9,d3
	; Restore
	calc32x64pos 18,15,vdp_map_bnt,uiVRAMAddress,d2
	writeLabelAndValues strRestore,9,plrRestore(a3)
	; Melee Damage Rating
	calc32x64pos 18,16,vdp_map_bnt,uiVRAMAddress,d2
	writeLabelAndValues strDmgMelee,9,plrDmgMelee(a3)
	; Magic Damage Rating
	calc32x64pos 18,17,vdp_map_bnt,uiVRAMAddress,d2
	writeLabelAndValues strDmgMagic,9,plrDmgMagic(a3)

	; Effect
	calc32x64pos 18,18,vdp_map_bnt,uiVRAMAddress,d2
	move.b	plrEffects(a3),d3
	beq	.fxEnd
	; Loop trough each bit. Draw text if set.
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
	lsr.b	d3		; Gets bit into C
	bcc	.nextStr
	jsr	draw8x8Text	; a0 will be at the start of next strFx string
	add32x64pos 0,1,d2	; Move down for next
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
