;GAME
;implementation of gamestates

;GAME STATE PLAYING
_gameStatePlaying:
	;snakeLastInput
	;convert input to two bytes
	LDA playerOneInput
	;let's make this easy for us

	CMP #%00001000
	BNE _snakePersistantInputUpDone
	LDX #$00
	STX snakeLastInputTemp
_snakePersistantInputUpDone:

	CMP #%00000100
	BNE _snakePersistantInputDownDone
	LDX #$01
	STX snakeLastInputTemp
_snakePersistantInputDownDone:

	CMP #%00000010
	BNE _snakePersistantInputLeftDone
	LDX #$02
	STX snakeLastInputTemp
_snakePersistantInputLeftDone:

	CMP #%00000001
	BNE _snakePersistantInputRightDone
	LDX #$03
	STX snakeLastInputTemp
_snakePersistantInputRightDone:
;;;;;;;;;;
	LDA snakeLastInputTemp
	EOR #$01
	CMP snakeLastTickInput
	BEQ _snakePersistantInputDone
	LDA snakeLastInputTemp
	STA snakeLastInput
_snakePersistantInputDone:

;;;;;;;;;;

	LDX snakeTicks
	INX
	STX snakeTicks
	CPX snakeFramesToMove
	BNE _tickDone
	JSR _tick
_tickDone:
;do things that need to be done every frame, such as updating sprites

;return from gamestate playing
	RTS


;keep this structure, as I could to add a state where the snake is not moving
;reads snakePos and updates namBuffer
;usage: load A with x of the position and X with y of the position, load Y with tile index
UpdateNamPos:
	;A has loaded snakePos_X
	;X has loaded snakePos_Y
	STA backgroundDir_lo
	LDA #$00
	STA backgroundDir_hi
	INX
_snakeUpdateHeadHighLoop:
	DEX
	BEQ _snakeUpdateHeadHighLoopDone
	LDA backgroundDir_lo
	CLC
	ADC #$20
	STA backgroundDir_lo
	LDA backgroundDir_hi
	ADC #$00
	STA backgroundDir_hi
	JMP _snakeUpdateHeadHighLoop
_snakeUpdateHeadHighLoopDone:
	;add to namBuffer, A (which contains the tileIndex in the function) will be loaded with the starting point in CHR, than added with the direction directly
	TYA
	;backgroundDir lo and hi are loaded with the correct adresses, minus $2000, A contains tile index
	JSR NamAdd

	RTS
;;;;;;;;;


;load X with x and Y with y, they will be updated depending on the dir in A (0 up, 1 down, 2 left, 3 right)
UpdatePos:
	;A is loaded with direction
	CMP #$00
	BNE _updatePosUpDone
	DEY
_updatePosUpDone:
	CMP #$01
	BNE _updatePosDownDone
	INY
_updatePosDownDone:
	CMP #$02
	BNE _updatePosLeftDone
	DEX
_updatePosLeftDone:
	CMP #$03
	BNE _updatePosDone
	INX
_updatePosDone:
	RTS
	

;Tick
_tick:
	LDA #$00
	STA snakeTicks

	;display a body tile in the previous tick's head's position
	LDA snakeInputs
	AND #%00000011
	CLC
	ADC #SNAKE_CHR_BODY_ROW
	TAY
	LDA snakePos_X
	LDX snakePos_Y
	JSR UpdateNamPos

;update the position
;when updated, the loop that goes through the rest of the snake can check for snake interception
;update pos as well as bouns checking with walls
	;update pos, check for wall collision
	LDA snakeLastInput
	LDX snakePos_X
	LDY snakePos_Y
	JSR UpdatePos

	STX snakePos_X
	STY snakePos_Y

	CPY #WALL_TOP
	BEQ _bumped
	CPY #WALL_BOTTOM
	BEQ _bumped
	CPX #WALL_LEFT
	BEQ _bumped
	CPX #WALL_RIGHT
	BNE _snakePosDone

_bumped:
	LDA #GAME_STATE_GAMEOVER
	STA gameState

