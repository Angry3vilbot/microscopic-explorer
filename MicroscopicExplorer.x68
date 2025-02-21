*-----------------------------------------------------------
* Title      : Microscopic Explorer
* Written by : Mykhailo Balaker
* Date       : 16/02/2025
* Description: A game about a microorganism
*-----------------------------------------------------------
    ORG    $1000
START:                  ; first instruction of program

*-----------------------------------------------------------
* Section       : Trap Codes
* Description   : Trap Codes used throughout StarterKit
*-----------------------------------------------------------
* Trap CODES
TC_SCREEN   EQU         33          ; Screen size information trap code
                                    ; First 16 bit Word is screen Width and Second 16 bits is screen Height
TC_KEYCODE  EQU         19          ; Check for pressed keys
TC_DBL_BUF  EQU         92          ; Double Buffer Screen Trap Code
TC_CURSR_P  EQU         11          ; Trap code cursor position
TC_TIME     EQU         8           ; Trap code to get the current time

TC_EXIT     EQU         09          ; Exit Trapcode

*-----------------------------------------------------------
* Section       : Charater Setup
* Description   : Size of Player and Enemy and properties
* of these characters e.g Starting Positions and Sizes
*-----------------------------------------------------------
PLYR_W_INIT EQU         08          ; Players initial Width
PLYR_H_INIT EQU         08          ; Players initial Height

PLYR_DFLT_V EQU         00          ; Default Player Velocity
PLYR_MOVE_V EQU        -20          ; Player Movement Velocity
PLYR_DRAG_V EQU         01          ; Player Drag

RUN_INDEX   EQU         00          ; Player Run Sound Index
JMP_INDEX   EQU         01          ; Player Jump Sound Index
OPPS_INDEX  EQU         02          ; Player Opps Sound Index

ENMY_W_INIT EQU         08          ; Enemy initial Width
ENMY_H_INIT EQU         08          ; Enemy initial Height

FOOD_W      EQU         08          ; Food Width
FOOD_H      EQU         08          ; Food Height
FOOD_VALUE  EQU         02          ; Size increase from consuming food
FOOD_POINTS EQU         10          ; Points received for consuming food

*-----------------------------------------------------------
* Section       : Margin of Error
* Description   : Margin of Error for Collision Detection
*-----------------------------------------------------------
MARGIN      EQU         10          

*-----------------------------------------------------------
* Section       : Keyboard Keys
* Description   : Spacebar and Escape or two functioning keys
* Spacebar to JUMP and Escape to Exit Game
*-----------------------------------------------------------
UP_ARROW      EQU         $26         ; Up Arrow ASCII Keycode
DOWN_ARROW    EQU         $28         ; Down Arrow ASCII Keycode
LEFT_ARROW    EQU         $25         ; Left Arrow ASCII Keycode
RIGHT_ARROW   EQU         $27         ; Right Arrow ASCII Keycode
ESCAPE        EQU         $1B         ; Escape ASCII Keycode

*-----------------------------------------------------------
* Subroutine    : Initialise
* Description   : Initialise game data into memory such as
* sounds and screen size
*-----------------------------------------------------------
INITIALISE:
    ; Initialise Sounds
    BSR     RUN_LOAD                ; Load Run Sound into Memory
    BSR     OPPS_LOAD               ; Load Opps (Collision) Sound into Memory

    ; Screen Size
    MOVE.B  #TC_SCREEN,D0         ; Access screen information
    MOVE.L  #1024*$10000+768, D1   ; Set the resolution to 1024x768
    TRAP    #15                   ; Interpret D0 and D1 for screen size
    MOVE.L  #1024, SCREEN_W        ; Store screen width
    MOVE.L  #768, SCREEN_H         ; Store screen height

    ; Place the Player at the center of the screen
    CLR.L   D1                      ; Clear contents of D1 (XOR is faster)
    MOVE.L  SCREEN_W,   D1          ; Place Screen width in D1
    DIVU    #02,        D1          ; divide by 2 for center on X Axis
    MOVE.L  D1,         PLAYER_X    ; Players X Position

    CLR.L   D1                      ; Clear contents of D1 (XOR is faster)
    MOVE.L  SCREEN_H,   D1          ; Place Screen width in D1
    DIVU    #02,        D1          ; divide by 2 for center on Y Axis
    MOVE.L  D1,         PLAYER_Y    ; Players Y Position

    ; Initialise Player Score
    CLR.L   D1                      ; Clear contents of D1 (XOR is faster)
    MOVE.L  #00,        D1          ; Init Score
    MOVE.L  D1,         PLAYER_SCORE

    ; Initialise Player Velocity
    CLR.L   D1                      ; Clear contents of D1 (XOR is faster)
    MOVE.B  #PLYR_DFLT_V,D1         ; Init Player Velocity
    MOVE.L  D1,         PLYR_X_VELOCITY
    MOVE.L  D1,         PLYR_Y_VELOCITY

    ; Initial Position for Enemy
    BSR     GENERATE_LOCATION
    MOVE.L  A2,         ENEMY_X     ; Enemy X Position
    MOVE.L  A3,         ENEMY_Y     ; Enemy Y Position

    ; Enable the screen back buffer
	MOVE.B  #TC_DBL_BUF,D0          ; 92 Enables Double Buffer
    MOVE.B  #17,        D1          ; Combine Tasks
	TRAP	#15                     ; Trap (Perform action)

    ; Clear the screen
    MOVE.B  #TC_CURSR_P,D0          ; Set Cursor Position
	MOVE.W  #$FF00,     D1          ; Fill Screen Clear
	TRAP	#15                     ; Trap (Perform action)

