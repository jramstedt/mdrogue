objPlayer	MODULE
	moveq	#0, d0
	move.b	obState(a0), d0	; a0 is object address
	move.w	.routineJmpTable(pc,d0.w), d1
	jmp	.routineJmpTable(pc,d1.w)

.routineJmpTable
	dc.w	.main-.routineJmpTable
	dc.w	.input-.routineJmpTable
	dc.w	.display-.routineJmpTable
	dc.w	.delete-.routineJmpTable

		rsset	obClassData
shootTimer	rs.b	1		; in frames TODO PAL/NTSC
		rs.b	2		; free
padState	rs.b	1
moveDirX	rs.w	1		; last move direction X 8.8
moveDirY	rs.w	1		; last move direction Y 8.8
		classDataValidate

moveDir		equ	moveDirX

.main ; inits the object
	addq.b	#1<<1, obState(a0)	; set object state to .input
	move.w	#$0800, obRender(a0)
	move.b	#8, obRadius(a0)
	move.b	#1, obPhysics(a0)
	move.b	#$1F, obCollision(a0)

	move.w	#$1000, obAnim(a0)
	move.b	#0, obFrameTime(a0)

	move.l	#4*4, d7 		; hard coded for one sprite
	jsr	allocVRAM
	lsr.w	#5, d6			; address to pattern number
	or.w	d6, obVRAM(a0)

	move.b	#0, shootTimer(a0)	; shoot timer
	move.l	#0, moveDir(a0)		; last move direction

.input
	; read pad1State and lookup direction vector
	lea	dirVector, a3

	move.b	pad1State, d0
	andi.b	#%1111, d0
	lsl.w	#2, d0
	adda.w	d0, a3
	
	tst.l	(a3)			; check if vector is zero length
	beq 	.noMovement		; if zero there is no movement.
	
	move.b	pad1State, padState(a0)	; keep previous pad state for continued shooting

	movem.w	(a3), d0/d1
	movem.w	d0/d1, moveDir(a0)
	bra	.setVelocity

.noMovement
	; TODO NTSC vs. PAL?
	; halve velocity each frame
	clr.w	d3
	movem.w	obVelX(a0), d0/d1
	asr.w	d0
	addx.w	d3, d0
	asr.w	d1
	addx.w	d3, d1

.setVelocity
	movem.w	d0/d1, obVelX(a0)

	; TODO increase velocity over time

	asr.w	#4, d0
	asr.w	#4, d1

	add.w	d0, obX(a0)
	add.w	d1, obY(a0)

	jsr	collideWithLevel

	; can shoot?
	tst	shootTimer(a0)
	beq	.shoot

	sub.b	#1, shootTimer(a0)
	bne	.display

.shoot	btst	#6, pad1State
	bne	.display

	jsr	findTarget

	; create bullet
	jsr	findFreeObject
	move.b	#(idBullet<<4)|0, obClass(a2)
	move.b	#8, obRadius(a2)
	move.b	#1, obPhysics(a2)
	move.b	#$42, obCollision(a2)

	; set position to player position
	move.l	obX(a0), d0		; X and Y
	move.l	d0, obX(a2)
	
	; update shoot timer
	move.b	#5, shootTimer(a0)

	move.l	a1, d4
	bne	.shootAtTarget		; we have target

	; no target, shoot straight
	movem.w	moveDir(a0), d0/d1
	asr.w	#2, d0
	asr.w	#2, d1
	movem.w	d0/d1, obVelX(a2)

	bra.s	.display

.shootAtTarget
	; calculate shoot vector
	move.w	obX(a1), d0
	move.w	obY(a1), d1
	sub.w	obX(a0), d0
	sub.w	obY(a0), d1

	moveq	#0, d2
	move.w	d0, d2
	bpl.s	*+4	; skip neg
	neg.w	d2	; abs

	moveq	#0, d3
	move.w	d1, d3
	bpl.s	*+4	; skip neg
	neg.w	d3	; abs

	approxlen d2, d3	; d2 length
	
	ext.l	d0
	asl.l	#3, d0
	divs.w	d2, d0

	ext.l	d1
	asl.l	#3, d1
	divs.w	d2, d1

	movem.w	d0/d1, obVelX(a2)

