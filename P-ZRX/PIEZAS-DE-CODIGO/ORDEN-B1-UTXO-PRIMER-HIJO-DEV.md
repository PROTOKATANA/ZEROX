# ORDEN B1 · aplicación UTXO reversible del primer hijo DAG dev

**Ejecutor:** DeepSeek Harness `deepseek-v4.1-flash`, esfuerzo `high`. Incremento parcial B1/D2, sin cerrar piezas ni admitir bloques. Lee antes `PROMPT.md` §6/§8, `SPEC.md` C-GEN-03, C-TX-05, C-REORG-01/02/03 y C-ORD-03/04, `crates/zx-storage/src/utxo.rs`, `crates/zx-consensus/src/cabecera_conjunta.rs`, `crates/zx-node/src/{bootstrap_dag_dev,cuerpo_coinbase_dag_dev,puerta_primer_hijo_dag_dev}.rs` y `crates/zx-node/tests/puerta_primer_hijo_dag_dev.rs`.

## Archivos exactos

- Crear `crates/zx-node/src/utxo_primer_hijo_dag_dev.rs`.
- Añadir `pub mod utxo_primer_hijo_dag_dev;` a `crates/zx-node/src/lib.rs` en orden junto a los otros módulos dev.
- Ampliar `crates/zx-node/tests/puerta_primer_hijo_dag_dev.rs` sin alterar el fixture compartido de PoT/PoAS.

No tocar manifests/lock, storage, consensus, red, binario, SPEC, CI, PDF ni archivos concurrentes. No hacer commit/push. Si una API exige otra ruta, detenerse e informar.

## Contrato

Crear `pub fn simular_utxo_primer_hijo_dag_dev(bootstrap: &EstadoBootstrapDagDev, bloque: &BloqueDag, comprobacion: &ComprobacionCabecera) -> Result<EstadoUtxoPrimerHijoDev, ErrorUtxoPrimerHijoDev>`. La palabra **simular** es intencional: produce una proyección UTXO **local de prueba**, no estado seleccionado ni admisión. Antes de aplicar nada, cotejar `comprobacion.block_hash() == bloque.cabecera.block_hash()` y `comprobacion.slot_auditado() == bloque.cabecera.slot`; si no, error tipado propio y sin `Ok`. Después llamar `comprobar_cuerpo_coinbase_cero_dev(bootstrap, bloque)` y conservar su error tipado. Sólo entonces crear `ConjuntoEnMemoria::nuevo()` vacío: C-GEN-03 prohíbe conectar la salida coinbase del génesis. Aplicar **solo** `bloque.txs()` con `zx_storage::aplicar_bloque(&mut conjunto, bloque.txs(), bloque.cabecera.height, bloque.cabecera.consensus_branch_id)`; conservar `UndoData` y `StorageError` tipado. No recalcular txid ni tomar la rama de un literal: `aplicar_bloque` la recibe de la cabecera ya cotejada por el perfil dev. Guardar `block_hash`, conjunto y undo en campos privados de `EstadoUtxoPrimerHijoDev`; exponer getters de solo lectura, incluido `conjunto()` para buscar la salida con el trait existente y `undo()` para comprobar que la salida creada quedó registrada. Exponer `revertir(self) -> Result<ConjuntoEnMemoria, ErrorUtxoPrimerHijoDev>` que invoque `zx_storage::revertir_bloque` sobre el conjunto propio y devuelva el conjunto vacío; propagar corrupción, sin `unwrap/expect` en producto.

No exponer ninguna API `admitir`, `seleccionar` o `publicar`. No escribir en RocksDB ni en el índice de admitidos. No aplicar otros bloques, mergesets, gastos ni transacciones de usuario. No convertir `ComprobacionCabecera` en certificado de admisión: su procedencia causal, reloj, economía completa, orden GHOSTDAG y atomicidad de publicación siguen pendientes. Documentar exactamente esos límites y las citas al SPEC.

## Pruebas que distinguen errores

Usar el `OnceLock` actual para no repetir archivo/ploteo/PoT. En el positivo, obtener `ComprobacionCabecera` **de la puerta A3 real** del bloque con coinbase del fixture; pasarla a la función, comprobar un único UTXO con `OutPoint { prev_txid: zx_core::txid(&bloque.txs()[0], rama_de_cabecera), prev_index: 0 }` y `ConjuntoUtxo::buscar`, valor cero, `altura_creacion=1`, `es_coinbase=true`, bloqueo a la clave del productor, y que `undo.creados` contiene ese par. `revertir` debe devolver conjunto vacío. Esto no mide red ni conecta el estado vivo.

Negativos sin rehacer PoT: (1) reutilizar evidencia A3 del bloque original con cabecera mutada y resellada ⇒ error de hash antes de tocar UTXO; (2) cuerpo coinbase mutado con cabecera/compromisos recalculados, pero evidencia del original ⇒ error de hash; (3) probar error de cuerpo (por ejemplo `expiry_height` erróneo) **sin** falsificar una `ComprobacionCabecera`: para aislarlo, usar mismo header y modificar solo tx/testigos dejando el hash de cabecera intacto; la función debe rechazar por el comprobador de cuerpo, no publicar estado. Si este caso requiere un constructor BloqueDag nuevo, usar el existente. No fabricar una evidencia A3 con mocks. Añadir test de corrupción del undo solo si puede hacerse mediante API pública sin reimplementar la lógica del storage; de lo contrario los tests existentes de `zx-storage` ya cubren `C-REORG-02`.

## Entrega

Ejecutar `cargo test -p zx-node --features farmer --locked --test puerta_primer_hijo_dag_dev`, `cargo fmt --all -- --check`, `cargo clippy -p zx-node --all-targets --features farmer --locked -- -D warnings`, `cargo check --workspace --locked`, `ci/citas-spec.sh`, `ci/alcance-consenso.sh`, `git diff --check`. Reportar archivos exactos, tests y límites. Detenerse para revisión del líder; no marcar B1/D2.
