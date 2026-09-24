# Orden C1/A2 · vista causal del primer hijo DAG dev

**Ejecutor:** DeepSeek Harness `deepseek-v4.1-flash`, esfuerzo `high`.
**Salida:** incremento preparatorio, **sin cerrar C1 ni A2**, sin admisión, PoST ni índice persistente.

Lee `AGENTS.md`, `README.md`, `MIGRACION.md`, `SPEC.md` C-GEN-03/07, C-HDR-05, C-POT-06/08, C-GD-03/04 y C-FLU-06/14; `PROMPT.md` §0/§4.1/§8.1, `PROGRESO-0.0.1.md`, `bootstrap_dag_dev.rs`, `dag_causal.rs`, `zx-consensus/src/bloque_dag.rs` (`ContextoDag` y `comprobar_padres_contextual`) y tests relevantes. Revisa `git status` antes de editar. Preserva los cambios ajenos de `TAREAS.md`, `P-ZRX/PROPUESTAS-VIABLES.md`, `P-ECLIPSE`, `P-RELOJ` y `P-ZRX/T-ZRX/ESTADO-RELOJ.md`.

## Archivos permitidos

- Crear `crates/zx-node/src/contexto_genesis_dag_dev.rs` y `crates/zx-node/tests/contexto_genesis_dag_dev.rs`.
- Modificar `crates/zx-node/src/lib.rs` **solo** para exportar el módulo.

No tocar otros crates, `bootstrap_dag_dev.rs`, `dag_causal.rs`, `SPEC.md`, CI, manifiestos/lock ni documentos P-ZRX. No commit ni push. No insertar G en `AlmacenAdmitidosDag`: su contrato es para bloques que superaron PoST y G es un **ancla confiada** de bootstrap dev. No usar la cola de candidatos ni `AlmacenGhostdag::anadir_sintetico` como procedencia.

## Interfaz y procedencia

Crea `pub fn instantanea_primer_hijo(bootstrap: &EstadoBootstrapDagDev, padres: &PadresDag, hash_candidato: BlockHash) -> Result<InstantaneaPrimerHijoDagDev, ErrorContextoPrimerHijoDev>` con campos privados. La única fuente estructural del snapshot es el `EstadoBootstrapDagDev` ya comprobado por `iniciar_bootstrap_dag_dev()`. Una `FuenteRegistrosDag` **privada** responde solo al `hash_congelado_dev()` y construye el registro G con `padres` y `slot` de `bootstrap.bloque_dev().cabecera` (cotejados con el hash congelado), nunca con campos del candidato. Cualquier otra clave responde `None`.

La función sirve **exclusivamente** `padres.count()==1`, seleccionado=G y sin extras. Para otra topología devuelve un error tipado `FueraDeAlcance`, que significa «esta vista aún no alcanza ese candidato», **no** invalidez de consenso. Para `{G}`, llama a `VistaPasadoEstructural::desde_padres` con presupuesto local exacto de un registro y `hash_candidato` recibido. Conserva el error de vista como causa tipada: candidato en su propio pasado, presupuesto agotado, ausencia o incoherencia nunca se convierten en snapshot ni se ocultan. El test de presupuesto cero puede usar una función privada de construcción con presupuesto inyectado; la API pública usa uno. No declares una cifra de consenso: el `1` es el tamaño exacto de la topología del **primer hijo**.

El snapshot expone getters inmutables de `vista()` (solo `{G}`), `hash_genesis_dev()`, `f0_dev()` y `ancla_pot_slot_0_dev()` tomados del bootstrap. Implementa `ContextoDag` **solo** para este snapshot: reconoce G como raíz confiada del perfil dev (`es_bloque_validado(G)` en el sentido especial del bootstrap, documentado; no afirmes que G superó PoST), `slot_de_padre(G)` lee slot 0 del registro, `padre_seleccionado({G})=G`, `es_genesis(G)=true` y consultas de otra clave devuelven el error contextual adecuado en vez de `false`/`0` fabricado. Para `esta_en_el_pasado_de(G,G)` devuelve `false` porque G no es su propio ancestro; ante claves desconocidas devuelve error contextual. No implementes todavía `InstantaneaPot`, `ContextoRangoDag`, `N_dev`, inyecciones, salidas PoT posteriores, contexto de parcela ni altura/rama derivadas: faltan parámetros y evidencia. `comprobar_padres_contextual` solo comprueba padres; su éxito **no** valida la cabecera ni el bloque.

## Pruebas discriminantes

1. Con el bootstrap real, hash dev contra el literal congelado, `{G}` da pasado exactamente `[G]` con `slot=0` y padres de génesis; `f0`/ancla son los getters del bootstrap. Cambiar un campo libre del candidato no cambia el snapshot (solo se usa su hash para detectar autociclo).
2. Padre desconocido, extra adicional, cero padres y `hash_candidato=G` con padre G producen errores tipados; el autociclo debe conservar `CandidatoEnSuPasado`, no disfrazarse de `FueraDeAlcance` ni `PresupuestoAgotado`. Presupuesto cero da `PresupuestoAgotado` en la ruta privada de prueba y no devuelve vista truncada.
3. `comprobar_padres_contextual` sobre una cabecera hija con `{G}` usa el contexto y pasa **solo** la comprobación de padres; una clave ajena falla. `slot(B)=0` puede pasar la cota no estricta de C-HDR-05: no inventes aquí una regla `slot(B)>0` ni afirmes PoT. Las consultas directas de `ContextoDag` con clave ajena deben dar error, sin valores por defecto.
4. No hay API pública que convierta este snapshot en `InstantaneaPot` o que escriba el índice de admitidos. Compruébalo por revisión de API, no con tests que leen texto fuente.

Ejecuta `cargo test -p zx-node --locked --test contexto_genesis_dag_dev`, `cargo test -p zx-node --locked --lib contexto_genesis_dag_dev`, Clippy `--all-targets -D warnings`, formato, `ci/citas-spec.sh`, `ci/alcance-consenso.sh` y `git diff --check`. Informa rutas tocadas y límites. La siguiente decisión, separada, es fijar el perfil PoT/PoAS dev y la historia de pieza antes de producir un bloque; `TIMESTAMP_DEV=1_800_000_000` del fixture no debe tomarse como reloj válido hoy ni cambiarse silenciosamente.
