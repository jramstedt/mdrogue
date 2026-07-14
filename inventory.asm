		clrso
uiHot		so.w	1	;
uiActive	so.w	1	;
uiBackpackIndex	so.b	1	; Selected item in backpack
uiHotSlotIndex	so.b	1	; Active slot index when equipping
uiAPressed	so.w	1	; frames A is pressed ; TODO move somewhere else to be used in other places
uiBPressed	so.w	1	; frames B is pressed
uiCPressed	so.w	1	; frames C is pressed
; TODO X,Y,Z
uiSPressed	so.w	1	; frames start is pressed
uiStateSize	equ	__SO

; Pad navigation
;			up,right,down,left
uiA		dc.w	uiFingerRight,uiB,uiNeck,uiBackpack
uiB		dc.w	uiFingerRight,uiC,uiNeck,uiA
uiC		dc.w	uiLegs,uiActions,uiHead,uiB
; TODO X,Y,Z, needs alternative table?
uiHead		dc.w	uiActions,uiGround,uiTorso,uiNeck
uiNeck		dc.w	uiA,uiHead,uiFingerRight,uiGround
uiTorso		dc.w	uiHead,uiBackpack,uiFingerLeft,uiFingerRight
uiFingerRight	dc.w	uiNeck,uiFingerLeft,uiA,uiBackpack
uiFingerLeft	dc.w	uiTorso,uiBackpack,uiLegs,uiFingerRight
uiLegs		dc.w	uiFingerLeft,uiBackpack,uiActions,uiFingerRight
uiBackpack	dc.w	uiGround,uiFingerRight,uiGround,uiActions
; Special
uiGround	dc.w	uiBackpack,uiNeck,uiBackpack,uiHead
uiActions	dc.w	uiLegs,uiBackpack,uiHead,uiC

	MACRO inventoryToUISlot
	lsl.w	#3,\1
	add.w	#uiA,\1
	ENDM

	MACRO uiSlotToInventory
	sub.w	#uiA,\1
	lsr.w	#3,\1
	ENDM

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
	;move.b	#1,(playerInventory+itemA)
	;move.b	#8,(playerInventory+itemB)
	;move.b	#9,(playerInventory+itemC)
	move.b	#3,(playerInventory+slotHead)
	move.b	#4,(playerInventory+slotNeck)
	move.b	#5,(playerInventory+slotTorso)
	;move.b	#7,(playerInventory+slotFingerRight)
	;move.b	#7,(playerInventory+slotFingerLeft)
	;move.b	#6,(playerInventory+slotLegs)

	; Fill backpack with stuff
	REPT 45
	move.b	#((REPTN)%10)+1,(playerInventory+backpack+REPTN)
	ENDR

	jsr compactBackpack

	move.l	#(uiBackpack<<16)|0,(inventoryUIState+uiHot)

	displayOn vdp_ctrl
	jsr	waitVBlankOff	; Wait for blanking to start (VBlank is off).
	jsr	waitVBlankOn	; Wait for blanking to stop.

.gameLoop
	readGamePads pad1State,pad2State,pad1Change,pad2Change

	clr.l	d0

	; Stats
	jsr	calculateStats

	; Slot items
	lea	inventoryUIState,a3
	lea	playerInventory,a4
	lea	items,a5
	lea	itemsTilemap,a6

; =======
; Borders
	MACRO drawSelectableBorder
	lea	(inventoryTilemap+border2),a1
	cmp.w	#\3,(uiHot,a3)
	bne	*+6
	lea	(inventoryTilemap+border1),a1

	calc32x64pos \1,\2,vdp_map_ant,uiVRAMAddress,d2
	jsr	draw9Slice
	ENDM

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

	; Backpack
	move.l	#(14<<16)|8,d3
	calc32x64pos 31,9,vdp_map_ant,uiVRAMAddress,d2
	drawSelectableBorder 31,9,uiBackpack

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

; =====
; Icons
	; ?\1 slot
	; ?\2 item index
	MACRO drawIcon
	INLINE
	iF NARG>0
	    clr.w	d0
	    IF NARG>1
	    move.b	(\1,a4,\2),d0
	    ELSE
	    move.b	(\1,a4),d0
	    ENDIF
	    ;beq	.skip			; Item at 0 is null
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

