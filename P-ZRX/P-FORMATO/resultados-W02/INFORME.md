# INFORME.md — ORDEN-W02

**Formatos v0 del híbrido en `zx-core`, con oráculo Julia independiente.**
Sesión: DeepSeek Harness, modelo `deepseek-flash` («DeepSeek-V41-Flash»), esfuerzo `high`.
Fecha: 2026-09-26, 01:23–01:36 +02:00. Zona única: `/home/katana/zeo/ZEROX/deepseek/W02/`.
Sin Python, sin dependencias Rust nuevas, sin commit ni push, nada escrito fuera de la zona.
Base: workspace de la raíz en el commit `29b6bd6` (W01), copiado a `ws.orig/` y `ws/`.

**Pregunta falsable:** «Las transacciones v2/v3 y la red dev de FORMATO-v0 se pueden codificar,
hashear y validar estructuralmente de forma canónica, con `txid` idénticos entre Rust y un oráculo
Julia escrito aparte, sin cambiar un solo byte de los `txid` y vectores v1 de `9681061`.»
**Veredicto: NO REFUTADA — SUPERADO.** Los 19 tests nuevos de `formato_v0.rs` comparan con el
oráculo Julia byte a byte (wire, `txid`, mensaje de aceptación) y V1–V7 cumplen.

## 1. Veredicto por paso

| Paso | Comando (desde `ws/`, entorno §4) | Veredicto |
|---|---|---|
| V1 | `cargo fmt --all -- --check` | **OK** (exit 0; `logs/V1-fmt.log`) |
| V2 | `cargo clippy --workspace --all-targets --all-features --locked -- -D warnings` | **OK** (exit 0; 0 avisos; `logs/V2-clippy.log`) |
| V3 | `cargo test --workspace --all-features --locked` | **OK** (exit 0; **182** pasan, 0 fallan; `logs/V3-test.log`) |
| V4 | `Pkg.test()` + `run.jl --seed 0x5a5a` | **OK** (80/80 tests; vectores generados; `logs/V4-julia-test.log`, `logs/V4-julia-run.log`) |
| V5 | nombres de test de V3 frente a `deepseek/W01/logs/V3-test.log` | **OK** (161 antiguos, **0** desaparecen; `logs/V5-faltantes.txt` vacío) |
| V6 | `git show 29b6bd6:<fichero>` vs `ws/` para tests y `testdata/` antiguos | **OK por criterio** (12 ficheros: 10 idénticos; 2 difieren solo por la inserción mecánica `extension: ExtensionTx::Ninguna` que §3.2 exige; **ningún vector cambia**; `logs/V6-diff.txt`) |
| V7 | `bash ci/dependencias-exactas.sh` | **OK** (10 dependencias exactas; `logs/V7-deps.log`) |
| Entrada | `sha256sum -c ENTRADA-W02.sha256` al inicio y al final | **OK** en ambos (4/4 huellas) |

Desglose de V3: `zx-core` = 146 (lib) + 4 (`cavp_sha3_256`) + 1 (`ed25519_no_unicidad`) + **19**
(`formato_v0`, nuevos) + 1 (`oraculo_julia`) + 2 (`parsers_dag_prop`) + 4 (`vectores_dag`) = **177**;
`zx-pot` = 1 + 3 + 1 = **5**; doc-tests 0. Antes de W02 eran 161: los 161 siguen con el mismo
nombre y pasan.

## 2. Archivos cambiados y por qué

**Producción (`crates/zx-core/src/`):**

