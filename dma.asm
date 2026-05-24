
; DMA queue code adapted from https://github.com/flamewing/ultra-dma-queue

; CD2 CD1 CD0
; 0   0   1     VRAM = %001
; 0   1   1     CRAM = %011
; 1   0   1     VSRAM = %101

	clrso
w_reg20	so.b	1	; vdp_w_reg+(20<<8) = $94
sizeHi	so.b	1
w_reg19	so.b	1	; vdp_w_reg+(19<<8) = $93
sizeLo	so.b	1
w_reg23	so.b	1	; vdp_w_reg+(23<<8) = $97
srcHi	so.b	1
w_reg22	so.b	1	; vdp_w_reg+(22<<8) = $96
srcMi	so.b	1
w_reg21	so.b	1	; vdp_w_reg+(21<<8) = $95
srcLo	so.b	1
dmaCom	so.l	1
dmaSize	equ	__SO

; d0.l	Source address (word aligned)
; d1.w	VRAM address (make sure top word is zero)
; d2.w	Length in words
startDMATransfer
	movea.w	(dma_queue_pointer).w,a0	; Temporarily use free DMA queue slot

	lsr.l	d0
	movep.l	d0,sizeLo(a0)		; Write source address. Top byte is overwritten next
	movep.w	d2,sizeHi(a0)		; Write length

	; Build DMA command
	arrangeDMAtoVRAMcmd d1
	move.l	d1,dmaCom(a0)

	lea	vdp_ctrl,a1
	dmaOn	(a1)
	fastHaltZ80
	move.l	(a0)+,(a1)	; reg 23, reg 22
	move.l	(a0)+,(a1)	; reg 21, reg 20
	move.l	(a0)+,(a1)	; reg 19, dma first half
	move.w	(a0),(a1)	; dma command second half
	resumeZ80
	dmaOff	(a1)

	rts

; d1	VRAM address (make sure top word is zero)
; d2	Length in words
startDMAFill
	movea.w	(dma_queue_pointer).w,a0	; Temporarily use free DMA queue slot

	movep.w	d2,sizeHi(a0)		; Write length

	; Build DMA command
	arrangeDMAtoVRAMcmd d1

	lea	vdp_ctrl,a1
	dmaOn	(a1)
	fastHaltZ80
	move.l	w_reg20(a0),(a1)
	move.w	#$9780,(a1)		; DMA Mode VRAM fill
	move.l	d1,(a1)
	move.w	#$0,vdp_data		; Fill with zero
	resumeZ80
	dmaOff	(a1)

	rts

; d0	Source address (word aligned)
; d1	VRAM address (make sure top word is zero)
; d2	Length in words
queueDMATransfer
	;move.w	sr,-(sp)		; Save current interrupt mask
	;move.w	#$2700,sr

	movea.w	(dma_queue_pointer).w,a0
	cmpa.w	#dma_queue_pointer,a0	; Compare dma_queue_pointer RAM address to current pointer
	beq.s	.done			; If they are the same, queue is full. (dma_queue_pointer is after dma_queue)

	lsr.l	d0
	movep.l	d0,sizeLo(a0)		; Write source address. Top byte is overwritten next
	movep.w	d2,sizeHi(a0)

	lea	dmaCom(a0),a0

	; Build DMA command
	arrangeDMAtoVRAMcmd d1
	move.l	d1,(a0)+

	move.w	a0,(dma_queue_pointer).w

.done
	;move.w	(sp)+,sr

	rts

;
initDMAQueue
	lea	dma_queue,a0
	move.w	a0,(dma_queue_pointer).w	; Set current pointer to beginning of dma queue
	move.l	#$FFFFFF94,d0
	move.l	#$93979695,d1
	REPT SlotCount
		move.b	d0,w_reg20+(REPTN*dmaSize)(a0)
		movep.l	d1,w_reg19+(REPTN*dmaSize)(a0)
	ENDR
	rts

;
processDMAQueue
	lea	vdp_ctrl,a1

	setVDPAutoIncrement 2,(a1)

	movea.w	(dma_queue_pointer).w,a0

	dmaOn	(a1)
	fastHaltZ80

	jmp	.jumpTable-dma_queue(a0)

.jumpTable
	jmp	.done
	nop
	nop
	nop
	nop
	nop

	REPT SlotCount
	lea	(vdp_ctrl).l,a1
	lea	(dma_queue).w,a0
	IF (REPTN+1)<SlotCount
		bra.w	.done-(REPTN+1)*8	; 4 * 2 byte instructions
	ENDIF
	ENDR

	REPT SlotCount
	move.l	(a0)+,(a1)	; reg 23, reg 22
	move.l	(a0)+,(a1)	; reg 21, reg 20
	move.l	(a0)+,(a1)	; reg 19, dma first half
	move.w	(a0)+,(a1)	; dma command second half
	ENDR

.done
	resumeZ80
	dmaOff	(a1)

	move.w	#dma_queue,(dma_queue_pointer).w	; Reset dma_queue_pointer

	rts
