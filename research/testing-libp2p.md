# Testear libp2p sin tests intermitentes

> **Fuentes leídas como código:**
> - `libp2p/rust-libp2p` @ tag **v0.56.0**, commit `70082df7e6181722630eabc5de5373733aac9a21`
> - `sigp/lighthouse` @ `e423a66763bb1bd780492d635123f208d80c3538` (rama `master`, **sin tag**)

---

## 0 · Las dos trampas que cambian cómo hay que escribir el código

### 🔴 `tokio::time::pause()` NO controla los temporizadores de libp2p

Búsqueda de `tokio::time::pause|advance|start_paused` sobre **todo** el árbol de v0.56.0: **cero
resultados**. En lighthouse aparece dos veces, y **nunca** en `lighthouse_network`.

La razón es estructural, no un olvido:

> `protocols/kad/src/bootstrap.rs` → `use futures_timer::Delay;` · `use web_time::Instant;`
> `protocols/gossipsub/src/behaviour.rs:34` → `use futures_timer::Delay;`

`tokio::time::pause()` solo afecta a los relojes de `tokio::time`. Kademlia y gossipsub usan
`futures_timer::Delay` —rueda de temporizadores propia, independiente del runtime— y
`web_time::Instant`, que envuelve `std::time::Instant` y **no es mockeable**. Pausar el reloj de
tokio no tiene ningún efecto sobre ellos.

Lo confirma el propio intento de arreglarlo, **posterior a 0.56.0 y sin mergear**:

