.include "constants.inc"

.segment "ZEROPAGE"
.importzp player_x, player_y, playerWalkState, playerFrameCounter
.importzp timer_x, timer_y, timer2_x, timer2_y, timerState, timerState2

.segment "CODE"
.import main
.export reset_handler
.proc reset_handler
  SEI
  CLD
  LDX #$40
  STX $4017
  LDX #$FF
  TXS
  INX
  STX $2000
  STX $2001
  STX $4010
  BIT $2002
vblankwait:
  BIT $2002
  BPL vblankwait

	LDX #$00
	LDA #$FF
clear_oam:
	STA $0200,X ; set sprite y-positions off the screen
	INX
	INX
	INX
	INX
	BNE clear_oam

	; initialize zero-page values
	LDA #$00
	STA player_x
	LDA #$c0
	STA player_y
	LDA #$00
	STA playerWalkState
	LDA #$00
	STA playerFrameCounter

	LDA #$88
	STA timer_x
	LDA #$07
	STA timer_y
	LDA #$8f
	STA timer2_x
	LDA #$07
	STA timer2_y
	LDA #$00
	STA timerState
	LDA #$00
	STA timerState2

vblankwait2:
  BIT $2002
  BPL vblankwait2
  JMP main
.endproc
