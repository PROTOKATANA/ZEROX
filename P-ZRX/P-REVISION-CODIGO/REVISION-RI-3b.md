# REVISIÓN RI-3b — revisión independiente de la evidencia y el castigo (SL-4a)

**Revisor de la revisión:** Claude (director). **Fecha:** 2026-09-26 (≈ 23:09). **Ejecutor:** subagente Sonnet,
22:49–23:07. Evidencia: `resultados-RI-3b/` (informe y diff de los dos tests de reproducción). **Veredicto:
ACEPTADA.** Un hallazgo alto confirmado; el resto (EV-05…EV-28, RAT-2′, RAT-3, undo) sin hallazgos.

| # | Hallazgo | Comprobación del director | Decisión |
|---|---|---|---|
| H1 (alta, CONFIRMADO) | Una `EvidenceTx` con `consensus_branch_id` ajeno (RAT-1) o con las cabeceras fuera del orden canónico (EV-04) se comprueba en la capa **semántica** (`crates/zx-consensus/src/transicion/aplicar.rs:660-673`: `ErrCbidAjeno`, `ErrOrdenCanonico`) y no en la de **forma** (`crates/zx-core/src/forma.rs`, `validar_forma_tx_v4`); en fusión, el bloque que la lleva se **acepta** con la transacción descartada | Leído. El contrato es explícito: RAT-1 «si no, `ErrForma`» y EV-04 «rechazo de forma… `ErrForma(OrdenCanonicoInvalido)`»; y `CONTRATO-ESTADO-DAG-v0.md` (tabla de la línea 46): forma de transacción ⇒ **bloque inválido**. `ErrorFormaTx::OrdenCanonicoInvalido` existe y nunca se construye. **Los oráculos T01/T04 de SL-3b se desviaron igual del contrato** y la revisión SL-3b (del director) no lo vio: error del director | **Se corrige el código y los oráculos al contrato** (no se enmienda el contrato): son comprobaciones sin contexto (no dependen del orden de fusión), y el orden canónico es la regla que hace única la codificación (principio de F-04: el parser rechaza lo no canónico). Coste para el honesto: ninguno (el detector de SL-4b2 construye siempre el orden canónico y solo indexa cabeceras de la red local). Órdenes: **SL-4c-O** (oráculos Julia T01/T04 y vectores nuevos) y **SL-4c** (Rust: forma, motor, arneses y decodificación de red de la v4) |
| Nota (FD-5) | `tx_desde_bytes` rechaza **toda** v4 (`crates/zx-core/src/wire.rs:306`): con la evidencia activa, un bloque que la lleve **no se puede recibir por red**. Declarado en SL-4a como FD-5; SL-4b2 lo habría encontrado tarde | Leído | Se decodifica la v4 en **SL-4c** (la activación la decide el motor, como ya hace con `ErrVersionInactiva`) |

Mitigantes que no cambian la decisión: hoy la v4 no es alcanzable por red (FD-5), no hay castigo falso ni escape
(la transacción malformada no tiene efecto) y el oráculo reproduce el mismo comportamiento (no hay división
motor↔oráculo).
