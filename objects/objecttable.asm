objectsOrigin
ptrPlayer	dc.w	objPlayer
ptrCollider	dc.w	objCollider

idPlayer	equ	((ptrPlayer-objectsOrigin)/sizeLong)+1
	include 'objects/01player.asm'
idCollider	equ	((ptrCollider-objectsOrigin)/sizeLong)+1
	include 'objects/02collider.asm'