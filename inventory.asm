		clrso
uiHot		so.w	1	;
uiHotAux	so.w	1	; can be used for indexing for example
uiActive	so.w	1
uiAPressed	so.w	1	; frames A is pressed ; TODO move somewhere else to be used in other places
uiBPressed	so.w	1	; frames B is pressed
uiCPressed	so.w	1	; frames C is pressed
uiSPressed	so.w	1	; frames start is pressed
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

	; Fill backpack with stuff
	REPT	48
	move.b	#((REPTN)%10)+1,(playerInventory+backpack+REPTN)
	ENDR

	move.l	#(uiBackpack<<16)|0,(inventoryUIState+uiHot)

	displayOn vdp_ctrl
	jsr	waitVBlankOff	; Wait for blanking to start (VBlank is off).
	jsr	waitVBlankOn	; Wait for blanking to stop.

.gameLoop
	readGamePads pad1State,pad2State,pad1Change,pad2Change

	clr.l	d0

	; Stats
	jsr	calculateStats
	jsr	drawPlayerStatus

	; Slot items
	lea	inventoryUIState,a3
	lea	playerInventory,a4
	lea	items,a5
	lea	itemsTilemap,a6

	; Increment press counters
	add.w	#1,(uiAPressed,a3)
	add.w	#1,(uiBPressed,a3)
	add.w	#1,(uiCPressed,a3)
	add.w	#1,(uiSPressed,a3)

	; Clear press counters if not pressed
	move.b	pad1State,d0
	btst	#4,d0		; B
	beq	*+6
	clr.w	(uiBPressed,a3)
	btst	#5,d0		; C
	beq	*+6
	clr.w	(uiCPressed,a3)
	btst	#6,d0		; A
	beq	*+6
	clr.w	(uiAPressed,a3)
	btst	#7,d0		; S
	beq	*+6
	clr.w	(uiSPressed,a3)

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


	MACRO drawSelectableBorder
	lea	(inventoryTilemap+border2),a1
	cmp.w	#\3,uiHot(a3)
	bne	*+6
	lea	(inventoryTilemap+border1),a1

	calc32x64pos \1,\2,vdp_map_ant,uiVRAMAddress,d2
	jsr	draw9Slice
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

	; ========
	; Backpack
	; TODO If inventory doesn't have holes, this can be optimized.
	; TODO Maybe "draw" empty slots too instead of skipping them? Scrolling then changes d4 (where drawing starts).

	; Border
	move.l	#(14<<16)|8,d3
	calc32x64pos 31,9,vdp_map_ant,uiVRAMAddress,d2
	drawSelectableBorder 31,9,uiBackpack

	; Loops trough each inventory item.
	move.w	#backpackSize,d4	; d4 is inventory index
	clr.l	d6			; d6 is processed item counter

	; TODO instead of backpackSize row count is needed (including possible short). It needs to be used in navigation wraparound too...
	; Scroll offsetting
	clr.l	d3
	move.w	uiHotAux(a3),d3
	andi	#$FC,d3			; mask X away
	sub.w	#4*3,d3			; rows over scroll top threshold
	ble	.startInventoryDrawing
	cmp.w	#backpackSize-4*7,d3	; rows over scroll bottom threshold
	ble	.skipNext
	move.w	#backpackSize-4*7,d3

.skipNext
	dbra	d3,.scrollOffset
	bra	.startInventoryDrawing

.scrollOffset
	sub.w	#1,d4
	move.b	(backpack,a4,d4.w),d0
	beq	.skipNext

	add.w	#1,d6
	bra	.skipNext

.startInventoryDrawing
	move.l	#(uiBackpack<<16)|0,d5	; d5.w is drawn item counter (4 bytes per item)
	bra	.calcCoordinates

.nextItem
	dbra	d4,.backpackLoop
	bra	.endBackpack

.backpackLoop
	move.b	(backpack,a4,d4.w),d0
	beq	.nextItem		; Item at 0 is null?
	drawIcon

	cmp.w	uiHotAux(a3),d6		; Checks both hot and current index
	bne	.calcNextIcon

	; Draw hot border
	calc32x64pos 31,9,vdp_map_ant,uiVRAMAddress,d2
	add.l	d3,d2
	lea	(inventoryTilemap+border1),a1
	move.l	#(2<<16)|2,d3
	jsr	draw9Slice

