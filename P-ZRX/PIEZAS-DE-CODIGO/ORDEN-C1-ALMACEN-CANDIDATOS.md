# Orden a DeepSeek · preparación C1: almacén de candidatos DAG

Modelo obligatorio: DeepSeek V4.1 Flash, esfuerzo `high`, mediante DeepSeek Harness. Esta orden es una **preparación**, no cierre de C1. No hagas commit ni push.

## Contexto que debes leer

Lee `AGENTS.md`, `README.md`, `MIGRACION.md` y `SPEC.md` C-HDR-01/02/07/09, C-WIRE-07 y C-STORE aplicable. Revisa `crates/zx-core/src/{preimage/dag.rs,wire_dag.rs}`, `crates/zx-storage/src/{lib.rs,almacen.rs,memoria.rs,disco.rs,error.rs}` y sus tests. `PROMPT.md` §2 decidió construir la ruta DAG al lado de la lineal. El test de 556 B en `zx-consensus/tests/spec_numeros.rs` examina la cabecera **lineal**, y no se toca en esta preparación. Hay cambios previos B1 en `zx-storage/src/error.rs` y `utxo.rs`: preservarlos byte a byte salvo que un error nuevo estrictamente necesario requiera añadir una variante a `error.rs`.

## Archivos permitidos

- Nuevo `crates/zx-storage/src/almacen_dag.rs`.
- `crates/zx-storage/src/lib.rs`, `src/memoria.rs`, `src/disco.rs`.
- Nuevo `crates/zx-storage/tests/almacen_dag.rs` (o tests unitarios equivalentes dentro de `almacen_dag.rs`).
- `crates/zx-storage/src/error.rs` **solo** si hace falta un error preciso y sin alterar el diff previo B1.

No edites manifests, lock, SPEC, CI, `zx-core`, `zx-consensus`, `zx-node`, `TAREAS.md`, `P-ZRX/` ni otros ficheros. Si una API o regla bloquea la tarea, comunica el impedimento en vez de ampliar la zona. No cambies `AlmacenCadena`, sus familias existentes ni su semántica lineal.

## Diseño fijado

1. Crea `pub trait AlmacenCandidatosDag: Send + Sync` en `almacen_dag.rs`, con `guardar_candidato_dag(&self, bloque: &BloqueDag) -> Result<(), StorageError>` y `candidato_dag(&self, hash: &BlockHash) -> Result<Option<BloqueDag>, StorageError>`. Documenta en el trait y los métodos: solo almacena **candidatos no validados**, no da `Válido`, no marca punta, no alimenta GHOSTDAG ni UTXO. `Ok(None)` significa que no existe el candidato, no que sea inválido o válido. Un consumidor no puede inferir validez por presencia. Cita C-HDR-07/09 y C-WIRE-07 con su alcance verdadero.
2. La clave es `bloque.cabecera.block_hash()`; no indexar por `header.height`, slot, orden de llegada ni punta. Dos cabeceras distintas con igual slot deben coexistir. Usa **solo** `zx_core::wire_dag::{bloque_dag_a_bytes,bloque_dag_desde_bytes}` para serializar; no copies ni inventes codec.
3. Guarda el bloque completo en **una** entrada por hash (cabecera, justificación y cuerpo). Una nueva versión bajo el mismo `block_hash` reemplaza atómicamente la entrada completa; esto permite reintentar con otra justificación PoT, que está fuera de `block_hash` por C-HDR-07. No combines justificación vieja con cuerpo nuevo ni expongas escrituras parciales. Esta política es solo para la **cola no confiable**: una prueba posterior mala puede desalojar una buena, por lo que la futura ruta validada debe promover la evidencia verificada a un almacén separado o protegerla contra sobrescritura. Escribe esa limitación en el doc comment; no afirmes resistencia DoS ni finalidad.
4. En lectura, rechaza como `StorageError::Corrupto` cualquier entrada que no decodifique completamente (incluidos bytes finales) o cuyo `block_hash()` no coincida con la clave solicitada. No transformes corrupción en `None` ni aceptes un candidato por haberlo deserializado. No ejecutes verificadores de consenso ni señales que el bloque es válido.
5. Implementa el trait para `AlmacenEnMemoria` usando un mapa nuevo dentro del `RwLock` existente. No hagas `unwrap` de locks en producción; sigue el patrón del módulo. Implementa para `AlmacenEnDisco` detrás de `rocksdb` añadiendo una **familia nueva** para candidatos DAG en `abrir`, sin quitar ni reinterpretar las familias lineales. Una escritura `put_cf` del bloque completo es atómica; una relectura tras reinicio debe recuperar exactamente la última versión. Mantén compatibilidad al abrir un almacén lineal previo mediante `create_missing_column_families` existente. No añadas un índice de cadena seleccionada ni altura derivada: lo hará consenso después.
6. Reexporta el trait desde `lib.rs`. Ajusta la nota de estado de ese módulo para decir que existe **almacenamiento de candidatos DAG**, mientras la admisión/orden/estado DAG sigue pendiente. Ninguna función pública de `zx-consensus` se añade.

## Tests requeridos

- Una prueba contra memoria y, bajo `rocksdb`, diferencial disco/memoria: dos bloques con **igual slot y distinta cabecera/hash** sobreviven y se recuperan por hash, con bytes de bloque idénticos a los originales (comparación independiente mediante codec existente). Las cabeceras de fixture pueden ser no válidas PoAS: etiquétalas *candidatos*.
- Una misma cabecera/hash con **dos justificaciones PoT diferentes**: la segunda reemplaza a la primera, sin cambiar el hash ni mezclar campos. Incluye al menos un bundle en la diferencia; usa `JustificacionPot::nueva`.
- Un hash desconocido devuelve `Ok(None)`.
- En disco, cerrar y reabrir conserva ambos candidatos y la sustitución. Comprueba que los métodos lineales aún pueden almacenar/leer una cabecera lineal en la misma DB.
- Prueba corrupción/clave discordante si la API de tests puede inyectar un valor sin exponer una mutación peligrosa en producción; si no es posible sin ampliar API, deja la defensa en código y explica esa limitación.

## Verificación y entrega

Ejecuta `cargo fmt --all -- --check`, `cargo test -p zx-storage --locked`, `cargo clippy -p zx-storage --all-targets --locked -- -D warnings`, los tests con `-p zx-storage --features rocksdb` si el entorno tiene la dependencia compilable, `ci/citas-spec.sh`, `ci/alcance-consenso.sh` y `git diff --check`. Si RocksDB falla por entorno, reporta causa exacta. Devuelve lista de archivos tocados, pruebas y límites. **No marques C1 cerrada:** aún falta integración en `zx-node` y validación conjunta.
