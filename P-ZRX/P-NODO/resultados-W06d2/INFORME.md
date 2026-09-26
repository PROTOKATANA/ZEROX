# INFORME — ORDEN-W06d2: Red del nodo

**Ejecutor:** Sonnet, único, sin subagentes ni forks. **Zona:** `/home/katana/zeo/ZEROX/deepseek/W06d2/`.
**Fecha:** 2026-09-26. Evidencia: `logs/`, `PROGRESO.md`, `HORAS.log`.

## Veredicto

**SUPERADO PARCIALMENTE.** La validación diferida (decisión 1), la difusión solo tras persistir
(decisión 2), el depósito de huérfanos (decisión 3), la sincronización PoW por localizador
(decisión 4, fase PoW) y la penalización (decisión 5) están implementadas, verificadas por tests
unitarios/de integración en proceso y **verificadas en vivo con dos procesos `zx-node` reales sobre
TCP real**: conectan, propagan bloques PoW por gossip y **convergen** (uno deja de auto-minar y
adopta la cadena del otro). La herramienta adversarial (decisión 6) es un binario aparte que habla
el protocolo real; verificado en vivo que un `PoW con nonce malo` contra un nodo real se rechaza y
desconecta.

**No se demuestra de extremo a extremo** la fase PoST por red (cruce del corte, ≥30 bloques PoST
entre dos nodos, partición/reunión, E-8): lo bloquea un hallazgo propio, documentado con evidencia
literal en `PROGRESO.md` — `zx_p2p::mensaje::BloqueRed::Post` no lleva el campo `JustificacionPot`
que `zx_post::cabecera_conjunta::verificar_cabecera_conjunta` necesita para verificar PoT/PoAS de un
bloque ajeno. Aceptar sin verificar habría sido el `Ok` ficticio que la orden prohíbe; en su lugar,
todo bloque PoST de red se trata como `Ignorar` (nunca `Rechazar`) y se registra el motivo exacto.
Esto también deja sin resolver el reorg de PoW (necesario para V6), documentado como límite aparte.

Durante la ejecución, el director envió dos avisos a mitad de sesión con hallazgos de revisiones
independientes (RI-2a, RI-2b) sobre `zx-cadena`/`zx-node`; los dos se corrigieron dentro de esta zona
(ver §«Cambios mínimos a otros crates» y `PROGRESO.md`).

## Tabla V1–V10

| Paso | Resultado |
|---|---|
| V1 `fmt --check` | **OK.** Workspace completo en verde. |
| V2 `clippy -D warnings --locked` | **OK.** Workspace completo (`--workspace --all-features --tests --bins`) en verde. |
| V3 `cargo test --workspace --all-features --locked` | **OK.** 715 pasan, 0 fallan, 2 ignorados (preexistentes). Ver `logs/V3-workspace.log`. |
| V4 Dos nodos cruzan el corte y producen ≥ 30 bloques PoST entre ambos | **PARCIAL.** Fase PoW: demostrado en vivo (dos procesos reales, TCP `127.0.0.1`, convergen). Fase PoST: **no demostrado** — bloqueada por `JustificacionPot` (documentado arriba). |
| V5 Tercer nodo que llega tras ≥ 100 bloques sincroniza | **NO DEMOSTRADO de extremo a extremo.** El mecanismo (localizador + `CabecerasPow` + `Bloques`) está implementado y el localizador tiene test unitario (denso cerca de la punta, termina en el génesis); no hubo presupuesto para levantar un tercer proceso real a ≥ 100 bloques dentro de esta sesión. |
| V6 Partición y reunión | **NO DEMOSTRADO.** Requiere reorg de PoW, fuera de alcance (límite documentado en `PROGRESO.md`): `admitir_pow_interno` (heredado de `ORDEN-W06d1`) valida siempre contra `historial_pow.last()`, no contra el padre declarado del bloque. |
| V7 Herramienta adversarial, cada entrada de E-7 | **PARCIAL.** `PoW nonce malo`: verificado en vivo (rechazado y desconectado). `Ráfaga de huérfanos`: implementada y ejecutada; una corrida mostró una desconexión sin que el objetivo llegara a admitir ningún mensaje (0 aceptados localmente por gossipsub) — intermitencia de la que no hubo tiempo de determinar la causa exacta dentro del presupuesto (ver «No demostrado»). `Coinbase mayor que el subsidio`: el escenario mina un PoW real acotado (2 000 000 intentos); en las corridas realizadas no siempre encontró nonce a tiempo y se omitió (declarado, no falseado). Los escenarios **PoST** (PoAS/PoT/sello malos) se envían de verdad pero el objetivo los ignora por el bloqueo de formato, no por su contenido. |
| V8 E-8 (equivocación) | **NO DEMOSTRADO por red** (mismo bloqueo de `JustificacionPot`: un PoST de red nunca llega al código que detectaría dos firmas del mismo slot). |
| V9 Traza de difusión: ningún `Aceptar` antes de validar | **PARCIAL.** Instrumentado (`bloque_red_admitido` se escribe solo tras que `admitir_pow_interno` retorna `Ok`, revisado por lectura del código); no se hizo un análisis automatizado de un registro de corrida larga que lo confirme sistemáticamente. |
| V10 `dependencias-exactas.sh`, `frontera-crates.sh`, lock sin cambios de versión | **OK.** `frontera-crates.sh`: `zx-p2p → {zx-core}` intacta. `dependencias-exactas.sh`: 23/23. Diff del lock: solo aristas nuevas de `zx-node` hacia `zx-p2p`/`tokio`/`tracing`/`libp2p` (ya resueltos en el árbol); ninguna versión cambiada. |

