# Revisión del director — W01 (2026-09-26)

**Veredicto: SUPERADO y migrado a la raíz** (01:19). DeepSeek, sesión 01:15–01:18.

Comprobado por el director, independientemente: `diff -r` de `crates/zx-core` y `crates/zx-pot`
contra `git archive 9681061` → solo la ruta autorizada de `tests/oraculo_julia.rs`; `testdata/nist-cavp`,
`rust-toolchain.toml`, `ci/dependencias-exactas.sh` y el fichero de vectores idénticos byte a byte;
las 131 parejas `nombre versión` del `Cargo.lock` nuevo existen con la misma versión en el antiguo
(`comm -23` vacío); `MIGRACION.sha256` (50 archivos) verificado **en la raíz** tras copiar. Tras la
migración, `git status` ve los crates como idénticos a `9681061` salvo `oraculo_julia.rs`. Se
restauró el modo 644 de `ci/dependencias-exactas.sh` (el original no era ejecutable).

Faltas de definición que señaló el ejecutor (resueltas bien): solo se actualizó el comentario de la
ruta dentro de `leer_oraculo`; se conservó `[profile.release]`.

**Pendiente:** la CI nueva no se ha ejecutado en GitHub (no hay push); se ejecutó localmente el
mismo conjunto de comandos (V1–V5 de la orden).
