; allocates memory from vram
; keeps track of free memory

; input:
; d7	number of patterns (32 = $20 bytes per pattern)
; output:
; d7	VRAM address for patterns
; trash:
; a2, a3, d6
allocVRAM
	lea.l	vrm_first, a3	; vrm_first is previous
	movea.l	(a3), a2
	moveq	#0, d6

@loop
	tst	(a2)
	beq	@notFound

	move.w	vrmStart(a2), d6
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