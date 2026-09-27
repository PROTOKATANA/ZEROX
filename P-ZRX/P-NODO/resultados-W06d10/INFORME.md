# INFORME — ORDEN-W06d10

**Ejecutor:** DeepSeek (`deepseek-flash`, esfuerzo `high`). **Zona:** `deepseek/W06d10/`.
**Base:** raíz en el commit `b3d6e8e` (código idéntico al candidato `3d21b1f`), verificada con
`sha256sum -c P-ZRX/P-NODO/ENTRADA-W06d10.sha256` (52/52) **antes** de editar.
**Inicio (orden):** 2026-09-27T21:43+02:00. **Fin:** ver `HORAS.log`.
**Nota de entorno:** `V-ZRX/LINEO.md` leído íntegro antes de escribir código. La orden rige código
Rust (no Julia), pero se aplican sus reglas de veracidad, reproducibilidad, presupuesto y
prohibición de Python.

---

## 1. Resumen

W07b (E-7) midió que `zx-adversario` difunde bloques demostrablemente inválidos y el nodo los
**rechaza** sin penalizar al par: el veredicto `VeredictoFinal::Rechazar` de un bloque de gossip
solo llegaba a `report_message_validation_result(Reject)` y, sin puntuación de pares de gossipsub,
descartar el mensaje no costaba nada al propagador. La desconexión con
`MotivoDesconexion::ViolacionDeConsenso` y el evento `par_penalizado` solo existían en la ruta de
sincronización.

Esta orden cierra esa asimetría:

1. **Misma respuesta en gossip que en sincronización** (`zx-p2p`): un veredicto `Rechazar` de un
   bloque difundido ahora **desconecta** al propagador con `ViolacionDeConsenso` (puntuación
   C-NET-05/C-NET-20), **mantiene** el `report_message_validation_result(Reject)` (C-NET-12) y
   **avisa al nodo** para que escriba `par_penalizado` (`par`, `motivo`, `accion`). `Aceptar` e
   `Ignorar` **nunca** penalizan.
2. **Solo lo demostrablemente inválido penaliza:** la tabla V1 (§4) enumera todos los caminos a
   `Rechazar`; las tres familias que dependen de la vista local se **reportan** (antes de editar) y
   **no** se tocan, por ser decisión de consenso del director.
3. **Red dev en `127.0.0.1`:** para direcciones **loopback** la penalización es por **`PeerId`**
   (veto en memoria acotado a `MAX_BANEADOS`), no por prefijo, para no vetar a los nodos honestos
   que comparten `127.0.0.0/24`. Fuera de loopback, sin cambios.
4. **`zx-adversario`:** cada vector E-7/E-8 se envía desde una **identidad nueva**, imprime el
   `PeerId` propio de cada vector y cierra la conexión de saludo antes de la ráfaga.

## 2. Base y V0

- `sha256sum -c ENTRADA-W06d10.sha256` en la raíz: **52/52** (incluye `ORDEN` y `LINEO`).
- Suite base (`cargo test --workspace --all-features --locked`): **todos los binarios de test en
  verde** (`test result: ok`, 0 fallos). El único `error` del log fue un doctest de `zx-node`
  (`method par_penalizado is not a member of trait ManejadorEntrante`) producido por editar
  `entrante.rs` **mientras** corría el test base; en V6 compila limpio. Log:
  `logs/v0-base-test.log`.
- `ws.orig/` es la copia de trabajo de la base con el **árbol construible** (`Cargo.toml`,
  `Cargo.lock`, `rust-toolchain.toml`, `crates/`, `ci/`, `testdata/` y el enlace `PDF ->
  /home/katana/zeo/ZEROX/PDF` que exigen las dependencias por ruta); no incluye los ~2 GiB de
  documentación de `P-ZRX/` (fuera del alcance del código y del presupuesto). La verificación de la
  base se hizo en la raíz real del repositorio, no en `ws.orig/`.

## 3. Falta de definición informada antes de editar