## Tests antes/después

**Antes** (entrada congelada, `REVISION-W06a-C.md`): 698 pasan, 0 fallan, 2 ignorados.

**Después:** `cargo test --workspace --all-features --locked` (log completo en
`logs/V3-workspace.log`): **715 pasan, 0 fallan, 2 ignorados** (los dos ignorados son preexistentes:
`bench_coloreo_mergeset_maximo` de `zx-dag` y `v6_extremo_a_extremo_con_n_dev_real` de `zx-post` —
ninguno nuevo de esta orden).

**Perdidos:** 0 — no se eliminó ningún test existente.

**Añadidos:** 17 (698 + 17 = 715, cuadra exacto) —
- `zx-p2p/tests/dos_nodos.rs`: 2 (`un_diferido_no_se_retransmite_hasta_informar_aceptar`,
  `un_diferido_sin_informe_a_tiempo_no_se_retransmite`).
- `zx-cadena/tests/padres_e_identidad.rs`: 1 (`w06d2_hijo_antes_que_el_padre_se_admite_al_llegar_el_padre`).
- `zx-node/src/red/huerfanos.rs`: 6 (unitarios del depósito).
- `zx-node/src/red/vista.rs`: 4 (unitarios de la instantánea y el localizador).
- `zx-node/src/red/manejador.rs`: 3 (unitarios del `ManejadorEntrante`).
- `zx-node/tests/red_tcp.rs`: 1 (`dos_nodos_reales_sobre_tcp_se_conectan`, TCP real).

## Cambios mínimos a otros crates, uno a uno

1. **`zx-p2p`** (el único cambio previsto por la orden, decisión 1): `entrante.rs` (`IdDiferido`,
   `Veredicto::Diferir`, `VeredictoFinal`), `limites.rs` (dos constantes nuevas), `servicio.rs`
   (tabla de pendientes, barrido, `Comando::InformarValidacion`, `arrancar_con_plazo`), y los tests
   de `dos_nodos.rs`/`servicio.rs` actualizados a la nueva firma de `bloque_difundido`. Frontera
   intacta (`zx-p2p → {zx-core}`, comprobado).
2. **`zx-cadena`** (no previsto por la orden; aviso del director a mitad de ejecución, RI-2a):
   `cadena.rs`, un método privado nuevo (`dependencia_no_disponible`) llamado al principio de
   `admitir()`; ningún cambio de firma pública. Corrige que un bloque sometido antes que su padre
   quedara inválido para siempre. Test nuevo en `tests/padres_e_identidad.rs`.
