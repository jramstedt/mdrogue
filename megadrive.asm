; I/O ports
io_ver		equ	$00A10001
io_data1	equ	$00A10003	; DATA 1 ( CTRL1 )
io_data2	equ	$00A10005	; DATA 2 ( CTRL2 )
io_data3	equ	$00A10007	; DATA 3 ( EXP   )
io_expRst	equ	$00A10008	; RESET
io_ctrl1	equ	$00A10009	; CTRL 1
io_ctrl2	equ	$00A1000B	; CTRL 2
io_ctrl3	equ	$00A1000D	; CTRL 3
io_tx1		equ	$00A1000F	; TxDATA 1
io_rx1		equ	$00A10011	; RxDATA 1
io_sctrl1	equ	$00A10013	; S-CTRL 1
io_tx2		equ	$00A10015	; TxDATA 2
io_rx2		equ	$00A10017	; RxDATA 2
io_sctrl2	equ	$00A10019	; S-CTRL 2
io_tx3		equ	$00A1001B	; TxDATA 3
io_reset	equ	$00A1000C	; RESET
io_rx3		equ	$00A1001D	; RxDATA 3
io_sctrl3	equ	$00A1001F	; S-CTRL 3

mem_mode	equ	$00A11000	; Memory mode, W $0000 = ROM, $0100 = D-RAM

Z80_ram		equ	$00A00000	; Z80 RAM start. 8KB. Byte access only.
Z80_busreq	equ	$00A11100	; Z80 Bus request, W $0000 = cancel, $0100 = request
Z80_reset	equ	$00A11200	; Z80 Reset

TMSS		equ	$00A14000

	include 'z80.asm'
	include 'vdp.asm'
	include 'dma.asm'

; Read game pads
; \1	pad1State
; \2	pad2State
	MACRO readGamePads
	clr.l	d0
	clr.l	d1

	haltZ80
	move.b	#$40,io_data1  ; Select 00CBRLDU
	move.b	#$40,io_data2  ; Select 00CBRLDU
	move.b	io_data1,d0    ; Read 00CBRLDU
	swap	d0
	move.b	io_data2,d0    ; Read 00CBRLDU
	move.b	#$00,io_data1  ; select 00SA00DU
	move.b	#$00,io_data2  ; select 00SA00DU
	move.b	io_data1,d1    ; Read 00SA00DU
	swap	d1
	move.b	io_data2,d1    ; Read 00SA00DU
	resumeZ80
	andi.l	#$003F003F,d0	; 00CBRLDU
	andi.l	#$00300030,d1	; 00SA0000
	lsl.l	#2,d1
	or.l	d1,d0
	move.b	d0,\2
	swap	d0
	move.b	d0,\1
	; TODO detect new buttons, hold buttons and released buttons
	ENDM