`crates/zx-node/src/red/sync.rs` **no está** en la lista de archivos permitidos, pero es el único
consumidor **exhaustivo** de `EventoRed` (`tarea_sincronizacion`, `match` en `sync.rs:101-138`):
añadir `EventoRed::ParPenalizado` habría roto la compilación sin poder editar ese archivo. En vez de
violar el contrato, el aviso al nodo se hace con un **método con implementación por defecto en
`ManejadorEntrante`** (`entrante.rs`, permitido) que `zx-p2p` invoca al penalizar, implementado por
`ManejadorRed` (`red/manejador.rs`, permitido), que escribe `par_penalizado` en el registro. Si el
director prefiere el `EventoRed` literal, basta autorizar la edición de `red/sync.rs`. Reportado en
`PROGRESO.md` §0.1 antes de editar.

## 4. V1 — caminos de un bloque de red a `VeredictoFinal::Rechazar` (antes de editar)

**V** = invalidez independiente de la vista local; **X** = depende de la vista local (se reporta y
**no** se toca). Referencias a la base `b3d6e8e`.

### 4.1 Gossip: despacho y códec — `zx-p2p/src/servicio.rs`

| # | Sitio | Motivo | Vista |
|---|---|---|---|
| G1 | `servicio.rs:865` | bytes residuales tras deserializar | **V** |
| G2 | `servicio.rs:866` | deserialización fallida / truncada | **V** |

### 4.2 Admisión PoW — `zx-node/src/nodo.rs`

| # | Sitio | Motivo | Vista |
|---|---|---|---|
| P1 | `nodo.rs:1621-1623` | `cadena.motivo(hash)` cacheado | **V** |
| P2 | `nodo.rs:1668-1683` | padre conocido **e inválido** | **V** |
| P3a | `nodo.rs:652-661` | `branch_id`/`prev_hash`/`altura`/`bits`/PoW/monotonía | **V** |
| P3a' | `nodo.rs:652-661` | `ErrorPow::TimestampDemasiadoFuturo` (C-TS-03, FTL) | **X1** |
| P3b | `nodo.rs:717-723` | `ErrSlot`, `ErrEmision`, `ErrSaldo`, `ErrMergeset`, `ErrU2`, `ErrMergeDepth`, `ErrGarantia`, `ErrTerminalAmbiguo`, `ErrTransicion`, `ErrSinPadre` | **V** |
| P3b' | idem | `MotivoBloque::ErrLimiteTerminales` (tope local de terminales) | **X2** |
| P3c | `nodo.rs:635-636` | `target_de_altura` Err | **V** |
| P3d | `nodo.rs:672-673` | desbordamiento de trabajo | **V** |
| P3e | `nodo.rs:730-731`, `752` | persistencia / `asegurar_servicios_verificacion` Err | **X3** |

### 4.3 Admisión PoST — `zx-node/src/nodo.rs`

| # | Sitio | Motivo | Vista |
|---|---|---|---|
| Po1 | `nodo.rs:1763-1765` | `cadena.motivo(hash)` cacheado | **V** |
| Po2 | `nodo.rs:1841-1855` | padre conocido e inválido | **V** |
| Po3 | `nodo.rs:1858-1875` | `BloqueDag::nuevo` (forma) | **V** |
| Po4 | `nodo.rs:1927-1940` | `Pendiente` (contexto PoT incompleto) | **Ignorar** |
| Po5 | `nodo.rs:1950-1973` | `ImposibleSinPenalizar` | **Ignorar** |
| Po6 | `nodo.rs:1974-1988` | `Legitimo`/`Interno` (sello/PoT/PoAS/cuenta/padres/garantía) y `verificar_solucion_poas` | **V** |
| Po6' | idem | `ErrLimiteTerminales` | **X2** |
| Po6'' | idem | `ErrorNodo::Otro` (detector/persistencia/servicio) | **X3** |

**Conclusión V1:** las tres familias **X** existen hoy y **ya penalizan** en la ruta de
sincronización (`nodo.rs:1533-1546`, `ORDEN-W07a`). `X1` es la más clara: el propio contrato de
`comprobar_ftl` (`zx-consensus/src/timestamps.rs:26-34`) exige **diferir y no banear**, pero
`nodo.rs:659` clasifica `ErrorPow::TimestampDemasiadoFuturo` como `Interno`; `X2`
(`ErrLimiteTerminales`, `rechazo.rs:161`) depende del conjunto **local** de terminales; `X3` son
fallos locales (disco/servicio), no defectos del candidato. La orden prohíbe cambiarlas sin
respuesta: **no se han tocado** y quedan reportadas. Ningún ejemplo de la orden (profundidad de
reorganización, finalidad C-FIN-01, terminal no seleccionado, contexto PoT incompleto, huérfanos,
duplicados) está hoy en `Rechazar`: todos son `Ignorar` en esta base.

