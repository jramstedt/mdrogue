patternsOrc
	incbin	assets/orcPatterns.bin

	cnop	0,2
spritesOrc
	dc.l	patternsOrc
	dc.w	@idle-spritesOrc
	dc.w	@angryIdle-spritesOrc
	dc.w	@thinking-spritesOrc
	dc.w	@surprised-spritesOrc

@idle
	incbin	assets/orcIdle.bin

@angryIdle
	incbin	assets/orcAngryIdle.bin

@thinking
	incbin	assets/orcThinking.bin

@surprised
	incbin	assets/orcSurprised.bin

aniOrc
	dc.w	@aniIdle-aniOrc
	dc.w	@aniAngryIdle-aniOrc
	dc.w	@aniThinking-aniOrc
	dc.w	@aniSurprised-aniOrc

@aniIdle
	dc.b	50/1, 0, 1, $80

@aniAngryIdle
	dc.b	50/5, 0, 1, 2, 3, 4, $80

@aniThinking
	dc.b	50/5, 0, 1, 2, 3, 4, $80

@aniSurprised
	dc.b	50/5, 0, 1, $80

	cnop	0,2