*-----------------------------------------------------------
* Subroutine    : Game
* Description   : Game including main GameLoop. GameLoop is like
* a while loop in that it runs forever until interrupted
* (Input, Update, Draw). The Enemies Run at Player Jump to Avoid
*-----------------------------------------------------------
GAME:
    BSR     PLAY_RUN                ; Play Run Wav
GAMELOOP:
    ; Main Gameloop
    BSR     INPUT                   ; Check Keyboard Input
    BSR     UPDATE                  ; Update positions and points
    BSR     CHECK_ENEMY_COLLISIONS  ; Check for Collisions with an enemy
    BSR     CHECK_FOOD_COLLISIONS   ; Check for Collisions with food
    BSR     MOVE_ENEMY              ; Move the Enemy
    BSR     DRAW                    ; Draw the Scene
    BSR     SET_DELAY               ; Slow down the execution
    BRA     GAMELOOP                ; Loop back to GameLoop

*-----------------------------------------------------------
* Subroutine    : Input
* Description   : Process Keyboard Input
*-----------------------------------------------------------
INPUT:
    ; Process Input
    CLR.L   D1                      ; Clear Data Register
    CLR.L   D2
    MOVE.B  #TC_KEYCODE,D0          ; Listen for Keys
    TRAP    #15                     ; Trap (Perform action)
    MOVE.B  D1,         D2          ; Move last key D1 to D2
    CMP.B   #00,        D2          ; Key is pressed
    BEQ     PROCESS_INPUT           ; Process Key
    TRAP    #15                     ; Trap for Last Key
    ; Check if key still pressed
    CMP.B   #$FF,       D1          ; Is it still pressed
    BEQ     PROCESS_INPUT           ; Process Last Key
    RTS                             ; Return to subroutine

*-----------------------------------------------------------
* Subroutine    : Process Input
* Description   : Branch based on keys pressed
*-----------------------------------------------------------
PROCESS_INPUT:
    MOVE.L  D2,         CURRENT_KEY     ; Put Current Key in Memory
    CMP.L   #ESCAPE,    CURRENT_KEY     ; Is Current Key Escape
    BEQ     EXIT                        ; Exit if Escape
    CMP.L   #UP_ARROW,  CURRENT_KEY     ; Is Current Key Up Arrow
    BEQ     UP                          ; Go Up
    CMP.L   #DOWN_ARROW,CURRENT_KEY     ; Is Current Key Down Arrow
    BEQ     DOWN                        ; Go Down
    CMP.L   #LEFT_ARROW,CURRENT_KEY     ; Is Current Key Left Arrow
    BEQ     LEFT                        ; Go Left
    CMP.L   #RIGHT_ARROW,CURRENT_KEY    ; Is Current Key Right Arrow
    BEQ     RIGHT                       ; Go Right
    BRA     IDLE                        ; Or Idle
    RTS                                 ; Return to subroutine
    
UP:
    CLR.L   D1                          ; Clear contents of D1
    MOVE.L  PLYR_MOVE_V, D1             ; Fetch Player Move Velocity
    MOVE.L  PLYR_Y_VELOCITY, D2         ; Fetch Player Y Velocity
    ADD.L   D1, D2                      ; Add Move Velocity to Player Y Velocity
    MOVE.L  D2, PLYR_Y_VELOCITY         ; Store Player Y Velocity
    RTS                                 ; Return from subroutine

DOWN:
    CLR.L   D1                          ; Clear contents of D1
    MOVE.L  PLYR_MOVE_V, D1             ; Fetch Player Move Velocity
    MOVE.L  PLYR_Y_VELOCITY, D2         ; Fetch Player Y Velocity
    SUB.L   D1, D2                      ; Subtract Move Velocity from Player Y Velocity
    MOVE.L  D2, PLYR_Y_VELOCITY         ; Store Player Y Velocity
    RTS                                 ; Return from subroutine
    
LEFT:
    CLR.L   D1                          ; Clear contents of D1
    MOVE.L  PLYR_MOVE_V, D1             ; Fetch Player Move Velocity
    MOVE.L  PLYR_X_VELOCITY, D2         ; Fetch Player X Velocity
    ADD.L   D1, D2                      ; Add Move Velocity to Player X Velocity
    MOVE.L  D2, PLYR_X_VELOCITY         ; Store Player X Velocity
    RTS                                 ; Return from subroutine
    
RIGHT:
    CLR.L   D1                          ; Clear contents of D1
    MOVE.L  PLYR_MOVE_V, D1             ; Fetch Player Move Velocity
    MOVE.L  PLYR_X_VELOCITY, D2         ; Fetch Player X Velocity
    SUB.L   D1, D2                      ; Add Move Velocity to Player X Velocity
    MOVE.L  D2, PLYR_X_VELOCITY         ; Store Player X Velocity
    RTS                                 ; Return from subroutine

