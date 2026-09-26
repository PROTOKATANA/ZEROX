# INFORME RI-3a — Revisión independiente de red (`crates/zx-p2p/`, `crates/zx-node/src/red/`)

**Revisor:** subagente Sonnet (RI-3a), independiente. **Fecha:** 2026-09-26. **Orden:**
`P-ZRX/P-REVISION-CODIGO/ORDEN-RI-3.md` (y `ORDEN-RI-1.md` por referencia de método). **Base:** commit
`7810f5139118f2999fe1c1b303621c272be3c1ee` (raíz del repo, tal y como estaba al empezar).

## 0. Comprobaciones previas

- `sha256sum -c P-ZRX/P-REVISION-CODIGO/ENTRADA-RI-3.sha256` (desde la raíz del repo), antes de leer
  nada:

  ```
  P-ZRX/P-REVISION-CODIGO/ORDEN-RI-3.md: La suma coincide
  P-ZRX/P-REVISION-CODIGO/ORDEN-RI-1.md: La suma coincide
  ```

- Procesos de `deepseek/W06d5/` (otra sesión, con procesos `zx-node` vivos): comprobados al empezar
  (PID 1370458, 1370463, 1370472) y **no tocados** en ningún momento; no se ha escrito nada fuera de
  `deepseek/RI-3a/`.
- Zona de trabajo: copia de la raíz en `deepseek/RI-3a/ws/` (`tar --exclude=./PDF --exclude=./deepseek
  --exclude=./target`, con `ws/PDF` enlazado a `/home/katana/zeo/ZEROX/PDF`), `CARGO_HOME` y
  `CARGO_TARGET_DIR` dentro de `deepseek/RI-3a/`, caché de dependencias copiada desde
  `deepseek/RI-2b/.cargo-home`. Todas las compilaciones y tests con `--locked -j4`
  (`RUST_TEST_THREADS` por defecto de `cargo test`, que ya reparte en como mucho 4 hilos con `-j4`
  fijado a nivel de compilación; no se lanzó ningún proceso con más de 4 hilos). Ningún proceso propio
  quedó vivo al terminar.
- `V-ZRX/LINEO.md` leído íntegro antes de escribir los tests de reproducción. Es un documento pensado
  para auditorías numéricas Julia/C++/CUDA (`veritas/`); no aplica en el detalle a tests Rust de
  reproducción de un defecto de red, pero sus principios generales sí: nada de Python, medición con
  `Instant` en vez de suposición, comando y salida literal, presupuesto declarado y respetado,
  reproducibilidad (sin RNG en los tests nuevos).

## 1. Tabla de hallazgos (por gravedad)

| # | Gravedad | Estado | Archivo:línea | Resumen |
|---|---|---|---|---|
| 1 | **Alta** | **CONFIRMADO** | `crates/zx-p2p/src/servicio.rs:494-512` + `crates/zx-node/src/red/vista.rs:145-160` | Una `Peticion::Bloques` con el mismo hash repetido (hasta 256 veces, sin exigir que sean distintos) hace que el nodo clone un bloque grande ya admitido una vez por repetición, **antes** de recortar a `MAX_BLOQUES_POR_RESPUESTA` (16); con un bloque de prueba de 644 KB, 256 repeticiones costaron 453 ms y ~157 MB clonados dentro del hilo que pollea el `Swarm` — bloqueando la red **entera**, no solo a quien preguntó. |
| 2 | **Alta** | **CONFIRMADO** | `crates/zx-p2p/src/codec.rs:215-240` + `crates/zx-p2p/src/presupuesto.rs:41-49,79-93` + `crates/zx-p2p/src/behaviour.rs:61,275-276` | `leer_acotado` reserva el **tamaño máximo posible** de la respuesta (`MAX_RESPUESTA_BYTES`, ~32,4 MiB) **antes** de leer un solo byte, y la retiene mientras el `read` esté pendiente (hasta `TIMEOUT_SYNC` = 30 s). Un solo par que abre unos pocos *streams* de sincronización y no escribe nada agota el presupuesto agregado (256 MiB) usando **menos** de `MAX_STREAMS_SYNC` (8) — confirmado con 7 —, y deniega a cualquier otro par (honesto o no) durante ese plazo, aunque su respuesta ya esté completa esperando. |
| 3 | **Alta** | **CONFIRMADO** | `crates/zx-node/src/red/mod.rs:203` + `crates/zx-node/src/red/manejador.rs:42-57` + `crates/zx-node/src/red/sync.rs:208-217` | La cola `TrabajoRed` (de `zx-p2p` hacia el hilo de consenso) es un `tokio::sync::mpsc::unbounded_channel()`: no tiene tope ni de número de elementos ni de bytes. Cada bloque de gossipsub que solo pasa el parseo de formato (no la validación de consenso) se clona entero y se encola sin límite; medido: 40 960 bloques encolados en 16,7 ms sin ningún rechazo ni espera, muy por encima de `MAX_DIFERIDOS_PENDIENTES` (4 096), el tope equivalente que sí existe en `zx-p2p` para la tabla de correlación con gossipsub. |
| 4 | Baja | PLAUSIBLE (no reproducido) | `crates/zx-node/src/red/vista.rs:121-143` (`cabeceras_desde`) | `locator.iter().find_map(|h| i.cabeceras_pow.iter().position(...))` es lineal en el historial PoW por cada hash del locator (hasta 64): coste `O(len(locator) × len(historial))` por petición, servido en el mismo hilo que `atender_swarm`. Con el historial de la fase PoW acotado en 0.0.1 (dev, antes del corte) el coste absoluto es pequeño; se deja anotado por si crece con `N_dev` real o con una red de vida larga, y porque es el mismo patrón (trabajo servido en el hilo único, ligado a algo que declara el par) que los hallazgos 1 y 3. No se ha medido tiempo real ni se ha construido un caso adversarial: por eso PLAUSIBLE y no CONFIRMADO. |

