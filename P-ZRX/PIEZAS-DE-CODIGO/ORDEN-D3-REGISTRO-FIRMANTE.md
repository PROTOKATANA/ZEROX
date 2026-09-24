# ORDEN D3 · Registro y firmante local antes del productor

**Ejecutor:** DeepSeek Harness, `deepseek-v4.1-flash`, esfuerzo `high`.
**Estado:** preparación de D3; **no** marcar D3 hasta que D2 use esta ruta para todo sello emitido.

## Alcance y fuentes

Lee `AGENTS.md`, `README.md`, `MIGRACION.md`, `SPEC.md` §6.2 (`C-HDR-03`, `C-HDR-04`) y §11 (`C-GD-04`, `C-GD-07`, `C-GD-10`), además de `P-ZRX/P-FIRMANTE/ESPECIFICACION.md` §3, `informe/INFORME.md`, `informe/INTEGRACION.md` y el prototipo Rust. El prototipo es evidencia y base de portado, no autoridad normativa. Conserva su contrato probado y corrige los riesgos descritos abajo. No hay autorización para alterar el prototipo.

**Archivos permitidos:** exclusivamente `crates/zx-consensus/src/firmante/mod.rs`, `identidad.rs`, `registro.rs`, `crates/zx-consensus/src/lib.rs`, `crates/zx-consensus/tests/firmante_local.rs` y `crates/zx-consensus/Cargo.toml`. En ese manifiesto, mueve la dependencia `ed25519-zebra = { workspace = true }` de `[dev-dependencies]` a `[dependencies]`, pues el firmante de biblioteca necesita `SigningKey`; no añadas otra dependencia. `zx-core` y `thiserror` ya son dependencias normales. Ningún otro archivo, especialmente raíz `Cargo.toml`/`Cargo.lock`, `SPEC.md`, `ci/`, `PDF/`, `veritas/`, `P-ZRX/` y `zx-node`. Si mover `ed25519-zebra` exige modificar `Cargo.lock`, detente y explica el bloqueo sin tocarlo. Si `std::fs::File::try_lock` no está disponible con MSRV 1.90, detente y explica el bloqueo; no añadas `libc` ni otro paquete por tu cuenta. No hagas commit ni push.

## Frontera y API

Este módulo es **política local del productor**, no condición de consenso: ningún verificador DAG puede invocarlo ni rechazar un bloque remoto porque falte registro. `Firmante::firmar(&mut DagBlockHeader, &SigningKey) -> Result<Resultado, FirmanteError>` calcula `header.pre_hash()` (`C-HDR-03`), deriva internamente la identidad vigente `(public_key, sector_index, history_size, chunk, slot)` de `C-GD-07`, llama al registro y solo firma tras el retorno durable. Debe comprobar que la clave del firmador corresponde a `header.sol.public_key` antes de reservar el registro; si no, error sin mutar el sello ni ocupar la oportunidad. Usa `ed25519-zebra` y comprueba el sello resultante con `DagBlockHeader::verificar_sello()` (`C-HDR-04`). No expongas una variante pública que permita al llamante declarar una identidad no vinculada a la cabecera. No aceptes un `s_max_slots` del candidato; recibe un valor explícito del perfil futuro, sin constante nueva de consenso.

`Resultado`: `Sellado`, `Reemitido`, `AbstenidoPorConflicto { pre_hash_registrado }`. Si hay conflicto, cualquier error de registro o error de firmador, el campo `sello` de entrada queda intacto y no se publica nada; la responsabilidad de descartar el candidato queda explícita. La misma oportunidad con igual `pre_hash` puede reemitirse; con `pre_hash` distinto jamás se firma. La huella local de identidad usa dominio y versión del prototipo; no entra en wire ni altera `C-HASH-05`. Mantén el índice `(huella, slot) -> pre_hash` y cita `C-GD-07` en su definición.

`Registro` usa el formato del prototipo o una versión **nueva declarada** si cambias campos. Debe tomar bloqueo exclusivo entre procesos durante toda su vida con `File::try_lock`, además del `Mutex` entre hilos. `resolver` hace consulta, `write_all`, `sync_all` y solo después permite firma. En cualquier fallo ambiguo de escritura o `sync_all`, envenena esa instancia: toda llamada posterior devuelve error hasta cerrar/reabrir y recuperar el log. Recuperación: checksum por entrada, rechazo de corrupción interior, truncado solo de cola incompleta demostrable. Si una entrada completa reaparece dos veces con mismo índice y distinto `pre_hash`, rechaza el fichero; nunca elijas por orden de llegada. No uses `unwrap_or(0)` ni saturación para convertir un tamaño o desplazamiento de archivo que pueda autorizar una firma.

**Corrige dos huecos de durabilidad del prototipo:**

1. Su `abrir` crea un fichero de abstención pero deja `abstencion_activa` solo en RAM; reabrirlo elimina la abstención. Haz que `abstener_hasta` y su activación queden en cabecera durable y se recuperen tras reinicio. Ante fichero perdido, el alta conservadora se ancla al slot actual con `s_max_slots` explícito; mientras `slot <= abstener_hasta` falla cerrado. Si el horizonte desborda `u64`, sigue absteniéndose. No habilites una ruta pública de «registro nuevo sin historia» que permita saltar esa espera tras una pérdida.
2. El `podar` del prototipo reescribe en sitio y podría dejar un log válido pero incompleto tras un corte. Para esta preparación **no portes `podar`**: el log solo crece durante 0.0.1. No implementes una compactación improvisada. La política de poda durable se hará después si llega a ser necesaria.

La creación y sincronización de un fichero nuevo debe incluir el directorio padre cuando el sistema lo permita; documenta y devuelve error si no se puede garantizar la durabilidad de la ruta. Nunca guardes claves privadas en el registro. Ante versión de formato desconocida, falla cerrado.

## Pruebas con rutas independientes

Porta o adapta solo pruebas relevantes del prototipo: distinto padre con mismo billete/slot se abstiene y deja `sello` intacto; mismo `pre_hash` se reemite; billete o slot diferente puede firmarse; reinicio conserva entradas; dos hilos y dos procesos sobre el mismo fichero no firman dos hashes; pérdida crea abstención que **persiste tras otro reinicio**; corrupción interior y duplicado conflictivo fallan cerrado; cola incompleta recuperable; clave firmadora que no corresponde a la cabecera no ocupa oportunidad; fallo de persistencia deja instancia envenenada. Un test de fallo de E/S puede usar una abstracción pequeña de `sync_all` inyectada solo en tests, sin convertir un `Ok` falso en producción. Donde sea práctico, reutiliza el test de aborto por proceso del prototipo; no dejes un test `#[ignore]` que abortaría el runner si se ejecuta con `--include-ignored` sin guardia.

Ejecuta `cargo test -p zx-consensus --locked`, `cargo clippy -p zx-consensus --all-targets --locked -- -D warnings`, `cargo fmt --all -- --check`, `ci/citas-spec.sh`, `ci/frontera-crates.sh` y `git diff --check`. Informa los resultados exactos y lista todos los archivos cambiados. El guardián `ci/alcance-consenso.sh` ya está rojo por una llamada A3 aún no cableada: ejecútalo y reporta su diagnóstico sin editar inventarios para aparentar integración.

## Criterio de esta entrega

Un registro y firmante local portados, recuperables y probados. D3 seguirá abierta hasta que el productor D2 use obligatoriamente `Firmante::firmar` antes de cada sello y no tenga una ruta alternativa de firma; por ahora no hay productor.
