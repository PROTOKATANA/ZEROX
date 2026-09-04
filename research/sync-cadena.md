# Sincronización de cadena · Zebra, Bitcoin Core y zcashd

> **Repos anclados y leídos como código, no como documentación:**
> - `ZcashFoundation/zebra` @ `b685fbe3a798c04b22598922f9b945fcac89b75d` (HEAD de `main`, 2026-09-04)
> - `bitcoin/bitcoin` @ `4519933391dd23dbf1a4eceec6dd53d2e9e71cc3`
> - `zcash/zcash` @ `558f686599586f55def3db86955d74d3be44605e`

---

## 0 · El hallazgo que corrige un supuesto nuestro

🔴 **Zebra NO hace headers-first para su propio IBD.**

Nuestro SPEC y la hoja de ruta decían "sync headers-first" citando a Zebra como referencia. Zebra
pide **hashes**, no cabeceras: usa `getblocks` (`FindBlocks` interno) con un locator, nunca emite
`getheaders` como cliente. `FindHeaders` existe, pero solo para **responder** a otro peer.

> `zebra-network/src/protocol/internal/request.rs:100-138`
> ```rust
> /// # Warning
> /// This is implemented by sending a `getblocks` message. … the
> /// response may occasionally contain a single hash of a new chain tip
> /// rather than a list of hashes of subsequent blocks.
> FindBlocks { known_blocks: Vec<block::Hash>, stop: Option<block::Hash> },
> ```
>
> Único uso de `FindHeaders` fuera de tests: `peer_set/set.rs:1052` (detector de *stall*) e
> `inbound.rs:534` (responder a un `getheaders` ajeno).

**No hay un RFC de Zebra que explique por qué.** La razón está dispersa en comentarios de código, no
centralizada. Eso importa: no podemos citar "Zebra lo hace así" como argumento de diseño.

Los tres modelos, entonces:

| | Descubre la cadena con | Valida antes de pedir cuerpo | Anti-DoS de cabeceras |
|---|---|---|---|
| **Bitcoin Core** | `getheaders` — headers-first real | PoW + continuidad de cabecera | `GetAntiDoSWorkThreshold` (post-CVE) |
| **zcashd** | `getheaders` (heredado) | igual | 🔴 **no encontrado** |
| **Zebra** | `getblocks` — locator de hashes | nada: descarga el cuerpo y decide después | no aplica; acota altura y memoria |

---

## 1 · CVE-2019-25220 — headers-first tuvo su propio agujero

Divulgado **2024-09-18**. Un atacante enviaba cadenas de cabeceras de **baja dificultad**; Bitcoin
Core guardaba un `CBlockIndex` por cabecera **sin exigir trabajo acumulado**, hasta tumbar el nodo
por OOM.

Lo que lo vuelve interesante: **el coste del ataque bajó solo con el tiempo**, porque el umbral no
se ajustaba con la dificultad de red — de ~4,12 BTC (32 % de un bloque, enero 2019) a **~0,14 BTC**
(4,4 % de un bloque, septiembre 2024).

