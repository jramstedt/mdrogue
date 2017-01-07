waitVBlankOn
	btst    #3, vdp_ctrl+1
	bne     waitVBlankOn
	rts

waitVBlankOff
	btst    #3, vdp_ctrl+1
	beq     waitVBlankOff
	rts
