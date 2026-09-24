# Orden E1/C3 · identidad de transporte DAG dev, sin admitir bloques

**Ejecutor:** DeepSeek Harness `deepseek-v4.1-flash`, esfuerzo `high`.
**Estado esperado:** preparación para conectar `zx-dag-dev` a una red propia; no cierra E1, C3 ni F4.

Lee `AGENTS.md`, `README.md`, `MIGRACION.md`, `SPEC.md` C-NET-01/02/12/25/26 y `PROMPT.md` §0/§4.1/§8.1. Lee `PROGRESO-0.0.1.md` y el commit local `8a485b7`; preserva `TAREAS.md`, P-ECLIPSE y P-RELOJ. Examina `zx-p2p/src/{config,behaviour,codec,mensaje,servicio}.rs`, todos los tests existentes y el diff inicial antes de editar.

## Hallazgo que gobierna la orden

`ParametrosRed::magic()` existe, pero el `magic` **no aparece en el wire** del codec sync ni del gossip actual. Por tanto una cifra `magic` distinta **no aísla hoy** el tráfico y no acredita C-NET-01. Los protocolos y temas propios dev sí separan los mensajes de aplicación; Noise/ping pueden conservar una conexión libp2p cruzada hasta que el futuro runner coteje el saludo de génesis y la corte. No afirmes que esta orden implementa C-NET-01 ni que `PeerConectado` equivale a identidad DAG verificada.

## Archivos autorizados

- `crates/zx-p2p/src/config.rs` y sus tests internos.
- `crates/zx-p2p/src/behaviour.rs` y sus tests internos.
- `crates/zx-p2p/src/codec.rs` y sus tests internos.
- Si un test de integración independiente aporta evidencia adicional, crear solo `crates/zx-p2p/tests/dag_dev_identity.rs`.

No tocar `zx-node`, `zx-core`, `zx-consensus`, manifests/lock, CI, `SPEC.md`, `research/`, `veritas/`, ni documentación de `P-ZRX/`. No commit ni push. No cambiar los bytes/nombres/puertos de mainnet o testnet ni su codec lineal. No añadir `Red::DagDev` a `zx-core`.

## Configuración

Mantén `ParametrosRed::de(Red)` como única vía mainnet/testnet y añade `ParametrosRed::dag_dev()` **sin parámetros libres**. Modela la identidad interna como enum que separe `Mainnet`, `Testnet`, `DagDev` (o `Publica(Red)`/`DagDev`); ningún valor dev debe disfrazarse de `Red::Testnet`. La API `red()` puede adaptarse a un enum P2P público si hace falta, pero revisa todos sus consumidores y evita pánicos para dev. Los campos del perfil siguen privados y se construyen todos juntos.

Valores **elegidos solo para desarrollo**: `puerto=0` (ephemeral/loopback elegido por el futuro runner), topic bloques `/zerox-dag-dev/blocks/2`, tx `/zerox-dag-dev/txs/1`, sync `/zerox-dag-dev/sync/1`, Kad `/zerox-dag-dev/kad/1`, identify `/zerox-dag-dev/id/1`, agent `zerox/<versión>/dag-dev`. Para conservar un campo `magic` dev, deriva los 4 bytes iniciales de `SHA3-256("ZEROX/dag-dev/magic")` una vez con OpenSSL y congela el literal; testea el vector, distinción de main/testnet y que **todavía es solo metadato, no barrera del wire**. No introduzcas esta cifra como consenso de lanzamiento. Añade getter para protocolo identify; mainnet/testnet conservan `/zerox/id/1`.

En `ZxBehaviour::con_presupuesto`, usa el identify del perfil y desactiva mDNS en dag-dev (como en mainnet), sin cambiar testnet. Mantén suscripción exacta a los dos temas del perfil y el mismo presupuesto compartido. El request-response usa el protocolo sync dev y un codec que admite **solo** `Peticion::Estado` y `Respuesta::Estado(_)` en dag-dev. Las otras variantes (`Cabeceras`, `Bloques`, `FaltantesCompactas`, `NoDisponible`) se rechazan en **lectura y escritura**, antes de servir o publicar datos lineales; errores `InvalidData`/`InvalidInput` según dirección, nunca `Ok` con datos omitidos. Los perfiles públicos conservan el codec completo actual. Implementa el modo dev como campo privado del codec elegido por el constructor de `ZxBehaviour`, no como bandera pública arbitraria. Conserva el cómputo acotado de memoria y error de truncado; no abras una ruta `read_to_end` sin límite.

## Pruebas y aceptación

Tests de configuración: las identidades dev/main/test tienen `magic`, sync, Kad, identify, topics y agent distintos donde corresponda; mainnet/testnet conservan sus valores anteriores; dev no activa mDNS. Coteja el magic dev literal con OpenSSL sin usar Python. Tests del codec con streams en memoria: `Estado` dev ida/vuelta; cada petición/respuesta lineal rechazada tanto al escribir como al leer bytes lineales bajo modo dev; comprueba que el codec público sigue admitiéndolas. Un test de construcción de `ZxBehaviour` verifica protocolo sync dev y que no se suscribe a temas main/test (no confundir configuración con entrega). Si no puede introspectarse la suscripción sin agregar API pública de test, prueba por `gossipsub` real como los tests existentes.

Ejecuta `cargo test -p zx-p2p --locked`, `cargo clippy -p zx-p2p --all-targets --locked -- -D warnings`, `cargo fmt --all -- --check`, `ci/citas-spec.sh`, `ci/alcance-consenso.sh`, `git diff --check`. Reporta exactamente qué aislamiento probaste. La futura orden `zx-dag-dev` hará el saludo en 3 nodos con hash congelado y plazo; esta entrega por sí sola no abre sockets ni demuestra comunicación.
