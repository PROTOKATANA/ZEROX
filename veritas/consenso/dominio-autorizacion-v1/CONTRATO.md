# DAV-v0.1 — Dominio, vinculación, autorización y evidencia contextual

Fecha: 2026-09-11. **Contrato candidato con implementación experimental aislada.**
No activado. No cambia SPEC, wire, fork choice, emisión, ventana, retarget ni espera de Cortex.
Refina [IDV](../identidad-disponibilidad-v1/CONTRATO-VALIDACION.md) y conserva
[CBE](../contrato-billete-v1/CONTRATO.md) como contrato abstracto de adjudicación y undo.

## 1. Decisiones de esta variante

| Problema | Decisión candidata | Estado exacto |
|---|---|---|
| Dominio económico | Uno por red, anclado al génesis definitivo; no renace por fork, inyección o upgrade | Clave exacta experimental; valor de red y codificación de producción no fijados. |
| Identidad entre retos | `(red, slot, pk, sector, history_size, piece_offset)`; reto/raíz/rango/prueba no crean derecho nuevo | Igualdad fijada como política económica, no como equivalencia de coste físico. |
| Compatibilidad del reloj | Comparar prefijos en el slot histórico correspondiente, incluyendo N efectivo | Comparador de descriptores declarados; no verifica su origen ni PoT. |
| Vinculación de cuerpo | Longitud y vector ordenado de pares `(txid, auth_digest)`, incluida coinbase | Proyección exacta y comparación implementadas; aún sin compromiso en cabecera DAG autenticada. |
| Autorización | Componer controles nativos y firmas sobre snapshot owned e inmutable | Implementado para el perfil transparente explícito de §4. |
| Conservación | Caché por cuerpo completo y snapshot; sólo tokens privados del compositor | Implementada en memoria; no ledger ni RocksDB. |
| Reorg local de evidencia | Contexto exacto, identidad de instancia y revisión no reciclable | Cambio de vista y publicación condicional; no ejecuta un reorg económico. |

## 2. Dominio económico y flujos

**DAV-01.** El dominio lo configura el protocolo, no lo declara libremente el productor.
La comparación local rechaza otra red; no la trata como un nuevo billete pagable aquí.
El `CONSENSUS_BRANCH_ID` de las firmas sigue verificándose, pero no reinicia derechos económicos.
Cambiar codificación o versión debe preservar la igualdad y los consumos anteriores.

**DAV-02.** Distintas representaciones de la misma coordenada/slot tienen un solo derecho
por historia aplicada. Esto incluye alternativas de reto, raíz y rango si resultan admisibles.
La clave no incluye chunk, PoS, sello, coinbase, padres, hash de bloque ni versión de caché.
No implica que todos esos contextos sean simultáneamente admisibles ni que servirlos cueste igual.

**DAV-03.** Se conserva el consumo contextual reversible de CBE. Cambiar de rama significa
deshacer al prefijo común y reproducir la nueva historia, no unir ledgers finales ni usar una
lista mundial de pagos observados. El nuevo prototipo no reimplementa ese ledger ni conecta
todavía el token transparente con la máquina económica CBE.

**DAV-04.** R-FIN-5 se comprueba en `slot(X)` para cada X del pasado real. Diferencias futuras
no eliminan pasado común anterior. En el descriptor candidato se incluyen origen, semilla,
semántica de transición y N inicial, más eventos efectivos `(activación, entropía, N)`.
N no puede omitirse mientras su derivación única no esté demostrada. Un evento que activa en s
pertenece al prefijo en s; si activa después, todavía no pertenece.

El instrumento normaliza el orden de anuncios y rechaza activaciones repetidas. Su origen
resume el estado inicial; por convención de representación sólo admite eventos posteriores.
**Eso no decide cómo será la inyección inicial del génesis real.** La cobertura y el conjunto
de antecesores son oráculos suministrados; ausencia de cobertura devuelve pendiente. No se
extiende la desigualdad de slots del padre seleccionado a todos los padres. Tampoco se acredita
el horizonte adicional de autoría `s+D` por comparar sólo el prefijo a s.

Coste honesto explícito: abandonar una rama puede perder su adjudicación; dos trabajos en
contextos distintos con la misma coordenada/slot no tienen prometidos dos pagos. No se afirma
«sólo pierde quien equivoca». La elección entre pruebas/retos sigue siendo parte del adversario.
La derivación y sus obligaciones están en [DOMINIO.md](DOMINIO.md).

## 3. Compromiso esperado frente a clave local de evidencia

**DAV-05.** El contrato semántico de cuerpo transparente es:

```text
(n, [(txid(tx_i, CBID), auth_digest(testigos_i)) para i=0..n-1])
```

`n` es la longitud real; debe haber una lista de testigos por transacción. Se conserva orden,
multiplicidad y coinbase, incluido el digest real de su lista vacía. No rellenar listas ausentes,
no omitir duplicados y no reemplazar el digest vacío por un sentinel. La proyección txid debe
coincidir con el Merkle declarado. La validez de duplicados, estructura y firmas se comprueba aparte.

Este objeto no contiene hash de cabecera, padres, sello ni PoS. La futura preimagen autenticada
del productor deberá comprometerlo, evitando autorreferencia. En el prototipo se compara el vector
exacto: no se fija etiqueta/hash compacto, tamaño/offset de cabecera ni formato Orchard.

