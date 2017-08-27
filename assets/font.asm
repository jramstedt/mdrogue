; 16x16 font
; 32 characters per row
; 3 rows
; tilemap starts from ascii 0x20 (space)

drawFont
	setVDPAutoIncrement 2
	setVDPWriteAddressVRAM vdp_map_ant

	move #vdp_map_ant, d2
	; add X
	; add Y

	lsl.l #2, d2
	lsr.w #2, d2
	swap d2
	or.l #vdp_w_vram, d2 ; d2 is first row address
	move.l d2, d3
	add.l #(128<<16), d3 ; d3 is second row address

@charLoop
	clr.l d0
	move.b (a6)+, d0
	beq @complete

	; TODO line break

	sub #$20, d0
	move.l d0, d1

	and.b #$1F, d0	; Get char index in row
	lsl.w #2, d0	; Each character is 4 bytes width

	lsr.b #5, d1	; /32, calculates row number
	lsl.w #8, d1	; Calculate data offset, each row is 128 bytes width, character is two rows
	add.l d1, d0

	lea.l	fontTilemap, a5
	adda.l	d0, a5

	move.l d2, vdp_ctrl
	move.l (a5), vdp_data
	
	move.l d3, vdp_ctrl
	move.l 128(a5), vdp_data

	add.l #(4<<16), d2
	add.l #(4<<16), d3
	jmp @charLoop

@complete
	rts
