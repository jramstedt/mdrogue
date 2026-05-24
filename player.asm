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
slotHead		so.b	1
slotNeck		so.b	1
slotTorso		so.b	1
slotFingerRight		so.b	1
slotFingerLeft		so.b	1
slotLegs		so.b	1
backpackSize		equ	48
backpack		so.b	backpackSize
plrInventorySize	equ	__SO

	MACRO addEffect
	move.b	\1,d0
	asr.b	#3,d0
	or.b	d0,plrEffects(\2)
.end
	ENDM

	MACRO addStat
	move.b	\1,d0
	move.b	d0,d1
	and.w	#%111,d0
	asr.b	#3,d1
	add.b	d1,(\2,d0.w)
	ENDM

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