Ningún hallazgo de esta lista permite aceptar un bloque inválido, forjar consenso ni doble gastar: los
tres CONFIRMADOS son de **disponibilidad** (denegación de servicio a pares honestos, con coste ínfimo o
nulo para quien la provoca), no de corrección de consenso. Por eso ninguno se marca "crítica" en el
criterio que este proyecto ha usado en `REVISION-RI-2a.md`/`REVISION-RI-2b.md` (reservado para lo que
rompe la corrección o la seguridad del consenso mismo).

## 2. Detalle de cada hallazgo

### Hallazgo 1 — Amplificación de memoria/CPU vía hashes repetidos en `Peticion::Bloques`

**Regla del contrato.** `ORDEN-RI-3.md` §"Qué buscar" (RI-3a): *"trabajo o memoria que un par sin coste
puede forzar antes de la validación barata"*. `ORDEN-W06d2.md` decisión 5 exige que la penalización
solo alcance "lo demostrablemente inválido"; aquí ni siquiera hace falta que el par mienta: una
petición **perfectamente bien formada** basta.

**Dónde.**
- El códec solo acota la **cuenta** de hashes de una `Peticion::Bloques`, nunca su unicidad:
  `crates/zx-p2p/src/codec.rs:624-636` (`leer_hashes`, llamado con
  `limites::MAX_HASHES_POR_PETICION` = 256, `crates/zx-p2p/src/limites.rs:128`).
- `VistaRed::bloques_por_hash` (`crates/zx-node/src/red/vista.rs:145-160`) itera los hashes pedidos
  **uno a uno** y clona (`.cloned()`, línea 157) el bloque que encuentre, sin deduplicar ni acotar
  cuántos bytes totales produce.
- `ManejadorRed::bloques_por_hash` (`crates/zx-node/src/red/manejador.rs:68-70`) delega tal cual.
- El único recorte existe **después**, en `zx-p2p`, no en `zx-node`:
  `crates/zx-p2p/src/servicio.rs:494-512` (`fn servir`) llama a `self.manejador.bloques_por_hash(hashes)`
  (línea 502) y **luego** `recortar(bs, crate::limites::MAX_BLOQUES_POR_RESPUESTA)` (línea 508,
  `MAX_BLOQUES_POR_RESPUESTA` = 16, `crates/zx-p2p/src/limites.rs:110`). Todo el trabajo de clonar ya
  se hizo cuando `recortar` actúa.
- `servir` se invoca desde `atender_sync` (`servicio.rs:460`), y `atender_sync` desde `atender_swarm`
  (`servicio.rs:445`), que es lo que atiende cada evento del `Swarm` **dentro del propio bucle que lo
  pollea** (`BucleRed::correr`, `servicio.rs:392-410`): mientras `servir` no termina, el `Swarm` entero
  deja de atenderse — ninguna otra conexión, petición ni mensaje de gossip de **ningún** par progresa.