*-----------------------------------------------------------
* Subroutine    : Update
* Description   : Main update loop update Player and Enemies
*-----------------------------------------------------------
UPDATE:
    ; Update the Players Position based on Velocity and Gravity
    ; Y Velocity
    CLR.L   D1                      ; Clear contents of D1 (XOR is faster)
    CLR.L   D2                      ; Clear contents of D2 (XOR is faster)
    MOVE.L  PLYR_Y_VELOCITY, D1     ; Fetch Player Y Velocity
    CMP     #0, D1                  ; Compare the Y Velocity with 0
    BGT     ANTI_DOWN               ; The player is moving down (the velocity is positive)
    BLT     ANTI_UP                 ; The player is moving up (the velocity is negative)
    
    ; X Velocity
    CLR.L   D1                      ; Clear contents of D1 (XOR is faster)
    MOVE.L  PLYR_X_VELOCITY, D1     ; Fetch Player X Velocity
    CMP     #0, D1                  ; Compare the X Velocity with 0
    BGT     ANTI_RIGHT              ; The player is moving right (the velocity is positive)
    BLT     ANTI_LEFT               ; The player is moving left (the velocity is negative)

    ; Move the Enemy
    CLR.L   D1                      ; Clear contents of D1 (XOR is faster)
    CLR.L   D1                      ; Clear the contents of D0
    MOVE.L  ENEMY_X,    D1          ; Move the Enemy X Position to D0
    CMP.L   #00,        D1
    BRA     MOVE_ENEMY              ; Move the Enemy

    RTS                             ; Return to subroutine

*-----------------------------------------------------------
* Subroutine    : Anti X/Y
* Description   : Slows down the player's movement based on
* where they are moving
*-----------------------------------------------------------
ANTI_UP:
    MOVE.L  PLAYER_Y, D2            ; Fetch the Player Y Position
    ADD.L   D1, D2                  ; Add the velocity to the position
    MOVE.L  D2, PLAYER_Y            ; Save the new Y Position
    ADD.L   #PLYR_DRAG_V, D1        ; Add the drag to the velocity to slow down the player
    MOVE.L  D1, PLYR_Y_VELOCITY     ; Save the new velocity
    RTS

ANTI_DOWN:
    MOVE.L  PLAYER_Y, D2            ; Fetch the Player Y Position
    ADD.L   D1, D2                  ; Add the velocity to the position
    MOVE.L  D2, PLAYER_Y            ; Save the new Y Position
    
    SUB.L   #PLYR_DRAG_V, D1        ; Subtract the drag from the velocity to slow down the player
    MOVE.L  D1, PLYR_Y_VELOCITY     ; Save the new velocity
    RTS
    
ANTI_LEFT:
    MOVE.L  PLAYER_X, D2            ; Fetch the Player X Position
    ADD.L   D1, D2                  ; Add the velocity to the position
    MOVE.L  D2, PLAYER_X            ; Save the new X Position

    ADD.L   #PLYR_DRAG_V, D1        ; Add the drag to the velocity to slow down the player
    MOVE.L  D1, PLYR_X_VELOCITY     ; Save the new velocity
    RTS

ANTI_RIGHT:
    MOVE.L  PLAYER_X, D2            ; Fetch the Player X Position
    ADD.L   D1, D2                  ; Add the velocity to the position
    MOVE.L  D2, PLAYER_X            ; Save the new X Position
    
    SUB.L   #PLYR_DRAG_V, D1        ; Subtract the drag from the velocity to slow down the player
    MOVE.L  D1, PLYR_X_VELOCITY     ; Save the new velocity
    RTS

*-----------------------------------------------------------
* Subroutine    : Move Enemy
* Description   : Move Enemy Right to Left
*-----------------------------------------------------------
MOVE_ENEMY:
    SUB.L   #01,        ENEMY_X     ; Move enemy by X Value
    RTS

*-----------------------------------------------------------
* Subroutine    : Generate Location
* Description   : Generates a set of X and Y coordinates
*-----------------------------------------------------------

GENERATE_LOCATION:
    CLR     D1
    CLR     D6
    SUB.L   A2,      A2
    SUB.L   A3,      A3
    MOVE.B  #TC_TIME,D0           ; Get the current time
    TRAP    #15
    MOVE.L  D1,      SEED         ; Use current time as seed

    MOVE.L  SCREEN_W,D6           ; Use screen width as max
    BSR     RAND_GEN
    MOVE.W  D1,      A2           ; Store X coordinate
    
    MOVE.L  SCREEN_H,D6           ; Use screen height as max
    BSR     RAND_GEN
    MOVE.W  D1,      A3           ; Store Y coordinate
    
    RTS

