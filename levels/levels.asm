	include 'levels/test.asm'

	cnop 0,2

	; level description
			rsreset
pattern		rs.l	1
patternLen	rs.w	1
planeATiles	rs.l	1
planeBTiles	rs.l	1
levelDesc	equ		__RS

levelDescriptions
	dc.l	testLevelPatterns
	dc.w	(testLevelPatternsEnd-testLevelPatterns)/sizePattern
	dc.l	testLevelTilemap
	dc.l	testLevelTilemap
	