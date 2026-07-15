; Pre calculated stats based on equipment and bonuses
			clrso
plrMaxHealth		so.b	1
plrMaxMana		so.b	1
plrProtection		so.b	1
plrRestore		so.b	1
plrDmgMelee		so.b	1
plrDmgMagic		so.b	1
plrEffects		so.b	1
			so.b	1
plrStatsSize		equ	__SO

; Current status that changes
			clrso
plrHealth		so.b	1
plrMana			so.b	1
plrStatusSize		equ	__SO

; Player inventory
			clrso
itemA			so.b	1
itemB			so.b	1
itemC			so.b	1
;itemX			so.b	1	; TODO detect controller
;itemY			so.b	1
;itemZ			so.b	1
slotHead		so.b	1
slotNeck		so.b	1
slotTorso		so.b	1
slotFingerRight		so.b	1
slotFingerLeft		so.b	1
slotLegs		so.b	1
backpackSize		equ	48
backpack		so.b	backpackSize
			so.b	1
plrInventorySize	equ	__SO

	MACRO addEffect
	move.b	\1,d0
	lsr.b	#3,d0
	or.b	d0,plrEffects(\2)
	ENDM

	MACRO addStat
	move.b	\1,d0
	move.b	d0,d1
	and.w	#%111,d0
	asr.b	#3,d1
	add.b	d1,(\2,d0.w)
	ENDM

; TODO Don't use "non null indexing", but just address to inventory. 2D Grid wrapping is a problem.

; TODO Check calling convention and registers
; Goes trough inventory and calculates stats. Adds bonus stats on top.
calculateStats
	lea	playerStats,a0		; TODO require caller to set for player1 or player2
	lea	playerStatsBonus,a1
	move.l	(a1),(a0)
	move.l	4(a1),4(a0)

	clr.w	d0
	lea	playerInventory,a2
	lea	items,a3

	; Usable items don't have effects
	move.b	itemA(a2),d0
	lsl.w	#3,d0			; itemDescSize == 1 << 3
	lea	(a3,d0.w),a1
	jsr	addStats

	move.b	itemB(a2),d0
	lsl.w	#3,d0
	lea	(a3,d0.w),a1
	jsr	addStats

	move.b	itemC(a2),d0
	lsl.w	#3,d0
	lea	(a3,d0.w),a1
	jsr	addStats

	; Equipment with effects
	move.b	slotHead(a2),d0
	lsl.w	#3,d0
	lea	(a3,d0.w),a1
	jsr	addEffectAndStats

	move.b	slotNeck(a2),d0
	lsl.w	#3,d0
	lea	(a3,d0.w),a1
	jsr	addEffectAndStats

	move.b	slotTorso(a2),d0
	lsl.w	#3,d0
	lea	(a3,d0.w),a1
	jsr	addEffectAndStats

	move.b	slotFingerRight(a2),d0
	lsl.w	#3,d0
	lea	(a3,d0.w),a1
	jsr	addEffectAndStats

	move.b	slotFingerLeft(a2),d0
	lsl.w	#3,d0
	lea	(a3,d0.w),a1
	jsr	addEffectAndStats

	move.b	slotLegs(a2),d0
	lsl.w	#3,d0
	lea	(a3,d0.w),a1
	jsr	addEffectAndStats

	rts

addEffectAndStats	; Items and weapons are usable and don't provide effect bonuses.
	addEffect slot(a1),a0
addStats
	addStat	priB(a1),a0
	addStat	secB(a1),a0
	rts

; Calculate number of non null items
; a4	playerInventory
; return
; d0	count of items
getBackpackItemCount
	clr.l	d0
	move.w	#backpackSize,d1
.accumulateLoop
	dbra	d1,.accumulate
	rts
.accumulate
	tst.b	(backpack,a4,d1.w)
	beq	.accumulateLoop		; Item is null?
	add.w	#1,d0
	bra	.accumulateLoop

; d2.w	sequential index in non null items
; return
; d0.w 	items index
; d1.w 	index to backpack
; trash
; d3.b, a0
getBackpackItem
	lea	playerInventory,a0
	clr.l	d0
	move.w	#backpackSize,d1
