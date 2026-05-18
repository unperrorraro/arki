
* Tabla de vectores (direcciones 0x000000 - 0x0003FF)

        ORG     $0

* Vector 0: Puntero de pila inicial de supervisor (SSP)
* La RAM del simulador es de 32KB desde 0x000000 hasta 0x007FFF
* La pila se coloca al final de la RAM, crece hacia abajo
        DC.L    $007FFE

* Vector 1: PC inicial tras reset (comienzo del programa)
        DC.L    START

* Vectores para excepciones (para depuración)
        DC.L    BUS_ERROR       * Vector 2 - Bus error (dirección 8)
        DC.L    ADDR_ERROR      * Vector 3 - Address error (dirección 12)
        DC.L    ILLEG_IN        * Vector 4 - Illegal instruction (dirección 16)
        DC.L    ILLEG_IN        * Vector 5 - Divide by zero (dirección 20)
        DC.L    ILLEG_IN        * Vector 6 - CHK instruction (dirección 24)
        DC.L    ILLEG_IN        * Vector 7 - TRAPV instruction (dirección 28)
        DC.L    PRIV_VIO        * Vector 8 - Privilege violation (dirección 32)
        DC.L    ILLEG_IN        * Vector 9 - Trace (dirección 36)
        DC.L    ILLEG_IN        * Vector 10 - Line 1010 emulator (40)
        DC.L    ILLEG_IN        * Vector 11 - Line 1111 emulator (44)
        DS.L    20              * Reservar espacio para el resto (hasta 0x3FF)

* Vector 64 (0x40 en hex, dirección 0x100) para la DUART
        ORG     $100
        DC.L    RTI             * Rutina de tratamiento de interrupción


* 2. Constantes y Equivalencias 

* Registros DUART - Línea A
MR1A    EQU     $EFFC01         * Registro de modo 1 (escritura)
MR2A    EQU     $EFFC01         * Registro de modo 2 (escritura - mismo puerto)
CSRA    EQU     $EFFC03         * Registro selección reloj (escritura)
SRA     EQU     $EFFC03         * Registro de estado (lectura)
CRA     EQU     $EFFC05         * Registro de control (escritura)
RBA     EQU     $EFFC07         * Buffer recepción (lectura)
TBA     EQU     $EFFC07         * Buffer transmisión (escritura)

* Registros DUART - Línea B
MR1B    EQU     $EFFC11         * Registro de modo 1 (escritura)
MR2B    EQU     $EFFC11         * Registro de modo 2 (escritura - mismo puerto)
CSRB    EQU     $EFFC13         * Registro selección reloj (escritura)
SRB     EQU     $EFFC13         * Registro de estado (lectura)
CRB     EQU     $EFFC15         * Registro de control (escritura)
RBB     EQU     $EFFC17         * Buffer recepción (lectura)
TBB     EQU     $EFFC17         * Buffer transmisión (escritura)

* Registros DUART - Comunes
ACR     EQU     $EFFC09         * Registro de control auxiliar
ISR     EQU     $EFFC0B         * Registro estado interrupción (lectura)
IMR     EQU     $EFFC0B         * Registro máscara interrupción (escritura)
IVR     EQU     $EFFC19         * Registro vector interrupción

* Constantes del programa principal
DESA    EQU     0               * Descriptor línea A (lectura)
DESB    EQU     1               * Descriptor línea B (lectura)
TAMBS   EQU     30              * Tamaño de bloque para SCAN
TAMBP   EQU     7               * Tamaño de bloque para PRINT

* Máscaras para bits de interrupción
RXR_A   EQU     %00000001       * Bit 0: RxRDY/FFULL línea A
TXR_A   EQU     %00000010       * Bit 1: TxRDY línea A
RXR_B   EQU     %00010000       * Bit 4: RxRDY/FFULL línea B
TXR_B   EQU     %00100000       * Bit 5: TxRDY línea B


* Variables globales 


        ORG     $600

IMR_COPY:   DC.B    0           * Copia de IMR (porque no se puede leer)
            DS.B    1           * Alineamiento a palabra


* Código principal 


        ORG     $400

START:
        * Instalar manejadores de excepciones
        MOVE.L  #BUS_ERROR, $8
        MOVE.L  #ADDR_ERROR, $C
        MOVE.L  #ILLEG_IN, $10
        MOVE.L  #PRIV_VIO, $20
        MOVE.L  #ILLEG_IN, $28
        MOVE.L  #ILLEG_IN, $2C

        * Inicializar sistema
        BSR     INIT

        * Habilitar interrupciones (bit 8 del SR = 1, máscara nivel 0)
        MOVE.W  #$2000, SR

        * Ir al bucle principal
        BRA     MAIN


