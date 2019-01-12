haltZ80 MACRO
	local waitAck
	move.w	#$100, Z80_busreq
waitAck	btst.b	#0, z80_busreq
	bne.s	waitAck
	ENDM

resumeZ80 MACRO
	move.w	#$00, Z80_busreq
	ENDM