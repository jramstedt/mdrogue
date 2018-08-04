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
obClass		rs.b	1	; Class & Subclass nibbles
obState		rs.b	1
obRender	rs.w	1	; HRYX
obX			rs.w	1	; FFF.F
obY			rs.w	1	; FFF.F
obVelX		rs.w	1	; FFF.F
obVelY		rs.w	1	; FFF.F
obWidth		rs.b	1
obHeight	rs.b	1
obAnim		rs.w	1	; animation number
						; F000 15 animation
						; 0FC0 64 animation index
						; 003F 64 frame
obFrameTime	rs.b	1   ; vblanks left until next frame
obCollision	rs.b	1
obVRAM		rs.w	1	; VRAM address for patterns
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

; VRAM hole for memory manager
			rsreset
vrmNext		rs.l	1
vrmStart	rs.w	1	; in patterns ($20 bytes)
vrmEnd		rs.w	1	; in patterns ($20 bytes)
vrmDataSize	equ		__RS

; System stuff
			rsset	ramStartAddress
hblank_counter		rs.l	1
vblank_counter		rs.l	1

dma_queue			rs.w	7*20
dma_queue_pointer	rs.l	1

vrm_list			rs.b	sDataSize*10
vrm_first			dc.l	vrm_list

; Game globals
gameObjects			rs.b	obDataSize*128

; 128 sprites max. 80 can be rendered. 20 per line or 320px

spriteAttrTable		rs.b 	sDataSize*128	; RAM buffer for sprite attribute table
;spriteOrder			rs.b	80				; Sorted sprites (for linked list indexes)

spriteCount			rs.b	1				; number of sprites to render
fontVRAMAddress		rs.w	1				; address of font patterns in VRAM
levelVRAMAddress	rs.w	1				; address of level patters in VRAM

scrollBuffer		rs.w	40				; Used on map scrolling DMA. Maximum of H40 and V30.