* Manejadores de excepción (solo para depuración)


BUS_ERROR:  BREAK
            NOP

ADDR_ERROR: BREAK
            NOP

ILLEG_IN:   BREAK
            NOP

PRIV_VIO:   BREAK
            NOP


* Inicialización (INIT) 
* Configura la DUART y los buffers internos 
 
INIT:
        * Inicializar buffers internos de las rutinas auxiliares
        BSR     INI_BUFS

        * Actualizar tabla de vectores con dirección de RTI
        * Vector 64 (0x40) → dirección 0x100 = 64 * 4
        MOVE.L  #RTI, $100

        * Configurar ACR: Conjunto 1 de velocidades (bit 7 = 0)
        * Necesario para 38400 baudios
        MOVE.B  #%00000000, ACR

        * Línea A*
        * Reiniciar puntero a MR1A
        MOVE.B  #%00000001, CRA

        * Configurar MR1A: 8 bits por carácter, interrupción por RxRDY
        * Bits 1-0 = 11 (8 bits), Bit 6 = 0 (RxRDY, no FFULL)
        MOVE.B  #%00000011, MR1A

        * Configurar MR2A: Modo normal (sin eco)
        MOVE.B  #%00000000, MR1A

        * Configurar velocidad: 38400 bps (recepción=0001, transmisión=0001)
        MOVE.B  #%00010001, CSRA

        * Habilitar transmisión y recepción
        *    Bits 3-2 = 01 (Tx enable), Bits 1-0 = 01 (Rx enable)
        MOVE.B  #%00000101, CRA

        * Línea B*
        * Reiniciar puntero a MR1B
        MOVE.B  #%00000001, CRB

        * Configurar MR1B: 8 bits por carácter, interrupción por RxRDY
        MOVE.B  #%00000011, MR1B

        * Configurar MR2B: Modo normal (sin eco)
        MOVE.B  #%00000000, MR1B

        * Configurar velocidad: 38400 bps
        MOVE.B  #%00010001, CSRB

        * Habilitar transmisión y recepción
        MOVE.B  #%00000101, CRB


        * Establecer vector de interrupción a 0x40
        MOVE.B  #$40, IVR

        * Configurar IMR: solo interrupciones de recepción activas al inicio
        * Las interrupciones de transmisión se activarán dinámicamente
        MOVE.B  #RXR_A|RXR_B, IMR
        MOVE.B  #RXR_A|RXR_B, IMR_COPY

        RTS


* SCAN - Lectura de dispositivo
* Parámetros en pila (desde 8(A6) hacia arriba):
*   8(A6)  = Buffer destino (dirección, 4 bytes)
*   12(A6) = Descriptor línea (2 bytes): 0 = A, 1 = B
*   14(A6) = Tamaño máximo a leer (2 bytes)
* Retorno: D0 = número de caracteres leídos, o -1 si error


SCAN:
        LINK    A6, #0              * Crear marco de pila
        MOVEM.L D1-D3/A0, -(A7)    * Salvar registros

        * Cargar parámetros
        EOR.L D0,D0
        * 0(A6) es la dir retorno
        MOVE.L  4(A6),  A0          * A0 = buffer destino
        MOVE.W  8(A6), D0          * D0 = descriptor (0=A, 1=B)
        MOVE.W  10(A6), D2          * D2 = tamaño máximo

        * Validar descriptor (solo 0 o 1 son válidos)
          CMP.W   #1, D0
        BHI     SCAN_ERROR
        * Validar tamaño (si es 0, no hay nada que leer)
        CMP.W   #0, D2
        BEQ     SCAN_CERO
        * Inicializar contador de caracteres leídos
        CLR.L   D3

SCAN_LOOP:
        * ¿Ya leímos el máximo?
        CMP.W   D3, D2
        BEQ     SCAN_FIN
        EOR.L D0,D0
        MOVE.W  8(A6), D0          * D0 = descriptor (0=A, 1=B)

        BSR     LEECAR
        * Si LEECAR devuelve -1, buffer vacío → terminar
        CMP.L   #$FFFFFFFF, D0
        BEQ     SCAN_FIN

        * Copiar carácter al buffer destino y avanzar puntero
        MOVE.B  D0, (A0)+
        ADDQ.W  #1, D3
        BRA     SCAN_LOOP

SCAN_CERO:
        * Tamaño = 0: devolver 0 caracteres leídos
        CLR.L   D0
        BRA     SCAN_RET

