# INFORME — ORDEN-SL4c (segundo lanzamiento)

**Ejecutor:** DeepSeek (`deepseek-flash`, esfuerzo `high`, DeepSeek Harness). **Fecha:** 2026-09-27.
**Zona:** `/home/katana/zeo/ZEROX/deepseek/SL4c/`. **Regla:** LINEO (`V-ZRX/LINEO.md`) leído íntegro
antes del código. **Entrada:** `P-ZRX/P-SLASHING/ENTRADA-SL4c.sha256` (22/22 en verde). **Base:** raíz
del repositorio en el commit de la entrada (`fa98bec`; la bitácora del director avanzó a `d8c4ecf` sin
tocar código), copiada a `ws.orig/` y `ws/`. **Modelo de la API:** `deepseek-flash`, esfuerzo `high`
(el entorno del arnés no expone un identificador de modelo adicional; es el perfil configurado).

## Veredicto

**SUPERADO.** La forma de la `EvidenceTx` v4 incluye ya `RAT-1` (`cbid` local) y `EV-01`/`EV-04`
(orden canónico), con la precedencia `entradas/salidas/testigos → cbid → orden` por transacción, y
`tx_desde_bytes` decodifica la v4. Los dos arneses diferenciales reproducen T01 **v0.5** (3 179 casos)
y T04 **v0.6** (2 108 casos) con **0 discrepancias** y la cobertura **idéntica** a la de los oráculos
(secciones de vectores, evidencia y `FORMA`). Los tres errores semánticos
(`ErrCbidAjeno`, `ErrOrdenCanonico`, `ErrEvidenciaConEntradas`) desaparecen del motor.

## Tabla de verificación

| Paso | Qué | Resultado |
|---|---|---|
| V0 | `sha256sum -c ENTRADA-SL4c.sha256`; suite completa sin cambios | **22/22** y suite verde (`logs/V0-baseline.log`, EXIT=0) |
| V1a | `diferencial_t01` (T01 v0.5, 3 179) + negativos (v0.2, 3 914) | **0 discrepancias**; cobertura idéntica a `cobertura-v0.5.txt` |
| V1b | `diferencial_t04` (T04 v0.6, 2 108) | **0 discrepancias**; cobertura idéntica a `cobertura-v0.6.txt` |
| V2 | ida y vuelta y rechazos del códec v4 (`zx-core/tests/formato_v0.rs`) | **OK** (210 idas y vueltas firmadas + truncamientos + sobrante + límites + extensión ajena) |
| V3 | `fmt --check`; `clippy … -D warnings`; `cargo test --workspace --all-features --locked`; `ci/dependencias-exactas.sh`; `ci/frontera-crates.sh` | ver abajo |

## Tabla de cobertura (casos por error de forma y por resultado; mínimo 1 por fila)

### T01 v0.5 (cobertura idéntica a `cobertura-v0.5.txt`)

| Contador | Casos | Contador | Casos |
|---|---:|---|---:|
| `cbid_ajeno` (`ErrForma(EvidenciaCbidAjeno)`) | 252 | `con_entradas` (`ErrForma(EvidenciaConEntradasOSalidas)`) | 120 |
| `orden_canonico` (`ErrForma(OrdenCanonicoInvalido)`) | 252 | `orden_descendente` (subtipo) | 132 |
| `ambos` (cbid ajeno + orden; gana cbid) | 120 | `orden_igual` (subtipo) | 120 |
| `aplicada` | 260 | `sin_saldo` | 120 |
| `duplicada` | 40 | `tardia` | 200 |
| `deshecha` | 380 | | |

### T04 v0.6 (cobertura idéntica a `cobertura-v0.6.txt`)

| Contador | Casos | Contador | Casos |
|---|---:|---|---:|
| `bloque_estructura` | 108 | `bloque_cbid` | 283 |
| `bloque_estructura_entradas` | 62 | `bloque_orden` | 243 |
| `bloque_estructura_salidas` | 37 | `bloque_orden_igual` | 115 |
| `bloque_estructura_ambos` | 9 | `bloque_orden_desc` | 128 |
| `bloque_estructura_cbid_orden` | 9 | `ev_cbid` / `ev_orden` | 283 / 243 |
| `ev_estructura` | 108 | `ev_orden_igual` / `ev_orden_desc` | 115 / 128 |
| `con_tx_estructura` | 108 | `ambos_cbid` | 161 |
| `con_tx_cbid` / `con_tx_orden` | 166 / 152 | `minimos_SL4cO` | **OK** |
| `EV aplicada` / `construida` / `duplicada` | 353 / 560 / 20 | `EV sin_saldo` / `tardia` / `deshecha` | 42 / 145 / 59 |

