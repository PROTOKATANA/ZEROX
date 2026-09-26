# INFORME.md — ORDEN-W05b2-R

**ID:** W05b2-R. **Rebase de W05b2 sobre la raíz actual.**
**Ejecutor:** DeepSeek Harness, `deepseek-flash`, esfuerzo `high`.
**Zona única:** `/home/katana/zeo/ZEROX/deepseek/W05b2R/`.

## 1. Veredicto

**SUPERADO.** El parche de W05b2 se aplica sobre la raíz actual salvo sus tres ficheros ya migrados
por W06c/W03-R (`Cargo.toml`, `Cargo.lock`, `ci/frontera-crates.sh`), que se rehacen a mano con el
mínimo cambio. Ningún conflicto adicional. Todos los tests de la raíz actual conservan su nombre y se
suman exactamente los de W05b2 (104). El lock solo añade `zx-post` y sus aristas, **sin cambiar
ninguna versión**. Los dos guardianes de CI dan OK.

## 2. Qué se hizo (con evidencia)

1. **Copia.** `Cargo.toml`, `Cargo.lock`, `rust-toolchain.toml`, `crates/`, `testdata/`, `ci/` y
   `.github/` de la raíz actual a `ws.orig/` y `ws/`, con el enlace `PDF -> ../../../PDF` (clon del
   proyecto, excluido de la migración) en ambos. Comprobado que la raíz viva es idéntica byte a byte
   al árbol de W03-R (`diff -rq` vacío en `crates`, `Cargo.toml`, `ci`, `testdata`,
   `rust-toolchain.toml`, `Cargo.lock`), lo que permite reutilizar su `target` sin recompilar todo.
2. **Parche.** En `ws`, `git apply -p1 --exclude=Cargo.toml --exclude=Cargo.lock
   --exclude=ci/frontera-crates.sh deepseek/W05b2/cambios.patch` → aplica limpio (`logs/V0-apply.log`,
   `exit=0`). Los 16 ficheros nuevos de `crates/zx-post` y `crates/zx-pot/examples/medir_pot.rs` quedan
   **idénticos** a `deepseek/W05b2/ws` (`diff -rq`). Los tres ficheros excluidos no se tocan
   (`diff -q` sin cambios en `ws.orig` vs `ws` antes de la edición a mano).
3. **Rehecho a mano (mínimo).**
   - `Cargo.toml`: una línea, `"crates/zx-post",` añadida a los miembros (conservando `zx-p2p`).
   - `ci/frontera-crates.sh`: una línea,
     `frontera("zx-post"; ["zx-core", "zx-pot", "zx-dag", "zx-poas"]),` (conservando la regla de
     `zx-p2p`).
   - `Cargo.lock`: **un único** `cargo metadata --format-version 1 >/dev/null` dentro de `ws`, sin
     `cargo update`. `logs/lock-diff.txt`: **+19 líneas, 0 eliminadas, 0 cambios de versión**.
4. **Cargo (`--locked`).** `cargo fmt --all -- --check` limpio (`logs/V1-fmt.log`);
   `cargo clippy --workspace --all-targets --all-features --locked -- -D warnings` limpio, 8,75 s
   (`logs/V2-clippy.log`); `cargo test --workspace --all-features --locked` (`logs/V3-test.log`).
5. **CI.** `bash ci/dependencias-exactas.sh` → `OK — 20 dependencias con versión exacta`
   (`logs/V7-dependencias.log`). `bash ci/frontera-crates.sh` → seis fronteras OK, incluida
   `zx-post → {zx-core,zx-pot,zx-dag,zx-poas}` (`logs/V8-frontera.log`).
6. **No pérdida de tests.** `--list` de `ws.orig` (517) y de `ws` (621):
   **0 perdidos, 104 añadidos** (`logs/comparacion-tests.txt`). El extremo a extremo del bloque de
   transición (`extremo_a_extremo::v5_tres_semillas_construyen_y_comprueban_el_primer_bloque_post`)
   pasa.
7. **Parche reconstruye el árbol.** `cambios.patch` aplicado con `git apply -p1` sobre una copia
   limpia de `ws.orig` produce un árbol **idéntico** a `ws` (`diff -rq -x PDF` vacío).

## 3. Recuentos

| Prueba | Resultado |
|---|---|
| `cargo test --workspace --all-features --locked` | **620 pasan, 0 fallan, 1 ignorado** (46 bloques) |
| Tests de la raíz actual (`ws.orig`, `--list`) | 517 |
| Tests de `ws` (`--list`) | 621 |
| Perdidos respecto a la raíz | **0** (`logs/comparacion-tests.txt`) |
| Añadidos por W05b2 | **104** (21 unit + 11 + 12 + 6 + 3 + 9 + 33 + 7 + 2 doctests) |
| `extremo_a_extremo` | 12/12 (V5 3/3 semillas, V6 9 negativos + 1 pendiente, V7 núcleo PoT) |
| `ci/dependencias-exactas.sh` | OK — 20 dependencias con versión exacta |
| `ci/frontera-crates.sh` | OK — `zx-consensus`, `zx-dag`, `zx-poas`, `zx-farmer`, `zx-post`, `zx-p2p` |

