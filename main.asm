	include 'init.asm'
	include 'memorymap.asm'
	include 'megadrive.asm'
	include 'interrupts.asm'
	include 'timing.asm'

	include 'objects/objects.asm'

__main
	jsr initDMAQueue

	loadPalette testPalette, 0
	loadPalette testPalette, 2
	
	loadPatterns testPattern, $0, 1

	setVDPRegister 11, %00000111

	setVDPAutoIncrement 2
	setVDPWriteAddressVRAM vdp_map_hst

	move.l #255, d0
	move.l #0, d1
@setHScrollLoop
	move.l d1, vdp_data
	addq.l #1, d1
	dbra d0, @setHScrollLoop
	
	setVDPAutoIncrement 2
	setVDPWriteAddressVSRAM 0

	move.l #19, d0
	move.l #0, d1
@setVScrollLoop
	move.l d1, vdp_data
	addq.l #1, d1
	dbra d0, @setVScrollLoop

gameLoop
	; do input processing

	; do game processing

	jsr waitVBlankOn

	; do graphics commands
	jsr processDMAQueue

	jsr waitVBlankOff
	
	jmp gameLoop

	include 'assets/palettes.asm'
	include 'assets/patterns.asm'
	
	
	include 'objects/01player.asm'
__end