.display
	; update main camera to player coordinates!
	
	lea	obX(a0), a1
	;vrotate a1, #-1&$FF

	;varctan a1, d2
	;vcpsign	a1, a1

	;moveq	#126, d3
	;moveq	#67, d4
	;approxlen d3, d4

	lea.l	mainCamera, a2
	moveq.l	#0, d2

	move.w	obX(a0), d3
	asr.w	#3, d3
	addx.w	d2, d3
	sub.w	#160, d3		; move offset by half screen width
	move.w	d3, camX(a2)

	move.w	obY(a0), d3
	asr.w	#3, d3
	addx.w	d2, d3
	sub.w	#112, d3		; move offset by half screen height
	move.w	d3, camY(a2)

	;move.l	obX(a0), d1		; XXXX YYYY
	;and.l	#$FFF8FFF8, d1
	;lsr.l	#3, d1			; convert to full pixels
	;move.l	d1, camX(a2)

	move	#aniOrc, a5
	jsr	animateSprite

	move	#spritesOrc, a5
	jsr	displaySprite

	rts

.delete
	move.w	obVRAM(a0), d6
	lsl.w	#5, d6			; pattern number to address
	move.l	#4*4, d7
	jsr	freeVRAM

	jsr	freeObject

	rts

	MODEND

objCollisionPlayer MODULE
	movem.w	moveDir(a0), d0/d1
	asl.w	#3, d0
	asl.w	#3, d1
	movem.w	d0/d1, obVelX(a1)

	rts

	MODEND

	EVEN

dirVector				; RLDU
	dc.w	$0000, $0000		; 0000 all directions are pressed down
	dc.w	$0000, $0100		; 0001
	dc.w	$0000, $FF00		; 0010
	dc.w	$0000, $0000		; 0011

	dc.w	$0100, $0000 		; 0100
	dc.w	$00B5, $00B5		; 0101
	dc.w	$00B5, $FF4B		; 0110
	dc.w	$0100, $0000		; 0111

	dc.w	$FF00, $0000		; 1000
	dc.w	$FF4B, $00B5		; 1001
	dc.w	$FF4B, $FF4B		; 1010
	dc.w	$FF00, $0000		; 1011

	dc.w	$0000, $0000		; 1100
	dc.w	$0000, $0100		; 1101
	dc.w	$0000, $FF00		; 1110
	dc.w	$0000, $0000		; 1111 none is pressed

	EVEN

findTarget MODULE
	moveq	#0, d7

	move.b	padState(a0), d7
	andi.b	#%1111, d7
	lsl.w	#1, d7				; 2 bytes per jump offset
	move.w	.dirJmpTable(pc, d7.w), d7

	movea	#0, a3				; last target
	move.l	#(160+90)<<3, d4			; last target distance (320/2) ; TODO FIXME hardcoded

	lea.l	hiGameObjectsFirst, a2
.processNext
	tst.w	llNext(a2)			; is last?
	beq.s	.end	; todo closest found?

	movea.w	llNext(a2), a2
	; tst.b	llStatus(a2)
	; beq.s	.processNext			; deleted, skip

	movea.l	llPtr(a2), a1			; a1 is game object
	; todo check type (shootable?)

	cmp.b	#(idCollider<<4)|0, obClass(a1)	; is collider
	bne.s	.processNext

	movem.w	obX(a0), d0/d1			; p
	movem.w	obX(a1), d2/d3			; e

	jsr	.dirJmpTable(pc, d7.w)

	cmp.w	d4, d2
	bgt	.processNext			; further away

	move	a1, a3
	move.w	d2, d4

	bra	.processNext

.end
	move	a3, a1				; set closest as target

	rts

