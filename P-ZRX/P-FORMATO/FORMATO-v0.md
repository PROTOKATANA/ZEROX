# Formatos v0 del ZEROX híbrido (red dev de 0.0.1)

**Estado:** diseño del director, **no normativo**; se implementa en `ORDEN-W02` y rige la red dev de
0.0.1. **Fecha:** 2026-09-26. **Firma:** Claude. Parte del código reproducido en L01 (`zx-core` de
`9681061`) y cambia **solo** lo que el híbrido necesita. Identificadores `F-nn` de trabajo.

## 0. Principios

1. Lo antiguo que no cambia conserva sus bytes y sus vectores (codificación `C-ENC`, dominios
   `C-HASH`, `txid`/`auth_digest` `C-TX-01…06`, sighash `C-SIG`, `Lock` `C-TX-09`).
2. Lo nuevo entra por el **gancho de versión** que el SPEC antiguo reservaba (`C-TX-07`: «este
   campo es el gancho de extensión»), con un sub-digest propio en el `txid`: una transacción v1
   produce exactamente el mismo `txid` que en `9681061`.
3. Toda regla que dependía de una **altura** en la fase PoST queda **inactiva** en v0 (IPA B-10):
   no se inventa semántica de altura DAG.

## 1. Cabeceras

**F-01 · Cabecera PoW (`PoW_arranque`) = cabecera lineal antigua, sin cambios.** 92 bytes
(`branch_id u32 ‖ prev_hash 32 ‖ merkle_root 32 ‖ timestamp u64 ‖ bits u32 ‖ nonce u64 ‖ height u32`,
little-endian), preimagen PoW `"ZZKBlkHeader____" ‖ cabecera` (108 B), `block_hash = SHA3-256` de esa
preimagen, `hash < target` en U256 big-endian (`zx-core/src/preimage/block.rs`, `target.rs`). El
génesis usa este formato con `height = 0` y `prev_hash = 0`; su PoW **no** se comprueba (génesis
constructivo, `C-GEN-01`).

**F-02 · Cabecera PoST (`PoAS_PoT_DAG`) = cabecera DAG antigua** (`zx-core/src/preimage/dag.rs`:
prefijo fijo de 492 B, compromiso del cuerpo, `parent_count`, padres extra ascendentes, sello
Ed25519; 589–1 037 B). El padre seleccionado del bloque de transición es el `block_hash` del
terminal PoW (mismo tipo `BlockHash`, 32 B).

**F-03 · Campo `height` de la cabecera PoST: reservado, MUST ser 0** en v0. Motivo: la semántica de
altura DAG sigue pendiente (`C-HDR-02` antiguo, IPA B-10); un valor no nulo se rechaza
(`ErrFormato`). Se revisará cuando exista la regla.

**F-04 · Distinción de familias.** Por longitud y por tipo de mensaje: una cabecera PoW mide
exactamente 92 B y una PoST entre 589 y 1 037 B; los códecs son distintos y **no** se intenta
«adivinar» la familia de un buffer ambiguo: el llamante indica qué familia espera y el parser
rechaza cualquier otra longitud. Ambas usan `"ZZKBlkHeader____"` para `block_hash`; como las
codificaciones tienen longitudes disjuntas, no hay dos cabeceras de familias distintas con la misma
preimagen.

## 2. Transacciones

**F-05 · Versiones activas en v0:**

| `version` | Nombre | Entradas | Salidas | Campos de efecto extra | Dónde es válida |
|---|---|---|---|---|---|
| 1 | Transferencia / coinbase PoW | ≥ 1 (transferencia) · 0 (coinbase PoW, solo primera tx de un bloque PoW) | ≥ 1 | ninguno (idéntica a `9681061`) | ambas fases; coinbase solo PoW |
| 2 | Operación de garantía | según `tipo` | según `tipo` | `tipo u8 ‖ clave 32 B ‖ importe u64` | ambas fases (TRN-03, TRN-10); liberación solo PoST |
| 3 | Coinbase PoST | 0 | 0 | `clave 32 B ‖ importe u64` | solo primera tx de un bloque PoST |
| 4 | Evidencia (`C-EVP-03`) | 0 | 0 | reservada | **inactiva en v0**: se rechaza (`ErrVersionInactiva`) |

