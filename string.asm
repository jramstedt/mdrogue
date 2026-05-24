
; a0	String buffer
; d0	Unsigned byte to write
btos
	moveq	#3,d1
	and.l	#$FF,d0
	bra.s	writeToString

; a0	String buffer
; d0	Unsigned word to write
wtos
	moveq	#5,d1
	and.l	#$FFFF,d0
	bra.s	writeToString

; a0	String buffer
; d0	Unsigned integer to write
itos
	moveq	#10,d1

; a0	String buffer
; d0	Unsigned number to write
; d1	Number of characters to write. Padded with zero.
writeToString
	lea	(1,a0,d1.w),a0	; +1 for null char
	move.b	#0,-(a0)	; null char
cloop
	divu	#10,d0
	swap	d0
	add.b	#'0',d0
	move.b	d0,-(a0)
	sub	#1,d1
	clr.w	d0
	swap	d0
	bne	cloop
	bra	.pads
.pad
	move.b	#'0',-(a0)
.pads	dbra	d1,.pad
	rts
