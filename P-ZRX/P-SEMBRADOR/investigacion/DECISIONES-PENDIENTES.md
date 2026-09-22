# Decisiones pendientes — P-SEMBRADOR

Este documento no fija parámetros ni modifica el consenso. Presenta las bifurcaciones que Katana tendría que cerrar después de prototipar y medir.

## 1. Aceptar o rechazar un registro verificable de parcelas

### Opción 1A — mantener el formato y el modelo sin registro

**Qué gana [verificado].** Conserva alta sin espera, identidades gratuitas, cabecera y parcela Autonomys actuales, sin estado de activaciones.

**Qué paga [demostrado].** No hay evidencia de antigüedad ni sector completo. El sembrador sigue disponible y sólo puede tarifarse mediante coste, menor adelanto o pago diferido.

**Qué cierra.** Descarta presentar A, C o E como eliminación mientras no exista un compromiso exacto anterior al reto.

### Opción 1B — activar compromisos exactos antes del reto

**Qué gana [propuesto].** Permite eliminar condicionalmente la adaptación cuando la edad excede una cota del adelanto y la prueba obliga a la parcela completa.

**Qué paga [no determinado].** Espera del nuevo granjero, altas/bajas, estado o acumulador, poda, prueba de pertenencia y migración. Revoca expresamente la ausencia de registro de sectores.

**Qué cierra.** Define la base necesaria para A1+C1 y para una E verificable. Aún debe escogerse entre registro por sector, raíz por lote o activación por época.

## 2. Qué debe demostrar el compromiso

### Opción 2A — sólo `SectorId` o referencia histórica

**Qué gana.** Implementación pequeña.

**Qué paga [demostrado].** Protección nula frente a crear hoy los bytes o precomprometer identificadores fantasma.

**Qué cierra.** Debe rechazarse como prueba de antigüedad física.

### Opción 2B — raíz, versión y cardinalidad de bytes codificados

**Qué gana [propuesto].** Liga una instancia concreta y permite aperturas posteriores.

**Qué paga [no determinado].** Construcción de raíz, testigos, estado y regeneración aún posible.

**Qué cierra.** Hace viable A1 y E, pero sólo eleva C1 a «elimina» si existe prueba suficiente de cómputo completo o una cota de regeneración.

### Opción 2C — certificado sucinto de codificación completa

**Qué gana [propuesto].** Obliga a pagar el sector completo por alta/intento y puede cerrar el ploteo parcial.

**Qué paga [no determinado].** Circuito/prueba nueva para PoS, erasure coding y KZG; generación, verificación, parámetros y migración.

**Qué cierra.** Decide si C1 es eliminación junto con edad previa o sólo mitigación por muestreo.

## 3. Prevención o tarifa de permanencia

### Opción 3A — prevención A1+C1

**Qué gana [propuesto].** Cierra la adaptación posterior al reto bajo una cota de adelanto.

**Qué paga.** Registro, prueba completa y espera de alta.

**Qué cierra.** Exige definir `A_actual`, compromiso exacto y tratamiento de altas/reorganizaciones antes de tocar el SPEC.

### Opción 3B — recompensa sujeta a auditorías futuras E

**Qué gana [propuesto].** Impide desechar inmediatamente el sector ganador y tarifa la no permanencia.

**Qué paga [demostrado por contabilidad].** Los intentos fallidos siguen desechándose. El honesto asume riesgo de disco/red; nodos y cadena mantienen obligaciones.

**Qué cierra.** Requiere decidir si una coinbase fallida cuenta para el controlador, qué bloques del DAG generan obligación, plazo, número de retos y semántica de pérdida.

### Opción 3C — ambas

**Qué gana [propuesto].** Prevención de adaptación y evidencia posterior de retención del ganador.

**Qué paga.** Suma estado, pruebas y riesgo operativo; maximiza la migración.

**Qué cierra.** Permite presentar E como seguro adicional, no como sustituto de A1+C1.

## 4. Conservar Autonomys o investigar sellado secuencial

### Opción 4A — conservar PoAS actual y endurecerlo

**Qué gana.** Reutiliza piezas, KZG, red y herramientas existentes.

