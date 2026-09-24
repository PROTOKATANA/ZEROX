# Corrección D2 · rechazo A1 y contexto

Usa `deepseek-v4.1-flash`, esfuerzo `high`. La entrega de `ORDEN-D2-CONVERSION-POAS.md` ya está en el árbol; cambia **solo** `crates/zx-node/src/productor_poas.rs` y `crates/zx-node/tests/farmer_disco.rs`. No hagas commit ni push ni edites CI.

El revisor Rust halló que `DiagnosticoLocal::falsos_positivos_a1` atribuye una causa no demostrada. `ErrorPoas::Prueba` puede proceder de `PieceCheckParams` inyectado incompatible (`FutureHistorySize`, `InvalidPieceOffset`, `SectorExpired`, `InvalidPiece`, etc.), y el test de compromiso de segmento ajeno lo demuestra. Renombra el campo a `rechazos_a1` y neutraliza documentación, test y comentarios. Di explícitamente que un rechazo no prueba un falso positivo del auditor y que todos los rechazos con contexto ajeno pueden ocultar un fallo de integración causal; la función no acredita procedencia del contexto.

Además, `subspace_verification::Error::InvalidHistorySize` dentro de `ErrorPoas::Prueba` es un error del contexto de pieza/expiración, como clasifica `zx-consensus/src/cabecera_conjunta.rs`. Propágalo por `ErrorProductorPoas::Contexto`, sin contarlo como rechazo ordinario ni convertirlo en conjunto vacío. El resto de `ErrorPoas::Prueba` puede contarse como `rechazos_a1` y descartarse, sin atribución de causa. Conserva el motivo upstream en el error propagado y prueba el caso `InvalidHistorySize` si el fixture permite inducirlo sin duplicar costos; si no, documenta el límite y no inventes un resultado.

Repite pruebas de D2 y D1 (`cargo test -p zx-node --features farmer --locked --test farmer_disco`), Clippy, formato, `ci/citas-spec.sh` y `git diff --check`. Informa `ci/alcance-consenso.sh` sin alterar el inventario.
