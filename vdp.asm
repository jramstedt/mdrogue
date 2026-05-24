; VDP addresses
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

; set vdp register to value
; \1	vdp register
; \2	value
; \3	vdp_ctrl
	MACRO setVDPRegister
	move.w	#vdp_w_reg+(\1<<8)+\2,\3
	ENDM

; set vdp auto increment register
; \1	bytes
; \2	vdp_ctrl
	MACRO setVDPAutoIncrement
	setVDPRegister $F,\1,\2
	ENDM

; sets write address to vram
; \1	address
; \2	vdp_ctrl
	MACRO setVDPWriteAddressVRAM
	move.l	#vdp_w_vram+((\1&$3FFF)<<16)+((\1&$C000)>>14),\2
	ENDM

; sets write address to cram
; \1	address
; \2	vdp_ctrl
	MACRO setVDPWriteAddressCRAM
	move.l	#vdp_w_cram+(\1<<16),\2
	ENDM

; sets write address to vsram
; \1	address
; \2	vdp_ctrl
	MACRO setVDPWriteAddressVSRAM
	move.l	#vdp_w_vsram+(\1<<16),\2
	ENDM

; set vram fill address
; \1	address
; \2	vdp_ctrl
	MACRO setVDPFillAddressVRAM
	move.l	#vdp_w_vram+$80+((\1&$3FFF)<<16)+((\1&$C000)>>14),\2
	ENDM

; loads patterns to vram from address
; \1	source address
; \2	vram address
; \3	count
	MACRO loadPatterns
	INLINE
	setVDPAutoIncrement 2,vdp_ctrl
	setVDPWriteAddressVRAM \2,vdp_ctrl

	movea.l	\1,a0
	move.l	#\3,d0
	bsr	.copyPatterns

.copyPatternLoop
	move.l	(a0)+,vdp_data
	move.l	(a0)+,vdp_data
	move.l	(a0)+,vdp_data
	move.l	(a0)+,vdp_data
	move.l	(a0)+,vdp_data
	move.l	(a0)+,vdp_data
	move.l	(a0)+,vdp_data
	move.l	(a0)+,vdp_data
.copyPatterns
	dbra	d0,.copyPatternLoop
	rts
	EINLINE
	ENDM

; loads palette to cram
; \1	source address
; \2	palette index
	MACRO loadPalette
	setVDPAutoIncrement 2,vdp_ctrl
	setVDPWriteAddressCRAM (\2*16*2),vdp_ctrl

	movea.l	\1,a0
	move.l	(a0)+,vdp_data
	move.l	(a0)+,vdp_data
	move.l	(a0)+,vdp_data
	move.l	(a0)+,vdp_data
	move.l	(a0)+,vdp_data
	move.l	(a0)+,vdp_data
	move.l	(a0)+,vdp_data
	move.l	(a0)+,vdp_data
	ENDM

; start dma fill with zero to zero address
; NOTE: Set dmaOff after fill finishes if necessary.
	MACRO dmaClearVRAM
	lea	vdp_ctrl,a0

	dmaOn (a0)
	setVDPAutoIncrement 1,(a0)
	setVDPRegister 19,$FF,(a0)
	setVDPRegister 20,$FF,(a0)
	setVDPRegister 23,%10000000,(a0)
	setVDPFillAddressVRAM 0,(a0)
	move.w	#$0,vdp_data
	ENDM

; \1	vdp_ctrl
	MACRO dmaOn
	bset	#4,vdp1rState+1	; DMA On
	move.w	vdp1rState,\1
	ENDM

; \1	vdp_ctrl
	MACRO dmaOff
	bclr	#4,vdp1rState+1	; DMA Off
	move.w	vdp1rState,\1
	ENDM

; \1	vdp_ctrl
	MACRO displayOn
	bset	#6,vdp1rState+1	; DMA On
	move.w	vdp1rState,\1
	ENDM

; \1	vdp_ctrl
	MACRO displayOff
	bclr	#6,vdp1rState+1	; DMA Off
	move.w	vdp1rState,\1
	ENDM

; VRAM

; \1.w	VRAM address (make sure top word is zero)
	MACRO arrangeWriteVRAMcmd
	lsl.l	#2,\1		; 2 bits goes to upper word
	addq.w	#%01,\1		; Set two lowest bits to VRAM write
	ror.w	#2,\1		; Rotate right. Moves two added bits to highest bits.
	swap	\1
	ENDM

; \1.w	VRAM address (make sure top word is zero)
	MACRO arrangeDMAtoVRAMcmd
	arrangeWriteVRAMcmd \1
	ori.b	#%10000000,\1
	ENDM

; \1.w	VRAM address (make sure top word is zero)
	MACRO arrangeDMAVRAMtoVRAMcmd
	arrangeWriteVRAMcmd \1
	ori.b	#%11000000,\1
	ENDM

; CRAM

; \1.w	CRAM address (make sure top word is zero)
	MACRO arrangeWriteCRAMcmd
	lsl.l	#2,\1		; 2 bits goes to upper word
	addq.w	#%11,\1		; Set two lowest bits to VRAM write
	ror.w	#2,\1		; Rotate right. Moves two added bits to highest bits.
	swap	\1
	ENDM

; \1.w	CRAM address (make sure top word is zero)
	MACRO arrangeDMAtoCRAMcmd
	arrangeWriteCRAMcmd \1
	ori.b	#%10000000,\1
	ENDM

; VSRAM

; \1.w	VSRAM address (make sure top word is zero)
	MACRO arrangeWriteVSRAMcmd
	arrangeWriteVRAMcmd \1
	ori.b	#%00010000,\1
	ENDM

; \1.w	VSRAM address (make sure top word is zero)
	MACRO arrangeDMAtoVSRAMcmd
	arrangeWriteVRAMcmd \1
	ori.b	#%10010000,\1
	ENDM
