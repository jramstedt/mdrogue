; Loops while (VB = true) vertical blank is in progress
waitVBlankOn
	btst	#3,vdp_ctrl+1
	bne.s	waitVBlankOn
	rts

; Loops while (VB = false) vertical blank is not in progress
waitVBlankOff
	btst	#3,vdp_ctrl+1
	beq.s	waitVBlankOff
	rts

; Loops while (DMA = true) DMA transfer is in progress
waitDMAOn
	btst	#1,vdp_ctrl+1
	bne.s	waitDMAOn
	rts
