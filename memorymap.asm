sizeByte			equ $01
sizeWord			equ $02
sizeLong			equ $04

sizeSpriteDesc		equ $08
sizePattern			equ $20
sizePalette			equ $20

ramStartAddress		equ	$00FF0000
stackStartAddress	equ	$00FFE000

; gameobject variables
obClass		equ $00	;
obSubclass	equ $01	;
obState		equ	$02	;
obRender	equ	$03	; HRYX
obX			equ $05	; FFFF
obY			equ $07	; FFFF
obVelX		equ $09	; FFF.F
obVelY		equ $0B	; FFF.F
obWidth		equ	$0D	; 
obHeight	equ $0E	;
obFrame		equ $0F	;
obAnimTime	equ $10	;
obCollision	equ	$11	;

obDataSize	equ $20	; 32 bytes

; sprite attributes
sVpos		equ	$0	; 000000VVVVVVVVVV
sSize		equ	$2	; 0000HHVV
sLinkData	equ $3	; 0XXXXXXX
sRender		equ $4	; PCCVHNNNNNNNNNNN
sHpos		equ	$6	; 000000HHHHHHHHHH

sDataSize	equ	$8	; 8 bytes

; VRAM MAPPING

; System stuff
hblank_counter		equ ramStartAddress
vblank_counter		equ (hblank_counter+sizeLong)

; 32 bytes reserved

; Game globals
gameObjects			equ	ramStartAddress+32	; 4096bytes, fits 128 gameObjects
spriteCount			equ gameObjects+(4096)	; 1byte
spriteAttrTable		equ spriteCount+1		; 640bytes (8 * 80)
spriteOrder			equ	spriteAttrTable+640	; 80bytes