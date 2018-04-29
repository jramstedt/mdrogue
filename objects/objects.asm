	include 'objects/objecttable.asm'

; $80,$80 top left 
; $1BF,$15F
; width $13F = 319
; height $DF = 223
processObjects
	move.b	#0, spriteCount

	lea.l	gameObjects, a0
	move.w	#127,d7	; see memorymap.asm, max 128 game objects
@loop
	moveq	#0,	d0
	move.b	obClass(a0), d0
	beq.s	@skip
	lsl.w	#2, d0	; index to pointer

	movea.l	objectsOrigin-sizeLong(pc,d0.w), a2 ; class start at 1, decrement address by one long
	jsr		(a2)	; jump to object code

@skip
	lea	obDataSize(a0), a0
	dbra d7, @loop
	rts

displaySprite
	addq.l	#1, spriteCount
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
	move.w	#127,d0	; see memorymap.asm, max 128 game objects
@loop
	tst.b	(a2)
	beq.s	@found
	lea	obDataSize(a2), a2
	dbra d0, @loop
	
@found
	rts