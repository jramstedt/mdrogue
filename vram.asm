; allocates memory from vram
; keeps track of free memory

; input:
; d0.w	Words to allocate
; output:
; d0.w	0 = No VRAM space available
; d1.l	VRAM address
allocVRAM
	lsl.w	d0			; word to bytes
	lea.l	vrm_first,a0		; vrm_first is current
	moveq	#0,d1

.loop
	tst.w	vrmNext(a0)
	beq	.notFound

	move.w	vrmStart(a0),d1
	add.w	d0,d1
	cmp.w	vrmEnd(a0),d1
	blo	.allocFromHoleStart
	beq	.allocFullHole
	
	cmp.l	#vrm_first,vrmNext(a0)
	beq	.notFound

	movea.l	vrmNext(a0),a0
	bra	.loop

.allocFromHoleStart
	move.l	d1,d0
	move.w	vrmStart(a0),d1
	move.w	d0,vrmStart(a0)
	rts

.allocFullHole
	move.w	vrmStart(a0),d1
	; copy next hole to this hole and clear next
	movea.l	vrmNext(a0),a1
	move.l	vrmNext(a1),vrmNext(a0)
	move.l	vrmStart(a1),vrmStart(a0)	; copy both start and end
	clr.l	vrmNext(a1)
	clr.l	vrmStart(a1)		; clears both start and end
	rts

.notFound				; No memory left in VRAM.
	moveq	#0,d0
	rts

; \1 	Word aligned VRAM address
; \2 	Size in words
	MACRO	reserveVRAM
	move.l	\1,d0
	move.l	\2,d1
	jsr	reserveVRAM
	ENDM

; input:
; d0 	Word aligned VRAM address
; d1 	Size in words
reserveVRAM
	lsl.w	d1			; word to bytes
	lea.l	vrm_first,a0		; vrm_first is current
	add	d0,d1			; End address

.loop
	tst.w	vrmNext(a0)
	beq	.notFound

	cmp.w	vrmStart(a0),d0
	blo	.notFound

	cmp.w	vrmEnd(a0),d1
	blo	.reserveHole
	beq	.reserveFullHole

	movea.l	vrmNext(a0),a0
	bra	.loop

.reserveHole
	cmp.w	vrmStart(a0),d0
	beq	.reserveFromHoleStart

	movea.l	a0,a1			; set current as previous

	lea.l	vrm_list,a0		; find free hole
.freeLoop
	tst.l	vrmStart(a0)		; tests both start and end for null
	beq	.makeHole

	lea	vrmDataSize(a0),a0
	cmpa.l	#vrm_list_end,a0
	blo.s	.freeLoop
	rts	; no free holes left!

.makeHole
	move.w	vrmEnd(a1),vrmEnd(a0)
	move.w	d0,vrmEnd(a1)		; shorten the current hole
	move.w	d1,vrmStart(a0)
	move.l	vrmNext(a1),vrmNext(a0)
	move.l	a0,vrmNext(a1)
	rts

.reserveFromHoleStart
	move.w	d1,vrmStart(a0)
	rts

.reserveFullHole
	; copy next hole to this hole and clear next
	movea.l	vrmNext(a0),a1
	move.l	vrmNext(a1),vrmNext(a0)
	move.l	vrmStart(a1),vrmStart(a0)	; copy both start and end
	clr.l	vrmNext(a1)
	clr.l	vrmStart(a1)		; clears both start and end
	rts

.notFound
	rts

; input:
; d0 	Word aligned VRAM address
; d1 	Size in words
freeVRAM
	lsl.w	d1			; word to bytes
	lea.l	vrm_first,a0		; vrm_first is current
	add	d0,d1			; End address

.loop
	tst.w	vrmNext(a0)
	beq	.notFound

	cmp.w	vrmStart(a0),d1
	beq	.mergeStart

	cmp.w	vrmEnd(a0),d0
	beq	.mergeEnd

	cmp.l	#vrm_first,vrmNext(a0)
	beq	.notFound

	movea.l	vrmNext(a0),a0
	bra	.loop

.notFound
	lea.l	vrm_list,a1		; find free hole
.freeLoop
	tst.l	vrmStart(a1)		; tests both start and end for null
	beq	.makeHole

	lea	vrmDataSize(a1),a1
	cmpa.l	#vrm_list_end,a1
	blo.s	.freeLoop
	rts	; no free holes left!

.mergeStart
	move.w	d0,vrmStart(a0)
	rts

.mergeEnd
	move.w	d1,vrmEnd(a0)
	rts

.makeHole
	move.l	vrmNext(a0),vrmNext(a1)
	move.w	d0,vrmStart(a1)
	move.w	d1,vrmEnd(a1)
	move.l	a1,vrmNext(a0)
	rts

; Initialize vram holes list
initVRAM
	lea.l	vrm_list,a0
	move.l	#vrm_first,vrmNext(a0)	; first hole points to itself
	move.w	#$0000,vrmStart(a0)
	move.w	#$FFFF,vrmEnd(a0)
	rts

; /1	Source address start
; /2	Source address end
; /3	Optional out VRAM address
 	MACRO allocAndQueueDMA
 	INLINE
	move.l	#(\2-\1)/sizeWord,d0
	jsr	allocVRAM
	tst	d0
	; d0.w	0 = No VRAM space available
        ; d1.l	VRAM address
        beq.s	.outOfMemory

	move.l	#\1,d0
	IF NARG=3
		move.w	d1,\3
	ENDIF
	move.l	#(\2-\1)/sizeWord,d2
	jsr	queueDMATransfer
.outOfMemory
	EINLINE
	ENDM
