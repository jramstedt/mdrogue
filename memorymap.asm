sizeByte		equ	$01
sizeWord		equ	$02
sizeLong		equ	$04

sizeSpriteDesc		equ	8
sizePattern		equ	$20
sizePalette		equ	$20

ramStartAddress		equ	$00FF0000
stackStartAddress	equ	$FFFF8000 ; was 00FFFFFE

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
obClassData		rs.b	32-__rs
obDataSize		equ	__rs	; 32 bytes

classDataValidate	MACRO
			IF __rs>obDataSize
				INFORM	3, "Class data overflow (%h/%h)", __rs, obDataSize
			endif
			ENDM

; Linked list node
			rsreset
llNext			rs.w	1
llPrev			rs.w	1
llStatus		rs.b	0	; 24-bit address, MSB 8 bits are ignored
llPtr			rs.l	1
llNodeSize		equ	__rs

; camera variables
			rsreset
camX			rs.w	1	; 16.0
camY			rs.w	1	; 16.0
camXprev		rs.w	1	; 16.0
camYprev		rs.w	1	; 16.0
camDataSize		equ		__rs

; sprite attributes
			rsreset
sVpos			rs.w	1	; 000000VVVVVVVVVV
sSize			rs.b	1	; 0000HHVV
sNext			rs.b	1	; 0XXXXXXX
sRender			rs.w	1	; PCCVHNNNNNNNNNNN
sHpos			rs.w	1	; 000000HHHHHHHHHH
sDataSize		equ		__rs

; VRAM MAPPING
; VRAM hole for memory manager
			rsreset
vrmNext			rs.l	1
vrmStart		rs.w	1	; in patterns ($20 bytes)
vrmEnd			rs.w	1	; in patterns ($20 bytes)
vrmDataSize		equ	__rs

; https://www.muchen.ca/documents/CPEN412/2020-01-09-Lecture-2.html
; 24-bit address, MSB 8 bits are ignored
; FFFF8000 - FFFFFFFF -> address can be save as word and sign extended on read
; Address instructions such as MOVEA and ADDA sign extends words

; System stuff
			rsset	ramStartAddress+$FF008000
SlotSize		equ	(8*sizeWord)
SlotCount		equ	20
dma_queue		rs.b	SlotSize*SlotCount
dma_queue_pointer	rs.w	1

vrm_list		rs.b	vrmDataSize*12
vrm_first		equ	vrm_list

pad1State		rs.b	1	;  SACBRLDU
pad2State		rs.b	1	;  SACBRLDU

lcgSeed			rs.l	1

vdp1rState		rs.w	1

; Game object lists
maxGameObjects		equ	512
allGameObjects		rs.b	obDataSize*maxGameObjects		; Game Objects
allGameObjectNodes	rs.b	llNodeSize*maxGameObjects		; Nodes for Doubly linked lists below, indexing corresponds to allGameObjects

hiGameObjectsFirst	rs.w	1	; Doubly linked list
hiGameObjectsLast	rs.w	1	; hi priority objects, updated every frame

;lowGameObjectsFirst	rs.w	1	; Doubly linked list 
;lowGameObjectsLast	rs.w	1	; low priority objects, one per frame
;lowGameObjectsCurrent	rs.w	1	; Last processed node in lowGameObjectsHead, must be updated if node is removed!

freeGameObjectsFirst	rs.w	1	; Singly linked list head for nodes of free objects
gameObjectsMaximum	rs.w	1	; Maximum count of used gameObjects. Use as index if gameObjectsFree is empty

			IF __rs>$FFFFFFFF
				INFORM	3, "RAM overflow (%h)", __rs
			endif

			rsset	ramStartAddress

; FF0000 - FF7FFF

; Game globals

mainCamera		rs.b	camDataSize

; 128 sprites max. 80 can be rendered. 20 per line or 320px
spriteAttrTable		rs.b 	sDataSize*128	; RAM buffer for sprite attribute table
;spriteOrder		rs.b	80		; Sorted sprites (for linked list indexes)

spriteCount		rs.b	1		; number of sprites to render
fontVRAMAddress		rs.w	1		; address of font patterns in VRAM

loadedLevelAddress	rs.l	1		; address of loaded level description
levelVRAMAddress	rs.w	1		; address of level patters in VRAM

horBufferLen		equ	41
horBuffer		rs.w	horBufferLen	; Used on map scrolling DMA. H40.

verBufferLen		equ	31
verBuffer		rs.w	verBufferLen	; Used on map scrolling DMA. V30.

textScrap		rs.b	10

; STACK!