SCAN_FIN:
        * Devolver número de caracteres leídos
        MOVE.L  D3, D0
        BRA     SCAN_RET

SCAN_ERROR:
        * Parámetro inválido: devolver -1
        MOVE.L  #$FFFFFFFF, D0

SCAN_RET:
        MOVEM.L (A7)+, D1-D3/A0    * Restaurar registros
        UNLK    A6                  * Destruir marco de pila
        RTS


* Print - Escritura en dispositivo
* Parámetros en pila (desde 8(A6) hacia arriba):
*   8(A6)  = Buffer fuente (dirección, 4 bytes)
*   12(A6) = Descriptor línea (2 bytes): 0 = A, 1 = B
*   14(A6) = Tamaño a escribir (2 bytes)
* Retorno: D0 = número de caracteres aceptados, o -1 si error


PRINT:
        LINK    A6, #0              * Crear marco de pila
        MOVEM.L D1-D5/A0-A1, -(A7) * Salvar registros

        * Cargar parámetros
        EOR.L D0,D0
        MOVE.W  8(A6), D0          * D0 = descriptor (0=A, 1=B)
        MOVE.W  10(A6), D2          * D2 = tamaño
        MOVE.L  4(A6),  A0          * A0 = buffer fuente

        * Validar descriptor (solo 0 o 1 son válidos)
        CMP.W   #1, D0
        BHI     PRINT_ERROR

        * Validar tamaño (si es 0, no hay nada que escribir)
        CMP.W   #0, D2
        BEQ     PRINT_CERO

        * Inicializar contador
        CLR.L   D3
        MOVE.L  A0, A1              * A1 = puntero fuente (avanza)

PRINT_LOOP:
        * ¿Ya escribimos todo?
        CMP.W   D3, D2
        BEQ     PRINT_FIN

    
        * Obtener carácter del buffer fuente
        MOVE.B  (A1)+, D1

        * Calcular descriptor para ESCCAR (transmisión)
        * Descriptor original 0 → 2 (PRNT_A)
        * Descriptor original 1 → 3 (PRNT_B)
        EOR.L D0,D0
        MOVE.W  8(A6), D0          * D0 = descriptor (0=A, 1=B)
        ADDQ.W  #2, D0

        * Insertar carácter en buffer interno
        BSR     ESCCAR

       
        * Si ESCCAR devuelve -1, buffer lleno → terminar
        CMP.L   #$FFFFFFFF, D0
        BEQ     PRINT_FIN

        * Incrementar contador
        ADDQ.W  #1, D3
        BRA     PRINT_LOOP

PRINT_FIN:
        * ¿Se insertó algún carácter?
        TST.L   D3
        BEQ     PRINT_RET_OK

  

        * Activar TxRDY según la línea
        EOR.L D0,D0
        MOVE.W  8(A6), D0
        CMP.W   #0, D0
        BEQ     PRINT_ACT_A
        * Línea B: activar bit 5 (TXR_B)
        OR.B   #$10,IMR_2
        BRA     PRINT_ACT_OK
PRINT_ACT_A:
        * Línea A: activar bit 1 (TXR_A)
        
        OR.B   #$01,IMR_2

PRINT_ACT_OK:
        * Actualizar IMR y su copia
       
        MOVE.B IMR_2,IMR


PRINT_RET_OK:
        MOVE.L  D3, D0              * Devolver caracteres aceptados
        BRA     PRINT_RET

PRINT_CERO:
        CLR.L   D0                  * Devolver 0
        BRA     PRINT_RET

PRINT_ERROR:
        MOVE.L  #$FFFFFFFF, D0      * Devolver -1 (error)

PRINT_RET:
        MOVEM.L (A7)+, D1-D5/A0-A1
        UNLK    A6
        RTS


* RTI - Rutina de Tratamiento de Interrupción
* Atiende interrupciones de la DUART:
*   - Recepción: lee carácter del hardware y lo guarda en buffer
*   - Transmisión: saca carácter del buffer y lo envía


RTI:
        * Salvar registros que vamos a modificar
        MOVEM.L D0-D2/A0, -(A7)

        * Leer fuentes de interrupción activas (ISR)
        MOVE.B  ISR, D2

        * ========== TRANSMISIÓN LÍNEA A (bit 1) ==========
        BTST    #1, D2
        BEQ     RTI_CHECK_RXA

        MOVE.L  #2, D0              * Descriptor: PRNT_A
        BSR     LEECAR

        CMP.L   #$FFFFFFFF, D0
        BEQ     RTI_TXA_VACIO

        * Hay carácter: enviarlo
        MOVE.B  D0, TBA
        BRA     RTI_CHECK_RXA

