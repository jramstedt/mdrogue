; Loops while (VB = true) vertical blank is in progress
waitVBlankOn	MODULE
	btst	#3, vdp_ctrl+1
	bne.s	waitVBlankOn
	rts
	MODEND

; Loops while (VB = false) vertical blank is not in progress
waitVBlankOff	MODULE
	btst	#3, vdp_ctrl+1
	beq.s	waitVBlankOff
	rts
	MODEND

waitDMAOn	MODULE
	btst	#1, vdp_ctrl+1
	bne.s	waitDMAOn
	rts
	MODEND