_snakePosDone:
	;update namBuffer through UpdateNamPos
	LDA #SNAKE_CHR_HEAD_ROW
	CLC
	ADC snakeLastInput
	TAY
	LDA snakePos_X
	LDX snakePos_Y
	JSR UpdateNamPos
	;now to the 2 remaining elements to be updated
	
	;loop to update snakeInputs buffer and to check for collisions with the current position
	;temp position variable for comparasions
	LDA snakePos_X
	STA snakeTempPos_X
	LDA snakePos_Y
	STA snakeTempPos_Y

	;translate the 16-bit length to an 8-bit indexer, this indexer covers up to 3 unnessesary elements, don't read these

;when outer is at the last index, use another inner loop
;first create the outer loop's index which should leave out remaining elements, create another counter which tells how many elements there are in the only parially filled byte
;snakeLength_lo, snakeLength_hi, snakeLengthCounter_lo, snakeLengthCounter_hi, use snakeTempPos_X and Y with this loop's own pos updater

;loop time
	;snakeLastInput must not have any ones apart from bit 0 and 1
	LDA snakeLastInput
	AND #$03
	STA snakeInputsTemp		;

;create "meta loop" counter
	LDA snakeLength_hi
	LSR A
	TAX
	LDA snakeLength_lo
	ROR A
	TAY
	TXA
	LSR A
	TYA
	ROR A
	STA snakeInputsAllBytes		;the "meta loop" counter
	;the "last inner loop" counter is the two last bits in snakeLength_lo

	LDA snakeInputs
	STA snakeInputsDummy

	LDX #$FF


;OUTER LOOP
_snakeInputsOuterLoop:
	CPX snakeInputsAllBytes		;no worries
	BEQ _snakeInputsLoopDone
	INX
	CPX snakeInputsAllBytes
	BNE _snakeInputsNotQuitting
	;set y to "last inner loop"
	LDA snakeLength_lo
	AND #%00000011
	TAY
	INY		;because of the y offset which is beneficial for the loop
	JMP _snakeInputsBoundsCheckDone
_snakeInputsNotQuitting:
	LDY #$04
_snakeInputsBoundsCheckDone:

	;now shift current byte
	LDA snakeInputs, X		;this is faster
	ASL	A
	ROL snakeInputsTempTemp
	ASL A
	ROL snakeInputsTempTemp
	ORA snakeInputsTemp		;bit 0 and 1
	STA snakeInputs, X
	LDA snakeInputsTempTemp
	STA snakeInputsTemp

	;load the relevant byte to check and update on
	LDA snakeInputs, X
	STA snakeInputsDummy


;INNER LOOP
_snakeInputsLoop:
	DEY			;when it hits zero
	BEQ _snakeInputsOuterLoop
	
	;do stuff only with A
	LDA snakeInputsDummy
	AND #%00000011
	BNE _snakeInputsLoopUpDone
	;up
	INC snakeTempPos_Y
	JMP _snakeInputsLoopRightDone
_snakeInputsLoopUpDone:
	CMP #$01
	BNE _snakeInputsLoopDownDone
	;down
	DEC snakeTempPos_Y
	JMP _snakeInputsLoopRightDone
_snakeInputsLoopDownDone:
	CMP #$02
	BNE _snakeInputsLoopLeftDone
	;left
	INC snakeTempPos_X
	JMP _snakeInputsLoopRightDone
_snakeInputsLoopLeftDone:
	;right
	DEC snakeTempPos_X
_snakeInputsLoopRightDone:

	;check for body colission
	LDA snakeTempPos_X
	CMP snakePos_X
	BNE _snakeInputsNoBumps
	LDA snakeTempPos_Y
	CMP snakePos_Y
	BEQ _snakeBumped
_snakeInputsNoBumps:

	;shift it
	LSR snakeInputsDummy
	LSR snakeInputsDummy

	;done, next "inner" iteration
	JMP _snakeInputsLoop


_snakeBumped:
	LDA #GAME_STATE_GAMEOVER
	STA gameState

_snakeInputsLoopDone:
;update snakeTempPos as tail, wait maybe not, the empty one instead
;update updated snakeTempPos as empty tile
	LDA #SNAKE_CHR_EMPTY_TILE
	TAY
	LDA snakeTempPos_X
	LDX snakeTempPos_Y
	JSR UpdateNamPos

	LDA snakeLastInput
	STA snakeLastTickInput

;return from tick
	RTS
;;;;


;GAME STATE TITLE
_gameStateTitle:
	LDA #GAME_STATE_PLAYING
	STA gameState

	RTS


;GAME STATE GAME OVER
_gameStateGameOver:
	RTS