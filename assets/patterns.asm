testPattern
    dc.l $12000000
    dc.l $00340000
    dc.l $00005600
    dc.l $00000078
    dc.l $9A000000
    dc.l $00BC0000
    dc.l $0000DE00
    dc.l $000000F0

; 16x16 font
fontStripe equ 64   ; Number of cells in one row.
fontRows   equ 6    ; Number of rows.

fontPatterns
    incbin assets/FontPatterns.bin

; tilemap starts from ascii 0x20 (space)
fontTilemap
    incbin assets/FontTilemap.bin