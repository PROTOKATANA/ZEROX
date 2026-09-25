# INFORME.md — ORDEN-W01

**Workspace Rust nuevo (`ws/`) con `zx-core` y `zx-pot` portados byte a byte de `9681061`.**
Sesión: DeepSeek Harness, modelo `deepseek-flash` («DeepSeek-V41-Flash»), esfuerzo `high`.
Fecha: 2026-09-26, 01:15–01:18 +02:00. Zona única:
`/home/katana/zeo/ZEROX/deepseek/W01/`. Sin Python, sin `git commit`/`push`, nada escrito fuera de
la zona.

**Pregunta falsable:** «`zx-core` y `zx-pot` de `9681061`, fuera de su workspace original, con el
lock recortado y la misma toolchain, pasan exactamente los mismos tests que en L01 (156 y 5), con
`fmt`, `clippy -D warnings` y `--locked`». **Veredicto: NO REFUTADA — SUPERADO.** V1–V6 cumplen.

## 1. Veredicto por paso

| Paso | Comando (desde `ws/`, entorno §4) | Veredicto |
|---|---|---|
| V1 | `cargo fmt --all -- --check` | **OK** (exit 0; sin diferencias) |
| V2 | `cargo clippy --workspace --all-targets --all-features --locked -- -D warnings` | **OK** (exit 0; 0 warnings) |
| V2b (CI) | `cargo build --workspace --all-features --locked` | **OK** (exit 0) |
| V3 | `cargo test --workspace --all-features --locked` | **OK** (exit 0; `zx-core` **156**, `zx-pot` **5**, 0 fallidas, 0 ignoradas) |
| V4 | nombres de test de V3 vs `L01/logs/S1-zx-core.log`+`S2-zx-pot.log`, ordenados + `diff` | **OK** (161/161 idénticos; `diff` exit 0) |
| V5 | `bash ci/dependencias-exactas.sh` | **OK** (10 dependencias con versión exacta) |
| V6 | `diff -r extract/crates ws/crates` | **OK** (solo la región autorizada de `oraculo_julia.rs`) |
| Lock | subconjunto name+version (shell/`awk`/`comm`) | **OK** (496 → 130 paquetes; **0** del nuevo ausentes en el antiguo) |
| Entrada | `sha256sum -c ENTRADA-W01.sha256` al inicio y al final | **OK** en ambos |

Desglose de V3 (una línea por binario): `zx-core` = 144 (lib) + 4 (`cavp_sha3_256`) + 1
(`ed25519_no_unicidad`) + 1 (`oraculo_julia`) + 2 (`parsers_dag_prop`) + 4 (`vectores_dag`) =
**156**; `zx-pot` = 1 (lib) + 3 (`contexto_verificado`) + 1 (`diferencial`) = **5**; doc-tests 0.

Evidencia: `logs/V1-fmt.log`, `logs/V2-clippy.log`, `logs/V2b-build.log`, `logs/V3-test.log`,
`logs/V4-tests.txt` (+ `V4-diff-raw.txt`), `logs/V5-deps.log`, `logs/diff-crates.txt`,
`logs/lock-subconjunto.txt`, `logs/verifica-lock.sh`, `logs/verifica-V4-tests.sh`,
`logs/diff-cargo-toml.txt`.

## 2. Archivos creados

- `ws/` (50 archivos, listados y hasheados en `MIGRACION.sha256`):
  - `Cargo.toml`, `Cargo.lock` (recortado), `rust-toolchain.toml` (idéntico a `9681061`).
  - `crates/zx-core/` y `crates/zx-pot/` completos (byte a byte salvo la excepción declarada).
  - `testdata/nist-cavp/` (5 archivos, con `README.md`).
  - `testdata/vectores-cabecera-dag/vectores.txt` + `PROCEDENCIA.md`.
  - `ci/dependencias-exactas.sh` (sin cambios).
  - `.github/workflows/zerox-ci.yml` (CI nueva).
- `logs/`: `V1-fmt.log`, `V2-clippy.log`, `V2b-build.log`, `V3-test.log`, `V4-tests.txt`,
  `V4-diff-raw.txt`, `V5-deps.log`, `diff-crates.txt`, `lock-subconjunto.txt`,
  `lock-metadata.log`, `diff-cargo-toml.txt`, `verifica-lock.sh`, `verifica-V4-tests.sh`,
  `run-V2-V3.sh`.
