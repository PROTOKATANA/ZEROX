# CBE-v0.1 — Contrato candidato de billete, elegibilidad y ejecución

Fecha: 2026-09-11. Estado: **autorizado para especificación y evaluación; no activado en consenso**.
Decisión del usuario: mantener PoST + DAG, un único derecho económico y un único cuerpo ejecutable
por billete. Objetivo: minimizar la espera real de Cortex a riesgo explícito y coste de nodo asumible.

Este contrato no introduce comité, staking, autoridad de finalidad ni otro algoritmo de firma.
El ancla PoT acelerada permanece como investigación separada. No cambia todavía las reglas R-FIN
del SPEC: describe un candidato y su alternativa de comparación. Los identificadores CBE son
locales a este contrato; no sustituyen ni reutilizan identificadores retirados del SPEC.

## 0. Frontera de esta primera entrega

Hay dos niveles diferentes:

1. **Contrato candidato:** obligaciones de identidad, disponibilidad, selección, ejecución,
   contabilidad y publicación. Incluye dependencias aún no resueltas.
2. **Modelo ejecutable M0:** transición discreta de un lote cuyo contexto, identidades, orden,
   colores y resultados de validación se proporcionan explícitamente. Sirve para comprobar
   semántica y equivalencia Rust/Julia, no para aceptar bloques de red.

M0 NO calcula PoAS/PoT/KZG, GHOSTDAG, firmas, merkle roots, importes de coinbase reales, estado
Orchard ni una cota de riesgo. Sus etiquetas V/P/I son entradas de fixtures, **no verificadores
de sustitución**. Sus enteros de identidad/rango son nombres sintéticos, no una serialización
consensuada. No se conecta este modelo al nodo ni a rutas de producción.

## 1. Identidad y autenticación

**CBE-01 — Una oportunidad, una identidad.** `TicketId` designa una clase de oportunidades
económicas que debe justificarse criptográficamente. Misma identidad significa mismo derecho,
no necesariamente los mismos bytes de prueba o envoltorio. Una misma oportunidad no puede cobrar
otra vez por modificar sello, padres, cuerpo, dirección de recompensa o hash del bloque.

Punto de partida a estudiar, no tupla certificada:
`(public_key, sector_index, history_size, piece_offset, chunk, slot)` y su contexto de reto/flujo.
Falta justificar las equivalencias entre pruebas, historia y retos admitidos. `s_bucket` es
derivado del reto; no se convierte en identificador libre. No se añade `proof_hash` para contar
variantes sin una justificación económica y criptográfica.

**CBE-02 — Autenticación no es prioridad.** Se conserva Ed25519/ZIP-215. La preimagen DAG debe
comprometer todos los campos relevantes, incluidos padres y cuerpo. El determinismo del firmador
no impone unicidad de firma aceptada; el test existente refuta esa inferencia.

Antes de integrar el orden, debe comprobarse invariancia frente a variantes admitidas de sello
y analizar el efecto de variantes de cuerpo/prueba bajo contexto fijado. Cambiar padres cambia
causalidad y puede cambiar rango: no se exige la falsa propiedad de que todos los padres posibles
produzcan el mismo orden. Esos grados de libertad requieren un modelo adversarial de coste.

**Pendiente bloqueante para producción:** derivación de TicketId, formato comprometido y orden
completo resistente a las estrategias relevantes. M0 no pretende resolverlos asignando números.

## 2. Contexto y orden

**CBE-03 — Contexto candidato fijo.** Un lote `L(C)` contiene los bloques que toca procesar al
avanzar una historia candidata desde su prefijo aplicado hasta C. Incluye el padre seleccionado
y los integrantes nuevos del mergeset según la convención de R-FIN-8′. Cada bloque se incorpora
una sola vez en esa historia. El conjunto y su orden se fijan antes de consultar disponibilidad.

`Orden_C` es total y canónico, calculado a partir de datos de consenso; nunca llegada, reloj local,
velocidad de descarga o finalización de hilos. La función concreta procede de la integración DAG
pendiente, no de una elección arbitraria del operador. M0 recibe posiciones `rank` únicas como
oráculo de ese orden y por ello NO prueba su resistencia al grinding.

El consumo económico se mantiene separado de U3″ y de la coloración. No se realimenta el registro
de pagos dentro de la selección azul de este candidato. Se evalúa por separado si esa separación
produce incentivos o retrasos indeseables.

## 3. Disponibilidad y estados

**CBE-04 — Ausencia no es invalidez.** Distinguir:

| Estado | Consecuencia |
|---|---|
| Pendiente: faltan bytes, prueba, dependencia o validación concluyente | No publicar transición ni declarar inválido por timeout. |
| Invalidez establecida bajo las reglas aplicables | Rechazar el candidato que depende del bloque inválido; no saltarlo para elegir otra copia. |
| Transacción no aplicable por conflicto de estado | Omitir esa transacción conforme al orden, sin invalidar por ello el bloque ni liberar el billete. |
| Completo y validado | Permite preparar la transición contextual; no significa finalidad del pago. |

La frontera exacta entre invalidez del bloque y rechazo de una transacción requiere la integración
de validadores transparentes/blindados. Un testigo faltante no equivale a testigo inválido, y no
disponer del UTXO histórico para comprobar una autorización no convierte un conflicto en invalidez.
Las pruebas y autorizaciones exigibles deben quedar verificadas en el contexto apropiado.

**CBE-05 — Perfil DA0 conservador de evaluación.** Se requieren los cuerpos completos y la
validación exigible de **todos los bloques nuevos del lote**, incluidos perdedores, rojos_U3 y
tardíos. Las dependencias del prefijo se presuponen ya verificadas y disponibles para validar.
No se deriva que los cuerpos inertes se puedan olvidar antes de comprobar su validez.

Si cualquiera está pendiente, todo el lote queda pendiente: no hay consumo, emisión, conteo,
ejecución ni punta nueva publicables. Puede guardarse trabajo preparatorio en caché, pero no
publicarse como estado de consenso. Cuando llegan los datos se evalúa el mismo candidato.
Si aparece evidencia de invalidez, el candidato es inválido; una historia alternativa debe
justificarse por sus propias reglas, no por cambiar localmente de representante.

**Coste explícito:** una copia perdedora retenida también puede bloquear el candidato. DA0 evita
decidir por disponibilidad local, pero NO resuelve disponibilidad adversarial ni garantiza viveza.
Se deberán estudiar estrategias de propagación, selección de padres y recuperación compatibles
con consenso. No se añade aquí un certificado de disponibilidad, comité o plazo de exclusión.

## 4. Elegibilidad temporal y elección

**CBE-06 — Ventana común, perfil L0.** Sean `s_C` el índice PoT del contexto y `W_adm` una anchura
entera no negativa, fijada para cada experimento. El intervalo de admisión económica es cerrado:

```text
lo(C) = max(0, s_C - W_adm)       // resta saturada, sin underflow
EnVentana(B,C) := lo(C) <= slot(B) <= s_C
```

W_adm se expresa en slots y NO se iguala a F, S_max, una duración física o una ventana upstream.
Su valor de producción queda pendiente; las cifras pequeñas de fixtures son sólo casos de borde.
Los slots futuros respecto al contexto son entrada inválida de M0, no billetes tardíos.

En L0, una copia fuera de ventana no cobra, no genera observación y no ejecuta transacciones;
no se invalida su cabecera únicamente por esa exclusión económica. Sus transacciones pueden ser
reincluidas en otro billete. Una variante L1 que permita ejecutar tardíos sin subsidio queda
reservada para comparación: necesita otra definición de consumo, comisiones y recursos.

**CBE-07 — Elegibilidad semántica.** Una copia completa puede participar si su color contextual es
azul o rojo_k, está en ventana y su TicketId no está consumido en el prefijo heredado. Un rojo_U3
no participa. La elección no depende de si sus transacciones ganarán conflictos ni de que el
subsidio sea positivo. La falta de datos suspende el lote, no elimina un participante.

**CBE-08 — Dos políticas explícitas.**

- **P0, candidato principal:** por cada identidad disponible, elegir la primera copia elegible
  en Orden_C.
- **P1, comparación:** por cada identidad disponible, preferir azul sobre rojo_k dentro del
  lote; entre iguales, usar Orden_C. Nunca reemplaza una adjudicación heredada ni espera azules
  futuros. El ganador ejecuta en su propia posición original, no en la de una roja desplazada.

Ambas selecciones se calculan sobre el lote completo antes de ejecutar. No se cambia de política
según el resultado de las transacciones, la disponibilidad local o la conveniencia del productor.
Un cambio por reorganización supone otra historia y otro registro, no una segunda adjudicación
en la misma historia.

## 5. Consumo y ejecución

**CBE-09 — Consumo único, aunque el importe sea cero.** Para cada representante se prepara un
evento que contiene TicketId, bloque representante, contexto de incorporación, slot original,
slot de incorporación, subsidio efectivo y comisiones realmente aceptadas.
El TicketId se consume en la transición que publica ese evento, no al gastar o madurar coinbase.
Un cuerpo vacío, todos sus gastos en conflicto o subsidio cero NO liberan el billete.