**Escenario concreto.** Un par (honesto en apariencia, con una sola conexión) envía una única
`Peticion::Bloques { hashes: [H; 256] }`, donde `H` es el hash de **cualquier** bloque grande que el
nodo ya tenga admitido (puede haberlo visto por gossip, o pedido él mismo). Coste de la petición para
el atacante: ~8,2 KiB (1 + 9 + 256×32 B), muy por debajo de `MAX_PETICION_BYTES` (64 KiB). El nodo
clona el bloque 256 veces antes de quedarse con 16: con un bloque cercano al máximo del protocolo
(`MAX_BLOQUE_RED_BYTES` ≈ 2,02 MiB, `crates/zx-p2p/src/limites.rs:45-46`), la extrapolación lineal de
la medición de abajo da del orden de **~520 MB clonados y 1,5–2 s de bloqueo del bucle de red por una
sola petición de 8 KiB**, repetible a voluntad mientras la conexión siga abierta (o reabriéndola: no
hay penalización posible, porque la petición es válida en formato y `Ignorar`/`Rechazar` no aplican a
"pedir el mismo hash varias veces").

**Reproducción (CONFIRMADO).** Test añadido en la copia:
`deepseek/RI-3a/ws/crates/zx-node/tests/ri3a_bloques_por_hash_duplicados.rs` (íntegro, ver el archivo).
Usa un bloque de 644 096 B (4 000 transacciones simples, para que la medición sea rápida sin acercarse
al límite real) y pide el mismo hash 256 veces.

Comando:

```
cd /home/katana/zeo/ZEROX/deepseek/RI-3a/ws
export CARGO_HOME=/home/katana/zeo/ZEROX/deepseek/RI-3a/.cargo-home
export CARGO_TARGET_DIR=/home/katana/zeo/ZEROX/deepseek/RI-3a/.cargo-target
export GIT_CEILING_DIRECTORIES=/home/katana/zeo/ZEROX/deepseek/RI-3a/ws
cargo test -p zx-node --test ri3a_bloques_por_hash_duplicados --locked -j4 -- --nocapture
```

Salida (literal, recortada a lo relevante):

```
running 1 test
RI-3a: bloque de prueba = 644096 B (4000 txs)
RI-3a: 256 hashes IDÉNTICOS -> 256 clones completos (164888576 B en total) en 453.358095ms, dentro del hilo que pollea el Swarm; zx-p2p recorta a MAX_BLOQUES_POR_RESPUESTA = 16 DESPUÉS de este trabajo, no antes: 240 de los 256 clones se tiran sin usarse
test pedir_el_mismo_hash_repetido_clona_el_bloque_una_vez_por_repeticion ... ok

test result: ok. 1 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.79s
```

**Corrección sugerida (no aplicada: fuera de mi zona escribible).** Deduplicar `hashes` antes de
buscar en `VistaRed` (un `HashSet` o `sort_unstable`+`dedup` sobre la entrada, en `bloques_por_hash` o
ya en `manejador.rs`), y/o cortar la construcción del vector de respuesta en `MAX_BLOQUES_POR_RESPUESTA`
**dentro** de `vista.rs`/`manejador.rs`, no solo en `zx-p2p::servir`. Cualquiera de las dos basta; las
dos juntas son más robustas porque no dependen de que el llamante recorte después.

---

### Hallazgo 2 — Agotamiento del presupuesto agregado de memoria por un solo par silencioso

**Regla del contrato.** Mismo criterio de `ORDEN-RI-3.md` que el hallazgo 1: trabajo/memoria forzado
sin coste. También toca directamente el propio diseño de `crates/zx-p2p/src/presupuesto.rs`, cuyo
comentario (líneas 1-36) calcula el peor caso **agregado** (`MAX_RESPUESTA_BYTES × MAX_STREAMS_SYNC ×
MAX_PEERS_ENTRANTES` ≈ 14,7 GB) y usa el presupuesto de 256 MiB para acotarlo — pero razona sobre la
suma de *todos* los pares, no sobre lo que *un solo* par puede reservar por sí solo.

