	include 'levels/test.asm'

	cnop 0,2

	; level description
			rsreset
pattern		rs.l	1
patternLen	rs.w	1
lvlWidth    rs.b    1   ; in chunks
lvlHeight   rs.b    1   ; in chunks
planeATiles	rs.l	1
planeBTiles	rs.l	1
levelDesc	equ		__RS

lvlChunkSize equ    32  ; number of patterns in level chunk at at each axis
lvlChunkArea equ	lvlChunkSize*lvlChunkSize

levelDescriptions
	dc.l	testLevelPatterns
	dc.w	(testLevelPatternsEnd-testLevelPatterns)/sizePattern
	dc.b    4
	dc.b    4
	dc.l	testLevelTilemap
	dc.l	testLevelTilemap
	