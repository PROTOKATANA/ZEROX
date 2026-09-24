# Progreso de ZEROX 0.0.1

**Estado:** 1/18 piezas cerradas (A1). `PROMPT.md` dice 17, pero enumera 18 (A3+B3+C3+D3+E2+F4). Ninguna casilla se marca por trabajo parcial.

## Lista viva

| Pieza | Estado | Dónde vive / próximo paso |
|---|---|---|
| A1 · Verificador PoAS | **cerrada** · C-POT-08 paso 5; aún sin llamada del nodo | `crates/zx-consensus/src/poas.rs`, `tests/poas.rs`; `ci/consenso-pendiente.txt` registra cableado C1/B3 |
| A2 · PoT a wire DAG | pendiente | `zx-consensus/pot_rango.rs`, `zx-core/wire_dag.rs` |
| A3 · Cabecera DAG conjunta | pendiente; primitivas separadas revisadas | `zx-core/preimage/dag.rs`, `zx-consensus/bloque_dag.rs`; cierre tras A2 y contexto causal |
| B1 · UTXO a cadena DAG | pendiente; motor aislado posible, cierre tras B3/C1/C2 | `zx-storage/utxo.rs`, nueva ruta de nodo |
| B2 · Persistir UTXO y undo | pendiente | `zx-storage/` |
| B3 · `validar_bloque` activo | pendiente | `zx-node/cadena.rs`, nueva ruta DAG |
| C1 · Cabecera DAG en nodo/almacén | pendiente | `zx-node/`, `zx-storage/` |
| C2 · GHOSTDAG activo | pendiente | `zx-consensus/ghostdag.rs`, nueva ruta DAG |
| C3 · Génesis DAG | pendiente | `zx-consensus/genesis.rs` |
| D1 · Plotter/auditor | pendiente | integrar API pública Autonomys |
| D2 · Productor | pendiente | módulo nuevo en `zx-node` |
| D3 · Firmante seguro | pendiente | integrar prototipo `P-ZRX/P-FIRMANTE/` |
| E1 · Relé compacto | pendiente | `zx-p2p/rele_compacto.rs`, `servicio.rs` |
| E2 · IBD DAG | pendiente | `zx-node/sync.rs` |
| F1 · Métricas de Δ | pendiente | nueva ruta DAG/red |
| F2 · Métricas DAG | pendiente | nueva ruta DAG |
| F3 · Coste de validación | pendiente | etapas del verificador |
| F4 · Red local reproducible | pendiente | arranque de desarrollo |

## Pruebas de extremo a extremo

- [ ] Tres nodos producen durante 30 min.
- [ ] Los tres convergen y la convergencia se demuestra.
- [ ] Un nodo reiniciado se pone al día; los tests ignorados relevantes pasan.
- [ ] `SolucionPoas` inválida se rechaza en la ruta activa.
- [ ] F1–F3 exportan datos plausibles; toda discrepancia con la simulación se informa.

## Bitácora de entrada