RTI_TXA_VACIO:
        * Buffer vacío: deshabilitar TxRDY A
        MOVE.B  IMR_COPY, D0
        ANDI.B  #~TXR_A, D0         * Bit 1 a 0
        MOVE.B  D0, IMR
        MOVE.B  D0, IMR_COPY

        * ========== RECEPCIÓN LÍNEA A (bit 0) ==========
RTI_CHECK_RXA:
        BTST    #0, D2
        BEQ     RTI_CHECK_TXB

        * Leer carácter del hardware (RBA)
        MOVE.B  RBA, D1

        * Intentar guardar en buffer interno RX A
        MOVE.L  #0, D0              * Descriptor: SCAN_A
        BSR     ESCCAR

        * Si buffer lleno (D0 = -1), el carácter se pierde (no hacemos nada)
        * (ESCCAR ya leyó el carácter del buffer FIFO, la interrupción se desactiva)

        * ========== TRANSMISIÓN LÍNEA B (bit 5) ==========
RTI_CHECK_TXB:
        BTST    #5, D2
        BEQ     RTI_CHECK_RXB

        MOVE.L  #3, D0              * Descriptor: PRNT_B
        BSR     LEECAR

        CMP.L   #$FFFFFFFF, D0
        BEQ     RTI_TXB_VACIO

        MOVE.B  D0, TBB
        BRA     RTI_CHECK_RXB

RTI_TXB_VACIO:
        * Buffer vacío: deshabilitar TxRDY B
        MOVE.B  IMR_COPY, D0
        ANDI.B  #~TXR_B, D0         * Bit 5 a 0
        MOVE.B  D0, IMR
        MOVE.B  D0, IMR_COPY

        * ========== RECEPCIÓN LÍNEA B (bit 4) ==========
RTI_CHECK_RXB:
        BTST    #4, D2
        BEQ     RTI_FIN

        MOVE.B  RBB, D1
        MOVE.L  #1, D0              * Descriptor: SCAN_B
        BSR     ESCCAR

RTI_FIN:
        * Restaurar registros y salir
        MOVEM.L (A7)+, D0-D2/A0
        RTE                         * Retorno de excepción (NO RTS)

* Bucle que lee de línea A y escribe en línea B


        ORG     $4000

BUFFER: DS.B    2100                * Buffer para almacenar caracteres
PARDIR: DC.L    0                   * Dirección que se pasa como parámetro
PARTAM: DC.W    0                   * Tamaño que se pasa como parámetro
CONTC:  DC.W    0                   * Contador de caracteres a imprimir

MAIN:
        * Bucle de lectura
BUCPR:
        MOVE.W  #TAMBS, PARTAM
        MOVE.L  #BUFFER, PARDIR

OTRAL:
        * Llamar a SCAN para leer de línea A
        MOVE.W  PARTAM,     -(A7)   * Tamaño
        MOVE.W  #DESA,      -(A7)   * Puerto A
        MOVE.L  PARDIR,     -(A7)   * Dirección de lectura
        BSR     SCAN
        ADD.L   #8, A7              * Restablecer pila

        * Actualizar puntero y tamaño restante
        ADD.L   D0, PARDIR
        SUB.W   D0, PARTAM
        BNE     OTRAL               * Seguir si no se leyó todo

        * Bucle de escritura
        MOVE.W  #TAMBS, CONTC
        MOVE.L  #BUFFER, PARDIR

OTRAE:
        MOVE.W  #TAMBP, PARTAM

ESPE:
        * Llamar a PRINT para escribir en línea B
        MOVE.W  PARTAM,     -(A7)   * Tamaño
        MOVE.W  #DESB,      -(A7)   * Puerto B
        MOVE.L  PARDIR,     -(A7)   * Dirección de escritura
        BSR     PRINT
        ADD.L   #8, A7              * Restablecer pila

        * Actualizar puntero, contador y tamaño
        ADD.L   D0, PARDIR
        SUB.W   D0, CONTC
        BEQ     BUCPR               * Volver a leer si no quedan caracteres

        SUB.W   D0, PARTAM
        BNE     ESPE                * Seguir si no se escribió todo

        * Si quedan pocos caracteres, ajustar tamaño del último bloque
        CMP.W   #TAMBP, CONTC
        BHI     OTRAE               * Siguiente bloque completo

        MOVE.W  CONTC, PARTAM
        BRA     ESPE                * Escribir bloque restante


* Incluir rutinas auxiliares


        INCLUDE bib_aux.s

        
