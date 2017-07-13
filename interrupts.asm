HBlankInterrupt:
   add.l #1, hblank_counter    ; Increment hinterrupt counter
   rte

VBlankInterrupt:
   add.l #1, vblank_counter    ; Increment vinterrupt counter
   rte

Exception:
   stop #$2700 ; Halt CPU