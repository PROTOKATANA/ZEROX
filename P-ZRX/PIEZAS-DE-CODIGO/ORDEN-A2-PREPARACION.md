# Orden A2 · preparación verificable de PoT

**Ejecutor:** DeepSeek Harness, modelo `deepseek-v4.1-flash`, esfuerzo `high`.
**Estado:** preparación de A2; no declarar A2 cerrada ni un bloque PoST válido.

## Archivos permitidos

- `crates/zx-consensus/src/pot_rango.rs`
- `crates/zx-consensus/src/lib.rs`
- `crates/zx-consensus/tests/pot_rango.rs`

No modificar `zx-core`, `zx-node`, `zx-storage`, CI, manifests, lock, SPEC, research, veritas ni otros documentos. Hay cambios de B1 sin commit en `crates/zx-storage/`; déjalos intactos. No hacer commit ni push.

## Problema exacto

`C-POT-08` impone estructura (1), flujo (1b), sello (2), caché (3), AES (4), PoAS (5). Hoy `verificar_rango_pot` agrupa 1/1b/3/4 y A3 no puede insertar el sello entre 1b y 3. Además, `CachePot` es un trait público y `EntradaCachePot` tiene campos públicos: un llamante puede fabricar un portador completo coincidente y saltarse AES. El `PotValido` resultante solo es una salida del núcleo probado con contexto libre; no acredita procedencia causal de producción.

## Implementación solicitada

1. Separar `verificar_rango_pot` en dos fases públicas, con nombres claros. La primera comprueba génesis, padres, diferencia y portadores (paso 1), y consistencia de flujo de todo el pasado (1b), **sin consultar caché ni consumir presupuesto AES**. Devuelve un token opaco de fase previa o `EstadoPot::{PotInvalido,PotPendiente}`; sus campos no serán públicos. El token debe quedar ligado a la cabecera y justificación usadas, al menos con el `block_hash` y un identificador determinista de los bytes de la justificación, o mediante referencias con lifetimes que hagan imposible usarlo para otro candidato. No usar `header.pot_output` como salida del slot auditado.
2. La segunda fase recibe ese token, el contexto, reloj, caché y presupuesto; ejecuta pasos 3/4 y el anclaje final. La API ha de permitir a A3 llamar a la primera fase, verificar sello ZIP-215 y **solo entonces** llamar a la segunda. Si se mantiene la función combinada por compatibilidad de tests, documentar que es solo el núcleo PoT y que no realiza el sello ni el PoAS; no publicarla como validador integral.
3. Sustituir la caché pública inyectable por una caché concreta con estado interno privado, por ejemplo `CachePotVerificada`. Ninguna API pública podrá insertar o deserializar una entrada que el propio verificador no haya validado con `verificar_slot_aes`. Se puede crear vacía. La entrada de 128 B solo se registra tras AES exitoso y bajo la clave contextual `(f,s,semilla,N)`. Una coincidencia completa de **clave y 128 B** evita repetir AES; si bajo la misma clave difieren salida o portador, es `PotInvalido(CacheDiscrepante)` sin AES. Otra clave no invalida. Un acierto de solo 16 B no acredita los siete checkpoints: si se conserva ese caso, debe consumir AES o devolver `Pendiente` por presupuesto. No guardar resultados tras una verificación fallida. Usar aritmética entera comprobada.
4. Mantener `InstantaneaPot` como contrato contextual **no acreditado en producción** y `PotPendiente` si faltan pasado, `D`, `N(s)`, ancla o reloj. No introducir números de consenso ni un `Ok` por omisión. No cambiar `wire_dag::verificar_justificacion_pot` a aceptación: la dependencia `zx-core → zx-consensus` sería circular y aún no existe derivador de pasado validado.
5. Actualizar exports de `lib.rs` y todos los tests de `pot_rango.rs` a la nueva API. Eliminar los tests que precargan caché fabricada y reemplazarlos por calentamiento real: primero verificar con AES y presupuesto suficiente, después verificar con presupuesto cero y exigir acierto. Mutar un checkpoint intermedio manteniendo la salida final para comprobar rechazo de misma clave. Probar que otra clave no causa rechazo, que un presupuesto agotado devuelve `Pendiente`, que una primera fase inválida/pendiente no toca caché/AES, y que el token no se puede usar para otro candidato. Conservar los demás vectores de rango, cruce de inyección, `d=0`, génesis y errores contextuales.

## Reglas y comprobación

Citar con precisión `C-POT-06`, `C-POT-07`, `C-POT-08`, `C-HDR-05`, `C-HDR-07`, `C-FLU-14`, `C-NET-32.2` y `C-NET-33` según cada función. Leer las secciones aplicables de `SPEC.md`, `README.md` y `MIGRACION.md` antes de editar. Ejecutar `cargo fmt --all -- --check`, `cargo test -p zx-consensus --test pot_rango --locked`, `cargo clippy -p zx-consensus --all-targets --locked -- -D warnings`, `ci/citas-spec.sh` y `git diff --check`. Informar de la salida real de cada uno y de cada archivo cambiado. Si la separación segura requiere un archivo fuera de la lista, detenerse y explicar la necesidad sin editarlo.