.calcNextIcon
	add.w	#1,d6

	; Calculate plane address for next icon
	add.w	#2<<1,d5		; 2 name table entries
	cmp.w	#28*2<<1,d5		; Draw max 24 items
	beq	.endBackpack
.calcCoordinates
	clr.l	d0
	; Y
	move.w	d5,d0
	and.b	#$F0,d0			; mask X off	(2<<1 * 3 = 0x10, so +1 Y)
	lsl.w	#6-2,d0			; Y coord (for 64 width plane, 4 bytes per item)
	; X
	move.w	d5,d2
	and.b	#$0F,d2			; mask Y off
	add.b	d2,d0
	; New write address
	calc32x64pos 31,9,vdp_map_bnt,uiVRAMAddress,d2	; Restore d2 to origin
	swap	d0
	add.l	d0,d2
	move.l	d0,d3			; Save d0 for hot border position

	dbra	d4,.backpackLoop
.endBackpack

	; TODO clear empty slots of short rows

	; User input
	cmp.w	#uiBackpack,uiHot(a3)
	bne	.defaultNavigation

	cmp.w	#10,(uiBPressed,a3)
	blt	.itemNavigation
	jsr	defaultNavigateHot
	bra	.endBackpackNavigation

.defaultNavigation
	jsr	defaultNavigateHot
	bra	.endBackpackNavigation

.itemNavigation
	move.b	pad1State,d0
	not.b	d0
	and.b	pad1Change,d0

.up
	btst	#0,d0			; Up
	beq	.down
	sub.w	#4,uiHotAux(a3)	; One row up
	bpl	.left
	add.w	d6,uiHotAux(a3)	; Wrap around
	bra	.left
.down
	btst	#1,d0			; Down
	beq	.left
	add.w	#4,uiHotAux(a3)	; One row down
	cmp.w	uiHotAux(a3),d6
	bgt	.left
	sub.w	d6,uiHotAux(a3)	; Wrap around
	bra	.left
.left
	btst	#2,d0			; Left
	beq	.right
	sub.w	#1,uiHotAux(a3)		; One column left
	bpl	.endBackpackNavigation
	add.w	d6,uiHotAux(a3)	; Wrap around
	bra	.endBackpackNavigation
.right
	btst	#3,d0			; Right
	beq	.endBackpackNavigation
	add.w	#1,uiHotAux(a3)		; One column right
	cmp.w	uiHotAux(a3),d6
	bgt	.endBackpackNavigation
	sub.w	d6,uiHotAux(a3)	; Wrap around
.endBackpackNavigation

	; Borders
	move.l	#(2<<16)|2,d3

	; Neck
	drawSelectableBorder 1,2,uiNeck

	; Head
	drawSelectableBorder 14,2,uiHead

	; Torso
	drawSelectableBorder 14,10,uiTorso

	; Finger Right hand
	drawSelectableBorder 1,14,uiFingerRight

	; Finger Left hand
	drawSelectableBorder 14,14,uiFingerLeft

	; Legs
	drawSelectableBorder 14,18,uiLegs

	; Info
	lea	(inventoryTilemap+border2),a1
	move.l	#(6<<16)|12,d3
	calc32x64pos 18,2,vdp_map_ant,uiVRAMAddress,d2
	jsr	draw9Slice

	; Ground
	move.l	#(6<<16)|8,d3
	calc32x64pos 31,2,vdp_map_ant,uiVRAMAddress,d2
	jsr	draw9Slice

	; A
	move.l	#(3<<16)|3,d3
	drawSelectableBorder 1,24,uiA
	jsr	draw9Slice

	; B
	drawSelectableBorder 5,24,uiB
	jsr	draw9Slice

	; C
	drawSelectableBorder 9,24,uiC
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

defaultNavigateHot
	lea	inventoryUIState+uiHot,a0
	move.w	(a0),a1

	move.b	pad1State,d0
	not.b	d0
	and.b	pad1Change,d0
	btst	#0,d0		; Up
	beq	*+4
	move.w	(0,a1),(a0)
	btst	#1,d0		; Down
	beq	*+6
	move.w	(4,a1),(a0)
	btst	#2,d0		; Left
	beq	*+6
	move.w	(6,a1),(a0)
	btst	#3,d0		; right
	beq	*+6
	move.w	(2,a1),(a0)

	rts

drawPlayerStatus
	lea	parchmentTilemap,a1	; Font tilemap, used by draw8x8Text
	lea	playerStatus,a2
	lea	playerStats,a3
	lea	playerInventory,a4
	lea	items,a5

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
	rts

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
