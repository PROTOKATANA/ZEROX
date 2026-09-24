# Orden a DeepSeek · C1: vista estructural del pasado DAG

Modelo obligatorio: **DeepSeek V4.1 Flash**, esfuerzo `high`, mediante DeepSeek Harness. Es un incremento parcial de C1/A2, no cierre. No hagas commit ni push.

## Contexto

Lee `AGENTS.md`, `README.md`, `MIGRACION.md`, `P-ZRX/PIEZAS-DE-CODIGO/PROMPT.md` y `SPEC.md` C-HDR-05, C-POT-06/08, C-FLU-13/14, C-GD-04. Consulta `crates/zx-core/src/preimage/dag.rs` (`PadresDag`), `crates/zx-consensus/src/{pot_rango.rs,bloque_dag.rs,ghostdag.rs,cabecera_conjunta.rs}` y `crates/zx-node/src/lib.rs`. Lee el estado C1 en `PROGRESO-0.0.1.md`. El almacén `AlmacenCandidatosDag` es una cola reemplazable **no validada**. `AlmacenGhostdag::admitir` solo comprueba SR; `anadir_sintetico` permite entradas libres. `ComprobacionCabecera` no acredita procedencia ni cuerpo. Ninguno puede alimentar una instantánea que afirme pasado PoST validado.

## Archivos permitidos

- Nuevo `crates/zx-node/src/dag_causal.rs`.
- `crates/zx-node/src/lib.rs` para declarar el módulo.
- Tests dentro del módulo o nuevo `crates/zx-node/tests/dag_causal.rs`.

No edites otros archivos, en particular `SPEC.md`, CI, manifiestos, lock, `zx-storage`, `zx-consensus`, `zx-p2p`, `TAREAS.md` ni el resto de `P-ZRX/`. No toques la ruta lineal. Conserva todo cambio previo sin mezclarlo en la entrega.

## Diseño delimitado

1. Implementa una **vista estructural** de la clausura ancestral de los padres de un candidato. Nómbrala de modo que nunca se confunda con un certificado PoST, por ejemplo `VistaPasadoEstructural`. Sus registros contienen solo `hash`, `PadresDag` y `slot`, con datos leídos por una fuente inyectada. No incluyas una marca `validado: bool`, ni una función pública `insertar_validado` o `admitir`. El origen real de bloques PoST verificados todavía no existe.
2. A partir de **todos** los padres de `PadresDag` (seleccionado y extras), recorre transitivamente cada ancestro, deduplica por hash y produce un resultado inmutable y determinista. El resultado es exactamente la unión de padres y sus pasados; no contiene al candidato. Un diamante comparte ancestro una sola vez. No uses punta, cadena seleccionada, orden de llegada, `height`, GHOSTDAG ni la cola de candidatos como fuente implícita.
3. La fuente de registros puede ser un trait o una función inyectada con resultado tipado. Su contrato expresa que la **integración futura** debe leer exclusivamente un índice separado de bloques PoST plenamente admitidos; una implementación de test no acredita nada. Al leer un registro, comprueba que el hash devuelto coincide con la clave pedida. Si falta cualquier padre o ancestro, devuelve error tipado de contexto incompleto; no construyas una vista parcial ni conviertas la ausencia en invalidez del candidato. Detecta ciclos como incoherencia de fuente; no bucles infinitos.
4. Recibe un **presupuesto explícito** de cantidad máxima de registros a visitar o materializar, elegido por el llamante como límite local de recursos y **no** como valor de consenso. Agotarlo devuelve un error distinto de padre/ancestro ausente; nunca devuelve una vista truncada. Usa aritmética comprobada, sin `unwrap` en producción. Evita recursión de pila no acotada. El orden de enumeración puede ser por `BlockHash` canónico ascendente; documenta que es orden de datos, no orden GHOSTDAG ni consenso.
5. Por ahora **no implementes `InstantaneaPot` ni `ContextoDag` sobre esta vista**: sus respuestas requieren flujo, inyecciones, salidas PoT auditadas y GHOSTDAG procedente de admisión real. No derives esos valores de campos del candidato. Tampoco se conecta la vista a `Nodo::atender`, se promocionan candidatos ni se altera la admisión. La inserción futura requerirá verificación integral y publicación atómica junto con GHOSTDAG/UTXO.

## Tests decisivos

- Diamante con dos padres distintos: unión transitiva exacta y ancestro compartido una vez. Compara el conjunto esperado **escrito independientemente** de la rutina bajo prueba.
- Dos padres del mismo slot se conservan; el algoritmo no indexa por slot ni por `height`.
- Falta el padre seleccionado, falta un extra y falta un ancestro profundo: error de ausencia y ninguna vista parcial.
- Un registro devuelto bajo otra clave y un ciclo: errores de incoherencia, sin aceptar.
- Presupuesto suficiente versus uno menor: límite explícito y error sin truncar. Un orden de inserción diferente en la fuente da la misma vista.
- Fixture con un candidato en una estructura separada que la fuente **no** ofrece: no cuenta como antepasado. No conectes `AlmacenCandidatosDag` para fabricar validez.

## Verificación y entrega

Ejecuta `cargo test -p zx-node --locked` (al menos el target del módulo), `cargo clippy -p zx-node --all-targets --locked -- -D warnings`, `cargo fmt --all -- --check`, `ci/citas-spec.sh`, `ci/alcance-consenso.sh` y `git diff --check`. Reporta archivos tocados, tests, API y límites. **C1 y A2 siguen abiertas** hasta que el índice sea alimentado por bloques PoST realmente admitidos y el nodo use la ruta DAG.