RAND_GEN:
    CLR     D1
    CLR     D2
    MOVE.L  SEED,D1           ; Load seed
    MOVE.W  D1,D2             ; Copy lower 16 bits of seed
    MULU    #20021,D2         ; Multiply by lower part of 22695477 (0x4E35)

    SWAP    D1                ; Move upper 16 bits to lower position
    MULU    #346,D1           ; Multiply upper part of 22695477 (0x015A)
    SWAP    D1                ; Swap back

    ADD.L   D2,D1             ; Combine the two multiplication results
    ADD.L   #1,D1             ; Increment
    MOVE.L  D1,SEED           ; Store back new seed

    AND.L   #$3FF,D1          ; Mask to keep it between 0 - 1023 (0x400)
    CMP.L   D6,D1             ; Ensure it's within the max range
    BCC     RAND_GEN          ; If too large, regenerate

    RTS

*-----------------------------------------------------------
* Subroutine    : Draw
* Description   : Draw Screen
*-----------------------------------------------------------
DRAW:
    ; Enable back buffer
    MOVE.B  #94,        D0
    TRAP    #15

    ; Clear the screen
    MOVE.B	#TC_CURSR_P,D0          ; Set Cursor Position
	MOVE.W	#$FF00,     D1          ; Clear contents
	TRAP    #15                     ; Trap (Perform action)

    BSR     DRAW_PLYR_DATA          ; Draw Draw Score, HUD, Player X and Y
    BSR     DRAW_PLAYER             ; Draw Player
    BSR     DRAW_ENEMY              ; Draw Enemy
    BSR     LOAD_FOOD_POS           ; Draw Food
    RTS                             ; Return to subroutine

*-----------------------------------------------------------
* Subroutine    : Delay Loop
* Description   : Loop that slows down the program 
* to a managable speed
*-----------------------------------------------------------
SET_DELAY:
    MOVE.L  DELAY, D6
DELAY_LOOP:
    SUB.L   #1, D6
    CMP.L   #0, D6
    BGT     DELAY_LOOP
    BLE     END_LOOP
END_LOOP:
    RTS

