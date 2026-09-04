# libp2p 0.56.0 · arquitectura de `zx-p2p`

> **Fuentes primarias, verificadas contra código, no docs.rs:**
> - `libp2p/rust-libp2p` @ tag **v0.56.0**, commit `70082df7e6181722630eabc5de5373733aac9a21`
> - `ethereum/consensus-specs`, `specs/phase0/p2p-interface.md`, rama `master` (2026-09-04)
>
> Ethereum consensus es la referencia porque es **el usuario serio de gossipsub v1.1**.
> Bitcoin Core y Zebra **no usan gossipsub** — tienen su propio `inv`/`getdata`—, así que no
> existe precedente 1:1 de "cadena PoW con gossipsub afinado". Lo que se tome de allí es
> **derivado**, y va etiquetado como tal.

---

## 0 · Los tres defaults que romperían ZEROX en silencio

Antes que nada, porque son la clase de fallo que no da error:

| Default de libp2p | Valor | Qué rompe en ZEROX |
|---|---|---|
| `gossipsub::max_transmit_size` | **65 536 B** | Nuestros bloques típicos son **100-200 KB** (zona libre 100 KB). **Ningún bloque normal se propagaría.** |
| `gossipsub::validate_messages` | **`false`** | El bloque se **reenvía al mesh antes** de que lo validemos. Amplificación regalada al atacante. |
| `kad::Config::default()` | `/ipfs/kad/1.0.0` | La DHT de ZEROX hablaría el protocolo **público de IPFS**. |

Ninguno de los tres falla al compilar. Los tres son `SHOULD` de configuración explícita.

> `"pub fn default_max_transmit_size() -> usize { 65536 }"` — `protocols/gossipsub/src/config.rs:244-247`
>
> `"When set to true, prevents automatic forwarding of all received messages… the user must
> manually call report_message_validation_result()."` — `config.rs:277-282`
>
> `Config::default() = Self::new(protocol::DEFAULT_PROTO_NAME)` — `protocols/kad/src/behaviour.rs:196-241`

Y un cuarto, de comportamiento:

**`idle_connection_timeout` pasó de `0s` a `10s` en 0.55.0** (`swarm/src/connection/pool.rs:1000`;
CHANGELOG 0.55.0: *"Update default for idle-connection-timeout to 10s. See PR 4967"*). Sigue siendo
**corto para un enlace de sync con huecos**: una conexión abierta solo para pedir rangos de bloques
puede cerrarse entre peticiones. Hace falta `ping` activo o subirlo explícitamente.

---

## 1 · El builder de 0.56 es por fases (typestate)

```rust
libp2p::SwarmBuilder::with_new_identity()      // o with_existing_identity(keypair)
    .with_tokio()
    .with_tcp(tcp::Config::default(), noise::Config::new, yamux::Config::default)?
    .with_quic()
    .with_behaviour(|key| { … })?
    .with_swarm_config(|c| c.with_idle_connection_timeout(…))
    .build()
```

`Swarm::new(transport, behaviour, peer_id)` es de **antes de 0.53** y no compila. Los ejemplos que
circulan por internet suelen ser de esa época.

- `#[derive(NetworkBehaviour)]` va sobre **`struct`**, nunca sobre `enum`:
  `swarm-derive/src/lib.rs:41-48` → `Data::Enum(_) => Err(… "Cannot derive NetworkBehaviour on enums")`.
- Con `.with_relay_client(…)`, el closure de `with_behaviour` pasa a recibir **dos** argumentos
  (`examples/dcutr/src/main.rs:88`). Cambio de firma real, fácil de no ver.

Evidencia: `libp2p/src/builder.rs:1-45`, `libp2p/src/builder/phase/*.rs`, `examples/chat/`,
`examples/file-sharing/`.

---

## 2 · Composición de behaviours

```rust
#[derive(NetworkBehaviour)]
struct ZxBehaviour {
    identify:  identify::Behaviour,
    ping:      ping::Behaviour,
    kademlia:  kad::Behaviour<kad::store::MemoryStore>,
    mdns:      mdns::tokio::Behaviour,               // testnet local, feature-gated
    gossipsub: gossipsub::Behaviour,
    sync:      request_response::Behaviour<ZxSyncCodec>,
    limits:    connection_limits::Behaviour,
}
```

| Behaviour | Lo que NO puede quedarse por defecto |
|---|---|
| `identify` | `agent_version` (por defecto delata `rust-libp2p/x.y.z`). Valorar `hide_listen_addrs` si hay Nym detrás |
| `ping` | Defaults bien (`interval=15s`, `timeout=20s`). Su papel real aquí es **keep-alive** frente al timeout de 10s |
| `kad` | **Nombre de protocolo propio.** `/zerox/kad/1.0.0` |
| `mdns` | Defaults bien. **Gotcha:** hay que llamar `gossipsub.add_explicit_peer()` en `Discovered` o el peer no entra al mesh |
| `connection_limits` | `ConnectionLimits::default()` es **todo `None` = sin límite**. `misc/connection-limits/src/lib.rs:177-227` |

