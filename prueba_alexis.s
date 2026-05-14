*
*Proyecto Arquitectura de computadores
*2024/2025
*
*Autors:
*   Roberto César Burgos Malgor     TODO: #8 DNI y Nº de matricula
*   Alexis André García Martínez    DNI:26963695J   Nº de matrícula:230053
*

*IMPORTANTE: Ubicar código y variables entre 0x0000400 hasta la 0x00007FFF
*Pila en posiciones de memoria ALTAS
*
 DC.L $8000 *Se lee el contenido de los primeros 4 bytes y se llevan al SSP
 DC.L INICIO *Se lee el contenido de los siguientes 4 B  y se llevan al PC

 *MAL!!!!!!!!!!
 *ORG $100 *En esta dirección está la RTI TODO: #9 Preguntar si al llamar a RTI el procesador ya guarda PC Y RE y activa bit S por sí sólo
              *No es correcto dejar esto así, se hace desde INIT.
              *BSR RTI
              *RTE
*FIN MAL!!!!!!!
 
 ORG $400
 
*-----------------------------------Aquí empiezan etiquetas para trabajar más claramente con la DUART-----------------------------------*

*----Línea A----*

MR1A EQU $effc01 *De modo A (primer acceso) A través de este registro se le ordena a la DUART el número de bits por caracter de la 
            *línea correspondiente y cuando ha de solicitar una interrupción en recepción.
MR2A EQU $effc01 *De modo A (posteriores accesos, tanto lectura como escritura) Modo de operación (Normal o Eco) 
SRA EQU $effc03 *(En lectura) Registro de estado, consultar manual.
CSRA EQU $effc03 *(En escritura)
CRA EQU $effc05 *(Sólo escritura)
RBA EQU $effc07 *(En lectura)
TBA EQU $effc07 *(En escritura)

*----Línea B----*

MR1B EQU $effc11 *(En lectura y escritura)
MR2B EQU $effc11 *(En lectura y escritura)
SRB EQU $effc13 *(En lectura)
CSRB EQU $effc13 *(En escritura)
CRB EQU $effc15 *(En escritura)
RBB EQU $effc17 *(En lectura)
TBB EQU $effc17 *(En escritura)

*----Ambas líneas----*

ACR EQU $effc08 *(En escritura)
ISR EQU $effc0b *(En lectura)
IMR EQU $effc0b *(En escritura)
IVR EQU $effc19 *(En lectura y escritura)

*---------------------------------------------------------------------------------------------------------------------------------------*
IMR_CPY: DC.B 0
 NO_ADRR_ERR: DC.L 0

       

INIT: 
       MOVE.B #%00010000,CRA  *Reiniciamos puntero para que acceda a MR1A
       MOVE.B #%00010000,CRB  *y MR1B 
       MOVE.B #%00000011,MR1A *Línea A 8 bits por caracter, RxRDY
       MOVE.B #$0,MR2A        *Modo Normal en A
       MOVE.B #%00000011,MR1B *Línea B 8 bits por caracter, RxRDY
       MOVE.B #$0,MR2B         *Modo normal en B
       MOVE.B #$0,ACR         *Seleccionamos conjunto 1 para velocidad de recepción/transmición
       MOVE.B #%11001100,CSRA *Velocidades de recepción/transmición=38400 para A
       MOVE.B #%11001100,CSRB *Velocidades de recepción/transmición=38400 para B
       MOVE.B #%00010101,CRA  *Full Duplex, habilitadas R/T en A
       MOVE.B #%00010101,CRB  *Full Duplex, habilitadas R/T en B
       MOVE.B #$40,IVR       *Vector de interupción a 0x40
                        *La rutina de tratamiento de interrupción deberá estar a partir de dir(0x40*4)
       *IMPORTANTE, la rutina INIT tiene que hacer lo necesario para dejar la dirección de la RTI en $100, no vale hacerlo fuera de INIT
       MOVE.L #RTI,$100 *Dejamos en $100 donde estará la dirección de la RTI           
       MOVE.B #%00100010,IMR *Habilitamos las interrupciones RxRDY y TxRDY en A y B
                                *OJO!!! INTERRUPCIÓN CADA VEZ QUE EL BUFFER DE TRANSMICIÓN TIENE ALGÚN CARACTER,
                                *CADA VEZ QUE TRANSMITAMOS, REGRESAR EL BUFFER A 0 SI NO LA INTERRUPCIÓN NO ACABA
       MOVE.B #%00100010,IMR_CPY   *Puede que el programa necesite una copia de IMR para más tarde
       BSR INI_BUFS  *Llamamos a INI_BUFS, @RobCbur ya arreglé el ensamblaje
       RTS           *En cuanto regrese a INIT, regresamos a donde se llamó
   







