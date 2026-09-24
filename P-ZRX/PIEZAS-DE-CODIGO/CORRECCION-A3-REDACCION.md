# Corrección A3 · precisión de dos comentarios

**Ejecutor:** DeepSeek Harness, `deepseek-v4.1-flash`, esfuerzo `high`. No commit ni push.

Archivo único permitido: `crates/zx-consensus/src/cabecera_conjunta.rs`. Lee las líneas actuales alrededor de `RangoSolucionValidado::validar` y del match de `ErrorPoas`; no edites otras rutas.

1. La frase «El valor esperado sale del contexto, nunca del candidato» es demasiado fuerte: el trait admite que una implementación capture el candidato por otra vía. Escríbela como «La puerta toma el esperado del método del contexto, sin leer directamente `cabecera.rango_solucion` como esperado; la procedencia causal del método sigue pendiente». Conserva el comentario que enumera `height`, `timestamp` y `pot_output` como fuentes prohibidas por C-HDR-06.
2. La frase «Fallos del candidato» sobre `ErrorPoas::Prueba(_)` general también es demasiado fuerte mientras el `PieceCheckParams` sea un argumento sin procedencia acreditada. Precisa que es una clasificación **condicionada al contexto** y que no se puede cachear como rechazo de producción hasta verificar esa procedencia. No cambies el match ni la clasificación en esta corrección: `InvalidHistorySize` ya se trata como `Pendiente`.

Ejecuta `cargo fmt --all -- --check`, `cargo clippy -p zx-consensus --all-targets --locked -- -D warnings` y `git diff --check`. Informa el diff exacto. A3 no se cierra.
