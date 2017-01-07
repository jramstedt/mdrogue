HBlankInterrupt:
   add.l #0x1, hblank_counter    ; Increment hinterrupt counter
   rte

VBlankInterrupt:
   add.l #0x1, vblank_counter    ; Increment vinterrupt counter
   rte

Exception:
   stop #$2700 ; Halt CPU