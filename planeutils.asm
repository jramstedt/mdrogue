; Calculate pattern name table offset of 32x64 screen plane
; \1 X
; \2 Y
; \3 Plane VRAM address
; \4 Pattern VRAM address
; \5 destination
	MACRO calc32x64pos
	move.l	#(\3+(\2<<7)+(\1<<1))<<16,\5
	move.w	\4,\5
	lsr.w	#5,\5
	ENDM

; Calculate pattern name table offset of 32x64 screen plane
; \1 X
; \2 Y
; \3 Plane VRAM address
; \4 Pattern VRAM address
; \5 destination
	MACRO calc32x64posStatic
	move.l	#(\3+(\2<<7)+(\1<<1))<<16|(\4>>5),\5
	ENDM

; Add X and Y to position
; \1 X
; \2 Y
; \3 destination
	MACRO add32x64pos
	add.l	#((\2<<7)+(\1<<1))<<16,\3
	ENDM

; a0	String address, will be at string end on return
; a1	Font tilemap source address
; d2.l	Hi = Plane VRAM address, Lo = Pattern VRAM index. HHHHLLLL
; TODO vdp16r determines scroll plane size. Currently hardcoded.
draw8x8Text
	setVDPAutoIncrement 2,vdp_ctrl

	move.l	d2,d1
	clr.w	d1
	swap	d1		; d1.w Plane VRAM address
	arrangeWriteVRAMcmd d1

.setVRAMAddress
	move.l	d1,vdp_ctrl

.char
	clr.w	d0
	move.b	(a0)+,d0	; Read character
	beq	.complete	; End at null

	cmp.b	#$A,d0		; \n
	beq	.newline

	cmp.b	#$D,d0		; \r
	beq	.carriageReturn

	sub.b	#' ',d0		; Font starts from space
	lsl.b	d0		; Each pattern name is two bytes

	move.w	(a1,d0.w),d0	; d0 is "pattern name"
	add.w	d2,d0		; Add pattern VRAM index

	move.w	d0,vdp_data

	add.l	#2<<16,d1	; 2 bytes per pattern name
	bra	.char

.newline
	add.l	#(1<<7)<<16,d1	; 64 pattern names per row, 2 bytes per pattern name
	bra	.setVRAMAddress

.carriageReturn
	move.l	d2,d0
	and.l	#$007F0000,d0	; Original X
	and.l	#$FF80FFFF,d1	; Clear current X
	add.l	d0,d1		; Add original X
	bra	.setVRAMAddress

.complete
	rts

; a1	9Slice Tilemap source address
; d2.l	Hi = Plane VRAM address, Lo = Pattern VRAM index. HHHHLLLL
; d3.l	Hi = Height, Lo = Width
; TODO vdp16r determines scroll plane size. Currently hardcoded.
draw9Slice
	setVDPAutoIncrement 2,vdp_ctrl

; Build VRAM write command
	move.l	d2,d7
	clr.w	d7
	swap	d7		; d7.w Plane VRAM address
	arrangeWriteVRAMcmd d7
	move.l	d7,vdp_ctrl

	move.l	d3,d1		; Size

; First row
	; start
	move.w	0(a1),d0	; d0 is "pattern name"
	add.w	d2,d0		; Add pattern VRAM index
	move.w	d0,vdp_data
	; middle
	move.w	2(a1),d0	; d0 is "pattern name"
	add.w	d2,d0		; Add pattern VRAM index

	sub.w	#$00003,d1
	blt	.fe
.fm
	move.w	d0,vdp_data
	dbra.w 	d1,.fm
.fe	; end
	move.w	4(a1),d0	; d0 is "pattern name"
	add.w	d2,d0		; Add pattern VRAM index
	move.w	d0,vdp_data

	sub.l	#$20000,d1
	blt	.lastRow

; Middle rows
.row
	add.l	#(1<<7)<<16,d7	; 64 pattern names per row, 2 bytes per pattern name
	move.l	d7,vdp_ctrl

	move.w	d3,d1		; Reset width
	sub.l	#$10000,d1
	blt	.lastRow

	; start
	move.w	6(a1),d0	; d0 is "pattern name"
	add.w	d2,d0		; Add pattern VRAM index
	move.w	d0,vdp_data
	; middle
	move.w	8(a1),d0	; d0 is "pattern name"
	add.w	d2,d0		; Add pattern VRAM index

	sub.w	#$00003,d1
	blt	.me
.mm
	move.w	d0,vdp_data
	dbra.w 	d1,.mm
.me	; end
	move.w	10(a1),d0	; d0 is "pattern name"
	add.w	d2,d0		; Add pattern VRAM index
	move.w	d0,vdp_data

	bra	.row

; Last row
.lastRow
	; start
	move.w	12(a1),d0	; d0 is "pattern name"
	add.w	d2,d0		; Add pattern VRAM index
	move.w	d0,vdp_data
	; middle
	move.w	14(a1),d0	; d0 is "pattern name"
	add.w	d2,d0		; Add pattern VRAM index

	sub.w	#$00003,d1
	blt	.le
.lm
	move.w	d0,vdp_data
	dbra.w 	d1,.lm
.le	; end
	move.w	16(a1),d0	; d0 is "pattern name"
	add.w	d2,d0		; Add pattern VRAM index
	move.w	d0,vdp_data

	rts

; a1	Tilemap source address
; d2.l	Hi = Plane VRAM address, Lo = Pattern VRAM index. HHHHLLLL
draw2x2
	setVDPAutoIncrement 2,vdp_ctrl

; Build VRAM write command
	move.l	d2,d1
	clr.w	d1
	swap	d1		; d1.w Plane VRAM address
	arrangeWriteVRAMcmd d1
	move.l	d1,vdp_ctrl

	; 1,1
	move.w	0(a1),d0	; d0 is "pattern name"
	add.w	d2,d0		; Add pattern VRAM index
	move.w	d0,vdp_data

	; 2,1
	move.w	2(a1),d0	; d0 is "pattern name"
	add.w	d2,d0		; Add pattern VRAM index
	move.w	d0,vdp_data

	add.l	#(1<<7)<<16,d1	; 64 pattern names per row, 2 bytes per pattern name
	move.l	d1,vdp_ctrl

	; 1,2
	move.w	4(a1),d0	; d0 is "pattern name"
	add.w	d2,d0		; Add pattern VRAM index
	move.w	d0,vdp_data

	; 2,2
	move.w	6(a1),d0	; d0 is "pattern name"
	add.w	d2,d0		; Add pattern VRAM index
	move.w	d0,vdp_data

	rts

; Fill rectangle with single tile
; a1	Tile source address
; d2.l	Hi = Plane VRAM address, Lo = Pattern VRAM index. HHHHLLLL
; d3.l	Hi = Height, Lo = Width
fillRect
	setVDPAutoIncrement 2,vdp_ctrl

; Build VRAM write command
	move.l	d2,d7
	clr.w	d7
	swap	d7		; d7.w Plane VRAM address
	arrangeWriteVRAMcmd d7

	move.w	(a1),d6		; d6 is "pattern name"
	add.w	d2,d6		; Add pattern VRAM index

	move.l	d3,d1
	swap	d1		; d1.w is height
	bra	.start

.loop
	move.w	d6,vdp_data
.row	dbra	d0,.loop
	add.l	#(1<<7)<<16,d7	; 64 pattern names per row, 2 bytes per pattern name
.start	move.l	d7,vdp_ctrl
	move.w	d3,d0		; d0.w is width
	dbra	d1,.row
	rts