; ========
; Draw Backpack
	jsr drawBackpack

; ==========
; User input

.backpackInput
	cmp.w	#uiBackpack,uiActive(a3)
	beq	.backpackNavigation

	; Not active, but hot?
	cmp.w	#uiBackpack,uiHot(a3)
	blt	.equipmentInput		; Continue with equipment input check
	bne	.defaultNavigation	; TODO should be bgt .groundInput or .actionInput

	move.w	#uiBackpack,uiActive(a3); Automatically set backpack as active if hot to lock navigation

; Backpack navigation input
.backpackNavigation
	cmp.w	#10,(uiBPressed,a3)	; If B pressed, get out of backpack, also cancels item scrap
	blt	.continueBackpackNavigation
.defaultNavigation
	clr.w	(uiActive,a3)		; Reset active
	jsr	defaultNavigateHot
	bra	.endInput

.continueBackpackNavigation
	tst.w	(uiCPressed,a3)		; If C pressed
	bne	.backpackScrap		; Skip navigation

	tst.w	(uiAPressed,a3)		; If A pressed
	beq	.continueNavigation
	jsr	equipItemFromBackpack
	bra	.endInput

.continueNavigation
	jsr	getBackpackItemCount
	tst.b	d0
	beq	.endInput		; No items in backpack, end input checking

	move.b	pad1State,d2
	not.b	d2			; flip pad1State bits
	and.b	pad1Change,d2

.up
	btst	#0,d2			; Up
	beq	.down
	clr.b	(uiHotSlotIndex,a3)	; reset equip navigation
	sub.b	#4,(uiBackpackIndex,a3)	; One row up
	bpl	.left

	move.w	d0,d1			; d1 is full rows
        add.b	#3,d1			; Alignment - 1
        andi.b	#$FC,d1			; Mask out bottom 2 bits
	add.b	d1,(uiBackpackIndex,a3)	; Wrap around

	cmp.b	(uiBackpackIndex,a3),d0	; Over last (partial row)?
	bgt	*+6
	sub.b	#4,(uiBackpackIndex,a3)	; One more row up
	bra	.left
.down
	btst	#1,d2			; Down
	beq	.left
	clr.b	(uiHotSlotIndex,a3)	; reset equip navigation
	add.b	#4,(uiBackpackIndex,a3)	; One row down
	cmp.b	(uiBackpackIndex,a3),d0
	bgt	.left

	move.w	d0,d1			; d1 is full rows
	add.b	#3,d1			; Alignment - 1
	andi.b	#$FC,d1			; Mask out bottom 2 bits
	sub.b	d1,(uiBackpackIndex,a3)	; Wrap around
	bpl	.left			; Before first item (partial row)?
	add.b	#4,(uiBackpackIndex,a3)	; One more row down
.left
	btst	#2,d2			; Left
	beq	.right
	clr.b	(uiHotSlotIndex,a3)	; reset equip navigation
	sub.b	#1,(uiBackpackIndex,a3)	; One column left
	bpl	.endInput
	add.b	d0,(uiBackpackIndex,a3)	; Wrap around
	bra	.endInput
.right
	btst	#3,d2			; Right
	beq	.endInput
	clr.b	(uiHotSlotIndex,a3)	; reset equip navigation
	add.b	#1,(uiBackpackIndex,a3)	; One column right
	cmp.b	(uiBackpackIndex,a3),d0
	bgt	.endInput
	sub.b	d0,(uiBackpackIndex,a3)	; Wrap around

	bra	.endInput

.backpackScrap
	move.b	pad1State,d2

	cmp.w	#25,(uiCPressed,a3)	; If C pressed, remove item
	blt	.endInput

	btst	#5,d2			; C
	beq	.endInput

	jsr	removeActive
	bra	.endInput

