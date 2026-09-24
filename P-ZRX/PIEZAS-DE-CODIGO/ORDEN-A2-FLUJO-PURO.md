# Orden A2 parcial · hashes del flujo y semilla del génesis

Usa `deepseek-v4.1-flash`, esfuerzo `high`, para **todo el código**. Lee `AGENTS.md`, `README.md`, `MIGRACION.md`, `PROMPT.md`, `veritas/LINEO.md` íntegro antes de escribir tests de cálculo, SPEC §4.5 (`C-HASH-04/05/06`) y §7.1.3–7.1.4 (`C-FLU-06/10`), además de `crates/zx-core/src/hash.rs`, `preimage/mod.rs` y `zx-consensus/src/pot.rs`. No usar el vault externo. No hacer commit ni push.

## Archivos

Editar solo `crates/zx-core/src/hash.rs`, `src/preimage/mod.rs`, `src/preimage/flow.rs` (nuevo), `crates/zx-consensus/src/pot.rs` y tests de esos crates en esos mismos archivos o en nuevos `tests/flow.rs` si son necesarios. No tocar `SPEC.md`, `research/`, `veritas/`, `PDF/`, CI ni otros módulos. No cambiar valores de lanzamiento ni parámetros de consenso pendientes.

## Funciones puras

1. Añadir exactamente las etiquetas de 16 B de la tabla C-HASH-06: `ZZKFlowId_______` y `ZZKFlowGenesis__`. Actualizar el array de etiquetas fijas y su prueba de unicidad/prefijo. `h_d` sigue privado de `zx-core`; no abrir una API que acepte buffers de wire para hashear.
2. En `zx-core::preimage::flow`, exponer funciones con entradas tipadas para:
   - `f_0 = H_flujo(ETIQUETA_GENESIS ‖ block_hash(génesis)) = SHA3-256(ETIQUETA_FLUJO ‖ ETIQUETA_GENESIS ‖ block_hash(génesis))`, tal como dice C-FLU-06 junto a C-FLU-10. Las **dos etiquetas** son distintas y no se uniforman.
   - `flujo_siguiente = H_flujo(flujo_anterior ‖ entropía_j ‖ LE64(t_j))`. No usar `t_{j-1}`: con época saltada el anterior es el valor vigente en `t_j−1`. La función recibe ese valor ya derivado y no afirma seleccionar `I_j`.
3. En `zx-consensus::pot`, añadir `semilla_genesis = blake3(block_hash(génesis) ‖ entropía_externa)[0..16)`, con entropía **explícita** del llamante. No escoger bytes de entropía ni permitir un default implícito. Esta función pura no acredita que se hubiera comprometido la entropía antes del hash, ni valida génesis. Si es necesario un tipo de entropía, no fijar una longitud normativa ausente del SPEC: aceptar `&[u8]` y documentar que el perfil de red fija la codificación.

No derivar de ahí `InstantaneaPot` ni declarar A2 cerrada: faltan `past(B)`, calendario de inyecciones, ancla, N(s), D, controlador SR y bootstrap C-GEN-02. No usar los valores declarados por un candidato como contexto. El código debe citar C-FLU-06/10 y C-HASH-06 por ID solo donde haya comportamiento implementado.

## Tests decisivos

Usar al menos un vector fijo de SHA3-256 calculado **fuera de la función bajo prueba** (por ejemplo `openssl dgst -sha3-256` sobre preimagen exacta de bytes), con la fuente y el orden de bytes anotados. Un test que calcule la expectativa con la misma `h_d` sería circular. Probar que cambiar la etiqueta génesis, el hash, la entropía de inyección y `t_j` cambia las salidas; comprobar LE64 con vector de slot asimétrico. Para BLAKE3, usar un vector fijo independiente si se dispone de oráculo local; en otro caso, comprobar longitud, concatenación inequívoca con entradas fijas y mutaciones sin afirmar independencia del oráculo. Los valores de test no son parámetros de red. No crear ni ejecutar auditorías Python.

## Verificación

`cargo test -p zx-core --locked`, `cargo test -p zx-consensus --locked`, `cargo clippy -p zx-core -p zx-consensus --all-targets --locked -- -D warnings`, `cargo fmt --all -- --check`, `git diff --check`. Ejecutar `ci/citas-spec.sh` y reportar si exige mover **solo** las reglas ahora parciales al inventario `sin-cablear`; el líder editará CI tras inspeccionar. Informar `ci/alcance-consenso.sh` sin falsear el estado activo.
