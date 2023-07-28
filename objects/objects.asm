; $80,$80 top left 
; $1BF,$15F
; width $13F = 319
; height $DF = 223
processObjects	MODULE
	move.b	#0, spriteCount

	lea.l	hiGameObjectsFirst, a6

@processNext
	tst.w	llNext(a6)			; is last?
	beq.s	@dmaSprites

	movea.w	llNext(a6), a6
	tst.b	llStatus(a6)
	beq.s	@processNext			; deleted, skip

	movea.l	llPtr(a6), a0			; a0 is game object
	move.b	obClass(a0), d0
	beq.s	@processNext

	andi.w	#$00F0, d0			; mask class
	lsr.b	#3, d0				; class to word pointer
	lea.l	objectRoutines-sizeWord.w, a1	; class start at 1, decrement address by one word
	move.w	(a1, d0.w), a1			; load object code address

	movem	d0-d7/a0-a6, -(sp)
	jsr	(a1)				; jump to object code
	movem	(sp)+, d0-d7/a0-a6

	bra	@processNext

@dmaSprites
	; DMA sprite table
	moveq	#0, d0
	move.b	spriteCount, d0
	beq	@exit

	lea	spriteAttrTable, a0

	add.w	d0, d0				; lsl.w	#2, d0
	add.w	d0, d0				; 4 words per sprite
	queueDMATransfer a0, #vdp_map_sat, d0

	add.w	d0, d0				; 8 bytes per sprite

@exit
	; TODO spriteAttrTable is linked list. Handle adding sprites better (metasprite links?, sorting?)
	move.b	#0, sNext-sDataSize(a0, d0.w)	; pointer to next must be zero on last sprite.

	rts
	MODEND

;
cleanupObjectList	MODULE
	lea.l	hiGameObjectsFirst, a0

@processNext
	tst.w	llNext(a0)			; is last?
	beq.s	@exit

	movea.w	llNext(a0), a0			; node

	tst.b	llStatus(a0)
	bne.s	@processNext			; not deleted

	; remove from hi
	movea.w	llNext(a0), a1
	movea.w	llPrev(a0), a2

	tst.w	llPrev(a0)
	beq.s	*+8			; Was first in list, skip updating previous
	move.w	a1, llNext(a2)
	bra.s	*+8			; Was not first, skip updating hiGameObjectsFirst
	move.w	a1, hiGameObjectsFirst

	tst.w	llNext(a0)
	beq.s	*+8			; Was last in list, skip updating next
	move.w	a2, llPrev(a1)
	bra.s	*+8			; Was not last, skip updating hiGameObjectsLast
	move.w	a2, hiGameObjectsLast

	; insert into free objects
	lea.l	freeGameObjectsFirst, a1
	tst.w	(a1)
	bne.s	@insert

	; free list is empty
	move.w	#0, llNext(a0)
	move.w	#0, llPrev(a0)
	move.w	a0, freeGameObjectsFirst

	; FIXME this will fail if first is removed, should be the "move.w	a2, XXXX" target (see above)
	movea.l	a2, a0			; reprocess previous node because it has changed
	bra	@processNext

@insert
	movea.w	(a1), a1		; a1 is node address of first

	move.w	llPrev(a1), d0		; d0 should be zero
	move.w	a0, llPrev(a1)
	move.w	a1, llNext(a0)
	move.w	d0, llPrev(a0)
	move.w	a0, freeGameObjectsFirst

	; FIXME this will fail if first is removed, should be the "move.w	a2, XXXX" target (see above)
	movea.l	a2, a0			; reprocess previous node because it has changed
	bra	@processNext

@exit
	rts
	MODEND

; input:
;	a0 object
;	a5 rom address
displaySprite	MODULE
	move.w	#$00F0, d0
	and.b	obAnim(a0), d0		; get animation number
	lsr.b	#4-1, d0		; convert number to offset (word per pointer)

	move.w	sizeLong(a5, d0.w), d0	; d0 is offset to metasprite data from rom address
	lea	(a5, d0.w), a3		; a3 is metasprite data address

	moveq	#$3F, d3
	and.b	obAnim+1(a0), d3	; get frame number
	beq	@drawSprites

	subq	#1, d3			; decrement one for loop
@findFrame
	move.w	(a3)+, d0		; d0 is	sprite count

	; sDataSize + 2 dplc data = 10 bytes
	; TODO change data format to include frame offsets

	move.w	d0, d2
	add.w	d2, d2			; * 2
	lsl.w	#3, d0			; * 8
	add.w	d2, d0			; = * 10

	adda	d0, a3
	dbra	d3, @findFrame

@drawSprites
	lea	spriteAttrTable, a2
	move.b	spriteCount, d0
	lsl.w	#3, d0			; sprite attribute is 8 bytes
	adda	d0, a2

	lea	mainCamera, a4
	move.l	#$80, d2		; offset to upper left corner of screen area

	move.w	(a3)+, d0		; d0 is	sprite count
	subq.w	#1, d0			; decrement one for loop
@drawSprite
	movem.w	(a3)+, d3-d7		; d3, d4, d5, d6, d7

	; X flip
	btst.b	#3, obRender(a0)
	beq.s	@x			; not set, skip flip
	neg.w	d6
	move.w	d4, d1			; get H size
	lsr.w	#10-3, d1		; move to low nibble and *8 (to pixels)
	andi.b	#%11000, d1		; clean
	addi.b	#8, d1			; right side of pattern
	sub.w	d1, d6