| Fichero | Cambio | Motivo |
|---|---|---|
| `tx.rs` | `ExtensionTx`, `TipoGarantia`, campo `Tx.extension`, `Tx::es_candidata_coinbase_pow` | §3.2 y F-05/F-07 |
| `error.rs` | `ErrorFormaTx` (variantes por caso) y `EncodingError::{VersionInactiva,VersionDesconocida,TipoGarantiaInvalido}` | §3.6 y errores específicos de §6 |
| `hash.rs` | `TAG_TXID_GARANTIA` = `ZZKTxIdGarantia_`, `TAG_TXSIG_GARANT` = `ZZKTxSigGarant__`; `TAGS_FIJAS` 15→17 | §3.4, F-06 y F-08 |
| `preimage/tx.rs` | `extension_digest` v2/v3, `txid` con la extensión, `mensaje_aceptacion`, `verificar_aceptacion` | §3.3 y F-06/F-08 |
| `wire.rs` | `tx_a_bytes`/`tx_desde_bytes` con los campos extra de F-14 y rechazo de versión/tipo fuera de rango | §3.5 y F-14 |
| `forma.rs` (**nuevo**) | `validar_forma_tx`, `validar_forma_cabecera_post` | §3.6 y §3.7 |
| `red.rs` | variante `Red::Dev`, `MAGIC_DEV`, `CBID_RED_DEV` | §3.8 y F-12 |
| `address.rs` | `HRP_DEV = "dzzk"` y su `match` | §3.8 |
| `lib.rs` | `pub mod forma` y reexport de todo lo nuevo | §3.3/§3.6/§3.7 |
| `preimage/dag.rs`, `wire_dag.rs` | literales de test con `extension: ExtensionTx::Ninguna` | §3.2 (coherencia del tipo) |

**Tests:**
- `crates/zx-core/tests/formato_v0.rs` (**nuevo**, 19 tests): vectores del oráculo, ida y vuelta,
  tres anclas v1 antiguas, negativos de §6, cabecera PoST y firma de aceptación.
- `crates/zx-core/tests/vectores_dag.rs` y `oraculo_julia.rs`: solo import + `extension: Ninguna`.

**Datos:**
- `testdata/formato-v0/vectores.txt` + `PROCEDENCIA.md` (**nuevos**), copiados del oráculo.
- `testdata/` antiguo: **intacto** (V6).

**Sin cambios:** `Cargo.toml`, `Cargo.lock`, `rust-toolchain.toml`, `ci/`, `.github/`.

## 3. Decisiones de nombres de API

- `ExtensionTx { Ninguna, Garantia { tipo, clave, importe }, CoinbasePost { clave, importe } }` en
  `zx_core::tx`; `TipoGarantia { Deposito=1, Retiro=2, Liberacion=3 }` con `byte()`/`desde_byte()`.
- `Tx::es_candidata_coinbase_pow(&self) -> bool`: marca consultable, no una comprobación contextual.
- `validar_forma_tx(tx, testigos) -> Result<(), ErrorFormaTx>` y
  `validar_forma_cabecera_post(&DagBlockHeader) -> Result<(), ErrorFormaTx>` en `zx_core::forma`
  (módulo nuevo; mantiene el códec en `wire.rs` y la validación en su sitio).
- `mensaje_aceptacion(tx, cbid) -> [u8; 32]` y
  `verificar_aceptacion(tx, &[u8], cbid) -> Result<(), ErrorFormaTx>` en `zx_core::preimage::tx`,
  reexportadas en la raíz junto a `txid`/`sighash`.
- `Red::Dev`, `MAGIC_DEV` (`db347847`), `CBID_RED_DEV` (`0xa8b466a7`), `HRP_DEV` (`dzzk`).
- Etiquetas internas `TAG_TXID_GARANTIA`/`TAG_TXSIG_GARANT`, añadidas a `TAGS_FIJAS` y cubiertas por
  el test de unicidad (que ahora exige 17).

## 4. Casos negativos cubiertos (§6)

Cada uno con error específico y su test en `formato_v0.rs`:

