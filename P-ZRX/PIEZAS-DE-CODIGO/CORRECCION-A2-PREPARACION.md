# Corrección A2 · atar las dos fases al mismo contexto

**Ejecutor:** DeepSeek Harness `deepseek-v4.1-flash`, esfuerzo `high`.
**Estado:** corrección obligatoria de `ORDEN-A2-PREPARACION.md`; no cerrar A2.

## Hallazgo independiente

La nueva `verificar_rango_pot_fase_previa(&header, &justificacion, &ctx_a)` devuelve un token que solo presta cabecera y justificación. `verificar_rango_pot_fase_aes(token, &ctx_b, ...)` acepta **otro** contexto sin volver a comprobar `C-FLU-14` ni `slot_sp`. Puede validar AES con `D`, ancla, inyecciones, `N(s)` y flujo de B tras haber acreditado solo el pasado de A. Esto viola la unidad contextual de `C-POT-06` y el orden de `C-POT-08`; los 27 tests verdes no cubrían el ataque. `TokenRangoPot::huella_justificacion` no lo resuelve.

## Cambio preciso

1. Hacer que `TokenRangoPot` preste **también** el mismo `&C` (tipo genérico/lifetime apropiado) usado en la fase previa. La fase AES debe recibir el token, reloj, caché y presupuesto, **sin argumento de contexto**; lee el contexto retenido en el token. La función combinada debe adaptarse. No basta con comparar punteros y seguir aceptando contextos de otro objeto. No introducir `unsafe`.
2. Documentar el límite real: `&C` impide pasar otro contexto o mutar normalmente el objeto entre fases, pero un implementador con mutabilidad interior podría cambiar sus respuestas. Por ello esta preparación **no acredita producción**; el derivador futuro entregará una instantánea inmutable del pasado validado. No afirmar que el trait libre por sí solo prueba procedencia o inmutabilidad.
3. Prueba adversarial significativa: construir dos contextos A y B, con B discrepante en un ancestro o `slot_sp`; mostrar que comprobar B por fase previa produce `PotInvalido` o `PotPendiente`, y que el token obtenido con A **no puede** recibir B en la segunda fase por la firma. Un doctest `compile_fail` breve para la llamada antigua `fase_aes(token, &ctx_b, ...)` sirve si compila en la suite. Conserva test de token ligado al candidato y las demás pruebas. No aceptar un test que solo compare hashes del token como cobertura de este fallo.
4. Mantener intacta la caché privada y todos los demás comportamientos. `verificar_rango_pot` combinado sigue siendo **solo** núcleo PoT; A3 debe insertar sello antes de la fase AES y PoAS después de `PotValido`. No tocar el stub de `zx-core`.
5. Corregir el helper de tests que dice «fase previa → sello ZIP-215 → AES»: hoy no llama al sello. Debe llamarse «fase previa → AES (núcleo aislado)». La huella de justificación se calcula y expone pero nunca se compara; como el préstamo inmutable ya ata esos bytes, eliminar la huella y su test tautológico, o justificar con una comprobación real si se conserva.

## Límites y verificación

Archivos permitidos: `crates/zx-consensus/src/pot_rango.rs`, `crates/zx-consensus/src/lib.rs`, `crates/zx-consensus/tests/pot_rango.rs`. No tocar los cambios ajenos en storage, TAREAS ni P-ECLIPSE. Ejecutar `cargo fmt --all -- --check`, `cargo test -p zx-consensus --locked` (incluye doctests), `cargo clippy -p zx-consensus --all-targets --locked -- -D warnings`, `ci/citas-spec.sh` y `git diff --check`. Informar resultados reales y archivos cambiados. No hacer commit ni push.

## Comprobación adicional del líder tras la primera corrección

`ci/alcance-consenso.sh` falla solo por la nueva API pública `zx-consensus::pot_rango::esta_vacia`, usada como auxiliar de tests sin llamada productiva. No hay autorización para ampliar el inventario CI en esta pieza y tampoco tiene sentido declarar ese método como consenso pendiente. **Retira `esta_vacia` de la API pública** y sustituye sus aserciones en tests por observaciones del comportamiento (por ejemplo, tras un calentamiento real, repetir con presupuesto cero; antes de él, exigir `Pendiente(PresupuestoAgotado)`), sin hacer público ningún inspector de caché de uso solo de test. Ejecuta también `ci/alcance-consenso.sh` y reporta su resultado. Conserva todos los demás cambios ya corregidos.
