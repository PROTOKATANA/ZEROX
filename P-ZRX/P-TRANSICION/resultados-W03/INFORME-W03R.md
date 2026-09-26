# INFORME.md — ORDEN-W03-R

**ID:** W03-R. **Rebase de W03 sobre la raíz actual.**
**Ejecutor:** DeepSeek Harness, `deepseek-flash`, esfuerzo `high`.
**Zona única:** `/home/katana/zeo/ZEROX/deepseek/W03R/`.

## 1. Veredicto

**SUPERADO.** El parche de W03 se aplica sobre la raíz actual salvo el trozo de `Cargo.lock`, que
`cargo` regenera con **una sola línea añadida**. Ningún conflicto adicional. Todos los tests de la
raíz actual conservan su nombre y se suman los de W03. El diferencial `diferencial_t01` da
**0 discrepancias en 2 055 casos** (1 947 con sufijo PoST). Los dos guardianes de CI dan OK.

## 2. Qué se hizo (con evidencia)

1. **Copia.** `Cargo.toml`, `Cargo.lock`, `rust-toolchain.toml`, `crates/`, `testdata/`, `ci/` y
   `.github/` de la raíz a `ws.orig/` y `ws/`, con el enlace `PDF -> ../../../PDF` (clon del
   proyecto, excluido de la migración) en ambos. Al cerrar se volvió a comprobar contra la raíz
   viva: los caminos copiados seguían **idénticos** (la raíz avanzó de commit durante la ventana,
   de `533ef3c` a `2237024`, pero sin tocar esos ficheros).
2. **Parche.** En `ws`, `git apply -p1 --exclude=Cargo.lock deepseek/W03/cambios.patch` → aplica
   limpio (`logs/V0-apply.log`, `exit=0`). Comprobado con `cmp` que los 13 ficheros nuevos y los
   4 modificados quedan **byte a byte idénticos** a `deepseek/W03/ws`. El trozo de `Cargo.lock`
   no se aplica; el resto del parche no se toca.
3. **Lock.** Un único `cargo metadata --format-version 1 >/dev/null` dentro de `ws` (sin
   `cargo update`). `logs/lock-diff.txt`: **+1 línea** (`"ed25519-zebra",` en las dependencias de
   `zx-consensus`), **0 líneas eliminadas y 0 cambios de versión**.
4. **Cargo (`--locked`).** `cargo fmt --all -- --check` limpio (`logs/V1-fmt.log`);
   `cargo clippy --workspace --all-targets --all-features --locked -- -D warnings` limpio
   (`logs/V2-clippy.log`, 9,06 s); `cargo test --workspace --all-features --locked`
   (`logs/V3-test.log`).
5. **CI.** `bash ci/dependencias-exactas.sh` → `OK — 20 dependencias con versión exacta`
   (`logs/V7-deps.log`). `bash ci/frontera-crates.sh` → las cinco fronteras OK
   (`logs/V8-frontera.log`).
6. **Diferencial.** `diferencial_t01` con `--nocapture`: `logs/V4-diferencial.log`.

## 3. Recuentos

| Prueba | Resultado |
|---|---|
| `cargo test --workspace --all-features --locked` | **516 pasan, 0 fallan, 1 ignorado** (37 bloques de test) |
| Tests de la raíz actual (`ws.orig`, `--list`) | 503 |
| Tests de `ws` (`--list`) | 517 |
| Perdidos respecto a la raíz | **0** (`comm` vacío, `logs/comparacion-tests.txt`) |
| Añadidos por W03 | **14** (11 unitarios en `transicion/tests.rs`, 1 `diferencial_t01`, 2 proptest) |
| `diferencial_t01` | **2 055 casos, 1 947 con PoST, 0 discrepancias**, 162,28 s |
| `ci/dependencias-exactas.sh` | OK — 20 dependencias con versión exacta |
| `ci/frontera-crates.sh` | OK — `zx-consensus`, `zx-dag`, `zx-poas`, `zx-farmer`, `zx-p2p` |

El único test ignorado es el banco preexistente `bench_coloreo_mergeset_maximo`
(`#[ignore]`, «banco; ejecutar con `--ignored --nocapture`»), igual que en la raíz.

