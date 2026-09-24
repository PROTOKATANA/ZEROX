# Orden A3 · puerta conjunta verificadora, sin admisión del nodo

**Ejecutor:** DeepSeek Harness, `deepseek-v4.1-flash`, esfuerzo `high`.
**Estado de la pieza:** preparación; A3 no se cierra con esta orden.

Lee `AGENTS.md`, `README.md`, `MIGRACION.md`, `SPEC.md` §6.1–6.2 y §7.1.5, y el estado de `PROGRESO-0.0.1.md`. Inspecciona los diffs existentes antes de editar: A2 y B1 son trabajo en curso que hay que preservar. No hagas commit ni push.

## Archivos declarados

- Crear `crates/zx-consensus/src/cabecera_conjunta.rs` y `crates/zx-consensus/tests/cabecera_conjunta.rs`.
- Modificar `crates/zx-consensus/src/lib.rs` para exponer el módulo.
- Si resulta estrictamente necesario para una prueba espía, modificar `crates/zx-consensus/src/pot_rango.rs` **solo** para una costura de test documentada; no cambiar la semántica PoT ni su API pública ya preparada.

No editar `zx-core`, `zx-node`, `zx-storage`, manifests, `SPEC.md`, `ci/` ni documentos de `P-ZRX/`.

## Propósito y frontera

Implementa una función de **comprobación conjunta de una cabecera DAG ya decodificada**, contra contextos aportados por el llamante. No insertes en GHOSTDAG, no apliques UTXO y no la llames `validar_bloque`: los rasgos `InstantaneaPot`, `ContextoDag` y `ContextoRangoDag` aún permiten mocks y no acreditan un `past(B)` causal. La respuesta exitosa solo significa que **las pruebas locales se han satisfecho contra esos contextos**, no que el bloque esté admitido en producción. No usar `wire_dag::verificar_justificacion_pot`: sigue siendo el stub de `zx-core`, y el verificador real está en `zx-consensus::pot_rango`.

## Interfaz

En `cabecera_conjunta.rs`, define un enum público `EstadoCabeceraConjunta` con tres formas distinguibles: `Comprobada(ComprobacionCabecera)`, `Invalida(MotivoCabeceraInvalida)` y `Pendiente(MotivoCabeceraPendiente)`. `ComprobacionCabecera` debe tener campos privados y documentar que **no** es certificado de admisión. Guarda al menos `block_hash`, `slot_auditado`, `salida_auditada` y `solution_distance` solo si todos los pasos terminaron; getters de solo lectura si son necesarios. Los motivos deben preservar la causa tipada: fallo de padres, rango, sello, PoT, PoAS; faltas contextuales de PoT y de contexto de pieza quedan `Pendiente`, nunca `Invalida` ni `Comprobada`. Si `ConsensusError` no distingue falta contextual y candidato inválido, no clasifiques arbitrariamente: incorpora un motivo `Pendiente` para la falla contextual o limita esos chequeos a un contrato que permita la distinción. No ocultes errores en strings si existe un tipo original.

Firma propuesta (ajústala mínimamente por tipos/lifetimes reales y explica el ajuste): `verificar_cabecera_conjunta<C, G, R, P>(bloque: &BloqueDag, pot: &C, dag: &G, rango: &R, reloj_pot: u64, cache: &mut CachePotVerificada, presupuesto: &mut P, contexto_pieza: Option<&PieceCheckParams>, kzg: &Kzg) -> EstadoCabeceraConjunta` con `C: InstantaneaPot, G: ContextoDag, R: ContextoRangoDag, P: PresupuestoPot`. Extrae cabecera y justificación del **mismo bloque wire**. El `Option` **solo** modela falta de contexto: `None` => `Pendiente(ContextoPiezaAusente)`, jamás pasa como `None` a upstream. `ErrorPoas::ContextoInvalido` también es fallo de contexto y queda `Pendiente`, mientras `EntradaNoCanonica` y `Prueba` son fallos del candidato. Si complica demasiado el tipo, usa un struct de argumentos con préstamos sin clonar contextos.

## Orden obligatorio

