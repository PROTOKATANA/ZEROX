# DIFF.md — `pot-estable-rutas` frente a `prototipos/pot-estable`

Copia de `prototipos/pot-estable` (sin `target/`). Cambios introducidos SOLO para el
banco de costes del salto (Q4, `veritas/rendimiento/coste-salto-v1`). No hay cambios en
rutas criptográficas: ninguna primitiva se ha tocado.

## Diff completo (fuente)

- `src/tipos.rs`
  - Añadido el enum `Ruta` (`Auto`, `Avx512fVaes`, `Avx2Vaes`, `AesSse41`, `Generica`)
    con un comentario que lo marca como ajeno al port original.
- `src/aes.rs`
  - Import de `Ruta`.
  - Añadida `verify_sequential_con_ruta(seed, key, checkpoints, checkpoint_iterations,
    ruta)`: misma validación que `verify_sequential`, pero ejecuta la ruta indicada:
    - `Auto` → `verify_sequential` (despacho normal por cpufeatures);
    - `Avx512fVaes` → `x86_64::verify_sequential_avx512f_vaes` forzada
      (comprueba `avx512f`+`vaes` y panica con mensaje explícito si la CPU no la tiene);
    - `Avx2Vaes` → `x86_64::verify_sequential_avx2_vaes` forzada;
    - `AesSse41` → `x86_64::verify_sequential_aes_sse41` forzada;
    - `Generica` → `verify_sequential_generic` (crate `aes`, sin intrínsecos propios
      EN ESTE PORT — pero el crate `aes` 0.9.3 sí autodetecta AES-NI en tiempo de
      ejecución por su cuenta, `aes-0.9.3/src/lib.rs:36-46`; en esta CPU corre con
      AES-NI, no es software. Ver «Corrección 1» más abajo).
    - En aarch64 las tres rutas x86_64 son `unreachable!`.
- `src/lib.rs`
  - Añadida `pub fn verify_con_ruta(seed, iterations, checkpoints, ruta)`: misma
    validación de múltiplos que `verify` y mismo reparto de iteraciones por checkpoint.
- `tests/rutas.rs` — **nuevo**: las cuatro rutas aceptan los mismos checkpoints válidos,
  coinciden con el despacho `Auto`, y un checkpoint mutado (y una semilla ajena) falla
  en las cuatro.

## Qué NO cambia

- `src/aes/x86_64.rs`, `src/aes/aarch64.rs`, `tests/diferencial.rs` y
  `tests/vectores-nightly.txt` idénticos byte a byte.
- `Cargo.toml` y `Cargo.lock` idénticos (mismas versiones: `aes 0.9.3` resuelto del
  requisito `0.9.0-rc.1`, `blake3 1.5`, `cpufeatures 0.2`, `thiserror 2`).
- `verify` (despacho automático) se comporta exactamente igual.

## Verificación

```
CARGO_TARGET_DIR=$PWD/target cargo test --offline --locked --release
```

debe pasar `diferencial.rs` (32/32 vectores byte a byte) y `rutas.rs`.

## Por qué forzar rutas en un Zen 5 NO equivale a CPUs antiguas

Las rutas sin AVX-512 se miden FORZADAS en un Ryzen 9 9950X3D. En una CPU que solo
tuviera AVX2+VAES o AES-NI+SSE4.1, la microarquitectura (frecuencias, decodificación,
puertos AES) es otra, así que estos números son una cota local de la ruta, no la
predicción del coste en hardware antiguo.

## Corrección 1 (2026-09-14) — etiqueta de la ruta `Generica`

Los ~925 ms/slot medidos con `Ruta::Generica` en el primer paso NO son AES por
software: son el crate `aes` 0.9.3 usando AES-NI por autodetección en esta CPU
(`aes-0.9.3/src/lib.rs:36-46`, confirmado con `#[cfg(aes_backend = "soft")]` en
`aes-0.9.3/src/backends.rs:4`, que es la ÚNICA forma de forzar el backend software).
`verify_sequential_generic` en `src/aes.rs` no usa intrínsecos PROPIOS de este port,
pero delega en el crate `aes`, que sí los usa por su cuenta. El código de
`pot-estable-rutas` no cambia por esta corrección — solo la etiqueta era engañosa.

Para medir AES por software real, el banco `coste-salto` compila un binario
SEGUNDO con `RUSTFLAGS='--cfg aes_backend="soft"'`
(`CARGO_TARGET_DIR=target-soft`), que solo se usa para la operación
`G-pot-aes-soft` y no publica ninguna otra medición de ese binario: al compilar así,
la ruta `aes_sse41` (que no pasa por el crate `aes`) se ralentiza ~50 % sin
explicación encontrada — posiblemente el `--cfg` global afecta la generación de
código de todo el binario (menos inlining/optimización cruzada), no solo del crate
`aes`. Ver `coste-salto/README.md` y `resultados/RESUMEN.md` §3.
