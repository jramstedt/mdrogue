objectRoutines
ptrPlayer	dc.w	objPlayer
ptrCollider	dc.w	objCollider
ptrBullet	dc.w	objBullet

idPlayer	equ	((ptrPlayer-objectRoutines)/sizeWord)+1
	include 'objects/01player.asm'
idCollider	equ	((ptrCollider-objectRoutines)/sizeWord)+1
	include 'objects/02collider.asm'
idBullet	equ	((ptrBullet-objectRoutines)/sizeWord)+1
	include 'objects/03bullet.asm'