.dirJmpTable	; gets distance to player to d2
	dc.w	.none-.dirJmpTable
	dc.w	.s-.dirJmpTable
	dc.w	.n-.dirJmpTable
	dc.w	.none-.dirJmpTable

	dc.w	.e-.dirJmpTable
	dc.w	.se-.dirJmpTable
	dc.w	.ne-.dirJmpTable
	dc.w	.e-.dirJmpTable

	dc.w	.w-.dirJmpTable
	dc.w	.sw-.dirJmpTable
	dc.w	.nw-.dirJmpTable
	dc.w	.w-.dirJmpTable

	dc.w	.none-.dirJmpTable
	dc.w	.s-.dirJmpTable
	dc.w	.n-.dirJmpTable
	dc.w	.none-.dirJmpTable

	; p = player
	; e = enemy
	; e' = p - e
	; a = 45' ==> a' = |sin(a)| = 0.7071067811865475244008443 ==> a' ~= 0.5
	;             a' = |cos(a)| = 0.7071067811865475244008443 ==> a' ~= 0.5
	; d = |cos(a)(e'y) - sin(a)(e'x)| = a' * (+-(e'y) - +-(e'x))
	; d = (+-(e'y) - +-(e'x)) >> 1

	; p = d2,d3  v = ?,?
	; p' = e - p
	; t = dot(e - p, v) / ||v||^2

	; y is -1 relative to mathematical coordinates
	; Distance is used only for comparison. It doesn't need to be in correct units or correct world scale.

.none	; Distance from player.
	; X diff
	sub.w	d0, d2
	bpl.s	*+4		; skip neg
	neg.w	d2		; abs
	; Y diff
	sub.w	d1, d3
	bpl.s	*+4		; skip neg
	neg.w	d3		; abs

	approxlen d2, d3	; d2 is length now
	rts

.n
	; v = 0,-1
	; t = -p'y

	; p'
	moveq	#0, d2
	sub.w	d1, d3

	; t
	sub.w	d3, d2
	bmi.s	.behind

	; sin(-90) = -1
	; cos(-90) = 0

	; d = |0*(e'y) - -1*(e'x)| ==> |(e'x)|

	; e'
	sub.w	obX(a1), d0
	
	; d
	bpl.s	*+4		; skip neg
	neg.w	d0		; abs

	asl.w	d0		; double scale to limit into 22.25' and prioritise projected distance from player
	cmp.w	d0, d2
	bmi.s	.outside

	; t + d
	add.w	d0, d2

	rts
.ne
	; v = 1,-1
	; t = p'x - p'y >> 1

	; p'
	sub.w	d0, d2
	sub.w	d1, d3

	; t
	sub.w	d3, d2
	bmi.s	.behind

	; t >> 1
	asr.w	d2

	; sin(-45) = -0.70710678118654752440084436210485
	; cos(-45) = +0.70710678118654752440084436210485

	; d = |0.7*(e'y) - -0.7*(e'x)| ==> 0.7 * |(e'y) + (e'x)| ==> ~ |(e'y) + (e'x)| >> 1

	; e'
	sub.w	obX(a1), d0
	sub.w	obY(a1), d1

	; d
	add.w	d1, d0
	bpl.s	*+4		; skip neg
	neg.w	d0		; abs

	; Note: d0 is already doubled, since its not shifted right
	cmp.w	d0, d2
	bmi.s	.outside

	; t + d
	add.w	d0, d2
	
	rts
.e
	; v = 1,0
	; t = p'x

	; p'
	sub.w	d0, d2

	; t
	bmi.s	.behind

	; sin(0) = 0
	; cos(0) = 1

	; d = |1*(e'y) - 0*(e'x)| ==> |(e'y)|

	; e'
	sub.w	obY(a1), d1

	; d
	bpl.s	*+4		; skip neg
	neg.w	d1		; abs

	asl.w	d1		; double scale to limit into 22.25' and prioritise projected distance from player
	cmp.w	d1, d2
	bmi.s	.outside

	; t + d
	add.w	d1, d2

	rts
.se
	; v = 1,1
	; t = p'x + p'y >> 1

	; p'
	sub.w	d0, d2
	sub.w	d1, d3

	; t
	add.w	d3, d2
	bmi.s	.behind

	; t >> 1
	asr.w	d2

	; sin(45) = +0.70710678118654752440084436210485
	; cos(45) = +0.70710678118654752440084436210485

	; d = |0.7*(e'y) - 0.7*(e'x)| ==> 0.7 * |(e'y) - (e'x)| ==> ~ |(e'y) - (e'x)| >> 1

	; e'
	sub.w	obX(a1), d0
	sub.w	obY(a1), d1

	; d
	sub.w	d1, d0
	bpl.s	*+4		; skip neg
	neg.w	d0		; abs

	; Note: d0 is already doubled, since its not shifted right
	cmp.w	d0, d2
	bmi.s	.outside

	; t + d
	add.w	d0, d2
	
	rts

.behind
	add.w	#$7FFF, d2
	rts

.outside
	move.w	#$7FFF, d2
	rts

.s
	; v = 0,1
	; t = p'y

	; p'
	moveq	#0, d2
	sub.w	d1, d3

	; t
	add.w	d3, d2
	bmi.s	.behind

	; sin(90) = 1
	; cos(90) = 0

	; d = |0*(e'y) - 1*(e'x)| ==> |(e'x)|

	; e'
	sub.w	obX(a1), d0
	
	; d
	bpl.s	*+4		; skip neg
	neg.w	d0		; abs

	asl.w	d0		; double scale to limit into 22.25' and prioritise projected distance from player
	cmp.w	d0, d2
	bmi.s	.outside

	; t + d
	add.w	d0, d2

	rts
.sw
	; v = -1,1
	; t = -p'x + p'y >> 1

	; p'
	sub.w	d0, d2
	sub.w	d1, d3
	neg.w	d2

	; t
	add.w	d3, d2
	bmi.s	.behind

	; t >> 1
	asr.w	d2

	; sin(135) = +0.70710678118654752440084436210485
	; cos(135) = -0.70710678118654752440084436210485

	; d = |-0.7*(e'y) + -0.7*(e'x)| ==> 0.7 * |(e'y) + (e'x)| ==> ~ |(e'y) + (e'x)| >> 1

	; e'
	sub.w	obX(a1), d0
	sub.w	obY(a1), d1

	; d
	add.w	d1, d0
	bpl.s	*+4		; skip neg
	neg.w	d0		; abs

	; Note: d0 is already doubled, since its not shifted right
	cmp.w	d0, d2
	bmi.s	.outside

	; t + d
	add.w	d0, d2

	rts
.w
	; v = -1,0
	; t = -p'x

	; p'
	sub.w	d0, d2
	neg.w	d2

	; t
	bmi.s	.behind

	; sin(180) = 0
	; cos(180) = -1

	; d = |-1*(e'y) - 0*(e'x)| ==> |(e'y)|

	; e'
	sub.w	obY(a1), d1

	; d
	bpl.s	*+4		; skip neg
	neg.w	d1		; abs

	asl.w	d1		; double scale to limit into 22.25' and prioritise projected distance from player
	cmp.w	d1, d2
	bmi.s	.outside

	; t + d
	add.w	d1, d2

	rts
.nw
	; v = -1,-1
	; t = -p'x - p'y >> 1

	; p'
	sub.w	d0, d2
	sub.w	d1, d3
	neg.w	d2

	; t
	sub.w	d3, d2
	bmi.s	.behind

	; t >> 1
	asr.w	d2

	; sin(-135) = -0.70710678118654752440084436210485
	; cos(-135) = -0.70710678118654752440084436210485

	; d = |-0.7*(e'y) - -0.7*(e'x)| ==> 0.7 * |(e'y) - (e'x)| ==> ~ |(e'y) - (e'x)| >> 1

	; e'
	sub.w	obX(a1), d0
	sub.w	obY(a1), d1

	; d
	sub.w	d1, d0
	bpl.s	*+4		; skip neg
	neg.w	d0		; abs

	; Note: d0 is already doubled, since its not shifted right
	cmp.w	d0, d2
	bmi.s	.outside

	; t + d
	add.w	d0, d2
	
	rts

	MODEND