@x	move.w	obX(a0), d1
	asr.w	#3, d1
	addx.w	d2, d1
	sub.w	camX(a4), d1
	add.w	d1, d6

	; cull X
	move.w	d6, d1
	subi.w	#$60, d1
	ble	@nextSprite
	subi.w	#$160, d1
	bge	@nextSprite

	; Y flip
	btst.b	#4, obRender(a0)
	beq.s	@y			; not set, skip flip
	neg.w	d3
	move.w	d4, d1
	lsr.w	#8-3, d1		; to multiples of eight
	andi.b	#%11000, d1
	addi.b	#8, d1
	sub.w	d1, d3

@y	move.w	obY(a0), d1
	asr.w	#3, d1
	addx.w	d2, d1
	sub.w	camY(a4), d1
	add.w	d1, d3

	; cull Y
	move.w	d3, d1
	subi.w	#$60, d1
	ble	@nextSprite
	subi.w	#$100, d1
	bge	@nextSprite

	; prepare spriteAttrTable
	addq.b	#1, spriteCount
	move.b	spriteCount, d4
	add.w	obVRAM(a0), d5		; add real VRAM pattern id to dplc relative tile position

	; write to spriteAttrTable
	movem.w	d3-d6, (a2)
	adda	#sDataSize, a2

	; DMA
	lsl	#5, d5			; 32 bytes per pattern
	move.l	d5, d6

	move.w	d7, d5
	and.w	#$7FF0, d5
	add.w	d5, d5			; lsr 4 + lsl 5 = lsl 1. Byte offset to metasprite pattern data
	add.l	(a5), d5

	and.w	#$000F, d7
	addq	#1, d7
	lsl.w	#4, d7			; lsl 5 + lsr 1 = lsl 4. Amount of words for all patterns
	jsr	_queueDMATransfer

@nextSprite
	dbra	d0, @drawSprite

	rts
	MODEND

; input:
;	a0 object
;	a5 animation table
; trash:
;	d0, d1, d2, a5
animateSprite	MODULE
	subq.b	#1, obFrameTime(a0)
	bmi	@processAnim
	rts

@processAnim
	moveq	#0, d0
	move.b	obAnim(a0), d0	; get animation number
	and.b	#$F0, d0
	lsr.b	#4-1, d0	; convert number to table offset (word per pointer)
	move	(a5, d0.w), d0	; d0 is offset to animation data
	lea	(a5, d0.w), a5	; a5 is animation script address

	moveq	#0, d2
	move.b	(a5)+, d2	; d2 is animation speed

@nextFrame
	move.w	obAnim(a0), d0
	move	d0, d1	; d1 is animation data

	and.w	#$0FC0, d0
	lsr.w	#6, d0	; d0 is animation index
	move.b	(a5, d0.w), d0	; d0 is frame or opcode
	bmi	@processOpcode

	add.b	d2, obFrameTime(a0)

	and.w	#$FFC0, d1
	or.b	d0, d1
	add	#64, d1 ; increase animation index
	move.w	d1, obAnim(a0)

	rts

@processOpcode
	and.w	#$F03F, d1
	move.w	d1, obAnim(a0)
	bra	@nextFrame
	MODEND

; input:
;	a0 object
; trashes
;	a0, a1, a2
freeObject	MODULE
	; calculate node address
	move.l	a0, d0
	subi.l	#allGameObjects, d0
	lsr.w	#2, d0			; NOTE obDataSize is 32 bytes, llNodeSize is 8 bytes
	lea.l	allGameObjectNodes, a0

	move.b	#$00, llStatus(a0, d0.w)	; Mark for removal
	rts

	MODEND

; output:
;	a2 object
; trashes:
;	d0, a0, a1, a2
findFreeObject	MODULE
	movem.l	d0/a0-a1, -(sp)

	lea.l	freeGameObjectsFirst, a0
	tst.w	(a0)
	bne.s	@useFreeNode

	; Free game objects is empty
	; Allocate new node
	moveq	#0, d0
	move.w	gameObjectsMaximum, d0
	add.w	#1, gameObjectsMaximum

	lea.l	allGameObjectNodes, a0
	lea.l	allGameObjects, a2

	lsl.l	#3, d0		; NOTE llNodeSize is 8 bytes
	adda.l	d0, a0		; a0 is address of linked list node

	lsl.l	#2, d0		; NOTE obDataSize is 32 bytes, shift by 2 more to get 3+2=5
	adda.l	d0, a2		; a2 is address of free game object

	move.l	a2, llPtr(a0)

@insertToHi
	moveq	#0, d0

	lea.l	hiGameObjectsLast, a1
	tst.w	(a1)
	movea.w	(a1), a1	; a1 is node address
	beq.s	@emptyHi	; if empty don't update last node

	move.w	llNext(a1), d0
	move.w	a0, llNext(a1)

@insert
	move.w	a1, llPrev(a0)
	move.w	d0, llNext(a0)
	move.w	a0, hiGameObjectsLast

	; NOTE obDataSize is 32 bytes
	moveq	#0, d0
	movea.l	a2, a0
	REPT obDataSize/sizeLong
	move.l	d0, (a0)+
	ENDR

	movem.l	(sp)+, d0/a0-a1
	rts

@useFreeNode
	movea.w	(a0), a0	; a0 is node address
	movea.l	llPtr(a0), a2
	move.b	#$FF, llStatus(a0)

	; move next free to first
	move.w	llNext(a0), freeGameObjectsFirst

	bra.s	@insertToHi

@emptyHi
	move.w	a0, hiGameObjectsFirst

	bra.s 	@insert

	MODEND

initGameObjects	MODULE
	clr.w	gameObjectsMaximum
	rts
	MODEND
