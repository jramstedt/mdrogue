incLevel	MACRO
\0Palette	incbin	\1
\0Patterns	incbin	\2
		incbin	\3
\0PatternLen	equ	(filesize(\2)+filesize(\3))/sizePattern
\0TilemapB	incbin	\4
\0TilemapA	incbin	\5
\0Collision	incbin	\6
	EVEN
	ENDM

buildLevelDescriptor	MACRO	width, height
	dc.l	\0Palette
	dc.l	\0Patterns
	dc.w	\0PatternLen
	dc.b	\width
	dc.b	\height
	dc.l	\0TilemapB
	dc.l	\0TilemapA
	dc.l	\0Collision
	ENDM


; level description
		rsreset
lvlPalette		rs.l	1
lvlPattern		rs.l	1
lvlPatternLen		rs.w	1
lvlWidth		rs.b	1	; in chunks
lvlHeight		rs.b	1	; in chunks
lvlPlaneBTiles		rs.l	1
lvlPlaneATiles		rs.l	1
lvlCollision		rs.l	1
levelDesc	equ	__rs

lvlChunkSize	equ	32	; number of patterns in level chunk at at each axis
lvlChunkArea	equ	lvlChunkSize*lvlChunkSize

	EVEN

	incLevel.testLevel 'assets/testlevel/planeB.pal','assets/testlevel/planeBpatterns.bin','assets/testlevel/planeApatterns.bin','assets/testlevel/planeBtilemap.bin','assets/testlevel/planeAtilemap.bin','assets/testlevel/col.data.bin'

levelDescriptions
	buildLevelDescriptor.testLevel 4, 2

; Collision bit per pattern
;		CY	CX	Y	X
; Size		2	4	32	32
; Stride	512	128	4	1/8	Bytes

; Collision type nibble per pattern
;		CY	CX	Y	X
; Size		2	4	32	32
; Stride	2048	512	16	4/8	Bytes

; Collision types
; 0 0000 Free
; 1 0001 Solid
; 2 0010 NW slope
; 3 0011 NE slope
; 4 0100 SE slope
; 5 0101 SW slope