**CBE-10 — Un solo cuerpo ejecutable por identidad e historia.** Se recorren representantes en
su orden original y sus transacciones en orden interno. Un gasto transparente ya consumido o
nullifier ya usado se rechaza por conflicto; las demás comprobaciones necesarias siguen vigentes.
Las transacciones rechazadas no producen comisiones ni efectos. Los perdedores no ejecutan ni
reciben subsidio/comisiones por ese cuerpo en P0/P1+L0.

La ejecución real debe cubrir UTXO, commitments, nullifiers y reconocimiento de pagos; no basta
un contador de cuerpos. M0 sólo usa claves de conflicto sintéticas separadas por dominio T/S y
no representa balance, creación de UTXO, notas, pruebas Orchard ni reconocimiento de la wallet.

**CBE-11 — Contabilidad desde el mismo evento.** Cada nueva adjudicación aporta una observación
y el subsidio efectivo correspondiente, incluso si éste es cero. Las comisiones se registran
aparte: no son nueva emisión. No se cambia quién recibe la coinbase a favor del fusionador.
La coinbase efectiva debe satisfacer los límites contextuales existentes; su integración y el
significado DAG de altura/madurez permanecen pendientes, no se sustituyen por el campo del fixture.

Conservar slot original y de incorporación permite definir, para una historia C:

```text
N_obs(C) = numero de eventos incorporados en esa historia
           cuyos slots originales pertenecen a la ventana declarada del controlador
```

La ventana de observación del controlador, su actualización, retraso causal, objetivo, redondeo y
arranque deben fijarse separadamente. Los eventos de C no pueden modificar retroactivamente el
rango usado para validar esos mismos bloques. Cambiar ventana no borra TicketUse heredado.
La igualdad del conjunto de eventos no demuestra estabilidad ni ausencia de sesgo del retarget.

M0 comprueba el **conteo acumulado de adjudicaciones**, no implementa N_obs ni un controlador.
Contar sólo admisiones oportunas observa producción admitida a tiempo, no toda la producida.
Retención, congestión y exclusión honesta deben medirse en una simulación con realimentación.

## 6. Estado, publicación y reorg

**CBE-12 — Estado contextual completo.** TicketUse guarda al menos identidad, representante,
contexto y slot original. Los eventos guardan también los datos contables necesarios. La transición
incluye conjuntamente estado de ejecución, aceptación, importes, observaciones, contexto y metadatos
necesarios para reconstrucción. Ninguna consulta mezcla versiones de esos componentes.

**CBE-13 — Preparar, validar, publicar.** Preparación privada; comprobación completa; publicación
atómica. Pending, Invalid, overflow o fallo de persistencia no publican una parte del lote.
Una implementación real requiere delimitación de batch y recuperación, no sólo un booleano de
éxito. M0 emplea copia de estado y publicación al final, sin probar durabilidad de disco.

**CBE-14 — Reorganización reversible.** El undo se liga al contexto que deshace y restaura todos
los componentes. Un cambio de rama se prepara como una operación: deshacer al ancestro, aplicar
rama candidata y publicar sólo si termina. Si falla o queda pendiente, conservar el estado público
anterior y registrar aparte el candidato pendiente. No aceptar pagos nuevos sobre una vista cuya
frescura/continuidad ya no esté acreditada.

**CBE-15 — Sin poda semántica implícita.** No olvidar consumos por salir de ventana. Poda de cuerpos,
compactación exacta y olvido de identidades requieren pruebas distintas. DA0 no autoriza eliminar
un cuerpo que una continuación permitida pueda exigir después. No se fija memoria usando lambda*F.

## 7. Modelo ejecutable y vectores compartidos

M0 tiene IDs y magnitudes UInt64 comprobadas; el oráculo Julia puede usar BigInt y restringe las
salidas al mismo dominio. Identidades opacas y contenidos asociados son inmutables: los fixtures
no simulan colisiones de hash ni sustituyen validadores. Colores y rank llegan del oráculo de orden.

Validación estructural de entrada: IDs de contexto/bloque/billete/transacción/clave positivos;
rank puede ser cero, pero es único por lote; bloques únicos y no incorporados antes en ese prefijo;
contexto padre igual al aplicado, contexto nuevo distinto de los activos y slot no decreciente;
slots de bloque no futuros; misma identidad tiene el mismo slot dentro del lote y respecto al
registro heredado. Una transacción idéntica repetida puede aparecer: el conflicto impide aplicarla
dos veces. Un mismo txid con contenido distinto viola la precondición de compromiso inmutable.