El arreglo (PR #25717, más #26355) es un umbral **relativo al tip**, no absoluto:

> `bitcoin/bitcoin@4519933391` `src/net_processing.cpp:749-753`
> ```cpp
> arith_uint256 PeerManagerImpl::GetAntiDoSWorkThreshold()
> {
>     arith_uint256 near_chaintip_work = 0;
>     LOCK(cs_main);
>     if (m_chainman.ActiveChain().Tip() != nullptr) {
>         const CBlockIndex *tip = m_chainman.ActiveChain().Tip();
>         // Use a 144 block buffer, so that we'll accept headers that fork from near our tip.
>         near_chaintip_work = tip->nChainWork
>             - std::min<arith_uint256>(144*GetBlockProof(*tip), tip->nChainWork);
>     }
>     return std::max(near_chaintip_work, m_chainman.MinimumChainWork());
> }
> ```

Más una máquina de estados aparte de *low-work headers presync* que guarda solo un resumen
comprimido hasta que la cadena demuestra trabajo suficiente.

🔶 **zcashd sigue expuesto al mismo patrón.** No se encontró equivalente: acepta cada cabecera con
PoW válido en `mapBlockIndex` vía `AcceptBlockHeader`, y lo único que limita es el tamaño de **un**
mensaje (`MAX_HEADERS_RESULTS = 160`, `src/main.h:115` — más pequeño que los 2000 de Core por el
tamaño de las soluciones Equihash). Nada impide encadenar mensajes.
*Confianza media: búsqueda textual dirigida sobre `main.cpp` (14k+ líneas), no auditoría exhaustiva.*

---

## 2 · Zebra: cómo funciona de verdad

### El bucle no tiene fases

No hay enum de estados. `ChainSync::sync` fuerza el génesis (el protocolo no deja pedirlo por
locator) y luego repite `try_to_sync()` + espera, sin distinguir IBD de régimen estable
(`zebrad/src/components/sync.rs:579-605`).

### "Estoy al día" se mide por longitud de respuesta, no por altura

> `sync/status.rs:24-92`, `sync/recent_sync_lengths.rs:30-36`
> ```rust
> const MIN_DIST_FROM_TIP: usize = 20;
> pub const MAX_RECENT_LENGTHS: usize = 3;
> ```

Media móvil de las **3 últimas** respuestas de `ObtainTips`/`ExtendTips`. Si el promedio de hashes
nuevos cae por debajo de 20, se considera cerca del tip. **No compara altura ni trabajo con el peer.**

Lo consumen el mempool y el gossiper: ninguno de los dos se activa hasta estar cerca del tip.

### `obtain_tips` / `extend_tips` y el workaround del prefijo

`FANOUT = 3` peers en paralelo. Los dos últimos hashes de cada respuesta se guardan como
`CheckedTip { tip, expected_next }` para validar la continuación:

> `sync.rs:954-989`
> ```rust
> // Legacy zcashd nodes could prepend an unrelated hash
> // to their response. Check the first hash against the
> // previous response, and discard mismatches.
> let unknown_hashes = match hashes.as_slice() {
>     [expected_hash, rest @ ..] if expected_hash == &tip.expected_next => rest,
>     [first_hash, expected_hash, rest @ ..] if expected_hash == &tip.expected_next => rest,
> ```

### Números de descarga

| Constante | Valor | Dónde |
|---|---|---|
| `FANOUT` | 3 | `sync.rs:57` |
| `download_concurrency_limit` | **50** ("2/3 del límite de peers salientes") | `sync.rs:250-256` |
| `BLOCK_DOWNLOAD_TIMEOUT` | **20 s** | `sync.rs:157` |
| `BLOCK_DOWNLOAD_RETRY_LIMIT` | 3 | `sync.rs:157` |
| `checkpoint_verify_concurrency_limit` | **1000** | `sync.rs:100-119` |
| `full_verify_concurrency_limit` | **20** ("para que el usuario vea la altura cambiar en cada log") | idem |
| `MAX_BLOCK_REOBTAIN_RETRIES` | 3 | `sync.rs:70-79` |
| `VERIFICATION_PIPELINE_DROP_LIMIT` | **50 000** alturas por delante del tip | `sync/downloads.rs:59-63` |

Sobre `Hedge`: no solo reintenta, **lanza una petición duplicada a otro peer** si la primera tarda
(`Hedge::new(…, AlwaysHedge, 20, 0.95, 2*SYNC_RESTART_DELAY)`). Y la política de reintento cede el
turno a propósito:

> `zebra-network/src/policies.rs:24-45` — *"We want to choose different peers for retries, so we
> have a better chance of getting each block"*

### Selección de peer: Power-of-Two-Choices

No es round-robin. Se muestrean **2 peers al azar** y se elige el menos cargado, con la carga medida
por `PeakEwma` sobre el RTT (`peer_set/set.rs:918-963`; `EWMA_DEFAULT_RTT = REQUEST_TIMEOUT + 1s`,
`EWMA_DECAY_TIME_NANOS = 200s`).

### Lento ≠ malicioso: son dos mecanismos separados

| | Mecanismo | Consecuencia |
|---|---|---|
| **Lento** | `FindResponseStallTracker`, umbral **3** respuestas vacías consecutivas | **desconecta**, no banea; el contador se olvida al reconectar |
| **Malicioso** | `misbehavior score` por **IP**, tope `MAX_PEER_MISBEHAVIOR_SCORE = 100` | **ban por IP** (`MAX_BANNED_IPS = 20 000`, FIFO) |

Y lo que más importa de la tabla de puntuación: **casi todos los errores "blandos" puntúan 0 a
propósito**, con advisory citado en el propio código:

> `sync/downloads.rs:110-122`
> ```rust
> /// `AboveLookaheadHeightLimit` deliberately falls through unscored, and must
> /// stay that way (GHSA-qhr3-cvch-5fh2): `FindBlocks` responses carry no
> /// address, so the follow-up request goes to an independently chosen, honest
> /// peer that served the block but did not choose its height.
> ```

Los errores de consenso duros (altura de coinbase inválida, subsidio inválido, tx duplicada) puntúan
**100 directo**: ban de un golpe.

### Peers

`peerset_initial_target_size = 25`, saliente `25×3 = 75`, entrante `25×5 = 125`, **total 200**. El
multiplicador de entrada es mayor **a propósito**, documentado como trade-off: *"Zebra puede terminar
conectado a una mayoría de peers que no eligió"* (`zebra-network/src/constants.rs:64-81`).

---

## 3 · El checkpoint verifier, y por qué nos sirve **hoy**

Zebra rutea por altura (`zebra-consensus/src/router.rs:191-213`): por debajo de
`max_checkpoint_height` va al `CheckpointVerifier`, por encima al verificador semántico completo.

El `CheckpointVerifier` acumula bloques **fuera de orden** en un `BTreeMap<Height, Vec<QueuedBlock>>`
(hasta `MAX_QUEUED_BLOCKS_PER_HEIGHT = 4` por altura, para tolerar bifurcaciones), y solo emite
resultados cuando hay una cadena **continua** hash-a-hash-previo entre dos checkpoints. Si falta un
eslabón, revierte al estado anterior sin perder progreso.

Cotas: `MAX_CHECKPOINT_HEIGHT_GAP = 400` alturas (porque `FindBlocks` de zcashd devuelve ≤500 hashes
y Zebra descarta 1-2 por el workaround) y `MAX_CHECKPOINT_BYTE_COUNT = 32 MiB`.

🟢 **Lo aplicable a una cadena nueva, y es lo más útil del informe:**

`CheckpointList::from_list` solo exige que exista una entrada en la **altura 0**. Una lista de **un
solo elemento** es válida:

> `zebra-chain/src/parameters/checkpoint/list.rs:134-141`
> ```rust
> match checkpoints.iter().next() {
>     Some((block::Height(0), _hash)) => {}
>     Some(_) => Err("checkpoints must start at the genesis block height 0")?,
>     None => Err("there must be at least one checkpoint, for the genesis block")?,
> };
> ```
>
> Test dedicado: `zebra-consensus/src/checkpoint/tests.rs::single_item_checkpoint_list`

Con una lista de un elemento, `max_checkpoint_height` degenera a 0 y **todo pasa por el verificador
completo**, sin tocar una línea. O sea: la arquitectura de dos verificadores se puede adoptar **desde
el día uno**, con solo el génesis, y añadir checkpoints en releases posteriores sin rediseñar nada.

---

## 4 · Reorgs llegando por la red

`prospective_tips: HashSet<CheckedTip>` permite seguir **varias puntas a la vez**. Una cadena mejor
anunciada a media sincronización se añade como una punta más y se descarga en paralelo: **el syncer
nunca decide "abandonar" una rama** (`sync.rs:840-873`). Esa decisión vive entera en el estado.

Detalle operativo importante: los anuncios de bloque nuevo se procesan **siempre, incluso durante
IBD**, por una cola independiente (`MAX_INBOUND_CONCURRENCY = 200`). Lo que se pausa hasta estar
cerca del tip es solo la **difusión saliente** — para no inundar la red anunciando mientras vas muy
atrás (`inbound/downloads.rs:49`, `sync/gossip.rs:88-91`).

---

## 5 · Bitcoin Core, para contraste numérico

| Constante | Valor | Dónde |
|---|---|---|
| `BLOCK_DOWNLOAD_WINDOW` | 1024 bloques por delante del ancestro común | `net_processing.cpp:136-155` |
| `MAX_BLOCKS_IN_TRANSIT_PER_PEER` | 16 | idem |
| `BLOCK_STALLING_TIMEOUT_DEFAULT` | 2 s | idem |
| `BLOCK_STALLING_TIMEOUT_MAX` | 64 s | idem |

El timeout de *stalling* **se duplica cada vez que desconecta a un peer**, a propósito: si el cuello
de botella es tu propio ancho de banda, desconectar en cascada empeora las cosas. Y el timeout por
bloque escala con `nPowTargetSpacing * (1 + 0.5 * peers_descargando)`.

---

## Lagunas declaradas

- **No hay RFC de Zebra** que explique la elección `getblocks` sobre headers-first. La evidencia está
  en comentarios dispersos.
- El PR histórico #4468 de Bitcoin Core (headers-first, 2014) **no se leyó línea a línea**; la
  narrativa de "por qué headers-first" viene de fuentes secundarias.
- `MAX_HEADERS_RESULTS = 2000` de Bitcoin Core **no está verificado en código** — se cita de memoria
  del ecosistema. Si va al SPEC, hay que confirmarlo.
- La ausencia del anti-DoS de cabeceras en zcashd es por **búsqueda dirigida**, no auditoría completa.
- No se compararon los valores numéricos de *misbehavior score* por infracción entre las tres
  implementaciones; solo se detallaron los de Zebra.
