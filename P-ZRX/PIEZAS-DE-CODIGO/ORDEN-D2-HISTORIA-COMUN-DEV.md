# ORDEN D2/A3 · historia archivada común de desarrollo, fase de extracción

**Ejecutor:** DeepSeek Harness `deepseek-v4.1-flash`, esfuerzo `high`. **Estado:** incremento parcial D2/A3; no cierra casillas. Lee `DECISIONES-0.0.1.md` (HISTORIA-DAG-DEV), `PROMPT.md` §8, `SPEC.md` C-POT-08 paso 5 y C-HDR-06, `crates/zx-consensus/src/poas.rs`, `crates/zx-node/src/farmer.rs`, `crates/zx-node/tests/farmer_disco.rs`, y las API públicas del clon fijado que el fixture ya usa.

## Archivos exactos

- Crear `crates/zx-node/src/historia_dag_dev.rs`.
- Añadir en `crates/zx-node/src/lib.rs` únicamente `#[cfg(feature = "farmer")] pub mod historia_dag_dev;` siguiendo el estilo existente.
- Refactorizar `crates/zx-node/tests/farmer_disco.rs` para que su fixture D1 consuma el módulo nuevo en vez de reconstruir por su cuenta el `RecordedHistorySegment`, `Archiver`, `FarmerProtocolInfo` y `PieceCheckParams`.
- Crear `crates/zx-node/tests/historia_dag_dev.rs` para el contrato de extracción.

No editar manifiestos, lockfile, `SPEC.md`, `PDF/`, otros crates, binario, CI, ni archivos de otros encargos. No hacer commit ni push. Si necesitas ampliar archivos, detente y explica cuál y por qué. `git status --short` antes y después; no modificar ni incorporar cambios ajenos.

## Contrato de implementación

Crear un tipo público `HistoriaDagDev` con campos privados. Constructor `pub fn construir() -> Result<Self, ErrorHistoriaDagDev>` (error tipado; `thiserror` ya existe). Debe reproducir **exactamente** la receta hoy en `construir_fondo` de `farmer_disco.rs`: `Kzg::new()`, `ErasureCoding` con `Record::NUM_S_BUCKETS.next_power_of_two().ilog2()`, `Archiver::new`, un `RecordedHistorySegment::new_boxed()` llenado por el mismo splitmix64 y la misma semilla `0x9E37_79B9_7F4A_7C15`, `add_block(..., Default::default(), true)` y tomar el primer `NewArchivedSegment`. Mantener `FarmerProtocolInfo` con `history_size=1`, `max_pieces_in_sector=2`, `recent_segments=5`, `recent_history_fraction=(1,10)`, `min_sector_lifetime=4`. Documentar que estos números son exclusivamente el fixture local dev. No reinterpretar el contenido ni crear un `PieceGetter` falso.

Exponer solo getters por referencia para `historial() -> &NewArchivedSegment`, `kzg() -> &Kzg`, `erasure_coding() -> &ErasureCoding`, `segment_commitment() -> SegmentCommitment`; `protocolo() -> FarmerProtocolInfo` por copia; `params_pieza() -> PieceCheckParams` por valor. `params_pieza` debe construir todos sus campos a partir del segmento archivado y del mismo `FarmerProtocolInfo`, con `sector_expiration_check_segment_commitment: None`, tal como hace hoy `params_pieza_fixture`. No aceptar compromiso, historia ni parámetros suministrados por candidato o usuario. No escribir ninguna función que declare válida una cabecera; el contexto de pieza aún no está cableado a A3. No usar `unwrap` o `expect` en la ruta pública: representar error si `ErasureCoding::new` falla o no sale segmento. Si el upstream tiene error de difícil tipado, envolverlo de forma concreta sin fabricar éxito.

El fixture `Fondo` conserva su parcela, bytes y clave, pero sustituye sus campos `kzg`, `erasure_coding`, `historial`, `protocolo` por **un solo** `HistoriaDagDev`. Todas las llamadas del test a ploteo, auditoría y `verificar_solucion_poas` deben obtener datos de este objeto. Quitar `llenar_determinista` y `params_pieza_fixture` privados para evitar dos fuentes. No alterar semántica ni alcance de las pruebas existentes. No construir dos archivos de 130 MB en el mismo proceso para un mismo test.

## Pruebas obligatorias

1. En `historia_dag_dev.rs`, un test construye el objeto, obtiene el compromiso desde la cabecera archivada y comprueba que coincide con `params_pieza().segment_commitment`. Comprueba por separado cada campo de `PieceCheckParams` contra el `FarmerProtocolInfo` esperado (sin comparar una función consigo misma), el índice de segmento y que hay piezas reales. Imprime **solo en `--nocapture`** el compromiso como `Debug` (96 dígitos hex) para que el líder lo mida; no lo congele ni lo invente en esta fase.
2. Una prueba de integración adicional debe plotear con `plotear_sector_en_disco` usando `HistoriaDagDev` y una clave/índice fijos distintos de los del fixture D1; reabrir la parcela y auditar un slot. Reutiliza los patrones de D1 y evita duplicar el archivo archivado dentro de esa prueba. El test debe demostrar que la API sirve para un segundo productor, sin afirmar que hay una red de tres nodos ni cerrar D2.
3. Ejecutar el test D1 existente completo para demostrar que la extracción no cambió su comportamiento ni ocultó el verificador PoAS. Si el coste es grande, informar tiempo real; no bajar la dificultad ni omitir tests por conveniencia.

## Verificación y parada

Ejecutar `cargo test -p zx-node --features farmer --locked --test historia_dag_dev -- --nocapture`, `cargo test -p zx-node --features farmer --locked --test farmer_disco`, `cargo fmt --all -- --check`, `cargo clippy -p zx-node --all-targets --features farmer --locked -- -D warnings`, `ci/citas-spec.sh`, `ci/alcance-consenso.sh`, `git diff --check`. No ejecutar perfiles release ni suites adicionales. Informar el compromiso observado y los resultados exactos; detenerse para revisión del líder. **No congelar todavía el literal**: el líder hará una segunda ejecución independiente y emitirá corrección. No marcar A3 ni D2.
