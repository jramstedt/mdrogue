; VDP
vdp_data  	equ 0x00C00000
vdp_ctrl  	equ 0x00C00004
vdp_hvcnt 	equ 0x00C00008
vdp_psg   	equ 0x00C00011

vdp_w_pal	equ	0x0000C000
vdp_w_reg	equ 0x00008000
vdp_w_vram	equ 0x00004000

; H40 cell mode
vdp_map_sat equ 0xA800
vdp_map_hst equ 0xAC00
vdp_map_wnt equ 0xB000
vdp_map_ant	equ 0xC000
vdp_map_bnt equ 0xE000

; a0	palette 68k address
; d0	palette index (0-3)
loadPalette
	move.w #0x8F02, vdp_ctrl ; vdp_w_reg, F register (autoincrement), 2 bytes

	lsl.w #5, d0 ; calculates addr in CRAM, multiplies index by 64: 16 colors, 2 bytes per color.
	or #vdp_w_pal, d0 ; set palette write command
	swap d0 ; move word
	move.l d0, vdp_ctrl

	move.w #sizePalette/sizeLong-1, d0
copyColorLoop
	move.l (a0)+, vdp_data
	dbra d0, copyColorLoop
	rts

; d0 register and value 0xXXYY, XX register, YY value
setVDPRegister
	or #vdp_w_reg, d0
	move.w d0, vdp_ctrl
	rts

; a0	pattern 68k address
; d0	pattern vram address
; d1	number of patterns
loadPatterns
	move.w #0x8F02, vdp_ctrl ; vdp_w_reg, F register (autoincrement), 2 bytes

	swap d0
	lsr.l #2, d0
	rol.w #2, d0
	or.l #vdp_w_vram<<16, d0
	move.l d0, vdp_ctrl
	
	subq.b #0x1, d1 ; decrease by one to make looping work
copyPatternLoop
	move.w #sizePattern/sizeLong, d0
copyPatternDataLoop
	move.l (a0)+, vdp_data
	dbra d0, copyPatternDataLoop
	dbra d1, copyPatternLoop
	rts

