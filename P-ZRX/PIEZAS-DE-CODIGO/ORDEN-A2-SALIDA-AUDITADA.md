# Orden a DeepSeek · preparación A2: salida PoT del slot auditado

Modelo obligatorio: DeepSeek V4.1 Flash, esfuerzo `high`, mediante DeepSeek Harness. No hagas commit ni push. **Esta preparación no cierra A2:** falta instantánea causal de producción e integración con `wire_dag`.

## Lee antes de editar

`AGENTS.md`, `README.md`, `MIGRACION.md`, `SPEC.md` C-POT-03/05/06/07/08, C-HDR-07 y C-NET-32; `crates/zx-consensus/src/{pot_rango.rs,pot.rs,poas.rs}` y `tests/pot_rango.rs`. Lee la nota correctiva de C-POT-05: el reto del slot auditado puede obtenerse de la **propia justificación de B**, pero solo después de verificarla, cuando `d > D`; con `d ≤ D` sale del pasado validado. No confundas `cabecera.pot_output = salida(slot(B)+D)` con `salida(slot(B))`.

## Archivos permitidos

Solo `crates/zx-consensus/src/pot_rango.rs` y `crates/zx-consensus/tests/pot_rango.rs`. Preserva los cambios A2 de la orden/corrección anteriores y el contexto retenido por `TokenRangoPot`. No edites `zx-core`, `wire_dag.rs`, `poas.rs`, `zx-storage`, manifests, lock, CI, SPEC, `TAREAS.md` ni `P-ZRX/`. Si falta una API, reporta el bloqueo; no amplíes la zona. No cambies `C-POT-08` ni la semántica de los tres estados.

## API y cálculo fijados

1. Sustituye el caso unitario `EstadoPot::PotValido` por `EstadoPot::PotValido(PruebaPotValidada)`. `PruebaPotValidada` es un struct público **con todos sus campos privados y sin constructor público**, `Debug + Clone + PartialEq + Eq`. Contiene al menos `bloque: BlockHash`, `slot_auditado: u64`, `salida_auditada: [u8;16]`. Expón getters de solo lectura para que A3 pueda pasar la salida a `poas::verificar_solucion_poas`; si los getters son `pub(crate)`, añade tests unitarios dentro del módulo para observarlos sin hacerlos públicos al nodo. Nadie debe poder fabricar esta prueba en código seguro fuera del módulo. Documenta que **el tipo solo acredita el núcleo PoT contra el `InstantaneaPot` recibido**, que aún puede ser mock o tener procedencia falsa; no es un certificado de validez de bloque.
2. `verificar_rango_pot_fase_aes` solo construye `PruebaPotValidada` **al final**, después de que todos los portadores del rango hayan superado caché contextual o AES y el resultado final iguale `cabecera.pot_output`. Mantén la secuencia C-POT-08: estructura/flujo → sello a insertar por A3 → caché/AES → PoAS futuro. `verificar_rango_pot` sigue siendo solo núcleo y devuelve el mismo `EstadoPot` enriquecido.
3. Calcula `slot_auditado = cabecera.slot`; `slot_base = slot(sp)+D`, `slot_fin = slot(B)+D` con `checked_add` ya existente. Si `slot_auditado > slot_base`, está en los portadores de B: captura la salida del portador cuyo `slot == slot_auditado` **solo después de verificar ese portador**; no consultes `contexto.salida_validada(slot_auditado)` en ese caso. Guarda localmente la salida capturada, pero no publiques la prueba hasta completar y anclar todo el rango. Si `slot_auditado ≤ slot_base` (incluido `d=0`), obtén `contexto.salida_validada(slot_auditado)` de la instantánea del pasado; si falta, `PotPendiente(ContextoAusente...)`, nunca sustituyas por `cabecera.pot_output` ni por cero. No permitas que una salida suministrada por el candidato reemplace esta fuente.
4. El propio `PruebaPotValidada.bloque` se toma de `token.hash_candidato`, ligando la salida al candidato cuya fase previa pasó. No aflojes la atadura de `&C`, cabecera ni justificación del token. Mantén aritmética entera comprobada y los diagnósticos actuales. Si un `slot_auditado > slot_base` no aparece en el rango debido a inconsistencia, devuelve `PotPendiente(ContextoAusente { ... })`, nunca `PotValido`.
5. Corrige la documentación de `pot_rango.rs` sobre el reto: distinguir el ancla de inicio del rango (siempre pasado validado) de la salida auditada (a veces portador propio ya verificado). Conserva la advertencia de que `InstantaneaPot` no acredita causalidad de producción y `wire_dag::verificar_justificacion_pot` permanece pendiente.

## Tests decisivos

- `d > D`: usa un escenario con al menos un portador **después** del slot auditado. El contexto de prueba **no** contiene `salida_validada(slot_auditado)`; el resultado `PotValido` expone exactamente la salida conocida de ese portador. No basta comparar con `cabecera.pot_output`: los dos valores deben ser distintos. Mutar un checkpoint posterior manteniendo el último según el fixture debe producir `PotInvalido` y no una prueba utilizable.
- `d ≤ D`: el contexto sí contiene la salida auditada de un ancestro; se devuelve esa, distinta de `pot_output` cuando corresponde. Eliminarla da `PotPendiente` incluso si el rango AES y el anclaje final verifican. Incluye `d=0`.
- Cambiar solo el `pot_output` del candidato no altera la salida auditada obtenida del contexto; al fallar el anclaje final, no hay `PruebaPotValidada`.
- Presupuesto agotado, caché discrepante, reloj futuro y sello pendiente de A3 siguen sin producir una prueba. Los tests existentes de los tres estados se actualizan por la nueva variante sin convertirlos en tautologías. La prueba de caché caliente conserva presupuesto cero y devuelve la misma salida.
- Añade un doctest `compile_fail` o una comprobación equivalente de que fuera del módulo no se puede construir `PruebaPotValidada` con campos arbitrarios.

## Verificación y entrega

Ejecuta `cargo test -p zx-consensus --locked`, `cargo clippy -p zx-consensus --all-targets --locked -- -D warnings`, `cargo fmt --all -- --check`, `ci/citas-spec.sh`, `ci/alcance-consenso.sh`, `git diff --check`. Reporta cualquier gate que falle por API pública huérfana; **no lo hagas pasar mediante llamadas añadidas solo a tests ni tocando CI**. Devuelve archivos tocados, tests, y límite de integración.
