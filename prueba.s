
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
 ISR: EQU $EFFC0B

 MR1B: EQU $EFFC11
 MR2B: EQU $EFFC11
 CSRB: EQU $EFFC13
 CRB: EQU $EFFC15
 BUFF_B: EQU $EFFC17

 IVR: EQU $EFFC19

 IMR_2: DC.B 0

 ORG $1000
 RTI:
 MOVE.B #$00,IMR
 MOVEM.L D0-D2/A2,-(A7)
 MOVEM.L D6,-(A7)
 ADD.B #$01,D3
 MOVE.B ISR,D6
 AND.B IMR_2,D6



 BTST #0,D6           
 BNE.L IN_TA  
RTI_1: BTST #1,D6           
 BNE.L IN_RA         
RTI_4: BTST #4,D6           
 BNE.L IN_TB 
RTI_5: BTST #5,D6  
 BNE.L  IN_RB  
 BRA.L FIN_RTI


IN_RA:

 MOVE.B #$00,D0
 MOVE.B BUFF_A,D1
 JSR ESCCAR
 ADD.B #$01,D4

 BRA.L RTI_4


IN_RB:

 MOVE.B #$01,D0
 MOVE.B BUFF_B,D1
 JSR ESCCAR
 ADD.B #$01,D5

 BRA.L FIN_RTI

IN_TA:

 MOVE.B #$02,D0
 JSR LEECAR
 CMP.L #$FFFFFFFF,D0
 BNE HIT_IN_TA
 AND.B #$FE,IMR_2
 BRA.L FIN_RTI


 HIT_IN_TA:
 ADD.B #$01,D4
 MOVE.B D0,BUFF_A

 BRA.L RTI_1


IN_TB:

 MOVE #$03,D0
 JSR LEECAR
 CMP.L #$FFFFFFFF,D0
 BNE HIT_TB
 AND.B #$EF,IMR_2
 BRA.L RTI_5






HIT_TB:
 ADD.B #$01,D5



 MOVE.B D0,BUFF_B

 BRA.L FIN_RTI



 







 FIN_RTI: MOVEM.L (A7)+,D6
 MOVEM.L (A7)+,D0-D2/A2
 MOVE.B IMR_2,IMR
 RTE

  


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
 MOVE.B #$33,IMR
 MOVE.B #$33,IMR_2
 MOVE.B #$00,ACR

 MOVE.L #RTI,$100

 MOVE.B #$15,CRA
 MOVE.B #$15,CRB *Activamos MR1  y las interrupciones


 RTS


 ORG $4000

 JSR INIT
 MOVE.W #$2000,SR
 EOR.L D0,D0
 EOR.L D1,D1
 ADD.B #$34,D1
 EOR.L D0,D0
 BUC:ADD.B #$0,D0
 ADD.W #$10,D2
 BRA BUC

INCLUDE bib_aux.s

