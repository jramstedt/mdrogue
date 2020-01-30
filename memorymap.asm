sizeByte		equ	$01
sizeWord		equ	$02
sizeLong		equ	$04

sizeSpriteDesc		equ	sDataSize
sizePattern		equ	$20
sizePalette		equ	$20

ramStartAddress		equ	$00FF0000
stackStartAddress	equ	$00FFFFFE

; gameobject variables
			rsreset
obClass			rs.b	1	; Class & Subclass nibbles
obState			rs.b	1
obX			rs.w	1	; 13.3
obY			rs.w	1	; 13.3
obVelX			rs.w	1	; 8.8
obVelY			rs.w	1	; 8.8
obAnim			rs.w	1	; animation number
					; F000 15 animation
					; 0FC0 64 animation index
					; 003F 64 frame
obFrameTime		rs.b	1	; vblanks left until next frame
obRadius		rs.b	1	; 8.0
obPhysics		rs.b	1	; %0000000K
					; K = kinematic, movable, does not respond to collision
obCollision		rs.b	1	; F.F = Groups.Mask
obRender		rs.b	0	; %PLLVHXXX $FF
obVRAM			rs.w	1	; P = priority
					; LL = palette
					; V = vertical flip
					; H = horizontal flip
					; XXX $FF = VRAM pattern number (address / 32)
obClassData		rs.b	32-__RS
obDataSize		equ	__RS	; 32 bytes

; camera variables
			rsreset
camX			rs.w	1	; 
camY			rs.w	1	; 
camXprev		rs.w	1	; 
camYprev		rs.w	1	;
camDataSize		equ		__RS

; sprite attributes
			rsreset
sVpos			rs.w	1	; 000000VVVVVVVVVV
sSize			rs.b	1	; 0000HHVV
sLinkData		rs.b	1	; 0XXXXXXX
sRender			rs.w	1	; PCCVHNNNNNNNNNNN
sHpos			rs.w	1	; 000000HHHHHHHHHH
sDataSize		equ		__RS

; VRAM MAPPING

; VRAM hole for memory manager
			rsreset
vrmNext			rs.l	1
vrmStart		rs.w	1	; in patterns ($20 bytes)
vrmEnd			rs.w	1	; in patterns ($20 bytes)
vrmDataSize		equ	__RS


; FFFF8000 - FFFFFFFF -> address can be save as word and sign extended on read

; System stuff
			rsset	ramStartAddress+$FF008000
dma_queue		rs.w	7*20
dma_queue_pointer	rs.w	1

vrm_list		rs.b	sDataSize*10
vrm_first		dc.l	vrm_list

pad1State		rs.b	1	;  SACBRLDU
pad2State		rs.b	1	;  SACBRLDU

lcgSeed			rs.l	1

			rsset	ramStartAddress

; 0000 - 7FFF -> address can be save as word

; Game globals
mainCamera		rs.b	camDataSize
gameObjectsLen		equ	128
gameObjects		rs.b	obDataSize*gameObjectsLen

; 128 sprites max. 80 can be rendered. 20 per line or 320px
spriteAttrTable		rs.b 	sDataSize*gameObjectsLen	; RAM buffer for sprite attribute table
;spriteOrder		rs.b	80		; Sorted sprites (for linked list indexes)

spriteCount		rs.b	1		; number of sprites to render
fontVRAMAddress		rs.w	1		; address of font patterns in VRAM

loadedLevelIndex	rs.b	1		; index of loaded level
levelVRAMAddress	rs.w	1		; address of level patters in VRAM

horBufferLen		equ	41
horBuffer		rs.w	horBufferLen	; Used on map scrolling DMA. H40.

verBufferLen		equ	29
verBuffer		rs.w	verBufferLen	; Used on map scrolling DMA. V28.


textScrap		rs.b	10