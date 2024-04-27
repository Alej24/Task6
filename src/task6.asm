.include "constants.inc"
.include "header.inc"

.segment "ZEROPAGE"
player_x: .res 1
player_y: .res 1
scroll: .res 1
ppuctrl_settings: .res 1
pad1: .res 1
playerWalkState: .res 1
playerFrameCounter: .res 1
timer_x: .res 1
timer_y: .res 1
timer2_x: .res 1
timer2_y: .res 1
timerState: .res 1
timerState2: .res 1
loadedLvl: .res 1
.exportzp player_x, player_y, pad1, playerWalkState, playerFrameCounter, timer_x, timer_y, timer2_x, timer2_y, timerState, timerState2

.segment "CONST"
standingState = $00
firstStepState = $01
secondStepState = $02
animationSpeed = 255  ; Higher value means slower animation speed
nineState = $00
eightState = $01
sevenState = $02
sixState = $03
fiveState = $04
fourState = $05
threeState = $06
twoState = $07
oneState = $08
zeroState = $09

.segment "CODE"
.proc irq_handler
  RTI
.endproc

.import read_controller1

.proc nmi_handler
  LDA #$00
  STA OAMADDR
  LDA #$02
  STA OAMDMA
  LDA #$00

  ; read controller
  JSR read_controller1

  ; Check if both timerState and timerState2 reached the end
  LDA timerState
  CMP #$0F
  BNE drawRoutine   ; If timerState is not #$0F, continue drawing
  LDA timerState2
  CMP #$0a
  BNE drawRoutine   ; If timerState2 is not #$0F, continue drawing

  LDA #240
  STA timer_y
  STA timer2_y

  JSR gameOver

  JMP doneClearing  ; Jump to the end of the routine after clearing the screen

drawRoutine:

  ; update tiles *after* DMA transfer
  JSR update_player
  JSR draw_player

  ; JSR updateTimer
  JSR draw_timer
  JSR draw_timer2

  ; Check if the player is within certain x positions on the screen
  LDA player_x
  CMP #$40   ; Left boundary
  BCC no_scroll
  CMP #$c0   ; Right boundary
  BCS no_scroll

  ; Update scroll only when player reaches the boundaries
  LDA player_x
  SEC
  SBC #$40   ; Adjust to make player_x within 0-160 range
  STA scroll

no_scroll:
  LDA scroll
  STA PPUSCROLL
  LDA #$00
  STA PPUSCROLL

doneClearing:
  RTI
.endproc

.import reset_handler
.import draw_obstacles, draw_stage
.import draw_obstacles2
.import draw_obstacles3, draw_stage2
.import draw_obstacles4

.export main
.proc main
	LDA #0	 ; Y is only 240 lines tall! CHANGE FOR POS OF SCREEN
	STA scroll

  ; write a palette
  LDX PPUSTATUS
  LDX #$3f
  STX PPUADDR
  LDX #$00
  STX PPUADDR
load_palettes:
  LDA palettes,X
  STA PPUDATA
  INX
  CPX #$20
  BNE load_palettes

	LDX #$20
  JSR draw_stage
  JSR draw_obstacles
  LDX #$24
  JSR draw_obstacles2
  LDX #$28
  JSR draw_stage2
  JSR draw_obstacles3
  LDX #$2c
  JSR draw_obstacles4

  ; set up obstacle slots

  vblankwait:       ; wait for another vblank before continuing
  BIT PPUSTATUS
  BPL vblankwait

  LDA #%10010000  ; turn on NMIs, sprites use first pattern table  IMPORTANT
	STA ppuctrl_settings
  STA PPUCTRL
  LDA #%00011110  ; turn on screen
  STA PPUMASK