1. Comprobar padres con `comprobar_padres_contextual` y condiciones estructurales de `C-HDR-05`; no consultar caché ni gastar AES. `PadreNoValidado` y `SlotDePadreAusente` significan contexto incompleto y quedan `Pendiente`; `GenesisConCeroPadresNoEsGenesis`, `GenesisConPadres`, `SlotDePadrePosterior`, `PadresNoAnticadena` y `PadreSeleccionadoIncorrecto` son `Invalida` cuando el contexto acredita sus datos. Si el rasgo devuelve otro `ConsensusError` cuyo origen sea ambiguo, devolver `Pendiente`, sin cachear invalidez permanente. Para un génesis sin semilla externa, conservar `Pendiente` de PoT, nunca aceptar.
2. `verificar_rango_pot_fase_previa` (estructura y flujo, `C-POT-08` 1/1b). Ante `Invalido` o `Pendiente`, retornar sin verificar sello, caché, AES ni PoAS.
3. `cabecera.verificar_sello()` sobre `pre_hash` canónico (`C-HDR-03/04`). Sello inválido => `Invalida` sin consultar caché ni gastar AES.
4. `verificar_rango_pot_fase_aes` con **el mismo token/contexto** de la fase previa (`C-POT-07/08`). Si `Pendiente` o `Invalido`, no invocar PoAS. La salida auditada viene de `PruebaPotValidada`, nunca de `cabecera.pot_output` futuro. Comprueba su `block_hash` y slot frente a la cabecera antes de usarla; si el tipo hace la discrepancia imposible, indícalo en código.
5. `RangoSolucionValidado::validar(cabecera, rango)` (`C-HDR-06`). `RangoIncorrecto` es `Invalida`; un error contextual ambiguo queda `Pendiente`. Exige `sr.bloque() == Some(cabecera.block_hash())`, nunca el constructor sintético `para_oraculos`. Usa exclusivamente `valor()` de ese resultado para PoAS, sin rederivar SR ni tomar el declarado directamente. La implementación actual del controlador no existe: deja explícita esa precondición en la API y sus docs.
6. Exigir `Some(contexto_pieza)` antes de PoAS. `verificar_solucion_poas(&cabecera.sol, prueba.slot_auditado(), prueba.salida_auditada(), sr.valor(), pieza, kzg)` (`C-POT-03/08` paso 5). Preservar `ErrorPoas` y no sustituir ningún fallo por éxito.

El codec único, `pre_hash` y `block_hash` ya existen en `zx-core::preimage::dag` (`C-HDR-01/03/09`); reutilízalos, no crees otro serializador. `verificar_sello()` ya aplica ZIP-215 a los 32 B de `pre_hash`. No afirmar `C-HDR-02/02b` ni validez global: falta altura derivada y rama contextual activa. El `pot_bundle_count` ya es la longitud del `JustificacionPot` decodificado; la fase previa comprueba la igualdad contextual. Esta puerta de **cabecera** tampoco comprueba compromisos del cuerpo, coinbase o UTXO. No imponer valores de consenso para `D`, `N(s)`, SR, rama, entropía o historia.

## Pruebas y verificación

Prueba el orden con efectos observables: (a) padres/flujo inválidos no llegan a sello/caché/AES; (b) sello inválido tras fase previa no consulta caché ni gasta presupuesto; (c) PoT pendiente o inválido no llega a PoAS; (d) falta de contexto de pieza retorna `Pendiente`; (e) ningún mock se presenta como admisión del nodo. Un helper **privado** puede inyectar cierres espía de sello/PoAS en tests internos; la función pública debe llamar siempre a `cabecera.verificar_sello()` y al PoAS real, sin argumento que permita reemplazarlos. Usa una cabecera **realmente firmada** para llegar a AES en un test de la función pública; no desactives `verificar_sello`. Reutiliza fixtures PoAS existentes donde sea posible; si no hay fixture completo verificable con PoT, prueba por separado los pasos alcanzables y documenta con exactitud la cobertura que falta. Evita pruebas tautológicas de hash con el mismo método a ambos lados.

Ejecuta `cargo fmt --all -- --check`, `cargo test -p zx-consensus --locked`, `cargo clippy -p zx-consensus --all-targets --locked -- -D warnings`, `ci/citas-spec.sh`, `ci/alcance-consenso.sh` y `git diff --check`. Informa el diff real, estado Git y límites pendientes. No marques A3 cerrada ni toques `PROGRESO-0.0.1.md`.
