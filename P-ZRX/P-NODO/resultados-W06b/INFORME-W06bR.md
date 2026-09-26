# INFORME.md — ORDEN-W06b-R

**ID:** W06b-R. **Fecha:** 2026-09-26. **Director:** Claude. **Ejecutor:** DeepSeek Harness,
`deepseek-flash`, esfuerzo `high`. **Zona única:** `/home/katana/zeo/ZEROX/deepseek/W06bR/`.
**Entrada:** `ORDEN-W06b-R.md` y `V-ZRX/LINEO.md` leídos íntegros antes de ejecutar.

## 1. Veredicto

**CUMPLIDO.** W06b + Corrección A se rebasa sobre la raíz actual (la que ya incluye W05b3 `zx-post` y
W06a `zx-cadena`) conservando el crate `crates/zx-storage` **byte a byte** idéntico al revisado. Solo
se rehacen a mano los tres ficheros que el parche no aplicaba (`Cargo.toml`, `Cargo.lock`,
`ci/frontera-crates.sh`) con el mínimo cambio y **sin `cargo update`**: un único `cargo metadata`
añade 17 paquetes, 0 eliminados y 0 versiones existentes cambiadas. V1–V3 y V8 quedan limpios y la
suite pasa de **662** tests en `ws.orig` a **682** en `ws`: **0 perdidos, 20 añadidos** (15 de W06b +
5 de la Corrección A).

## 2. Qué se hizo

1. **Copias.** `ws.orig/` y `ws/` desde la raíz actual (`/home/katana/zeo/ZEROX/`), subconjunto del
   workspace Rust (`Cargo.toml`, `Cargo.lock`, `rust-toolchain.toml`, `crates/`, `ci/`, `testdata/`,
   `.github/`) y enlace `PDF -> ../../../PDF` excluido de la migración (patrón W02/W04/W06b).
2. **Parche.** En `ws/`:
   `git apply -p1 --exclude=Cargo.toml --exclude=Cargo.lock --exclude=ci/frontera-crates.sh
   deepseek/W06b/cambios.patch` → aplica sin conflictos y crea `crates/zx-storage` (11 ficheros).
3. **Tres ficheros a mano.**
   - `Cargo.toml`: miembro `"crates/zx-storage"` (conservando `"crates/zx-cadena"`) y el bloque que
     W06b añadió a `[workspace.dependencies]`: `rocksdb = "=0.25.0"` y `tempfile = "=3.24.0"`.
   - `ci/frontera-crates.sh`: regla `frontera("zx-storage"; ["zx-core"])` **conservando** las siete
     actuales (incluida `zx-cadena`), más la frase de cabecera que documenta la frontera.
   - `Cargo.lock`: actualizado con **un único** `cargo metadata --offline --format-version 1
     >/dev/null` (sin `cargo update`); `--offline` usa la caché de `.cargo-home`, que fija el índice.
4. **Verificación** (V1–V3, V8 con `--locked`) y comparación nominal de tests `ws.orig` vs `ws`.

## 3. Alcance real del cambio sobre la raíz actual

`logs/estructura-diff.txt` (`diff -r` excluyendo `zx-storage`) demuestra que, **fuera de
`crates/zx-storage/`, solo difieren los tres ficheros rehecidos**:

| Fichero | Cambio |
|---|---|
| `crates/zx-storage/**` (11 ficheros) | nuevo; **idéntico byte a byte** al de `deepseek/W06b/ws/` (W06b + Corrección A) — `logs/zx-storage-identico.txt` |
| `Cargo.toml` | +`"crates/zx-storage"` en `members`; +`rocksdb`/`tempfile` en `[workspace.dependencies]` |
| `Cargo.lock` | +17 paquetes, 0 eliminados, 0 versiones cambiadas |
| `ci/frontera-crates.sh` | +`frontera("zx-storage"; ["zx-core"])` (y comentario); las 7 fronteras previas intactas |

Ningún otro fichero de la raíz cambia: el resto del árbol (`zx-cadena`, `zx-post`, `zx-core` con
`fusion.rs`, etc.) se conserva tal cual.

## 4. Verificación (V1–V3, V8) — todas con `--locked`

| Paso | Comando | Resultado | Log |
|---|---|---|---|
| V1 | `cargo fmt --all -- --check` | limpio | `logs/V1-fmt.log` |
| V2 | `cargo clippy --workspace --all-targets --locked -- -D warnings` (sin `rocksdb`) | limpio (9,5 s) | `logs/V2-clippy-sin-rocksdb.log` |
| V2 | `cargo clippy --workspace --all-targets --all-features --locked -- -D warnings` (con `rocksdb`) | limpio (1 m 48 s) | `logs/V2-clippy-con-rocksdb.log` |
| V2 | `cargo clippy --workspace --all-targets --features rocksdb --locked -- -D warnings` (forma literal) | limpio (0,15 s, ya construido) | `logs/V2-clippy-features-rocksdb.log` |
| V3 | `cargo test --workspace --all-features --locked` | **680 pasan, 0 fallan, 2 ignorados** (55 objetivos: 45 binarios + 10 doc-tests; 15,5 min) | `logs/V3-test.log` |
| V8 | `ci/dependencias-exactas.sh` | `OK — 22 dependencias con versión exacta` | `logs/V8-dependencias.log` |
| V8 | `ci/frontera-crates.sh` | 8 fronteras OK, incluida `zx-storage → {zx-core}` | `logs/V8-frontera.log` |
| V8 | Lock | +17 paquetes, 0 eliminados, 0 versiones cambiadas; a las versiones de W06b | `logs/lock-diff.txt`, `logs/lock-analisis.txt` |

