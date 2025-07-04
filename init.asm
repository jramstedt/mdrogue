
	dc.l	stackStartAddress	; Initial stack pointer value
	dc.l	EntryPoint		; Start of program
	dc.l	Exception		; Bus error
	dc.l	Exception		; Address error
	dc.l	Exception		; Illegal instruction
	dc.l	Exception		; Division by zero
	dc.l	Exception		; CHK exception
	dc.l	Exception		; TRAPV exception
	dc.l	Exception		; Privilege violation
	dc.l	Exception		; TRACE exception
	dc.l	Exception		; Line-A emulator
	dc.l	Exception		; Line-F emulator
	dc.l	Exception		; Unused (reserved)
	dc.l	Exception		; Unused (reserved)
	dc.l	Exception		; Unused (reserved)
	dc.l	Exception		; Uninitialized Interrupt Vector
	dc.l	Exception		; Unused (reserved)
	dc.l	Exception		; Unused (reserved)
	dc.l	Exception		; Unused (reserved)
	dc.l	Exception		; Unused (reserved)
	dc.l	Exception		; Unused (reserved)
	dc.l	Exception		; Unused (reserved)
	dc.l	Exception		; Unused (reserved)
	dc.l	Exception		; Unused (reserved)
	dc.l	Exception		; Spurious exception
	dc.l	Exception		; IRQ level 1
	dc.l	Exception		; IRQ level 2
	dc.l	Exception		; IRQ level 3
	dc.l	HBlankInterrupt		; IRQ level 4 (horizontal retrace interrupt)
	dc.l	Exception		; IRQ level 5
	dc.l	VBlankInterrupt		; IRQ level 6 (vertical retrace interrupt)
	dc.l	Exception		; IRQ level 7
	dc.l	Exception		; TRAP #00 exception
	dc.l	Exception		; TRAP #01 exception
	dc.l	Exception		; TRAP #02 exception
	dc.l	Exception		; TRAP #03 exception
	dc.l	Exception		; TRAP #04 exception
	dc.l	Exception		; TRAP #05 exception
	dc.l	Exception		; TRAP #06 exception
	dc.l	Exception		; TRAP #07 exception
	dc.l	Exception		; TRAP #08 exception
	dc.l	Exception		; TRAP #09 exception
	dc.l	Exception		; TRAP #10 exception
	dc.l	Exception		; TRAP #11 exception
	dc.l	Exception		; TRAP #12 exception
	dc.l	Exception		; TRAP #13 exception
	dc.l	Exception		; TRAP #14 exception
	dc.l	Exception		; TRAP #15 exception
	dc.l	Exception		; Unused (reserved)
	dc.l	Exception		; Unused (reserved)
	dc.l	Exception		; Unused (reserved)
	dc.l	Exception		; Unused (reserved)
	dc.l	Exception		; Unused (reserved)
	dc.l	Exception		; Unused (reserved)
	dc.l	Exception		; Unused (reserved)
	dc.l	Exception		; Unused (reserved)
	dc.l	Exception		; Unused (reserved)
	dc.l	Exception		; Unused (reserved)
	dc.l	Exception		; Unused (reserved)
	dc.l	Exception		; Unused (reserved)
	dc.l	Exception		; Unused (reserved)
	dc.l	Exception		; Unused (reserved)
	dc.l	Exception		; Unused (reserved)
	dc.l	Exception		; Unused (reserved)

; 100H - 1FFH cartridge data

	dc.b	"SEGA MEGA DRIVE "					; 100H Console name
	dc.b	"(C)  JR 2017.JAN"					; 110H Copyright holder and release date
	dc.b	"ROGUE GAME                                      "	; 120H Domestic name
	dc.b	"ROGUE GAME                                      "	; 150H International name
	dc.b	"GM T-XXXXXX-00"					; 180H Version number
	dc.w	$0000							; 18EH Checksum
	dc.b	"J               "					; 190H I/O support
	dc.l	$00000000						; 1A0H Start address of ROM
	dc.l	__end							; 1A4H End address of ROM
	dc.l	ramStartAddress						; 1A8H Start address of RAM
	dc.l	$00FFFFFF						; 1ACH End address of RAM
	dc.l	$00000000						; 1B0H SRAM enable ('RA',%1x1yz000,%00100000)
	dc.l	$00000000						; 1B4H Start address of SRAM
	dc.l	$00000000						; 1B8H End address of SRAM
	dc.b	"            "						; 1BCH Modem ('MO','xxxx','yy.zzz')
	dc.b	"                                        "		; 1C8H Notes (unused)
	dc.b	"F               "					; 1F0H Hardware enable code

	include 'memorymap.asm'
	include 'megadrive.asm'
	include 'interrupts.asm'
	include 'random.asm'

