# IDV-v0.1 — Identidad y disponibilidad con evidencia de validación

Fecha: 2026-09-11. Candidato de integración; **no activado en consenso**.
Refina las condiciones de entrada de [CBE-v0.1](../contrato-billete-v1/CONTRATO.md), sin
reescribir sus fixtures históricos ni presentar un verificador ausente como implementado.
Ventana, retarget y ancla de finalidad acelerada quedan fuera de esta etapa.

## 1. Tres identidades diferentes

No usar una misma clave para tres problemas:

| Clave | Qué distingue | Qué no demuestra |
|---|---|---|
| Oportunidad económica | El derecho que sólo puede adjudicarse una vez en una historia | Validez de todas sus representaciones o ausencia de grinding. |
| Evidencia de validación | Prueba y contexto exactos realmente comprobados | Un nuevo derecho a cobrar por cambiar rango, prueba o contexto de caché. |
| Contenido de bloque | Objetivo DAG: efectos y autorizaciones comprometidos por una cabecera autenticada; hoy la raíz sólo cubre efectos | Disponibilidad futura ni posibilidad de ejecutar esos efectos en cualquier estado. |

**IDV-01 — Clave económica recomendada, condicionada:**

```text
(dominio económico de red/era, slot, public_key, sector_index, history_size, piece_offset)
```

No incluye sello, hash de bloque, padres, coinbase, rango ni bytes de pruebas. El dominio debe
proceder de reglas comunes estables: no puede elegirlo el productor ni cambiar por copia.
No se fija aquí serialización o etiqueta de hash de producción.

Bajo un contexto archivado fijo y verificado, la selección de pieza, el compromiso de segmento,
la posición dentro del segmento y el s_bucket derivado fijan el record y su evaluación chunk,
condicionado al binding KZG y a resistencia a colisiones. En ese ámbito, chunk no crea otro
derecho independiente. Incluir piece_offset evita agrupar a ciegas piezas/semillas diferentes.
El argumento y sus límites se detallan en [IDENTIDAD.md](IDENTIDAD.md).

**Bloqueante pendiente:** qué retos y raíces alternativos del mismo slot pertenecen a la misma
oportunidad en ZEROX. No añadir flow/raíz a la clave sólo porque facilita una caché: podría
conceder nuevos cobros. Tampoco excluirlos demuestra automáticamente que se elimine la elección
ventajosa entre retos. La política entre flujos requiere una regla y análisis propios.

## 2. Verificación de solución y procedencia del contexto

**IDV-02 — Verificador completo dentro de su alcance.** Para una solución PoAS se exige la ruta
real `verify_solution::<ChiaTable, _>` con `piece_check_params: Some(...)`. La ruta None omite
pertenencia de pieza al archivo y comprobaciones de historia/caducidad; no genera evidencia
suficiente para admisión en este candidato.

El llamante debe resolver desde la historia candidata autenticada:

- salida PoT y slot; rango esperado, no rango propuesto libremente;
- parámetros de distribución de piezas y vida de sector;
- historia actual, compromiso del segmento correcto y contexto de caducidad cuando proceda;
- versión del verificador y parámetros KZG admitidos.

El compromiso de segmento debe corresponder al **índice de segmento derivado**; no basta pasar
un compromiso cualquiera junto con una prueba que se verifica contra él. Las comprobaciones
del verificador no sustituyen la selección correcta de su contexto por el llamante.

**IDV-03 — Caché de evidencia contextual.** Una entrada positiva debe identificar los bytes de
solución comprobados y todos los parámetros/contextos que puedan cambiar la respuesta. No se
reutiliza por TicketId únicamente: modificar PoS, rango, PoT, historia, raíz o caducidad exige
una prueba de equivalencia o nueva validación. Un caché negativo tampoco invalida otras pruebas
del mismo billete sólo porque una representación falló.

La PoS participa en `masked_chunk = chunk XOR hash(proof_of_space)`, y con ello en distancia y
elegibilidad. Deduplicar por oportunidad limita adjudicaciones, no los intentos de producir una
representación elegible. No se exige silenciosamente la primera prueba del generador: eso sería
otra regla, aún no justificada ni activada.

## 3. PoT válido no es solamente una salida de 16 bytes

**IDV-04 — Evidencia del reloj.** Una salida recibida es un dato, no prueba de trabajo secuencial.
Antes de emplearla como contexto admitido se requieren checkpoints verificados con semilla y
cantidad de iteraciones derivadas del flujo correcto. Faltan en ZEROX la integración completa
del flujo, inyección, calendario y su enlace con ancestros.

El prototipo `pot-estable` verifica checkpoints reales y dispone de vectores diferenciales.
Las nuevas regresiones comprueban alteración de cada checkpoint, semilla incorrecta y cantidad
de trabajo incorrecta. No prueban la procedencia de la semilla, el calendario ni finalidad.
No convierten 1.600 iteraciones de un fixture en parámetro de producción.

## 4. De una respuesta de red a un bloque elegible

**IDV-05 — No confundir objeto recibido con cabecera comprometida.** Refinamiento necesario
de las etiquetas V/P/I de M0:

