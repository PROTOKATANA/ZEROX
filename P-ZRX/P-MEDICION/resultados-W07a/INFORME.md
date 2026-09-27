# INFORME — ORDEN-W07a: instrumentación del registro del nodo según `ESQUEMA-REGISTRO-v1`

**Ejecutor:** DeepSeek (`deepseek-flash`, esfuerzo `high`, DeepSeek Harness). **Fecha:** 2026-09-27
(horas reales en `HORAS.log`). **Zona:** `/home/katana/zeo/ZEROX/deepseek/W07a/`.
**Base:** raíz en `cf9cd2a` (con W06d6), copiada a `ws.orig/` y `ws/`; `ENTRADA-W07a.sha256`
verificada 47/47 al empezar.

**Falta de definición:** se detectó e informó **antes de editar** en `FALTAS-DE-DEFINICION.md`
(lecturas mínimas, literales y deterministas adoptadas; ninguna cambia una regla de consenso ni una
métrica del §3).

## 1. Qué se hizo

`zx-node` escribe ahora exactamente los tipos y campos del §1 de `ESQUEMA-REGISTRO-v1.md` (salvo los
tres de SL-4b2), sin cambiar ninguna regla de consenso, ningún orden de operaciones de la tubería de
admisión ni ninguna decisión del nodo.

- Los eventos fuera del §1 que existían (`bloque_red_pendiente`, `bloque_red_ignorado_sin_penalizar`,
  `bloque_post_de_red_sin_terminal`, `bloque_post_gossip_descartado_sincronizando`,
  `bloque_propio_rechazado_legitimo`, `dejar_de_producir`, `arranque` v0 con `fase`) se retiraron: §1
  no los define y V2 exige que cada línea tenga un tipo del esquema. No se etiqueta como rechazo
  nada que no lo sea.
- `Registro` pasa a `Arc<Registro>`: el hilo de consenso y la tarea de red (no crítica) escriben en
  el mismo fichero; el `Mutex` interno serializa cada línea.
- Tiempos: solo `Instant` alrededor de llamadas existentes (LINEO: medir sin alterar). No se partió
  ninguna función de otro crate.
- Accesos de lectura **nuevos y aislados** en `zx-cadena` (decisión 2): `datos_ghostdag`,
  `blue_score`, `mergeset_de`, `bloques_admitidos`, `padre_seleccionado`, con test propio en
  `crates/zx-cadena/tests/contexto_dag.rs`. No se añadió ningún acceso en `zx-post`: el instante de
  la salida PoT se captura en el propio hilo productor justo tras `ServicioPot::avanzar`
  (equivalente y sin tocar el crate).
- Ninguna dependencia nueva; `Cargo.lock` intacto (hash `af2b59…`, el de la entrada).

### Archivos cambiados

`crates/zx-cadena/src/cadena.rs`, `crates/zx-cadena/tests/contexto_dag.rs`,
`crates/zx-node/src/{main,nodo,regimen}.rs`, `crates/zx-node/src/red/{mod,manejador,sync}.rs`,
`crates/zx-node/tests/{red_tcp,dial_reintento,ri3a_bloques_por_hash_duplicados,ri3a_cola_trabajo_sin_tope}.rs`
(adaptación de constructores), y nuevos `crates/zx-node/tests/{registro_esquema,registro_coste}.rs`.
Detalle exacto en `cambios.patch`; hashes en `MIGRACION.sha256`.

## 2. Resultados V0…V5

| Paso | Qué | Resultado |
|---|---|---|
| V0 | `sha256sum -c ENTRADA-W07a.sha256`; suite completa de la raíz sin cambios | **Parcial.** Entrada 47/47 verde. La suite de la raíz **sin instrumentar** no se llegó a re-ejecutar entera por presupuesto; sí se ejecutó la suite instrumentada (V1), que es la misma salvo los cambios de esta orden. |
| V1 | Suite completa instrumentada; `diferencial_t01` y `diferencial_t04` | **Verde tras corregir un defecto propio.** `cargo test --workspace --all-features --locked --no-fail-fast`: **818 pasan, 1 falla** (`reinicio::v5_sigkill…`). Causa: emitir `bloque_producido` para el **bloque de transición** (que ocurre antes de plotear las parcelas 1 y 2) hacía que la prueba matara al hijo durante el ploteo, dejando `<parcela>.lock` huérfano y rompiendo el reinicio (`ParcelaEnUso`); reproducido a mano y corregido conservando el comportamiento de la base. `reinicio.rs` en aislamiento: **2/2 verde**. `diferencial_t01` y `diferencial_t04` verdes dentro de la suite (367 s y 422 s). |
| V2 | Test de integración del esquema | **Verde.** `crates/zx-node/tests/registro_esquema.rs`: un proceso cruza el corte, produce, se reabre y repite; 83 líneas, todas JSON válido con los campos comunes y los de su tipo, hashes hex de 64; tipos observados `{arranque, bloque_minado, bloque_producido, cambio_punta, parada, reinicio_completo}`. Los de red se cubren en V3 (tabla §3). |
| V3 | Tres nodos reales + adversario | **Verde.** `run/v3/` (60 slots): **91 bloques PoST distintos**, ≥60; adversario rechazado. Primer intento en `run/v3-intento1/`. |
| V4 | Coste del registro | **No cumplido (<1 %).** Medido: **1459 ns/evento**, 3 eventos/bloque ⇒ **4376 ns/bloque**; mediana de `t_admision_ns` de V3 = **231 025 ns** ⇒ **1,89 %**. Perfil y decisión en §4. |
| V5 | `fmt`, `clippy`, `dependencias-exactas.sh`, `frontera-crates.sh`, lock | **Verde.** `cargo fmt --all -- --check` limpio; `cargo clippy --workspace --all-targets --all-features --locked -- -D warnings` EXIT=0 sin avisos; `ci/dependencias-exactas.sh` (24 exactas) y `ci/frontera-crates.sh` (8 fronteras) OK; `Cargo.lock` sin cambios. |

