
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

 BRA.L FIN_RTI

IN_TA:

 MOVE.B #$02,D0
 JSR LEECAR
 CMP.L #$FFFFFFFF,D0
 BNE HIT_IN_TA
 AND.B #$FE,IMR_2
 BRA.L FIN_RTI


 HIT_IN_TA:
 MOVE.B D0,BUFF_A

 BRA.L RTI_1


IN_TB:

 MOVE.L #$03,D0
 JSR LEECAR
 CMP.L #$FFFFFFFF,D0
 BNE HIT_TB
 AND.B #$EF,IMR_2
 BRA.L RTI_5






HIT_TB:



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


* SCAN - Lectura de dispositivo
* Parámetros en pila (desde 8(A6) hacia arriba):
*   8(A6)  = Buffer destino (dirección, 4 bytes)
*   12(A6) = Descriptor línea (2 bytes): 0 = A, 1 = B
*   14(A6) = Tamaño máximo a leer (2 bytes)
* Retorno: D0 = número de caracteres leídos, o -1 si error


SCAN:
        LINK    A6,#0              * Crear marco de pila
        MOVEM.L D1-D3/A0,-(A7)    * Salvar registros

        * Cargar parámetros
        EOR.L D0,D0
        * 0(A6) es la dir retorno
        MOVE.L  8(A6),A0          * A0 = buffer destino
        MOVE.W  12(A6),D0          * D0 = descriptor (0=A, 1=B)
        MOVE.W  14(A6),D2          * D2 = tamaño máximo

        * Validar descriptor (solo 0 o 1 son válidos)
          CMP.W   #1,D0
        BHI     SCAN_ERROR
        * Validar tamaño (si es 0, no hay nada que leer)
        CMP.W   #0,D2
        BEQ     SCAN_CERO
        * Inicializar contador de caracteres leídos
        CLR.L   D3

SCAN_LOOP:
        * ¿Ya leímos el máximo?
        CMP.W   D3,D2
        BEQ     SCAN_FIN
        EOR.L D0,D0
        MOVE.W  12(A6),D0          * D0 = descriptor (0=A, 1=B)

        BSR     LEECAR
        * Si LEECAR devuelve -1, buffer vacío → terminar
        CMP.L   #$FFFFFFFF,D0
        BEQ     SCAN_FIN

        * Copiar carácter al buffer destino y avanzar puntero
        MOVE.B  D0,(A0)+
        ADDQ.W  #1,D3
        BRA     SCAN_LOOP

SCAN_CERO:
        * Tamaño = 0: devolver 0 caracteres leídos
        CLR.L   D0
        BRA     SCAN_RET

SCAN_FIN:
        * Devolver número de caracteres leídos
        MOVE.L  D3,D0
        BRA     SCAN_RET

SCAN_ERROR:
        * Parámetro inválido: devolver -1
        MOVE.L  #$FFFFFFFF,D0

SCAN_RET:
        MOVEM.L (A7)+,D1-D3/A0    * Restaurar registros
        UNLK    A6                  * Destruir marco de pila
        RTS


* Print - Escritura en dispositivo
* Parámetros en pila (desde 8(A6) hacia arriba):
*   4(A6)  = Buffer fuente (dirección, 4 bytes)
*   8(A6) = Descriptor línea (2 bytes): 0 = A, 1 = B
*   10(A6) = Tamaño a escribir (2 bytes)
* Retorno: D0 = número de caracteres aceptados, o -1 si error


PRINT:
        LINK    A6,#0              * Crear marco de pila
        MOVEM.L D1-D5/A0-A1,-(A7) * Salvar registros

        * Cargar parámetros
        EOR.L D0,D0
        MOVE.W  12(A6),D0          * D0 = descriptor (0=A, 1=B)
        MOVE.W  14(A6),D2          * D2 = tamaño
        MOVE.L  8(A6),A0          * A0 = buffer fuente

        * Validar descriptor (solo 0 o 1 son válidos)
        CMP.W   #1,D0
        BHI     PRINT_ERROR

        * Validar tamaño (si es 0, no hay nada que escribir)
        CMP.W   #0,D2
        BEQ     PRINT_CERO

        * Inicializar contador
        CLR.L   D3
        MOVE.L  A0,A1              * A1 = puntero fuente (avanza)

PRINT_LOOP:
        * ¿Ya escribimos todo?
        CMP.W   D3,D2
        BEQ     PRINT_FIN

    
        * Obtener carácter del buffer fuente
        MOVE.B  (A1)+,D1

        * Calcular descriptor para ESCCAR (transmisión)
        * Descriptor original 0 → 2 (PRNT_A)
        * Descriptor original 1 → 3 (PRNT_B)
        EOR.L D0,D0
        MOVE.W  12(A6),D0          * D0 = descriptor (0=A, 1=B)
        ADDQ.W  #2,D0

        * Insertar carácter en buffer interno
        BSR     ESCCAR

       
        * Si ESCCAR devuelve -1, buffer lleno → terminar
        CMP.L   #$FFFFFFFF,D0
        BEQ     PRINT_FIN

        * Incrementar contador
        ADDQ.W  #1,D3
        BRA     PRINT_LOOP

