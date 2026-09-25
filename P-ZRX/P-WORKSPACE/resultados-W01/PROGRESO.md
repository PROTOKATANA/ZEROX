# PROGRESO.md — ORDEN-W01

Workspace Rust nuevo (`ws/`) con `zx-core` y `zx-pot` portados **byte a byte** de `9681061`,
vectores, `Cargo.lock` recortado, CI nueva y verificación V1–V6. Zona única:
`/home/katana/zeo/ZEROX/deepseek/W01/`.

## Entrada congelada — comprobación de INICIO (2026-09-26T01:15:52+02:00)

Comando (desde `/home/katana/zeo/ZEROX`):

```
LC_ALL=C sha256sum -c P-ZRX/P-WORKSPACE/ENTRADA-W01.sha256
```

Salida literal:

```
P-ZRX/P-WORKSPACE/ORDEN-W01.md: OK
V-ZRX/LINEO.md: OK
exit=0
```

## Entrada congelada — comprobación FINAL (2026-09-26T01:18:00+02:00, último paso)

Mismo comando, salida literal:

```
P-ZRX/P-WORKSPACE/ORDEN-W01.md: OK
V-ZRX/LINEO.md: OK
exit=0
```

## Pasos ejecutados

1. **Lectura íntegra** de `ORDEN-W01.md`, `V-ZRX/LINEO.md`, `PLAN-0.0.1.md` (§3,
   D-P01/D-P03), `INFORME.md` de L01 y `logs/S1-zx-core.log` + `S2-zx-pot.log`.
2. **Extracción** de `9681061` con `git archive` a `extract/` (staging, fuera de `ws/`), sin
   escribir en `.git` ni en el árbol de trabajo del repositorio.
3. **Montaje de `ws/`** por copia byte a byte de `crates/zx-core/`, `crates/zx-pot/`,
   `testdata/nist-cavp/`, `ci/dependencias-exactas.sh`, `Cargo.lock` y `rust-toolchain.toml`.
   `veritas/consenso/vectores-cabecera-dag/resultados/vectores.txt` → `testdata/vectores-cabecera-dag/vectores.txt`.
4. **`Cargo.toml` raíz** recortado: 2 miembros, sin `exclude`, `[workspace.dependencies]` de
   31 → 10 entradas, `[workspace.package]`/`[workspace.lints]` idénticos. **CI nueva** de dos
   jobs. **`PROCEDENCIA.md`** del vector del oráculo.
5. **Única edición de código autorizada**: `crates/zx-core/tests/oraculo_julia.rs` (ruta del
   vector + comentario inline que la explica).
6. **Recorte del lock**: copia del antiguo y `cargo metadata --format-version 1 >/dev/null`
   (sin `--locked`, sin `cargo update`, sin `generate-lockfile`). 496 → 130 paquetes.
7. **Verificación del subconjunto** con `awk`/`sort`/`comm` (sin Python): 0 paquetes del lock
   nuevo ausentes en el antiguo → `logs/lock-subconjunto.txt`, `VERIFICACION_LOCK=OK`.
8. **V1–V6** desde `ws/` con el entorno de §4 y `--locked`.

## Veredicto por paso

| Paso | Resultado | Evidencia |
|---|---|---|
| V1 `cargo fmt --all -- --check` | **OK** (exit 0, sin diferencias) | `logs/V1-fmt.log` |
| V2 `cargo clippy ... --locked -- -D warnings` | **OK** (exit 0, 0 warnings) | `logs/V2-clippy.log` |
| build CI `cargo build --workspace --all-features --locked` | **OK** (exit 0) | `logs/V2b-build.log` |
| V3 `cargo test --workspace --all-features --locked` | **OK** (exit 0; zx-core 156, zx-pot 5, 0 fallidas) | `logs/V3-test.log` |
| V4 nombres de test vs L01 | **OK** (161/161 idénticos, `diff` exit 0) | `logs/V4-tests.txt` |
| V5 `bash ci/dependencias-exactas.sh` | **OK** (10 dependencias exactas) | `logs/V5-deps.log` |
| V6 `diff -r` de crates vs `9681061` | **OK** (solo la región autorizada) | `logs/diff-crates.txt` |
| Lock subconjunto | **OK** (0 ausentes) | `logs/lock-subconjunto.txt` |
| `MIGRACION.sha256` | **OK** (50 archivos, `sha256sum -c` exit 0) | `MIGRACION.sha256` |

## Reproducir

```bash
Z=/home/katana/zeo/ZEROX/deepseek/W01
cd "$Z"/ws
export CARGO_HOME="$Z"/.cargo-home CARGO_TARGET_DIR="$Z"/target
export CARGO_BUILD_JOBS=8 RUST_TEST_THREADS=8 RUSTFLAGS=
cargo fmt --all -- --check
cargo clippy --workspace --all-targets --all-features --locked -- -D warnings
cargo build --workspace --all-features --locked
cargo test --workspace --all-features --locked
bash ci/dependencias-exactas.sh
bash logs/verifica-lock.sh
bash logs/verifica-V4-tests.sh
diff -r "$Z"/extract/crates "$Z"/ws/crates
```

## Presupuesto

Tope 1 h de reloj, 8 hilos, 16 GiB RAM, 20 GiB disco. Consumo real: ≈ 3 min de reloj,
8 jobs, `target` 622 MiB + `.cargo-home` 718 MiB + `ws` 2,1 MiB + `extract` 2,2 MiB; carga del
sistema ≈ 0,9–1,5 (1 min). **No agotado.**