**DAV-06.** `autorizar_con_compromiso` exige igualdad con el compromiso esperado y luego llama
al compositor real. Su procedencia se suministra externamente: hoy **no** está autenticada por
la cabecera PoST/DAG. Construir una proyección correcta no acredita firmas ni perfil soportado.
Una autorización distinta puede ser válida y, aun así, no corresponder al cuerpo esperado.

`body_key` tiene otra finalidad: huella local de TODO el candidato, incluida cabecera, autorizaciones
y perfil. Puede identificar evidencia pero **no** entrar como campo en esa misma cabecera: sería
circular. Los hashes locales del prototipo no son hashes nuevos de consenso ni compromisos
firmados por el productor. No se cambia txid.

Comprometer el cuerpo no impide elegir otro antes de firmar. No se da por neutralizado el grinding
ni se presupone unicidad de firma. Con la cabecera actual siguen existiendo variantes de autorización
que comparten blockhash; esta variante no corrige retroactivamente el formato existente.

## 4. Composición de autorización y contexto

**DAV-07.** El compositor experimental admite explícitamente:

- transacciones transparentes v1, perfil `SIGHASH_ALL`, `lock_time=0`;
- PubKey, MultiSig y ambas vías HTLC mediante `sighash` y `satisface` nativos;
- datos de salidas gastadas completos, altura, madurez, balances, fees y límites nativos;
- controles adicionales necesarios de coinbase, listas y MultiSig antes de delegar el cuerpo.

Los otros cinco HashType definidos, Orchard (incluso un bundle vacío), `lock_time != 0` y
gastos de transacciones del mismo cuerpo devuelven `NoSoportado`. No se inventa un byte HashType,
una política de MTP o una semántica intra-cuerpo. Ese resultado **no** significa invalidez de consenso.

**DAV-08.** El snapshot es owned, inmutable y hasheado desde todos sus datos/estados y parámetros.
No acepta que un ID arbitrario certifique datos distintos. Su constructor comprueba coherencia
estructural, no procedencia DAG. `completo=true` es una declaración del proveedor; no es una prueba.
Un outpoint omitido sigue siendo dependencia, nunca inexistencia inferida automáticamente.

Se distinguen desconocido/omitido, gastado declarado e inexistencia declarada. `GastadoEnSnapshot`
no afirma que las firmas hayan verificado ni que exista un conflicto legítimo de ejecución.
Para validar autorización histórica de un gasto perdedor faltan sus datos de salida y la vista
causal apropiada; no se reutiliza la vista de ejecución como si fuera su pasado original.

**DAV-09.** `AutorizacionPerfil` sólo se construye pasando el compositor; conserva el cuerpo por
valor y expone lecturas inmutables. Su huella de cuerpo y contexto no puede relabelarse desde
un consumidor Rust seguro. No es certificado portátil de consenso, PoAS/PoT, procedencia de
archivo, aceptación UTXO/Orchard ni disponibilidad global. Véase [AUTORIZACION.md](AUTORIZACION.md).

## 5. Almacén de evidencia y publicación local

**DAV-10.** La caché sólo retiene tokens del compositor por `(body_key, context_key)`.
Una entrega mala no obtiene token, no envenena el blockhash y no reemplaza evidencia buena.
Un duplicado exacto es idempotente. Dos autorizaciones válidas pueden coexistir bajo claves
distintas; si se agota capacidad, se devuelve un fallo local sin invalidar ni expulsar silenciosamente.

**DAV-11.** La visibilidad exige clave exacta elegida externamente y versión esperada.
La versión contiene `(instancia, contexto, revisión)`; cada cambio de contexto y publicación
avanza la revisión con aritmética comprobada. A→B→A no resucita una solicitud vieja. Otra caché
del proceso no puede reutilizar su ticket. Contadores agotados fallan sin publicar parcialmente.
Son referencias volátiles, sin serialización para reutilizarlas después de reiniciar el proceso.

El consumidor no obtiene «cualquier cuerpo con este blockhash». Retención por llegada puede
afectar aciertos de caché, pero no fija representante, color, ejecución o cobro. No existe
`insertar_validado(bytes, true)` accesible al consumidor.

**DAV-12.** Los límites locales de entradas y peso retenido no son parámetros de consenso ni
una medición de RAM. No hay expulsión/poda ni caché negativa en este prototipo. Construcción del
snapshot, candidatos en vuelo y transporte necesitan presupuestos adicionales antes de integrar.
`&mut self` serializa sus cambios; se ensayan intercalados de publicaciones, no un motor concurrente.

Esta atomicidad de memoria es distinta del batch de ledger+UTXO+Orchard+emisión+conteo+undo.
No se implementó aquí durabilidad, WAL, recuperación tras corte ni persistencia RocksDB.
Las obligaciones generales están en [ALMACENAMIENTO.md](ALMACENAMIENTO.md).

## 6. Resultado y siguiente frontera

El [informe](INFORME.md) distingue pruebas ejecutadas de propiedades documentales.
El contrato ya permite estudiar ventana y retarget con una igualdad económica explícita y
una composición de autorización delimitada, pero cualquier evaluación seguirá siendo condicional
a admisión, contexto, multiplicidad de ensayos y disponibilidad. No usarlo para publicar una tabla
de finalidad de producción sin integrar y verificar esas hipótesis.

Siguen pendientes los proveedores causales/autenticados de archivo/reloj/UTXO, la cabecera DAG
firmada con compromiso de cuerpo, la capa blindada, la transición económica conjunta y disponibilidad
adversarial. DA0 puede detenerse por retención de cuerpos aunque esta caché se comporte correctamente.
