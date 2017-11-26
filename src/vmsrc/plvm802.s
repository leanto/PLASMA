;**********************************************************
;*
;*          APPLE ][ 65802/65816 PLASMA INTERPRETER
;*
;*              SYSTEM ROUTINES AND LOCATIONS
;*
;**********************************************************
;*
;* THE DEFAULT CPU MODE FOR EXECUTING OPCODES IS:
;*   16 BIT A/M
;*    8 BIT X/Y
;*
;* THE EVALUATION STACK WILL BE THE HARDWARE STACK UNTIL
;* A CALL IS MADE. THE 16 BIT PARAMETERS WILL BE COPIED
;* TO THE ZERO PAGE INTERLEAVED EVALUATION STACK.
;*
SELFMODIFY  =   0
;*
;* MONITOR SPECIAL LOCATIONS
;*
CSWL    =       $36
CSWH    =       $37
PROMPT  =       $33
;*
;* PRODOS
;*
PRODOS  =       $BF00
DEVCNT  =       $BF31            ; GLOBAL PAGE DEVICE COUNT
DEVLST  =       $BF32            ; GLOBAL PAGE DEVICE LIST
MACHID  =       $BF98            ; GLOBAL PAGE MACHINE ID BYTE
RAMSLOT =       $BF26            ; SLOT 3, DRIVE 2 IS /RAM'S DRIVER VECTOR
NODEV   =       $BF10
;*
;* HARDWARE ADDRESSES
;*
KEYBD   =       $C000
CLRKBD  =       $C010
SPKR    =       $C030
LCRDEN  =       $C080
LCWTEN  =       $C081
ROMEN   =       $C082
LCRWEN  =       $C083
LCBNK2  =       $00
LCBNK1  =       $08
ALTZPOFF=       $C008
ALTZPON =       $C009
ALTRDOFF=       $C002
ALTRDON =       $C003
ALTWROFF=       $C004
ALTWRON =       $C005
        !SOURCE "vmsrc/plvmzp.inc"
OP16IDX =       FETCHOP+4
OP16PAGE=       OP16IDX+1
DROP16  =       $EE
NEXTOP16=       $EF
STRBUF  =       $0280
INTERP  =       $03D0
;*
;* HARDWARE STACK OFFSETS
;*
TOS     =       $01             ; TOS
NOS     =       $03             ; TOS-1
;*
;* INTERPRETER INSTRUCTION POINTER INCREMENT MACRO
;*
        !MACRO  INC_IP  {
        INY
        BNE     * + 8
        SEP     $20             ; SET 8 BIT MODE
        INC     IP16H
        REP     $20             ; SET 16 BIT MODE
        }
;******************************
;*                            *
;* INTERPRETER INITIALIZATION *
;*                            *
;******************************
*        =      $2000
        LDX     #$FE
        TXS
        LDX     #$00
        STX     $01FF
;*
;* DISCONNECT /RAM
;*
        ;SEI                    ; DISABLE /RAM
        LDA     MACHID
        AND     #$30
        CMP     #$30
        BNE     RAMDONE
        LDA     RAMSLOT
        CMP     NODEV
        BNE     RAMCONT
        LDA     RAMSLOT+1
        CMP     NODEV+1
        BEQ     RAMDONE
RAMCONT LDY     DEVCNT
RAMLOOP LDA     DEVLST,Y
        AND     #$F3
        CMP     #$B3
        BEQ     GETLOOP
        DEY
        BPL     RAMLOOP
        BMI     RAMDONE
GETLOOP LDA     DEVLST+1,Y
        STA     DEVLST,Y
        BEQ     RAMEXIT
        INY
        BNE     GETLOOP
RAMEXIT LDA     NODEV
        STA     RAMSLOT
        LDA     NODEV+1
        STA     RAMSLOT+1
        DEC     DEVCNT
RAMDONE ;CLI UNTIL I KNOW WHAT TO DO WITH THE UNENHANCED IIE
;*
;* MOVE VM INTO LANGUAGE CARD
;*
        BIT     LCRWEN+LCBNK2
        BIT     LCRWEN+LCBNK2
        LDA     #<VMCORE
        STA     SRCL
        LDA     #>VMCORE
        STA     SRCH
        LDY     #$00
        STY     DSTL
        LDA     #$D0
        STA     DSTH
-       LDA     (SRC),Y         ; COPY VM+CMD INTO LANGUAGE CARD
        STA     (DST),Y
        INY
        BNE     -
        INC     SRCH
        INC     DSTH
        LDA     DSTH
        CMP     #$E0
        BNE     -
;*
;* MOVE FIRST PAGE OF 'BYE' INTO PLACE
;*
        STY     SRCL
        LDA     #$D1
        STA     SRCH
-       LDA     (SRC),Y
        STA     $1000,Y
        INY
        BNE     -
;*
;* SAVE DEFAULT COMMAND INTERPRETER PATH IN LC
;*
        JSR     PRODOS          ; GET PREFIX
        !BYTE   $C7
        !WORD   GETPFXPARMS
        LDY     STRBUF          ; APPEND "CMD"
        LDA     #"/"
        CMP     STRBUF,Y
        BEQ     +
        INY
        STA     STRBUF,Y
+       LDA     #"C"
        INY
        STA     STRBUF,Y
        LDA     #"M"
        INY
        STA     STRBUF,Y
        LDA     #"D"
        INY
        STA     STRBUF,Y
        STY     STRBUF
        BIT     LCRWEN+LCBNK2    ; COPY TO LC FOR BYE
        BIT     LCRWEN+LCBNK2
-       LDA     STRBUF,Y
        STA     LCDEFCMD,Y
        DEY
        BPL     -
        JMP     CMDENTRY
GETPFXPARMS !BYTE 1
        !WORD   STRBUF          ; PATH STRING GOES HERE
;************************************************
;*                                              *
;* LANGUAGE CARD RESIDENT PLASMA VM STARTS HERE *
;*                                              *
;************************************************
VMCORE  =        *
        !PSEUDOPC       $D000 {
;****************
;*              *
;* OPCODE TABLE *
;*              *
;****************
        !ALIGN  255,0
OPTBL   !WORD   ZERO,ADD,SUB,MUL,DIV,MOD,INCR,DECR              ; 00 02 04 06 08 0A 0C 0E
        !WORD   NEG,COMP,BAND,IOR,XOR,SHL,SHR,IDXW              ; 10 12 14 16 18 1A 1C 1E
        !WORD   LNOT,LOR,LAND,LA,LLA,CB,CW,CS                   ; 20 22 24 26 28 2A 2C 2E
        !WORD   DROP,DUP,PUSHEP,PULLEP,BRGT,BRLT,BREQ,BRNE      ; 30 32 34 36 38 3A 3C 3E
        !WORD   ISEQ,ISNE,ISGT,ISLT,ISGE,ISLE,BRFLS,BRTRU       ; 40 42 44 46 48 4A 4C 4E
        !WORD   BRNCH,IBRNCH,CALL,ICAL,ENTER,LEAVE,RET,CFFB     ; 50 52 54 56 58 5A 5C 5E
        !WORD   LB,LW,LLB,LLW,LAB,LAW,DLB,DLW                   ; 60 62 64 66 68 6A 6C 6E
        !WORD   SB,SW,SLB,SLW,SAB,SAW,DAB,DAW                   ; 70 72 74 76 78 7A 7C 7E
;*
;* ENTER INTO BYTECODE INTERPRETER - IMMEDIATELY SWITCH TO NATIVE
;*
        !AL
DINTRP  CLC                     ; SWITCH TO NATIVE MODE
        XCE
        REP     #$20            ; 16 BIT A/M
        SEP     #$10            ; 8 BIT X,Y
        PLA
        INC     A
        STA     IP16
        LDA     IFP
        PHA                     ; SAVE ON STACK FOR LEAVE/RET
        LDA     PP              ; SET FP TO PP
        STA     IFP
        LDY     #$00
!IF SELFMODIFY {
        BEQ +
} ELSE {
        STX     ESP
        TSX
        STX     HWSP
        LDX     #>OPTBL
        STX     OP16PAGE
        JMP     FETCHOP16
}
IINTRP  CLC                     ; SWITCH TO NATIVE MODE
        XCE
        REP     #$20            ; 16 BIT A/M
        SEP     #$10            ; 8 BIT X,Y
        PLA
        STA     TMP
        LDY     #$01
        LDA     (TMP),Y
        DEY
        STA     IP16
        LDA     IFP
        PHA                     ; SAVE ON STACK FOR LEAVE/RET
        LDA     PP              ; SET FP TO PP
        STA     IFP
+       STX     ESP
        TSX
        STX     HWSP
        LDX     #>OPTBL
        STX     OP16PAGE
!IF SELFMODIFY {
        LDX     LCRWEN+LCBNK2
        LDX     LCRWEN+LCBNK2
}
        JMP     FETCHOP16
IINTRPX CLC                     ; SWITCH TO NATIVE MODE
        XCE
        REP     #$20            ; 16 BIT A/M
        SEP     #$10            ; 8 BIT X,Y
        PLA
        STA     TMP
        LDY     #$0
        LDA     (TMP),Y
        STA     IP16
        DEY
        LDA     IFP
        PHA                     ; SAVE ON STACK FOR LEAVE/RET
        LDA     PP             ; SET FP TO PP
        STA     IFP
        STX     ESP
        TSX
        STX     HWSP
        LDX     #>OPXTBL
        STX     OP16PAGE
        ;SEI UNTIL I KNOW WHAT TO DO WITH THE UNENHANCED IIE
        STX     ALTRDON
!IF SELFMODIFY {
        LDX     LCRWEN+LCBNK2
        LDX     LCRWEN+LCBNK2
}
        JMP     FETCHOP16
;************************************************************
;*                                                          *
;* 'BYE' PROCESSING - COPIED TO $1000 ON PRODOS BYE COMMAND *
;*                                                          *
;************************************************************
        !AS
        !ALIGN  255,0
        !PSEUDOPC       $1000 {
BYE     LDY     DEFCMD
-       LDA     DEFCMD,Y        ; SET DEFAULT COMMAND WHEN CALLED FROM 'BYE'
        STA     STRBUF,Y
        DEY
        BPL     -
        INY                     ; CLEAR CMDLINE BUFF
        STY     $01FF
CMDENTRY =      *
;
; DEACTIVATE 80 COL CARDS
;
        BIT     ROMEN
        LDY     #4
-       LDA     DISABLE80,Y
        ORA     #$80
        JSR     $FDED
        DEY
        BPL     -
        BIT     $C054           ; SET TEXT MODE
        BIT     $C051
        BIT     $C05F
        JSR     $FC58           ; HOME
;
; INSTALL PAGE 0 FETCHOP ROUTINE
;
        LDY     #$12
-       LDA     PAGE0,Y
        STA     DROP16,Y
        DEY
        BPL     -
;
; INSTALL PAGE 3 VECTORS
;
        LDY     #$12
-       LDA     PAGE3,Y
        STA     INTERP,Y
        DEY
        BPL     -
;
; READ CMD INTO MEMORY
;
        JSR     PRODOS          ; CLOSE EVERYTHING
        !BYTE   $CC
        !WORD   CLOSEPARMS
        BNE     FAIL
        JSR     PRODOS          ; OPEN CMD
        !BYTE   $C8
        !WORD   OPENPARMS
        BNE     FAIL
        LDA     REFNUM
        STA     READPARMS+1
        JSR     PRODOS
        !BYTE   $CA
        !WORD   READPARMS
        BNE     FAIL
        JSR     PRODOS
        !BYTE   $CC
        !WORD   CLOSEPARMS
        BNE     FAIL
;
; INIT VM ENVIRONMENT STACK POINTERS
;
;        LDA #$00               ; INIT FRAME POINTER
        STA     PPL
        STA     IFPL
        LDA     #$BF
        STA     PPH
        STA     IFPH
        LDX     #$FE            ; INIT STACK POINTER (YES, $FE. SEE GETS)
        TXS
        LDX     #ESTKSZ/2       ; INIT EVAL STACK INDEX
        JMP     $2000           ; JUMP TO LOADED SYSTEM COMMAND
;
; PRINT FAIL MESSAGE, WAIT FOR KEYPRESS, AND REBOOT
;
FAIL    INC     $3F4            ; INVALIDATE POWER-UP BYTE
        LDY     #33
-       LDA     FAILMSG,Y
        ORA     #$80
        JSR     $FDED
        DEY
        BPL     -
        JSR     $FD0C           ; WAIT FOR KEYPRESS
        JMP     ($FFFC)         ; RESET
OPENPARMS !BYTE 3
        !WORD   STRBUF
        !WORD   $0800
REFNUM  !BYTE   0
READPARMS !BYTE 4
        !BYTE   0
        !WORD   $2000
        !WORD   $9F00
        !WORD   0
CLOSEPARMS !BYTE 1
        !BYTE   0
DISABLE80 !BYTE 21, 13, '1', 26, 13
FAILMSG !TEXT   "...TESER OT YEK YNA .DMC GNISSIM"
PAGE0    =      *
;******************************
;*                            *
;* INTERP BYTECODE INNER LOOP *
;*                            *
;******************************
        !PSEUDOPC       $00EE {
        PLA                     ; DROP16 @ $EE
        INY                     ; NEXTOP16 @ $EF
        BEQ     NEXTOPH
        LDX     $FFFF,Y         ; FETCHOP16 @ $F2, IP16 MAPS OVER $FFFF @ $F3
        JMP     (OPTBL,X)       ; OP16IDX AND OP16PAGE MAP OVER OPTBL
NEXTOPH SEP     $20             ; SET 8 BIT MODE
        INC     IP16H
        REP     $20             ; SET 16 BIT MODE
        BRA     FETCHOP
}
PAGE3   =       *
;*
;* PAGE 3 VECTORS INTO INTERPRETER
;*
        !PSEUDOPC       $03D0 {
        BIT     LCRDEN+LCBNK2   ; $03D0 - DIRECT INTERP ENTRY
        JMP     DINTRP
        BIT     LCRDEN+LCBNK2   ; $03D6 - INDIRECT INTERP ENTRY
        JMP     IINTRP
        BIT     LCRDEN+LCBNK2   ; $03DC - INDIRECT INTERPX ENTRY
        JMP     IINTRPX
}
DEFCMD  !FILL   28
ENDBYE  =       *
}
LCDEFCMD =      *-28            ; DEFCMD IN LC MEMORY
;*****************
;*               *
;* OPXCODE TABLE *
;*               *
;*****************
        !ALIGN  255,0
OPXTBL  !WORD   ZERO,ADD,SUB,MUL,DIV,MOD,INCR,DECR              ; 00 02 04 06 08 0A 0C 0E
        !WORD   NEG,COMP,BAND,IOR,XOR,SHL,SHR,IDXW              ; 10 12 14 16 18 1A 1C 1E
        !WORD   LNOT,LOR,LAND,LA,LLA,CB,CW,CSX                  ; 20 22 24 26 28 2A 2C 2E
        !WORD   DROP,DUP,PUSHEP,PULLEP,BRGT,BRLT,BREQ,BRNE      ; 30 32 34 36 38 3A 3C 3E
        !WORD   ISEQ,ISNE,ISGT,ISLT,ISGE,ISLE,BRFLS,BRTRU       ; 40 42 44 46 48 4A 4C 4E
        !WORD   BRNCH,IBRNCH,CALLX,ICALX,ENTER,LEAVEX,RETX,CFFB; 50 52 54 56 58 5A 5C 5E
        !WORD   LBX,LWX,LLBX,LLWX,LABX,LAWX,DLB,DLW             ; 60 62 64 66 68 6A 6C 6E
        !WORD   SB,SW,SLB,SLW,SAB,SAW,DAB,DAW                   ; 70 72 74 76 78 7A 7C 7E
;*********************************************************************
;*
;*      CODE BELOW HERE DEFAULTS TO NATIVE 16 BIT A/M, 8 BIT X,Y
;*
;*********************************************************************
        !AL
;*
;* ADD TOS TO TOS-1
;*
ADD     PLA
        CLC
        ADC     TOS,S
        STA     TOS,S
        JMP     NEXTOP16
;*
;* SUB TOS FROM TOS-1(NOS)
;*
SUB     LDA     NOS,S
        SEC
        SBC     TOS,S
        STA     NOS,X
        JMP     DROP16
;*
;* SHIFT TOS LEFT BY 1, ADD TO TOS-1
;*
IDXW    PLA
        ASL
        CLC
        ADC     TOS,S
        STA     TOS,S
        JMP     NEXTOP
;*
;* MUL TOS-1 BY TOS
;*
MUL     STY     IPY
        LDY     #$10
        LDA     ESTKL+1,X
        EOR     #$FF
        STA     TMPL
        LDA     ESTKH+1,X
        EOR     #$FF
        STA     TMPH
        LDA     #$00
        STA     ESTKL+1,X       ; PRODL
;       STA     ESTKH+1,X       ; PRODH
MULLP   LSR     TMPH            ; MULTPLRH
        ROR     TMPL            ; MULTPLRL
        BCS     +
        STA     ESTKH+1,X       ; PRODH
        LDA     ESTKL,X         ; MULTPLNDL
        ADC     ESTKL+1,X       ; PRODL
        STA     ESTKL+1,X
        LDA     ESTKH,X         ; MULTPLNDH
        ADC     ESTKH+1,X       ; PRODH
+       ASL     ESTKL,X         ; MULTPLNDL
        ROL     ESTKH,X         ; MULTPLNDH
        DEY
        BNE     MULLP
        STA     ESTKH+1,X       ; PRODH
        LDY     IPY
;       INX
;       JMP     NEXTOP
        JMP     DROP
;*
;* INTERNAL DIVIDE ALGORITHM
;*
_NEG    LDA     #$00
        SEC
        SBC     ESTKL,X
        STA     ESTKL,X
        LDA     #$00
        SBC     ESTKH,X
        STA     ESTKH,X
        RTS
_DIV    STY     IPY
        LDY     #$11            ; #BITS+1
        LDA     #$00
        STA     TMPL            ; REMNDRL
        STA     TMPH            ; REMNDRH
        LDA     ESTKH,X
        AND     #$80
        STA     DVSIGN
        BPL     +
        JSR     _NEG
        INC     DVSIGN
+       LDA     ESTKH+1,X
        BPL     +
        INX
        JSR     _NEG
        DEX
        INC     DVSIGN
        BNE     _DIV1
+       ORA     ESTKL+1,X       ; DVDNDL
        BEQ     _DIVEX
_DIV1   ASL     ESTKL+1,X       ; DVDNDL
        ROL     ESTKH+1,X       ; DVDNDH
        DEY
        BCC     _DIV1
_DIVLP  ROL     TMPL            ; REMNDRL
        ROL     TMPH            ; REMNDRH
        LDA     TMPL            ; REMNDRL
        CMP     ESTKL,X         ; DVSRL
        LDA     TMPH            ; REMNDRH
        SBC     ESTKH,X         ; DVSRH
        BCC     +
        STA     TMPH            ; REMNDRH
        LDA     TMPL            ; REMNDRL
        SBC     ESTKL,X         ; DVSRL
        STA     TMPL            ; REMNDRL
        SEC
+       ROL     ESTKL+1,X       ; DVDNDL
        ROL     ESTKH+1,X       ; DVDNDH
        DEY
        BNE     _DIVLP
_DIVEX  INX
        LDY     IPY
        RTS
;*
;* NEGATE TOS
;*
NEG     LDA     #$00
        SEC
        SBC     ESTKL,X
        STA     ESTKL,X
        LDA     #$00
        SBC     ESTKH,X
        STA     ESTKH,X
        JMP     NEXTOP
;*
;* DIV TOS-1 BY TOS
;*
DIV     JSR     _DIV
        LSR     DVSIGN          ; SIGN(RESULT) = (SIGN(DIVIDEND) + SIGN(DIVISOR)) & 1
        BCS     NEG
        JMP     NEXTOP
;*
;* MOD TOS-1 BY TOS
;*
MOD     JSR     _DIV
        LDA     TMPL            ; REMNDRL
        STA     ESTKL,X
        LDA     TMPH            ; REMNDRH
        STA     ESTKH,X
        LDA     DVSIGN          ; REMAINDER IS SIGN OF DIVIDEND
        BMI     NEG
        JMP     NEXTOP
;*
;* INCREMENT TOS
;*
INCR    INC     ESTKL,X
        BNE     INCR1
        INC     ESTKH,X
INCR1   JMP     NEXTOP
;*
;* DECREMENT TOS
;*
DECR    LDA     ESTKL,X
        BNE     DECR1
        DEC     ESTKH,X
DECR1   DEC     ESTKL,X
        JMP     NEXTOP
;*
;* BITWISE COMPLIMENT TOS
;*
COMP    LDA     #$FF
        EOR     ESTKL,X
        STA     ESTKL,X
        LDA     #$FF
        EOR     ESTKH,X
        STA     ESTKH,X
        JMP     NEXTOP
;*
;* BITWISE AND TOS TO TOS-1
;*
BAND    LDA     ESTKL+1,X
        AND     ESTKL,X
        STA     ESTKL+1,X
        LDA     ESTKH+1,X
        AND     ESTKH,X
        STA     ESTKH+1,X
;       INX
;       JMP     NEXTOP
        JMP     DROP
;*
;* INCLUSIVE OR TOS TO TOS-1
;*
IOR     LDA     ESTKL+1,X
        ORA     ESTKL,X
        STA     ESTKL+1,X
        LDA     ESTKH+1,X
        ORA     ESTKH,X
        STA     ESTKH+1,X
;       INX
;       JMP     NEXTOP
        JMP     DROP
;*
;* EXLUSIVE OR TOS TO TOS-1
;*
XOR     LDA     ESTKL+1,X
        EOR     ESTKL,X
        STA     ESTKL+1,X
        LDA     ESTKH+1,X
        EOR     ESTKH,X
        STA     ESTKH+1,X
;       INX
;       JMP     NEXTOP
        JMP     DROP
;*
;* SHIFT TOS-1 LEFT BY TOS
;*
SHL     STY     IPY
        LDA     ESTKL,X
        CMP     #$08
        BCC     SHL1
        LDY     ESTKL+1,X
        STY     ESTKH+1,X
        LDY     #$00
        STY     ESTKL+1,X
        SBC     #$08
SHL1    TAY
        BEQ     SHL3
SHL2    ASL     ESTKL+1,X
        ROL     ESTKH+1,X
        DEY
        BNE     SHL2
SHL3    LDY     IPY
;       INX
;       JMP     NEXTOP
        JMP     DROP
;*
;* SHIFT TOS-1 RIGHT BY TOS
;*
SHR     STY     IPY
        LDA     ESTKL,X
        CMP     #$08
        BCC     SHR2
        LDY     ESTKH+1,X
        STY     ESTKL+1,X
        CPY     #$80
        LDY     #$00
        BCC     SHR1
        DEY
SHR1    STY     ESTKH+1,X
        SEC
        SBC     #$08
SHR2    TAY
        BEQ     SHR4
        LDA     ESTKH+1,X
SHR3    CMP     #$80
        ROR
        ROR     ESTKL+1,X
        DEY
        BNE     SHR3
        STA     ESTKH+1,X
SHR4    LDY     IPY
;       INX
;       JMP     NEXTOP
        JMP     DROP
;*
;* LOGICAL NOT
;*
LNOT    LDA     ESTKL,X
        ORA     ESTKH,X
        BEQ     LNOT1
        LDA     #$FF
LNOT1   EOR     #$FF
        STA     ESTKL,X
        STA     ESTKH,X
        JMP     NEXTOP
;*
;* LOGICAL AND
;*
LAND    LDA     ESTKL+1,X
        ORA     ESTKH+1,X
        BEQ     LAND2
        LDA     ESTKL,X
        ORA     ESTKH,X
        BEQ     LAND1
        LDA     #$FF
LAND1   STA     ESTKL+1,X
        STA     ESTKH+1,X
;LAND2  INX
;       JMP     NEXTOP
LAND2   JMP     DROP
;*
;* LOGICAL OR
;*
LOR     LDA     ESTKL,X
        ORA     ESTKH,X
        ORA     ESTKL+1,X
        ORA     ESTKH+1,X
        BEQ     LOR1
        LDA     #$FF
        STA     ESTKL+1,X
        STA     ESTKH+1,X
;LOR1   INX
;       JMP     NEXTOP
LOR1    JMP     DROP
;*
;* DUPLICATE TOS
;*
DUP     DEX
        LDA     ESTKL+1,X
        STA     ESTKL,X
        LDA     ESTKH+1,X
        STA     ESTKH,X
        JMP     NEXTOP
;*
;* PUSH EVAL STACK POINTER TO CALL STACK
;*
PUSHEP  TXA
        PHA
        JMP     NEXTOP
;*
;* PULL EVAL STACK POINTER FROM CALL STACK
;*
PULLEP  PLA
        TAX
        JMP     NEXTOP
;*
;* CONSTANT
;*
ZERO    DEX
        LDA     #$00
        STA     ESTKL,X
        STA     ESTKH,X
        JMP     NEXTOP
CFFB    LDA     #$FF
    !BYTE $2C   ; BIT $00A9 - effectively skips LDA #$00, no harm in reading this address
CB      LDA     #$00
        DEX
        STA     ESTKH,X
        +INC_IP
        LDA     (IP),Y
        STA     ESTKL,X
        JMP     NEXTOP
;*
;* LOAD ADDRESS & LOAD CONSTANT WORD (SAME THING, WITH OR WITHOUT FIXUP)
;*
LA      =       *
CW      DEX
        +INC_IP
        LDA     (IP),Y
        STA     ESTKL,X
        +INC_IP
        LDA     (IP),Y
        STA     ESTKH,X
        JMP     NEXTOP
;*
;* CONSTANT STRING
;*
CS      DEX
        +INC_IP
        TYA                     ; NORMALIZE IP AND SAVE STRING ADDR ON ESTK
        CLC
        ADC     IPL
        STA     IPL
        STA     ESTKL,X
        LDA     #$00
        TAY
        ADC     IPH
        STA     IPH
        STA     ESTKH,X
        LDA     (IP),Y
        TAY
        JMP     NEXTOP
;
CSX DEX
        +INC_IP
        TYA                     ; NORMALIZE IP
        CLC
        ADC     IPL
        STA     IPL
        LDA     #$00
        TAY
        ADC     IPH
        STA     IPH
        LDA     PPL             ; SCAN POOL FOR STRING ALREADY THERE
        STA     TMPL
        LDA     PPH
        STA     TMPH
_CMPPSX ;LDA    TMPH            ; CHECK FOR END OF POOL
        CMP     IFPH
        BCC     _CMPSX          ; CHECK FOR MATCHING STRING
        BNE     _CPYSX          ; BEYOND END OF POOL, COPY STRING OVER
        LDA     TMPL
        CMP     IFPL
        BCS     _CPYSX          ; AT OR BEYOND END OF POOL, COPY STRING OVER
_CMPSX  STA     ALTRDOFF
        LDA     (TMP),Y         ; COMPARE STRINGS FROM AUX MEM TO STRINGS IN MAIN MEM
        STA     ALTRDON
        CMP     (IP),Y          ; COMPARE STRING LENGTHS
        BNE     _CNXTSX1
        TAY
_CMPCSX STA     ALTRDOFF
        LDA     (TMP),Y         ; COMPARE STRING CHARS FROM END
        STA     ALTRDON
        CMP     (IP),Y
        BNE     _CNXTSX
        DEY
        BNE     _CMPCSX
        LDA     TMPL            ; MATCH - SAVE EXISTING ADDR ON ESTK AND MOVE ON
        STA     ESTKL,X
        LDA     TMPH
        STA     ESTKH,X
        BNE     _CEXSX
_CNXTSX LDY     #$00
        STA     ALTRDOFF
        LDA     (TMP),Y
        STA     ALTRDON
_CNXTSX1 SEC
        ADC     TMPL
        STA     TMPL
        LDA     #$00
        ADC     TMPH
        STA     TMPH
        BNE     _CMPPSX
_CPYSX  LDA     (IP),Y          ; COPY STRING FROM AUX TO MAIN MEM POOL
        TAY                     ; MAKE ROOM IN POOL AND SAVE ADDR ON ESTK
        EOR     #$FF
        CLC
        ADC     PPL
        STA     PPL
        STA     ESTKL,X
        LDA     #$FF
        ADC     PPH
        STA     PPH
        STA     ESTKH,X         ; COPY STRING FROM AUX MEM BYTECODE TO MAIN MEM POOL
_CPYSX1 LDA     (IP),Y          ; ALTRD IS ON,  NO NEED TO CHANGE IT HERE
        STA     (PP),Y          ; ALTWR IS OFF, NO NEED TO CHANGE IT HERE
        DEY
        CPY     #$FF
        BNE     _CPYSX1
        INY
_CEXSX  LDA     (IP),Y          ; SKIP TO NEXT OP ADDR AFTER STRING
        TAY
        JMP     NEXTOP
;*
;* LOAD VALUE FROM ADDRESS TAG
;*
!IF SELFMODIFY {
LB      LDA     ESTKL,X
        STA     LBLDA+1
        LDA     ESTKH,X
        STA     LBLDA+2
LBLDA   LDA   $FFFF
        STA     ESTKL,X
    LDA #$00
        STA     ESTKH,X
        JMP     NEXTOP
} ELSE {
LB      LDA     ESTKL,X
        STA     TMPL
        LDA     ESTKH,X
        STA     TMPH
        STY     IPY
        LDY     #$00
        LDA     (TMP),Y
        STA     ESTKL,X
        STY     ESTKH,X
        LDY     IPY
        JMP     NEXTOP
}
LW      LDA     ESTKL,X
        STA     TMPL
        LDA     ESTKH,X
        STA     TMPH
        STY     IPY
        LDY     #$00
        LDA     (TMP),Y
        STA     ESTKL,X
        INY
        LDA     (TMP),Y
        STA     ESTKH,X
        LDY     IPY
        JMP     NEXTOP
;
!IF SELFMODIFY {
LBX     LDA     ESTKL,X
        STA     LBXLDA+1
        LDA     ESTKH,X
        STA     LBXLDA+2
        STA     ALTRDOFF
LBXLDA  LDA     $FFFF
        STA     ESTKL,X
    LDA #$00
        STA     ESTKH,X
        STA     ALTRDON
        JMP     NEXTOP
} ELSE {
LBX     LDA     ESTKL,X
        STA     TMPL
        LDA     ESTKH,X
        STA     TMPH
        STY     IPY
        STA     ALTRDOFF
        LDY     #$00
        LDA     (TMP),Y
        STA     ESTKL,X
        STY     ESTKH,X
        LDY     IPY
        STA     ALTRDON
        JMP     NEXTOP
}
LWX     LDA     ESTKL,X
        STA     TMPL
        LDA     ESTKH,X
        STA     TMPH
        STY     IPY
        STA     ALTRDOFF
        LDY     #$00
        LDA     (TMP),Y
        STA     ESTKL,X
        INY
        LDA     (TMP),Y
        STA     ESTKH,X
        LDY     IPY
        STA     ALTRDON
        JMP     NEXTOP
;*
;* LOAD ADDRESS OF LOCAL FRAME OFFSET
;*
LLA     +INC_IP
        LDA     (IP),Y
        DEX
        CLC
        ADC     IFPL
        STA     ESTKL,X
        LDA     #$00
        ADC     IFPH
        STA     ESTKH,X
        JMP     NEXTOP
;*
;* LOAD VALUE FROM LOCAL FRAME OFFSET
;*
LLB     +INC_IP
        LDA     (IP),Y
        STY     IPY
        TAY
        DEX
        LDA     (IFP),Y
        STA     ESTKL,X
        LDA     #$00
        STA     ESTKH,X
        LDY     IPY
        JMP     NEXTOP
LLW     +INC_IP
        LDA     (IP),Y
        STY     IPY
        TAY
        DEX
        LDA     (IFP),Y
        STA     ESTKL,X
        INY
        LDA     (IFP),Y
        STA     ESTKH,X
        LDY     IPY
        JMP     NEXTOP
;
LLBX    +INC_IP
        LDA     (IP),Y
        STY     IPY
        TAY
        DEX
        STA     ALTRDOFF
        LDA     (IFP),Y
        STA     ESTKL,X
        LDA     #$00
        STA     ESTKH,X
        STA     ALTRDON
        LDY     IPY
        JMP     NEXTOP
LLWX    +INC_IP
        LDA     (IP),Y
        STY     IPY
        TAY
        DEX
        STA     ALTRDOFF
        LDA     (IFP),Y
        STA     ESTKL,X
        INY
        LDA     (IFP),Y
        STA     ESTKH,X
        STA     ALTRDON
        LDY     IPY
        JMP     NEXTOP
;*
;* LOAD VALUE FROM ABSOLUTE ADDRESS
;*
!IF SELFMODIFY {
LAB     +INC_IP
        LDA     (IP),Y
        STA     LABLDA+1
        +INC_IP
        LDA     (IP),Y
        STA     LABLDA+2
LABLDA  LDA     $FFFF
        DEX
        STA     ESTKL,X
    LDA #$00
        STA     ESTKH,X
        JMP     NEXTOP
} ELSE {
LAB     +INC_IP
        LDA     (IP),Y
        STA     TMPL
        +INC_IP
        LDA     (IP),Y
        STA     TMPH
        STY     IPY
        LDY     #$00
        LDA     (TMP),Y
        DEX
        STA     ESTKL,X
        STY     ESTKH,X
        LDY     IPY
        JMP     NEXTOP
}
LAW     +INC_IP
        LDA     (IP),Y
        STA     TMPL
        +INC_IP
        LDA     (IP),Y
        STA     TMPH
        STY     IPY
        LDY     #$00
        LDA     (TMP),Y
        DEX
        STA     ESTKL,X
        INY
        LDA     (TMP),Y
        STA     ESTKH,X
        LDY     IPY
        JMP     NEXTOP
;
!IF SELFMODIFY {
LABX    +INC_IP
        LDA     (IP),Y
        STA     LABXLDA+1
        +INC_IP
        LDA     (IP),Y
        STA     LABXLDA+2
        STA     ALTRDOFF
LABXLDA LDA     $FFFF
        DEX
        STA     ESTKL,X
    LDA #$00
        STA     ESTKH,X
        STA     ALTRDON
        JMP     NEXTOP
} ELSE {
LABX    +INC_IP
        LDA     (IP),Y
        STA     TMPL
        +INC_IP
        LDA     (IP),Y
        STA     TMPH
        STY     IPY
        STA     ALTRDOFF
        LDY     #$00
        LDA     (TMP),Y
        DEX
        STA     ESTKL,X
        STY     ESTKH,X
        STA     ALTRDON
        LDY     IPY
        JMP     NEXTOP
}
LAWX    +INC_IP
        LDA     (IP),Y
        STA     TMPL
        +INC_IP
        LDA     (IP),Y
        STA     TMPH
        STY     IPY
        STA     ALTRDOFF
        LDY     #$00
        LDA     (TMP),Y
        DEX
        STA     ESTKL,X
        INY
        LDA     (TMP),Y
        STA     ESTKH,X
        STA     ALTRDON
        LDY     IPY
        JMP     NEXTOP
;*
;* STORE VALUE TO ADDRESS
;*
!IF SELFMODIFY {
SB      LDA     ESTKL,X
        STA     SBSTA+1
        LDA     ESTKH,X
        STA     SBSTA+2
        LDA     ESTKL+1,X
SBSTA   STA     $FFFF
        INX
;       INX
;       JMP     NEXTOP
        JMP     DROP
} ELSE {
SB      LDA     ESTKL,X
        STA     TMPL
        LDA     ESTKH,X
        STA     TMPH
        LDA     ESTKL+1,X
        STY     IPY
        LDY     #$00
        STA     (TMP),Y
        LDY     IPY
        INX
;       INX
;       JMP     NEXTOP
        JMP     DROP
}
SW      LDA     ESTKL,X
        STA     TMPL
        LDA     ESTKH,X
        STA     TMPH
        STY     IPY
        LDY     #$00
        LDA     ESTKL+1,X
        STA     (TMP),Y
        INY
        LDA     ESTKH+1,X
        STA     (TMP),Y
        LDY     IPY
        INX
;       INX
;       JMP     NEXTOP
        JMP     DROP
;*
;* STORE VALUE TO LOCAL FRAME OFFSET
;*
SLB     +INC_IP
        LDA     (IP),Y
        STY     IPY
        TAY
        LDA     ESTKL,X
        STA     (IFP),Y
        LDY     IPY
;       INX
;       JMP     NEXTOP
        JMP     DROP
SLW     +INC_IP
        LDA     (IP),Y
        STY     IPY
        TAY
        LDA     ESTKL,X
        STA     (IFP),Y
        INY
        LDA     ESTKH,X
        STA     (IFP),Y
        LDY     IPY
;               INX
;       JMP     NEXTOP
        JMP     DROP
;*
;* STORE VALUE TO LOCAL FRAME OFFSET WITHOUT POPPING STACK
;*
DLB     +INC_IP
        LDA     (IP),Y
        STY     IPY
        TAY
        LDA     ESTKL,X
        STA     (IFP),Y
        LDY     IPY
        JMP     NEXTOP
DLW             +INC_IP
        LDA     (IP),Y
        STY     IPY
        TAY
        LDA     ESTKL,X
        STA     (IFP),Y
        INY
        LDA     ESTKH,X
        STA     (IFP),Y
        LDY     IPY
        JMP     NEXTOP
;*
;* STORE VALUE TO ABSOLUTE ADDRESS
;*
!IF SELFMODIFY {
SAB     +INC_IP
        LDA     (IP),Y
        STA     SABSTA+1
        +INC_IP
        LDA     (IP),Y
        STA     SABSTA+2
        LDA     ESTKL,X
SABSTA  STA     $FFFF
;       INX
;       JMP     NEXTOP
        JMP     DROP
} ELSE {
SAB     +INC_IP
        LDA     (IP),Y
        STA     TMPL
        +INC_IP
        LDA     (IP),Y
        STA     TMPH
        LDA     ESTKL,X
        STY     IPY
        LDY     #$00
        STA     (TMP),Y
        LDY     IPY
;       INX
;       JMP     NEXTOP
        JMP     DROP
}
SAW     +INC_IP
        LDA     (IP),Y
        STA     TMPL
        +INC_IP
        LDA     (IP),Y
        STA     TMPH
        STY     IPY
        LDY     #$00
        LDA     ESTKL,X
        STA     (TMP),Y
        INY
        LDA     ESTKH,X
        STA     (TMP),Y
        LDY     IPY
;       INX
;       JMP     NEXTOP
        JMP     DROP
;*
;* STORE VALUE TO ABSOLUTE ADDRESS WITHOUT POPPING STACK
;*
!IF SELFMODIFY {
DAB     +INC_IP
        LDA     (IP),Y
        STA     DABSTA+1
        +INC_IP
        LDA     (IP),Y
        STA     DABSTA+2
        LDA     ESTKL,X
DABSTA  STA     $FFFF
        JMP     NEXTOP
} ELSE {
DAB     +INC_IP
        LDA     (IP),Y
        STA     TMPL
        +INC_IP
        LDA     (IP),Y
        STA     TMPH
        STY     IPY
        LDY     #$00
        LDA     ESTKL,X
        STA     (TMP),Y
        LDY     IPY
        JMP     NEXTOP
}
DAW     +INC_IP
        LDA     (IP),Y
        STA     TMPL
        +INC_IP
        LDA     (IP),Y
        STA     TMPH
        STY     IPY
        LDY     #$00
        LDA     ESTKL,X
        STA     (TMP),Y
        INY
        LDA     ESTKH,X
        STA     (TMP),Y
        LDY     IPY
        JMP     NEXTOP
;*
;* COMPARES
;*
ISEQ    LDA     ESTKL,X
        CMP     ESTKL+1,X
        BNE     ISFLS
        LDA     ESTKH,X
        CMP     ESTKH+1,X
        BNE     ISFLS
ISTRU   LDA     #$FF
        STA     ESTKL+1,X
        STA     ESTKH+1,X
;       INX
;       JMP     NEXTOP
        JMP     DROP
;
ISNE    LDA     ESTKL,X
        CMP     ESTKL+1,X
        BNE     ISTRU
        LDA     ESTKH,X
        CMP     ESTKH+1,X
        BNE     ISTRU
ISFLS   LDA     #$00
        STA     ESTKL+1,X
        STA     ESTKH+1,X
;       INX
;       JMP     NEXTOP
        JMP     DROP
;
ISGE    LDA     ESTKL+1,X
        CMP     ESTKL,X
        LDA     ESTKH+1,X
        SBC     ESTKH,X
        BVC     ISGE1
        EOR     #$80
ISGE1   BPL     ISTRU
        BMI     ISFLS
;
ISGT    LDA     ESTKL,X
        CMP     ESTKL+1,X
        LDA     ESTKH,X
        SBC     ESTKH+1,X
        BVC     ISGT1
        EOR     #$80
ISGT1   BMI     ISTRU
        BPL     ISFLS
;
ISLE    LDA     ESTKL,X
        CMP     ESTKL+1,X
        LDA     ESTKH,X
        SBC     ESTKH+1,X
        BVC     ISLE1
        EOR     #$80
ISLE1   BPL     ISTRU
        BMI     ISFLS
;
ISLT    LDA     ESTKL+1,X
        CMP     ESTKL,X
        LDA     ESTKH+1,X
        SBC     ESTKH,X
        BVC     ISLT1
        EOR     #$80
ISLT1   BMI     ISTRU
        BPL     ISFLS
;*
;* BRANCHES
;*
BRTRU   INX
        LDA     ESTKH-1,X
        ORA     ESTKL-1,X
        BNE     BRNCH
NOBRNCH +INC_IP
        +INC_IP
        JMP     NEXTOP
BRFLS   INX
        LDA     ESTKH-1,X
        ORA     ESTKL-1,X
        BNE     NOBRNCH
BRNCH   LDA     IPH
        STA     TMPH
        LDA     IPL
        +INC_IP
        CLC
        ADC     (IP),Y
        STA     TMPL
        LDA     TMPH
        +INC_IP
        ADC     (IP),Y
        STA     IPH
        LDA     TMPL
        STA     IPL
        DEY
        DEY
        JMP     NEXTOP
BREQ    INX
        LDA     ESTKL-1,X
        CMP     ESTKL,X
        BNE     NOBRNCH
        LDA     ESTKH-1,X
        CMP     ESTKH,X
        BEQ     BRNCH
        BNE     NOBRNCH
BRNE    INX
        LDA     ESTKL-1,X
        CMP     ESTKL,X
        BNE     BRNCH
        LDA     ESTKH-1,X
        CMP     ESTKH,X
        BEQ     NOBRNCH
        BNE     BRNCH
BRGT    INX
        LDA     ESTKL-1,X
        CMP     ESTKL,X
        LDA     ESTKH-1,X
        SBC     ESTKH,X
        BMI     BRNCH
        BPL     NOBRNCH
BRLT    INX
        LDA     ESTKL,X
        CMP     ESTKL-1,X
        LDA     ESTKH,X
        SBC     ESTKH-1,X
        BMI     BRNCH
        BPL     NOBRNCH
IBRNCH  LDA     IPL
        CLC
        ADC     ESTKL,X
        STA     IPL
        LDA     IPH
        ADC     ESTKH,X
        STA     IPH
;       INX
;       JMP     NEXTOP
        JMP     DROP
;*
;* CALL INTO ABSOLUTE ADDRESS (NATIVE CODE)
;*
CALL    +INC_IP
        LDA     (IP16),Y
        STA     TMP
        +INC_IP
EMUSTK  STY     IPY
        SEC                     ; SWITCH TO EMULATED MODE
        XCE
        !AS
        TSX                     ; COPY HW EVAL STACK TO ZP EVAL STACK
        TXA
        SEC
        SBC     HWSP
        LSR
        LDX     ESP
        TAY
        BEQ     +
-       DEX
        PLA
        STA     ESTKL,X
        PLA
        STA     ESTKH,X
        DEY
        BNE     -
+       LDA     IP16H
        PHA
        LDA     IP16L
        PHA
        LDA     IPY
        PHA
        PHX
        JSR     JMPTMP
        PLY                     ; COPY RETURN VALUES TO HW EVAL STACK
        STY     ESP
        PLY
        PLA
        STA     IP16L
        PLA
        STA     IP16H
        CPX     ESP
        BEQ     +
-       LDA     ESTKH,X
        PHA
        LDA     ESTKL,X
        PHA
        INX
        CPX     ESP
        BNE     -
+       CLC                     ; SWITCH BACK TO NATIVE MODE
        XCE
        REP     #$20            ; 16 BIT A/M
        SEP     #$10            ; 8 BIT X,Y
        !AL
!IF SELFMODIFY {
        LDX     LCRWEN+LCBNK2
        LDX     LCRWEN+LCBNK2
}
        LDX     #>OPTBL         ; MAKE SURE WE'RE INDEXING THE RIGHT TABLE
        STX     OP16PAGE
        JMP     NEXTOP16
;
CALLX   +INC_IP
        LDA     (IP16),Y
        STA     TMP
        +INC_IP
EMUSTKX STY     IPY
        SEC                     ; SWITCH TO EMULATED MODE
        XCE
        !AS
        TSX                     ; COPY HW EVAL STACK TO ZP EVAL STACK
        TXA
        SEC
        SBC     HWSP
        LSR
        LDX     ESP
        TAY
        BEQ     +
-       DEX
        PLA
        STA     ESTKL,X
        PLA
        STA     ESTKH,X
        DEY
        BNE     -
+       LDA     IP16H
        PHA
        LDA     IP16L
        PHA
        LDA     IPY
        PHA
        PHX
        STX     ALTRDOFF
        ;CLI UNTIL I KNOW WHAT TO DO WITH THE UNENHANCED IIE
        JSR     JMPTMP
        ;SEI UNTIL I KNOW WHAT TO DO WITH THE UNENHANCED IIE
        STX     ALTRDON
        PLY                     ; COPY RETURN VALUES TO HW EVAL STACK
        STY     ESP
        PLY
        PLA
        STA     IP16L
        PLA
        STA     IP16H
        CPX     ESP
        BEQ     +
-       LDA     ESTKH,X
        PHA
        LDA     ESTKL,X
        PHA
        INX
        CPX     ESP
        BNE     -
+       CLC                     ; SWITCH BACK TO NATIVE MODE
        XCE
        REP     #$20            ; 16 BIT A/M
        SEP     #$10            ; 8 BIT X,Y
        !AL
!IF SELFMODIFY {
        LDX     LCRWEN+LCBNK2
        LDX     LCRWEN+LCBNK2
}
        LDX     #>OPXTBL         ; MAKE SURE WE'RE INDEXING THE RIGHT TABLE
        STX     OP16PAGE
        JMP     NEXTOP16

;*
;* INDIRECT CALL TO ADDRESS (NATIVE CODE)
;*
ICAL    PLA
        STA     TMP
        JMP     EMUSTK
;
ICALX   PLA
        STA     TMP
        JMP     EMUSTKX
;*
;* JUMP INDIRECT THROUGH TMP
;*
JMPTMP  JMP     (TMP)
;*
;* ENTER FUNCTION WITH FRAME SIZE AND PARAM COUNT
;*
ENTER   INY
        SEP     #$20            ; 8 BIT A/M
        !AS
        LDA     (IP16),Y
        PHA                     ; SAVE ON STACK FOR LEAVE
        REP     #$20            ; 16 BIT A/M
        !AL
        AND     #$00FF
        EOR     #$FFFF          ; ALLOCATE FRAME
        SEC
        ADC     PP
        STA     PP
        STA     IFP
        SEP     #$20            ; 8 BIT A/M
        !AS
        INY
        LDA     (IP16),Y
        ASL
        TAY
        BEQ     +
        LDX     ESP
-       LDA     ESTKH,X
        DEY
        STA     (IFP),Y
        LDA     ESTKL,X
        INX
        DEY
        STA     (IFP),Y
        BNE -
        STX     ESP
+       LDY     #$02
        REP     #$20            ; 16 BIT A/M
        !AL
        JMP     NEXTOP16
;*
;* LEAVE FUNCTION
;*
LEAVEX  STX     ALTRDOFF
        ;CLI UNTIL I KNOW WHAT TO DO WITH THE UNENHANCED IIE
LEAVE   SEP     #$20            ; 8 BIT A/M
        !AS
        TSX                     ; COPY HW EVAL STACK TO ZP EVAL STACK
        TXA
        LDX     ESP
        SEC
        SBC     HWSP
        LSR
        BEQ     +
        TAY
-       DEX
        PLA
        STA     ESTKL,X
        PLA
        STA     ESTKH,X
        DEY
        BNE     -
+       PLA                     ; DEALLOCATE POOL + FRAME
        REP     #$20            ; 16 BIT A/M
        !AL
        AND     #$00FF
        CLC
        ADC     IFP
        STA     PP
        PLA                     ; RESTORE PREVIOUS FRAME
        STA     IFP
        SEC                     ; SWITCH TO EMULATED MODE
        XCE
        RTS
;
RETX    STX     ALTRDOFF
        ;CLI UNTIL I KNOW WHAT TO DO WITH THE UNENHANCED IIE
RET     SEP     #$20            ; 8 BIT A/M
        !AS
        TSX                     ; COPY HW EVAL STACK TO ZP EVAL STACK
        TXA
        LDX     ESP
        SEC
        SBC     HWSP
        LSR
        BEQ     +
        TAY
-       DEX
        PLA
        STA     ESTKL,X
        PLA
        STA     ESTKH,X
        DEY
        BNE     -
+       REP     #$20            ; 16 BIT A/M
        !AL
        LDA     IFP             ; DEALLOCATE POOL
        STA     PP
        PLA                     ; RESTORE PREVIOUS FRAME
        STA     IFP
        SEC                     ; SWITCH TO EMULATED MODE
        XCE
        !AS
        RTS
VMEND   =       *
}