; Equipment slot input
.equipmentInput
	tst.w	(uiActive,a3)
	bne	.equipmentActive

	; No ui element is active.
	move.w	(uiHot,a3),d1
	beq	.endInput		; Can hot be null?
	cmp.w	#uiLegs,d1
	bgt	.endInput		; TODO should be bgt .groundInput or .actionInput ??

	; Check inputs
	move.b	pad1State,d0
	not.b	d0
	and.b	pad1Change,d0		; 1 pressed down

	andi.b	#%01110000,d0		; BCA
	beq	.defaultNavigation	; Not
	move.w	d1,(uiActive,a3)

	btst	#6,d0			; A pressed
	beq	.equipmentActive	; Not

	; A pressed, show filtered item in backpack
	move.b	(uiBackpackIndex,a3),d2
	jsr	getBackpackItem
	move.w	d0,d4
	lea	checkSlots,a2
	lea	inventoryUIState,a3
	lea	items,a5
	jsr	(a2)			; Check if current selected can be equipped
	beq	.equipmentActive
	jsr	findNextItem		; Find next equippable item
	bmi	.equipmentRelease	; TODO show player "no suitable items" message
	move.b	d0,(uiBackpackIndex,a3)	; Select equippable item in backpack

.equipmentActive
	move.b	pad1State,d0
	move.b	d0,d1
	not.b	d0
	and.b	pad1Change,d0		; 1 pressed down

.equipmentSwitch	; A Switch / Use
	move.b	pad1State,d2
	and.b	pad1Change,d2
	btst	#6,d2			; A released?
	bne	.switchItem

	btst	#6,d1			; A
	bne	.equipmentMove		; Not

	btst	#0,d0			; Up
	bne	.selectPreviousItem	; Yes

	btst	#1,d0			; Down
	bne	.selectNextItem		; Yes

	btst	#2,d0			; Left
	bne	.selectPreviousItem	; Yes

	btst	#3,d0			; right
	bne	.selectNextItem		; Yes

	bra	.endInput

.selectNextItem
	clr.l	d2
	clr.l	d3
	move.b	(uiBackpackIndex,a3),d2
	lea	checkSlots,a2
	lea	inventoryUIState,a3
	lea	items,a5
	jsr	findNextItem
	bmi	.endInput
	move.b	d0,(uiBackpackIndex,a3)
	bra	.endInput

.selectPreviousItem
	clr.l	d2
	clr.l	d3
	move.b	(uiBackpackIndex,a3),d2
	lea	checkSlots,a2
	lea	inventoryUIState,a3
	lea	items,a5
	jsr	findPrevItem
	bmi	.endInput
	move.b	d0,(uiBackpackIndex,a3)
	bra	.endInput

.switchItem
	move.b	(uiBackpackIndex,a3),d2
	jsr	getBackpackItem		; d0.w is index to items, d1.w is index to backpack

	move.w	(uiActive,a3),d3
	uiSlotToInventory d3
	; swap items
	move.b	(a4,d3.w),d2		; d2 is item in slot
	move.b	d0,(a4,d3.w)		; backpack -> slot
	move.b	d2,(backpack,a4,d1.w)	; slot -> backpack
	bne	.equipmentRelease

	; Null item set to backpack
	jsr	fixBackpackIndex
	bra	.equipmentRelease

.equipmentMove	; B Move to backpack
	btst	#4,d0			; B
	beq	.equipmentScrap		; Not

	jsr	getBackpackFree
	tst.w	d0
	bmi	.equipmentRelease	; No free slot. TODO Show message to player

	move.w	(uiActive,a3),d1
	uiSlotToInventory d1
	move.b	(a4,d1.w),(a0)
	clr.b	(a4,d1.w)		; Clear slot
	bra	.equipmentRelease

.equipmentScrap	; C Scrap
	btst	#5,d1			; C released?
	beq	.endInput		; Not

	cmp.w	#25,(uiCPressed,a3)	; If C pressed, remove item
	blt	.equipmentRelease

	move.w	uiHot(a3),d0
	uiSlotToInventory d0
	clr.b	(a4,d0.w)
	bra	.equipmentRelease

.equipmentRelease
	clr.w	(uiActive,a3)

