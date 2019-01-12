waitVBlankOn
	btst	#3, vdp_ctrl+1
	bne.s	waitVBlankOn
	rts

waitVBlankOff
	btst	#3, vdp_ctrl+1
	beq.s	waitVBlankOff
	rts

waitDMAOn
	btst	#1, vdp_ctrl+1
	bne.s	waitDMAOn
	rts