EntryPoint
	tst.w	io_expRst	; Test expansion port reset
	bne	HotStart	; Branch if Not Equal (to zero) - to HotStart
	tst.w	io_reset	; Test reset button
	bne	HotStart	; Branch if Not Equal (to zero) - to HotStart

; Cold start

; TMSS
	move.b	io_ver, d0
	andi.b	#$0F, d0
	beq	skipTMSS
	move.l	#'SEGA', $00A14000
skipTMSS

; VDP
	move.l	#vdp_w_reg, d0
	lea	VDPRegisters, a0
	lea	vdp_ctrl, a1

initVDPLoop
	move.b	(a0)+, d0
	move.w	d0, (a1)
	add.w	#$0100, d0
	cmpa.w	#VDPRegistersEnd, a0
	blo.s	initVDPLoop

	dmaClearVRAM	; Start filling VRAM using DMA. Does not block CPU.

; IO controls
	move.b	#$00, io_ctrl1
	move.b	#$00, io_ctrl2
	move.b	#$00, io_ctrl3

; Clear RAM FF0000 - FFFFFF
	moveq	#0, d0
	lea	ramStartAddress, a0
	move.l	#$00003FFF, d1
clearRamLoop
	move.l	d0, (a0)+
	dbra	d1, clearRamLoop

; clean init registers
	movem.l	ramStartAddress, d0-d7/a0-a6
	lea	stackStartAddress, sp
	move.w	#$2700, sr	; supervisor, interrupt level 7

	move.w	#$100, Z80_reset
	move.w	#$100, Z80_busreq
	; upload program here
	move.w	#$000, Z80_reset
	move.w	#$000, Z80_busreq
	move.w	#$100, Z80_reset

	move.l	#1, lcgSeed

HotStart
	jsr	waitDMAOn	; wait all background DMAs to finish, DMA can be running if hot started with reset.

	bra	__main ; Begin external main

VDPRegisters
	dc.b	%00000100 ; 0: Horiz. interrupt off, 
vdp1r	dc.b	%00000100 ; 1: display off, Vert. interrupt off, screen blank off, DMA off, V28 mode, Mega Drive mode on
	dc.b	(vdp_map_ant>>10) ; 2: Pattern table for Scroll Plane A (bits 3-5)
	dc.b	(vdp_map_wnt>>10) ; 3: Pattern table for Window Plane (bits 1-5)
	dc.b	(vdp_map_bnt>>13) ; 4: Pattern table for Scroll Plane B (bits 0-2)
	dc.b	(vdp_map_sat>>9) ; 5: Sprite table (bits 0-6)
	dc.b	%00000000 ; 6: Unused
	dc.b	%00000000 ; 7: Background colour - bits 0-3 = colour, bits 4-5 = palette
	dc.b	%00000000 ; 8: Unused
	dc.b	%00000000 ; 9: Unused
	dc.b	%00000000 ; 10: Frequency of Horiz. interrupt in Rasters (number of lines travelled by the beam)
	dc.b	%00000000 ; 11: External interrupts off, V scroll fullscreen, H scroll fullscreen
	dc.b	%10000001 ; 12: Shadows and highlights off, interlace off, H40 mode (64 cells horizontally)
	dc.b	(vdp_map_hst>>10) ; 13: Horiz. scroll table (bits 0-5)
	dc.b	%00000000 ; 14: Unused
	dc.b	%00000000 ; 15: Autoincrement off
	dc.b	%00000001 ; 16: Vert. scroll 32, Horiz. scroll 64
vdp17r	dc.b	%00000000 ; 17: Window Plane X pos 0 left (pos in bits 0-4, left/right in bit 7)
vdp18r	dc.b	%10010100 ; 18: Window Plane Y pos 0 up (pos in bits 0-4, up/down in bit 7)
	dc.b	%00000000 ; 19: DMA length lo byte
	dc.b	%00000000 ; 20: DMA length hi byte
	dc.b	%00000000 ; 21: DMA source address lo byte
	dc.b	%00000000 ; 22: DMA source address mid byte
	dc.b	%00000000 ; 23: DMA source address hi byte, memory-to-VRAM mode (bits 6-7)
VDPRegistersEnd