Los bloques con transacciones válidas que quedan inválidos están cubiertos por
`con_tx_estructura=108`, `con_tx_cbid=166` y `con_tx_orden=152`; la precedencia por transacción, por
`ambos_cbid=161` y `bloque_estructura_cbid_orden=9`.

### V2 (códec v4)

| Caso | Cobertura |
|---|---|
| ida y vuelta | 210 `EvidenceTx` v4 con cabeceras reales firmadas (mutando nº de padres 1…15) → bytes → tx y `txid` idénticos, resto vacío |
| truncada | todo prefijo estricto (incluida cada frontera de campo) rechazado |
| sobrante de 1 byte | no se absorbe (queda como resto de la transacción contenedora, F-14) |
| cabecera de 588 B | truncada ⇒ rechazada |
| región de 1 038 B | 1 037 B máx. + 1 byte: el parser consume la cabecera y deja el byte; sin H2 detrás ⇒ rechazada |
| `version = 4` con extensión de otra versión | rechazada (`Truncado`) |

## Qué se cambió (11 archivos; ver `cambios.patch` y `MIGRACION.sha256`)

- **`zx-core/src/error.rs`** — variante nueva `ErrorFormaTx::EvidenciaCbidAjeno` (RAT-1).
- **`zx-core/src/forma.rs`** — `validar_forma_tx_v4(tx, testigos, cbid_local: u32)`: tras la
  estructura vigente, `cbid` de ambas cabeceras (`EvidenciaCbidAjeno`) y orden canónico estricto por
  `pre_hash` (`OrdenCanonicoInvalido`). Sin valor por defecto para `cbid_local`.
- **`zx-core/src/wire.rs`** — `tx_desde_bytes` decodifica la v4 (`H1 ‖ H2`, cada cabecera
  autodelimitada por su `parent_count`) en vez de `VersionInactiva`; la activación la decide el motor.
- **`zx-core/tests/formato_v0.rs`** — tests V2 y actualización del rechazo de `version = 4` del códec.
- **`zx-consensus/src/transicion/aplicar.rs`** — `validar_bloque(bloque, evp)` pasa `evp.cbid` a la
  forma v4; `aplicar_evidencia` deja de comprobar forma (entradas/salidas, cbid, orden).
- **`zx-consensus/src/transicion/error.rs`** — se eliminan `ErrCbidAjeno`, `ErrOrdenCanonico` y
  `ErrEvidenciaConEntradas`; `nombre_t01` escribe `ErrForma(...)` para los tres.
- **`zx-consensus/src/transicion/fusion.rs`** — `validar_bloque(bloque, evp)`.
- **`zx-consensus/tests/evidencia.rs`** — los dos dirigidos esperan las variantes de forma.
- **`zx-consensus/tests/diferencial_t01.rs`** — lee T01 v0.5; cobertura con `ambos`,
  `orden_igual`, `orden_descendente`.
- **`zx-cadena/src/cadena.rs`** — `chequear_forma` comprueba la forma v4 **antes** de la garantía
  del productor (`ORDEN-SL4c` §3.2; sin esto `ErrGarantia` enmascaraba `ErrForma(...)`).
- **`zx-cadena/tests/diferencial_t04.rs`** — lee T04 v0.6; conserva `ent`/`sal` de la evidencia real;
  genera la sección `FORMA`; limita `contar_evidencia` a los grupos del oráculo.

**Testdata (solo añadir):** `testdata/transicion-v0.5/` (vectores `d72c5fd9…`, `.sha256` y
`cobertura-v0.5.txt`) y `testdata/estado-dag-v0.6/` (vectores `86348a48…`, `.sha256` y
`cobertura-v0.6.txt`), copiados byte a byte de los resultados de los oráculos. Los directorios
v0.4/v0.5 quedan históricos y ningún test los lee.

