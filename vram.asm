; allocates memory from vram
; keeps track of free memory

; input:
; d7	number of patterns (32 = $20 bytes per pattern)
; output:
; d7	VRAM address for patterns
; trash:
; a2, a3, d6, d7
allocVRAM
	lsl.l	#5, d7	; pattern amount to bytes
	lea.l	vrm_first, a3	; vrm_first is previous
	movea.l	(a3), a2
	moveq	#0, d6

@loop
	tst.w	(a2)
	beq	@notFound

	move.w	vrmStart(a2), d6
	add	d7, d6
	cmp.w	vrmEnd(a2), d6
	blo	@allocFromHoleStart
	beq	@allocFullHole
	
	movea.l a2, a3	; set current as previous
	movea.l	vrmNext(a2), a2
	bra	@loop

@allocFromHoleStart
	move.w	vrmStart(a2), d7
	move.w	d6, vrmStart(a2)
	rts

@allocFullHole
	move.w	vrmStart(a2), d7
	move.l	vrmNext(a2), vrmNext(a3)	; move link
	clr.l	vrmNext(a2)
	clr.l	vrmStart(a2)
	rts

@notFound	; No memory left in VRAM.
	moveq	#0, d7
	rts

reserveVRAM MACRO sourceMem, lenPatterns
	move.l \sourceMem, d6
	move.l \lenPatterns, d7
	jsr _reserveVRAM
	ENDM

; input:
; d6 VRAM address
; d7 number of patterns
_reserveVRAM
	lsl.l	#5, d7	; pattern amount to bytes
	lea.l	vrm_first, a3	; vrm_first is previous
	movea.l	(a3), a2

@loop
	tst.w	(a2)
	beq	@notFound

	cmp.w	vrmStart(a2), d6
	blo @notFound

	add	d6, d7
	cmp.w	vrmEnd(a2), d7
	blo	@reserveHole
	beq	@reserveFullHole

	movea.l a2, a3	; set current as previous
	movea.l	vrmNext(a2), a2
	bra	@loop

@reserveHole
	cmp.w	vrmStart(a2), d6
	beq	@reserveFromHoleStart

	move.w	vrmEnd(a2), d5	; d5 is end for new hole
	move.w	d6, vrmEnd(a2)

	move.l	a2, a3

	lea.l	vrm_list, a2
	move.l	#9, d6	; see memorymap.asm, max 10 vrm holes
@freeLoop	
	tst.l	vrmStart(a2) ; tests both start and end for null
	beq	@makeHole

	lea	vrmDataSize(a2), a2
	dbra d6, @freeLoop
	rts ; no free holes left!

@makeHole
	move.w	d7, vrmStart(a2)
	move.w	d5, vrmEnd(a2)
	move.l	vrmNext(a3), vrmNext(a2)
	move.l	a2, vrmNext(a3)
	rts

@reserveFromHoleStart
	move.w	d7, vrmStart(a2)
	rts

@reserveFullHole
	move.l	vrmNext(a2), vrmNext(a3)	; move link
	clr.l	vrmNext(a2)
	clr.l	vrmStart(a2)
	rts

@notFound
	rts

; input:
; d6 VRAM address
; d7 number of patterns
; trash:
; a3, d5, d7
freeVRAM
	move.l	d6,	d5
	lsl	#5, d7
	add	d7, d5 ; d5 is the VRAM end address
	lea.l	vrm_first, a3
	movea.l	(a3), a2

@loop
	tst.w	(a2)
	beq	@notFound

	cmp.w	vrmEnd(a2), d6
	beq	@mergeEnd

	cmp.w	vrmStart(a2), d5
	beq	@mergeStart
	blo @notFound

	movea.l a2, a3	; set a3 as last link in list (this is to keep linked list in order)

	movea.l	vrmNext(a2), a2
	bra	@loop

@notFound
	lea.l	vrm_list, a2
	move.l	#9, d7	; see memorymap.asm, max 10 vrm holes
@freeLoop	
	tst.l	vrmStart(a2) ; tests both start and end for null
	beq	@makeHole

	lea	vrmDataSize(a2), a2
	dbra d7, @freeLoop
	rts ; no free holes left!

@mergeStart
	move.w	d6, vrmStart(a2)
	rts

@mergeEnd
	move.w	d5, vrmEnd(a2)
	rts

@makeHole
	move.w	d6, vrmStart(a2)
	move.w	d5, vrmEnd(a2)
	move.l	vrmNext(a3), vrmNext(a2)
	move.l	a2, vrmNext(a3)
	rts

allocAndQueueDMA MACRO sourceStart, sourceEnd, outVramAddress
	local dataLen
dataLen equ sourceEnd-sourceStart

	move.l #dataLen/sizePattern, d7
	jsr allocVRAM

	if	narg=3
		move.w	d7, \outVramAddress
	endif

	move.l #sourceStart, d5
	move.l d7, d6
	move.l #dataLen/sizeWord, d7
	jsr _queueDMATransfer
	ENDM