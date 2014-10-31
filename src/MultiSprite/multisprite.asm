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

	; Load all of the sprites attributes, ready for DMA transfer
	ldx #$00 			; initialize X to 0
LoadSpritesLoop:
	lda sprites, X 
	sta $0200, X
	inx
	cpx #$10 			; compare X to decimal 16
	bne LoadSpritesLoop ; keep looping if we haven't reached 16 (haven't loaded all sprites)

	; Enable sprites
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


LatchController:		; Grab controller data
	lda #$01
	sta $4016
	lda #$00
	sta $4016			; tell the controller to latch the buttons

	; don't care about these button presses
	lda $4016			; read A button
	lda $4016			; read B button
	lda $4016			; read select button
	lda $4016 			; read start button

ReadUp:
	lda $4016			; Player 1 - Up
	and #$01 			; only look at bit 0
	beq ReadUpDone 		; branch if button isn't pressed (0)

	; Player 1 Up button pressed
	ldx #$00
SpritesUp:
	lda $0200, X 			; load sprite y position
	sec
	sbc #$02 				; increment y position
	sta $0200, X

	txa
	clc
	adc #$04
	tax						; increment X by 4
	cpx #$10
	bne SpritesUp 			; keep looping until all sprites have moved
ReadUpDone:

ReadDown:
	lda $4016			; Player 1 - Down
	and #$01 			; only look at bit 0
	beq ReadDownDone 	; branch if button isn't pressed (0)

	; Player 1 Down button pressed
	ldx #$00
SpritesDown:
	lda $0200, X 			; load sprite y position
	clc
	adc #$02 				; decrement y position
	sta $0200, X

	txa
	clc
	adc #$04
	tax						; increment y by 4
	cpx #$10
	bne SpritesDown 		; keep looping until all sprites have moved
ReadDownDone:

ReadLeft:
	lda $4016			; Player 1 - A
	and #$01 			; only look at bit 0
	beq ReadLeftDone 	; branch if button isn't pressed (0)

	; Player 1 B button pressed
	ldx #$00
SpritesLeft:
	lda $0203, X 			; load sprite X position
	sec
	sbc #$02 				; increment x position
	sta $0203, X

	txa
	clc
	adc #$04
	tax						; increment X by 4
	cpx #$10
	bne SpritesLeft 		; keep looping until all sprites have moved
ReadLeftDone:

ReadRight:
	lda $4016			; Player 1 - A
	and #$01 			; only look at bit 0
	beq ReadRightDone 	; branch if button isn't pressed (0)

	; Player 1 A button pressed
	ldx #$00
SpritesRight:
	lda $0203, X 			; load sprite X position
	clc
	adc #$02 				; increment x position
	sta $0203, X

	txa
	clc
	adc #$04
	tax						; increment X by 4
	cpx #$10
	bne SpritesRight 		; keep looping until all sprites have moved

ReadRightDone:



	rti					; return from interrupt

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

	.bank 1
	.org $E000
; Image and sprite palettes
palette:
	.db $22,$29,$1A,$0F,$22,$36,$17,$0F,$22,$30,$21,$0F,$22,$27,$17,$0F		; image palette
  	.db $00,$16,$27,$18,$00,$1A,$30,$27,$00,$16,$30,$27,$00,$0F,$36,$17		; sprite palette

sprites:
	; vert tile attr horiz
	.db $80, $32, $00, $80		; sprite 0
	.db $80, $33, $00, $88		; sprite 1
	.db $88, $34, $00, $80		; sprite 2
	.db $88, $35, $00, $88		; sprite 3

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