.endInput

	; Help
	calc32x64pos 25,24,vdp_map_ant,uiVRAMAddress,d2
	lea	strHelp,a0
	lea	parchmentTilemap,a1
	jsr	draw8x8Text

.finishFrame
	; Note: This is done at the end to allow checking pressed duration and state change
	; Increment press counters if pressed
	; Clear press counters if not pressed
	move.b	pad1State,d0

	btst	#4,d0		; B
	beq	*+8
	clr.w	(uiBPressed,a3)
	bra	*+6
	add.w	#1,(uiBPressed,a3)

	btst	#5,d0		; C
	beq	*+8
	clr.w	(uiCPressed,a3)
	bra	*+6
	add.w	#1,(uiCPressed,a3)

	btst	#6,d0		; A
	beq	*+8
	clr.w	(uiAPressed,a3)
	bra	*+6
	add.w	#1,(uiAPressed,a3)

	btst	#7,d0		; S
	beq	*+8
	clr.w	(uiSPressed,a3)
	bra	*+6
	add.w	#1,(uiSPressed,a3)

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

	; TODO Move some stuff here

	jsr	drawPlayerStatus

	jsr	waitVBlankOn	; Wait for blanking to stop.

	bra 	.gameLoop

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

drawBackpack
	; TODO If inventory doesn't have holes, this can be optimized.
	; TODO Maybe "draw" empty slots too instead of skipping them? Scrolling then changes d4 (where drawing starts).

	; Loops trough each inventory item.
	move.w	#backpackSize,d4	; d4 is inventory index
	clr.l	d6			; d6 is processed item counter

	jsr	getBackpackItemCount	; d0 is count
	cmp.b	#4*7,d0			; No scrolling needed
	ble	.startInventoryDrawing

	add.b	#3,d0			; Alignment - 1
	andi.b	#$FC,d0			; Mask out bottom 2 bits
	sub.b	#4*3+4*4,d0		; Subtracts top threshold 3 and bottom threshold 4

	; Scroll offsetting
	clr.l	d3
	move.b	(uiBackpackIndex,a3),d3
	andi.b	#$FC,d3			; mask X away
	sub.b	#4*3,d3			; rows over scroll top threshold
	ble	.startInventoryDrawing
	cmp.b	d0,d3			; rows over scroll bottom threshold
	ble	.scrollForward
	move.b	d0,d3			; Scroll to max

.scrollForward
	dbra	d3,.checkNextItem
	bra	.startInventoryDrawing

.checkNextItem
	sub.w	#1,d4
	move.b	(backpack,a4,d4.w),d0
	beq	.checkNextItem

	add.b	#1,d6
	bra	.scrollForward

	; Draw
.startInventoryDrawing
	move.l	#(uiBackpack<<16)|0,d5	; d5.w is drawn item counter (4 bytes per item)
	bra	.calcCoordinates

.nextItem
	dbra	d4,.backpackLoop
	bra	.drawEmpty		; End of backpack items. Draw empty

.backpackLoop
	move.b	(backpack,a4,d4.w),d0
	beq	.nextItem		; Item is null?
	drawIcon

	cmp.b	(uiBackpackIndex,a3),d6		; Is d6 hot?
	bne	.calcNextIcon

	; Draw hot border
	calc32x64pos 31,9,vdp_map_ant,uiVRAMAddress,d2
	add.l	d3,d2
	lea	(inventoryTilemap+border1),a1
	move.l	#(2<<16)|2,d3
	jsr	draw9Slice

.calcNextIcon
	add.b	#1,d6

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

	bra	.nextItem

.drawEmpty
	; Fill rest with empty
	move.w	#empty,d0
	lea	(a6,d0.w),a1
	jsr	draw2x2
	clr.w	d4			; clear d4 to not branch into .backpackLoop
	bra	.calcNextIcon

.endBackpack
	rts

; Remove active item from backpack
removeActive
	clr.l	d0
	move.w	#backpackSize,d1
.accumulateLoop
	dbra	d1,.accumulate
	bra	.end