- `MIGRACION.sha256` (50 huellas, rutas relativas a `ws/`; `sha256sum -c` → OK).
- `INFORME.md`, `PROGRESO.md`, `HORAS.log`.
- Fuera de `ws/` (no se migran): `extract/` (staging de `9681061`), `.cargo-home/` (copia del de
  L01; el original no se tocó), `target/`.

## 3. Diferencias exactas con `9681061`

Ficheros de `ws/` idénticos a la extracción de `9681061` **salvo**:

1. **`crates/zx-core/tests/oraculo_julia.rs`** — única edición de código autorizada:
   - el `PathBuf` pasa de `["veritas","consenso","vectores-cabecera-dag","resultados","vectores.txt"]`
     a `["testdata","vectores-cabecera-dag","vectores.txt"]` (`CARGO_MANIFEST_DIR` sigue siendo
     `crates/zx-core` y la raíz sigue a dos niveles);
   - se actualiza el comentario inline inmediato que explicaba esa ruta.
   - **No** se tocó el doc-comentario de módulo, que aún cita la ruta histórica
     `lineo/vectores-cabecera-dag/resultados/vectores.txt` (decisión de cambio mínimo; ver §6).
   - `diff -r` literal: `logs/diff-crates.txt` (3 líneas de comentario + 4 de ruta, nada más).
2. **`Cargo.toml` raíz** — reescrito según §3.3: `members` de 11 → 2 (solo `crates/zx-core`,
   `crates/zx-pot`); eliminada la lista `exclude`; `[workspace.dependencies]` de 31 → 10 entradas.
   `[workspace.package]`, `[workspace.lints.clippy]`, `[workspace.lints.rust]` y
   `[profile.release]` **idénticos**. Diff literal en `logs/diff-cargo-toml.txt`.
3. **`Cargo.lock`** — recortado por `cargo metadata` (496 → 130 paquetes). **Ninguna versión
   cambió**: todo `name`+`version` del nuevo existe con la misma versión en el antiguo
   (0 ausentes, `logs/lock-subconjunto.txt`).
4. **Nuevos** (no existen en `9681061` en esa ubicación): `testdata/vectores-cabecera-dag/`
   (`vectores.txt` copiado de `veritas/...`, + `PROCEDENCIA.md`) y `.github/workflows/zerox-ci.yml`.
5. **`rust-toolchain.toml`**: idéntico (`cmp` → IDENTICO).
6. **No portado** (órdenes posteriores): `zx-consensus`, `zx-storage`, `zx-node`, `zx-p2p`,
   `zx-mempool`, `zx-rpc`, `zx-wallet`, `zx-lightwalletd`, `zx-scanner`, `prototipos/`,
   `veritas/`, el clon `PDF/autonomys-subspace`, `SPEC.md`, `ci/` restante, docs de raíz.

## 4. Dependencias del workspace: conservadas y eliminadas

**Conservadas (10, con su versión exacta antigua y su comentario):**
`ed25519-zebra = "=4.2.0"`, `sha3 = "=0.12.0"`, `bech32 = "=0.12.0"`,
`primitive-types = "=0.14.0"`, `aes = "=0.9.3"`,
`blake3 = { version = "=1.8.7", default-features = false }`, `cpufeatures = "=0.2.17"`,
`thiserror = "=2.0.20"`, `hex = "=0.4.3"`, `proptest = "=1.11.0"`.
(Usadas por `zx-core`/`zx-pot` y sus dev-dependencies; `V5` cuenta 10.)

**Eliminadas del workspace (21):** `orchard`, `halo2_proofs`, `incrementalmerkletree`,
`blake2b_simd`, `siphasher`, `capnp`, `capnpc`, `serde`, `rocksdb`, `libp2p`, `jsonrpsee`,
`tokio`, `async-trait`, `futures`, `anyhow`, `tracing`, `tracing-subscriber`, `clap`,
`futures_ringbuf`, `criterion`, `tempfile`. Todas ellas solo las usaban los crates no portados.

## 5. Hallazgos: definición imperfecta detectada antes de actuar

1. **§3.1 vs §5/V6 — «el comentario» y «la línea autorizada».** §3.1 autoriza cambiar la ruta y
   «actualizar el comentario que explica la ruta»; §5 y V6 piden que el `diff -r` muestre «solo la
   línea autorizada». Hay dos comentarios que citan rutas: el doc-comentario de módulo (que ya
   citaba una ruta vieja, `lineo/...`) y el comentario inline del `PathBuf`. **Resolución:** se
   actualizó solo el comentario inline (el que explica la ruta del vector) y **no** el
   doc-comentario de módulo, para no rebasar la excepción autorizada. Consecuencia declarada: el
   doc-comentario conserva una ruta histórica obsoleta; es cosmético y no afecta a la compilación
   ni al test.
