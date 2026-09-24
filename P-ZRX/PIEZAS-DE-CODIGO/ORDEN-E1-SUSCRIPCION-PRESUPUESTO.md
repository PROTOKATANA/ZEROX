# Orden a DeepSeek · E1: suscripción compacta y presupuesto compartido

Ejecuta con **DeepSeek V4.1 Flash**, esfuerzo `high`, mediante DeepSeek Harness. Esta entrega acerca E1 al transporte real; **no cierra E1**, pues el nodo no valida/reconstruye DAG ni anuncia bloques propios. No hagas commit ni push.

## Lectura obligatoria

Lee `AGENTS.md`, `README.md`, `MIGRACION.md`, `P-ZRX/PIEZAS-DE-CODIGO/PROMPT.md`, `SPEC.md` C-NET-12/21/25/26/27 y el progreso E1. Examina `crates/zx-p2p/src/{config.rs,behaviour.rs,servicio.rs,entrante.rs,presupuesto.rs,rele_compacto.rs}`, `crates/zx-p2p/tests/dos_nodos.rs`, `crates/zx-node/src/main.rs`. Confirma que no hay llamadas `gossipsub.subscribe` en `crates/` y que `Cadena::anuncio_compacto` hereda `Ignorar`. La ruta lineal aún es la que atiende el nodo; no la conviertas en DAG fingiendo validación.

## Archivos permitidos

- `crates/zx-p2p/src/config.rs`, `behaviour.rs`, `servicio.rs`.
- `crates/zx-p2p/tests/dos_nodos.rs` y tests unitarios de esos tres módulos.
- `crates/zx-node/src/main.rs` **solo** para crear/pasar el mismo `Presupuesto` al codec y al bucle.

No edites manifests, lock, CI, `zx-consensus`, `zx-core`, `zx-storage`, `SPEC.md`, `TAREAS.md` ni documentos de `P-ZRX/`. Preserva el árbol actual; el trabajo concurrente externo queda intacto. Si una dependencia obliga a ampliar la zona, informa antes de editarla.

## Cambios

1. `ParametrosRed::topic_bloques()` debe seleccionar únicamente `/zerox/blocks/2` o `/zerox-testnet/blocks/2`; `topic_txs()` conserva `/txs/1`. En `ZxBehaviour::con_presupuesto`, crea gossipsub mutable y suscribe **exactamente** esos dos temas, propagando fallo de `subscribe` como error de configuración de arranque. No suscribas `/blocks/1`: C-NET-25 prohíbe difundir bloques completos por gossip, y dos temas simultáneos duplican tráfico. Deja claro que suscribirse no admite mensajes: el callback compacto actual sigue `Ignorar` sin validación DAG.
2. Corrige `id_por_contenido`: hoy usa solo `SHA3(datos)` y permite que bytes emitidos primero en `/txs/1` consuman el mismo `message_id` de un anuncio legítimo posterior en `/blocks/2`. Construye un ID que incorpore **tema exacto y contenido** con delimitación inequívoca y coste de memoria acotado. Puedes usar `SHA3(SHA3(tema) || SHA3(datos))` con 64 bytes intermedios y la primitiva existente de `zx-core`; documenta que es ID de transporte, no hash de consenso. Mismo tema+bytes = mismo ID independientemente del emisor; mismo bytes+otro tema = ID distinto. Evita reservar otro buffer proporcional al mensaje.
3. Elimina el `Presupuesto::default()` nuevo por mensaje en `BucleRed::juzgar`. Añade un `Presupuesto` de larga vida en `BucleRed`, entregado al construir las `Piezas`; úsalo en cada `despachar`. Haz que `main.rs` cree **una sola instancia** y pase clones del mismo contador tanto a `ZxBehaviour::con_presupuesto` (codec de sync) como a `arrancar`/el bucle. Ajusta los usos en tests. El contrato debe indicar con precisión que la reserva de parseo se libera antes de retener anuncio/callback; compartir el contador **no** completa C-NET-21 para memoria retenida, ni hay cola C-NET-27. No declares cerrada ninguna de esas reglas.
4. Quita la publicación pública con `topico: String` libre de `ManejoRed::difundir`, que permite anunciar bloque completo por `/blocks/1` o datos del canal equivocado. Sustitúyela por una API tipada mínima para `AnuncioCompacto` que serialice con `a_bytes()` y publique solo en `ParametrosRed::topic_bloques()`; conserva, si es necesaria, una API de tx separada que use únicamente `topic_txs()`. `ManejoRed` puede recibir los parámetros de red al arrancar; ajusta solo los callsites existentes. `Comando::Difundir` queda privado al handle o se valida defensivamente en el bucle contra los dos temas configurados. Nunca conviertas bytes parseados ni un candidato no validado en `Veredicto::Aceptar`.

## Pruebas

- `ParametrosRed` mainnet/testnet exponen `/blocks/2`, no `/blocks/1`; los dos temas suscritos son los exactos de esa red y no hay suscripción cruzada.
- `id_por_contenido` separa mismo payload en `/txs/1` y `/blocks/2`, conserva igualdad para mismo tema+payload aun si cambia el emisor, y cambia al cambiar datos.
- En `MemoryTransport` de dos nodos, un anuncio real `AnuncioCompacto` publicado por la API tipada llega al callback del otro nodo y este devuelve `Ignorar`; sin prueba DAG no se retransmite. Usa sincronización acotada de la malla, sin depender de un `sleep` fijo como única condición. Bytes truncados y residuales no llegan al callback. Si la prueba de ausencia de retransmisión requiere tres nodos, impleméntala sin hacerla intermitente; si no, deja el límite explícito.
- Una reserva en el **mismo contador** que usa el codec agota temporalmente el parseo compacto; `despachar` devuelve `Ignorar`, no llama al callback y no penaliza. Tras liberar la reserva, un anuncio distinto puede llegar. Comprueba que el contador vuelve a cero. No confundas esa prueba con la garantía sobre objetos retenidos.
- `/blocks/1` no se puede publicar desde el handle ni llega a un suscriptor del nuevo perfil; `/txs/1` mantiene su callback.

## Gates y reporte

Ejecuta `cargo test -p zx-p2p --locked`, `cargo test -p zx-node --locked`, Clippy `-p zx-p2p -p zx-node --all-targets --locked -- -D warnings`, `cargo fmt --all -- --check`, `ci/citas-spec.sh`, `ci/alcance-consenso.sh`, `git diff --check`. Reporta archivos editados, tests reales, límites de red y cualquier gate fallido. **E1 permanece abierta** hasta la reconstrucción/validación DAG asíncrona del nodo, la cola huérfana y el relé completo.
