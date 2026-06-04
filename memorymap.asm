sizeByte		equ	$01
sizeWord		equ	$02
sizeLong		equ	$04

sizeSpriteDesc		equ	8
sizePattern		equ	$20
sizePalette		equ	$20

ramStartAddress		equ	$00FF0000
stackStartAddress	equ	$FFFFFFFC ; was 00FFFFFE

; game object variables
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

			MACRO classDataValidate
			assert __RS<obDataSize Data overflow (\<$__RS>/\<$obDataSize>)
			ENDM

; Linked list node
			rsreset
llNext			rs.w	1
llPrev			rs.w	1
llStatus		rs.b	0
llPtr			rs.l	1	; 24-bit address, MSB 8 bits are ignored
llNodeSize		equ	__RS

; camera variables
			rsreset
camX			rs.w	1	; 16.0
camY			rs.w	1	; 16.0
camXprev		rs.w	1	; 16.0
camYprev		rs.w	1	; 16.0
camDataSize		equ		__RS

; sprite attributes
			rsreset
sVpos			rs.w	1	; 000000VVVVVVVVVV
sSize			rs.b	1	; 0000HHVV
sNext			rs.b	1	; 0XXXXXXX
sRender			rs.w	1	; PCCVHNNNNNNNNNNN
sHpos			rs.w	1	; 000000HHHHHHHHHH
sDataSize		equ		__RS

; VRAM MAPPING
; VRAM hole for memory manager
			rsreset
vrmNext			rs.l	1	; next hole in linked list
vrmStart		rs.w	1	; Word aligned VRAM address
vrmEnd			rs.w	1	; Word aligned VRAM address
vrmDataSize		equ	__RS

; https://www.muchen.ca/documents/CPEN412/2020-01-09-Lecture-2.html
; 24-bit address, MSB 8 bits are ignored
; FFFF8000 - FFFFFFFF -> address can be save as word and sign extended on read
; Address instructions such as MOVEA and ADDA sign extends words

			rsset	ramStartAddress+$FF000000	; FF0000 - FF7FFF
mainCamera		rs.b	camDataSize

; 128 sprites max. 80 can be rendered. 20 per line or 320px
spriteAttrTable		rs.b 	sDataSize*128	; RAM buffer for sprite attribute table
;spriteOrder		rs.b	80		; Sorted sprites (for linked list indexes)

spriteCount		rs.b	1		; number of sprites to render

			rs.b	1		; even address

uiVRAMAddress		rs.w	1		; address of ui patterns in VRAM

loadedLevelAddress	rs.l	1		; address of loaded level description
levelVRAMAddress	rs.w	1		; address of level patters in VRAM

horBufferLen		equ	41
horBuffer		rs.w	horBufferLen	; Used on map scrolling DMA. H40.

verBufferLen		equ	31
verBuffer		rs.w	verBufferLen	; Used on map scrolling DMA. V30.

textScrap		rs.b	10


			rsset	ramStartAddress+$FF008000	; Sign extends
vdp1rState		rs.w	1

vrm_list		rs.b	vrmDataSize*12
vrm_first		equ	vrm_list
vrm_list_end		equ	__RS

pad1State		rs.b	1	;  SACBRLDU
pad2State		rs.b	1	;  SACBRLDU
pad1Change		rs.b	1
pad2Change		rs.b	1

lcgSeed			rs.l	1

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

playerStats		rs.b	plrStatsSize
playerStatsBonus	rs.b	plrStatsSize
playerStatus		rs.b	plrStatusSize
playerInventory		rs.b	plrInventorySize

inventoryUIState	rs.b	uiStateSize

			rsset	ramStartAddress+$FF00FDE0	; Special position for DMA queue to allow 16-bit jump offset calculation
SlotCount		equ	20
dma_queue		rs.b	dmaSize*SlotCount
dma_queue_pointer	rs.w	1

; STACK!
			assert __RS<stackStartAddress,"RAM overflow to stack ($__RS)"

			assert __RS<=$FFFFFFFF,"RAM overflow ($__RS)"
