patternsOrc
	incbin	assets/orcPatterns.bin

	cnop 0,2
spritesOrc
	dc.l	patternsOrc
	dc.w	@idle-spritesOrc
	dc.w	@angryIdle-spritesOrc
	dc.w	@thinking-spritesOrc
	dc.w	@surprised-spritesOrc

	cnop 1,2
@idle
	incbin	assets/orcIdle.bin

	cnop 1,2
@angryIdle
	incbin	assets/orcAngryIdle.bin

	cnop 1,2
@thinking
	incbin	assets/orcThinking.bin

	cnop 1,2
@surprised
	incbin	assets/orcSurprised.bin

	cnop 0,2
aniOrc
	dc.w	@aniIdle-aniOrc
	dc.w	@aniAngryIdle-aniOrc
	dc.w	@aniThinking-aniOrc
	dc.w	@aniSurprised-aniOrc

@aniIdle
	dc.b	60, 0, 1, $80

@aniAngryIdle
	dc.b	60, 0, 1, 2, 3, 4, $80

@aniThinking
	dc.b	60, 0, 1, 2, 3, 4, $80

@aniSurprised
	dc.b	60, 0, 1, $80