.accumulate
	tst.b	(backpack,a4,d1.w)
	beq	.accumulateLoop		; Item is null?

	cmp.b	(uiBackpackIndex,a3),d0
	beq	.remove

	add.b	#1,d0
	bra	.accumulateLoop

.remove
	clr.b	(backpack,a4,d1.w)	; Remove item from backpack
	jsr	fixBackpackIndex
.end
	rts

; Checks if last non null item. If not moves index back one. Clamps to zero.
; d1.w	backpack index
fixBackpackIndex
	; Check if last item and fix backpack index
.restLoop
	dbra	d1,.check
	bra	.fixBackpackIndex
.check
	tst.b	(backpack,a4,d1.w)
	beq	.restLoop		; Item is null?
	bra	.end

.fixBackpackIndex
	sub.b	#1,(uiBackpackIndex,a3)
	bge	.end
	clr.b	(uiBackpackIndex,a3)
.end
	rts

; Swap backpack item with slot item
equipItemFromBackpack
        ; TODO for items & weapons, ask for A,B,C,X,Y,Z or other to cancel?

	move.b	(uiBackpackIndex,a3),d2
	jsr	getBackpackItem		; d0.w is index to items, d1.w is index to backpack

	lea	items,a0
	move.w	d0,d2
	lsl.w	#3,d2			; Slot descriptor is 8 bytes
	move.b	(slot,a0,d2.w),d2
	and.w	#%111,d2		; d2 slot

	lea	slotToInventory,a1
	lsl.w	d2
	move.w	(2,a1,d2.w),d3		; d3 is end of slot list
	move.w	(a1,d2.w),a1		; a1 possible inventory slots
	sub.w	a1,d3			; d3 is count of possible slots

	move.b	pad1State,d2
	not.b	d2
	and.b	pad1Change,d2

	btst	#0,d2		; Up
	beq	*+6
	sub.b	#1,(uiHotSlotIndex,a3)
	btst	#1,d2		; Down
	beq	*+6
	add.b	#1,(uiHotSlotIndex,a3)
	btst	#2,d2		; Left
	beq	*+6
	sub.b	#1,(uiHotSlotIndex,a3)
	btst	#3,d2		; right
	beq	*+6
	add.b	#1,(uiHotSlotIndex,a3)

	clr.l	d2
	move.b	(uiHotSlotIndex,a3),d2
	add.b	d3,d2			; add count to wrap around if negative
	divu	d3,d2
	swap	d2			; d2 remainder
	move.b	d2,(uiHotSlotIndex,a3)	; save wrapped
	move.b	(a1,d2.w),d3		; d3 selected inventory slot

	; A released to confirm switch?
	move.b	pad1State,d2
	and.b	pad1Change,d2
	btst	#6,d2			; A released?
	beq	.endSetHot		; Not, skip item swap

	lea	playerInventory,a1
	; swap items
	move.b	(a1,d3.w),d2		; d2 is item in slot
	move.b	d0,(a1,d3.w)		; backpack -> slot
	move.b	d2,(backpack,a1,d1.w)	; slot -> backpack
	bne	.endClearHot

	; Null item set to backpack
	clr.b	(uiHotSlotIndex,a3)	; reset equip navigation
	jsr	fixBackpackIndex

.endClearHot
	move.w	#uiBackpack,(uiHot,a3)
	rts

.endSetHot
	inventoryToUISlot d3
	move.w	d3,(uiHot,a3)
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
	; Needs d3 to be total protection
	MACRO writeLabelAndSlotProtection
	INLINE
	lea	\1,a0
	jsr	draw8x8Text

	move.b	(\3,a4),d0
	beq	.writeNull		; Item is null
	lsl.w	#3,d0			; Slot descriptor is 8 bytes
	move.b	(priB,a5,d0.w),d0	; TODO what if this is not protect?
	asr.b	#3,d0			; Get value
	sub.b	d0,d3			; Subs from total protection
	lea	textScrap,a0
	writeValue \2
	bra	.end

.writeNull
	add32x64pos \2,0,d2
	lea	strNull,a0
	jsr	draw8x8Text
.end
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

strNull		dc.b	'---',0

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
