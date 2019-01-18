
; DMA queue code adapted from https://github.com/flamewing/ultra-dma-queue

; CD2 CD1 CD0
; 0   0   1     VRAM = %001
; 0   1   1     CRAM = %011
; 1   0   1     VSRAM = %101

startDMATransfer
	; length
	move.w	#$93FF, d4
	and.b	d7, d4
	move.w	d4, vdp_ctrl

	lsr.w	#8, d7
	move.w	#$94FF, d4
	and.b	d7, d4
	move.w	d4, vdp_ctrl

	; source
	lsr.l	#1, d5		; Source address >> 1 (even address)
	move.w	#$95FF, d4
	and.b	d5, d4
	move.w	d4, vdp_ctrl

	lsr.l	#8, d5
	move.w	#$96FF, d4
	and.b	d5, d4
	move.w	d4, vdp_ctrl

	lsr.l	#8, d5
	move.w	#$977F, d4
	and.b	d5, d4
	move.w	d4, vdp_ctrl

	; Build DMA command
	lsl.l	#2, d6		; Shift left. 2 bits goes to upper word
	addq.w	#%01, d6	; Set two lowest bits to VRAM write
	ror.w	#2, d6		; Rotate right. Moves two added bits to highest bits.
	swap	d6
	ori.b	#%10000000, d6
	move.l	d6, vdp_ctrl

	rts


queueDMATransfer MACRO sourceMem, destVRAM, lenWords
	move.l	\sourceMem, d5
	move.l	\destVRAM, d6
	move.l	\lenWords, d7
	jsr	_queueDMATransfer
	ENDM

; input:
;	d5 source
;	d6 destination
;	d7 length in words
; trashes:
;	a6, d4, d5, d6
_queueDMATransfer
	movea.w	(dma_queue_pointer).w, a6	; Move current pointer to a6
	cmpa.w	#dma_queue_pointer, a6	; Compare dma_queue_pointer RAM address to current pointer
	beq.s	@done			; If they are the same, queue is full. (dma_queue_pointer is after dma_queue)

	lsr.l	#1, d5		; Source address >> 1 (even address)
	swap	d5		; Swap high and low word (low word contains SA23-SA17)
	move.w	#$977F, d4	; vdp_w_reg+(23<<8) & $7F where 7F is mask for upper bits (SA23-SA17)
	and.b	d5, d4		; AND d4 with d5 lower 8 bits
	move.w	d4, (a6)+	; Save reg 23 command+data to DMA queue
	move.w	d7, d5		; Move length to d5 lower word
	movep.l	d5, 1(a6)	; Move each byte to its own word
	lea	8(a6), a6	; Add 8 to queue (the four words written with movep)

	; Build DMA command
	lsl.l	#2, d6		; Shift left. 2 bits goes to upper word
	addq.w	#%01, d6	; Set two lowest bits to VRAM write
	ror.w	#2, d6		; Rotate right. Moves two added bits to highest bits.
	swap	d6
	ori.b	#%10000000, d6
	move.l	d6, (a6)+

	move.w	a6, (dma_queue_pointer).w

@done
	rts

SlotCount	equ (dma_queue_pointer-dma_queue)/(7*2)

initDMAQueue
	lea	dma_queue, a6
	move.w	a6, (dma_queue_pointer).w	; Set current pointer to beginning of dma queue
	move.l	#$96959493, d7		; vdp_w_reg+(22<<8), vdp_w_reg+(21<<8), vdp_w_reg+(20<<8), vdp_w_reg+(19<<8)

lc = 0
	REPT SlotCount
	movep.l	d7, 2+lc(a6)
lc = lc+14
	ENDR

	rts

;
processDMAQueue
	;haltZ80

	setVDPAutoIncrement 2

	movea.w	(dma_queue_pointer).w, a6
	suba	#dma_queue, a6
	jmp	@jumpTable(a6)

@jumpTable
	rts
	REPT 6
	nop
	ENDR
lc = 1
	REPT SlotCount
	lea	vdp_ctrl, a5
	lea	dma_queue.w, a6
	if lc<>SlotCount
		bra.w	@done-lc*8
	endif
lc = lc+1
	ENDR

	REPT SlotCount
	move.l	(a6)+, (a5)	; reg 23, reg 22
	move.l	(a6)+, (a5)	; reg 21, reg 20
	move.l	(a6)+, (a5)	; reg 19, dma first hlf
	move.w	(a6)+, (a5)	; dma command second half
	ENDR

@done
	move.w	#dma_queue, (dma_queue_pointer).w	; Reset dma_queue_pointer

	;resumeZ80

	rts
