	include 'init.asm'
	include 'megadrive.asm'
	include 'memorymap.asm'
	include 'interrupts.asm'
	include 'timing.asm'

	include 'objects/objects.asm'

__main
	loadPalette testPalette, 0
	loadPalette testPalette, 2
	
	loadPatterns testPattern, $0, 1

gameLoop
	; do input processing

	; do game processing

	jsr waitVBlankOn

	; do graphics commands

	jsr waitVBlankOff
	
	jmp gameLoop

	include 'assets/palettes.asm'
	include 'assets/patterns.asm'
	
	
	include 'objects/01player.asm'
__end