*-----------------------------------------------------------
* Subroutine    : Draw Player Data
* Description   : Draw Player X, Y, Velocity, Gravity and OnGround
*-----------------------------------------------------------
DRAW_PLYR_DATA:
    CLR.L   D1                      ; Clear contents of D1 (XOR is faster)

    ; Player Score Message
    MOVE.B  #TC_CURSR_P,D0          ; Set Cursor Position
    MOVE.W  #$0201,     D1          ; Col 02, Row 01
    TRAP    #15                     ; Trap (Perform action)
    LEA     SCORE_MSG,  A1          ; Score Message
    MOVE    #13,        D0          ; No Line feed
    TRAP    #15                     ; Trap (Perform action)

    ; Player Score Value
    MOVE.B  #TC_CURSR_P,D0          ; Set Cursor Position
    MOVE.W  #$0901,     D1          ; Col 09, Row 01
    TRAP    #15                     ; Trap (Perform action)
    MOVE.B  #03,        D0          ; Display number at D1.L
    MOVE.L  PLAYER_SCORE,D1         ; Move Score to D1.L
    TRAP    #15                     ; Trap (Perform action)

    ; Player X Message
    MOVE.B  #TC_CURSR_P,D0          ; Set Cursor Position
    MOVE.W  #$0202,     D1          ; Col 02, Row 02
    TRAP    #15                     ; Trap (Perform action)
    LEA     X_MSG,      A1          ; X Message
    MOVE    #13,        D0          ; No Line feed
    TRAP    #15                     ; Trap (Perform action)

    ; Player X
    MOVE.B  #TC_CURSR_P, D0          ; Set Cursor Position
    MOVE.W  #$0502,     D1          ; Col 05, Row 02
    TRAP    #15                     ; Trap (Perform action)
    MOVE.B  #03,        D0          ; Display number at D1.L
    MOVE.L  PLAYER_X,   D1          ; Move X to D1.L
    TRAP    #15                     ; Trap (Perform action)

    ; Player Y Message
    MOVE.B  #TC_CURSR_P,D0          ; Set Cursor Position
    MOVE.W  #$1002,     D1          ; Col 10, Row 02
    TRAP    #15                     ; Trap (Perform action)
    LEA     Y_MSG,      A1          ; Y Message
    MOVE    #13,        D0          ; No Line feed
    TRAP    #15                     ; Trap (Perform action)

    ; Player Y
    MOVE.B  #TC_CURSR_P,D0          ; Set Cursor Position
    MOVE.W  #$1202,     D1          ; Col 12, Row 02
    TRAP    #15                     ; Trap (Perform action)
    MOVE.B  #03,        D0          ; Display number at D1.L
    MOVE.L  PLAYER_Y,   D1          ; Move X to D1.L
    TRAP    #15                     ; Trap (Perform action)

    ; Player Velocity X Message
    MOVE.B  #TC_CURSR_P,D0          ; Set Cursor Position
    MOVE.W  #$0203,     D1          ; Col 02, Row 03
    TRAP    #15                     ; Trap (Perform action)
    LEA     VX_MSG,      A1         ; Velocity Message
    MOVE    #13,        D0          ; No Line feed
    TRAP    #15                     ; Trap (Perform action)

    ; Player X Velocity
    MOVE.B  #TC_CURSR_P,D0          ; Set Cursor Position
    MOVE.W  #$0503,     D1          ; Col 05, Row 03
    TRAP    #15                     ; Trap (Perform action)
    MOVE.B  #03,        D0          ; Display number at D1.L
    MOVE.L  PLYR_X_VELOCITY,D1      ; Move X to D1.L
    TRAP    #15                     ; Trap (Perform action)
    
    ; Player Velocity Y Message
    MOVE.B  #TC_CURSR_P,D0          ; Set Cursor Position
    MOVE.W  #$0803,     D1          ; Col 08, Row 03
    TRAP    #15                     ; Trap (Perform action)
    LEA     VY_MSG,      A1         ; Velocity Message
    MOVE    #13,        D0          ; No Line feed
    TRAP    #15                     ; Trap (Perform action)
    
    ; Player Y Velocity
    MOVE.B  #TC_CURSR_P,D0          ; Set Cursor Position
    MOVE.W  #$0B03,     D1          ; Col 11, Row 03
    TRAP    #15                     ; Trap (Perform action)
    MOVE.B  #03,        D0          ; Display number at D1.L
    MOVE.L  PLYR_Y_VELOCITY,D1      ; Move X to D1.L
    TRAP    #15                     ; Trap (Perform action)

    ; Show Keys Pressed
    MOVE.B  #TC_CURSR_P,D0          ; Set Cursor Position
    MOVE.W  #$2001,     D1          ; Col 20, Row 1
    TRAP    #15                     ; Trap (Perform action)
    LEA     KEYCODE_MSG, A1         ; Keycode
    MOVE    #13,        D0          ; No Line feed
    TRAP    #15                     ; Trap (Perform action)

    ; Show KeyCode
    MOVE.B  #TC_CURSR_P,D0          ; Set Cursor Position
    MOVE.W  #$3001,     D1          ; Col 30, Row 1
    TRAP    #15                     ; Trap (Perform action)
    MOVE.L  CURRENT_KEY,D1          ; Move Key Pressed to D1
    MOVE.B  #03,        D0          ; Display the contents of D1
    TRAP    #15                     ; Trap (Perform action)

    ; Show if Update is Running
    MOVE.B  #TC_CURSR_P,D0          ; Set Cursor Position
    MOVE.W  #$0205,     D1          ; Col 02, Row 05
    TRAP    #15                     ; Trap (Perform action)
    LEA     UPDATE_MSG, A1          ; Update
    MOVE    #13,        D0          ; No Line feed
    TRAP    #15                     ; Trap (Perform action)

    ; Show if Draw is Running
    MOVE.B  #TC_CURSR_P,D0          ; Set Cursor Position
    MOVE.W  #$0206,     D1          ; Col 02, Row 06
    TRAP    #15                     ; Trap (Perform action)
    LEA     DRAW_MSG,   A1          ; Draw
    MOVE    #13,        D0          ; No Line feed
    TRAP    #15                     ; Trap (Perform action)

    ; Show if Idle is Running
    MOVE.B  #TC_CURSR_P,D0          ; Set Cursor Position
    MOVE.W  #$0207,     D1          ; Col 02, Row 07
    TRAP    #15                     ; Trap (Perform action)
    LEA     IDLE_MSG,   A1          ; Move Idle Message to A1
    MOVE    #13,        D0          ; No Line feed
    TRAP    #15                     ; Trap (Perform action)

    RTS               ; Return to subroutine
    

*-----------------------------------------------------------
* Subroutine    : Idle
* Description   : Perform a Idle
*-----------------------------------------------------------
IDLE:
    BSR     PLAY_RUN                ; Play Run Wav
    RTS                             ; Return to subroutine

*-----------------------------------------------------------
* Subroutines   : Sound Load and Play
* Description   : Initialise game sounds into memory
* Current Sounds are RUN, JUMP and Opps for Collision
*-----------------------------------------------------------
RUN_LOAD:
    LEA     RUN_WAV,    A1          ; Load Wav File into A1
    MOVE    #RUN_INDEX, D1          ; Assign it INDEX
    MOVE    #71,        D0          ; Load into memory
    TRAP    #15                     ; Trap (Perform action)
    RTS                             ; Return to subroutine

PLAY_RUN:
    MOVE    #RUN_INDEX, D1          ; Load Sound INDEX
    MOVE    #72,        D0          ; Play Sound
    TRAP    #15                     ; Trap (Perform action)
    RTS                             ; Return to subroutine

OPPS_LOAD:
    LEA     OPPS_WAV,   A1          ; Load Wav File into A1
    MOVE    #OPPS_INDEX,D1          ; Assign it INDEX
    MOVE    #71,        D0          ; Load into memory
    TRAP    #15                     ; Trap (Perform action)
    RTS                             ; Return to subroutine

PLAY_OPPS:
    MOVE    #OPPS_INDEX,D1          ; Load Sound INDEX
    MOVE    #72,        D0          ; Play Sound
    TRAP    #15                     ; Trap (Perform action)
    RTS                             ; Return to subroutine

