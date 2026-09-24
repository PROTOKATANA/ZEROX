# Orden C3 · bootstrap aislado del génesis DAG de desarrollo

**Ejecutor:** DeepSeek Harness, `deepseek-v4.1-flash`, esfuerzo `high`.
**Resultado esperado:** ejecutable local que comprueba un génesis DAG dev congelado y expone su estado inicial para la futura ruta DAG. Es un incremento C3; no cierra C3 ni inicia una red.

Lee íntegros `AGENTS.md`, `README.md`, `MIGRACION.md`, `P-ZRX/PIEZAS-DE-CODIGO/PROMPT.md` §0, §4.1 y §8.1, `DECISIONES-0.0.1.md` C3-ARRANQUE y su corrección matemática, `SPEC.md` C-GEN-01/02/03/06/07, C-FLU-06/10, C-HDR-09, C-POT-01/05. Lee el código real antes de editar: `zx-consensus/src/genesis_dag.rs`, `tests/genesis_dag.rs`, `zx-core/src/preimage/flow.rs`, `zx-consensus/src/pot.rs`, `zx-node/src/{lib,main}.rs`. Revisa `git status --short` y preserva los cambios ajenos.

## Archivos autorizados

- Crear `crates/zx-node/src/bootstrap_dag_dev.rs` y `crates/zx-node/tests/bootstrap_dag_dev.rs`.
- Crear `crates/zx-node/src/bin/zx-dag-dev.rs`.
- Modificar `crates/zx-node/src/lib.rs` solo para exportar el módulo.
- Modificar `crates/zx-node/Cargo.toml` solo para declarar `[[bin]] name = "zx-dag-dev" path = "src/bin/zx-dag-dev.rs"` si Cargo no descubre el bin automáticamente. Si lo descubre, conserva el manifest intacto.

No edites `main.rs`, `cadena.rs`, `zx-core`, `zx-consensus`, `zx-storage`, `zx-p2p`, CI, `SPEC.md`, `research/`, `veritas/`, ni otros documentos. No hagas commit ni push. No uses `AlmacenAdmitidosDag` ni `AlmacenGhostdag::anadir_sintetico` para meter el génesis: atribuirían admisión PoST a un fixture. No inventes aceptación de bloques ordinarios.

## Contrato de implementación

En `bootstrap_dag_dev.rs`, define **constantes privadas explícitamente DEV** que reproduzcan exactamente el fixture ya congelado en `zx-consensus/tests/genesis_dag.rs`: mensaje, timestamp `1_800_000_000`, rama `0x0D06_0001`, `POT`, `SR`, solución y sello, y hash literal `04 00 e4 a0 03 2d 96 f3 9b 6c a5 fb 26 2f a8 37 42 29 e8 39 e6 54 90 66 06 e0 69 d8 81 b8 e1 7f`. Documenta cada número como **elegido para el fixture dev**, no medido ni valor de red de lanzamiento. El `hash_esperado` procede del literal, nunca del bloque recién construido. Añade una entropía pública dev literal, documentada como **elegida para desarrollo**, sin presentarla como precompromiso de lanzamiento. El perfil fija `D_dev=0`, un flujo y el `SR` fijo del fixture **solo para preparación**; no fija `N_dev` ni tasa de slots todavía.

`iniciar_bootstrap_dag_dev() -> Result<EstadoBootstrapDagDev, ErrorBootstrapDagDev>` construye con `construir_dag_dev`, comprueba con `comprobar_estructura_y_hash_dag_dev` y solo entonces crea el estado. El estado debe conservar el bloque completo, hash congelado, `f₀ = zx_core::preimage::flow::flujo_genesis(hash)` y **`pot_output(G)` como ancla PoT confiada del slot 0**. Sus campos deben ser privados y los getters deben nombrar explícitamente la condición dev. La coinbase del génesis no se inserta en ningún UTXO. No invoques verificación PoT/PoAS/sello para G ni lo llames `GenesisValido` o `Admitido`; es la excepción provisional C3-ARRANQUE aislada. La función pura `semilla_genesis(hash, entropía)` puede calcularse **solo si queda etiquetada como dato teórico no usado para validar ni derivar el ancla**, pues hacerlo reintroduciría el punto fijo señalado en `DECISIONES`. No la hagas requisito del estado si confunde esa distinción.

El binario `zx-dag-dev` llama únicamente a `iniciar_bootstrap_dag_dev`, sale con código distinto de cero si falla, y en éxito muestra hash dev y aviso claro: `solo bootstrap local; sin red, persistencia ni admisión PoST`. No acepta ni reinterpreta `--red`, `--peer` o `--datos`; no levanta sockets ni abre RocksDB. Mantén `zx-node` principal y mainnet/testnet lineales intactos. C3 seguirá pendiente de inserción DAG real y parámetros de red; este binario solo permite ejecutar y verificar el ancla sin compartir identidad con testnet.

## Pruebas que discriminan errores reales

1. El hash de `iniciar_bootstrap_dag_dev` coincide con el literal congelado y el bloque se reserializa con `bloque_dag_a_bytes` sin cola; el test no construye su valor esperado desde el mismo bloque.
2. Mutar `pot_output` o hash esperado de un perfil de prueba produce `HashNoCoincide`/`CampoNoCoincide`; no expongas API pública para inyectar perfil arbitrario en producción. Si necesitas un helper privado de construcción para probar el fallo, úsalo solo dentro del módulo de test.
3. El bloque contiene una coinbase cero, sin entradas, y el estado no expone método de aplicar UTXO. Prueba contenido concreto, no introspección de fuente ni un assert tautológico.
4. El `f₀` del hash literal coincide con un vector fijo independiente de la llamada bajo prueba (puedes obtenerlo una vez por el vector de `zx-core`/OpenSSL y congelarlo); la salida confiada de slot 0 coincide **exactamente** con el campo `pot_output` del hash dev. No compares `f₀` con la misma función dos veces.
5. `cargo run -p zx-node --bin zx-dag-dev --locked` sale bien e imprime el alcance acotado; argumentos de red ajena fallan.

Ejecuta `cargo test -p zx-node --locked --test bootstrap_dag_dev`, `cargo clippy -p zx-node --all-targets --locked -- -D warnings`, `cargo fmt --all -- --check`, `ci/citas-spec.sh`, `ci/alcance-consenso.sh`, `git diff --check`. Si el test necesita invocar el binario, usa `CARGO_BIN_EXE_zx-dag-dev` y evita dependencias nuevas. Informa archivos tocados, comandos y límites; no marques C3 cerrada.
