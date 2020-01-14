haltZ80 MACRO
	local waitAck
	move.w	#%0000000100000000, Z80_busreq
waitAck	btst.b	#0, z80_busreq	; Byte access = bit 0. (Word access = bit 8)
	bne.s	waitAck
	ENDM

resumeZ80 MACRO
	move.w	#$00, Z80_busreq
	ENDM