SCAN:  *(DR 4B, Buffer 4B, Descriptor 2B, Tamaño 2B)
       MOVE.L #0,D0         *Limpiamos de 0 para dejar el descriptor (para LEECAR)
       MOVE.W 8(A7),D0       *Guardamos el descriptor en D0(0=A, 1=B)
       MOVE.L 4(A7),A1      *A1<-Dir(buffer)
       CMP.W #1,D0          *Si 1 es...
       BHI ERROR          *Mayor que uno, es que es incorrecto.    
       MOVE.L #0,D3 *Iniciamos contador a 0 D3<-0       
       

BUCSCAN:
       MOVE.W 10(A7),D1 *D1<-Tamaño
       CMP.W D3,D1 *Comparamos el contador con tamaño
       BEQ FIN *Si hemos llegado al máximo, entonces FIN
       BSR LEECAR  *Llamamos a LEECAR (Devuelve en D0)
       CMP.L #$ffffffff,D0 *Revisamos que no haya devuelto buffer vacío
       BEQ FIN         *Si lo es, protocolo de salida     
       MOVE.B D0,(A1)+     *Guardamos en "Buffer" el caracter y preparamos para siguiente
       ADD.W #1,D3          *Sumamos una lectura exitosa
       MOVE.W 8(A7),D0     *Volvemos a restaurar el descriptor->D0 para LEECAR
       BRA BUCSCAN
 
FIN:   MOVE.L #0,D0  *Limpiamos D0 en caso de error
       MOVE.W D3,D0 *Devolvemos en D0 el número de caracteres leídos 
       RTS




ERROR: MOVE.L #$ffffffff,D0
       RTS





PRINT: *(DR 4B, Buffer 4B, Descriptor 2B, Tamaño 2B)
       MOVE.L #0,D0    *Limpiamos D0 de posible basura
       MOVE.W 8(A7),D0 *Cargamos en D0 el descriptor
       CMP.W #1,D0     *Comparamos
       BHI ERROR       *Si es mayor que 1, es decir no es ni 0s ni 1, error
       BSET #1,D0      *Si es correcto preparamos para escribir en el buffer de transmisión de la línea correspondiente 
       MOVE.L #0,D4     *D4<-Inicializamos contador a 0
       MOVE.L 4(A7),A2  *A2<- dirección de buffer para hacer de puntero
BUCPRINT: 
       MOVE.W 10(A7),D1 *D1<-Tamaño  
       CMP.W D4,D1      *Revisamos si llegamos al máximo de tamaño
       BEQ FIN_P        *Si son iguales entonces fin
       MOVE.B (A2)+,D1  *Guardamos el caracter en D1 e incrementamos puntero
       BSR ESCCAR       *Llamamos a ESCCAR
       CMP.L #$ffffffff,D0 *Revisamos si el buffer interno está lleno
       BEQ FIN_P              *Si lo es, fin.
CONT:  ADD.W #1,D4       *Sumamos escritura exitosa
       MOVE.W 8(A7),D0     *Cargamos en D0 el descriptor
       BSET #1,D0           *Preparamos para escribir en el buffer de transmisión de la línea correspondiente
       BRA BUCPRINT         *Ya tenemos en D0 el descriptor, seguimos con el bucle                         
FIN_P: MOVE.L #0,D1         *D1<-0
       CMP.W D4,D1          *Si no se escribieron caracteres,
       BEQ NO_ACT            *No activamos nada, si no
       MOVE.W 8(A7),D0      *Cargamos en D0 el descriptor
       CMP.W #1,D0          *Comparamos para elegir línea
       BEQ ACT_B            *Activamos interrupciones por escritura en la línea (Si es en B).   

ACT_A: MOVE.B IMR_CPY,D1
       BSET #0,D1      
       BRA SAL_PRINT

ACT_B: MOVE.B IMR_CPY,D1
       BSET #4,D1      
       
SAL_PRINT:       
       MOVE.B D1,IMR_CPY  *Acualizamos la copia porque si no puede saltar la RTI sin que hayamos cambiado la copia
       MOVE.B D1,IMR      *Activamos en B en caso de
