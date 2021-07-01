waitVBlankOn	MODULE
	btst	#3, vdp_ctrl+1
	bne.s	waitVBlankOn
	rts
	MODEND

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