*-----------------------------------------------------------
* Subroutine    : Draw Player
* Description   : Draw Player Square
*-----------------------------------------------------------
DRAW_PLAYER:
    ; Set Pixel Colors
    MOVE.L  #WHITE,     D1          ; Set Background color
    MOVE.B  #80,        D0          ; Task for Background Color
    TRAP    #15                     ; Trap (Perform action)

    ; Set X, Y, Width and Height
    MOVE.L  PLAYER_X,   D1          ; X
    MOVE.L  PLAYER_Y,   D2          ; Y
    MOVE.L  PLAYER_X,   D3
    ADD.L   #PLYR_W_INIT,   D3      ; Width
    MOVE.L  PLAYER_Y,   D4
    ADD.L   #PLYR_H_INIT,   D4      ; Height

    ; Draw Player
    MOVE.B  #87,        D0          ; Draw Player
    TRAP    #15                     ; Trap (Perform action)
    RTS                             ; Return to subroutine

*-----------------------------------------------------------
* Subroutine    : Draw Enemy
* Description   : Draw Enemy Square
*-----------------------------------------------------------
DRAW_ENEMY:
    ; Set Pixel Colors
    MOVE.L  #RED,       D1          ; Set Background color
    MOVE.B  #80,        D0          ; Task for Background Color
    TRAP    #15                     ; Trap (Perform action)

    ; Set X, Y, Width and Height
    MOVE.L  ENEMY_X,    D1          ; X
    MOVE.L  ENEMY_Y,    D2          ; Y
    MOVE.L  ENEMY_X,    D3
    ADD.L   #ENMY_W_INIT,   D3      ; Width
    MOVE.L  ENEMY_Y,    D4
    ADD.L   #ENMY_H_INIT,   D4      ; Height

    ; Draw Enemy
    MOVE.B  #87,        D0          ; Draw Enemy
    TRAP    #15                     ; Trap (Perform action)
    RTS                             ; Return to subroutine
    
*-----------------------------------------------------------
* Subroutine    : Draw Food
* Description   : Draw Food Square
*-----------------------------------------------------------
LOAD_FOOD_POS:
    SUB.L   A4,     A4              ; Clear the registers
    SUB.L   A5,     A5
    LEA     FOOD_X, A4              ; Load the X coordinates of all food
    LEA     FOOD_Y, A5              ; Load the Y coordinates of all food
DRAW_FOOD_LOOP:
    TST.L     (A4)                  ; Check if you reached the end of the array
    BEQ       END_DRAW_FOOD         ; If the end of the array is reached 
DRAW_FOOD:
    ; Set Pixel Colors
    MOVE.L  #GREEN,     D1          ; Set Background color
    MOVE.B  #80,        D0          ; Task for Background Color
    TRAP    #15                     ; Trap (Perform action)

    ; Set X, Y, Width and Height
    MOVE.L  (A4),D1         ; X
    MOVE.L  (A5),D2         ; Y
    MOVE.L  (A4)+,D3
    ADD.L   #FOOD_W,D3      ; Width
    MOVE.L  (A5)+,D4
    ADD.L   #FOOD_H,D4      ; Height

    ; Draw Food
    MOVE.B  #87,        D0          ; Draw Food
    TRAP    #15                     ; Trap (Perform action)
    BRA     DRAW_FOOD_LOOP          ; Go back to the beginning
    
END_DRAW_FOOD:
    RTS                             ; Return to subroutine

*-----------------------------------------------------------
* Subroutine    : Enemy Collision Check
* Description   : Axis-Aligned Bounding Box Collision Detection
* Algorithm checks for overlap on the 4 sides of the Player and
* Enemy rectangles
* PLAYER_X <= ENEMY_X + ENEMY_W &&
* PLAYER_X + PLAYER_W >= ENEMY_X &&
* PLAYER_Y <= ENEMY_Y + ENEMY_H &&
* PLAYER_H + PLAYER_Y >= ENEMY_Y
*-----------------------------------------------------------
CHECK_ENEMY_COLLISIONS:
    CLR.L   D1                      ; Clear D1
    CLR.L   D2                      ; Clear D2
PLAYER_X_LTE_TO_ENEMY_X_PLUS_W:
    MOVE.L  PLAYER_X,   D1          ; Move Player X to D1
    MOVE.L  ENEMY_X,    D2          ; Move Enemy X to D2
    ADD.L   #ENMY_W_INIT,D2          ; Set Enemy width X + Width
    CMP.L   D2,         D1          ; Do they Overlap ?
    BLE     PLAYER_X_PLUS_W_LTE_TO_ENEMY_X  ; Less than or Equal ?
    BRA     COLLISION_CHECK_DONE    ; If not no collision
PLAYER_X_PLUS_W_LTE_TO_ENEMY_X:     ; Check player is not
    ADD.L   #PLYR_W_INIT,D1          ; Move Player Width to D1
    MOVE.L  ENEMY_X,    D2          ; Move Enemy X to D2
    CMP.L   D2,         D1          ; Do they OverLap ?
    BGE     PLAYER_Y_LTE_TO_ENEMY_Y_PLUS_H  ; Less than or Equal
    BRA     COLLISION_CHECK_DONE    ; If not no collision
