# Orden F4/C3 · saludo DAG dev de tres nodos, sin bloques

**Ejecutor:** DeepSeek Harness `deepseek-v4.1-flash`, esfuerzo `high`.
**Alcance:** transporte y cotejo real del hash de génesis del perfil local. Incremento F4/C3, sin cierre de pieza ni métricas Δ.

Lee `AGENTS.md`, `README.md`, `MIGRACION.md`, `SPEC.md` C-GEN-01/02/07 y C-NET-01/02/03/05/12, `PROMPT.md` §0/§4.1/§8.1 y `PROGRESO-0.0.1.md`. Examina los commits `8a485b7` y `503c3d3`; lee `zx-node/src/{bootstrap_dag_dev,nodo,main}.rs`, `zx-p2p/src/{entrante,mensaje,servicio,config,behaviour,codec}.rs` y los arneses `zx-p2p/tests/dos_nodos.rs`, `zx-node/tests/tres_nodos.rs`. Revisa `git status` antes de editar. Preserva `TAREAS.md`, P-ECLIPSE y P-RELOJ.

## Archivos autorizados

- Crear `crates/zx-node/src/nodo_dag_dev.rs` y `crates/zx-node/tests/saludo_dag_dev.rs`.
- Modificar `crates/zx-node/src/lib.rs` solo para exportar `nodo_dag_dev`.
- Modificar `crates/zx-node/src/bin/zx-dag-dev.rs` para mantener un runner P2P local con flags `--listen` y `--peer`; conservar la salida de bootstrap/hash ya probada.

No tocar `main.rs`, `cadena.rs`, `sync.rs`, `zx-core`, `zx-consensus`, `zx-storage`, `zx-p2p`, manifests/lock, CI, `SPEC.md`, `research/`, `veritas/` ni documentos P-ZRX. No commit ni push. No usar `Nodo`, `Cadena`, `Sincronizador`, `AlmacenAdmitidosDag` ni `AlmacenGhostdag::anadir_sintetico`: todos pertenecen a la ruta lineal o atribuirían admisión PoST al fixture.

## Handler y criterio de identidad

Implementa un `ManejadorDagDev` de `ManejadorEntrante` construido **solo** desde `EstadoBootstrapDagDev` (o su hash congelado con constructor no libre). `estado()` devuelve exactamente `Estado { genesis: hash_dev, tip: hash_dev, altura: 0, trabajo: [0; 32] }`. Esto es solo el estado inicial de transporte, **no** `blue_work` ni un orden DAG calculado. `bloque_difundido`, `tx_difundida` y `anuncio_compacto` deben devolver `Ignorar`; `cabeceras_desde`/`bloques_por_hash` devuelven vacío y el códec dag-dev ya prohíbe esos tipos de petición. No hay aceptación/retransmisión de anuncios ni producción de bloques. La coinbase no se inserta en UTXO.

Implementa un coordinador `NodoDagDev` de eventos con `ManejoRed`, conjunto pendiente y conjunto `listo`, ambos por `PeerId`. En `PeerConectado` **solo** marca pendiente y pide `Peticion::Estado`. Marca un peer `listo` únicamente si llega `Respuesta::Estado(e)` mientras está pendiente y los cuatro campos concuerdan con el estado local completo: `genesis=tip=hash_dev`, `altura=0`, `trabajo=[0;32]`. Una discrepancia, respuesta de otra variante o fallo de petición causa `desconectar` con motivo no puntuable (`Ilegible` o `Lento`) y elimina el peer de pendiente/listo. `PeerDesconectado` elimina ambos. Un evento tardío sin pendiente no puede marcar listo. El plazo de saludo local es `10 s` **elegido solo para desarrollo**, no parámetro de consenso: el runner llama a un método de expiración periódicamente y desconecta pendientes vencidos sin puntuar. No cuentes `PeerConectado` ni `EventoRed::Suscripcion` como identidad verificada. Evita `sleep` fijo en las pruebas: usa `Instant` inyectable para la expiración.

El bin `zx-dag-dev` primero llama a `iniciar_bootstrap_dag_dev()` y falla **antes de abrir sockets** si el hash no coincide. Solo después crea `ZxBehaviour::con_presupuesto` con `ParametrosRed::dag_dev()` y un `Presupuesto` compartido con `arrancar_con`, transportes TCP+Noise+Yamux; no reutilices ninguna instancia ni protocolo de testnet. Default de escucha `/ip4/127.0.0.1/tcp/0`; `--listen` y cada `--peer` deben restringirse a loopback `127.0.0.1` o `::1` (rechazo explícito de IP/hostname externo), y el `--listen` debe imprimirse con la dirección realmente asignada desde `EventoRed::Escuchando`, para poder lanzar tres procesos locales. Usa `tokio::select!` sobre eventos, señal de apagado y tick de expiración; no bloquees el `Swarm` con trabajo de consenso. En éxito de saludo imprime `peer listo` con PeerId y hash dev; al apagar suelta handles y detén el bucle cooperativamente. El bin no expone flags `--red` ni `--datos`, no abre RocksDB y sigue diciendo que **no admite PoST ni propaga bloques**. No conviertas un bin que escucha en una prueba de producción.

## Pruebas discriminantes

1. `ManejadorDagDev::estado()` contra el **hash literal externo** congelado; callbacks no aceptan ni retransmiten. Test de coordinador: `PeerConectado` no marca listo; `Estado` con los cuatro campos correctos sí; hash, tip, altura o trabajo alterados no; evento tardío y timeout no marcan. El test observa motivo no puntuable sin inspeccionar texto fuente. Si necesitas mock de `ManejoRed`, usa `MemoryTransport` en vez de API de test nueva en P2P.
2. Test de integración con **tres** `Swarm<ZxBehaviour>` reales sobre `MemoryTransport` puro, `ParametrosRed::dag_dev()`, handler y coordinador del mismo código del bin: A–B–C; espera acotada a eventos/estado, no sleeps. A y C no se marcan listos solo por topología o `PeerConectado`; cada enlace debe completar `Estado` y los tres nodos conservar el mismo hash dev. No afirmar convergencia de cadena: no se produce ningún bloque.
3. Peer impostor con `Estado` de hash distinto sobre el mismo protocolo dev: el coordinador lo desconecta y nunca lo marca listo. Peer con perfil mainnet/testnet: protocolo sync no negocia, el plazo lo desconecta; no contar `magic` como barrera del wire. Aclara que una conexión Noise cruzada puede existir hasta entonces.
4. `cargo run -p zx-node --bin zx-dag-dev --locked -- --help` muestra flags locales sin `--red`/`--datos`; escucha no loopback falla antes de abrir socket. Usa subprocess acotado para esta última prueba; no dejes procesos huérfanos.

Ejecuta `cargo test -p zx-node --locked --test saludo_dag_dev`, `cargo test -p zx-node --locked --test bootstrap_dag_dev`, `cargo clippy -p zx-node --all-targets --locked -- -D warnings`, `cargo fmt --all -- --check`, `ci/citas-spec.sh`, `ci/alcance-consenso.sh`, `git diff --check`. Reporta archivos y límites precisos. Si la prueba de tres nodos necesita ajustar un archivo fuera de la lista, detente y repórtalo; no amplíes el alcance sin una corrección explícita.