| Caso | Error |
|---|---|
| versión 0, 5, `u32::MAX` | `ErrorFormaTx::VersionDesconocida` (y `EncodingError::VersionDesconocida` en el códec) |
| versión 4 | `VersionInactiva { version: 4 }` |
| v1 con extensión (en memoria) | `ExtensionIncoherente { version: 1 }` |
| v2 con `tipo` 0, 4, `0xff` | `EncodingError::TipoGarantiaInvalido` (códec) |
| depósito sin entradas | `DepositoSinEntradas` |
| retiro con entradas / salidas | `RetiroConEntradas` / `RetiroConSalidas` |
| liberación con entradas / salidas | `LiberacionConEntradas` / `LiberacionConSalidas` |
| v2 con `n_wit ≠ n_in + 1` | `NumeroDeTestigosInvalido` |
| testigo de aceptación de 63 / 65 B | `TestigoAceptacionLongitud` |
| `importe = 0` | `ImporteCero` |
| `importe > ZX_VALUE_SANITY_LIMIT` | `Amount` no lo representa; el códec devuelve `ImporteFueraDeRango` |
| `lock_time ≠ 0` / `expiry_height ≠ 0` | `CampoInactivo` |
| salida `Lock::Htlc` | `SalidaHtlc` |
| v3 con entradas / salidas / testigos | `EntradasEnCoinbasePost` / `SalidasEnCoinbasePost` / `TestigosEnCoinbasePost` |
| extensión truncada | `EncodingError::Truncado` (cortes 14..=56) |
| bytes sobrantes | el parser no consume nada tras el último testigo (resto no vacío) |
| cabecera PoST `height = 1` y `u32::MAX` | `AlturaPostNoCero` |
| firma de aceptación: otra clave, otro `txid`, otra `CBID`, 63/65 B | `ErrorFormaTx` / `FirmaInvalida` |

Además, el test `cada_campo_de_la_extension_y_la_version_cambia_el_txid` demuestra que cambiar
`version`, `tipo`, `clave`, `importe`, la ausencia de extensión o el `CBID` cambia el `txid`
(modelo de amenaza de §5: colisión de dominio).

## 5. Definición imperfecta detectada antes de actuar (y resolución)

1. **§9(b) pide tres `txid` v1 antiguos y solo existen dos congelados** (`txid1`, `txid2` en
   `testdata/vectores-cabecera-dag/vectores.txt`). **Resolución:** se anclan esos dos y, como
   tercero, el `txid` v1 del escenario `tx_ejemplo()` de los tests unitarios de `preimage/tx.rs`,
   congelado con el código antiguo (`29b6bd6`) antes de tocar nada y reproducido por Julia. Los
   tres coinciden.
2. **V6 (comparación byte a byte) choca con §3.2**, que obliga a añadir `extension` a los literales
   de test antiguos. **Resolución:** se cumple el **criterio** de V6 (los vectores antiguos no
   cambian); el diff de `oraculo_julia.rs` y `vectores_dag.rs` es solo el import y
   `extension: ExtensionTx::Ninguna`, como exige §3.2. Anotado, no improvisado.
3. **«bytes sobrantes» en un parser que devuelve el resto por diseño** (lo necesita
   `cuerpo_desde_bytes`). **Resolución:** el parser no consume esos bytes (resto no vacío
   verificable) y `validar_forma_tx` rechaza la incoherencia v1+extensión en memoria.
4. **`importe > ZX_VALUE_SANITY_LIMIT` no es representable en `Tx`** porque `Amount` lo impide por
   construcción. **Resolución:** se cubre en `Amount` y en el códec (bytes hostiles), documentado.
5. **Ubicación de los vectores**: el oráculo escribe
   `oraculo-formato-v0/testdata/formato-v0/vectores.txt`; se copia sin editar a
   `ws/testdata/formato-v0/`. Los vectores **no** se generan desde Rust.

## 6. Lo que esta orden NO demuestra

- **Reglas contextuales:** posición de la coinbase (`C-BLK-07`), saldos y `Σ entradas = Σ salidas +
  importe`, madurez, `clave == sol.public_key` (F-09). Son de W03.
