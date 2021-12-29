objectsOrigin
ptrPlayer	dc.w	objPlayer
ptrCollider	dc.w	objCollider
ptrBullet	dc.w	objBullet

idPlayer	equ	((ptrPlayer-objectsOrigin)/sizeWord)+1
	include 'objects/01player.asm'
idCollider	equ	((ptrCollider-objectsOrigin)/sizeWord)+1
	include 'objects/02collider.asm'
idBullet	equ	((ptrBullet-objectsOrigin)/sizeWord)+1
	include 'objects/03bullet.asm'