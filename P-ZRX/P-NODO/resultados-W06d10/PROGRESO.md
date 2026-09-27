# PROGRESO — ORDEN-W06d10

**Ejecutor:** DeepSeek (`deepseek-flash`, esfuerzo `high`). **Zona:** `deepseek/W06d10/`.
**Base:** raíz en el commit `b3d6e8e` (código idéntico al candidato `3d21b1f`), verificada con
`sha256sum -c P-ZRX/P-NODO/ENTRADA-W06d10.sha256` (52/52) **antes** de editar.
**Inicio (orden):** 2026-09-27T21:43+02:00. **Inicio de trabajo:** ver `HORAS.log`.
**Nota de entorno:** se ha leído `V-ZRX/LINEO.md` íntegro antes de escribir código (la orden rige
código Rust; la política de veracidad, reproducibilidad, presupuesto y prohibición de Python se
aplica igual).

---

## 0. INFORMES PREVIOS A EDITAR (obligación de la orden)

### 0.1 Falta de definición: `crates/zx-node/src/red/sync.rs` no está en la lista de permitidos

La decisión 1 pide «avisa al nodo con un **evento de red nuevo** (p. ej.
`EventoRed::ParPenalizado { peer, motivo, accion }`)». El **único** punto que consume `EventoRed`
de forma exhaustiva es `crates/zx-node/src/red/sync.rs` (`tarea_sincronizacion`, match en
`sync.rs:101-138`, con `EventoRed::Escuchando(_) | EventoRed::Suscripcion { .. } => {}`). Añadir una
variante a `EventoRed` deja ese `match` no exhaustivo y **rompe la compilación**, pero `red/sync.rs`
**no** figura en «Archivos permitidos» y el contrato dice «Vedado el resto».

**Resolución adoptada (sin tocar archivos vedados):** el aviso al nodo se hace por un **método
nuevo con implementación por defecto en el trait `ManejadorEntrante`** (`crates/zx-p2p/src/entrante.rs`,
permitido) que `zx-p2p` invoca al penalizar, e implementado por el `ManejadorRed` real
(`crates/zx-node/src/red/manejador.rs`, permitido), que escribe el evento `par_penalizado` en el
registro (`par`, `motivo`, `accion`). Es funcionalmente lo que pide la decisión 1 (el nodo escribe
`par_penalizado` al penalizar `zx-p2p`) sin violar la lista de archivos. El `Default` del método
mantiene compilando a todos los manejadores de test (`Espia`, `Contador`, `Diferidor`, …).

> Si el director prefiere el `EventoRed::ParPenalizado` literal, basta **autorizar la edición de
> `red/sync.rs`** (una rama `EventoRed::ParPenalizado { .. } => { escribir par_penalizado }`). Queda
> registrado aquí antes de editar, como exige la orden.

### 0.2 V1 — Todos los caminos de un bloque de red a `VeredictoFinal::Rechazar`

Tabla completa (archivo:línea de la base `b3d6e8e`), con la justificación de dependencia de la
vista local. **V** = la invalidez no depende de la vista local (demostrable). **X** = depende de la
vista local (debería ser `Ignorar`).

#### A. Ruta de gossip: despacho y códec — `zx-p2p/src/servicio.rs`

| # | Sitio | Motivo | Vista | Justificación |
|---|---|---|---|---|
| G1 | `servicio.rs:865` (`despachar`) | `Ok((_, _))`: bytes residuales tras deserializar | **V** | Los bytes no son un bloque canónico; cualquier nodo lo juzga igual. |
| G2 | `servicio.rs:866` (`despachar`) | `Err(_)`: deserialización fallida / truncada | **V** | Formato inválido independiente del estado. |

#### B. Ruta de gossip/sync: admisión PoW — `zx-node/src/nodo.rs`