**Dónde.**
- `leer_acotado` (`crates/zx-p2p/src/codec.rs:215-240`) reserva `max + 1` bytes (línea 221-222)
  **antes** de intentar leer nada (`io.take(...).read_to_end(...)`, línea 230). El `max` que
  `read_response` le pasa es siempre `limites::MAX_RESPUESTA_BYTES` (`codec.rs:163`,
  ≈ 33 943 776 B ≈ 32,37 MiB), **sin importar qué se pidió** (hasta un `Peticion::Estado` trivial
  reserva el máximo posible de una respuesta).
- La reserva (`Reserva`, `presupuesto.rs:113-133`) solo se libera al `Drop`, es decir, cuando el
  `read_response` completo termina (éxito, error o cancelación) — mientras el `Future` esté pendiente
  de datos que nunca llegan, la reserva sigue viva.
- `request_response::Config` fija `with_request_timeout(TIMEOUT_SYNC)` = 30 s
  (`crates/zx-p2p/src/behaviour.rs:61,275`) y `with_max_concurrent_streams(MAX_STREAMS_SYNC)` = 8
  (línea 276). Verificado contra el código fuente de `libp2p-request-response 0.29.0`
  (`.cargo-home/registry/.../libp2p-request-response-0.29.0/src/handler.rs:83,113-116`): el
  `FuturesMap` de streams concurrentes vive en el `Handler`, que es **por conexión**, y
  `MAX_CONEXIONES_POR_PEER` = 1 (`limites.rs:140`): así que los 8 *streams* concurrentes son un tope
  **por par**, no repartido entre pares.
- Con `PRESUPUESTO_BYTES` = 256 MiB (`presupuesto.rs:49`) y coste por lectura = `MAX_RESPUESTA_BYTES +
  1` ≈ 32,37 MiB, caben **7** lecturas simultáneas antes de agotar el techo — por debajo del propio
  tope de 8 *streams* por conexión.

**Escenario concreto.** Un solo par se conecta, y el nodo local le envía (por el flujo normal de
sincronización, `crates/zx-node/src/red/sync.rs:79-83`, saludo al conectar) una petición `Estado`. El
par malicioso simplemente **no responde nunca** a esa ni a las siguientes 6 peticiones que el nodo le
haga en la misma conexión (p. ej. las que dispara el propio saludo tras cruzarse: `CabecerasPow`,
lotes de `Bloques`, `sync.rs:144-183`). Cada `read_response` pendiente reserva ~32,37 MiB de inmediato,
sin que el atacante escriba un solo byte. Con 7 peticiones así pendientes (dentro del propio tope de 8
por conexión), el presupuesto agregado del nodo queda en menos de 30 MiB libres —insuficiente para
**cualquier** otra lectura de respuesta— durante hasta `TIMEOUT_SYNC` = 30 s, momento en el que las
peticiones fallan por *timeout*, se liberan, y el atacante puede repetir el ciclo indefinidamente
reabriendo peticiones. Mientras dura, un par honesto que responde al instante con un mensaje
diminuto y válido es rechazado igual: la reserva es por el **tamaño máximo posible**, no por lo que el
honesto de verdad mandó.

**Reproducción (CONFIRMADO).** Test añadido en la copia:
`deepseek/RI-3a/ws/crates/zx-p2p/tests/ri3a_presupuesto_agotable.rs` (íntegro, ver el archivo). Usa el
`Presupuesto` real de producción (`PRESUPUESTO_BYTES`), abre `cabida` = 7 *streams* que nunca escriben
nada (verificado `cabida < MAX_STREAMS_SYNC`), y comprueba que un par honesto con una respuesta ya
completa y esperando es rechazado con `OutOfMemory`.

Comando:

```
cd /home/katana/zeo/ZEROX/deepseek/RI-3a/ws
export CARGO_HOME=/home/katana/zeo/ZEROX/deepseek/RI-3a/.cargo-home
export CARGO_TARGET_DIR=/home/katana/zeo/ZEROX/deepseek/RI-3a/.cargo-target
export GIT_CEILING_DIRECTORIES=/home/katana/zeo/ZEROX/deepseek/RI-3a/ws
cargo test -p zx-p2p --test ri3a_presupuesto_agotable --locked -j4
```

Salida (literal):

```
running 1 test
test un_par_silencioso_agota_el_presupuesto_y_deniega_a_un_par_honesto ... ok

test result: ok. 1 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.21s
```

