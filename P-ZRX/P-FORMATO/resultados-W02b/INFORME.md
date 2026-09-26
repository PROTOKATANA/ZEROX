# INFORME.md — ORDEN-W02b

**ID:** W02b. **FORMATO v0.1 (F-15…F-18) en `zx-core`, `zx-consensus::transicion` y `zx-post`, con
oráculo de formato v0.1 y diferencial contra T01-D.**
**Ejecutor:** DeepSeek Harness, `deepseek-flash`, esfuerzo `high`.
**Zona única:** `/home/katana/zeo/ZEROX/deepseek/W02b/`.

## 1. Veredicto

**SUPERADO** en V1–V7.

- **V1** `cargo fmt --all -- --check`: limpio (`logs/V1-fmt.log`).
- **V2** `cargo clippy --workspace --all-targets --all-features --locked -- -D warnings`: limpio
  (`logs/V2-clippy.log`).
- **V3** `cargo test --workspace --all-features --locked`: **630 pasan, 0 fallan, 1 ignorado** (46
  bloques de test; `logs/V3-test.log`). Ningún test previo desaparece: 621 nombres en `ws.orig`,
  631 en `ws`, **0 perdidos y 10 añadidos** (`logs/comparacion-tests.txt`,
  `logs/tests-anadidos.txt`).
- **V4** Diferencial v0.1: **0 discrepancias** en los **2 055** casos base (1 947 con sufijo PoST) y
  **0** en los **3 939** negativos (2 024 `ErrNonce`); 257,85 s
  (`logs/V4-diferencial.log`).
- **V5** Tests propios F-15…F-18: 9 unitarios nuevos en `transicion::tests` (más el
  `diferencial_t01_negativos`) — ver §4.
- **V6** Oráculo de formato v0.1 (Julia): `Pkg.test()` **85/85** y `run.jl --seed 0x5a5a`
  (`logs/V6-oraculo-pkgtest.log`, `logs/V6-oraculo-tests.log`, `logs/V6-oraculo-run.log`); los casos
  **v1 no-coinbase** son byte a byte y `txid` a `txid` idénticos a los v0.
- **V7** `bash ci/dependencias-exactas.sh` → `OK — 20 dependencias con versión exacta`;
  `bash ci/frontera-crates.sh` → las 6 fronteras OK; `Cargo.lock` **idéntico** a `ws.orig` (sin
  dependencias nuevas; `logs/V7-deps.log`, `logs/V8-frontera.log`, `logs/lock-diff.txt`).

**Pregunta falsable, respondida:** ninguna operación de garantía se aplica dos veces (F-15; el
nonce se comprueba antes que el resto y el undo lo restituye), ninguna coinbase PoW repite `txid`
(F-16: el `expiry_height = altura` entra en el `txid`), el motor coincide con T01-D en todos sus
casos (0/2 055 y 0/3 939) y los `txid` y bytes v1 no-coinbase siguen siendo los de `9681061`.

## 2. Qué se hizo (con evidencia)

### `zx-core` (formato, `txid`, códec, forma)

1. `ExtensionTx::Garantia` gana `nonce: u64` y `ExtensionTx::CoinbasePost` gana `slot: u64`
   (`crates/zx-core/src/tx.rs`).
2. `extension_digest` escribe `tipo ‖ clave ‖ importe ‖ nonce` (v2) y `clave ‖ importe ‖ slot` (v3)
   dentro de `H_d("ZZKTxIdGarantia_", …)` (`src/preimage/tx.rs`).
3. `tx_a_bytes`/`tx_desde_bytes` codifican/decodifican los campos nuevos **entre las salidas y los
   testigos** (F-14), sin prefijo de longitud (`src/wire.rs`).
4. `validar_forma_tx` exime del `expiry_height == 0` a las **candidatas a coinbase PoW** (F-16
   contextual: el motor exige `expiry_height = altura`); el resto de reglas de forma no cambia
   (`src/forma.rs`, ver FD-1 en `PROGRESO.md`).
5. `tests/formato_v0.rs` lee los vectores v0.1 (14 casos), comprueba bytes/`txid`/mensaje, ida y
   vuelta del códec, negativos y firma de aceptación, y añade la igualdad v1 no-coinbase contra los
   vectores v0 y la sensibilidad al `nonce`/`slot`.

### `zx-consensus::transicion` (estado y reglas)

6. `Garantia::nonce_siguiente: u64` (0 al crearse) y `ErrorTransicion::ErrNonce`
   (`tipos.rs`, `error.rs`).
7. **F-15** al inicio de `aplicar_garantia` para depósito, retiro y liberación: una clave sin
   registro se crea con `nonce_siguiente = 0`, si el nonce no coincide se devuelve `ErrNonce` y si
   coincide se incrementa; el undo por delta restituye la garantía completa (`aplicar.rs`,
   `estado.rs`). En modo fusión el fallo se descarta con motivo `ErrNonce` (`fusion.rs` ya usaba
   `aplicar_tx`).
