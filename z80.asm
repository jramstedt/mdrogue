	MACRO haltZ80
	INLINE
	move.w	#$0100,Z80_busreq
.waitAck
	btst.b	#0,Z80_busreq	; Byte access = bit 0. (Word access = bit 8)
	bne.s	.waitAck
	EINLINE
	ENDM

	MACRO fastHaltZ80
	move.w	#$0100,Z80_busreq
	ENDM

	MACRO resumeZ80
	move.w	#$0000,Z80_busreq
	ENDM

	MACRO resetZ80assert
	INLINE
	move.w	#$0000,Z80_reset
	move.w  #16,d0	; Wait ~192 cycles
.wait	; Document says Z80 reset requires 26ms?
	dbra	d0,.wait
	EINLINE
	ENDM

	MACRO resetZ80release
	move.w	#$0100,Z80_reset
	ENDM
