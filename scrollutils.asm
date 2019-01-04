
calculateCopyStartAddress	MACRO level, camera, outAddress, xOffset, yOffset
	move.l	#0, d2
	move.l	#0, d3
	move.l	#0, d4

	; Y offset
	move.w  camY(\camera), d2
	if yOffset<>0
		add	#\yOffset, d2
	endif
	asr.w	#3,	d2				; y in patterns
	move.w	d2, d4

	and.w	#$FFE0, d2			; full chunks in patterns
	move.b	lvlWidth(\level), d3
	mulu.w	d3, d2				; multiply by amount of chunks in row

	and.w	#$1F, d4 			; y in patterns (chunk space)
	add		d4, d2

	; from address
	lsl.l	#6,	d2				; multiply by 32 (lvlChunkSize), 2 bytes per pattern
	add.l	planeATiles(\level), d2
	move.l	d2, \outAddress				; start address of row in map data

	; X offset
	move.w  camX(\camera), d2
	if xOffset<>0
		add	#\xOffset, d2
	endif
	asr.w	#3,	d2				; x in patterns
	move.w	d2, d4

	and.w	#$FFE0, d2			; full chunks in patterns
	lsl.l	#5,	d2				; multiply by 32 (lvlChunkSize)

	and.w	#$1F, d4 			; x in patterns (chunk space)
	add		d4, d2

	lsl.l	#1,	d2				; 2 bytes per pattern
	add.l	d2, \outAddress

	ENDM

; fill scroll buffer
copyRowToBuffer	MACRO rowAddress
	local initCopy, startCopyLoop, copy, complete

	move	#scrollBufferLen, d2	; d2 = number of patterns needed to fill screen row
	lea.l	scrollBuffer, a3
initCopy
	move	#lvlChunkSize, d3	; d5 = number of patterns in row of chunk
	sub		d4, d3				; d5 = number of patterns left in this row

	cmp		d3, d2
	bge		startCopyLoop

	move	d2, d3
	beq		complete

startCopyLoop
	sub		d3, d2				; d2 = number of patterns left in the screen row

	sub		#1, d3
copy
	move.w	(\rowAddress)+, (a3)+
	dbra	d3, copy

	; skip to next chunk
	move.l	#lvlChunkArea-lvlChunkSize, d3
	lsl.l	#1,	d3
	add.l	d3, \rowAddress

	move	#0, d4	; start from zero x
	bra		initCopy

complete
	ENDM

queueRowToVram	MACRO camera, xOffset, yOffset
	local lastCopy, complete

	move.l	#0, d2
	move.l	#0, d3
	move.l	#0, d6

	; source
	move.l	#scrollBuffer, d5

	; amount
	move.l	#scrollBufferLen, d7

	; destination address base
	move.w  camY(\camera), d3
	if yOffset<>0
		add	#\yOffset, d3
	endif
	asr.w	#3,	d3 ; y in patterns
	and.w	#$1F, d3
	asl.w	#6,	d3	; plane width 64

	move.w  camX(\camera), d2
	if xOffset<>0
		add	#\xOffset, d2
	endif
	and.w	#$1FF, d2
	asr.w	#3,	d2	; x in patterns

	move	d3,	d6
	add		d2, d6
	asl.w	#1,	d6	; 2 bytes per pattern
	add		#vdp_map_bnt, d6

	cmp		#64-scrollBufferLen, d2
	blt		lastCopy

	; overflow, draw till right side
	move	#64, d7
	sub		d2, d7

	jsr _queueDMATransfer	; draw buffer

	; draw rest from left side
	move.l	d7,	d5
	asl		#1,	d5	; 2 bytes per pattern
	add.l	#scrollBuffer, d5

	move.l	d3,	d6
	asl.w	#1,	d6	; 2 bytes per pattern
	add		#vdp_map_bnt, d6

	move.l	#scrollBufferLen, d3
	sub.w	d7, d3
	beq		complete

	move.l	d3, d7

lastCopy
	jsr _queueDMATransfer	; draw buffer

complete

	ENDM