8. **F-16** en `aplicar_coinbase_pow`: `expiry_height == altura`, si no `ErrEmision` (`aplicar.rs`).
9. **F-17** en `aplicar_coinbase_post` y en `fusion_post`: `slot` de la v3 = `slot` del bloque que
   la contiene, si no `ErrEmision` (`aplicar.rs`, `fusion.rs`).
10. **F-18** la liberación crea la salida `(txid, 0)`; se elimina `prox_salida` de `Estado`,
    `Escalares` y `deshacer` (`aplicar.rs`, `tipos.rs`, `estado.rs`).
11. Tests V5 nuevos en `transicion/tests.rs` (ver §4); `transicion_prop.rs` actualizado a F-16/F-17.

### Arnés diferencial (`tests/diferencial_t01.rs`)

12. Lee `testdata/transicion-v0.1/vectores-transicion-v0.1.txt` y
    `…-negativos-v0.1.txt` (copiados sin editar de T01-D; `sha256` del fichero de entrada).
13. Construye coinbases PoW con `expiry_height = altura`, coinbases PoST con el `slot` del bloque y
    operaciones de garantía con el `nonce` del vector.
14. **Sin claves de salida artificiales**: cada salida se bloquea con la clave real de su dueño
    abstracto (F-15/F-16 hacen innecesarios los ids únicos de W03); no hubo colisiones.
15. Mapea el id abstracto de la salida implícita de `Liberacion` (contador `prox_salida` del
    oráculo) al `OutPoint` real `(txid, 0)` de F-18.
16. Traduce `GAR` con `nonce=`; correspondencias de W03 más `ErrNonce ↔ ErrNonce` y
    `ErrForma(DepositoSinEntradas) → ErrAutorizacion` (FD-7).

### `zx-post` (productor)

17. `construir_bloque` construye la coinbase v3 con el `slot` de su cabecera (`src/productor.rs`);
    el test de extremo a extremo lo comprueba (`tests/extremo_a_extremo.rs`).

### Oráculo de formato v0.1

18. `oraculo-formato-v0.1/` (copia del v0) con `nonce` en la v2 (F-15) y `slot` en la v3 (F-17) en
    `TxSpec`, `campos_extra`, `txid` y el códec; casos con nonces `0,7,1,2,0xdead,3,4,5,6` y slots
    `0,0x2a`; `runtests.jl` ampliado a 85 comprobaciones; vectores regenerados con
    `run.jl --seed 0x5a5a` y copiados a `ws/testdata/formato-v0.1/`.

## 3. Ficheros cambiados (23)

| Fichero | Por qué |
|---|---|
| `crates/zx-core/src/tx.rs` | `nonce` (v2) y `slot` (v3) en `ExtensionTx` (F-15/F-17) |
| `crates/zx-core/src/preimage/tx.rs` | `extension_digest` con los campos nuevos |
| `crates/zx-core/src/wire.rs` | códec F-14 con `nonce`/`slot` |
| `crates/zx-core/src/forma.rs` | exención F-16 para la candidata a coinbase PoW |
| `crates/zx-core/tests/formato_v0.rs` | vectores v0.1, v1 no-coinbase vs v0, nonce/slot |
| `crates/zx-consensus/src/transicion/tipos.rs` | `Garantia::nonce_siguiente`; `prox_salida` fuera |
| `crates/zx-consensus/src/transicion/error.rs` | `ErrNonce`; correspondencias del diferencial |
| `crates/zx-consensus/src/transicion/estado.rs` | undo sin `prox_salida` |
| `crates/zx-consensus/src/transicion/aplicar.rs` | F-15, F-16, F-17, F-18 |
| `crates/zx-consensus/src/transicion/fusion.rs` | F-17 en modo fusión |
| `crates/zx-consensus/src/transicion/tests.rs` | 9 tests V5 nuevos y constructores |
| `crates/zx-consensus/tests/transicion_prop.rs` | secuencias válidas con F-16/F-17 |
| `crates/zx-consensus/tests/diferencial_t01.rs` | arnés v0.1 (base + negativos), sin claves artificiales |
| `crates/zx-post/src/productor.rs` | coinbase v3 con `slot` |
| `crates/zx-post/tests/extremo_a_extremo.rs` | assert del `slot` de la coinbase |
| `testdata/formato-v0.1/` (3 ficheros) | vectores v0.1 + procedencia + sha256 |
| `testdata/transicion-v0.1/` (5 ficheros) | vectores v0.1 base y negativos + sha256 + procedencia |

## 4. Tests propios F-15…F-18 (V5)

