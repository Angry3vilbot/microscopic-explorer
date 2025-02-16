*-----------------------------------------------------------
* Title      : Microscopic Explorer
* Written by : Mykhailo Balaker
* Date       : 16/02/2025
* Description: A game made in Motorola 68000 assembly
*-----------------------------------------------------------

    ORG $1000
START:
    MOVE    #$2700,SR   ; Disable interrupts
    LEA     SCREEN,A0   ; Load screen memory address
    CLR.B   D0          ; Player X position
    CLR.B   D1          ; Player Y position
    BSR     DRAW_PLAYER ; Draw initial player position

GAME_LOOP:
     BSR     READ_INPUT   ; Read user input
     BSR     UPDATE_POS   ; Update position based on input
     BSR     DRAW_PLAYER  ; Draw player at new position
     BRA     GAME_LOOP    ; Repeat forever

; Read user input
READ_INPUT:
     MOVE.B  $FFFFFC02,D2 ; Read key input
     CMP.B   #$4E,D2      ; Up arrow
     BEQ     MOVE_UP
     CMP.B   #$4F,D2      ; Down arrow
     BEQ     MOVE_DOWN
     CMP.B   #$4B,D2      ; Left arrow
     BEQ     MOVE_LEFT
     CMP.B   #$4D,D2      ; Right arrow
     BEQ     MOVE_RIGHT
     RTS

MOVE_UP:
    SUBQ.B #1,D1    ; Move up (decrease Y)
    RTS
MOVE_DOWN:
    ADDQ.B #1,D1    ; Move down (increase Y)
    RTS
MOVE_LEFT:
    SUBQ.B #1,D0    ; Move left (decrease X)
    RTS
MOVE_RIGHT:
    ADDQ.B #1,D0    ; Move right (increase X)
    RTS

UPDATE_POS:
        ; Check boundaries for X (0-39)
        CMP.B   #0,D0            ; Check if X < 0
        BLT     CLAMP_X_LEFT
        CMP.B   #39,D0           ; Check if X > 39
        BGT     CLAMP_X_RIGHT

        ; Check boundaries for Y (0-24)
        CMP.B   #0,D1            ; Check if Y < 0
        BLT     CLAMP_Y_TOP
        CMP.B   #24,D1           ; Check if Y > 24
        BGT     CLAMP_Y_BOTTOM

        RTS

CLAMP_X_LEFT:
        MOVE.B  #0,D0            ; Set X to 0 (left boundary)
        RTS

CLAMP_X_RIGHT:
        MOVE.B  #39,D0           ; Set X to 39 (right boundary)
        RTS

CLAMP_Y_TOP:
        MOVE.B  #0,D1            ; Set Y to 0 (top boundary)
        RTS

CLAMP_Y_BOTTOM:
        MOVE.B  #24,D1           ; Set Y to 24 (bottom boundary)
        RTS

; Draw player
DRAW_PLAYER:
    LEA     SCREEN,A0            ; Load Screen memory address into A0
    MOVE.W  D1,D2                ; Copy Y-coordinate to D2
    MULU    #40,D2               ; Multiply Y by 40 (width of the screen)
    ADD.W   D0,D2                ; Add X-coordinate (D0) to the result
    MOVE.B  #'O',0(A0,D2.W)      ; Use D2 as the final offset to store 'O'
    RTS

    ORG     $4000       ; Screen memory
SCREEN:
    ;Define Storage Byte - reserve a certain amount of bytes
    DS.B    40*25       ; 40x25 character screen buffer

    END    START