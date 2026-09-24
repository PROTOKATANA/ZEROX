# Corrección A2 · semilla inicial sin asignación proporcional a entropía

Usa `deepseek-v4.1-flash`, esfuerzo `high`. Tras `ORDEN-A2-FLUJO-PURO.md`, edita **solo** `crates/zx-consensus/src/pot.rs` y, si necesitas una regresión material, `crates/zx-consensus/tests/flow.rs`. No hagas commit ni push ni toques CI.

`semilla_genesis` hoy construye `Vec::with_capacity(32 + entropia_externa.len())` y copia todos los bytes. La longitud del parámetro de lanzamiento no tiene cota normativa, y no hace falta una reserva proporcional a la entrada. Sustituye esa concatenación por `blake3::Hasher` incremental: `update(block_hash.as_bytes())`, `update(entropia_externa)`, `finalize()`, truncar a 16 B. Debe ser bit a bit la misma fórmula `blake3(block_hash ‖ entropía)[0..16)`, sin cambiar interfaz, salida ni estados. Evita toda suma de longitudes sin `checked_*` en esta función de consenso. Ajusta el comentario de memoria. Prueba el mismo resultado con dos tamaños de entropía en el test existente; no dupliques un test tautológico si la comprobación previa ya lo cubre.

Verifica `cargo test -p zx-consensus --locked --test flow`, Clippy del crate, `cargo fmt --all -- --check` y `git diff --check`; `ci/citas-spec.sh` seguirá rojo hasta que el líder actualice el inventario. Informa el resultado.
