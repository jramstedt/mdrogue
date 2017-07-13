	include 'objects/objecttable.asm'

displaySprite
	rts

deleteObject
	moveq	#(obDataSize/sizeLong), d0
	moveq	#0, d1
@loop
	move.l	d1, (a0)+
	dbra d0, @loop
	rts

findFreeObject
	lea.l	gameObjects,a2
	move.w	#127,d0	; see memorymap.asm, max 128 game objects
@loop
	tst.b	(a2)
	beq.s	@found
	lea	obDataSize(a2), a2
	dbra d0, @loop
	
@found
	rts