## Correspondencias de error nuevas, una a una

| Motor (`ErrorTransicion`) | Vector (`RES`/`nombre_t01`) |
|---|---|
| `ErrForma(ErrorFormaTx::EvidenciaCbidAjeno)` | `ErrForma(EvidenciaCbidAjeno)` |
| `ErrForma(ErrorFormaTx::OrdenCanonicoInvalido)` | `ErrForma(OrdenCanonicoInvalido)` |
| `ErrForma(ErrorFormaTx::EvidenciaConEntradasOSalidas)` | `ErrForma(EvidenciaConEntradasOSalidas)` |

Cobertura T01: las tres se cuentan como `cbid_ajeno`, `orden_canonico` y `con_entradas`
respectivamente. Cobertura T04: `bloque_cbid`/`bloque_orden`/`bloque_estructura` y sus desgloses.

## Falta de definición detectada (resuelta, declarada)

- **Límites de tamaño de cabecera `[589, 1 037] B` (V2).** La orden (decisión 4) pide rechazar
  «tamaño fuera de `[589, 1 037] B`», pero la codificación de la cabecera `PoAS_PoT_DAG` es
  **autodelimitada por `parent_count`** (offset fijo 524) y `parent_count ∈ [0, 15]` fija la longitud
  en `[589, 1 037]`: una cabecera que decodifica nunca puede tener una longitud fuera de rango. Lo
  observable es el **truncamiento** (588 B ⇒ `Truncado`) y el **sobrante** (una región de 1 038 B =
  cabecera máxima + 1 byte; el parser no absorbe ese byte y sin H2 detrás se rechaza). El parser
  delega en `dag_header_desde_bytes`, que ya acota `parent_count` (`DemasiadosPadres`). No se elige
  ninguna regla nueva: los límites quedan garantizados por construcción y se documentan así.

## Lo no demostrado

- La sección `run.jl` de `cobertura-v0.6.txt` (seed `0x5a5a`, 200 réplicas) no se reproduce desde el
  fichero de vectores: la genera otro `run.jl` que no está en la entrada congelada, igual que en SL-4a.
- El códec de red de la v4 **no** se prueba contra bytes de un peer real ni a través de `zx-p2p`/
  `zx-node` (vedados en esta orden): V2 cubre `tx_a_bytes`/`tx_desde_bytes` a nivel de `zx-core`.
- La activación de la v4 sigue siendo decisión del motor (`ParametrosEvidencia::evp`): con la
  evidencia inactiva, el motor conserva `ErrVersionInactiva`/`ErrFueraDeAlcanceV0` como antes.
- Compatibilidad con SL-4b1: la resuelve el director en la migración, como fija `ACLARACION-SL4c.md`.

## Cómo reproducir

```bash
source /home/katana/zeo/ZEROX/deepseek/SL4c/env.sh
cd "$Z/ws"
cargo test --workspace --all-features --locked
cargo test -p zx-consensus --test diferencial_t01 --locked -- --nocapture
cargo test -p zx-cadena   --test diferencial_t04 --locked -- --nocapture
cargo fmt --all -- --check
cargo clippy --workspace --all-targets --all-features --locked -- -D warnings
bash ci/dependencias-exactas.sh && bash ci/frontera-crates.sh
```

## V3 (resultado)

| Comando | Resultado |
|---|---|
| `cargo fmt --all -- --check` | **OK** |
| `cargo clippy --workspace --all-targets --all-features --locked -- -D warnings` | **OK** (0 warnings) |
| `cargo test --workspace --all-features --locked` | **OK** — 734 pasan, 0 fallan, 2 ignorados (731/0/2 antes; +3 tests V2) |
| `ci/dependencias-exactas.sh` | **OK** — 23 dependencias exactas |
| `ci/frontera-crates.sh` | **OK** — 9/9 fronteras |

Logs: `logs/V0-baseline.log`, `logs/diferenciales.log`, `logs/diferencial-t04-r4.log`,
`logs/tests-core-evidencia.log`, `logs/v3-fmt-ci.log`, `logs/v3-clippy2.log`, `logs/v3-tests-r2.log`.