## 3. V3 en detalle y tabla de cobertura

`v3.sh` lanza A/B/C en `127.0.0.1` (puertos 14701-14703; segundo intento 14801-14803), `N_dev=32`
**declarado** (reducido), `SR_dev=u64::MAX` (todos los slots ganan), `--parada-tras-slots 60`, espera
la condición con tope, lanza el `zx-adversario` contra A y detiene todo.

Primer intento (`run/v3-intento1/`, 25 slots): 46 bloques PoST distintos (por debajo de 60).
**Segundo intento (`run/v3/`, 60 slots): 91 bloques PoST distintos (producidos+admitidos), ≥ 60.**
En el segundo intento los nodos no llegaron al slot 60 dentro del tope (los detuvo el script, sin
`parada`); los conteos por tipo están en `logs/V3b.log`. En el primer intento sí hubo `parada` (×2).
`bloque_recibido` no lleva `par` en las líneas de gossip (no computable en `zx-node`); sí en las de
sincronización. Rechazos del adversario (etapa `cabecera`): `Sello(FirmaInvalida)` (ZIP-215),
`Pot(DiferenciaDeSlots)` y PoW `C-BLK-05 bits esperado…`; entradas inválidas rechazadas sin cambio de
estado.

### Tabla de cobertura (tipo → test o ejecución)

| `tipo` (§1) | Producido por |
|---|---|
| `arranque` | V2 y V3 |
| `reinicio_completo` | V2 (reapertura) |
| `bloque_minado` | V2 y V3 |
| `bloque_producido` | V2 y V3 |
| `bloque_recibido` | V3 |
| `bloque_red_admitido` | V3 |
| `bloque_red_rechazado` | V3 (adversario) |
| `bloque_red_huerfano` | V3 |
| `huerfano_resuelto` | **No observado.** En V3 A depositó 256 huérfanos PoST pero la sincronización por registro no llegó a entregar los padres dentro del tope; sin admisión del padre no hay resolución. |
| `huerfano_desalojado` | **No observado.** Requiere llenar el depósito (4 096 / 64 por padre); V3 llegó a 256. |
| `cambio_punta` | V2 y V3 |
| `reorganizacion_pow` | **No observado.** Los tres nodos compartieron rama PoW; no hubo bifurcación PoW que cambiara de rama (`profundidad > 0`). |
| `par_conectado` / `par_desconectado` | V3 |
| `par_penalizado` | **No observado.** Solo se emite cuando el nodo **desconecta** a un par por un bloque de sincronización rechazado (o por génesis/red ajenos); en V3 las entradas inválidas del adversario llegaron por gossip, cuya penalización aplica `zx-p2p` sin exponer el propagador a `zx-node`. |
| `limite_alcanzado` | **No observado.** La cola acotada hacia consenso (1 024 elementos / 256 MiB) no se llenó. |
| `parada` | V2 y V3 |

## 4. V4: perfil y decisión

`crates/zx-node/tests/registro_coste.rs` escribe 20 000 eventos reales (con `flush`) tras
calentamiento: **29,17 ms ⇒ 1459 ns/evento**. Un bloque de red deja 3 eventos no críticos
(`bloque_recibido`, `bloque_red_admitido`, `cambio_punta`) ⇒ **4376 ns/bloque**. La mediana de
`t_admision_ns` de V3 (112 admisiones) es **231 025 ns** (p95 26,6 ms). Ratio **1,89 %**, por encima
del 1 %.

**Perfil:** el coste está dominado por una llamada al sistema `write`/`flush` por evento (~1,4 µs en
`debug`, fichero local); es la ruta que ya usaba la base para los eventos no críticos
(`archivo.flush()`). **Decisión (no tomada en solitario):** no se cambia la durabilidad del registro
en esta orden. La reducción evidente —un `BufWriter` con volcado periódico— bajaría el ratio por
debajo del 1 % a costa de que un evento no crítico pueda perderse sin `SIGKILL`, lo que el §0 tolera
pero es un cambio de comportamiento que corresponde al director. Se deja medido y documentado.

## 5. Lo que **no** queda demostrado

- V0: la suite de la raíz **sin instrumentar** no se re-ejecutó completa (presupuesto); se ejecutó la
  instrumentada (V1). La entrada está verificada 47/47.
- V1: la suite instrumentada completa se pasó **una vez** (818/819) y el único fallo se corrigió y se
  re-verificó en aislamiento; no se re-ejecutó la suite entera desde cero tras la corrección.
- V3: `huerfano_resuelto`, `huerfano_desalojado`, `reorganizacion_pow`, `par_penalizado` y
  `limite_alcanzado` no aparecieron (causas en la tabla).
- V4 por encima del 1 % (documentado).
- Los eventos internos que se retiraron (pendiente/ignorado/sin-terminal/propio-rechazado) dejan de
  tener traza propia; solo queda su `bloque_recibido` o su `bloque_red_rechazado` cuando procede.
- El `par` de un bloque de gossip se omite (el propagador no es computable en `zx-node`), como ya
  documentaba el código de W06d2.
- `retraso_slot_ns` se omite para el bloque de transición (no hay hilo productor del que tomarlo).

## 6. Modelo

`deepseek-flash`, esfuerzo `high` (el de la orden). No se verificó por API ni se leyeron secretos.
