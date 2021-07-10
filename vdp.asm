; VDP addressses
vdp_data  	equ	$00C00000
vdp_ctrl  	equ	$00C00004
vdp_hvcnt 	equ	$00C00008
vdp_psg   	equ	$00C00011

vdp_w_reg	equ	$00008000

vdp_w_vram	equ	$40000000
vdp_w_cram	equ	$C0000000
vdp_w_vsram	equ	$40000010

vdp_r_vram	equ	$00000000
vdp_r_cram	equ	$00000040
vdp_r_vsram	equ	$00000010

; H40 cell mode
;vdp_map_ant	equ	$C000	; scroll a pattern name table
;vdp_map_wnt	equ	$D000	; window pattern table
;vdp_map_bnt	equ	$E000	; scroll b pattern name table
;vdp_map_sat	equ	$F000	; sprite attribute table
;vdp_map_hst	equ	$F800	; horizontal scroll table
vdp_map_ant	equ	$C000	; scroll a pattern name table
vdp_map_wnt	equ	$D000	; window pattern table
vdp_map_bnt	equ	$E000	; scroll b pattern name table
vdp_map_sat	equ	$D000	; sprite attribute table
vdp_map_hst	equ	$D800	; horizontal scroll table

; macros
setVDPRegister MACRO register, value
	move.w	#vdp_w_reg+(register<<8)+value, vdp_ctrl
	ENDM

setVDPAutoIncrement MACRO bytes
	setVDPRegister $F, \bytes
	ENDM

; sets write address to vram
setVDPWriteAddressVRAM MACRO address
	move.l	#vdp_w_vram+((address&$3FFF)<<16)+((address&$C000)>>14), vdp_ctrl
	ENDM

; sets write address to cram
setVDPWriteAddressCRAM MACRO address
	move.l	#vdp_w_cram+(address<<16), vdp_ctrl
	ENDM

; sets write address to vsram
setVDPWriteAddressVSRAM MACRO address
	move.l	#vdp_w_vsram+(address<<16), vdp_ctrl
	ENDM

; loads patterns to vram
loadPatterns MACRO source, vram, count
	setVDPAutoIncrement 2
	setVDPWriteAddressVRAM \vram

	lea.l	(source), a0
	move.l	#count, d0
	bsr	copyPatterns
	ENDM

; loads palette to cram
loadPalette MACRO source, index
	setVDPAutoIncrement 2
	setVDPWriteAddressCRAM (\index*16*2)

	lea.l	(source), a0
	bsr	copyPalette
	ENDM

; a0	palette 68k address
copyPalette	MODULE
	move.w	#sizePalette/sizeLong-1, d0
@copyColorLoop
	move.l	(a0)+, vdp_data
	dbra	d0, @copyColorLoop
	rts
	MODEND

; a0	pattern 68k address
; d0	number of patterns
copyPatterns	MODULE
	subq.b	#1, d0 ; decrease by one to make looping work
@copyPatternLoop
	move.w	#sizePattern/sizeLong-1, d1
@copyPatternDataLoop
	move.l	(a0)+, vdp_data
	dbra	d1, @copyPatternDataLoop
	dbra	d0, @copyPatternLoop
	rts
	MODEND

dmaClearVRAM MACRO
	setVDPAutoIncrement 1
	setVDPRegister 19, $FF
	setVDPRegister 20, $FF
	setVDPRegister 23, %10000000
	move.l	#vdp_w_vram+$80, vdp_ctrl
	move.w	#$0, vdp_data
	ENDM