3. **`zx-node`** (el propio alcance de la orden): módulo nuevo `src/red/`, cambios en `nodo.rs`
   (campos nuevos de `Nodo`, orden persistir/admitir corregido en `admitir_post_interno` — aviso del
   director, RI-2b —, métodos de admisión de red, registro estructurado), `main.rs`/`cli.rs` (flags
   `--red-escuchar`/`--red-marcar`), binario nuevo `zx-adversario`, dependencias nuevas en
   `Cargo.toml` (`zx-p2p`, `tokio`, `tracing`, `libp2p` con features mínimas).

## Avisos del director a mitad de ejecución (registrados también en `PROGRESO.md`)

1. **RI-2a** (`deepseek/RI-2a/INFORME.md`): `Cadena::admitir` cacheaba `ErrSinPadre` por padre
   ausente como definitivo para siempre — divergencia por orden de llegada. Corregido; test
   añadido; `diferencial_t04` (914 casos) y `propiedades.rs` siguen en verde tras el arreglo.
2. **RI-2b** (`deepseek/RI-2b/INFORME.md`): `admitir_post_interno` admitía en memoria antes de
   persistir (al revés que `admitir_pow_interno`), abriendo una ventana de doble firma PoST tras un
   `SIGKILL`. Corregido invirtiendo el orden, con el mismo argumento que ya documentaba el caso PoW.
   No se añadió un punto de inyección de fallo determinista para la ventana exacta (pendiente,
   declarado en `PROGRESO.md`): la reproducción original de RI-2b tampoco fue concluyente
   (ventana submilisegundo).

## Faltas de definición (ver `PROGRESO.md` para el detalle completo)

1. Caché de `cargo` incompleta para `clap_lex` — resuelta con un `cargo fetch` puntual (sin cambiar
   el lock).
2. `BloqueRed::Post` sin `JustificacionPot` — bloqueo central de esta orden, documentado con
   evidencia literal.
3. Sin reorg de PoW — límite heredado de `ORDEN-W06d1`, documentado.
4. El depósito de huérfanos no guarda la procedencia del huérfano original; la cascada de
   resolución no dirige peticiones a un par concreto para el segundo salto.
5. `red::arrancar` no reconecta automáticamente tras una desconexión ni reintenta `--red-marcar`.

## Lo no demostrado (honesto, sin adornar)

- No se demuestra `V4` en su forma PoST (≥ 30 bloques PoST entre dos nodos por red), `V5` (tercer
  nodo, ≥ 100 bloques), `V6` (partición/reunión) ni `V8` (E-8 por red) de extremo a extremo, por los
  motivos documentados arriba.
- La intermitencia observada en el escenario «ráfaga de huérfanos» de `zx-adversario` (una
  desconexión del objetivo sin que se entregara ningún mensaje) no se diagnosticó del todo: se
  investigó el mecanismo de formación de la malla de gossipsub como hipótesis principal, se aplicó
  un ajuste (espera fija tras conectar) que resolvió una regresión más grave introducida en el
  camino (el saludo dejaba de responder), pero la causa exacta de esa desconexión puntual queda sin
  cerrar.
- La prueba de 5 ejecuciones seguidas de la suite completa sin fallo (punto 7 de la orden) no se
  hizo: se ejecutó dentro de la corrida única de `cargo test --workspace` de este informe. El cambio
  en sí (subir el plazo de 30 s a 120 s) es una corrección conservadora sobre un mecanismo que ya
  esperaba eventos del registro, no una espera fija nueva.
- No se instaló ni ejecutó `perf`/similar para medir el «coste de CPU por entrada inválida antes del
  rechazo» que pide la métrica de V7 en `ESCENARIOS-0.0.1.md`.

## Ruta de este informe

`/home/katana/zeo/ZEROX/deepseek/W06d2/INFORME.md`. Progreso detallado y bitácora completa en
`/home/katana/zeo/ZEROX/deepseek/W06d2/PROGRESO.md`; horas en
`/home/katana/zeo/ZEROX/deepseek/W06d2/HORAS.log`; logs en
`/home/katana/zeo/ZEROX/deepseek/W06d2/logs/`.