| # | Sitio | Motivo | Vista | Justificación |
|---|---|---|---|---|
| P1 | `nodo.rs:1621-1623` | `cadena.motivo(hash)` ya cacheado | **V** | El caché solo guarda rechazos ya demostrados; se re-rechaza sin reevaluar. |
| P2 | `nodo.rs:1668-1683` | padre conocido **e inválido** (`es_valido(padre)==false` y `motivo(padre)` presente) | **V** | Extender un padre demostradamente inválido es inválido para cualquier nodo con ese padre. |
| P3a | `nodo.rs:652-661` (`validar_cabecera_pow` → `Interno`) | `branch_id`, `prev_hash`, `altura`, `bits`, `PoW`, monotonía de timestamp | **V** | Reglas permanentes de cabecera, función del bloque y de su padre declarado. |
| P3a' | `nodo.rs:652-661` | `ErrorPow::TimestampDemasiadoFuturo` (C-TS-03, FTL) | **X** | `ts ≤ reloj_local + ftl` usa el **reloj local**; el propio tipo lo declara «no permanente» (`zx-consensus/src/timestamps.rs:26-34` exige **diferir y no banear**), pero `nodo.rs:659` lo clasifica `Interno` y `intentar_admitir_pow_de_red` (`nodo.rs:1737`) lo convierte en `Rechazar`. |
| P3b | `nodo.rs:717-723` vía `clasificar_motivo_bloque` | `ErrSlot`, `ErrEmision`, `ErrSaldo`, `ErrMergeset`, `ErrU2`, `ErrMergeDepth`, `ErrGarantia`, `ErrTerminalAmbiguo`, `ErrTransicion`, `ErrSinPadre` | **V** | Reglas de consenso evaluadas sobre el pasado declarado (padres ya validados); cualquier nodo con esos padres decide igual. |
| P3b' | idem, `MotivoBloque::ErrLimiteTerminales` | Noveno terminal con sufijo no supera al peor de los ocho **locales** (`zx-cadena/src/cadena.rs:798-812`) | **X** | El conjunto de terminales con DAG es estado **local**; un nodo con otra rama lateral decide distinto. `rechazo.rs:161` lo deja en `Interno` (penaliza). |
| P3c | `nodo.rs:635-636` | `pow::target_de_altura` Err → `ErrorNodo::Otro` → `Rechazar` (`nodo.rs:1737`) | **V** | Depende del historial del padre declarado, no de la punta local. |
| P3d | `nodo.rs:672-673` | desbordamiento de trabajo | **V** | Aritmética del bloque. |
| P3e | `nodo.rs:730-731`, `nodo.rs:752` | `almacen.admitir` / `asegurar_servicios_verificacion` Err → `Otro` → `Rechazar` | **X** | Fallo **local** de disco/servicio, no defecto del candidato. |

#### C. Ruta de gossip/sync: admisión PoST — `zx-node/src/nodo.rs`

| # | Sitio | Motivo | Vista | Justificación |
|---|---|---|---|---|
| Po1 | `nodo.rs:1763-1765` | `cadena.motivo(hash)` cacheado | **V** | Igual que P1. |
| Po2 | `nodo.rs:1841-1855` | padre conocido e inválido | **V** | Igual que P2. |
| Po3 | `nodo.rs:1858-1875` | `BloqueDag::nuevo` falla (forma) | **V** | Forma del candidato. |
| Po4 | `nodo.rs:1927-1940` | `clasificacion.es_pendiente()` | **Ignorar** | Ya correcto: contexto PoT incompleto. |
| Po5 | `nodo.rs:1950-1973` | `!clasificacion.penaliza_en_red()` (`ImposibleSinPenalizar`) | **Ignorar** | Ya correcto: `PruebaPotIncoherente`/`RangoSinAtadura`. |
| Po6 | `nodo.rs:1974-1988` (genérico) | `Legitimo`/`Interno` de `verificar_cabecera_conjunta`, `verificar_solucion_poas`, `cadena.admitir` | **V** | Defecto del candidato (sello/PoT/PoAS/padres/garantía) evaluado sobre su pasado declarado. |
| Po6' | idem | `ErrLimiteTerminales` (via `cadena.admitir`) | **X** | Igual que P3b'. |
| Po6'' | idem | `ErrorNodo::Otro`: `observar_para_detector`, `asegurar_servicios_verificacion`, persistencia | **X** | Fallo local, no defecto del candidato. |