## 5. Cambios (solo archivos permitidos; `Cargo.lock` sin cambios)

| Archivo | Cambio |
|---|---|
| `zx-p2p/src/entrante.rs` | `ManejadorEntrante::par_penalizado(peer, motivo, accion)` con implementación por defecto (aviso al nodo). |
| `zx-p2p/src/servicio.rs` | `reportar_a_gossipsub`: en `Rechazar`, conserva el `Reject` + `desconectar_con_motivo(propagador, ViolacionDeConsenso)` + `manejador.par_penalizado(...)`. Constantes `MOTIVO_PAR_PENALIZADO_GOSSIP` / `ACCION_PAR_PENALIZADO_EXPULSION`. `desconectar_con_motivo` usa `penalizar_peer`. |
| `zx-p2p/src/limites_ip.rs` | `Prefijo::es_loopback()`; `puntos_peer` + `baneados_peer` (FIFO, `MAX_BANEADOS`, `HashSet` O(1)); `puntuar_peer`/`esta_baneado_peer`/`penalizar_peer` (`Penalizacion`); `Denegada::PeerBaneado` y comprobación en `handle_established_inbound_connection`. Excepción de red local documentada. |
| `zx-node/src/red/manejador.rs` | Implementa `par_penalizado` escribiendo el evento `par_penalizado` del esquema v1. |
| `zx-node/src/bin/zx-adversario.rs` | `enviar_vector_con_identidad_nueva`: `PeerId` nuevo y conexión nueva por vector; imprime el `PeerId` propio; cierra la conexión de saludo antes de la ráfaga y espera 1.5 s entre vectores (cupo `MAX_POR_PREFIJO`). E-8 envía cada bloque desde su identidad. |
| `zx-p2p/tests/penalizacion_gossip.rs` | Tests de integración TCP (nuevo). |
| `zx-p2p/src/limites_ip.rs` (tests) | 4 tests unitarios de la política loopback/`PeerId`. |

La ruta de sincronización (`nodo.rs:33-1546`) y su `par_penalizado` **no cambian**. `Ignorar`
sigue sin penalizar.

## 6. V2/V3 — tests

`cargo test -p zx-p2p --all-features --locked`: **82/82 lib + 14/14 `dos_nodos` + 2/2
`penalizacion_gossip`** en verde (`logs/test-p2p.log`).

- `rechazar_en_gossip_desconecta_penaliza_y_no_veta_el_prefijo` (TCP `127.0.0.1`): con 3 pares del
  mismo `/24`, el adversario que difunde el bloque marcado es desconectado y avisado
  (`par_penalizado` con `motivo`/`accion`); dos honestos siguen conectados y un par **nuevo** puede
  reconectar (el prefijo no se veta).
- `ignorar_no_desconecta_ni_penaliza`: `Ignorar` no desconecta ni genera `par_penalizado`.
- Unit `limites_ip`: `es_loopback` (v4/v6), penalización loopback por `PeerId` sin vetar el prefijo,
  fuera de loopback por prefijo como antes, y cota FIFO de `baneados_peer`.
- Ruta de sincronización: los tests preexistentes de `dos_nodos`/`ri3a_presupuesto_agotable` siguen
  en verde; no se cambió su código.

## 7. V4 — procesos reales, E-7 ×3

Guiones `scripts/r4_e7_rep.sh` (E-7 de `r4.sh` de W07b + verificación W07d) y `scripts/run_v4.sh`.
Una clave por nodo (A=0, B=1, C=2), `N_dev=138873760`, `SR_dev=13043817825332783104`, semillas
101/202/303. Logs en `run/R4-E7-{1,2,3}/`.