**Qué paga [verificado].** La prueba actual sólo cubre una pieza; cerrar el sector entero requiere una capa nueva.

**Qué cierra.** Prioriza A1+C1 y pospone B.

### Opción 4B — PoRep/sellado secuencial B

**Qué gana [propuesto].** Puede hacer que cada adaptación tenga una latencia no paralelizable superior al adelanto.

**Qué paga [no determinado].** Nueva criptografía, hardware especializado, prueba sucinta, migración total y necesidad de cotar al adversario.

**Qué cierra.** Sólo procede si un prototipo demuestra `T_seal,adv > sup A_actual`; medir el equipo honesto no basta.

## 5. Reducir el adelanto con revelación retardada

### Opción 5A — no añadir líneas PoT

**Qué gana.** Conserva coste y comportamiento de partición del diseño actual.

**Qué paga.** A/B deben cubrir el adelanto completo.

### Opción 5B — R-FIN-14(h) como mitigación D

**Qué gana [propuesto].** Reduce la edad o sellado exigidos a A/B dentro de una región de aceleración.

**Qué paga [estimado].** Verificación aproximada `1+L/I`, varias líneas AES y riesgo de que un lado de partición no produzca.

**Qué cierra.** No puede aprobarse antes de rehacer `A_actual` con la salida futura `D` y medir plataformas/particiones. Nunca debe figurar como eliminación universal.

## 6. Registro por sector o activación por época

### Opción 6A — altas por sector/lote

**Qué gana.** Cambio más próximo a la parcela actual y granularidad fina.

**Qué paga.** Mayor tasa de transacciones/estado y posibles ataques de alta.

### Opción 6B — PoST/activación por época G

**Qué gana [propuesto].** Compromiso de capacidad, edad y permanencia integrados; precedente de Spacemesh.

**Qué paga.** Cambio de selección/retarget, espera por época, auditorías de gran volumen y abandono explícito del modelo sin registro.

**Qué cierra.** Debe decidir si ZEROX acepta esta migración antes de estudiar parámetros; no debe introducir PoET, comité ni autoridad externa.

## 7. Política ante pérdida de una auditoría de recompensa

### Opción 7A — el bloque cuenta y la recompensa se quema

**Qué gana.** Evita corregir retrospectivamente el controlador.

**Qué paga.** Emisión real menor y posible incentivo de censura/DoS contra respuestas.

### Opción 7B — el bloque deja de contar para emisión/retarget

**Qué gana.** Alinea bloques contados y pagados.

**Qué paga.** Contabilidad retrospectiva y dependencia del futuro en el controlador.

### Opción 7C — seguro o tolerancia de varias auditorías

**Qué gana.** Reduce falsos fallos honestos.

**Qué paga.** Debilita la tarifa adversarial y añade estado. Los umbrales son parámetros pendientes, no cifras heredables.

## 8. Umbral de decisión tras las mediciones

Antes de escoger una rama hacen falta, como mínimo:

1. **[Medición pendiente]** latencia, rendimiento y memoria de un intento parcial dirigido en CPU/GPU y un adversario razonable;
2. **[Derivación pendiente]** `A_actual(ρ,L,I,W_dec,D,…)`, incluida la salida futura y particiones;
3. **[Medición pendiente]** tamaño, generación y verificación de raíz/certificado/aperturas;
4. **[Medición pendiente]** regeneración y compromisos tiempo-memoria del sector comprometido;
5. **[Modelo pendiente]** `π_DAG` y contabilidad exacta de bloques pagados;
6. **[Medición pendiente]** espera y coste de alta para un granjero pequeño, crecimiento de estado y tasa de altas;
7. **[Medición pendiente]** pérdida honesta de auditorías, disponibilidad y efecto de particiones.

La decisión de diseño queda preparada así:

- si se acepta registro y el certificado completo es viable, escoger **A1+C1** y considerar E;
- si el certificado no es viable pero un sellado tiene cota adversarial creíble, estudiar **B**;
- si se acepta una migración de capacidad, comparar **G** contra A1+C1;
- si ninguna de esas condiciones se satisface, declarar el sembrador **mitigado/tarifado**, usar D/E/C2 sólo con factores medidos y no afirmar eliminación.