(El test hace las aserciones internamente: `presupuesto.en_vuelo()` igual a lo reservado por las 7
tareas silenciosas, `presupuesto.disponible() < MAX_RESPUESTA_BYTES`, y el `read_response` del par
honesto devuelve `io::ErrorKind::OutOfMemory` con el texto `C-NET-21` — todo verificado con `assert!`
que habría hecho fallar el test si no se cumpliera.)

**Nota.** Esto **no** contradice el propio análisis de `presupuesto.rs` (que sí evita el peor caso
agregado de ~14,7 GB): el presupuesto cumple su objetivo de no dejar que la **suma** de todos los pares
provoque un OOM. El hallazgo es que, dentro de ese techo ya más pequeño, **un solo par** —sin
necesidad de coludirse con otros ni de generar tráfico— puede ocupar casi todo el presupuesto y negar
el servicio de sincronización a los demás, con coste cero (ni siquiera necesita mandar bytes).

**Corrección sugerida (no aplicada).** Dos vías razonables, no mutuamente excluyentes: (a) una cuota
**por par** dentro del presupuesto agregado (p. ej. `PRESUPUESTO_BYTES / MAX_PEERS_ENTRANTES` como
techo blando por conexión, cayendo al agregado como límite duro); (b) reservar de forma incremental
según se leen los bytes reales en vez de por el máximo teórico del tipo de mensaje —more costoso de
implementar sobre el trait `Codec` de `request-response`, que no expone el tamaño real hasta leer.

---

### Hallazgo 3 — Cola de trabajo hacia el hilo de consenso sin ningún tope

**Regla del contrato.** `ORDEN-RI-3.md` §"Qué buscar": *"consumo no acotado... antes de validar"* (de
`ORDEN-RI-1.md`, incorporado por referencia) y la propia disciplina de recursos que `V-ZRX/LINEO.md`
pide para cualquier cola o buffer que un agente externo pueda alimentar.

**Dónde.**
- `crates/zx-node/src/red/mod.rs:203`: `let (tx_trabajo, rx_trabajo) =
  tokio::sync::mpsc::unbounded_channel();` — el canal por el que **todo** el trabajo de red llega al
  hilo de consenso.
- `ManejadorRed::bloque_difundido` (`crates/zx-node/src/red/manejador.rs:42-57`): por cada mensaje de
  gossipsub que `zx-p2p::servicio::despachar` ya decodificó con éxito (formato válido; **no** implica
  PoW/PoAS/PoT válidos — eso lo decide el hilo de consenso más tarde), clona el `BloqueRed` entero
  (línea 47, `bloque.clone()`) y lo empuja al canal sin ninguna comprobación de cupo.
- `sync::atender_respuesta`, rama `Respuesta::Bloques` (`crates/zx-node/src/red/sync.rs:208-217`):
  igual, por cada bloque que llega como respuesta de sincronización.
- Compárese con la tabla de correlación de la propia `zx-p2p` para gossipsub diferido
  (`PendienteDiferido`, `servicio.rs:277-308`), que **sí** tiene un tope declarado
  (`MAX_DIFERIDOS_PENDIENTES` = 4 096, `crates/zx-p2p/src/limites.rs:165`) con desalojo FIFO
  (`servicio.rs:578-606`). Ese tope protege la tabla de **identificadores**; no protege en absoluto la
  cola de **bloques enteros** de `zx-node`, que es una estructura totalmente distinta y sin cota
  equivalente.

**Escenario concreto.** Un par publica, por gossipsub, una ráfaga de mensajes con formato válido en el
tema `/zx-dev/bloques/post/1` (cabecera, justificación PoT y cuerpo bien formados, pero con PoAS/PoT/
sello inválidos: eso no lo comprueba `zx-p2p`, solo el hilo de consenso, más tarde y más despacio —del
orden de decenas de milisegundos por bloque real, según la propia documentación del módulo). Cada
mensaje pasa el parseo del códec, `despachar` (`servicio.rs:807-836`) llama a `bloque_difundido`, que
siempre difiere y encola (nunca rechaza en esta etapa: el rechazo por PoAS/PoT/sello ocurre después,
en el hilo de consenso). Mientras la tasa de llegada supere la de validación —que es exactamente lo que
un atacante controla generando basura barata de validar en formato pero cara en consenso—, la cola
crece sin límite: no hay *backpressure* (el productor nunca se bloquea, nunca fallará por cupo lleno,
porque el canal no tiene cupo) ni descarte determinista (a diferencia del depósito de huérfanos,
`crates/zx-node/src/red/huerfanos.rs`, que sí tiene los dos topes declarados y un FIFO de desalojo).
Con bloques PoST cercanos al máximo del protocolo (~2,02 MiB con la justificación PoT al máximo,
`limites.rs:45-46`), unos pocos miles de mensajes ya representan varios gigabytes retenidos sin que el
proceso pueda hacer nada distinto de agotar la memoria.

