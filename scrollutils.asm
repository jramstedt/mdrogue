;
toPatterns MACRO positionPixels, offsetPixels, out
	move.l	#0, \out
	move.w	\positionPixels, \out
	if offsetPixels<>0
		add	#\offsetPixels, \out
	endif
	asr.w	#3, \out
	ENDM

;
chunkSizeShift MACROS y
	lsl.l	#5, \y		; multiply by 32 (lvlChunkSize)

;
xChunkStart MACRO x
	and.w	#$FFE0, \x	; full chunks in patterns
	chunkSizeShift \x
	ENDM

;
yChunkStart MACRO level, y
	and.w	#$FFE0, \y	; full chunks in patterns
	move.b	lvlWidth(\level), d3
	mulu.w	d3, \y		; multiply by amount of chunks in row
	chunkSizeShift \y
	ENDM

;
chunkOffset MACROS c
	and.w	#$1F, \c	; in patterns (chunk space)

;
copyRowToVram MACRO level, camera, xOffset, yOffset
	local initCopy, startCopyLoop, copy, queueRowToVram, lastTransfer, complete

	move.l	#0, d6

	toPatterns camY(\camera), \yOffset, d2
	move.l	d2, d5
	yChunkStart \level, d2
	add	d2, d6
	chunkOffset d5
	chunkSizeShift d5
	add	d5, d6
	
	toPatterns camX(\camera), \xOffset, d2
	move.l	d2, d4
	xChunkStart d2
	add	d2, d6
	chunkOffset d4
	add	d4, d6
	
	move.l	planeBTiles(\level), a2
	lsl.l	d6			; 2 bytes per pattern
	adda.l	d6, a2
	
	move	#horBufferLen, d2	; number of patterns needed to fill screen row
	lea.l	horBuffer, a3
initCopy
	move	#lvlChunkSize, d3	; number of patterns in row of chunk
	sub	d4, d3			; number of patterns left in this row

	cmp	d3, d2			; is space left in buffer for full row of patterns
	bge	startCopyLoop		; if there is then start copying
	
	move	d2, d3			; else copy only what is needed to fill buffer
	beq	queueRowToVram		; 0 needed to fill, skip copying

startCopyLoop
	sub	d3, d2			; d2 = number of patterns left in the screen row

	sub	#1, d3
copy
	move.w	(a2)+, (a3)+
	dbra	d3, copy

	; skip to next chunk
	adda.l	#(lvlChunkArea-lvlChunkSize)<<1, a2

	move	#0, d4	; start from zero x
	bra	initCopy

queueRowToVram
	; source
	move.l	#horBuffer, d5

	; amount
	move.l	#horBufferLen, d7

	; destination address base
	toPatterns camY(\camera), \yOffset, d3
	and.w	#$1F, d3

	move.l	d3, d6
	asl.w	#6, d6	; scroll plane width 64

	toPatterns camX(\camera), \xOffset, d2
	and.w	#$3F, d2
	add	d2, d6
	
	lsl.w	d6	; 2 bytes per pattern
	add.l	#vdp_map_bnt, d6

	cmp	#64-horBufferLen, d2
	ble	lastTransfer

	; overflow, draw till right side
	move	#64, d7
	sub	d2, d7

	haltZ80
	setVDPAutoIncrement 2
	jsr	startDMATransfer	; draw buffer
	resumeZ80

	move	#64, d7
	sub	d2, d7

	; draw rest from left side
	move.l	d7, d5
	lsl.l	d5	; 2 bytes per pattern
	add.l	#horBuffer, d5

	move.l	d3, d6
	asl.w	#6, d6	; scroll plane width 64
	lsl.l	d6	; 2 bytes per pattern
	add	#vdp_map_bnt, d6

	move.l	#horBufferLen, d3
	sub.w	d7, d3
	beq	complete

	move.l	d3, d7

lastTransfer
	haltZ80
	setVDPAutoIncrement 2
	jsr startDMATransfer	; draw buffer
	resumeZ80

complete

	ENDM

copyColumnToVram MACRO level, camera, xOffset, yOffset
	local initCopy, startCopyLoop, copy, dmaColumnToVram, lastTransfer, complete

	move.l	#0, d6

	toPatterns camY(\camera), \yOffset, d2
	move.l	d2, d5
	yChunkStart \level, d2
	add	d2, d6
	chunkOffset d5
	move.l	d5, d2
	chunkSizeShift	d2
	add	d2, d6

	toPatterns camX(\camera), \xOffset, d2
	move.l	d2, d4
	xChunkStart d2
	add	d2, d6
	chunkOffset d4
	add	d4, d6

	move.l	planeBTiles(\level), a2
	lsl.l	d6	; 2 bytes per pattern
	adda.l	d6, a2

	move.l	#0, d6
	move.b	lvlWidth(\level), d6
	subq.b	#1, d6
	lsl.l	#8, d6		; 1024 (lvlChunkArea)
	lsl.l	#3,	d6	; 2 bytes per pattern

	move	#verBufferLen, d2	; number of patterns needed to fill screen column (patterns left in buffer)
	lea.l	verBuffer, a3
initCopy
	move	#lvlChunkSize, d3	; number of patterns in column of chunk
	sub	d5, d3			; number of patterns left in this column
	beq	dmaColumnToVram		; 0 needed to fill, skip copying

	cmp	d3, d2			; is space left in buffer for full column of patterns
	bge	startCopyLoop		; if there is then start copying

	move	d2, d3			; else copy only what is needed to fill buffer
	beq	dmaColumnToVram		; 0 needed to fill, skip copying

startCopyLoop
	sub	d3, d2			; subtract amount of copied patterns

	sub	#1, d3
copy
	move.w	(a2), (a3)+
	adda.l	#lvlChunkSize<<1, a2	; increase by full row of patterns
	dbra	d3, copy

	; skip to next chunk
	adda.l	d6, a2

	move	#0, d5	; start from zero x
	bra	initCopy

dmaColumnToVram
	; source
	move.l	#verBuffer, d5

	; amount
	move.l	#verBufferLen, d7

	; destination address base
	toPatterns camY(\camera), \yOffset, d3
	and.w	#$1F, d3
	
	move.l	d3, d6
	asl.w	#6, d6	; scroll plane width 64

	toPatterns camX(\camera), \xOffset, d2
	and.w	#$3F, d2
	add	d2, d6
	
	lsl.w	d6	; 2 bytes per pattern
	add.l	#vdp_map_bnt, d6

	cmp	#32-verBufferLen, d3
	ble	lastTransfer

	; overflow, draw till bottom side
	move	#32, d7
	sub	d3, d7

	haltZ80
	setVDPAutoIncrement $80
	jsr	startDMATransfer
	resumeZ80

	move	#32, d7
	sub	d3, d7

	; draw rest from top side
	move.l	d7, d5
	lsl.l	d5	; 2 bytes per pattern
	add.l	#verBuffer, d5

	move.l	d2, d6
	lsl.l	d6	; 2 bytes per pattern
	add	#vdp_map_bnt, d6

	move.l	#verBufferLen, d3
	sub.w	d7, d3
	beq	complete

	move.l	d3, d7

lastTransfer
	haltZ80
	setVDPAutoIncrement $80
	jsr	startDMATransfer
	resumeZ80

complete

	ENDM