---

## 3 · Request-response propio — y el límite que el trait NO pone

El trait `Codec` (`protocols/request-response/src/codec.rs:26-75`):

```rust
#[async_trait]
pub trait Codec {
    type Protocol: AsRef<str> + Send + Clone;
    type Request: Send;
    type Response: Send;
    async fn read_request<T>(&mut self, p: &Self::Protocol, io: &mut T) -> io::Result<Self::Request>;
    async fn read_response<T>(&mut self, p: &Self::Protocol, io: &mut T) -> io::Result<Self::Response>;
    async fn write_request<T>(&mut self, p: &Self::Protocol, io: &mut T, r: Self::Request) -> io::Result<()>;
    async fn write_response<T>(&mut self, p: &Self::Protocol, io: &mut T, r: Self::Response) -> io::Result<()>;
}
```

🔴 **El trait no impone ningún límite de tamaño.** El `.take(N)` que acota la lectura es
responsabilidad de cada implementación. La de referencia sí lo hace:

> `io.take(self.request_size_maximum).read_to_end(&mut vec)` — `protocols/request-response/src/cbor.rs:60-90`,
> con defaults documentados de **1 MiB petición / 10 MiB respuesta**.

Un `Codec` propio que use `read_to_end` sin `.take(MAX)` deja que un peer reserve memoria arbitraria
**antes** de que el parser de consenso pueda rechazar nada. Es la vía de DoS más barata de todo el
crate.

No usamos `cbor::Behaviour` ni `json::Behaviour`: nuestro formato de cable es Cap'n Proto y la
preimagen es propia. Códec a mano, con `.take()`.

`Config` real (`protocols/request-response/src/lib.rs:310-340`): `request_timeout = 10s`,
`max_concurrent_streams = 100`. Los 10 s pueden quedarse cortos para un bloque de 200 KB por un
enlace lento — **medir, no adivinar** (P-019).

---

## 4 · Por qué gossipsub NO sirve para el IBD

Gossipsub difunde **hacia el mesh actual**. No es un almacén direccionable: no existe forma de pedir
"el bloque de la altura N de hace seis meses". Su caché de deduplicación dura
`duplicate_cache_time = 60s` (`config.rs:515`) y no hay garantía alguna para quien se conecta después.

Es exactamente la separación que hace Ethereum, y la fuente lo dice con todas las letras:

> "The beacon_block topic is used **solely for propagating new** signed beacon blocks to all nodes
> on the networks." — `p2p-interface.md:636`
>
> "BeaconBlocksByRange is primarily used to **sync historical blocks**." — sección `BeaconBlocksByRange v1`

Y el handshake que precede al sync, que es literalmente el patrón que necesitamos:

> "The dialing client MUST send a **Status** request upon connection." … "the client with the lower
> `finalized_epoch` or `head_slot` … SHOULD request beacon blocks from its counterparty via the
> BeaconBlocksByRange request." — sección `Status v1`

Primero un saludo ligero de "dónde está tu tip", después pedir el rango que falta.

**Test de regresión que esto sugiere:** arrancar un nodo nuevo contra una red cuyo historial solo
viajó por gossipsub, y confirmar que **se queda atascado en el génesis**. Si pasa, es que alguien
metió historial por el canal equivocado.

---

## 5 · Gossipsub: parámetros

**Defaults de rust-libp2p 0.56** (`config.rs:502-556`, `TopicMeshConfig::default()` en `:73-87`):

```
mesh_n=6  mesh_n_low=5  mesh_n_high=12  mesh_outbound_min=2
heartbeat_interval=1s   heartbeat_initial_delay=5s
history_length=5        history_gossip=3
duplicate_cache_time=60s
max_transmit_size=65536          ← ROMPE ZEROX, ver §0
validate_messages=false          ← ROMPE ZEROX, ver §0
flood_publish=true
message_id_fn = source_peer_id + sequence_number   ← NO es hash de contenido
```

Ese último también importa: el `message_id` por defecto **no deduplica por contenido**. El ejemplo
`chat` lo sobrescribe a `hash(message.data)` a propósito.

**Producción real (Ethereum consensus, `p2p-interface.md:528-540`):**

```
D = 8   D_low = 6   D_high = 12   D_lazy = 6
heartbeat_interval = 0.7s
fanout_ttl = 60s   mcache_len = 6   mcache_gossip = 3
```

Malla **más agresiva** que el default (8/6/12 frente a 6/5/12).

🔶 **PLAUSIBLE NO DEMOSTRADO.** Los valores de Ethereum son para **slots de 12 s**; ZEROX tiene
bloques de **120 s**, un factor 10. La **topología** (D/D_low/D_high) es transferible porque no
depende de la cadencia; el **`heartbeat`** sí depende. No hay ninguna fuente que diga qué heartbeat
corresponde a 120 s. Si se fija un número en el SPEC, va etiquetado como derivado y **hay que
medirlo** con el arnés multi-nodo antes de cerrarlo → P-019.

