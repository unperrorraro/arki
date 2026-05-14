
 ORG $0

  DC.L $8000
  DC.L $4000



 
 ORG $500

 MR1A: EQU $EFFC01
 MR2A: EQU $EFFC01
 CSRA: EQU $EFFC03
 CRA: EQU $EFFC05
 BUFF_A: EQU $EFFC07
 
 ACR: EQU $EFFC09
 IMR: EQU $EFFC0B

 MR1B: EQU $EFFC11
 MR2B: EQU $EFFC11
 CSRB: EQU $EFFC13
 CRB: EQU $EFFC15
 BUFF_B: EQU $EFFC17

 IVR: EQU $EFFC19

 ORG $1000
 RTI:
 MOVE.B #$00,IMR
 MOVEM.L D0/A0,-(A7)

 LEA COUNT,A0
 MOVE.B D0,(A0) 

 LEA BUFFER,A1
 MOVE.B 


 ADD.B #$01,D5
 LEA BUFF_A,A0
 MOVE.B (A0),D0
 LEA BUFF_B,A0
 MOVE.B (A0),D0
 MOVE.B BUFF_B,D0 
 MOVEM.L (A7)+,D0/A0
 MOVE.B #$22,IMR
 RTE



 ORG $2000

 COUNT: DS.B 1
 BUFFER: DS.B 100 


 ORG $3000

INIT: 

 * Reg MR1X 0(0)0000(11) = $03 (RxRGY & 8bits)
 * Reg MR2X (00)0000(0) = $0 (Modo normal)
 * Reg ACR (0)000000 = $0 (Conjunto 1 de velocidades) 
 * Reg CSRX (1100)(1100) = $CC ( velocidades de transmision y recepcion)
 * Reg CRX (0001)(01)(01) = $15 (Habilitar transmision y recepcion)
 * Reg IVR  $40 (Dado por el enunciado)
 * Reg IMR  00(1)(0)00(1)(0) = $22 (habilitar E/S)

 BSR.L INI_BUFS

 MOVE.B #$10,CRA
 MOVE.B #$10,CRB *Activamos MR1 pero no ponemos las interrupciones aun

 MOVE.B #$03,MR1A
 MOVE.B #$03,MR1B
 MOVE.B #$00,MR2A
 MOVE.B #$00,MR2B


 MOVE.B #$CC,CSRA
 MOVE.B #$CC,CSRB


 MOVE.B #$40,IVR
 MOVE.B #$22,IMR
 MOVE.B #$00,ACR

 MOVE.L #RTI,$100

 MOVE.B #$15,CRA
 MOVE.B #$15,CRB *Activamos MR1  y las interrupciones


 RTS


 ORG $4000

 JSR INIT
 MOVE.B #$00,COUNT
 MOVE.W #$2000,SR
 EOR.L D0,D0
 EOR.L D1,D1
 ADD.B #$34,D1
 * JSR ESCCAR
 EOR.L D0,D0
 BUC:ADD.B #$0,D0
 ADD.W #$10,D2
 * JSR LEECAR
 BRA BUC


INCLUDE bib_aux.s