PLAYER_Y_LTE_TO_ENEMY_Y_PLUS_H:
    MOVE.L  PLAYER_Y,   D1          ; Move Player Y to D1
    MOVE.L  ENEMY_Y,    D2          ; Move Enemy Y to D2
    ADD.L   #ENMY_H_INIT,D2          ; Set Enemy Height to D2
    CMP.L   D2,         D1          ; Do they Overlap ?
    BLE     PLAYER_Y_PLUS_H_LTE_TO_ENEMY_Y  ; Less than or Equal
    BRA     COLLISION_CHECK_DONE    ; If not no collision
PLAYER_Y_PLUS_H_LTE_TO_ENEMY_Y:     ; Less than or Equal ?
    ADD.L   #PLYR_H_INIT,D1          ; Add Player Height to D1
    MOVE.L  ENEMY_Y,    D2          ; Move Enemy Y to D2
    CMP.L   D2,         D1          ; Do they OverLap ?
    BGE     COLLISION               ; Collision !
    BRA     COLLISION_CHECK_DONE    ; If not no collision
COLLISION_CHECK_DONE:               ; No Collision
    RTS                             ; Return to subroutine

COLLISION:
    BSR     PLAY_OPPS               ; Play Opps Wav
    MOVE.L  #00, PLAYER_SCORE       ; Reset Player Score
    RTS                             ; Return to subroutine
    
*-----------------------------------------------------------
* Subroutine    : Food Collision Check
* Description   : Axis-Aligned Bounding Box Collision Detection
* Algorithm checks for overlap on the 4 sides of the Player and
* Food rectangles
* PLAYER_X <= FOOD_X + FOOD_W &&
* PLAYER_X + PLAYER_W >= FOOD_X &&
* PLAYER_Y <= FOOD_Y + FOOD_H &&
* PLAYER_H + PLAYER_Y >= FOOD_Y
*-----------------------------------------------------------
CHECK_FOOD_COLLISIONS:    
    SUB.L   A4,     A4              ; Clear the registers
    SUB.L   A5,     A5
    LEA     FOOD_X, A4              ; Load the X coordinates of all food
    LEA     FOOD_Y, A5              ; Load the Y coordinates of all food
CHECK_FOOD_COLLISIONS_LOOP:
    CLR.L   D1                          ; Clear D1
    CLR.L   D2                          ; Clear D2
    CLR.L   D3
    TST.L   (A4)                        ; Check if you reached the end of the array
    BEQ     END_FOOD_COLLISIONS_CHECK   ; If the end of the array is reached

PLAYER_X_LTE_TO_FOOD_X_PLUS_W:
    MOVE.L  PLAYER_X,   D1          ; Move Player X to D1
    MOVE.L  (A4),D2                 ; Move Food X to D2
    MOVE.L  #FOOD_W,D3
    ADD.L   D3,D2               ; Set Food width X + Width
    CMP.L   D2,         D1          ; Do they Overlap ?
    BLE     PLAYER_X_PLUS_W_LTE_TO_FOOD_X  ; Less than or Equal ?
    BRA     FOOD_COLLISION_CHECK_DONE    ; If not no collision
PLAYER_X_PLUS_W_LTE_TO_FOOD_X:      ; Check player is not
    MOVE.L  #PLYR_W_INIT,D3
    ADD.L   D3,D1          ; Move Player Width to D1
    MOVE.L  (A4),D2                 ; Move Food X to D2
    CMP.L   D2,         D1          ; Do they OverLap ?
    BGE     PLAYER_Y_LTE_TO_FOOD_Y_PLUS_H  ; Less than or Equal
    BRA     FOOD_COLLISION_CHECK_DONE    ; If not no collision
PLAYER_Y_LTE_TO_FOOD_Y_PLUS_H:
    MOVE.L  PLAYER_Y,   D1          ; Move Player Y to D1
    MOVE.L  (A5),D2                 ; Move Food Y to D2
    MOVE.L  #FOOD_H,D3
    ADD.L   D3,D2               ; Add Food Height to D2
    CMP.L   D2,         D1          ; Do they Overlap ?
    BLE     PLAYER_Y_PLUS_H_LTE_TO_FOOD_Y  ; Less than or Equal
    BRA     FOOD_COLLISION_CHECK_DONE    ; If not no collision
PLAYER_Y_PLUS_H_LTE_TO_FOOD_Y:      ; Less than or Equal ?
    MOVE.L  #PLYR_H_INIT,D3
    ADD.L   D3,D1          ; Add Player Height to D1
    MOVE.L  (A5),D2                 ; Move Food Y to D2
    CMP.L   D2,         D1          ; Do they OverLap ?
    BGE     FOOD_COLLISION               ; Collision !
    BRA     FOOD_COLLISION_CHECK_DONE    ; If not no collision
FOOD_COLLISION_CHECK_DONE:               ; No Collision
    MOVE.L  (A4)+,D1                     ; Increment A4
    MOVE.L  (A5)+,D1                     ; Increment A5
    BRA     CHECK_FOOD_COLLISIONS_LOOP   ; Check the next food