forever:
  ; Increase frame counters
  INC playerFrameCounter

  ; Delay to control the update frequency
  LDX #180  ; The higher the vlue the longer the delay
  delayLoop:
  DEX
  BNE delayLoop
  
  ; Check if it's time to update animation frame
  INC playerWalkState
  LDA playerFrameCounter
  CMP animationSpeed
  BNE skipUpdatePlayer

  ; Reset frame counter
  LDA #$00
  STA playerFrameCounter

  ; Update animation frame
  JSR update_player
  JSR updateTimer

  skipUpdatePlayer:

  ; Check if the player is near the maximum x position
  LDA player_x
  CMP #$f0  ; Check if player is near the maximum x position
  BNE continueLoop  ; If not, continue the loop

  ; Change level if player is near the maximum x position
  JSR changeLvl
continueLoop:

  ; Continue with the main loop
  JMP forever
.endproc

.proc changeLvl
  PHP  ; Start by saving registers,
  PHA  ; as usual.
  TXA
  PHA
  TYA
  PHA
  ; Changes level, resets x and y positions and scroll, and timerStates
  LDA #%10010010  ; use next pattern table
	STA ppuctrl_settings
  STA PPUCTRL
  LDA #0
	STA scroll
  LDA #$00
	STA player_x
	LDA #$c0
	STA player_y
  LDA #$02
  STA timerState2
  LDA #$00
  STA timerState
  
skip_lvl:
  PLA ; Done with updates, restore registers
  TAY ; and return to where we called this
  PLA
  TAX
  PLA
  PLP
  RTS
.endproc

.proc update_player
  PHP  ; Start by saving registers,
  PHA  ; as usual.
  TXA
  PHA
  TYA
  PHA

check_left:
  LDA pad1
  AND #BTN_LEFT
  BEQ check_right
  ; If the player is moving left, he cannot move past the left edge of the screen
  LDA player_x
  CMP #$01 ; Left edge
  BCC skip_left
  DEC player_x ; Decrease player's x position if he's within the left edge
skip_left:

check_right:
  LDA pad1
  AND #BTN_RIGHT
  BEQ check_up
  ; If the player is moving right, he cannot move past the right edge of the screen
  LDA player_x
  CMP #$f0 ; Right edge
  BCS skip_right
  INC player_x ; Decrease player's x position if within the right edge
skip_right:

check_up:
  LDA pad1
  AND #BTN_UP
  BEQ check_down
  DEC player_y
check_down:
  LDA pad1
  AND #BTN_DOWN
  BEQ done_checking
  INC player_y
done_checking:
  PLA ; Done with updates, restore registers
  TAY ; and return to where we called this
  PLA
  TAX
  PLA
  PLP
  RTS
.endproc

.proc draw_player
  ; save registers
  PHP
  PHA
  TXA
  PHA
  TYA
  PHA

  LDA playerWalkState
  AND #$03 ; Keep playerWalkState between 0 and 3

checkRight:
  ; Check if the player is moving to the right
  LDA pad1
  AND #BTN_RIGHT
  BEQ checkLeft ; Skip to check left if right button is not pressed
  INC playerWalkState ; Increase walk state only if moving right
  JMP drawSpriteRight ; Jump to draw sprite facing right

checkLeft:
  ; Check if the player is moving to the left
  LDA pad1
  AND #BTN_LEFT
  BEQ checkUp ; Skip to check up if left button is not pressed
  INC playerWalkState ; Increase walk state only if moving left
  JMP drawSpriteLeft ; Jump to draw sprite facing left

checkUp:
  ; Check if the player is moving up
  LDA pad1
  AND #BTN_UP
  BEQ checkDown ; Skip to check down if up button is not pressed
  INC playerWalkState ; Increase walk state only if moving up
  JMP drawSpriteUp ; Jump to draw sprite facing up

checkDown:
  ; Check if the player is moving down
  LDA pad1
  AND #BTN_DOWN
  BEQ drawSpriteRight ; Skip to draw sprite right if down button is not pressed
  INC playerWalkState ; Increase walk state only if moving down
  JMP drawSpriteDown ; Jump to draw sprite facing down

