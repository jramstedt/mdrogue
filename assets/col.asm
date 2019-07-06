
patternsCol
	incbin	assets/colpat.bin

	cnop	0,2
spritesCol
	dc.l	patternsCol
	dc.w	@sprite8x8-spritesCol
	dc.w	@sprite16x16-spritesCol
	dc.w	@sprite24x24-spritesCol
	dc.w	@sprite32x32-spritesCol

@sprite8x8
	incbin	assets/8x8spr.bin

@sprite16x16
	incbin	assets/16x16spr.bin

@sprite24x24
	incbin	assets/24x24spr.bin

@sprite32x32
	incbin	assets/32x32spr.bin

	cnop	0,2