NO_ACT: 
       MOVE.L D4,D0 *Regresamos en D0 el número de caracteres leídos 
       RTS











RTI: *#1 Salvaguardar registros, y antes de regresar, resturarlos. (Solamente los que modifique la RTI)
       *Habilitar la máscara de interrupción con ISR para poder solamente tratar las interrupciones habilitadas. (con un AND)
       MOVE.L D0,-(A7) *Guardamos los registros que se van a modificar
       MOVE.L D1,-(A7)
       MOVE.L D2,-(A7)
       MOVE.B ISR,D2    *Leemos el registro de estado de interrupción para identificar cúal de las 4 posibles causas.
       AND.B IMR_CPY,D2  *Enmascaramos con IMR 
       BTST #0,D2           *TxRDYA?
       BNE A_TxRDY          *Por alguna razón BTST revisa un bit y deja en Z EL COMPLEMENTARIO, entonces si está a 1, Z<-0
RTN_TA: BTST #1,D2           *RxRDYA?
       BNE A_RxRDY
RTN_RA: BTST #4,D2           *TxRDYB?
       BNE B_TxRDY
RTN_TB: BTST #5,D2           *RxRDYB?
       BNE B_RxRDY
       BRA RTIFIN           *Si no salta a B_RxRDY entonces ya directamente a fin

A_TxRDY: MOVE.L #2,D0 *Si se pasa en D0=2 a LEECAR se accede al buffer interno de transmisión A
       BSR LEECAR
       CMP #$ffffffff,D0 *Comparamos para revisar si el buffer interno está vacío
       BEQ ERRA_TxRDY    *Si es así, tratamiento especial
       MOVE.B D0,TBA *Si no, lo transmitimos por A
       BRA RTN_TA        *Regresamos a revisar los demás motivos si proceden

A_RxRDY: MOVE.L #0,D0 *Si se pasa D0=0 a ESCCAR se accede al buffer interno de recepción de A
       MOVE.B RBA,D1 *Dejamos el caracter recibido en D1
       BSR ESCCAR          *Lo dejamos en el buffer interno de recepción (o se tira)
       BRA RTN_RA
B_TxRDY: MOVE.L #3,D0
       BSR LEECAR
       CMP #$ffffffff,D0 *Comparamos para ver si el buffer interno está vacío
       BEQ ERRB_TxRDY    *Si es así, tratamiento especial
       MOVE.B D0,TBB *Si no, lo transmitimos por B
       BRA RTN_TB
       
B_RxRDY: MOVE.L #1,D0 *Si se pasa D0=1 a ESCCAR se accede al buffer interno de recepción de B
       MOVE.B RBB,D1 *Dejamos el caracter recibido en D1
       BSR ESCCAR          *Lo dejamos en el buffer interno de recepción (o se tira)
       
RTIFIN:
       MOVE.L (A7)+,D2
       MOVE.L (A7)+,D1
       MOVE.L (A7)+,D0 *Restauramos registros
       RTE

ERRA_TxRDY:
       MOVE.B IMR_CPY,D0
       BCLR #0,D0 
       MOVE.B D0,IMR_CPY *Actualizamos copia primero
       MOVE.B D0,IMR *Deshabilitamos las interrupciones TxRDYA       
       MOVE.L (A7)+,D2
       MOVE.L (A7)+,D1
       MOVE.L (A7)+,D0 *Restauramos registros
       RTE
ERRB_TxRDY:
       MOVE.B IMR_CPY,D0
       BCLR #4,D0
       MOVE.B D0,IMR_CPY *Actualizamos copia
       MOVE.B D0,IMR *Deshabilitamos las interrupciones TxRDYB
       MOVE.L (A7)+,D2
       MOVE.L (A7)+,D1
       MOVE.L (A7)+,D0 *Restauramos registros
       RTE
 






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

TESTSCAN:
       MOVE.L #0,D3 *Contador
       MOVE.L #1,D0  *Para acceder al buffer interno de repeción de línea B
       MOVE.L D0,-(A7)
       MOVE.L #$800,A1 *Puntero para texto
BUC:   CMP.L #10,D3
       BEQ FINAL
       MOVE.B (A1)+,D1
       BSR ESCCAR
       ADD.L #1,D3
       BRA BUC
FINAL: MOVE.W #10,-(A7) *Tamaño
       MOVE.W #1,-(A7) *Descriptor
       MOVE.L #$900,-(A7) *Buffer
       BSR SCAN       
       BREAK


*--------------------------------------------------------------------------------------------*

