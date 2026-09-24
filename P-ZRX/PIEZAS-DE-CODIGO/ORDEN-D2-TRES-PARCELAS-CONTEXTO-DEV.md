# ORDEN D2 · tres parcelas distintas contra una historia dev común

**Ejecutor:** DeepSeek Harness `deepseek-v4.1-flash`, esfuerzo `high`. Incremento parcial D2/A3; ninguna casilla se cierra. Lee `PROMPT.md` §8, `DECISIONES-0.0.1.md` HISTORIA-DAG-DEV, `SPEC.md` C-POT-03 y C-POT-08 paso 5, `crates/zx-node/tests/historia_dag_dev.rs`, `crates/zx-node/tests/farmer_disco.rs` (tests `convierte_candidatos_y_verifica_a1` y `convierte_pot_dev_y_solucion_disco`), `crates/zx-node/src/{historia_dag_dev,farmer,productor_poas}.rs` antes de editar.

## Alcance exacto

Editar **solo** `crates/zx-node/tests/historia_dag_dev.rs`. Conserva los dos tests existentes y el `OnceLock<HistoriaDagDev>`. Puedes ampliar `DirTemporal` o añadir funciones privadas de test en ese archivo. No tocar código de producto, tests D1, manifests/lock, `SPEC.md`, CI, PDF, binario ni archivos ajenos. No commit ni push. `git status --short` antes/después.

## Prueba decisiva

Añadir **un** test que construya tres parcelas reales con `plotear_sector_en_disco`, usando tres `PublicKey` distintas: `PublicKey::default()` (sector `2`), `[0xB7;32]` (sector `9`) y `[0x5A;32]` (sector `17`). Las tres deben usar **el mismo** `&HistoriaDagDev`, su `NewArchivedSegment`, `FarmerProtocolInfo`, KZG, erasure coding y `PieceCheckParams`, sin volver a construir historia ni pasar compromisos calculados por las parcelas. Reabrir cada parcela con su clave. Confirmar metadatos básicos y que una clave equivocada no abre esa parcela, si la API actual devuelve ese error.

Barrido determinista y acotado de `slot=0..64` con `salida_slot=[13u8;16]` y `SR=u64::MAX`, **etiquetados como datos de test**. Para cada parcela llamar `convertir_candidatos_locales` y detener el barrido de esa parcela en su primera `SolucionComprobadaLocal`. Exigir que las tres encuentran al menos una antes del límite; si alguna no, fallar con índice, clave, slots recorridos y contadores de diagnóstico. No fabricar una solución ni relajar el rango o la historia para obtener verde. Para la solución hallada de cada identidad, volver a llamar **de forma independiente** a `verificar_solucion_poas` con los mismos slot/salida/rango y el `PieceCheckParams` común, cotejar la distancia de A1 con la devuelta y cotejar la `public_key`/`sector_index` de la solución con la parcela. Mutar `proof_of_space` en una solución de cada identidad y exigir rechazo de A1; no basta afirmar que la conversión descartaría la mutación. Imprimir solo con `--nocapture` una línea por identidad con primer slot y contadores de test, sin llamarlos tasa de red.

Este test demuestra que **tres identidades de parcela** pueden producir soluciones PoAS verificadas contra **un compromiso archivado común**. La salida `[13;16]` es sintética: no afirmar PoT de `N_dev`, bloques, red de tres procesos, cadencia ni Δ. No tocar la lógica de verificación para adaptar el test.

## Verificación

Ejecutar `cargo test -p zx-node --features farmer --locked --test historia_dag_dev -- --nocapture`, `cargo fmt --all -- --check`, `cargo clippy -p zx-node --all-targets --features farmer --locked -- -D warnings`, `ci/citas-spec.sh`, `ci/alcance-consenso.sh`, `git diff --check`. Si `slot<64` no basta, **no aumentes el límite por tu cuenta**: informa el resultado exacto para revisión. No ejecutar la batería D1 ni release (ya verificadas en la entrega anterior). Informar archivos tocados, resultados y detenerse.
