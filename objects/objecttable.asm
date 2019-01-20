objectsOrigin
ptrPlayer	dc.l	objPlayer

idPlayer	equ	((ptrPlayer-objectsOrigin)/sizeLong)+1
	include 'objects/01player.asm'
