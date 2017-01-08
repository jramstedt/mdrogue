	include 'init.asm'
	include 'megadrive.asm'
	include 'memorymap.asm'
	include 'interrupts.asm'
	include 'timing.asm'

__main
	lea testPalette, a0
	clr d0
	jsr loadPalette

	lea testPattern, a0
	clr d0
	move #1, d1
	jsr loadPatterns

gameLoop
	; do input processing

	; do game processing

	jsr waitVBlankOn

	; do graphics commands

	jsr waitVBlankOff

	jmp gameLoop

	include 'assets/palettes.asm'
	include 'assets/patterns.asm'

__end