2. **§3.3 no menciona `[profile.release]`.** El `Cargo.toml` de `9681061` lo tiene. **Resolución:**
   se conserva íntegro, por D-P03 («portado con el menor cambio»).

Ninguno de los dos impide cumplir la orden; no se improvisó nada más.

## 6. Riesgos

- **La CI no se ha ejecutado en GitHub.** V2/V3/V5 reproducen localmente los comandos de los jobs
  en la máquina de referencia, no en `ubuntu-latest`. El YAML es nuevo y no está validado por un
  runner real.
- **Carga de la máquina no controlada del todo**: `uptime` ≈ 0,9–1,5 (1 min) durante la sesión.
  Los tiempos de los logs no son una medida de rendimiento.
- **El oráculo Julia no se ejecutó**; sus vectores son copia histórica del commit, no regenerados
  (declarado en `PROCEDENCIA.md`).
- **El recorte del lock dependió del caché/red de cargo**: se usó la copia de `.cargo-home` de L01;
  sin ese caché el `cargo metadata` podría requerir red. Aun así, la comprobación de subconjunto
  demuestra que ninguna versión se movió.
- **El doc-comentario obsoleto** de `oraculo_julia.rs` (ver §5.1), que puede corregirse en una
  orden posterior si el director lo desea.
- **`--all-features` no ejercita features** porque ninguno de los dos crates declara `[features]`;
  el resultado es equivalente al de L01, que no pasó features.

## 7. Lo que esta orden NO demuestra

- **No demuestra ni cambia ninguna regla de consenso híbrido.** Los 161 tests prueban el contrato
  **antiguo** de `zx-core`/`zx-pot`; un test verde aquí no transfiere ninguna garantía al diseño
  nuevo (D-P03: portado sin cambios ≠ adaptación).
- **No demuestra que la CI funcione en GitHub**: no se ejecutó allí.
- **No demuestra que el oráculo Julia siga siendo reproducible** en el árbol nuevo: no se ejecutó
  Julia ni se recomputaron los vectores.
- **No demuestra nada sobre la adaptación**: rutas nuevas de producción, formatos híbridos,
  cabeceras PoST, máquina de estados, PoW, PoAS/PoT, GHOSTDAG, nodo, red.
- **No demuestra nada sobre `zx-consensus`, `zx-storage`, `zx-node`, `zx-p2p`, `zx-mempool`,
  `zx-rpc`, `zx-wallet`, `zx-lightwalletd`, `zx-scanner`** ni sobre el clon de Autonomys: están
  fuera de alcance.
- **No valida ningún parámetro antiguo** (`T`, `N`, `SHIFT`, `COINBASE_MATURITY`, `k`, `S_max`…)
  para el híbrido.
- **No demuestra que la carga de la máquina estuviera controlada** (§6).
- **No se ejecutó ninguna prueba `#[ignore]`,** no había; y no se tocó `rocksdb`.

## 8. Presupuesto y trazas

Presupuesto: 1 h de reloj, 8 hilos, 16 GiB RAM, 20 GiB disco. Consumo ≈ 3 min de reloj, 8 jobs,
`target` 622 MiB, `.cargo-home` 718 MiB, `ws` 2,1 MiB, `extract` 2,2 MiB; RAM sin tensión.
Toolchain efectiva: `cargo 1.97.0-nightly (4f9b52075 2026-05-01)` /
`rustc 1.97.0-nightly (20de910db 2026-05-02)` (canal `nightly-2026-05-03`).
Trazas: `HORAS.log`, `PROGRESO.md`, `logs/`, `MIGRACION.sha256`, `extract/` (staging íntegro para
futuras comprobaciones).

## 9. Resumen final

`ws/` está listo para que el director lo migre a la raíz: `zx-core` (156 tests) y `zx-pot`
(5 tests) idénticos a L01, `fmt`/`clippy -D warnings`/`build`/`test --locked` en verde, lock
recortado sin cambiar ninguna versión y CI nueva de dos jobs. La única edición de código es la
región autorizada de `oraculo_julia.rs`. Queda pendiente, por diseño, ejecutar la CI en GitHub.
