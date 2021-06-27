;
toPatterns MACRO positionPixels, offsetPixels, out
	moveq.l	#0, \out
	move.w	\positionPixels, \out
	IF offsetPixels<>0
		add	#\offsetPixels, \out
	ENDIF
	asr.w	#3, \out
	ENDM

; Calculates chunk start position in patterns
; x in patterns
xChunkStart MACRO x
	; >>5 then <<5 == AND $FFE0
	;lsr.w	#5, \x		; patterns to full chunk widths
	;lsl.l	#10, \x		; to number of patterns in chunk (32*32)

	and.w	#$FFE0, \x	; full chunks, already in rows (*32)
	lsl.l	#5, \x		; multiply by 32 to get full chunks (32*32)
	ENDM

;
yChunkStart MACRO level, y
	and.w	#$FFE0, \y	; full chunks, already in rows (*32)
	lsl.l	#5, \y		; multiply by 32 to get full chunks (32*32)
	move.b	lvlWidth(\level), d3
	mulu.w	d3, \y		; multiply by amount of chunks in row
	ENDM

;
chunkOffset MACROS c
	and.w	#$1F, \c	; in patterns (chunk space)

;
copyRowToVram MACRO level, camera, xOffset, yOffset
	local initCopy, startCopyLoop, copy, queueRowToVram, lastTransfer, complete

	move.l	#0, d6

	; full chunks
	toPatterns camY(\camera), \yOffset, d2
	move.l	d2, d5
	yChunkStart \level, d2	; full chunk rows in patterns
	add	d2, d6

	; full rows
	chunkOffset d5
	lsl.l	#5, d5		; to full rows of patterns
	add	d5, d6
	
	; full chunks
	toPatterns camX(\camera), \xOffset, d2
	move.l	d2, d4
	xChunkStart d2
	add	d2, d6

	; patterns
	chunkOffset d4
	add	d4, d6
	
	move.l	lvlPlaneBTiles(\level), a2
	lsl.l	d6			; 2 bytes per pattern
	adda.l	d6, a2
	
	move	#horBufferLen, d2	; number of patterns needed to fill screen row
	lea.l	horBuffer, a3
initCopy
	move	#lvlChunkSize, d3	; number of patterns in row of chunk
	sub	d4, d3			; number of patterns left in this row
	beq	queueRowToVram		; 0 needed to fill, skip copying

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

	; skip to next chunk, and move to start of the row
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

	setVDPAutoIncrement 2

	cmp	#64-horBufferLen, d2
	ble	lastTransfer

	; overflow, draw till right side
	move	#64, d7
	sub	d2, d7

	haltZ80
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
	jsr	startDMATransfer	; draw buffer
	resumeZ80

complete

	ENDM

copyColumnToVram MACRO level, camera, xOffset, yOffset
	local initCopy, startCopyLoop, copy, dmaColumnToVram, lastTransfer, complete

	; full chunks
	toPatterns camY(\camera), \yOffset, d2
	move.l	d2, d5
	yChunkStart \level, d2	; full chunk rows in patterns
	move.l	d2, d6

	; full rows
	chunkOffset d5
	move.l	d5, d2
	lsl.l	#5, d2		; d2 is number of patterns (rows * lvlChunkSize)
	add	d2, d6

	toPatterns camX(\camera), \xOffset, d2
	move.l	d2, d4
	xChunkStart d2
	add	d2, d6
	chunkOffset d4
	add	d4, d6

	move.l	lvlPlaneBTiles(\level), a2
	lsl.l	d6	; 2 bytes per pattern
	adda.l	d6, a2

	; calculate bytes to to next row
	moveq.l	#0, d6
	moveq.l #11, d4		; 1024 (lvlChunkArea), 2 bytes per pattern
	move.b	lvlWidth(\level), d6
	subq.b	#1, d6
	lsl.l	d4, d6

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
	adda.l	#lvlChunkSize<<1, a2	; increase by full row of patterns (32), 2 bytes per pattern
	dbra	d3, copy

	; a2 is now at the next chunk

	; skip to next chunk
	adda.l	d6, a2

	move	#0, d5	; start from zero y
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

	setVDPAutoIncrement $80

	cmp	#32-verBufferLen, d3
	ble	lastTransfer

	; overflow, draw till bottom side
	move	#32, d7
	sub	d3, d7

	haltZ80
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
	jsr	startDMATransfer
	resumeZ80

complete

	ENDM