| Test | Qué fija | Resultado |
|---|---|---|
| `dos_depositos_con_nonces_consecutivos_valen_y_la_repeticion_no` | nonces `n, n+1` válidos (activo 20, `nonce_siguiente = 2`); `n, n` ⇒ bloque inválido | OK |
| `repeticion_de_retiro_invalida_el_bloque_estricto` | repetir bytes de un retiro ⇒ `ErrNonce` | OK |
| `repeticion_de_liberacion_invalida_el_bloque_estricto` | repetir bytes de una liberación ⇒ `ErrNonce` | OK |
| `fusion_descarta_repeticion_con_err_nonce` | en fusión la repetición se descarta con `ErrNonce` | OK |
| `el_nonce_se_comprueba_antes_que_el_saldo` | nonce ≠ y saldo insuficiente ⇒ `ErrNonce` (orden F-15) | OK |
| `el_undo_restituye_el_nonce` | `deshacer(aplicar(E,B)) == E`, `nonce_siguiente` vuelve a 0 | OK |
| `la_coinbase_pow_exige_expiry_igual_a_la_altura` | `expiry ∈ {0,2,99}` a altura 1 ⇒ `ErrEmision`; `expiry=1` ⇒ OK | OK |
| `dos_coinbases_pow_iguales_salvo_altura_no_colisionan` | `txid` distintos y dos entradas de UTXO | OK |
| `la_coinbase_post_exige_el_slot_del_bloque` | `slot ∈ {0,2,99}` ≠ bloque 1 ⇒ `ErrEmision`; `slot=1` ⇒ OK | OK |
| `diferencial_t01_negativos` | 3 939 negativos con `ErrNonce` incluido | 0 discrepancias |

## 5. Faltas de definición detectadas antes de editar

Están en `PROGRESO.md` §«Faltas de definición detectadas ANTES de editar» (FD-1…FD-7): la más
relevante es **FD-1** (F-16 choca con la letra «`validar_forma_tx` sin cambios salvo la nueva
anchura»: sin eximir a la coinbase, F-16 sería inalcanzable) y **FD-7** (los negativos de T01-C, que
W03 nunca consumió, exigen la correspondencia `DepositoSinEntradas → ErrAutorizacion` y el mapeo del
id de la liberación a `(txid, 0)`). Se documentaron antes de aplicar cada lectura.

## 6. Entregables

| Fichero | Contenido |
|---|---|
| `ws/`, `ws.orig/` | copia de trabajo y prístina (idénticas al copiar) |
| `cambios.patch` | `diff -ruN … ws.orig ws`; 23 ficheros, 17 615 340 bytes; `git apply --check` OK |
| `oraculo-formato-v0.1/` | oráculo Julia v0.1 completo con su `INFORME.md` |
| `MIGRACION.sha256` | 155 huellas del árbol `ws`; `sha256sum -c` OK |
| `logs/` | V0-apply, V1-fmt, V2-clippy, V3-test, V4-diferencial, V6-*, V7-deps, V8-frontera, lock-diff, comparación de tests, listas de tests |
| `INFORME.md` | este documento |
| `PROGRESO.md` | faltas de definición y secuencia de trabajo |
| `HORAS.log` | marcas de tiempo |
| `env.sh` | entorno de la zona |

Entorno: `CARGO_HOME=<zona>/.cargo-home`, `CARGO_TARGET_DIR=<zona>/target`,
`CARGO_BUILD_JOBS=8`, `RUST_TEST_THREADS=8` (diferencial a 2); `JULIA_DEPOT_PATH=<zona>/.julia-depot`,
`env -u LD_LIBRARY_PATH`, `--threads=1`. Toolchain `nightly-2026-05-03`
(`rustc 1.97.0-nightly 20de910db`). Sin Python, sin secretos, sin commit ni push, nada escrito fuera
de `deepseek/W02b/`.

## 7. Entrada congelada

`sha256sum -c P-ZRX/P-FORMATO/ENTRADA-W02b.sha256` al empezar y como último paso:
**47/47 OK** (`logs/entrada-inicio.log`, `logs/entrada-final.log`).

## 8. Lo que esta orden NO demuestra

- **Persistencia, red y nodo**: el undo es en memoria; no hay storage ni reorg persistente.
- **Verificación de cabeceras**: PoW, PoT, PoAS y sellos siguen siendo entradas de `HechosCabecera`.
- **Motor DAG completo (ED-1…ED-3, orden del mergeset, `rojo_U3`)**: `aplicar_fusion` implementa las
  primitivas; la orquestación es de W06a. F-17 en fusión se prueba con los tests V5, no con vectores.
- **Peso (`C-WGT-02`)**: no hay `peso.rs` todavía; el orden de campos del códec sí respeta F-14.
- **F-16 en el oráculo de formato**: es contextual y no se modela en Julia; se cubre en Rust.
- **`aplicar_fusion` con dos liberaciones idénticas**: la salida `(txid, 0)` es única gracias a F-15,
  pero la igualdad de `OutPoint` se apoya en que el `txid` incluya el nonce.
- **La correspondencia `DepositoSinEntradas → ErrAutorizacion`** (FD-7) es del diferencial: la forma
  sigue rechazando el depósito sin entradas; solo se traduce el nombre para el oráculo, que comprueba
  la autorización antes de consumir entradas.