FOOD_COLLISION:
    CLR.L   D1                           ; Clear D1
    CLR.L   D2                           ; Clear D2
    ADD.L   #FOOD_POINTS, D1             ; Add Food Points to D1
    ADD.L   PLAYER_SCORE, D1             ; Add points to D1
    MOVE.L  D1,           PLAYER_SCORE   ; Save the new score
    MOVE.L  #-100,(A4)                   ; Move the food out of bounds
    MOVE.L  #-100,(A5)                   ; Move the food out of bounds
    BRA     END_FOOD_COLLISIONS_CHECK    ; Finish checking
END_FOOD_COLLISIONS_CHECK:
    RTS

*-----------------------------------------------------------
* Subroutine    : EXIT
* Description   : Exit message and End Game
*-----------------------------------------------------------
EXIT:
    ; Show if Exiting is Running
    MOVE.B  #TC_CURSR_P,D0          ; Set Cursor Position
    MOVE.W  #$4004,     D1          ; Col 40, Row 1
    TRAP    #15                     ; Trap (Perform action)
    LEA     EXIT_MSG,   A1          ; Exit
    MOVE    #13,        D0          ; No Line feed
    TRAP    #15                     ; Trap (Perform action)
    MOVE.B  #TC_EXIT,   D0          ; Exit Code
    TRAP    #15                     ; Trap (Perform action)
    SIMHALT

*-----------------------------------------------------------
* Section       : Messages
* Description   : Messages to Print on Console, names should be
* self documenting
*-----------------------------------------------------------
SCORE_MSG       DC.B    'Score : ', 0       ; Score Message
KEYCODE_MSG     DC.B    'KeyCode : ', 0     ; Keycode Message
JUMP_MSG        DC.B    'Jump....', 0       ; Jump Message

IDLE_MSG        DC.B    'Idle....', 0       ; Idle Message
UPDATE_MSG      DC.B    'Update....', 0     ; Update Message
DRAW_MSG        DC.B    'Draw....', 0       ; Draw Message

X_MSG           DC.B    'X:', 0             ; X Position Message
Y_MSG           DC.B    'Y:', 0             ; Y Position Message
VX_MSG          DC.B    'VX:', 0            ; Velocity X Position Message
VY_MSG          DC.B    'VY:', 0            ; Velocity Y Position Message

EXIT_MSG        DC.B    'Exiting....', 0    ; Exit Message

*-----------------------------------------------------------
* Section       : Graphic Colors
* Description   : Screen Pixel Color
*-----------------------------------------------------------
WHITE           EQU     $00FFFFFF
RED             EQU     $000000FF
GREEN           EQU     $00008000

*-----------------------------------------------------------
* Section       : Screen Size
* Description   : Screen Width and Height
*-----------------------------------------------------------
SCREEN_W        DS.L    01  ; Reserve Space for Screen Width
SCREEN_H        DS.L    01  ; Reserve Space for Screen Height

*-----------------------------------------------------------
* Section       : Keyboard Input
* Description   : Used for storing Keypresses
*-----------------------------------------------------------
CURRENT_KEY     DS.L    01  ; Reserve Space for Current Key Pressed

*-----------------------------------------------------------
* Section       : Entity Positions
* Description   : Player, Food and Enemy Position Memory 
* Locations
*-----------------------------------------------------------
PLAYER_X        DS.L    01  ; Reserve Space for Player X Position
PLAYER_Y        DS.L    01  ; Reserve Space for Player Y Position
PLAYER_SCORE    DS.L    01  ; Reserve Space for Player Score

PLYR_X_VELOCITY DS.L    01  ; Reserve Space for Player Horizontal Velocity
PLYR_Y_VELOCITY DS.L    01  ; Reserve Space for Player Vertical Velocity
PLYR_ON_GND     DS.L    01  ; Reserve Space for Player on Ground

ENEMY_X         DS.L    01  ; Reserve Space for Enemy X Position
ENEMY_Y         DS.L    01  ; Reserve Space for Enemy Y Position

FOOD_X          DC.L    05, 10, 15, 20, 30, 0  ; Reserve Space for Food X Positions
FOOD_Y          DC.L    05, 15, 25, 35, 55, 0  ; Reserve Space for Food Y Positions
FOOD_COUNT      DC.L    05                     ; Reserve Space for Food Count
    
*-----------------------------------------------------------
* Section       : Sounds
* Description   : Sound files, which are then loaded and given
* an address in memory, they take a longtime to process and play
* so keep the files small. Used https://voicemaker.in/ to
* generate and Audacity to convert MP3 to WAV
*-----------------------------------------------------------
JUMP_WAV        DC.B    'jump.wav',0        ; Jump Sound
RUN_WAV         DC.B    'run.wav',0         ; Run Sound
OPPS_WAV        DC.B    'opps.wav',0        ; Collision Opps

*-----------------------------------------------------------
* Section       : Utility
* Description   : Other stuff
*-----------------------------------------------------------
DELAY           DC.L    2000    ; Delay to slow down the game
SEED            DC.L    1       ; Seed to generate a random number

    END    START        ; last line of source

*~Font name~Courier New~
*~Font size~12~
*~Tab type~1~
*~Tab size~4~
