*-----------------------------------------------------------
* Title      : Microscopic Explorer Random Position Generator
* Written by : Mykhailo Balaker
* Date       : 2025-02-18
* Description: Generates random X and Y positions within the screen bounds
*-----------------------------------------------------------
    ORG    $1000
TC_SCREEN   EQU         33          ; Screen size information trap code
TC_TIME     EQU         8           ; Trap code to get the current time

START:
    MOVE.B  #TC_SCREEN,D0         ; Access screen information
    MOVE.L  #1024*$10000+768, D1   ; Set the resolution to 1024x768
    TRAP    #15                   ; Interpret D0 and D1 for screen size
    MOVE.L  #1024, SCREEN_W        ; Store screen width
    MOVE.L  #768, SCREEN_H         ; Store screen height
    MOVE.L  SCREEN_W, A0
    MOVE.L  SCREEN_H, A1

    MOVE.B  #TC_TIME,D0           ; Get the current time
    TRAP    #15
    MOVE.L  D1,SEED               ; Use current time as seed

    MOVE.L  SCREEN_W,D6           ; Use screen width as max
    BSR     RAND_GEN
    MOVE.W  D1,D4                 ; Store X coordinate
    
    MOVE.L  SCREEN_H,D6           ; Use screen height as max
    BSR     RAND_GEN
    MOVE.W  D1,D3                 ; Store Y coordinate



RAND_GEN:
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

* Variables and Constants
SEED            DS.L    1   ; Reserve space for seed
SCREEN_W        DS.L    1   ; Reserve space for screen width
SCREEN_H        DS.L    1   ; Reserve space for screen height
    END    START                  ; Last line of source
*~Font name~Courier New~
*~Font size~12~
*~Tab type~1~
*~Tab size~4~