BUFFER: DS.B 2100 * Buffer para lectura y escritura de caracteres
PARDIR: DC.L 0 * Dirección que se pasa como parámetro
PARTAM: DC.W 0 * Tamaño que se pasa como parÁmetro
CONTC: DC.W 0 * Contador de caracteres a imprimir
DESA: EQU 0 * Descriptor línea A
DESB: EQU 1 * Descriptor línea B
TAMBS: EQU 1 * Tamaño de bloque para SCAN
TAMBP: EQU 1 * Tamaño de bloque para PRINT

* Manejadores de excepciones
INICIO: 
       MOVE.L  #$8000,A7
	MOVE.L  #$0,D0
	MOVE.L  #$0,D1
	MOVE.L  #$0,D2
	MOVE.L  #$0,D3
	MOVE.L  #$0,D4
	MOVE.L  #$0,D5
	MOVE.L  #$0,D6
	MOVE.L  #$0,D7
	MOVE.L  #$0,A0
	MOVE.L  #$0,A1
	MOVE.L  #$0,A2
	MOVE.L  #$0,A3
	MOVE.L  #$0,A4
	MOVE.L  #$0,A5
       MOVE.L  #$0,A6       
       MOVE.L #BUS_ERROR,8 * Bus error handler
       MOVE.L #ADDRESS_ER,12 * Address error handler
       MOVE.L #ILLEGAL_IN,16 * Illegal instruction handler
       MOVE.L #PRIV_VIOLT,32 * Privilege violation handler
       MOVE.L #ILLEGAL_IN,40 * Illegal instruction handler
       MOVE.L #ILLEGAL_IN,44 * Illegal instruction handler
       BSR INIT
       MOVE.W #$2000,SR * Permite interrupciones y activa modo supervisor
       BUCPR: MOVE.W #TAMBS,PARTAM * Inicializa par´ametro de tama~no
       MOVE.L #BUFFER,PARDIR * Par´ametro BUFFER = comienzo del buffer
       OTRAL: MOVE.W PARTAM,-(A7) * Tama~no de bloque
       MOVE.W #DESA,-(A7) * Puerto A
       MOVE.L PARDIR,-(A7) * Direcci´on de lectura
       ESPL: BSR SCAN
       ADD.L #8,A7 * Restablece la pila
       ADD.L D0,PARDIR * Calcula la nueva direcci´on de lectura
       SUB.W D0,PARTAM * Actualiza el n´umero de caracteres le´ıdos
       BNE OTRAL * Si no se han le´ıdo todas los caracteres
                     * del bloque se vuelve a leer
       MOVE.W #TAMBS,CONTC * Inicializa contador de caracteres a imprimir
       MOVE.L #BUFFER,PARDIR * Par´ametro BUFFER = comienzo del buffer
       OTRAE: MOVE.W #TAMBP,PARTAM * Tama~no de escritura = Tama~no de bloque
       ESPE: MOVE.W PARTAM,-(A7) * Tama~no de escritura
       MOVE.W #DESB,-(A7) * Puerto B
       MOVE.L PARDIR,-(A7) * Direcci´on de escritura
       BSR PRINT
       ADD.L #8,A7 * Restablece la pila
       ADD.L D0,PARDIR * Calcula la nueva direcci´on del buffer
       SUB.W D0,CONTC * Actualiza el contador de caracteres
       BEQ SALIR * Si no quedan caracteres se acaba
       SUB.W D0,PARTAM * Actualiza el tama~no de escritura
       BNE ESPE * Si no se ha escrito todo el bloque se insiste
       CMP.W #TAMBP,CONTC * Si el no de caracteres que quedan es menor que
                            * el tama~no establecido se imprime ese n´umero
       BHI OTRAE * Siguiente bloque
       MOVE.W CONTC,PARTAM
       BRA ESPE * Siguiente bloque
       SALIR: BRA BUCPR
       BUS_ERROR: BREAK * Bus error handler
       NOP
       ADDRESS_ER: BREAK * Address error handler
       NOP
       ILLEGAL_IN: BREAK * Illegal instruction handler
       NOP
       PRIV_VIOLT: BREAK * Privilege violation handler
       NOP







**** ATENCION AMIGA ASSEMBLY LA EXTENSION NO ENTIENDE ALGUNAS COSAS, EN UNA CORRECCION HACER LOS SIGUIENTES PASOS:

* TODO: DESCOMENTAR
INCLUDE bib_aux.s
