		clrso
uiHot		so.w	1
uiActive	so.w	1
uiListIndex	so.b	1
uiStateSize	equ	__SO

; Pad navigation
;			up,right,down,left
uiA		dc.w	uiFingerRight,uiB,uiNeck,uiBackpack
uiB		dc.w	uiFingerRight,uiC,uiNeck,uiA
uiC		dc.w	uiLegs,uiActions,uiHead,uiB
uiHead		dc.w	uiActions,uiGround,uiTorso,uiNeck
uiNeck		dc.w	uiA,uiHead,uiFingerRight,uiGround
uiTorso		dc.w	uiHead,uiBackpack,uiFingerLeft,uiFingerRight
uiFingerRight	dc.w	uiNeck,uiFingerLeft,uiA,uiBackpack
uiFingerLeft	dc.w	uiTorso,uiBackpack,uiLegs,uiFingerRight
uiLegs		dc.w	uiFingerLeft,uiBackpack,uiActions,uiBackpack
uiGround	dc.w	uiBackpack,uiNeck,uiBackpack,uiHead
uiBackpack	dc.w	uiGround,uiFingerRight,uiGround,uiActions
uiActions	dc.w	uiLegs,uiBackpack,uiHead,uiC

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
	loadPalette #uiPal2,2
	loadPalette #uiPal3,3
	allocAndQueueDMA uiPatterns,uiPatternsEnd,uiVRAMAddress

	jsr	processDMAQueue

	; Test data TODO remove
	move.b	#1,(playerInventory+itemA)
	move.b	#8,(playerInventory+itemB)
	move.b	#9,(playerInventory+itemC)
	move.b	#3,(playerInventory+slotHead)
	move.b	#4,(playerInventory+slotNeck)
	move.b	#5,(playerInventory+slotTorso)
	move.b	#7,(playerInventory+slotFingerRight)
	move.b	#7,(playerInventory+slotFingerLeft)
	move.b	#6,(playerInventory+slotLegs)

	move.b	#2,(playerInventory+backpack)
	move.b	#10,(playerInventory+backpack+1)
	move.b	#1,(playerInventory+backpack+2)
	move.b	#4,(playerInventory+backpack+3)

	move.b	#5,(playerInventory+backpack+4)
	move.b	#6,(playerInventory+backpack+5)
	move.b	#8,(playerInventory+backpack+6)
	move.b	#9,(playerInventory+backpack+7)

	move.w	#uiBackpack,(inventoryUIState+uiHot)

	displayOn vdp_ctrl
	jsr	waitVBlankOff	; Wait for blanking to start (VBlank is off).
	jsr	waitVBlankOn	; Wait for blanking to stop.

.gameLoop
	readGamePads pad1State,pad2State,pad1Change,pad2Change

	lea	inventoryUIState+uiHot,a0
	move.w	(a0),a1

	; Navigation
	move.b	pad1State,d0
	not	d0
	and.b	pad1Change,d0
	btst	#0,d0
	beq	*+4
	move.w	(0,a1),(a0)
	btst	#1,d0
	beq	*+6
	move.w	(4,a1),(a0)
	btst	#2,d0
	beq	*+6
	move.w	(6,a1),(a0)
	btst	#3,d0
	beq	*+6
	move.w	(2,a1),(a0)

	; Stats
	jsr	calculateStats

	lea	playerStatus,a2
	lea	playerStats,a3
	lea	playerInventory,a4
	lea	items,a5
	lea	itemsTilemap,a6

	clr.l	d0

	; Slot items

	; ?\1 slot
	; ?\2 item index
	MACRO drawIcon
	INLINE
	iF NARG>0
	    IF NARG>1
	    move.b	\1(a4,\2),d0
	    ELSE
	    move.b	\1(a4),d0
	    ENDIF
	    beq	.skip			; Item at 0 is null
	ENDIF
	lsl.w	#3,d0			; Slot descriptor is 8 bytes
	move.w	(gfx,a5,d0.w),d0
	lea	(a6,d0.w),a1
	jsr	draw2x2
.skip
	EINLINE
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

	calc32x64pos 1,24,vdp_map_bnt,uiVRAMAddress,d2
	drawIcon itemA

	calc32x64pos 5,24,vdp_map_bnt,uiVRAMAddress,d2
	drawIcon itemB

	calc32x64pos 9,24,vdp_map_bnt,uiVRAMAddress,d2
	drawIcon itemC

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
	INLINE
	lea	\1,a0
	jsr	draw8x8Text

	move.b	\3(a4),d0
	beq	.skip			; Item at 0 is null
	lsl.w	#3,d0			; Slot descriptor is 8 bytes
	move.b	(priB,a5,d0.w),d0	; TODO what if this is not protect?
	asr.b	#3,d0
	sub.b	d0,d3			; Subs from total protection

	lea	textScrap,a0
	writeValue \2
.skip
	EINLINE
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

	; Backpack
	; Loops trough each inventory item.
	; TODO If inventory doesn't have holes, this can be optimized.
	; TODO Maybe "draw" empty slots too instead of skipping them? Scrolling then changes d4 (where drawing starts).
	calc32x64pos 31,9,vdp_map_bnt,uiVRAMAddress,d1			; d1 is inventory origin
	move.l	d1,d2
	move.l	#0,d3							; d3 is drawn item counter (4 bytes per item)
	move.w	#backpackSize,d4
.nextItem
	dbra	d4,.backpackLoop

.backpackLoop
	move.b	backpack(a4,d4.w),d0
	beq	.nextItem		; Item at 0 is null?
	drawIcon
	; Calculate plane address for next icon
	add.b	#2<<1,d3		; 2 name table entries
	cmp	#24*2<<1,d3		; Draw max 24 items
	beq	.endBackpack
	; Y
	move.l	d3,d0
	and.b	#$F0,d0			; mask X off	(2<<1 * 3 = 0x10, so +1 Y)
	lsl.w	#6-2,d0			; Y coord (for 64 width plane, 4 bytes per item)
	; X
	move.l	d3,d2
	and.b	#$0F,d2			; mask Y off
	add.b	d2,d0
	; New write address
	move.l	d1,d2			; Restore d2 to origin
	swap	d0
	add.l	d0,d2
	dbra	d4,.backpackLoop
.endBackpack

	lea	inventoryUIState,a6

	MACRO drawSelectableSlot
	lea	(inventoryTilemap+border2),a1
	cmp.w	#\3,uiHot(a6)
	bne	*+6
	lea	(inventoryTilemap+border1),a1

	calc32x64pos \1,\2,vdp_map_ant,uiVRAMAddress,d2
	jsr	draw9Slice
	ENDM

	; Borders
	move.l	#(2<<16)|2,d3

	; Neck
	drawSelectableSlot 1,2,uiNeck

	; Head
	drawSelectableSlot 14,2,uiHead

	; Torso
	drawSelectableSlot 14,10,uiTorso

	; Finger Right hand
	drawSelectableSlot 1,14,uiFingerRight

	; Finger Left hand
	drawSelectableSlot 14,14,uiFingerLeft

	; Legs
	drawSelectableSlot 14,18,uiLegs

	; Info
	lea	(inventoryTilemap+border2),a1
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
	drawSelectableSlot 1,24,uiA
	jsr	draw9Slice

	; B
	drawSelectableSlot 5,24,uiB
	jsr	draw9Slice

	; C
	drawSelectableSlot 9,24,uiC
	jsr	draw9Slice

	; Actions
	lea	(inventoryTilemap+border2),a1
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