| Rep | Semilla | rechazos A | `par_penalizado` (distintos) | ajenos | desconex. B/C | convergencia W07d | Resultado |
|---|---:|---:|---:|---:|---:|---|---|
| 1 | 101 | 4 | 4 | 0 | 0 | sí | **SUPERADO** |
| 2 | 202 | 4 | 4 | 0 | 0 | sí | **SUPERADO** |
| 3 | 303 | 4 | 4 | 0 | 0 | sí | **SUPERADO** |

Los 5 vectores salen de 5 identidades nuevas: la ráfaga de huérfanos queda `Ignorar` (no penaliza,
por diseño) y los 4 vectores rechazados (PoST malo, E-8 ×2, PoW nonce) generan 4 `par_penalizado`
distintos en A; A sigue conectado a B y C; los tres convergen en `resumen_estado` y
`compendio_bloques`.

## 8. V5 — sin falsos positivos

Guiones `scripts/r150.sh` (3 nodos honestos al slot 150) y `scripts/r3_e6.sh` (partición E-6 con
aislamiento real), driver `scripts/run_v5.sh`. Resultado (`run/v5-driver.log`):

| Conjunto | Reps | Criterio | `par_penalizado` | Resultado |
|---|---:|---|---:|---|
| R150 (A/B/C al slot 150) | 3 | slot 150 en los tres, 0 fallo_productor, convergencia W07d | 0 | **SUPERADO** |
| R3-E6 (partición, aislamiento real) | 1 | `contactos_A_con_BC=0`, `contactos_B_con_A=0`, `contactos_C_con_A=0`, convergencia W07d | 0 | **CONVERGEN (W07d)** |

**0 `par_penalizado` entre nodos honestos en las 4 ejecuciones**: el cambio no introduce falsos
positivos en operación normal ni en partición y reunión.

## 9. V6 — fmt, clippy, suite, guardianes, T01/T04

- `cargo fmt --all -- --check`: verde.
- `cargo clippy --workspace --all-targets --all-features --locked -- -D warnings`: verde
  (`logs/clippy.log`, 0 errores).
- `cargo test --workspace --all-features --locked`: **84 binarios de test, 883 pasados, 0 fallos,
  6 ignorados**; los doctests de los 10 crates pasan (`logs/v6-test.log`). T01/T04 (diferenciales)
  en verde.
- Guardianes: `ci/dependencias-exactas.sh` (24 exactas), `ci/firmante-obligatorio.sh` y
  `ci/frontera-crates.sh` (5 fronteras) en verde.
- `Cargo.lock` sin cambios: `sha256sum -c` de la entrada sigue dando 52/52 en la raíz base.

## 10. Límites y hallazgos

- **X1/X2/X3** (V1): se reportan y no se tocan. En particular, un bloque con timestamp demasiado
  futuro (C-TS-03) sigue penalizando en gossip; el contrato del tipo pide diferirlo. Es una
  decisión de consenso pendiente del director.
- `zx-adversario`: el vector «coinbase mayor que el subsidio» puede omitirse (el minado real con
  `bits` de fixture no encuentra nonce en el presupuesto); ya ocurría en W07b. Los 4 rechazos se
  alcanzan igual (PoST, E-8 ×2, PoW).
- La excepción loopback es de **red local**: en producción los pares honestos no comparten prefijo
  con el adversario y la puntuación por prefijo no cambia.
- `par_penalizado` desde gossip se escribe con `motivo = "bloque difundido rechazado"` y
  `accion = "expulsion"`; el detalle del defecto queda en `bloque_red_rechazado` (`motivo`).

## 11. Reproducción

```bash
Z=/home/katana/zeo/ZEROX/deepseek/W06d10
cd "$Z/ws"
cargo fmt --all -- --check
cargo clippy --workspace --all-targets --all-features --locked -- -D warnings
cargo test --workspace --all-features --locked
bash ci/dependencias-exactas.sh
bash ci/firmante-obligatorio.sh
bash ci/frontera-crates.sh
# V4 (E-7 x3) y V5 (sin falsos positivos), require binarios release:
cargo build --release -p zx-node --all-features --locked
bash "$Z/scripts/run_v4.sh"
bash "$Z/scripts/run_v5.sh"
```

Artefactos por repetición en `run/R4-E7-*/` (adversario, rechazos, convergencia W07d) y
`run/R150-*`, `run/R3-E6-*` (falsos positivos).
