	.inesprg 1			; 1x 16KB bank of Program code
	.ineschr 1			; 1x 8KB bank of Character data
	.inesmap 0			; mapper 0 = NROM, no bank swapping
	.inesmir 1 			; background mirroring

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	.bank 0
	.org $C000

; Reset Handler
RESET:
	sei					; disable interrupts 
	cld					; disable decimal mode (isn't supported on NES)
	ldx #$40
	stx $4017			; disable APU frame IRQ
	ldx #$FF
	txs					; Load initial stack pointer
	inx					; now X = 0
	stx $2000			; Disable NMI (PPU CR1)
	stx $2001			; Disable rendering (PPU CR2)
	stx $4010			; disable DMC IRQs (sound registers)

vblankwait1:			; First wait for vblank to make sure PPU is ready
	bit $2002			; AND address $2002 with 0 and set flags
	bpl vblankwait1		; if bit 7 of PPU Status is clear, keep looping

clrmem:
	lda #$00
	sta $0000, X
	sta $0100, X
	sta $0300, X
	sta $0400, X
	sta $0500, X
	sta $0600, X
	sta $0700, X
	lda #$FE
	sta $0200, X
	inx
	bne clrmem			; keep looping until X = 0 (looped from $00 to $ff to $00)

vblankwait2:			; Second wait for vblank, PPU is ready after this
	bit $2002
	bpl vblankwait2

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Main code

SetPaletteAddr:
	lda $2002			; read PPU status to reset the high/low latch to high
	lda #$3F
	sta $2006			; write the high byte of $3f00 address
	lda #$00
	sta $2006			; write the low byte of $3f00 address
	ldx #$00

; Load both the image and sprite palettes
LoadPalettesLoop:
	lda palette, X 		; load palette byte
	sta $2007			; write to PPU memory
	inx					; set index to next byte
	cpx #$20 			
	bne LoadPalettesLoop 	; if x = $20, 32bytes copied, all done

	; Set Sprite 0 to center of screen
	lda #$77
	sta $0200			; put sprite 0 in center ($77) of screen vert
	lda #$7C
	sta $0203			; put sprite 0 in center ($7C) of screen horiz
	lda #$FD
	sta $0201			; tile number = 0
	lda #$00
	sta $0202			; color = 0, no flipping

	lda #%10000000		; enable NMI, sprites from pattern table 0
	sta $2000			; PPU CR1

	lda #%00010000		; enable sprites
	sta $2001			; PPU CR2

Forever:				; Infinite loop
	jmp Forever

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; Interrupt handlers

NMI:
	; Sprite DMA Transfer from CPU to Sprite memory
	lda #$00
	sta $2003			; set the low byte (00) of the Sprite RAM address
	lda #$02
	sta $4014			; Set the high byte (02), and start the transfer

	rti					; return from interrupt

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	.bank 1
	.org $E000
; Image and sprite palettes
palette:
	.db $0F,$31,$32,$33,$0F,$35,$36,$37,$0F,$39,$3A,$3B,$0F,$3D,$3E,$0F		; image palette
  	.db $0F,$1C,$15,$14,$0F,$02,$38,$3C,$0F,$1C,$15,$14,$0F,$02,$38,$3C		; sprite palette

	; Interrupt Table
	.org $FFFA			; first of the three vectors start here
	.dw NMI				; When VBlank occurs, run this interrupt
	.dw RESET			; when the processor first turns on or is reset, it will run this interrupt
	.dw 0 				; don't use this interrupt

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	.bank 2
	.org $0000
	.incbin "mario.chr"	; includes 8KB graphics file from SMB1

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;