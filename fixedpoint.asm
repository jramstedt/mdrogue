
; dst = round(dst) as int
ftori MACRO
	moveq.l	#0, \2
	asr.w	#4, \1
	addx.w	\2, \1
	ENDM

; dst = dst as int
ftoi MACRO
	asr.w	#4, \1
	ENDM

; dst = src as fp + dst
; src will be fixed point!
faddi MACRO
	asl.w	#4, \1
	add.w	\1, \2
	ENDM

; dst = dst - src as fp
; src will be fixed point!
fsubi MACRO
	asl.w	#4, \1
	sub.w	\1, \2
	ENDM

; dst = dst * src
fmul MACRO
	muls.w	\1, \2
	asr.l	#4, \2
	ENDM

; dst = dst / src
fdiv MACRO
	ext.l	\2
	asl.l	#4, \2
	divs.w	\1, \2
	ENDM

; dst = dst as fixed point
itof MACRO
	asl.w	#4, \1
	ENDM

; dst = src as int + dst 
; src will be int!
iaddf MACRO
	asr.w	#4, \1
	addx.w	\1, \2
	ENDM

; dst = dst - src as int
; src will be int!
isubf MACRO
	asr.w	#4, \1
	subx.w	\1, \2
	ENDM

sinCos MACRO table, angle, sin, cos
	lsl.w	#2, \2	; to long
	movem.w	(\1, \2.w), \3/\4
	ENDM

sin MACRO table, angle, sin
	lsl.w	#2, \2	; to long
	move.w	(\1, \2.w), \3
	ENDM

cos MACRO table, angle, cos
	lsl.w	#2, \2	; to long
        move.w	(2, \1, \2.w), \3
        ENDM