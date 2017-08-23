sizeByte			equ $01
sizeWord			equ $02
sizeLong			equ $04

sizeSpriteDesc		equ sDataSize
sizePattern			equ $20
sizePalette			equ $20

ramStartAddress		equ	$00FF0000
stackStartAddress	equ	$00FFE000

; gameobject variables
			rsreset
obClass		rs.b	1
obSubclass	rs.b	1
obState		rs.b	1
obRender	rs.w	1	; HRYX
obX			rs.w	1	; FFF.F
obY			rs.w	1	; FFF.F
obVelX		rs.w	1	; FFF.F
obVelY		rs.w	1	; FFF.F
obWidth		rs.b	1
obHeight	rs.b	1
obAnim		rs.b	1	; animation number
obFrame		rs.b	1   ; frame in animation
obFrameTime	rs.b	1   ; vblanks left until next frame
obCollision	rs.b	1
obClassData	rs.b	32-__RS
obDataSize	equ		__RS	; 32 bytes

; sprite attributes
			rsreset
sVpos		rs.w	1	; 000000VVVVVVVVVV
sSize		rs.b	1	; 0000HHVV
sLinkData	rs.b	1	; 0XXXXXXX
sRender		rs.w	1	; PCCVHNNNNNNNNNNN
sHpos		rs.w	1	; 000000HHHHHHHHHH
sDataSize	equ		__RS

; VRAM MAPPING

; System stuff
			rsset	ramStartAddress
hblank_counter		rs.l	1
vblank_counter		rs.l	1

dma_queue			rs.w	7*20
dma_queue_pointer	rs.l	1

; Game globals
gameObjects			rs.b	obDataSize*128
spriteCount			rs.b	1				; number of sprites to render
spriteAttrTable		rs.b 	sDataSize*80	; RAM buffer for sprite attribute table
spriteOrder			rs.b	80				; Sorted sprites (for linked list indexes)