- **Peso (`C-WGT-02`)** y la igualdad «longitud serializada = peso»: `peso.rs` no se ha portado.
- **Génesis (F-13)** y la constante del hash de génesis.
- **Semántica de estado / máquina de estados**, UTXO, undo.
- **PoW, PoAS, PoT, GHOSTDAG, nodo, red**: fuera de alcance.
- **Firmas de entrada** de v1/v2: el parser no las verifica (necesitan el UTXO); solo se verifica la
  firma de aceptación de v2.
- **Que la CI funcione en GitHub**: no se ejecutó allí.
- **Independencia de la especificación**: dos implementaciones de acuerdo no prueban que la
  especificación sea correcta; una ambigüedad las haría coincidir en el mismo error.

## 7. Presupuesto y trazas

Presupuesto: 2 h de reloj, 8 hilos, 16 GiB de RAM, 20 GiB de disco. Consumo real ≈ 13 min de reloj;
`ws` 2,2 MiB, `ws.orig` 2,1 MiB, `oraculo-formato-v0` 60 KiB, `.cargo-home` 718 MiB, `target`
693 MiB, `.julia-depot` 7,4 MiB; total ≈ 1,4 GiB, muy por debajo de los 20 GiB; sin tensión de RAM.
Toolchain: `cargo`/`rustc` `nightly-2026-05-03`; Julia 1.13.0.
Artefactos: `ws/`, `ws.orig/`, `cambios.patch`, `MIGRACION.sha256` (54 huellas, `sha256sum -c` OK),
`oraculo-formato-v0/` (con `INFORME.md`), `logs/`, `PROGRESO.md`, `HORAS.log`.

## 8. Resumen final (≤ 40 líneas)

1. W02 cumple: formatos v0 (F-01…F-14 en lo que toca) implementados en `crates/zx-core`.
2. `Tx` gana `extension` con `ExtensionTx::{Ninguna,Garantia,CoinbasePost}` y `TipoGarantia`.
3. Coherencia `1⇔Ninguna`, `2⇔Garantia`, `3⇔CoinbasePost`; v4 inactiva y versiones raras rechazadas.
4. `txid` de v1 intacto byte a byte; v2/v3 añaden `H_d("ZZKTxIdGarantia_", campos)`.
5. Firma de aceptación F-08 implementada y verificada con `ed25519-zebra` (ZIP-215).
6. Códec F-14 v1/v2/v3 con campos extra entre salidas y testigos; parser sin pánicos.
7. `validar_forma_tx` y `validar_forma_cabecera_post` cubren todos los negativos de §6.
8. `Red::Dev` con `magic = db347847`, `CBID = a8b466a7` (ambos recalculados en test) y HRP `dzzk`.
9. Oráculo Julia independiente (solo stdlib) con 80/80 tests propios: NIST y 3 `txid` v1 antiguos.
10. `testdata/formato-v0/vectores.txt`: 14 casos generados por el oráculo, no por Rust.
11. `formato_v0.rs`: 19 tests; Rust y Julia coinciden en wire, `txid` y mensaje de aceptación.
12. V1 fmt, V2 clippy `-D warnings`, V3 tests, V4 oráculo, V5 nombres, V6 vectores, V7 deps: OK.
13. 161 tests antiguos siguen pasando con su nombre; 182 pasan en total, 0 fallan.
14. `Cargo.lock`/`Cargo.toml` sin tocar; ninguna dependencia Rust nueva.
15. Dos ficheros de test antiguos difieren solo por `extension: ExtensionTx::Ninguna` (§3.2 vs V6).
16. No demuestra reglas contextuales, peso, génesis ni semántica de estado: eso es W03+.
17. Queda para W03 la aplicación de saldos/posición de coinbase y para W05 la cabecera PoST real.
18. Veredicto: **SUPERADO**; la pregunta falsable no queda refutada.