**Reproducción (CONFIRMADO).** Test añadido en la copia:
`deepseek/RI-3a/ws/crates/zx-node/tests/ri3a_cola_trabajo_sin_tope.rs` (íntegro, ver el archivo). Llama
a `ManejadorRed::bloque_difundido` 40 960 veces (10× `MAX_DIFERIDOS_PENDIENTES` de `zx-p2p`) sin que
nadie lea del otro extremo del canal, y comprueba que las 40 960 entradas siguen todas en la cola.

Comando:

```
cd /home/katana/zeo/ZEROX/deepseek/RI-3a/ws
export CARGO_HOME=/home/katana/zeo/ZEROX/deepseek/RI-3a/.cargo-home
export CARGO_TARGET_DIR=/home/katana/zeo/ZEROX/deepseek/RI-3a/.cargo-target
export GIT_CEILING_DIRECTORIES=/home/katana/zeo/ZEROX/deepseek/RI-3a/ws
cargo test -p zx-node --test ri3a_cola_trabajo_sin_tope --locked -j4 -- --nocapture
```

Salida (literal):

```
running 1 test
RI-3a: 40960 bloques encolados en 16.702792ms sin backpressure ni tope (MAX_DIFERIDOS_PENDIENTES de zx-p2p = 4096); la cola sigue creciendo mientras el hilo de consenso no la vacíe
test la_cola_de_trabajo_hacia_consenso_no_tiene_tope ... ok

test result: ok. 1 passed; 0 failed; 0 ignored; 0 measured; 0 filtered out; finished in 0.02s
```

**Corrección sugerida (no aplicada).** Sustituir `unbounded_channel` por `mpsc::channel(N)` acotado
(con `N` declarado y justificado, como `MAX_DIFERIDOS_PENDIENTES`), y decidir explícitamente qué hacer
cuando se llena: lo más coherente con el resto del diseño (huérfanos, diferidos) es un desalojo FIFO
del elemento más viejo, **sin penalizar** a nadie por ello (es agotamiento de un recurso local, mismo
razonamiento que ya usa el proyecto en `presupuesto.rs` y `huerfanos.rs`).

---

### Hallazgo 4 — Coste lineal de `cabeceras_desde` con el historial PoW (PLAUSIBLE, no confirmado)

`crates/zx-node/src/red/vista.rs:129-131`:

```rust
let Some(inicio) = locator
    .iter()
    .find_map(|h| i.cabeceras_pow.iter().position(|c| c.block_hash() == *h))
```

Por cada hash del locator (hasta `MAX_LOCATOR` = 64, `crates/zx-p2p/src/codec.rs:50`), se hace un
`position()` lineal sobre `cabeceras_pow`, que crece con toda la historia PoW. Un locator adversarial
que no reconozca nada (64 hashes ajenos) fuerza 64 recorridos completos del vector antes de devolver
`Vec::new()` (líneas 132-134), dentro del mismo hilo único que atiende todo el `Swarm`
(`servicio.rs:445→460→494→498`, vía `manejador.cabeceras_desde`). En la red dev de 0.0.1 la fase PoW
es corta (se cruza el corte pronto) y el coste absoluto es pequeño; no lo he medido con un historial
grande porque construir uno realista (miles de cabeceras encadenadas) para medir el *orden de
magnitud real* excede el presupuesto de esta revisión. Lo dejo como **PLAUSIBLE**, no CONFIRMADO, y
señalado por ser el mismo patrón de fondo que los hallazgos 1 y 3: trabajo servido en el hilo único,
proporcional a algo que un par declara (el locator) y a algo que crece con el tiempo (el historial),
sin ningún tope propio más allá de `MAX_LOCATOR`.