> [PR #6361](https://github.com/libp2p/rust-libp2p/pull/6361): *"By leveraging Tokio's `test-util`
> feature and explicitly wrapping our mocks for the tests… **Production paths are untouched because
> `futures_timer::Delay` is preserved under `#[cfg(not(test))]`**."*

Es decir: para que funcione hubo que **meter una abstracción de reloj en el código de producción**.
No sale gratis por usar tokio.

Y el fallo que lo motivó es exactamente el antipatrón a evitar
([#6421](https://github.com/libp2p/rust-libp2p/issues/6421), abierto):

```
panicked at protocols/kad/src/bootstrap.rs:275:9:
assertion failed: elapsed < MS_5 * 2
```

Un presupuesto de 10 ms de reloj real, en un runner de CI compartido.

**Consecuencia para `zx-p2p`:** si nuestros temporizadores propios usan `tokio::time::sleep`
—no `futures-timer`—, `#[tokio::test(start_paused = true)]` **debería** funcionar sobre ellos.
🔶 **Hipótesis razonable, no verificada**: no se encontró ningún ejemplo real de eso funcionando con
un `Swarm` vivo en el mismo runtime. **Validar con un test canario antes de construir nada encima.**

### 🔴 `swarm-test` abre TCP real aunque le pidas memoria

`swarm-test/src/lib.rs:397-441`: `listen()` escucha **siempre** en los dos transportes, memoria
**y** `/ip4/127.0.0.1/tcp/0`, sin importar qué helper uses después.

> [#6062](https://github.com/libp2p/rust-libp2p/issues/6062) (abierto): el reportante ve eventos
> `Discovered(...)` con IPs de LAN y de Docker en un test que creía hermético.

Para nosotros importa el doble, porque tenemos **mDNS**.

---

## 1 · `libp2p-swarm-test` — útil para dos nodos, no para el arnés

Crate `libp2p-swarm-test = "0.6.0"`. Depende **incondicionalmente** de `libp2p-tcp`.

```rust
fn new_ephemeral_tokio(behaviour_fn: impl FnOnce(Keypair) -> Self::NB) -> Self;
async fn connect<T>(&mut self, other: &mut Swarm<T>);
async fn dial_and_wait(&mut self, addr: Multiaddr) -> PeerId;
async fn wait<E, P>(&mut self, predicate: P) -> E;
fn listen(&mut self) -> ListenFuture<&mut Self>;
async fn next_behaviour_event(&mut self) -> <B as NetworkBehaviour>::ToSwarm;
async fn loop_on_next(self);
```

Dos nodos, completo (`protocols/request-response/tests/ping.rs:93-104`):

```rust
let mut swarm1 = Swarm::new_ephemeral_tokio(|_| /* behaviour */);
let mut swarm2 = Swarm::new_ephemeral_tokio(|_| /* behaviour */);
swarm1.listen().with_memory_addr_external().await;
swarm2.connect(&mut swarm1).await;
```

⚠️ `ListenFuture::wait` hace **`panic!`** ante un evento inesperado. Con mDNS activo eso es una
bomba de relojería: cualquier vecino en la LAN rompe el test.

---

## 2 · `MemoryTransport` — hermético, pero no determinista

Vive **dentro de `libp2p-core`** (`core/src/transport/memory.rs`), no en un crate aparte.

Un `HUB` global de proceso, `Mutex<FnvHashMap<NonZeroU64, ChannelSender>>`, canales `mpsc` de 4096.
**No toca el stack de red del SO**: sin bind, sin DNS, sin firewall.

```rust
let transport = MemoryTransport::default()
    .upgrade(upgrade::Version::V1)
    .authenticate(noise::Config::new(&local_key)?)
    .multiplex(yamux::Config::default())
    .boxed();
```

**3+ nodos en un test funciona y está probado arriba:** `protocols/kad/src/behaviour/test.rs:159`
construye redes de hasta 20 nodos.

**Honestidad sobre "determinista":** `register_port(0)` usa `rand::random()` en bucle
(`memory.rs:59-73`), y el **orden de entrega de eventos** sigue dependiendo del scheduler. Es
**hermético y rápido**, no reproducible byte a byte. Para eso harían falta `loom` o `turmoil`, que
no usa nadie en este ecosistema.

---

## 3 · Testear un `Codec` sin `Swarm` — el patrón que adoptamos

`protocols/request-response/src/cbor.rs:199-259`:

```rust
use futures_ringbuf::Endpoint;

#[tokio::test]
async fn test_codec() {
    let (mut a, mut b) = Endpoint::pair(124, 124);
    codec.write_request(&protocol, &mut a, esperado.clone()).await?;
    a.close().await?;
    let leido = codec.read_request(&protocol, &mut b).await?;
    assert_eq!(leido, esperado);
}
```

Sin `Swarm`, sin transporte, sin negociación. Aísla el fallo al códec.

Lighthouse hace lo mismo sobre `BytesMut` con `encode_then_decode_response`
(`rpc/codec.rs:1229-1301`) — un roundtrip byte-exacto plano.

---

## 4 · Probar un límite de tamaño — y el matiz de `.take()`

⚠️ **`AsyncReadExt::take(N)` NO produce un error de "demasiado grande": trunca en silencio.** La
memoria queda acotada, que es lo importante, pero el fallo llega como error de parseo, no como
"excede el límite". Para rechazar limpio hay que **comparar los bytes leídos con `N`** y tratar la
igualdad como sospecha de truncamiento.

### El patrón bueno: mentir en el prefijo de longitud

`lighthouse/beacon_node/lighthouse_network/src/rpc/codec.rs:2270-2317`:

```rust
// Prefijo que declara max_payload_size + 1 …
uvi_codec.encode(chain_spec.max_payload_size + 1, &mut dst)?;
// … pero el cuerpo real son ~130 bytes.
dst.extend_from_slice(writer.get_ref());

assert!(matches!(decode_response(…).unwrap_err(), RPCError::InvalidData(_)));
```

Prueba que el rechazo ocurre **leyendo solo el prefijo**, antes de reservar nada — sin construir un
buffer gigante y sin castigar al CI.

### Y el antipatrón, en sus propias palabras

> `lighthouse/…/tests/rpc_tests.rs:50`
> *"11,000 × 1KB ≈ 11MB, just above the 10MB max_payload_size. **Previously used 100,000 txs
> (~100MB) which caused hangs and timeouts.**"*

Cuando haya que construir el payload real, usar **el tamaño mínimo que cruce el umbral**.

---

## 5 · Lo que este arnés NO puede cubrir

Declararlo es parte del trabajo, no una excusa:

- **NAT y hole punching** — `hole-punching-tests/` es un crate aparte con Docker, por eso mismo.
- **mDNS y descubrimiento en LAN real** — por diseño necesita interfaces reales. Es #6062.
- **Latencia, pérdida, reordenamiento, backpressure real** — `mpsc` de 4096 no modela una red.
- **Timing bajo carga de CI** — roto incluso upstream (#6421).
- **Caída real de proceso.** En el arnés, "caer" un nodo es `drop(swarm)`: prueba el cierre limpio,
  **no** un `kill -9` con estado a medio escribir. Para resync tras caída hacen falta procesos de SO
  reales, y no hay atajo.

---

## 6 · Antipatrones, cada uno con su issue

| Antipatrón | Evidencia |
|---|---|
| Aserciones de reloj real estrictas | [#6421](https://github.com/libp2p/rust-libp2p/issues/6421) — `assert!(elapsed < MS_5 * 2)` |
| Creer que `swarm-test` en memoria es hermético | [#6062](https://github.com/libp2p/rust-libp2p/issues/6062) |
| Aleatorio sin garantizar unicidad | [PR #4030](https://github.com/libp2p/rust-libp2p/pull/4030) |
| Payloads gigantes "por si acaso" | comentario en `rpc_tests.rs:50` |
| Confiar en `tokio::time::pause()` con libp2p | [PR #6361](https://github.com/libp2p/rust-libp2p/pull/6361) |
| Borrar el test flaky en vez de arreglarlo | [PR #4640](https://github.com/libp2p/rust-libp2p/pull/4640) — quic `dial_failure`, **borrado** |

El último merece leerse dos veces: **ni el equipo upstream tiene esto resuelto.** No es un problema
nuestro, es estructural en el ecosistema tal como está en 0.56.0.

---

## Lo que se adopta en `zx-p2p`

1. **Códec** → `futures-ringbuf::Endpoint::pair`, sin `Swarm`. Roundtrip byte-exacto + rechazo por
   prefijo mentiroso.
2. **Un behaviour, dos nodos** → `libp2p-swarm-test`, asumiendo que abre TCP de fondo. **Nunca con
   mDNS activo**, por el `panic!` de `ListenFuture::wait`.
3. **Arnés de 3+ nodos** → `MemoryTransport` **puro**, a mano, siguiendo
   `protocols/kad/src/behaviour/test.rs` (`build_nodes`, `build_connected_nodes`), conducido con un
   único `poll_fn` en round-robin explícito. Sin `swarm-test`.
4. **Temporizadores propios** → `tokio::time`, nunca `futures-timer`, y **un test canario** que
   demuestre que `start_paused` los controla antes de construir nada encima.
5. **Lo no cubierto** → escrito en la matriz de cobertura, no omitido.