**Resultado V1:** hay **tres** familias de `Rechazar` que dependen de la vista local:
**(X1)** C-TS-03 (`ErrorPow::TimestampDemasiadoFuturo`, P3a'), **(X2)**
`MotivoBloque::ErrLimiteTerminales` (P3b'/Po6') y **(X3)** errores locales de persistencia/servicio
(P3e/Po6''). Las tres existen **hoy** y ya penalizan en la ruta de sincronización
(`nodo.rs:1533-1546`, `ORDEN-W07a`). La orden prohíbe tocarlas sin respuesta del director («es una
decisión de consenso de red, no tuya»): **se dejan intactas** y quedan reportadas aquí y en
`INFORME.md` §V1. Ninguno de los ejemplos que cita la orden (profundidad de reorganización,
finalidad C-FIN-01, terminal no seleccionado, contexto PoT incompleto, huérfanos, duplicados) está
hoy en `Rechazar`: todos son `Ignorar` en esta base.

---

## 1. Plan de implementación (tras los informes de §0)

| Decisión | Implementación |
|---|---|
| 1 (misma respuesta en gossip) | `zx-p2p/src/servicio.rs::reportar_a_gossipsub`: si el veredicto es `Rechazar`, además de `report_message_validation_result(Reject)`, `desconectar_con_motivo(propagador, ViolacionDeConsenso)` + aviso al nodo (`ManejadorEntrante::par_penalizado`) para escribir `par_penalizado`. `Ignorar`/`Aceptar` no penalizan. Cubre la ruta directa y la diferida (`Comando::InformarValidacion`). |
| 2 (solo lo demostrable) | Tabla §0.2; las tres familias X se reportan y no se tocan. |
| 3 (loopback por `PeerId`) | `zx-p2p/src/limites_ip.rs`: `Prefijo::es_loopback()`, `puntos_peer`/`baneados_peer` (FIFO acotado a `MAX_BANEADOS`); `desconectar_con_motivo` puntúa `PeerId` para prefijos loopback y prefijo para el resto; veto del `PeerId` en `handle_established_inbound_connection`. Documentado como excepción de red local. |
| 4 (`zx-adversario`) | Identidad y conexión nuevas por vector; imprime el `PeerId` propio de cada vector; cierra la conexión persistente (la del saludo) antes de la ráfaga para no agotar `MAX_POR_PREFIJO` del /24 compartido. |

## 2. Estado

- [x] V0: `sha256sum -c` 52/52 (raíz); suite base: todos los binarios de test en verde (el único
  fallo del log, un doctest de `zx-node`, es artefacto de haber editado `entrante.rs` **mientras**
  corría el test base; se recompila limpio en V6).
- [x] V1: tabla §0.2 (antes de editar).
- [x] Código + tests V2/V3: 4 unit `limites_ip` + 2 integración TCP `penalizacion_gossip` en verde.
- [x] V4 (E-7 ×3, procesos reales): 3/3 SUPERADO.
- [x] V5 (sin falsos positivos): 3/3 R150 (slot 150) + 1 partición E-6 con aislamiento real
  (`contactos_*=0`), **0 `par_penalizado`** entre honestos; convergencia W07d.
- [x] V6: `fmt --check` verde; `clippy --workspace --all-targets --all-features --locked -D warnings`
  verde; suite completa **883 pasados / 0 fallos / 6 ignorados** (84 binarios + doctests); los tres
  guardianes verdes; T01/T04 verdes. Entrada 52/52 (raíz base intacta).

## 3. Resultado V4 (E-7 ×3, semillas 101/202/303)

- 5 identidades nuevas (una por vector); la ráfaga de huérfanos queda `Ignorar` y **no** penaliza
  (por diseño); los 4 vectores rechazados (PoST malo, E-8 ×2, PoW nonce) → 4 `par_penalizado`
  distintos en A, 0 ajenos al adversario, 0 desconexiones de B/C, convergencia W07d. Las 3
  repeticiones **SUPERADO**.

## 4. Resultado V5 (sin falsos positivos)

| Conjunto | Reps | `par_penalizado` | Resultado |
|---|---:|---:|---|
| R150 (3 nodos, slot 150) | 3 | 0 | SUPERADO |
| R3-E6 (partición, aislamiento real `contactos_*=0`) | 1 | 0 | CONVERGEN (W07d) |

## 5. Aviso de implementación

`zx-adversario` imprime ahora el `PeerId` **propio** de cada vector (antes imprimía, por error, el
del objetivo), y cierra la conexión persistente del saludo antes de la ráfaga: con
`MAX_POR_PREFIJO = 3` y B/C ocupando dos cupos del /24 `127.0.0.0`, esa conexión dejaba fuera a las
identidades nuevas (verificado en el primer intento de V4: A cerraba la conexión entrante y
`publish` fallaba con `NoPeersSubscribedToTopic`).