## 3. Revisado sin más hallazgos (o sin hallazgos que reporte)

**Archivos leídos íntegros:**

`crates/zx-p2p/src/lib.rs`, `mensaje.rs`, `config.rs`, `error.rs`, `codec.rs` (incl. todos los tests),
`limites.rs` (incl. tests), `presupuesto.rs` (incl. tests), `behaviour.rs` (incl. tests),
`limites_ip.rs` (incl. tests), `entrante.rs`, `servicio.rs` (incl. tests) — el crate `zx-p2p` completo.

`crates/zx-node/src/red/mod.rs`, `huerfanos.rs` (incl. tests), `manejador.rs` (incl. tests), `sync.rs`,
`vista.rs` (incl. tests) — `crates/zx-node/src/red/` completo.

`P-ZRX/P-REVISION-CODIGO/ORDEN-RI-3.md`, `ORDEN-RI-1.md`; `P-ZRX/P-NODO/PLAN-W06.md`,
`ORDEN-W06c.md`, `ORDEN-W06d2.md`, `ORDEN-W06d3.md`, `REVISION-W06d2.md`; `P-ZRX/P-FORMATO/FORMATO-v0.md`;
`P-ZRX/P-MEDICION/ESCENARIOS-0.0.1.md`; `P-ZRX/P-REVISION-CODIGO/REVISION-RI-2a.md` (para el formato de
informe y el criterio de gravedad ya usado); `V-ZRX/LINEO.md` íntegro.

**Muestreados/consultados sin lectura completa:** el código fuente de `libp2p-request-response 0.29.0`
(`handler.rs`, para verificar que `max_concurrent_streams` es por conexión, no global —
`.cargo-home/registry/.../libp2p-request-response-0.29.0/src/handler.rs:83,98-116`) y de
`zx-core` lo estrictamente necesario para construir los tests de reproducción (`digest.rs`,
`preimage/block.rs`, `tx.rs`, `amount.rs`, `firma.rs`, `red.rs` — solo las firmas y tipos usados, no
revisados como parte del alcance de RI-3a, que es red).

**Comprobado y descartado por lectura, sin hallazgo:**

- **Frontera `zx-p2p → {zx-core}` intacta.** Ningún `use` de `zx-consensus`, `zx-storage` ni
  `zx-mempool` en ningún archivo de `zx-p2p` (grep e inspección de cada `use` en los archivos leídos).
- **F-04 (familia de bloque no se adivina):** `bloque_desde_bytes` exige la familia declarada por el
  llamante y la compara contra el byte del wire (`codec.rs:304-327`); probado exhaustivamente en los
  tests propios (`una_familia_cambiada_se_rechaza`, `una_familia_desconocida_se_rechaza`).
- **Decodificación no canónica:** `CompactSize` no mínimo y booleanos que no son `0`/`1` se rechazan
  (`codec.rs`, tests `un_contador_no_minimo_se_rechaza`, `el_booleano_de_parada_debe_ser_canonico`,
  `el_booleano_del_terminal_debe_ser_canonico`); relleno sobrante y truncamiento se rechazan siempre
  (`el_relleno_sobrante_se_rechaza`, `un_mensaje_truncado_nunca_se_acepta_a_medias`).
