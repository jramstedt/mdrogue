
; DMA queue code adapted from https://github.com/flamewing/ultra-dma-queue
; See LICENCE.dma.md

; Copyright 2015-2017 flamewing
;
; Licensed under the Apache License, Version 2.0 (the "License");
; you may not use this file except in compliance with the License.
; You may obtain a copy of the License at
;
;     http://www.apache.org/licenses/LICENSE-2.0
;
; Unless required by applicable law or agreed to in writing, software
; distributed under the License is distributed on an "AS IS" BASIS,
; WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
; See the License for the specific language governing permissions and
; limitations under the License.

; CD2 CD1 CD0
; 0   0   1     VRAM = %001
; 0   1   1     CRAM = %011
; 1   0   1     VSRAM = %101

queueDMATransfer MACRO sourceMem, destVRAM, lenWords
	move.l \sourceMem, d5
	move.l \destVRAM, d6
	move.l \lenWords, d7
	jsr _queueDMATransfer
	ENDM

;    d5 source
;    d6 destination
;    d7 length in words
_queueDMATransfer
    movea.l dma_queue_pointer, a6           ; Move current pointer to a6
    cmpa.l  #dma_queue_pointer, a6    ; Compare dma_queue_pointer RAM address to current pointer
    beq.s   @done                           ; If they are the same, queue is full. (dma_queue_pointer is after dma_queue)

    lsr.l   #1, d5          ; Source address >> 1 (even address)
    swap    d5              ; Swap high and low word (high word contains SA23-SA17)
    move.w  #$977F, d0      ; vdp_w_reg+(23<<8) & $7F where 7F is mask for upper bits (SA23-SA17)
    and.b   d5, d0          ; AND d0 with d5 lower 8 bits
    move.w  d0, (a6)+       ; Save reg 23 command+data to DMA queue
    move.w  d7, d5          ; Move length to d5 lower word
    movep.l d5, 1(a6)       ; Move each byte to its own word
    lea     8(a6), a6       ; Add 8 to queue (the four words written with movep)

    ; Build DMA command
    lsl.l   #2, d6      ; Shift left. 2 bits goes to upper word
    addq.w  #%01, d6    ; Set two lowest bits to VRAM write
    ror.w   #2, d6      ; Rotate right. Moves two added bits to highest bits.
    swap    d6
    ori.b   #%10000000, d6
    move.l  d6, (a6)+   ; 

    clr.w   (a6)        ; Clear word at address a6 (end token)
    move.l  a6, dma_queue_pointer

@done
    rts

initDMAQueue
    lea     dma_queue, a6
    move.w  #0, (a6)                ; Move zero to beginning of dma queue
    move.l  a6, dma_queue_pointer   ; Set current pointer to beginning of dma queue
    move.l  #$96959493, d7          ; vdp_w_reg+(22<<8), vdp_w_reg+(21<<8), vdp_w_reg+(20<<8), vdp_w_reg+(19<<8)

lc = 0
    REPT (dma_queue_pointer-dma_queue)/(7*2)
    movep.l d7, 2+lc(a6)
lc = lc+14
    ENDR

    rts
    
processDMAQueue
    ; M1 enable dma

    lea     vdp_ctrl, a5
    lea     dma_queue, a6
    move.l  a6, dma_queue_pointer   ; Reset dma_queue_pointer

    REPT (dma_queue_pointer-dma_queue)/(7*2)
    move.w	(a6)+, d6               
    beq.w   @done                   ; if word in queue was zero (stop token)

    move.w  d6, (a5)                ; reg 23
    move.l  (a6)+, (a5)             ; reg 22, reg 21
    move.l  (a6)+, (a5)             ; reg 20, reg 19
    move.l  (a6)+, (a5)             ; dma command
    ENDR
    moveq   #0, d6

@done
    move.w  d6, dma_queue

    ; wait dma to finish

    rts