El único test ignorado es el banco preexistente `bench_coloreo_mergeset_maximo` (`#[ignore]`), igual
que en la raíz.

## 4. Lock

`logs/lock-diff.txt` contiene el diff íntegro. Único bloque añadido:

```
@@ -4720,6 +4720,25 @@
 ]
 
 [[package]]
+name = "zx-post"
+version = "0.0.0"
+dependencies = [
+ "blake3",
+ "ed25519-zebra",
+ "primitive-types",
+ "subspace-core-primitives",
+ "subspace-kzg",
+ "subspace-verification",
+ "thiserror 2.0.20",
+ "zx-consensus",
+ "zx-core",
+ "zx-dag",
+ "zx-farmer",
+ "zx-poas",
+ "zx-pot",
+]
+
+[[package]]
 name = "zx-pot"
```

- Raíz actual (`ws.orig/Cargo.lock`): `4da3e37c69fa0e374d7d7b0d5931cb502d3c83f8459485a3318efa1f2ce2257d`
- Rebase (`ws/Cargo.lock`): `c113c061beef3e46f4fad651a1add9212402e8b7ddc7385a3ba0ad83d6ac7d62`
- **Sin cambios de versión**: solo se añade el paquete `zx-post` y su lista de dependencias (aristas;
  incluye `zx-consensus`/`zx-farmer` porque son `dev-dependencies`, que también entran en el lock).

## 5. Notas de ejecución (sin efecto en el resultado)

1. **`--exclude` literal.** Como `ws/` vive dentro del repositorio git de la raíz, `git apply`
   antepone la ruta relativa al repo y `--exclude` no coincide. Se ejecutó con
   `GIT_CEILING_DIRECTORIES=$ZONE` (como W03-R), que impide a git ver el `.git` padre; entonces el
   patrón coincide con la ruta del parche.
2. **`--locked` y `cargo fmt`.** `cargo fmt` no admite `--locked` (es `rustfmt`, no compilación); se
   ejecutó `cargo fmt --all -- --check`. `--locked` se aplicó a `clippy` y `test`.
3. **Caché.** `CARGO_HOME` y `CARGO_TARGET_DIR` en la zona. El `target` se copió de W03-R (que
   acababa de construir la misma raíz), lo que evitó recompilar las dependencias externas;
   `CARGO_HOME = .cargo-home` es copia de `~/.cargo` (2,6 GiB), superset del de W05b2, para no
   depender de red. `CARGO_BUILD_JOBS=8`, `RUST_TEST_THREADS=8`.
4. **Orden de test y `comm`.** La primera comparación de nombres usó `sort` en `LC_ALL=C` pero `comm`
   en el locale por defecto, produciendo 8 falsos «perdidos» que aparecían también como «añadidos».
   Repetida con `LC_ALL=C` en `sort` y `comm`: 0 perdidos.
5. **`LINEO.md`.** Documento de cálculo Julia (CPU) / C++/CUDA (GPU); esta orden es un rebase de un
   port Rust de consenso. Se cumplen sus reglas aplicables (sin Python, determinismo explícito,
   presupuesto declarado, evidencia reproducible). No procede crear ninguna auditoría Julia.
6. **Sin secretos, sin commit ni push, nada escrito fuera de la zona.**

## 6. Entregables

| Fichero | Contenido |
|---|---|
| `cambios.patch` | `diff -ruN -x target -x .cargo-home -x PDF ws.orig ws`; 20 ficheros, 299 329 bytes; aplica limpio sobre `ws.orig` y reconstruye `ws`. sha256 `f116ca55…` |
| `MIGRACION.sha256` | 147 huellas del árbol `ws`; `sha256sum -c` OK. sha256 `2d20fd6c…` |
| `logs/` | `V0-apply`, `V0-apply-check`, `V0-metadata`, `V1-fmt`, `V2-clippy`, `V3-test`, `V7-dependencias`, `V8-frontera`, `lock-diff`, `comparacion-tests`, `raiz-test-list`, `ws-test-list` |
| `INFORME.md` | este documento |
| `HORAS.log` | marcas de tiempo |

Entorno: `CARGO_HOME=<zona>/.cargo-home`, `CARGO_TARGET_DIR=<zona>/target`,
`CARGO_BUILD_JOBS=8`, `RUST_TEST_THREADS=8`, `GIT_CEILING_DIRECTORIES=<zona>`; toolchain pineado
`nightly-2026-05-03` (`rustc 1.97.0-nightly 20de910db`). Presupuesto 1 h / 8 hilos / 16 GiB no
agotado (~11 min).