drawSpriteRight:

  ; Check if the right button is pressed
  LDA pad1
  AND #BTN_RIGHT
  BEQ skipAnimationRight ; If right button is not pressed, skip animation

  ; Increase the walk state for the player only when moving right
  LDA playerWalkState
  AND #$03 ; Keep playerWalkState between 0 and 3
  CMP #standingState
  BEQ standing_right
  CMP #firstStepState
  BEQ step1_right
  CMP #secondStepState
  BEQ step2_right

  step2_right:
  ; write player ship tile numbers
  LDA #$04
  STA $0201
  LDA #$05
  STA $0205
  LDA #$0a
  STA $0209
  LDA #$0b
  STA $020d
  ; write player ship tile attributes
  ; use palette 0
  LDA #$00
  STA $0202
  STA $0206
  STA $020a
  STA $020e
  JMP drawDone

  step1_right:
  ; write player ship tile numbers
  LDA #$04
  STA $0201
  LDA #$05
  STA $0205
  LDA #$08
  STA $0209
  LDA #$09
  STA $020d
  ; write player ship tile attributes
  ; use palette 0
  LDA #$00
  STA $0202
  STA $0206
  STA $020a
  STA $020e
  JMP drawDone

  standing_right:
  ; write player ship tile numbers
  LDA #$04
  STA $0201
  LDA #$05
  STA $0205
  LDA #$06
  STA $0209
  LDA #$07
  STA $020d
  ; write player ship tile attributes
  ; use palette 0
  LDA #$00
  STA $0202
  STA $0206
  STA $020a
  STA $020e
  JMP drawDone

  skipAnimationRight:
  ; If right button is not pressed, keep the player in standing state
  LDA #$04
  STA $0201
  LDA #$05
  STA $0205
  LDA #$06
  STA $0209
  LDA #$07
  STA $020d
  ; write player ship tile attributes
  ; use palette 0
  LDA #$00
  STA $0202
  STA $0206
  STA $020a
  STA $020e
  JMP drawDone

drawSpriteLeft:
  
  ; Increase the walk state for the player only when moving left
  LDA playerWalkState
  AND #$03 ; Keep playerWalkState between 0 and 3
  CMP #standingState
  BEQ standing_left
  CMP #firstStepState
  BEQ step1_left
  CMP #secondStepState
  BEQ step2_left

  step2_left:
  ; write player ship tile numbers
  LDA #$0c
  STA $0201
  LDA #$0d
  STA $0205
  LDA #$12
  STA $0209
  LDA #$13
  STA $020d
  ; write player ship tile attributes
  ; use palette 0
  LDA #$00
  STA $0202
  STA $0206
  STA $020a
  STA $020e
  JMP drawDone

  step1_left:
  ; write player ship tile numbers
  LDA #$0c
  STA $0201
  LDA #$0d
  STA $0205
  LDA #$10
  STA $0209
  LDA #$11
  STA $020d
  ; write player ship tile attributes
  ; use palette 0
  LDA #$00
  STA $0202
  STA $0206
  STA $020a
  STA $020e
  JMP drawDone

  standing_left:
  ; write player ship tile numbers
  LDA #$0c
  STA $0201
  LDA #$0d
  STA $0205
  LDA #$0e
  STA $0209
  LDA #$0f
  STA $020d
  ; write player ship tile attributes
  ; use palette 0
  LDA #$00
  STA $0202
  STA $0206
  STA $020a
  STA $020e
  JMP drawDone

drawSpriteUp:
  
  ; Increase the walk state for the player only when moving up
  LDA playerWalkState
  AND #$03 ; Keep playerWalkState between 0 and 3
  CMP #standingState
  BEQ standing_up
  CMP #firstStepState
  BEQ step1_up
  CMP #secondStepState
  BEQ step2_up

  step2_up:
  ; write player ship tile numbers
  LDA #$28
  STA $0201
  LDA #$29
  STA $0205
  LDA #$2a
  STA $0209
  LDA #$2b
  STA $020d
  ; write player ship tile attributes
  ; use palette 0
  LDA #$00
  STA $0202
  STA $0206
  STA $020a
  STA $020e
  JMP drawDone

  step1_up:
  ; write player ship tile numbers
  LDA #$24
  STA $0201
  LDA #$25
  STA $0205
  LDA #$26
  STA $0209
  LDA #$27
  STA $020d
  ; write player ship tile attributes
  ; use palette 0
  LDA #$00
  STA $0202
  STA $0206
  STA $020a
  STA $020e
  JMP drawDone

  standing_up:
  ; write player ship tile numbers
  LDA #$20
  STA $0201
  LDA #$21
  STA $0205
  LDA #$22
  STA $0209
  LDA #$23
  STA $020d
  ; write player ship tile attributes
  ; use palette 0
  LDA #$00
  STA $0202
  STA $0206
  STA $020a
  STA $020e
  JMP drawDone

