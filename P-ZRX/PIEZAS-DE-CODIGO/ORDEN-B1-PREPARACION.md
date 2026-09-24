# Orden B1, preparación aislada para DeepSeek · comparación del undo

**Estado de la pieza:** esta orden corrige un requisito de `C-REORG-02` dentro del motor existente. **No cierra B1**: el nodo todavía recibe cabeceras antes de cuerpos y no posee la proyección UTXO de `C-ORD-03/04` sobre el DAG. No cambies esa ruta ni afirmes que el estado se aplica en producción.

Trabaja en `/home/katana/zeo/ZEROX` mediante `dsh`, modelo DeepSeek-V41-Flash, esfuerzo `high`. Lee `AGENTS.md`, `README.md`, `MIGRACION.md`, `SPEC.md` §12 `C-REORG-01..03`, `SPEC.md` `C-ORD-03/04` y `crates/zx-storage/src/utxo.rs` completos antes de editar. La implementación es tuya; no elijas reglas nuevas ni números. El líder revisará el diff y las pruebas.

## Hallazgo verificado

`UndoData.creados: Vec<OutPoint>` guarda solo claves. `revertir_bloque` retira esas claves si existen, pero `C-REORG-02` exige que cada salida creada esté en el UTXO set **tal y como se espera** antes de borrarla. Una salida corrupta con la misma clave pasa inadvertida. Los especialistas Rust y matemáticas revisaron esta conclusión por separado.

## Cambio exacto

Archivos permitidos: **solo** `crates/zx-storage/src/utxo.rs` y, si necesitas una variante de error específica, `crates/zx-storage/src/error.rs`. Los tests van junto a `utxo.rs`. No toques manifests, lock, CI, `zx-node`, `zx-consensus`, `SPEC.md`, PDF, investigación ni documentación. El árbol ya contiene trabajo A1 ajeno a esta orden, incluso cambios de manifiesto: consérvalo byte a byte. No hagas commit ni push.

1. Cambia `UndoData.creados` para conservar `(OutPoint, EntradaUtxo)` esperado por cada salida creada, en el mismo orden en que `DeltaUtxo::de_bloque` las entrega. Reutiliza `EntradaUtxo` y `DeltaUtxo`; no recalcules ni reinterpretes la transacción en el undo.
2. En `aplicar_bloque`, guarda el par completo en `UndoData` solo después de insertar exitosamente la salida en la copia de trabajo. Conserva la publicación atómica actual.
3. En `revertir_bloque`, por cada par esperado comprueba primero la existencia **y la igualdad completa** de `EntradaUtxo` (`value`, `Lock`, altura y marca de coinbase). Ausencia conserva `OutpointAusente`; contenido distinto debe producir un error de corrupción explícito distinto. Retira solo después de comparar. Si falla cualquier salida, `conjunto` original debe permanecer intacto. Conserva el orden inverso de transacciones e inputs al reinsertar consumidos.
4. Adapta el único literal `UndoData` que usan los tests a la estructura nueva. No metas una aceptación por defecto ni omitas la comparación en otra rama.

## Pruebas que deben detectar el fallo antiguo

- Aplica un bloque con al menos una salida creada, sustituye en el conjunto esa entrada por otra del **mismo outpoint** con valor diferente; `revertir_bloque` debe devolver el error específico y dejar el conjunto intacto.
- Repite la alteración en `Lock`, altura de creación o `es_coinbase` si una prueba parametrizada pequeña lo hace claro; la igualdad completa debe cubrirlos todos.
- Comprueba ausencia y doble undo, aplicación + reversión identidad, y fallo en una salida posterior sin publicar los borrados anteriores. Reutiliza los tests existentes, ampliándolos donde tengan valor; evita duplicados que solo repitan la implementación.

Entrega `git status --short` y diff limitado a esos dos archivos, más resultados reales de `cargo fmt --all -- --check`, `cargo test -p zx-storage --locked`, `cargo clippy -p zx-storage --all-targets --locked -- -D warnings`, `ci/citas-spec.sh`, `ci/alcance-consenso.sh` y `git diff --check`. El último guardián ya falla por A1: informa ese fallo preexistente, sin arreglarlo ni atribuirlo a B1.
