incLevel	MACRO
\0Palette	incbin	\1
\0Patterns	incbin	\2
\0PatternLen	equ	filesize(\2)/sizePattern
\0TilemapA	incbin	\3
\0TilemapB	incbin	\4
\0Collision	incbin	\5
\0CollisionType	incbin	\6
	cnop	0,2
	ENDM

buildLevelDescriptor	MACRO	width, height
	dc.l	\0Palette
	dc.l	\0Patterns
	dc.w	\0PatternLen
	dc.b	\width
	dc.b	\height
	dc.l	\0TilemapA
	dc.l	\0TilemapB
	dc.l	\0Collision
	dc.l	\0CollisionType
	ENDM


; level description
		rsreset
lvlPalette		rs.l	1
lvlPattern		rs.l	1
lvlPatternLen		rs.w	1
lvlWidth		rs.b	1	; in chunks
lvlHeight		rs.b	1	; in chunks
lvlPlaneATiles		rs.l	1
lvlPlaneBTiles		rs.l	1
lvlCollisionData	rs.l	1
lvlCollisionType	rs.l	1
levelDesc	equ	__rs

lvlChunkSize	equ	32	; number of patterns in level chunk at at each axis
lvlChunkArea	equ	lvlChunkSize*lvlChunkSize


	incLevel.testLevel 'assets/graphicstestlevel/level.pal','assets/graphicstestlevel/BigPicPatterns.bin', 'assets/graphicstestlevel/BigPicTilemap.bin', 'assets/graphicstestlevel/BigPicTilemap.bin', 'assets/collisiontestlevel/col.data.bin', 'assets/collisiontestlevel/col.type.bin'
	incLevel.collisionLevel 'assets/graphicstestlevel/level.pal','assets/graphicstestlevel/BigPicPatterns.bin', 'assets/graphicstestlevel/BigPicTilemap.bin', 'assets/graphicstestlevel/BigPicTilemap.bin', 'assets/collisiontestlevel/col.data.bin', 'assets/collisiontestlevel/col.type.bin'

levelDescriptions
	buildLevelDescriptor.testLevel 4, 2
	buildLevelDescriptor.collisionLevel 4, 2

; Collision bit per pattern
;		CY	CX	Y	X
; Size		2	4	32	32
; Stride	512	128	4	1/8	Bytes

; Collision type nibble per pattern
;		CY	CX	Y	X
; Size		2	4	32	32
; Stride	2048	512	16	4/8	Bytes