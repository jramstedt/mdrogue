; Slot
item		equ	0
weapon		equ	1
head		equ	2
neck		equ	3
torso		equ	4
finger		equ	5
legs		equ	6

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

; item structure
		rsreset
slot		rs.b	1	; EEEEESSS	E=Effect S=Slot
priB		rs.b	1	; BBBBBIII	B=Value  I=Stat
secB		rs.b	1	; BBBBBIII	B=Value  I=Stat
		rs.b	1	; padding
gfx		rs.w	1	; Tilemap offset
itemDescSize	equ	__RS

; item name = gfx of priB ?

; \1	Slot
; \2	Effect, Spells, Damage type
; \3	Primary bonus stat
; \4	Primary bonus value
; \5	Secondary bonus stat
; \6	Secondary bonus value
; \7	Graphics
	MACRO buildItemDescriptor
	dc.b	(\2<<3)|(\1)
	dc.b	(\4<<3)|(\3)
	dc.b	(\6<<3)|(\5)
	dc.b	0
	dc.w	\7
	ENDM

items
	buildItemDescriptor	item,none,health,1,0,0,potion_health		; health potion
	buildItemDescriptor	item,none,mana,1,0,0,potion_mana		; mana potion

	buildItemDescriptor	head,none,protect,1,0,0,helmet_iron		; iron helmet
	buildItemDescriptor	neck,none,protect,1,0,0,necklace_silver		; iron gorget
	buildItemDescriptor	torso,none,protect,1,0,0,chest_iron		; iron shirt
	buildItemDescriptor	legs,none,protect,1,0,0,legs_iron		; iron pants

	buildItemDescriptor	finger,none,protect,1,restore,1,ring_silver	; iron ring

	buildItemDescriptor	weapon,normal,melee,1,0,0,sword_iron		; iron sword

	buildItemDescriptor	weapon,fireball,magic,1,0,0,book_black_plain	; fireball spell
	buildItemDescriptor	weapon,1,magic,1,0,0,book_brown_plain		; ??? spell