### Validación manual: obligatoria

```rust
gossipsub::ConfigBuilder::default()
    .validate_messages()                        // sin esto, se reenvía solo
    .validation_mode(gossipsub::ValidationMode::Strict)
    .message_id_fn(|m| MessageId::from(zx_hash(&m.data)))
    .max_transmit_size(ZX_MAX_BLOCK_GOSSIP)
    .build()?;

// tras validar contra zx-consensus, y NO antes:
gossipsub.report_message_validation_result(&id, &origen, veredicto);
```

Las tres respuestas no son intercambiables (`protocols/gossipsub/src/types.rs:63-72`,
`behaviour.rs:807-809`):

| | Efecto |
|---|---|
| `Accept` | reenvía al mesh |
| `Reject` | descarta **y aplica la penalización P₄** al `propagation_source` |
| `Ignore` | descarta **sin penalizar** |

> "If acceptance = `Reject` the message will be deleted from the memcache and **the P₄ penalty will
> be applied** to the propagation_source. If acceptance = `Ignore` the message will be deleted from
> the memcache but **no P₄ penalty** will be applied."

**El error caro aquí es usar `Reject` donde toca `Ignore`.** Un bloque huérfano —padre todavía
desconocido— no es un bloque inválido: es un bloque que llegó antes de tiempo. Penalizarlo castiga a
peers honestos con otro timing. Ethereum codifica exactamente esa distinción con
`GossipIgnore`/`GossipReject` por condición (`p2p-interface.md:640-700`):

> `raise GossipIgnore("block is from a future slot")`
> `raise GossipReject("invalid proposer signature")`

---

## 6 · Peer scoring y las cuatro capas anti-DoS

`gossipsub.with_peer_score(params, thresholds)?` (`behaviour.rs:916-926`).

`PeerScoreThresholds::default()` (`peer_score/params.rs:53-183`):
`gossip=-10, publish=-50, graylist=-80, accept_px=10, opportunistic_graft=20`.

🔴 **`PeerScoreParams::default().topics` es un `HashMap` vacío.** Es decir: **P1-P4 —el scoring por
tópico, el que mide "primero en entregar" y "tiempo en el mesh"— no actúa en absoluto** hasta que se
rellena un `TopicScoreParams` por cada tópico. Configurar el scoring "por defecto" es configurar
casi nada.

Las cuatro capas, todas necesarias e independientes:

1. **Scoring de gossipsub** — P1-P7, con `topics` rellenado a mano.
2. **`connection_limits`** — porque el default no limita nada.
3. **`.take(MAX)` en el códec** — porque el trait no lo pone (§3).
4. **`max_transmit_size`** — más `idontwant_message_size_threshold` (default 1000 B), que evita
   reenviar duplicados grandes.

🔶 **LAGUNA declarada:** **no existe** una fuente con `PeerScoreParams` de producción para una cadena
PoW con bloques de 100-200 KB cada 120 s. Ethereum es el precedente más cercano y es otro dominio
(attestations, slots de 12 s). Hay que **derivarlo y probarlo**, no copiarlo.

---

## 7 · Los errores típicos, con su issue

1. Copiar un builder anterior a 0.55 → conexiones que mueren solas (`#4121`, `#4912`).
2. Bloques que no se propagan y no dan error → `max_transmit_size` (`#2603`).
3. Kademlia con el protocolo de IPFS → o hablas con IPFS, o no descubres a nadie.
4. `Codec` sin `.take(MAX)` → memoria arbitraria a petición del atacante.
5. `validate_messages=false` → el bloque ya viajó cuando lo rechazas.
6. mDNS descubre pero gossipsub no manda → falta `add_explicit_peer` en `Discovered`.

---

## Etiquetas de certeza — lo que puede ir al SPEC y cómo

| Punto | Estado |
|---|---|
| Builder por fases; `derive` sobre struct | **VERIFICADO** (código + ejemplos) |
| `idle_connection_timeout` 10 s, insuficiente sin ping | **VERIFICADO** |
| `max_transmit_size` 64 KiB < bloque ZEROX → override obligatorio | **VERIFICADO** |
| Kademlia necesita protocolo propio | **VERIFICADO** |
| El `Codec` no limita tamaño; hay que replicar `.take(MAX)` | **VERIFICADO** |
| Validación manual antes de reenviar | **VERIFICADO**, con precedente de diseño en consensus-specs |
| gossipsub inadecuado para IBD; separar tip / histórico | **VERIFICADO** contra consensus-specs |
| `Reject` vs `Ignore` para huérfanos | **VERIFICADO** (API) + **RESPALDADO POR FUENTE** (patrón) |
| D/D_low/D_high/heartbeat para 120 s | 🔶 **PLAUSIBLE NO DEMOSTRADO** — extrapolado de slots de 12 s. Medir (P-019) |
| `PeerScoreParams` concretos | 🔶 **SIN PRECEDENTE DIRECTO** — derivar y probar, no copiar |
