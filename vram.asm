; allocates memory from vram
; keeps track of free memory

; input:
; d7	number of patterns (32 = $20 bytes per pattern)
; output:
; d7	VRAM address for patterns
; trash:
; a2, a3, d6, d7
allocVRAM
	lea.l	vrm_first, a3	; vrm_first is previous
	movea.l	(a3), a2
	moveq	#0, d6

@loop
	tst.w	(a2)
	beq	@notFound

	move.w	vrmStart(a2), d6
	mulu #$20, d7
	add	d7, d6
	cmp.w	vrmEnd(a2), d6
	bhi	@allocFromHoleStart
	beq	@allocFullHole
	
	movea.l a2, a3	; set current as previous
	movea.l	vrmNext(a2), a2
	bra	@loop

@allocFromHoleStart
	move.w	d6, d7
	move.w	d6, vrmStart(a2)
	bra @exit

@allocFullHole
	move.w	d6, d7
	move.l	vrmNext(a2), vrmNext(a3)	; move link
	clr.l	vrmNext(a2)
	bra @exit

@notFound	; No memory left in VRAM.
	moveq	#0, d7	

@exit
	rts

; input:
; d6 VRAM address
; d7 number of patterns
; trash:
; a3, d5, d7
freeVRAM
	move.l	d6,	d5
	mulu #$20, d7
	add	d7, d5 ; d5 is the VRAM end address
	lea.l	vrm_first, a3
	movea.l	(a3), a2

@loop
	tst.w	(a2)
	beq	@notFound

	cmp.w	vrmEnd(a2), d6
	beq	@mergeEnd

	cmp.w	d5, vrmStart(a2)
	beq	@mergeStart
	blt @notFound

	movea.l a2, a3	; set a3 as last link in list (this is to keep linked list in order)

	movea.l	vrmNext(a2), a2
	bra	@loop

@notFound
	lea.l	vrm_list, a2
	move.w	#9, d7	; see memorymap.asm, max 10 vrm holes
@freeLoop	
	tst.l	vrmStart(a2) ; tests both start and end for null
	beq	@makeHole

	lea	vrmDataSize(a0), a0
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