drawSpriteDown:
  
  ; Increase the walk state for the player only when moving down
  LDA playerWalkState
  AND #$03 ; Keep playerWalkState between 0 and 3
  CMP #standingState
  BEQ standing_down
  CMP #firstStepState
  BEQ step1_down
  CMP #secondStepState
  BEQ step2_down

  step2_down:
  ; write player ship tile numbers
  LDA #$1c
  STA $0201
  LDA #$1d
  STA $0205
  LDA #$1e
  STA $0209
  LDA #$1f
  STA $020d
  ; write player ship tile attributes
  ; use palette 0
  LDA #$00
  STA $0202
  STA $0206
  STA $020a
  STA $020e
  JMP drawDone

  step1_down:
  ; write player ship tile numbers
  LDA #$18
  STA $0201
  LDA #$19
  STA $0205
  LDA #$1a
  STA $0209
  LDA #$1b
  STA $020d
  ; write player ship tile attributes
  ; use palette 0
  LDA #$00
  STA $0202
  STA $0206
  STA $020a
  STA $020e
  JMP drawDone

  standing_down:
  ; write player ship tile numbers
  LDA #$14
  STA $0201
  LDA #$15
  STA $0205
  LDA #$16
  STA $0209
  LDA #$17
  STA $020d
  ; write player ship tile attributes
  ; use palette 0
  LDA #$00
  STA $0202
  STA $0206
  STA $020a
  STA $020e
  JMP drawDone

drawDone:
  ; store tile locations
  ; top left tile:
  LDA player_y
  STA $0200
  LDA player_x
  STA $0203

  ; top right tile (x + 8):
  LDA player_y
  STA $0204
  LDA player_x
  CLC
  ADC #$08
  STA $0207

  ; bottom left tile (y + 8):
  LDA player_y
  CLC
  ADC #$08
  STA $0208
  LDA player_x
  STA $020b

  ; bottom right tile (x + 8, y + 8)
  LDA player_y
  CLC
  ADC #$08
  STA $020c
  LDA player_x
  CLC
  ADC #$08
  STA $020f

  ; restore registers and return
  PLA
  TAY
  PLA
  TAX
  PLA
  PLP
  RTS
.endproc

.proc updateTimer
  INC timerState
  RTS
.endproc

