# Orden a DeepSeek · C1: lector causal separado de la cola de candidatos

Ejecuta con DeepSeek V4.1 Flash, esfuerzo `high`, mediante DeepSeek Harness. **No hagas commit ni push.** Este es un incremento parcial; C1, A2, A3 y C2 permanecen abiertas.

## Lectura y frontera

Lee `AGENTS.md`, `README.md`, `MIGRACION.md`, `PROMPT.md`, `research/README.md`, `veritas/LINEO.md` íntegro antes de tocar tests de cálculo, SPEC C-HDR-07/09, C-POT-06/08, C-GD-04, C-FLU-14/21, C-STORE-06/07/08, y `PROGRESO-0.0.1.md`. Inspecciona `zx-storage/{almacen_dag,memoria,disco,error,lib}.rs`, `zx-node/dag_causal.rs`, `zx-consensus/{pot_rango,cabecera_conjunta,ghostdag}.rs`.

La cola `AlmacenCandidatosDag` **no** acredita PoST. `AlmacenGhostdag::admitir` verifica solo SR contextual parcial y `ComprobacionCabecera` usa contextos inyectados. Ninguno puede crear una entrada admitida. **No implementes un verificador ausente como aceptación incondicional.** No elijas `D`, `N(s)`, SR, altura DAG ni finalidad.

## Alcance permitido

`crates/zx-storage/src/{almacen_admitidos_dag,memoria,disco,error,lib}.rs`, tests unitarios de esos módulos; `crates/zx-node/src/dag_causal.rs` y tests unitarios allí. Evita otros archivos; informa si surge una dependencia real. Preserva `TAREAS.md`, P-ECLIPSE y P-RELOJ concurrentes.

## Entrega

1. Crea una API **de lectura** para un almacén **separado** de bloques DAG plenamente admitidos, indexado por `block_hash`: `bloque_admitido(hash) -> Result<Option<BloqueDag>, StorageError>`. Implementa en memoria y RocksDB, usando un mapa/familia distintos de `candidatos_dag`, sin tocar alturas ni punta lineal. Guarda el **bloque completo** en formato canónico versionado o con codificación existente más discriminante versionada; al leer, exige consumo exacto de bytes y `cabecera.block_hash()==clave`, y distingue corrupción de ausencia. No leas candidatos como fallback. Documenta que el almacenamiento retiene PoT/`sol.chunk`/`pot_output`, pero su presencia por sí sola no demuestra validez fuera del futuro camino de admisión.
2. **No exportes hoy un escritor público de admisión.** Si hacen falta escrituras para tests, que sean helpers `#[cfg(test)]` internos a la implementación y nombrados como inyección de fixture sin autoridad. El código de producción no debe poder promocionar un `BloqueDag` arbitrario, ni pasar `ComprobacionCabecera` parcial como credencial. Un futuro escritor será un único lote lógico con estado/undo/GHOSTDAG y publicación posterior, serializado; no lo simules ahora con un `guardar_admitido` suelto. Puede que el índice real quede vacío en la ruta activa: exprésalo como límite, no como éxito de integración.
3. Implementa en `zx-node/dag_causal.rs` un adaptador de `FuenteRegistrosDag` que lea **solo** de esa API. Construye `RegistroEstructural` del `BloqueDag` leído con hash/padres/slot canónicos. No transformes `Ok(None)` en invalidez. No construyas `InstantaneaPot` desde `(hash,padres,slot)` ni uses `pot_output` del candidato como `salida_validada`. Si el contrato de coherencia de instantánea requiere algo más, decláralo y no prometas snapshot estable por un `&self` mutable.
4. Tests decisivos: candidato presente sin entrada admitida devuelve `None`; dos cabeceras mismo slot no colisionan; bytes residuales/clave hash incoherente devuelven corrupción; reapertura RocksDB conserva lectura de fixture; una inyección de fixture no debe estar disponible en binario de producción. Para el adaptador en `zx-node`, usa un **fake de lectura** del nuevo trait si el helper `#[cfg(test)]` de `zx-storage` no es visible al crate dependiente; prueba diamante y ausencia sin llamar a la cola de candidatos, y deja claro que el fake no acredita admisión. Probar explícitamente que una entrada del índice no puede reemplazarse con otra justificación/cuerpo bajo el mismo hash si se llega a disponer de escritor test; comparación bajo corrupción y concurrencia solo si el mecanismo real permite probarlas con significado. Evita tests que se limiten a repetir la implementación o declarar validez de fixtures PoST.

## Gates

`cargo test -p zx-storage --locked`, `cargo test -p zx-storage --features rocksdb --locked` (tests dirigidos si la suite completa es costosa), `cargo test -p zx-node --locked` dirigido al adaptador, Clippy en crates editados, `cargo fmt --all -- --check`, `ci/citas-spec.sh`, `ci/alcance-consenso.sh`, `git diff --check`. Reporta qué probaste realmente y qué no. No limpies target de Cargo. No cierres piezas por esta entrega.
