sizeByte			equ 0x01
sizeWord			equ 0x02
sizeLong			equ 0x04

sizeSpriteDesc		equ 0x08
sizePattern			equ 0x20
sizePalette			equ 0x20

ramStartAddress		equ	0x00FF0000
stackStartAddress	equ	0x00FFE000

; System stuff
hblank_counter		equ ramStartAddress
vblank_counter		equ (hblank_counter+sizeLong)

; Game globals