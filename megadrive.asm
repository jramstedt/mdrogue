; I/O ports
io_ver    equ $00A10001
io_data1  equ $00A10003  ;  DATA 1 ( CTRL1 )
io_data2  equ $00A10005  ;  DATA 2 ( CTRL2 )
io_data3  equ $00A10007  ;  DATA 3 ( EXP   )
io_expRst equ $00A10008  ;  RESET
io_ctrl1  equ $00A10009  ;  CTRL 1
io_ctrl2  equ $00A1000B  ;  CTRL 2
io_ctrl3  equ $00A1000D  ;  CTRL 3
io_tx1    equ $00A1000F  ;  TxDATA 1
io_rx1    equ $00A10011  ;  RxDATA 1
io_sctrl1 equ $00A10013  ;  S-CTRL 1
io_tx2    equ $00A10015  ;  TxDATA 2
io_rx2    equ $00A10017  ;  RxDATA 2
io_sctrl2 equ $00A10019  ;  S-CTRL 2
io_tx3    equ $00A1001B  ;  TxDATA 3
io_reset  equ $00A1000C  ;  RESET
io_rx3    equ $00A1001D  ;  RxDATA 3
io_sctrl3 equ $00A1001F  ;  S-CTRL 3

    include 'vdp.asm'
    include 'dma.asm'
