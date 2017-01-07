	include 'init.asm'
	include 'megadrive.asm'
	include 'memorymap.asm'
	include 'interrupts.asm'
	include 'timing.asm'

__main
	; do input processing

	; do game processing

	jsr waitVBlankOn

	; do graphics commands

	jsr waitVBlankOff

	jmp __main

__end