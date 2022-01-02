; $80,$80 top left 
; $1BF,$15F
; width $13F = 319
; height $DF = 223
processObjects	MODULE
	move.b	#0, spriteCount

	lea.l	gameObjects, a0
	moveq	#0, d0
@loop
	move.b	obClass(a0), d0
	beq.s	@skip

	andi.b	#$F0, d0			; mask class
	lsr.b	#3, d0				; class to word pointer

	lea	objectsOrigin-sizeWord.w, a2	; class start at 1, decrement address by one word
	move.w	(a2,d0.w), a2
	jsr	(a2)				; jump to object code

	moveq	#0, d0
@skip
	lea	obDataSize(a0), a0
	cmpa.l	#(gameObjects+(obDataSize*gameObjectsLen)), a0
	blo.s	@loop

	move.b	spriteCount, d0
	beq	@exit
	add.w	d0, d0				; lsl.w	#2, d0
	add.w	d0, d0				; 4 words per sprite
	queueDMATransfer #spriteAttrTable, #vdp_map_sat, d0

	move.b	spriteCount, d0
	sub.b	#1, d0
	lsl.w	#3, d0				; 8 bytes per sprite

@exit
	lea	spriteAttrTable, a0
	add	d0, a0
	move.b	#0, sLinkData(a0)

	rts
	MODEND

; input:
;	a0 object
;	a6 rom address
displaySprite	MODULE
	movea.l	(a6), a4		; a4 is patterns start in ROM

	move.w	#$00F0, d0
	and.b	obAnim(a0), d0		; get animation number
	lsr.b	#4-1, d0		; convert number to offset (word per pointer)

	move.w	sizeLong(a6, d0.w), d0	; d0 is offset to metasprite data from rom address
	lea	(a6, d0.w), a3		; a3 is metasprite data address

	moveq	#$3F, d3
	and.b	obAnim+1(a0), d3	; get frame number
	beq	@drawSprites

	subq	#1, d3			; decrement one for loop
@findFrame
	move.w	(a3)+, d0		; d0 is	sprite count

	; sDataSize + 2 dplc data = 10 bytes

	;mulu	#10, d0
	move.w	d0, d2
	lsl.w	#3, d0			; * 8
	add.w	d2, d2			; * 2
	add.w	d2, d0			; *= 10

	adda	d0, a3
	dbra	d3, @findFrame

@drawSprites
	lea	spriteAttrTable, a2
	move.b	spriteCount, d0
	lsl.w	#3, d0			; sprite attribute is 8 bytes
	add	d0, a2

	move.w	(a3)+, d0		; d0 is	sprite count
	subq.w	#1, d0			; decrement one for loop
@drawSprite
	addq.b	#1, spriteCount

	movem.w	(a3)+, d3-d7		; d3, d4, d5, d6, d7

	lea.l	mainCamera, a5
	move.l	#$80, d2		; offset to upper left corner

	; TODO Cull sprites that are out of screen

	; X flip
	btst.b	#3, obRender(a0)
	beq.s	@x			; not set, skip flip
	neg.w	d6
	move.w	d4, d1
	lsr.w	#7, d1			; to multiples of eight
	andi.b	#%11000, d1
	addi.b	#8, d1
	sub.w	d1, d6

@x	move.w	obX(a0), d1
	asr.w	#3, d1
	addx.w	d2, d1
	sub.w	camX(a5), d1
	add.w	d1, d6
	
	;bne.s	*+4
	;dbra	d0, @drawSprite	; if 0, dont draw (will mask), TODO not needed when culling

	; Y flip
	btst.b	#4, obRender(a0)
	beq.s	@y			; not set, skip flip
	neg.w	d3
	move.w	d4, d1
	lsr.w	#5, d1			; to multiples of eight
	andi.b	#%11000, d1
	addi.b	#8, d1
	sub.w	d1, d3

@y	move.w	obY(a0), d1
	asr.w	#3, d1
	addx.w	d2, d1
	sub.w	camY(a5), d1
	add.w	d1, d3

	;lea.l	mainCamera, a5
	;move.l	obX(a0), d1	; XXXX YYYY
	;and.l	#$FFF8FFF8, d1
	;lsr.l	#3, d1		; convert to full pixels
	;sub.l	camX(a5), d1	; XXXX YYYY
	
	move.b	spriteCount, d4
	add.w	obVRAM(a0), d5		; add real VRAM pattern id to dplc relative tile position

	; write to spriteAttrTable
	movem.w	d3-d6, (a2)
	addi	#sDataSize, a2

	; DMA
	lsl	#5, d5			; 32 bytes per pattern
	move.l	d5, d6

	move.w	d7, d5
	and.w	#$7FF0, d5
	add.w	d5, d5			; lsr 4 + lsl 5 = lsl 1. Byte offset to metasprite pattern data
	add.l	a4, d5

	and.w	#$000F, d7
	addq	#1, d7
	lsl.w	#4, d7			; lsl 5 + lsr 1 = lsl 4. Amount of words for all patterns
	jsr	_queueDMATransfer

	dbra	d0, @drawSprite

	rts
	MODEND

; input:
;	a0 object
;	a6 animation table
; trash:
;	d0, d1, d2, a5, a6
animateSprite	MODULE
	subq.b	#1, obFrameTime(a0)
	bmi	@processAnim
	rts

@processAnim
	moveq	#0, d0
	move.b	obAnim(a0), d0	; get animation number
	and.b	#$F0, d0
	lsr.b	#4-1, d0	; convert number to table offset (word per pointer)
	move	(a6, d0.w), d0	; d0 is offset to animation data
	lea	(a6, d0.w), a6	; a5 is animation script address

	moveq	#0, d2
	move.b	(a6)+, d2	; d2 is animation speed

@nextFrame
	move.w	obAnim(a0), d0
	move	d0, d1	; d1 is animation data

	and.w	#$0FC0, d0
	lsr.w	#6, d0	; d0 is animation index
	move.b	(a6, d0.w), d0	; d0 is frame or opcode
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
deleteObject	MODULE
	moveq	#(obDataSize/sizeLong)-1, d0
	moveq	#0, d1
@loop
	move.l	d1, (a0)+
	dbra	d0, @loop
	rts
	MODEND

findFreeObject	MODULE
	lea.l	gameObjects, a2
	move.w	#127, d0	; see memorymap.asm, max 128 game objects
@loop
	tst.b	(a2)
	beq.s	@found
	lea	obDataSize(a2), a2
	dbra	d0, @loop

@found
	rts
	MODEND