.accumulateLoop
	dbra	d1,.accumulate
	bra	.end
.accumulate
	move.b	(backpack,a0,d1.w),d3
	beq	.accumulateLoop		; Item is null?

	cmp.w	d2,d0
	beq	.end

	add.w	#1,d0
	bra	.accumulateLoop
.end
	move.b	d3,d0
	rts

; d2.w	sequential index in non null items
; a2	check routine
; return
; d0	next item index
findNextItem
	lea	playerInventory+backpack+backpackSize,a0

	clr.l	d0
	move.l	#-1,d4
	clr.w	d4
	move.w	#backpackSize,d1

	; Find first match for wrap around
.findFirstLoop
	dbra	d1,.checkFirst
	swap	d4			; Not found
	move.w	d4,d0
	rts
.checkFirst
	move.b	-(a0),d4
	beq	.findFirstLoop		; Item is null?

	jsr	(a2)
	beq	.isFirstOk

	add.w	#1,d0
	bra	.findFirstLoop

.isFirstOk
	cmp.w	d2,d0
	ble	.firstFound
	rts

.firstFound
	move.w	d0,d4
	swap	d4			; d4 high is first found for wrap around
	clr.w	d4
	add.w	#1,d0

	; Find next
.checkLoop
	dbra	d1,.check
	swap	d4			; Not found
	move.w	d4,d0
	rts
.check
	move.b	-(a0),d4
	beq	.checkLoop		; Item is null?

	cmp.w	d2,d0
	ble	.continue

	jsr	(a2)
	bne	.continue
	rts

.continue
	add.w	#1,d0
	bra	.checkLoop

; d2.w	sequential index in non null items
; a2	check routine
; return
; d0	previous item index
findPrevItem
	lea	playerInventory+backpack+backpackSize,a0

	clr.l	d0
	move.l	#-1,d4
	clr.w	d4
	move.w	#backpackSize,d1

	; Find next
.checkLoop
	dbra	d1,.check
	swap	d4			; Not found
	move.w	d4,d0
	rts
.check
	move.b	-(a0),d4
	beq	.checkLoop		; Item is null?

	cmp.w	d2,d0
	beq	.wasFound

.wasNotFound
	jsr	(a2)
	bne	.continue
	move.w	d0,d4
	swap	d4			; save match
	clr.w	d4

.continue
	add.w	#1,d0
	bra	.checkLoop

.wasFound
	tst.l	d4
	bmi	.wasNotFound
	swap	d4			; restore saved
	move.w	d4,d0
	rts

; Compare type
checkType
	cmp.w	d3,d4
	rts

; Compare slot
; d3.w	wanted item type
; a5	items
checkSlot
	lsl.w	#3,d4			; Slot descriptor is 8 bytes
	move.b	(slot,a5,d4.w),d4
	and.w	#%111,d4		; d4 slot
	cmp.w	d3,d4
	rts

; Compare list of slots from inventoryToSlot
; a3	inventoryUIState
; a5	items
; d4	item index
checkSlots
	lsl.w	#3,d4			; Slot descriptor is 8 bytes
	move.b	(slot,a5,d4.w),d4
	and.w	#%111,d4		; d4 slot

	move.w	(uiActive,a3),d5
	uiSlotToInventory d5
	lsl.w	d5

	lea	inventoryToSlot,a1
	move.w	(2,a1,d5.w),d3		; d3 is end of slot list
	move.w	(a1,d5.w),a1		; a1 possible inventory slots
	sub.w	a1,d3			; d3 is count of possible slots
	bra	.checkNext

.checkLoop
	cmp.b	(a1,d3.w),d4
.checkNext
	dbeq	d3,.checkLoop
	rts

; d1.w	sequential index in non null items
; return
; a0	Address to backpack slot
getBackpackItemAddress
	lea	playerInventory+backpack+backpackSize,a0
	move.w	#backpackSize,d0
.checkLoop
	dbra	d0,.check
	rts