Primero se detecta invalidez estructural o etiqueta I; después cualquier P devuelve Pending;
las sumas contables se comprueban sólo al ejecutar un lote completo. Por tanto, P con un potencial
overflow aún no ejecutado sigue Pending. Cualquier overflow efectivo devuelve Invalid sin mutación.

Estado M0: contexto/slot, ledger con representante/contexto/slot, claves gastadas por dominio,
IDs de transacciones aceptadas en orden, subsidio/comisiones/conteo acumulados y conjunto de todos
los bloques incorporados (incluidos los inertes). Undo restaura también ese conjunto.

`fixtures/CASOS.txt` usa la siguiente gramática por líneas, separadas por espacios. `#` inicia
comentario de línea; las listas usan coma y `-` para vacío:

```text
CASE nombre first|blue
BATCH contexto padre slot W_adm
BLOCK id ticket slot rank B|R|U V|P|I subsidio
TX id T|S clave comision           # transacción del BLOCK anterior
APPLY
EXPECT Applied|Pending|Invalid|Reverted ctx slot conteo subsidio fees ledger txs spent seen
UNDO
END
```

`ledger` ordenado numéricamente por ticket: `ticket:bloque:contexto:slot_original`. `txs` conserva
orden de aceptación. `spent` ordena T antes de S y luego clave numérica; `seen` ordena IDs de bloque
numéricamente. Tras APPLY
se conserva la clasificación de resultado hasta EXPECT. UNDO revierte el último lote aplicado;
sin undo disponible es Invalid sin mutación. END reinicia escenario. BATCH reemplaza sólo el
lote preparatorio, nunca el estado aplicado. Los UNDO aislados son pruebas de restauración:
la atomicidad de un cambio completo de rama necesita su test transaccional adicional.

Las cantidades de estos vectores son **elegidas para tests**; no parametrizan producción ni
estiman la probabilidad de los escenarios. EXPECT compara la proyección de estado descrita,
no sólo sumas. No serializa todos los campos del journal por evento, la pila de undo ni el
historial de contextos: esas propiedades necesitan comprobaciones adicionales. Coincidir en
EXPECT no prueba por sí solo equivalencia de esos componentes ni durabilidad de producción.

## 8. Evaluación posterior y criterios de aprobación

Primera fase: mismos fixtures y transiciones Rust/Julia, oráculo independiente, bordes y
permutaciones de disponibilidad/entrada, reorgs, conflictos y errores; coste del kernel aislado.
No equivale a implementar la cadena ni demostrar una ganancia de rendimiento de nodo.

Segunda fase: mismas trazas estructuralmente válidas para aislar P0/P1 y perfiles de ejecución;
después simulaciones endógenas independientes con producción, pagos, retarget y estrategias que
respondan a cada variante. Un replay fijo no captura esa realimentación.

Para Cortex, el fallo principal es retirar después de aceptar el hecho histórico del pago, no
perder un bloque o cambiar blue_work. Registrar separadamente desacuerdo entre observadores,
ausencia de progreso, reinclusiones, exclusiones honestas, transacciones nunca aceptadas,
tiempos censurados al terminar el ensayo y colas largas. No calcular sólo la media de éxitos.

Comparar al mismo riesgo/adversario/presupuesto de nodo, incluyendo tráfico y verificación previos
a reconocer una copia, CPU/memoria/I/O del ledger, propagación y recuperación. No aumentar tasa
ni reducir k en esta entrega. Los criterios de riesgo, frescura y espera de producción aún deben
fijarse; ningún segundo nuevo queda certificado por este contrato.

## Fuentes y relación con el SPEC

- [SPEC](../../../SPEC.md): §§6–7 (pruebas/identidad), §§8–9 (emisión/privacidad), §§11–12 (orden/reorg),
  C-STORE-06..08. Sigue en preparación.
- [Ancla de orden](../../../research/dag-poas-ancla-de-orden.md): R-FIN-8′/11/13′ y laguna declarada.
- [Verificación independiente](../identidad-copias/INFORME.md): construcción entre fusiones,
  alcance de P1, claves Autonomys, non-DAA y contraejemplo de firma.
- [Modelo de pago](../../finalidad/baseline-30m/MODELO.md), §5: observador, continuidad y evento de fallo.
- [LINEO](../../LINEO.md): disciplina Julia CPU y pruebas reproducibles; tests Rust junto al crate.

La aprobación del usuario permite estudiar y escribir el candidato. La activación de consenso
requiere cerrar las dependencias anteriores y una decisión posterior explícita, no tests verdes
de un modelo que las toma como entradas.