Los 2 ignorados son preexistentes y ajenos a este crate: `bench_coloreo_mergeset_maximo` (banco) y
`v6_extremo_a_end_to_end_con_n_dev_real` (release con `--ignored`). Los tests V4
(`matar_a_mitad_de_escritura_no_deja_entrada_sin_bloque`), V5 (corrupción inyectada + cuerpo
`CuerpoNoCoincide`), V6 (`proptest` y diferencial memoria↔disco) se ejecutan dentro de V3; los 20
tests nuevos aparecen `... ok` en `logs/V3-test.log`.

## 5. Lock (`logs/lock-diff.txt`, `logs/lock-analisis.txt`)

- Base `ws.orig/Cargo.lock` (raíz actual): `sha256 e2f950dc…46e6`, 457 paquetes.
- Final `ws/Cargo.lock`: `sha256 03801a9e…3f2e`, 474 paquetes.
- **Añadidos (17):** `bindgen 0.72.1`, `bzip2-sys 0.1.13+1.0.8`, `cexpr 0.6.0`, `clang-sys 1.9.1`,
  `itertools 0.13.0`, `jobserver 0.1.35`, `libloading 0.8.9`, `librocksdb-sys 0.19.0+11.8.1`,
  `libz-sys 1.1.29`, `lz4-sys 1.11.1+lz4-1.10.0`, `pkg-config 0.3.34`, `rocksdb 0.25.0`,
  `rustflags 0.1.7`, `shlex 1.3.0`, `vcpkg 0.2.15`, `zstd-sys 2.1.0+zstd.1.5.7` y `zx-storage 0.0.0`
  (los 16 de registro son exactamente los que añadía W06b, a las mismas versiones).
- **Eliminados: 0. Pares `(nombre, versión)` de la base ausentes en el final: 0** ⇒ ninguna versión
  existente cambia.
- Las únicas líneas de dependencia modificadas son tres desambiguaciones en paquetes que conservan su
  versión (`cc 1.4.5`: `shlex` → `shlex 2.0.1` + `jobserver`,`libc`; `data-encoding-macro-internal
  0.1.19`: `syn 2.0.119` → `syn 3.0.4`; `prost-derive 0.14.4`: `itertools` → `itertools 0.14.0`),
  idénticas a las de W06b.
- El cuerpo del diff es igual al de `deepseek/W06b/logs/lock-diff.txt` salvo la última cabecera de
  hunk y el paquete de contexto (`zx-cadena` en vez de `zx-consensus`), porque la base actual ya
  incluye `zx-cadena` (W06a).

## 6. Tests (`logs/comparacion-tests.txt`)

`cargo test --workspace --all-features --locked -- --list`: `ws.orig` **662** vs `ws` **682**.
**0 perdidos, 20 añadidos** (14 unit de `disco`, 3 unit de `memoria`, 2 de propiedades/diferencial, 1
de `matar_a_mitad`). Criterio cumplido: todos los tests de la raíz actual con su nombre, más los 20 de
W06b/Corrección A.

## 7. Entregables

| Entregable | Detalle |
|---|---|
| `cambios.patch` | `diff -ruN -x target -x .cargo-home -x PDF ws.orig ws`; 14 ficheros, 109 477 bytes; `sha256 c6b1102c…01c2` |
| `MIGRACION.sha256` | 181 huellas sobre `ws/`; `sha256sum -c` OK; `sha256 a84eecf1…c7e7` |
| `logs/` | V1, V2 (×3), V3, V8 (×2), `lock-diff.txt`, `lock-analisis.txt`, `estructura-diff.txt`, `comparacion-tests.txt`, `zx-storage-identico.txt`, listados `--list`, `patch-apply.log` |
| `INFORME.md` | este informe |
| `HORAS.log` | marcas `date -Is` reales |

`logs/patch-apply.log`: sobre una copia limpia de `ws.orig`, `git apply -p1 cambios.patch` aplica sin
errores y reconstruye `ws` byte a byte (`diff -r` sin diferencias).

## 8. Presupuesto

Declarado: 1 h, 8 hilos, caché en la zona. Consumo real: **≈ 22 min de reloj** (05:04–05:26);
`CARGO_HOME`/`CARGO_TARGET_DIR` copiados de `deepseek/W06b/` (2,6 GiB + 22 GiB) reutilizan
`librocksdb-sys`. No agotado.

## 9. Límites (los de W06b; este encargo solo rebasa)

- No se re-verifican cabeceras ni PoT/PoAS (D-N03′); el reinicio es lineal en la historia y no sirve
  para producción sin instantáneas (IPA E). Los testigos PoW no están comprometidos por `merkle_root`
  (límite fijado por el test V5 (e)); en PoST los cubre `body_commitment`.
- V7 (medición release de 10 000 bloques) **no** se repite: la orden de rebase no lo pide y `zx-cadena`
  no toca `zx-storage`; las cifras revisadas de W06b siguen siendo las de referencia.
- Sin Python, sin `git commit`/`push`, sin secretos; solo se escribió dentro de la zona.