PRINT_FIN:
        * ¿Se insertó algún carácter?
        TST.L   D3
        BEQ     PRINT_RET_OK

  

        * Activar TxRDY según la línea
        EOR.L D0,D0
        MOVE.W  12(A6),D0
        CMP.W   #0,D0
        BEQ     PRINT_ACT_A
        * Línea B: activar bit 5 (TXR_B)
        OR.B   #$10,IMR_2
        BRA     PRNT_ACT_K
PRINT_ACT_A:
        * Línea A: activar bit 1 (TXR_A)
        
        OR.B   #$01,IMR_2

PRNT_ACT_K:
        * Actualizar IMR y su copia
       
        MOVE.B IMR_2,IMR


PRINT_RET_OK:
        MOVE.L  D3,D0              * Devolver caracteres aceptados
        BRA     PRINT_DEVUELVE

PRINT_CERO:
        CLR.L   D0                  * Devolver 0
        BRA     PRINT_DEVUELVE

PRINT_ERROR:
        MOVE.L  #$FFFFFFFF,D0      * Devolver -1 (error)

PRINT_DEVUELVE:
        MOVEM.L (A7)+,D1-D5/A0-A1
        UNLK    A6
        RTS





* ORG $4000

* JSR INIT
* MOVE.W #$2000,SR
* EOR.L D0,D0
* EOR.L D1,D1
* ADD.B #$34,D1
* EOR.L D0,D0
* BUC:ADD.B #$0,D0
* ADD.W #$10,D2
* BRA BUC




TEXTO DC.B '1234567890123456789012345678901234567890123456789012345678901234567890123456789012345678901234567890'


TESTPRINT: 
       MOVE.L #$8000,A7
       MOVE.W #$0,-(A7)
       MOVE.W #0,-(A7)
       MOVE.L #TEXTO,-(A7)
       BSR PRINT
       BREAK
       MOVE.W #$0064,-(A7)
       MOVE.W #1,-(A7)
       MOVE.L #TEXTO,-(A7)
       BSR PRINT
       BREAK
       MOVE.W #$0064,-(A7)
       MOVE.W #1,-(A7)
       MOVE.L #TEXTO,-(A7)
       BSR PRINT
       BREAK


 ORG $4000

* Manejadores de excepciones
 MOVE.L #BUS_ERROR,8
 MOVE.L #ADDRESS_ER,12
 MOVE.L #ILLEGAL_IN,16
 MOVE.L #PRIV_VIOLT,32
 MOVE.L #ILLEGAL_IN,40
 MOVE.L #ILLEGAL_IN,44

 JSR INIT
 MOVE.W #$2000,SR        * Habilitar interrupciones

BUCPR:
 MOVE.W #TAMBS,PARTAM
 MOVE.L #BUFFER,PARDIR

* Bucle de lectura: leer TAMBS caracteres de linea A
OTRAL:
 MOVE.W PARTAM,-(A7)     * Tamaño
 MOVE.W #DESB,-(A7)      * Descriptor linea A
 MOVE.L PARDIR,-(A7)     * Direccion buffer
 BSR SCAN
 ADD.L #8,A7
 ADD.L D0,PARDIR         * Avanzar puntero
 SUB.W D0,PARTAM         * Restar caracteres leidos
 BNE OTRAL               * Si no hemos leido todos, seguir

* Bucle de escritura: escribir en linea B en bloques de TAMBP
 MOVE.W #TAMBS,CONTC
 MOVE.L #BUFFER,PARDIR

OTRAE:
 MOVE.W #TAMBP,PARTAM

ESPE:
 MOVE.W PARTAM,-(A7)     * Tamaño
 MOVE.W #DESA,-(A7)      * Descriptor linea B
 MOVE.L PARDIR,-(A7)     * Direccion buffer
 BSR PRINT
 ADD.L #8,A7
 ADD.L D0,PARDIR         * Avanzar puntero
 SUB.W D0,CONTC          * Restar caracteres escritos
 BEQ BUCPR               * Si no quedan, volver al principio
 SUB.W D0,PARTAM         * Actualizar tamaño de bloque
 BNE ESPE                * Si no se escribio todo el bloque, insistir
 CMP.W #TAMBP,CONTC      * ¿Quedan menos de TAMBP caracteres?
 BHI OTRAE               * Si quedan mas, siguiente bloque
 MOVE.W CONTC,PARTAM     * Si quedan menos, ajustar tamaño
 BRA ESPE

* Manejadores
BUS_ERROR:  BREAK
 NOP
ADDRESS_ER: BREAK
 NOP
ILLEGAL_IN: BREAK
 NOP
PRIV_VIOLT: BREAK
 NOP

* Constantes
DESA:   EQU 0
DESB:   EQU 1
TAMBS:  EQU 1
TAMBP:  EQU 1

* Variables
BUFFER:  DS.B 2100
PARDIR:  DC.L 0
PARTAM:  DC.W 0
CONTC:   DC.W 0
INCLUDE bib_aux.s