Cualquier otra versión se rechaza (`C-TX-07`).

**F-06 · Sub-digest de las versiones 2 y 3.** El `txid` de v1 no cambia. Para `version ∈ {2, 3}`
se añade, **después** de los sub-digest antiguos y en el mismo orden de composición que ellos, un
sub-digest `H_d("ZZKTxIdGarantia_", campos)` con los campos extra en el orden de la tabla,
little-endian. La etiqueta mide 16 B, como las demás de `C-HASH`, y se añade a la tabla cerrada de
etiquetas. El `auth_digest` compromete los testigos como antes (F-08).

**F-07 · Tipos de la versión 2:**

| `tipo` | Operación | Entradas | Salidas | Semántica (la aplica W03) |
|---|---|---|---|---|
| 1 | Depósito (`C-BON-02`) | ≥ 1 | ≥ 0 (cambio) | `Σ entradas = Σ salidas + importe`; acredita `importe` como pendiente a `clave` |
| 2 | Retiro (`C-BON-05`) | 0 | 0 | mueve `importe` de activo a en retirada de `clave` |
| 3 | Liberación (`C-BON-06`) | 0 | 0 | crea la salida implícita `(txid, 0) → PubKey{clave}` por `importe` |

Otros valores de `tipo` se rechazan. `importe > 0` y `≤ ZX_VALUE_SANITY_LIMIT` (`C-TX-12`). En v0
el depósito **no** paga tarifa: la igualdad es exacta (coincide con la orden T01, AMBIGÜEDAD-3).

**F-08 · Testigos de la versión 2.** `testigos.len() = entradas.len() + 1`. El último testigo es la
**firma de aceptación** de `clave`: Ed25519 bajo `clave` sobre el mismo sighash `SIGHASH_ALL` que
`C-SIG` define para la transacción (ZIP-215, `C-SIG-01`). Para retiro y liberación, que no tienen
entradas, hay exactamente un testigo. La versión 3 no lleva testigos (la autoriza el sello de la
cabecera, `C-HDR-04`).

**F-09 · Coinbase PoST (v3).** `clave` **MUST** ser igual a `sol.public_key` de la cabecera que la
contiene (`C-BON-03`: la coinbase no puede pagar a otra clave). El importe cumple TRN y D-T08 (lo
comprueba W03, no el parser).

**F-10 · Campos dependientes de altura, inactivos en v0.** En toda transacción: `lock_time = 0` y
`expiry_height = 0`, si no `ErrCampoInactivo`. La coinbase PoW **no** aplica `C-EMIT-04`
(`expiry_height = altura`) en v0. **No** se admiten salidas `Lock::Htlc` nuevas (su `timeout` es una
altura): `ErrCampoInactivo`. Las tres restricciones se levantarán cuando exista semántica de altura.

## 3. Cuerpo, red y génesis

**F-11 · Cuerpo.** `merkle_root` (PoW) y `body_commitment` (PoST) se calculan como en `9681061`,
sobre los `txid` y `auth_digest` de las transacciones de cualquier versión.

**F-12 · `CONSENSUS_BRANCH_ID` de la red dev:** los 4 primeros bytes, en little-endian, de
`SHA3-256("ZEROX hibrido red dev v0")`; si salen 0, se usa `1`. Se documenta el valor calculado.
Es distinto de cualquier identificador de `9681061`; entra en `txid`, sighash y cabecera
(`C-UPG-04/05`). Solo la red dev puede usarlo (D-P05).

**F-13 · Génesis dev.** Cabecera PoW con `height = 0`, `prev_hash = 0`, `bits` = límite de
dificultad dev, una única transacción v1 coinbase **sin salidas de valor** (`C-GEN-03`), y hash
**congelado** en una constante de la red dev (`C-GEN-07`). El relleno del segmento génesis para
PoAS (D-T05) se especifica en W05, no aquí.

## 4. Lo que este formato no decide

Algoritmo PoW de producción (A-12), semántica de altura DAG (B-10), `EvidenceTx` (C-04), registro de
sectores (D-*), formato de red (`C-WIRE`) más allá de los códecs de cabecera y transacción.