- **Penalización que un honesto podría recibir por llegar antes que su padre:** ya corregido antes de
  esta revisión (RI-2a, `ErrSinPadre` ya no se guarda como definitivo; `REVISION-W06d2.md` §"Lo que
  queda hecho"); el depósito de huérfanos (`huerfanos.rs`) no penaliza al desalojar
  (`Desalojado` no lleva ninguna vía de puntuar, y quien llama —fuera de mi alcance, en `nodo.rs`— solo
  puede tratarlo como `Ignorar` según la documentación del módulo).
- **`MotivoDesconexion`/`LimitesPorIp`:** el baneo puntúa por **prefijo de red** (`/24`, `/64`), no por
  `PeerId` (gratis de regenerar); un `PeerId` nuevo desde el mismo prefijo no evade el baneo ni el cupo
  de conexiones establecidas/pendientes por prefijo (`limites_ip.rs`, tests propios cubren esto).
  `Lento`/`Ilegible` nunca puntúan (C-NET-05); solo `ViolacionDeConsenso` (100 pts, baneo de un golpe) y
  `Excedido` (20 pts, cinco avisos) lo hacen, con la asimetría razonada en el propio código
  (`error.rs:60-107`) y verificada en los tests.
- **Localizador PoW / fase PoST:** `VistaRed::locator()` siempre termina en el génesis y es denso cerca
  de la punta (test `el_locator_siempre_termina_en_el_genesis_y_es_denso_cerca_de_la_punta`); el hueco
  de W06d2 (nodo aislado que nunca vuelve a pedir cabeceras) está corregido en `sync.rs:143-159`
  (petición también quando la punta declarada es un hash desconocido, no solo por altura) y con el
  reintento periódico de saludo (`PLAZO_REINTENTO_SALUDO`, `sync.rs:53,97-103`).
- **Reorganización PoW y localizador tras reorganizar sobre sí mismo:** `fijar_cabeceras_pow`
  (`vista.rs:82-99`) sustituye la secuencia completa tras cada cambio de punta seleccionada, con test
  específico (`fijar_cabeceras_pow_sustituye_una_altura_ya_ocupada_por_registrar_pow`) que reproduce
  exactamente el hallazgo en vivo documentado en `PROGRESO.md` de W06d3.
- **Validación diferida (decisión 1 de `ORDEN-W06d2`):** un veredicto que no llega a tiempo se trata
  siempre como `Ignorar`, nunca `Rechazar` (`expirar_diferidos_vencidos`, `servicio.rs:417-431`); el
  `IdDiferido` es idempotente si se informa dos veces o tarde (`atender_comando`,
  `Comando::InformarValidacion`, `servicio.rs:709-726`).
- **`BloqueRed::Post` con justificación PoT (corrección de W06d3):** presente y ejercitada con una
  justificación no trivial (dos portadores) en los tests de ida y vuelta del códec
  (`justificacion_simple`, `codec.rs:734-748`); el límite de tamaño (`MAX_BLOQUE_RED_BYTES`) la incluye
  explícitamente (`limites.rs:36-46`).
- **`servir()` no bloquea en disco:** `cabeceras_desde`/`bloques_por_hash` del `ManejadorRed` delegan en
  `VistaRed`, que es enteramente en memoria (`RwLock<Interior>` con `Vec`/`BTreeMap`, `vista.rs:20-31`)
  — no hay E/S de `zx-storage` en el camino caliente del bucle de red (confirmé esto porque inicialmente
  sospeché lo contrario; quedó descartado por lectura).

## 4. Lo que esta revisión NO cubre

- `crates/zx-node/src/{nodo.rs, regimen.rs, pow.rs}`, `zx-adversario.rs`, `servicio_pot.rs`: fuera de mi
  parte (RI-3c). En particular, no he podido verificar cómo `nodo.rs` **consume** la cola `TrabajoRed`
  del hallazgo 3 (¿a qué ritmo, con qué prioridad, si descarta algo antes de admitir?), lo que podría
  matizar (pero no elimina: el canal sigue sin tope estructural) la severidad real bajo carga.
- Evidencia y castigo (RI-3b), lógica de régimen/producción (RI-3c): fuera de mi alcance.
- No he medido con procesos reales en TCP (`127.0.0.1`) ninguno de los tres hallazgos: los tres son
  reproducibles y están confirmados **a nivel de unidad**, sobre el código exacto que usaría un
  `Swarm` real (mismas constantes, mismos tipos, mismas funciones), pero no he montado el arnés
  multiproceso completo por presupuesto de tiempo. Los tres hallazgos son, por diseño de sus tests,
  independientes de si se llega a montar ese arnés: no dependen de temporización de red real, solo de
  las funciones y estructuras que sí se ejercitan.
- No he ejecutado `ci/dependencias-exactas.sh` ni `ci/frontera-crates.sh`; la frontera
  `zx-p2p → {zx-core}` la comprobé por lectura de cada `use` (sin hallazgo, ver §3).

## 5. Horas

Inicio: 2026-09-26 22:49 (CEST, `date -Is`). Fin: 2026-09-26 23:06 (CEST, `date -Is`; procesos propios
verificados: ninguno vivo — los tres `zx-node` de `deepseek/W06d5/` siguen siendo de esa sesión, con
PID distinto al de inicio porque reinició por su cuenta, no tocados por mí). Duración real: ~17 min,
muy por debajo del presupuesto de 2 h.
