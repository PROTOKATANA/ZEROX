# Corrección A3 · procedencia, SR y error de historial upstream

**Ejecutor:** DeepSeek Harness, `deepseek-v4.1-flash`, esfuerzo `high`. Lee `ORDEN-A3-PUERTA-PARCIAL.md`, este documento, `AGENTS.md`, `SPEC.md` C-HDR-06/C-GD-01/C-GD-08/C-POT-08 y el diff actual antes de editar. No hagas commit ni push. A3 sigue siendo preparación, no admisión de bloques.

## Archivos declarados

- `crates/zx-consensus/src/cabecera_conjunta.rs`.
- `crates/zx-consensus/tests/cabecera_conjunta.rs`, si una regresión pública lo requiere.
- `crates/zx-consensus/tests/poas.rs` **solo** para una prueba del error upstream descrito abajo, reutilizando su fixture existente.

No editar `zx-core`, `zx-node`, `zx-storage`, `pot_rango.rs`, manifests ni `ci/`.

## Fallo 1 · InvalidHistorySize puede ser culpa del contexto

La puerta actual clasifica todo `ErrorPoas::Prueba(_)` como `Invalida`. En el clon fijado `PDF/autonomys-subspace/crates/subspace-verification/src/lib.rs` la rama de `sector_expiration_check_segment_commitment` devuelve `Error::InvalidHistorySize` cuando `derive_expiration_history_size` retorna `None`. Esa función retorna `None` cuando `history_size + min_sector_lifetime` o `history_size * 4 + min_sector_lifetime` desborda (`subspace-core-primitives/src/sectors.rs` y `segments.rs`). `min_sector_lifetime` lo aporta `PieceCheckParams`, que la puerta aún no acredita. Un bloque podría etiquetarse inválido permanentemente por un contexto local aritméticamente erróneo.

Añade `MotivoCabeceraPendiente::PoasContexto(ErrorPoas)` o nombre equivalente que **conserve el error original**. Mapea `ErrorPoas::Prueba(subspace_verification::Error::InvalidHistorySize)` a `Pendiente`, antes de la rama general `Prueba(_)`. No cambies A1 ni suprimas la verificación upstream. Mantén las demás clasificaciones condicionadas al contexto como están, con documentación explícita de que `InvalidPiece`, `FutureHistorySize` y otros resultados también necesitan pieza/historia causal antes de un rechazo de producción.

Regresión 1: en prueba **interna** de la puerta, usa la costura espía PoAS existente para devolver `ErrorPoas::Prueba(Error::InvalidHistorySize)` después de PoT/sello/SR exitosos y exige `Pendiente` con causa tipada. En `tests/poas.rs`, reutiliza `fixture()` positivo, establece `sector_expiration_check_segment_commitment: Some(...)` con compromiso de tipo correcto y `min_sector_lifetime = HistorySize(u64::MAX)`; verifica que el adaptador real devuelve `ErrorPoas::Prueba(Error::InvalidHistorySize)`, no `panic` ni éxito. No dupliques el ploteo ni generes una solución nueva.

## Fallo 2 · conservar el mismo SR para GHOSTDAG

`ComprobacionCabecera` guarda distancia pero descarta el `RangoSolucionValidado` obtenido en el paso 5. Añade el valor tipado privado y getter de solo lectura `rango_validado() -> RangoSolucionValidado` o equivalente. El resultado debe conservar **esa instancia/copia** de `sr`, sin volver a validar ni reconstruir desde `cabecera.rango_solucion` o `para_oraculos`. La prueba positiva con espía PoAS debe comprobar `sr.bloque() == Some(block_hash)` y `sr.valor()` igual al esperado, además de confirmar que el espía recibió ese valor. Documenta que cuando se conecte C2, GHOSTDAG usará este mismo SR para `w(B)`/`blue_work`, no una rederivación. No conecta GHOSTDAG ahora.

## Fallo 3 · afirmación excesiva sobre circularidad

Corrige el comentario junto a `RangoSolucionValidado::validar` que dice que el candidato no puede declararse como esperado porque entra como `CandidatoSinRango`. Esa vista solo impide leer **directamente** `rango_solucion`; el contexto puede haberlo capturado por otra vía o usar `height`, `timestamp` o `pot_output`, que C-HDR-06 prohíbe como fuente. La garantía causal todavía falta. Alinea doc comments generales si algún otro afirma lo contrario. Tampoco afirmar cobertura integral de C-HDR-01/09: la puerta recibe un `BloqueDag` ya decodificado.

## Verificación

Ejecuta `cargo fmt --all -- --check`, `cargo test -p zx-consensus --locked`, `cargo clippy -p zx-consensus --all-targets --locked -- -D warnings`, `ci/citas-spec.sh`, `ci/alcance-consenso.sh`, `git diff --check`; informa resultados reales. El guardián de alcance puede seguir fallando por la línea de A1 en `ci/consenso-pendiente.txt`: **no** editar `ci/` para hacerlo verde. No marcar A3 cerrada.
