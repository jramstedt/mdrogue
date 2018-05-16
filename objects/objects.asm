; $80,$80 top left 
; $1BF,$15F
; width $13F = 319
; height $DF = 223
processObjects
	move.b	#0, spriteCount

	lea.l	gameObjects, a0
	move.w	#127,d7		; see memorymap.asm, max 128 game objects
@loop
	move.l d7, -(sp)	; push object counter to stack
	moveq	#0,	d0
	move.b	obClass(a0), d0
	beq.s	@skip
	lsr.b	#4, d0		; get class from nibble
	lsl.w	#2, d0		; index to pointer

	movea.l	objectsOrigin-sizeLong(pc,d0.w), a2 ; class start at 1, decrement address by one long
	jsr		(a2)		; jump to object code

@skip
	lea	obDataSize(a0), a0
	move.l	(sp)+, d7	; pop object counter from stack
	dbra d7, @loop

	moveq	#0,	d0
	move.b	spriteCount, d0
	beq	@exit
	lsl	#2, d0	; 4 words per sprite
	queueDMATransfer #spriteAttrTable, #vdp_map_sat, d0

@exit
	rts

; input:
;	a0 object
displaySprite
	lea	spriteAttrTable, a2
	movea.l	obROM(a0), a3	; rom address
	movea.l	(a3), a4		; a4 is patterns start in ROM

	moveq	#0, d0
	move.b	obAnim(a0), d0	; get animation index
	lsl.w	#1, d0	; convert index to offset (word per index)

	move.w	sizeLong(a3, d0), d0	; d0 is offset to metasprite data from obROM	
	lea		(a3, d0), a3	; a3 is metasprite data address

	moveq	#0, d3
	move.b	obFrame(a0), d3
	beq	@drawSprites

@findFrame
	move.w	(a3)+, d0		; d0 is	sprite count
	mulu	#10, d0
	adda	d0, a3
	dbra	d3,	@findFrame

@drawSprites
	move.w	(a3)+, d0		; d0 is	sprite count
	subq	#1, d0			; decrement one for loop

	moveq	#0, d2
	move.w	obVRAM(a0), d2
	lsr	#5, d2	;	address to pattern number

@drawSprite
	addq.b	#1, spriteCount

	movem.w	(a3)+, d3-d7

	add	#$EF, d3	; screen center vertical
	move.b	spriteCount, d4
	add	d2, d5	; add real VRAM pattern id to dplc relative tile position
	add	#$11F, d6	; screen center horizontal

	; write to spriteAttrTable
	move.w	d3, (a2)+
	move.w	d4, (a2)+
	move.w	d5, (a2)+
	move.w	d6, (a2)+

	; TODO move to animation code
	move.w	d7, d1
	and.w	#$000F, d1
	addq	#1, d1
	lsl	#4, d1	; lsl 5 + lsr 1 = lsl 4. Amount of words for all patterns

	and.w	#$7FF0, d7
	lsl	#1, d7	; lsr 4 + lsl 5 = lsl 1. Byte offset to metasprite pattern data
	lea	(a4, d7), a5	; a4 is ROM address for start of metasprite pattern data

	lsl	#5, d5
	move.l d5, a6

	queueDMATransfer a5, a6, d1
	; TODO END

	dbra	d0, @drawSprite

	rts

; input:
;	a0 object
;	a6 animation table
animateSprite
	subq	#1, obFrameTime(a0)
	bmi		@nextFrame
	rts

@nextFrame
	moveq	#0,	d0
	move.b	obAnim(a0), d0
	lsl.w	#1, d0
	move	(a6, d0.w),	a6	; a6 is animation script address

	move.b	(a6)+, d0	; d0 is animation speed
	add	d0, obFrameTime(a0)

	adda	obFrame(a0), a6

	rts

deleteObject
	moveq	#(obDataSize/sizeLong), d0
	moveq	#0, d1
@loop
	move.l	d1, (a0)+
	dbra d0, @loop
	rts

findFreeObject
	lea.l	gameObjects, a2
	move.w	#127,d0		; see memorymap.asm, max 128 game objects
@loop
	tst.b	(a2)
	beq.s	@found
	lea	obDataSize(a2), a2
	dbra d0, @loop
	
@found
	rts
