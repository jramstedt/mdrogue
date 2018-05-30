waitVBlankOn
	btst    #3, vdp_ctrl+1
	bne     waitVBlankOn
	rts

waitVBlankOff
	btst    #3, vdp_ctrl+1
	beq     waitVBlankOff
	rts

waitDMAOn
	btst    #1, vdp_ctrl+1
	bne     waitDMAOn
	rts
