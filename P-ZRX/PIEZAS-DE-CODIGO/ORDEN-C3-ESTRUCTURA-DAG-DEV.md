# Orden C3 · estructura y hash de génesis DAG de desarrollo

**Ejecutor:** DeepSeek Harness, `deepseek-v4.1-flash`, esfuerzo `high`.
**Estado:** preparación C3; no cierra la pieza ni habilita arranque DAG.

Lee `AGENTS.md`, `README.md`, `MIGRACION.md`, `SPEC.md` §15, C-FLU-06, C-HDR-01/02/07/09, `PROGRESO-0.0.1.md` y `DECISIONES-0.0.1.md` C3-ARRANQUE. Examina primero el diff existente de A2/A3/B1/C1; preserva todo. La decisión de bootstrap C3-ARRANQUE se ha planteado al usuario y **no** está respondida: no elijas una exención PoST, no derives la semilla del hash final para validar el mismo génesis, no inventes parámetros de red y no marques el génesis válido.

## Archivos declarados

- Crear `crates/zx-consensus/src/genesis_dag.rs` y `crates/zx-consensus/tests/genesis_dag.rs`.
- Modificar `crates/zx-consensus/src/lib.rs` solo para exponer el módulo (conservando los cambios A2/A3).

No editar `genesis.rs` lineal, `zx-core`, `zx-node`, `zx-storage`, manifests, `ci/`, `SPEC.md` ni documentos de `P-ZRX/`. No commit ni push.

## Interfaz y alcance

Define `ParametrosGenesisDagDev` sin `Default` ni constantes que se puedan confundir con mainnet/testnet: `mensaje_marca_dev` (bytes), `timestamp`, `consensus_branch_id`, `pot_output`, `rango_solucion`, `solucion: SolucionPoas`, `sello` y `hash_esperado: BlockHash`, todos **explícitos**. Si hace falta `&'a [u8]`, fija lifetime sin imponer `'static`. No mezcles `Red::Testnet` lineal con el perfil DAG; el identificador de rama es un dato explícito de desarrollo, no una afirmación de C-HDR-02b. Documenta que el mensaje lineal reutilizado por `coinbase_genesis` se condensa por XOR en 32 B y **no** preserva el texto legible en wire; C-GEN-05 de lanzamiento permanece pendiente.

`construir_dag_dev(&ParametrosGenesisDagDev) -> Result<BloqueDag, ErrorGenesisDagDev>`: reutiliza `genesis::coinbase_genesis` solo como fixture coinbase cero, `zx_core::preimage::block::merkle_root`, `zx_core::body_commitment`, `zx_core::txid`, `PadresDag::genesis()`, `JustificacionPot::vacia()` y `BloqueDag::nuevo`. Fija `height=0`, `slot=0`, un tx coinbase y su lista de testigos vacía, con `merkle_root` y `body_commitment` calculados del mismo tx bajo la rama explícita. No llama a `genesis::comprobar_al_arrancar` lineal ni a `verificar_cabecera_conjunta`, que devuelve `Pendiente` sin bootstrap.

`comprobar_estructura_y_hash_dag_dev(&BloqueDag, &ParametrosGenesisDagDev) -> Result<EstructuraYHashGenesisDagDev, ErrorGenesisDagDev>`: exige timestamp `>= TIMESTAMP_MINIMO_GENESIS`, `height=slot=0`, padres vacíos con hash nulo, justificación vacía, una coinbase exactamente igual a la derivada de `mensaje_marca_dev`, ninguna entrada, `expiry_height=0`, outputs con `Amount::suma` comprobada igual a cero, una lista de testigos vacía, ambos compromisos recalculados con funciones existentes, igualdad de campos declarados explícitos (rama, PoT, SR, solución, sello) y `block_hash == hash_esperado`. `hash_esperado` debe venir del manifiesto/fixture como dato independiente, **no** calcularse del bloque y volver a pasarse en la misma función. Devuelve errores tipados/concretos, sin panics para un candidato recibido. `EstructuraYHashGenesisDagDev` tiene campos privados y nombre/Docs que excluyen **admisión PoST**. No lo llames `GenesisValido` ni lo uses para insertar en estado; la coinbase de génesis **no entra** en UTXO (`C-GEN-03`).

La construcción puede devolver un objeto cuya estructura sea comprobable; eso no fija `D`, `N(s)`, entropía externa, flujo/rango normativos ni política C-GEN-02. Explica en el módulo la circularidad de C-FLU-06 con `block_hash(génesis)` que incluye `pot_output`, solución y sello (C-HDR-09), y que esta API no la resuelve. Evita copiar la exención PoW del génesis lineal.

## Pruebas

Fixture DAG **solo dev** con valores arbitrarios etiquetados como elegidos para test, hash esperado literal congelado en test (no obtenido del propio candidato en el `assert`). Demuestra construcción determinista y comprobación del hash fijo; cambios de timestamp, rama, `pot_output`, SR, solución, sello, coinbase, compromisos, slot/altura, padres, justificación y testigos fallan con motivo, sin `panic`. Prueba coinbase con muchas salidas positivas para asegurar que `Amount::suma` rechaza sin desbordar; no copies `sum::<i64>()` del código lineal. Haz roundtrip `bloque_dag_a_bytes`/`bloque_dag_desde_bytes` con cabecera mínima DAG de 589 B, justificación `count=0` y una tx. Comprueba que un timestamp marcador de posición se rechaza y que el génesis lineal de testnet conserva sus pruebas existentes. No pruebes por tautología `hash_esperado = bloque.cabecera.block_hash()` generado en la misma llamada.

Ejecuta `cargo fmt --all -- --check`, `cargo test -p zx-consensus --locked`, `cargo clippy -p zx-consensus --all-targets --locked -- -D warnings`, `ci/citas-spec.sh`, `ci/alcance-consenso.sh`, `git diff --check`. Informa el alcance real y el fallo de CI heredado de A3 sin editar `ci/`. C3 queda pendiente hasta decidir e integrar el bootstrap y el nodo.