- **2026-09-24T01:26:38+02:00** · `git -C /home/katana/zeo/ZEROX status --short`: salida vacía. `date --iso-8601=seconds`: `2026-09-24T01:26:38+02:00`. Rama `rediseno/v1-spec-first`, HEAD observado `1e7286d`. No había actividad ajena en `crates/`.
- Leídos `AGENTS.md`, `README.md`, `MIGRACION.md`, `research/README.md`, inventarios de `P-ZRX/T-ZRX/` y reglas aplicables de `SPEC.md`. `veritas/LINEO.md` consultado antes de considerar instrumentos; no se ha creado auditoría ni ejecutado Python.
- **Hallazgo de alcance:** `PROMPT.md` enumera 18 casillas y dice 17; se usará 18 para evitar omitir F4. El inventario `PIEZAS-DE-CODIGO.md` es histórico y añade trabajo fuera de esta 0.0.1.
- **Hallazgo documental:** `SPEC.md` §6.1 aún dice al comienzo que el tamaño/offsets DAG «no están fijados», pero C-HDR-01 en la misma sección fija offsets y tamaños. Se toma la regla identificada C-HDR-01 como texto normativo y se deja constancia; no se edita SPEC.
- **Riesgo de validez:** el verificador público `subspace_verification::verify_solution` permite `piece_check_params: None`, que omite la comprobación de inclusión de la pieza. La adaptación ZEROX debe construir siempre `Some` desde contexto validado; si falta, error explícito. El contexto de historia y compromisos aún no está integrado en la ruta activa.
- **Siguiente paso:** enviar `ORDEN-A1.md` a DeepSeek mediante `dsh` con modelo DeepSeek-V41-Flash y esfuerzo `high`, inspeccionar diff real y ejecutar pruebas. No marcar A1 hasta integrar y cerrar sus seis condiciones.
- **2026-09-24 ~01:31–01:34:** primer envío A1 a `dsh` (`deepseek-official/deepseek-flash`, `high`). El proceso leyó código y reglas y se detuvo **sin editar** al detectar que el CI exige registrar una función pública en `ci/consenso-pendiente.txt`, fuera de la zona permitida. También observó que citar `C-FLU-13` como implementada exigiría cambiar dos inventarios; la orden se afinó para citar en código solo `C-POT-08` paso 5, porque A1 no implementa validez absoluta. Se ha solicitado autorización acotada para `ci/`; mientras tanto A1 puede avanzar dentro de sus archivos declarados, sin cerrar casilla.
- **2026-09-24 ~01:45:** segunda entrega A1 de DeepSeek: wrapper y tests PoAS en `crates/zx-consensus`, dependencias por ruta y exclusiones del workspace en `Cargo.toml`; `Cargo.lock` añade paquetes. Reportó 9/9 tests A1 y check/fmt verdes; `ci/citas-spec.sh` verde. Mi inspección detectó una afirmación falsa de `solution_distance` como entrada de peso (C-GD-01 realmente pesa por SR), y los revisores Rust/matemáticas hallaron operaciones sin `checked_*` en el upstream con `PieceCheckParams` arbitrarios. Reproduje además el fallo de Clippy en `spec_numeros.rs`. Corrección detallada en `CORRECCION-A1.md`; **A1 no se marca**. `ci/alcance-consenso.sh` aún requiere decisión sobre la zona `ci/`.
- **2026-09-24 10:04:48+02:00:** corrección A1 de DeepSeek revisada. El adaptador distingue entrada inválida, contexto aritméticamente inválido y error upstream; comprueba sumas/productos/resta antes del verificador, conserva `piece_check_params: Some` y documenta la salida PoT del slot auditado. Corregida la afirmación de peso/distancia. `spec_numeros.rs` cambió solo dos líneas de formato interno para el gate Clippy. **Comprobación independiente del líder:** `cargo fmt --all -- --check` OK; `cargo check --workspace --locked` OK; `cargo test -p zx-consensus --test poas --locked` 14/14 OK; `cargo clippy -p zx-consensus --all-targets --locked -- -D warnings` OK; `ci/citas-spec.sh` OK; `git diff --check` OK. `ci/alcance-consenso.sh` falla únicamente por `zx-consensus::poas::verificar_solucion_poas` no declarada en el inventario; ver `DECISIONES-0.0.1.md` CI-A1. No se ha ejecutado la suite completa ni la red local. **Sigue 0/18, sin commit de pieza.**
- **2026-09-24 ~10:08+02:00 · corrección de alcance del líder:** al volver a contrastar §8 con `ORDEN-A1.md` detecté que **yo había permitido indebidamente** `Cargo.toml` y `Cargo.lock` de la raíz en la orden a DeepSeek. Este los modificó para que Cargo integre por ruta el clon Autonomys; ambos están fuera de la zona original aunque su diff es funcional y compila. Lo comuniqué al usuario y amplié CI-A1 a una decisión explícita sobre conservar esos dos cambios y permitir solo `ci/consenso-pendiente.txt`. No atribuir el error a DeepSeek ni cerrar A1 hasta la respuesta. No se han hecho más cambios de código.
- **2026-09-24 ~10:15+02:00 · revisión independiente B1:** los especialistas Rust y matemática comprobaron que `Cadena::adoptar/extender` consume solo `BlockHeader`, mientras que los cuerpos llegan después. `guardar_bloque` no acredita autorización completa y `bloque_difundido` aún devuelve `Ignorar`; por eso aplicar UTXO al tip de cabeceras o por orden de llegada sería falso. La proyección DAG de `C-ORD-03/04` exige mergeset/colores, conflictos tratados en su orden y una sola aplicación por bloque. B1 queda dividida en **preparación de motor** y **cierre con B3/C1/C2**; sin marcar hasta la ruta activa. Hallazgo además: `UndoData.creados` guarda solo `OutPoint`; `revertir_bloque` verifica presencia, pero `C-REORG-02` exige comparar también el `EntradaUtxo` esperado. Un test de corrupción debe probar rechazo y estado intacto. Se ajustó la hoja de ruta, sin editar código.
- **2026-09-24 ~10:16+02:00 · preparación B1 entregada:** se envió `ORDEN-B1-PREPARACION.md` a DeepSeek-V41-Flash `high`. Solo editó `crates/zx-storage/src/utxo.rs` y `crates/zx-storage/src/error.rs`: `UndoData.creados` conserva ahora `(OutPoint, EntradaUtxo)`, el rollback compara la entrada completa y distingue `UtxoIncoherente`; tests cubren las cuatro partes de `EntradaUtxo` y fallo tardío atómico. Inspeccioné diff y ejecuté independientemente `cargo fmt --all -- --check` (OK), `cargo test -p zx-storage --locked` (28/28 unitarios, integración RocksDB sin tests con features por defecto) y `git diff --check` (OK). DeepSeek reportó Clippy, citas SPEC y diff check OK; `ci/alcance-consenso.sh` sigue fallando **solo por A1**. **B1 sigue pendiente; no hay motor DAG activo ni commit de pieza.**
- **Cambio concurrente ajeno observado:** `TAREAS.md` pasó de limpio en el `git status` de ~10:07 a modificado con mtime **10:12:37+02:00**; la ejecución B1 cambió `utxo.rs` a las 10:14:58. El diff de `TAREAS.md` contiene una actualización extensa de inventario (315 inserciones, 26 eliminaciones), no coincide con la orden B1 ni con su código. Se deja intacto y fuera de cualquier commit de esta entrega; no se atribuye a DeepSeek sin evidencia. Antes de cualquier cierre revisar de nuevo el estado concurrente.
- **2026-09-24T10:17:37+02:00 · verificación final de esta tanda:** `ci/citas-spec.sh` OK (222 reglas, 35 sin cablear); `ci/alcance-consenso.sh` exit 1 solo por `zx-consensus::poas::verificar_solucion_poas`. `git status --short` lista exactamente `Cargo.lock`, `Cargo.toml`, `TAREAS.md`, `crates/zx-consensus/Cargo.toml`, `crates/zx-consensus/src/lib.rs`, `crates/zx-consensus/tests/spec_numeros.rs`, `crates/zx-storage/src/error.rs`, `crates/zx-storage/src/utxo.rs` modificados; `CORRECCION-A1.md`, `DECISIONES-0.0.1.md`, `HOJA-DE-RUTA.md`, `ORDEN-A1.md`, `ORDEN-B1-PREPARACION.md`, `PROGRESO-0.0.1.md`, `crates/zx-consensus/src/poas.rs` y `crates/zx-consensus/tests/poas.rs` sin seguimiento. Sin commits ni push de esta tanda.
- **2026-09-24 ~10:27+02:00 · estado solicitado y revisión A3:** `git status` y HEAD siguen sin cambios de código adicionales; `ci/alcance-consenso.sh` sigue fallando solo por A1. Especialistas Rust y matemáticas revisaron A3 de forma independiente. Codec, hash, sello, controles de padres/slots y portadores existen por separado; la puerta conjunta depende de A2, de la altura DAG derivada (C-HDR-02/02b), del controlador causal de rango (C-HDR-06) y del contexto de pieza. `verificar_rango_pot` reúne los pasos 1/1b/3/4 de C-POT-08; A3 necesita insertar sello (2) antes de caché/AES. Una preparación estructural podría ser parcial, pero no se ha ordenado otra edición ni se declara A3 válida. La dependencia y las pruebas decisivas constan en `HOJA-DE-RUTA.md`.
- **2026-09-24T10:33+02:00 · cierre A1 autorizado:** Katana respondió «AFIRMATIVO» a la excepción acotada para conservar `Cargo.toml`/`Cargo.lock` y añadir únicamente la entrada en `ci/consenso-pendiente.txt`; ver `DECISIONES-0.0.1.md`. La entrada explica que la función pública no llega aún al nodo y se cableará en C1/B3. **Repetición independiente:** `ci/alcance-consenso.sh` OK; `ci/citas-spec.sh` OK (222 reglas, 35 sin cablear); `cargo fmt --all -- --check` OK; `cargo check --workspace --locked` OK; `cargo test -p zx-consensus --test poas --locked` 14/14 OK; `cargo clippy -p zx-consensus --all-targets --locked -- -D warnings` OK; `git diff --check` OK. Los tests prueban una solución positiva con distancia fijada externamente y mutaciones PoS/KZG/PoT/rango, más errores aritméticos sin `panic`. El commit local de A1 incluye solo los archivos exactos de esta pieza y sus documentos de dirección; B1, `TAREAS.md`, y el nuevo `P-ZRX/P-ECLIPSE/` concurrente quedan excluidos. No se ha ejecutado la red local ni la suite completa, que no son cierre de A1.

## Decisiones provisionales

Ningún parámetro de consenso elegido. La excepción mínima de manifiesto, lock e inventario CI-A1 fue autorizada por Katana; consultar `DECISIONES-0.0.1.md`. No introducir configuración de desarrollo ni resolver el derivador de flujo inventando valores.

## Siguiente trabajo

A2 necesita una fuente causal de `InstantaneaPot` desde el pasado DAG validado, salida PoT del slot auditado para A1, y separación de los pasos 1/1b y 3/4 para insertar el sello en el paso 2 de `C-POT-08`. No inventar `D`, `N(s)` ni el controlador de rango. Antes de abrir la siguiente pieza, inspeccionar `git status`: B1 mantiene `crates/zx-storage/src/error.rs`/`utxo.rs` sin commit de cierre y hay cambios concurrentes en `TAREAS.md` y `P-ZRX/P-ECLIPSE/`; preservarlos y no mezclarlos con otra pieza. B1 sigue sin marcar hasta el orden UTXO DAG validado de C1/C2/B3.