.check
	tst.b	-(a0)
	beq	.checkLoop		; Item is null?
	dbra	d1,.checkLoop
	rts

; return
; a0	Address to free backpack slot
; d0.w	-1 if not found
; trash
; d3.b, a0
getBackpackFree
	lea	playerInventory+backpack+backpackSize,a0
	move.w	#backpackSize,d0
.checkLoop
	dbra	d0,.check
	rts
.check
	tst.b	-(a0)
	bne	.checkLoop		; Item is not null?
	rts

; Compacts backpack by moving each item to last null position. Keeps the order.
compactBackpack
	lea	playerInventory+backpack+backpackSize,a0	; Copy from
	move	a0,a1						; Copy to
	move.w	#backpackSize,d0
.checkLoop
	dbra	d0,.check
	move	a1,d0
	sub.l	a0,d0			; How many changed place
	dbeq	d0,.clear
	rts
.check
	move.b	-(a0),-(a1)
	bne	.checkLoop		; Item is not null?
	add	#1,a1			; Item was null, adjust target.
	bra 	.checkLoop
.clear					; clear "moved" items, since they were actually copied
	clr.b	-(a1)
	dbra	d0,.clear
	rts

; Find next item. Does not wrap around.
; a0	Start address, Note: decrement 1 if current address needs checking too.
; a2	Predicate subroutine
; d0	Matches to skip
; return
; a0	Found item address if Z true
findItemForwardToEnd
	move.l	#playerInventory+backpack+backpackSize,d1
	sub.l	a0,d1
	bra	findItemForwardFor

; Find next item. Wraps around.
; a0	Start address, Note: decrement 1 if current address needs checking too.
; a2	Predicate subroutine
; d0	Matches to skip
; return
; a0	Found item address if Z true
findItemForward
	move.l	#backpackSize,d1
	bra	findItemForwardFor

; Find next item. Wraps around.
; a0	Start address, Note: decrement 1 if current address needs checking too.
; a2	Predicate subroutine
; d0	Matches to skip
; d1	Count to check
; return
; a0	Found item address if Z true
findItemForwardFor
.nextItem
	addq	#1,a0			; Next item
	cmp.w	#playerInventory+backpack+backpackSize,a0
	blt	.checkLoop
	sub.l	#backpackSize,a0	; Wrap around
.checkLoop
	dbra	d1,.check
	; Not found
	move	#0,ccr
	rts
.check
	move.b	(a0),d2			; d2 is item type
	beq	.nextItem		; Item is null?

	jsr	(a2)
	beq	.match

	bra	.nextItem
.match
	dbra	d0,.nextItem
	rts

; Find next item. Does not wrap around.
; a0	Start address, Note: increment 1 if current address needs checking too.
; a2	Predicate subroutine
; d0	Matches to skip
; return
; a0	Found item address if Z true
findItemBackwardToStart
	move.l	a0,d1
	sub.l	#playerInventory+backpack,d1
	bra	findItemBackwardFor

; Find next item. Wraps around.
; a0	Start address, Note: increment 1 if current address needs checking too.
; a2	Predicate subroutine
; d0.w	Matches to skip
; return
; a0	Found item address if Z true
findItemBackward
	move.l	#backpackSize,d1
	bra	findItemBackwardFor

; Find next item. Wraps around.
; a0	Start address, Note: increment 1 if current address needs checking too.
; a2	Predicate subroutine
; d0	Matches to skip
; d1	Count to check
; return
; a0	Found item address if Z true
findItemBackwardFor
.nextItem
	subq	#1,a0			; Next item
	cmp.w	#playerInventory+backpack,a0
	bge	.checkLoop
	add.l	#backpackSize,a0	; Wrap around
.checkLoop
	dbra	d1,.check
	; Not found
	move	#0,ccr
	rts
.check
	move.b	(a0),d2			; d2 is item type
	beq	.nextItem		; Item is null?

	jsr	(a2)
	beq	.match

	bra	.nextItem
.match
	dbra	d0,.nextItem
	rts

nopMatch
	move	#%00100,ccr
	rts
