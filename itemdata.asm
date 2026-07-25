; Slot
item		equ	0
weapon		equ	1
head		equ	2
neck		equ	3
torso		equ	4
finger		equ	5
legs		equ	6
quest		equ	7	; Items that can't be equipped, such as quest items

; Bonus stats
health		equ	0
mana		equ	1
protect		equ	2
restore		equ	3
melee		equ	4
magic		equ	5

; effect
none		equ	0
float		equ	1

; spells
fireball	equ	0

; damage type
normal		equ	0

; quest flag
junk		equ	0
persistent	equ	1	; can't be removed from player inventory

	even
; Allowed inventory slots for item slot
slotToInventory
	INLINE
	dc.w	.item
	dc.w	.weapon
	dc.w	.head
	dc.w	.neck
	dc.w	.torso
	dc.w	.finger
	dc.w	.legs
	dc.w	.quest
	dc.w	.end

.item	dc.b	itemA,itemB,itemC	; TODO X,Y,Z
.weapon	dc.b	itemA,itemB,itemC
.head	dc.b	slotHead
.neck	dc.b	slotNeck
.torso	dc.b	slotTorso
.finger	dc.b	slotFingerRight,slotFingerLeft
.legs	dc.b	slotLegs
.quest	dc.b	backpack
.end
	EINLINE

	even
; Allowed item slots for inventory slot
inventoryToSlot
			INLINE
			dc.w	.itemA
			dc.w	.itemB
			dc.w	.itemC
			; TODO X,Y,Z
			dc.w	.slotHead
			dc.w	.slotNeck
			dc.w	.slotTorso
			dc.w	.slotFingerRight
			dc.w	.slotFingerLeft
			dc.w	.slotLegs
			dc.w	.end

.itemA			dc.b	item,weapon
.itemB			dc.b	item,weapon
.itemC			dc.b	item,weapon
.slotHead		dc.b	head
.slotNeck		dc.b	neck
.slotTorso		dc.b	torso
.slotFingerRight	dc.b	finger
.slotFingerLeft		dc.b	finger
.slotLegs		dc.b	legs
.end
			EINLINE

; item structure
		rsreset
slot		rs.b	1	; EEEEESSS	E=Effect S=Slot
priB		rs.b	1	; BBBBBIII	B=Value  I=Stat
secB		rs.b	1	; BBBBBIII	B=Value  I=Stat
		rs.b	1	; padding
gfx		rs.w	1	; Tilemap offset
label		rs.w	1	; Name string address
itemDescSize	equ	__RS

; item name = gfx of priB ?

; \1	Slot
; \2	Effect, Spells, Damage type, quest flags
; \3	Primary bonus stat
; \4	Primary bonus value
; \5	Secondary bonus stat
; \6	Secondary bonus value
; \7	Graphics
; \8	Name
	MACRO buildItemDescriptor
	dc.b	(\2<<3)|(\1)
	dc.b	(\4<<3)|(\3)
	dc.b	(\6<<3)|(\5)
	dc.b	0
	dc.w	\7
	dc.w	\8
	ENDM

	even
items
	buildItemDescriptor	quest,junk,0,0,0,0,empty,0					; Null item
	buildItemDescriptor	item,none,health,1,0,0,potion_health,str_potion_health		; health potion
	buildItemDescriptor	item,none,mana,1,0,0,potion_mana,str_potion_mana		; mana potion

	buildItemDescriptor	head,none,protect,1,0,0,helmet_iron,0				; iron helmet
	buildItemDescriptor	neck,float,protect,1,melee,1,necklace_silver,0			; iron gorget
	buildItemDescriptor	torso,none,protect,1,0,0,chest_iron,str_chest_iron		; iron shirt
	buildItemDescriptor	legs,none,protect,1,0,0,legs_iron,0				; iron pants

	buildItemDescriptor	finger,none,protect,1,restore,1,ring_silver,str_ring_silver	; iron ring

	buildItemDescriptor	weapon,normal,melee,1,0,0,sword_iron,0				; iron sword

	buildItemDescriptor	weapon,fireball,magic,1,0,0,book_black_plain,0			; fireball spell
	buildItemDescriptor	weapon,1,magic,1,0,0,book_brown_plain,0				; ??? spell