| Evidencia disponible | Clasificación | Efecto sobre el candidato |
|---|---|---|
| Faltan cuerpo, prueba, ancestros o estado necesario | Dependencia pendiente | No publicar, no consumir; mantener recuperación. |
| Bytes malformados o que no satisfacen el compromiso esperado | Entrega rechazada | Descartar esa entrega; no declarar inválida la cabecera solicitada por ese solo hecho. |
| Testigo/prueba auxiliar no comprometido falla, pero otros bytes podrían verificar | Representación rechazada | No contaminar la caché del bloque/billete; pedir evidencia correcta. |
| Datos autenticados y comprometidos violan una regla con contexto completo | Invalidez establecida de ese candidato/contexto | Rechazarlo, sin saltar localmente a otra copia del mismo lote. |
| Transacción previamente válida pierde un conflicto en el orden de ejecución | Conflicto contextual de ejecución | No aplicar esa transacción; no liberar el billete. |
| Persistencia o lectura falla | Error local de servicio | No publicar parcialmente ni convertirlo en fraude del productor. |

Un error enum que se llame permanente no identifica por sí solo el objeto/contexto contra el
que se puede cachear. La clave y la evidencia comprometida son parte de la clasificación.

**IDV-06 — Comprometer autorizaciones sin cambiar txid.** En el formato actual, la raíz de
Merkle del bloque usa txid; txid excluye firmas. Por eso una raíz correcta no autentica todos
los bytes del cuerpo. `auth_digest` sí distingue los testigos, pero no está comprometido por
la cabecera actual. La barrera `comprobar_cuerpo` no demuestra validez criptográfica completa.
Además, `validar_tx` separa deliberadamente las firmas en `testigo::satisface`, y la ruta actual
`validar_cuerpo` tampoco compone esa llamada. Ninguno de esos Ok aislados autoriza etiquetar el
cuerpo como verificado criptográficamente. La composición real debe calcular cada sighash con
los datos de salida/contexto apropiados y verificar cada condición de gasto exigida.

Recomiendo que el formato DAG comprometa explícitamente el vector ordenado de autorizaciones,
además de los efectos; debe enlazar número/orden de transacciones y el algoritmo de codificación
canónica. Se conserva el txid no maleable. El compromiso nuevo tiene que entrar en la preimagen
autenticada del productor, no sólo ser una etiqueta de caché enviada junto al cuerpo.

El patrón de separar efectos y autorizaciones tiene precedente en
[ZIP-244, compromisos de bloque](https://zips.z.cash/zip-0244#block-header-changes). No se copian
sus hashes, formato o constantes automáticamente. El formato/activación de esa extensión,
incluida Orchard, permanece pendiente; no se ha añadido un campo ficticio al nodo.

Comprometer autorizaciones no garantiza recibirlas. Tampoco autoriza a usar ese compromiso
maleable por el productor como prioridad resistente al grinding.

## 5. Validación causal y aplicación son contextos distintos

**IDV-07 — No adaptar M0 cambiando el significado de errores reales.** La validación intrínseca
y de autorización necesita los datos de las salidas gastadas y el contexto causal apropiado.
La aplicación posterior usa el estado del orden canónico, donde otras transacciones pueden
haber consumido esas salidas. Una consulta UTXO que devuelve None no identifica por sí sola
si faltan datos, nunca existió la salida o la consumió un bloque anterior en ese orden.

Se requiere procedencia del estado y, cuando sea necesario, datos históricos de la salida para
validar autorización aunque luego se descarte el gasto por conflicto. No aceptar firmas sin
verificar sólo porque la transacción va a perder. Una aplicación nativa debe preservar además
timelocks, madurez, límites, balances y reglas Orchard; las claves sintéticas T/S no lo hacen.

**IDV-08 — Doble gasto interno no es conflicto entre cuerpos.** El validador actual rechaza
gastos duplicados dentro de un bloque (C-BLK-09). M0 permite secuencias sintéticas con repeticiones
que descarta al aplicar. Esos fixtures comprueban la máquina abstracta, no que ese cuerpo pase el
verificador nativo. La integración debe mantener la distinción, no relajar C-BLK-09 para conseguir
equivalencia con un fixture. Se preserva la evidencia histórica de M0 con esta limitación explícita.

## 6. Disponibilidad: condiciones de progreso todavía abiertas

Se conserva DA0 como perfil conservador: no sustituir al representante según velocidad de
descarga. Una respuesta inválida no elimina la obligación de obtener el cuerpo correcto.
La retención de cuerpos, incluso perdedores, puede detener el candidato; estos verificadores
no resuelven por sí solos esa dependencia.

Siguiente integración recomendada: estados explícitos de cabecera comprobada, cuerpo vinculado,
autorización verificada y ejecución aplicada; recuperación acotada desde varias fuentes; impedir
que una entrega inválida sustituya evidencia validada; producción de referencias con datos
completos disponibles. Son condiciones operativas a ensayar, no certificado de disponibilidad
ni prueba de viveza. Los límites de recursos existentes se miden antes de cambiarlos.

No se permite un timeout local que marque la cabecera inválida o elija otra copia económica.
Cualquier política de cambiar de candidato completo debe justificarse con el fork choice y su
modelo de seguridad; no se inventa aquí una regla de exclusión ni una nueva autoridad.

## 7. Puerta de integración

Para pasar de estos verificadores aislados a elegibilidad de producción faltan: dominio/retos
del billete entre flujos, procedencia autenticada del archivo y reloj, formato DAG con compromisos
completos, validación causal/aplicación incluidas las transacciones blindadas, y almacenamiento
con estados de validación y recuperación coherentes. Ventana y retarget se tratan después.

El [informe](INFORME.md) identifica pruebas efectivamente ejecutadas. Una prueba positiva bajo
una raíz KZG sintética acredita la aceptación de ese fixture por el verificador real, no una
historia de archivo ZEROX alcanzable ni el cierre de todas estas dependencias.