.proc draw_timer2  ; Draw timer
  ; save registers
  PHP
  PHA
  TXA
  PHA
  TYA
  PHA
  ; only updates animation frames once every time draw_timer reaches 0
  ; Choose which sprite to draw based on timerState2
  LDA timerState2
  AND #$0f ; Keep timerState between 0 and 15
  CMP #nineState
  BEQ nine
  CMP #eightState
  BEQ eight
  CMP #sevenState
  BEQ seven
  CMP #sixState
  BEQ six
  CMP #fiveState
  BEQ five
  CMP #fourState
  BEQ four
  CMP #threeState
  BEQ three
  CMP #twoState
  BEQ two
  CMP #oneState
  BEQ one
  CMP #zeroState
  BEQ zero

  nine:
  ; write player ship tile numbers
  LDA #$59
  STA $0211
  JMP drawDone

  eight:
  ; write player ship tile numbers
  LDA #$58
  STA $0211
  JMP drawDone

  seven:
  ; write player ship tile numbers
  LDA #$57
  STA $0211
  JMP drawDone

  six:
  ; write player ship tile numbers
  LDA #$56
  STA $0211
  JMP drawDone

  five:
  ; write player ship tile numbers
  LDA #$55
  STA $0211
  JMP drawDone

  four:
  ; write player ship tile numbers
  LDA #$54
  STA $0211
  JMP drawDone

  three:
  ; write player ship tile numbers
  LDA #$53
  STA $0211
  JMP drawDone

  two:
  ; write player ship tile numbers
  LDA #$52
  STA $0211
  JMP drawDone

  one:
  ; write player ship tile numbers
  LDA #$51
  STA $0211
  JMP drawDone

  zero:
  ; write player ship tile numbers
  LDA #$50
  STA $0211
  JMP drawDone

  drawDone:
  ; store tile locations
  ; top left tile:
  LDA timer_y
  STA $0210
  LDA timer_x
  STA $0213

  ; T
  LDA #$43
  STA $0215
  LDA timer_y
  STA $0214
  LDA timer_x
  SEC
  SBC #$20
  STA $0217
  ; palette $00 used
  LDA #$00
  STA $0216

  ; I:
  LDA #$38
  STA $0219
  LDA timer_y
  STA $0218
  LDA timer_x
  SEC
  SBC #$19
  STA $021b
  ; palette $00 used
  LDA #$00
  STA $021a

  ; M:
  LDA #$3c
  STA $021d
  LDA timer_y
  STA $021c
  LDA timer_x
  SEC
  SBC #$12
  STA $021f
  ; palette $00 used
  LDA #$00
  STA $021e

  ; restore registers and return
  PLA
  TAY
  PLA
  TAX
  PLA
  PLP
  RTS
.endproc

.proc draw_timer  ; Draw left animation
  ; save registers
  PHP
  PHA
  TXA
  PHA
  TYA
  PHA

  ; Choose which sprite to draw based on timerState
  LDA timerState
  AND #$0f ; Keep timerState between 0 and 15
  TAX

  ; Get tile number from array
  LDA digitTiles, X
  STA $0221

  ; Increment timerState for next iteration
  INX
  CPX #15
  BNE notWrapAround
  LDA #00
  STX timerState
  INC timerState2

notWrapAround:

  ; store tile locations
  ; top left tile:
  LDA timer2_y
  STA $0220
  LDA timer2_x
  STA $0223

  ; E
  LDA #$34
  STA $0225
  LDA timer_y
  STA $0224
  LDA timer_x
  SEC
  SBC #$0b
  STA $0227
  ; palette $00 used
  LDA #$00
  STA $0226

  ; restore registers and return
  PLA
  TAY
  PLA
  TAX
  PLA
  PLP
  RTS
.endproc

.proc gameOver    ; draws game over screen

  LDA PPUSTATUS
	LDA #$21
	STA PPUADDR
	LDA #$8e
	STA PPUADDR
	LDX #$0a		
	STX PPUDATA
  LDX #$04		
	STX PPUDATA
  LDX #$10		
	STX PPUDATA
  LDX #$08		
	STX PPUDATA

  LDA PPUSTATUS
	LDA #$21
	STA PPUADDR
	LDA #$ae
	STA PPUADDR
	LDX #$12		
	STX PPUDATA
  LDX #$19		
	STX PPUDATA
  LDX #$08		
	STX PPUDATA
  LDX #$15		
	STX PPUDATA

  RTS
.endproc

.segment "VECTORS"
.addr nmi_handler, reset_handler, irq_handler

.segment "RODATA"
palettes:
.byte $2c, $07, $17, $38
.byte $2c, $04, $25, $30
.byte $2c, $0f, $07, $30
.byte $2c, $19, $09, $29

.byte $2c, $0f, $07, $30
.byte $2c, $19, $09, $29
.byte $2c, $24, $09, $29
.byte $2c, $3a, $24, $11

digitTiles:
.byte $59, $59, $58, $57, $57, $56, $55, $55, $54, $53, $53, $52, $51, $50, $50, $50

.segment "CHR"
.incbin "spriteAnim.chr"