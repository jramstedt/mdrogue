; 16x16 font
; 32 characters per row
; 3 rows
; tilemap starts from ascii 0x20 (space)

; input:
; a6	address for text
; d7	position. YYYYXXXX
; trash:
; d0, d1, d2, d3, d4, a5
drawFont	MODULE
	setVDPAutoIncrement 2

	move	#vdp_map_ant, d2

	lsl.l	d7	; Each table entry is 2 bytes width
	add.w	d7, d2

	swap	d7	; XXXXYYYY
	lsl.w	#6, d7	; Each row is 64 patterns (32 bytes)
	add.w	d7, d2
	clr.w	d7

	lsl.l	#2, d2
	lsr.w	#2, d2
	swap	d2
	or.l	#vdp_w_vram, d2	; d2 is first row address
	move.l	d2, d3
	add.l	#(128<<16), d3	; d3 is second row address

	move.w	fontVRAMAddress, d4
	swap	d4
	move.w	fontVRAMAddress, d4
	lsr.l	#5, d4

@charLoop
	clr.l	d0
	move.b	(a6)+, d0
	beq	@complete

	cmp.b	#$A, d0
	beq	@newline

	cmp.b	#$D, d0
	beq	@carriageReturn

	sub	#$20, d0
	move.l	d0, d1

	and.b	#$1F, d0	; Get char index in row
	lsl.w	#2, d0		; Each character is 4 bytes width

	lsr.b	#5, d1		; /32, calculates row number
	lsl.w	#8, d1		; Calculate data offset, each row is 128 bytes width, character is two rows
	add.l	d1, d0

	lea.l	fontTilemap, a5
	move.l	(a5, d0.l), d1	; d1 is pattern index
	add.l	d4, d1

	move.l	d2, vdp_ctrl
	move.l	d1, vdp_data
	
	add.l	#128, d0	; row is 128 bytes
	move.l	(a5, d0.l), d1	; d1 is pattern index
	add.l	d4, d1

	move.l	d3, vdp_ctrl
	move.l	d1, vdp_data

	add.l	#(4<<16), d2
	add.l	#(4<<16), d3
	bra	@charLoop

@newline
	add.l	#((128*2)<<16), d2
	add.l	#((128*2)<<16), d3
	bra	@charLoop

@carriageReturn
	and.l	#$FF80FFFF, d2
	add.l	d7, d2

	and.l	#$FF80FFFF, d3
	add.l	d7, d3

	bra	@charLoop

@complete
	rts
	MODEND

; int to four characters
; max value shown is 9999
; input:
; a0	address for string
; d0	int to write
itos	MODULE
	adda	#4, a0
	move.l	#4-1, d2
@aloop
	divu	#10, d0		; hi = modulo
	move.l	d0, d1
	and.l	#$FFFF, d0	; clear hi
	swap	d1
	add.b	#$30, d1	; add ascii start
	move.b	d1, -(a0)
	dbra	d2, @aloop

	rts
	MODEND