## 4. Lock

`logs/lock-diff.txt` contiene el diff íntegro:

```
@@ -4634,6 +4634,7 @@
 name = "zx-consensus"
 version = "0.0.0"
 dependencies = [
+ "ed25519-zebra",
  "primitive-types",
  "proptest",
  "thiserror 2.0.20",
```

- Raíz actual (`ws.orig/Cargo.lock`): `d7cef01347b66f7090e1006592791959cc170d936d22e847f514691fdbe50b72`
- Rebase (`ws/Cargo.lock`): `4da3e37c69fa0e374d7d7b0d5931cb502d3c83f8459485a3318efa1f2ce2257d`
- **Sin cambios de versión**: la causa es la dev-dependency `ed25519-zebra` de `zx-consensus`
  que W03 añade; cargo la refleja en el lock sin tocar ninguna versión (el paquete ya estaba en
  el árbol como dependencia de `zx-core`).

## 5. Notas de ejecución (sin efecto en el resultado)

1. **`--exclude=Cargo.lock` literal.** Como `ws/` vive dentro del repositorio git de la raíz,
   `git apply` antepone la ruta relativa al repo (`deepseek/W03R/ws/...`) al hacer coincidir el
   patrón, así que `--exclude=Cargo.lock` no coincidía. Se ejecutó el mismo comando con
   `GIT_CEILING_DIRECTORIES=$ZONE`, que impide a git ver el `.git` padre; entonces el patrón
   coincide con la ruta del parche (`Cargo.lock`) y sólo se excluye ese trozo. Alternativa
   equivalente comprobada: `--exclude='*Cargo.lock'`.
2. **`--locked` y `cargo fmt`.** `cargo fmt` no admite `--locked` (es `rustfmt`, no un comando de
   compilación); se ejecutó `cargo fmt --all -- --check` tal como figura, y `--locked` se aplicó a
   `clippy` y `test`, que sí lo aceptan. El lock no interviene en el formateo.
3. **Primer `cargo metadata` mal ubicado.** La primera invocación se lanzó desde el directorio de
   la zona (sin `Cargo.toml`), por lo que cargo resolvió el workspace **padre** de la raíz. No
   modificó nada (la raíz ya estaba resuelta; su `Cargo.lock` conserva mtime y contenido). El
   comando válido se repitió dentro de `ws` y es el que consta en `logs/V0-metadata.log` y
   `logs/lock-diff.txt`.
4. **Target compartido.** Para enumerar los nombres de test de la raíz se compiló `ws.orig` en el
   mismo `CARGO_TARGET_DIR` que `ws`; los artefactos de `zx-consensus` quedaron en un estado
   inconsistente y un `--list` posterior falló con «could not find `transicion`». Se resolvió con
   `cargo clean -p zx-consensus` y el test completo final (`logs/V3-test.log`) volvió a pasar
   limpio. `ws.orig` y `ws` tienen árboles fuente independientes (verificado con `cmp`).
5. **Sin Python, sin secretos, sin commit ni push, nada escrito fuera de la zona.**

## 6. Entregables

| Fichero | Contenido |
|---|---|
| `cambios.patch` | `diff -ruN -x target -x .cargo-home -x PDF ws.orig ws`; 18 ficheros, 8 356 518 bytes; aplica limpio sobre la raíz. sha256 `98ee69ba…` |
| `MIGRACION.sha256` | 130 huellas del árbol `ws`; `sha256sum -c` OK. sha256 `5c2a7f01…` |
| `logs/` | `V0-apply`, `V0-metadata`, `V1-fmt`, `V2-clippy`, `V3-test`, `V4-diferencial`, `V7-deps`, `V8-frontera`, `lock-diff`, `comparacion-tests`, `tests-anadidos`, `raiz-test-list`, `ws-test-list` |
| `INFORME.md` | este documento |
| `HORAS.log` | marcas de tiempo |

Entorno: `CARGO_HOME=<zona>/.cargo-home`, `CARGO_TARGET_DIR=<zona>/target`,
`CARGO_BUILD_JOBS=8`, `RUST_TEST_THREADS=8`; toolchain pineado `nightly-2026-05-03`
(`rustc 1.97.0-nightly 20de910db`).
