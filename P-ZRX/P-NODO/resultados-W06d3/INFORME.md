# INFORME — ORDEN-W06d3

**Ejecutor:** subagente Sonnet, único, sin subagentes. **Fecha:** 2026-09-26.
**Zona:** `/home/katana/zeo/ZEROX/deepseek/W06d3/`. **Entrada:** `ENTRADA-W06d3.sha256` verde al
empezar y al terminar.

## Veredicto

**SUPERADO PARCIALMENTE.** Las tres decisiones de código de la orden (justificación PoT en
`BloqueRed::Post`, verificación real de PoST ajenos por red, bifurcaciones PoW con selección de
terminal por FC-3) están implementadas, con tests dedicados y **cero regresiones** en la suite
completa (721 pasan, 0 fallan, 2 ignorados; 715/0/2 antes — 6 tests nuevos, 0 perdidos). La
diagnosis de la decisión 4 (desconexión intermitente) tiene causa identificada y corrección
aplicada. La prueba de reinicio (decisión 5, V8) pasó **5/5**. **Lo que no se cerró**: una corrida
limpia de V4 con los tres procesos reales cruzando el corte de punta a punta, por dos fallos reales
encontrados con procesos reales que no se llegaron a resolver dentro del presupuesto (uno de
verificación PoT, otro de activación de garantía Φ) — declarados en detalle en `PROGRESO.md`, con
todo lo que sí se pudo verificar de cada uno.

## Tabla V1–V9

| Paso | Resultado |
|---|---|
| V1 `fmt --check` | **OK** (verde tras cada tanda de cambios; verificado de nuevo al cierre) |
| V2 `clippy -D warnings` | **OK** (workspace completo, `--all-targets --all-features`, verde al cierre) |
| V3 `cargo test --workspace --all-features --locked` | **OK**: 721 pasan, 0 fallan, 2 ignorados (715/0/2 antes de esta orden; +6 tests nuevos — `zx-cadena/tests/bifurcacion_pow.rs` ×4, `zx-cadena/tests/equivocacion.rs` ×1, `zx-node::red::vista::tests::fijar_cabeceras_pow_sustituye_una_altura_ya_ocupada_por_registrar_pow` ×1 — 0 perdidos) |
| V4 (3 procesos reales, cruzan el corte y producen ≥60 PoST, 0 rechazos) | **PARCIAL, NO CERRADO EN LA VERSIÓN FINAL.** Ejecutado repetidas veces con procesos reales en `127.0.0.1` (ver abajo). En una corrida con una versión intermedia del código, dos de los tres procesos cruzaron el corte y produjeron **más de 100 bloques PoST** en régimen sin ningún rechazo (logs conservados, `logs/v4-real-1/`). En la corrida **final** (con todos los arreglos de esta orden aplicados), los tres procesos minaron durante ~9 min hasta la altura ~290 **sin ningún bloque propio rechazado**, pero ninguno llegó a fijar el terminal — ver el hallazgo Φ/depósito en `PROGRESO.md`, no resuelto |
| V5 (4.º proceso tardío sincroniza) | **NO EJECUTADO**: depende de que V4 cierre con un terminal fijado; no se llegó a este paso |
| V6 (partición y reunión) | **NO EJECUTADO** de extremo a extremo con procesos reales, por el mismo motivo. La convergencia tras bifurcación PoW (el mecanismo que V6a necesita) **sí** está probada de forma aislada y determinista: `zx-cadena/tests/bifurcacion_pow.rs` (FC-3, congelación al primer PoST, `mejor_punta_pow` sin corte alcanzable) |
| V7 (entradas inválidas de `zx-adversario`) | **PARCIAL.** `zx-adversario` actualizado para construir los escenarios PoST malos (E-7/E-8) con el terminal real del objetivo (antes imposible: bloqueo de formato ya resuelto por la decisión 1); no se relanzó contra un objetivo que hubiera cruzado el corte de verdad, porque ninguna corrida final llegó a cruzarlo. El escenario E-8 (equivocación) está demostrado a nivel de `Cadena` con claves propias: `zx-cadena/tests/equivocacion.rs` — los dos bloques se admiten, sin castigo (`C-EVP` inactivo, tal como pide el escenario) |
| V8 (5 ejecuciones seguidas de `cargo test -p zx-node --test reinicio`) | **OK — 5/5**, ver `logs/v8-reinicio-5x.log` (401 s, 415 s, 424 s, 452 s, 458 s; 2 tests cada vez, 0 fallos) |
| V9 (`dependencias-exactas.sh`, `frontera-crates.sh`, lock) | **OK** — 23 dependencias con versión exacta; las 9 fronteras de crate en verde; `Cargo.lock` idéntico byte a byte al de la raíz durante todo el trabajo |

## Qué se hizo (decisiones 1–5 de la orden)

### Decisión 1 — `BloqueRed::Post` lleva `JustificacionPot`

`zx_p2p::mensaje::BloqueRed::Post` tiene ahora el campo `justificacion: JustificacionPot`. El códec
(`zx-p2p/src/codec.rs`) usa, para PoST, el mismo formato que `zx_core::wire_dag::bloque_dag_a_bytes`/
`bloque_dag_desde_bytes` (cabecera ‖ justificación PoT ‖ cuerpo): la decodificación llama
directamente a esa función — no hay dos parsers del mismo formato. `MAX_BLOQUE_RED_BYTES` crece en
`MAX_JUSTIFICACION_POT_CODIFICADA` (19 201 B); los límites derivados (`MAX_GOSSIP_BYTES`,
`MAX_RESPUESTA_BYTES`) y sus aserciones de compilación siguen en verde.

### Decisión 2 — verificación real de PoST ajenos por red

`Nodo::intentar_admitir_post_de_red` (nuevo, espejo de la ruta PoW): sin terminal todavía →
`Ignorar`; padre declarado desconocido → huérfano (deposita y pide, igual que PoW); padre conocido
e inválido → `Rechazar`; en otro caso, construye el `BloqueDag` con la justificación ya presente y
llama a la tubería única (`admitir_post_interno`, `verificar = true`), que ya hacía la verificación
real (`verificar_cabecera_conjunta`, GHOSTDAG vía `Cadena::contexto_dag`, o `ContextoTransicion`
solo para el primer bloque tras el terminal). Simplificación declarada: `Invalida` y `Pendiente`
llegan como el mismo `Rechazar` (ver `PROGRESO.md`).

### Decisión 3 — bifurcaciones PoW por FC-3

`Cadena` (zx-cadena) gana `tips_pow`, `terminal_candidatos`, `mejor_punta_pow()` y `trabajo_pow()`.
El terminal, mientras no exista ningún bloque PoST (`self.dag.is_none()`), es el candidato de mayor
`Estado::trabajo` acumulado (FC-3), no el primero que llega; se congela para siempre en cuanto se
admite el primer PoST. `Nodo` gana `headers_pow` (todas las cabeceras PoW válidas conocidas, de
cualquier rama) y `actualizar_seleccion_pow` (reconstruye `historial_pow` desde la punta
seleccionada, con la profundidad de reorganización registrada). El contexto de validación PoW
(target/altura/timestamp) se calcula contra el **padre declarado**, nunca contra
`historial_pow.last()`. `VistaRed::fijar_cabeceras_pow` (nuevo) corrige que
`registrar_pow` nunca sustituía una altura ya ocupada tras una reorganización.

### Decisión 4 — diagnóstico de la desconexión intermitente

Causa identificada por lectura y confirmada en vivo: un bloque perdido por gossip antes de que la
malla de gossipsub termine de formarse deja una cadena de huérfanos que **nadie vuelve a pedir**
(`intentar_admitir_*_de_red` solo pide activamente el padre que falta cuando conoce el origen, nunca
para gossip; el único disparador de `CabecerasPow` era el saludo **al conectar**, sin reintento).
Corrección: reintento periódico del saludo a los pares ya conectados (`red/sync.rs`,
`PLAZO_REINTENTO_SALUDO = 5 s`) y el disparo de `CabecerasPow` ya no depende solo de la altura
relativa (que puede engañar frente a una bifurcación real), sino también de si la punta declarada
por el par es un hash que no reconocemos. No se demuestra que esto agote el fenómeno original de
`W06d2` (no se repitió el escenario exacto de `zx-adversario`), pero la causa que se encontró en
esta orden (un nodo aislado ~50 alturas sin admitir nada del resto) queda corregida y verificada
(las corridas de V4 posteriores no repiten ese patrón).

### Decisión 5 — prueba de reinicio, 5/5

`cargo test -p zx-node --test reinicio --locked --offline`: **5/5** verde,
`logs/v8-reinicio-5x.log`.

## Otros hallazgos y correcciones (no pedidos por una decisión concreta, encontrados con procesos reales)

Ninguno de los siguientes es reproducible con el arnés en memoria ni con un solo proceso: los cinco
necesitan latencia de red real y bifurcaciones reales.

1. **Nonce de depósito repetido** (`preparar_depositos`) — **corregido.** El `nonce` de una
   operación de garantía es un contador por clave, no por coinbase; el código leía el `nonce` una
   sola vez fuera del bucle y lo repetía para cada coinbase madura de la misma clave en el mismo
   bloque. `ErrNonce` en modo estricto invalida el bloque entero → bloque propio rechazado → fatal.
2. **`ErrPowTrasCorte` en un bloque propio** (`fase_pow`) — **corregido.** La comprobación de
   terminal solo vivía al final del bucle; un bloque propio obsoleto (`continue`) se la saltaba, y
   podía minarse sobre un padre cuyo estado ya tenía terminal fijado por un bloque de red admitido
   en la misma vuelta.
3. **Padre ajeno no registrado en el `ServicioPot` del hilo productor** (`regimen.rs`) —
   **corregido.** El hilo productor mantiene su propia copia de `ServicioPot` (diseño de `W06d1`,
   sin red); en cuanto GHOSTDAG elige un padre **ajeno**, la copia del hilo no lo conocía.
   `MsgBucle::Padres` ahora lleva `(hash, slot)` de cada padre; el hilo los registra (con
   `avanzar_hasta` si el padre es de un slot más adelantado que el propio) antes de producir.
4. **`SlotNoProgreso` tratado como fatal** — **corregido.** Consecuencia legítima de (3): un padre
   de un slot igual o posterior al que se está produciendo ya no es un candidato válido (otro nodo
   se adelantó). Antes hacía `panic!`; ahora se descarta esa candidata concreta y se sigue.
5. **`Pot(PasadoIncompleto)` verificando un bloque propio** — **NO RESUELTO.** Un padre declarado
   (según `Cadena`, ya válido) no aparece en `pasado()` del `ServicioPot` de **verificación** del
   bucle principal en el instante de verificar. Se investigó por lectura sin encontrar el hueco
   exacto entre las dos vistas (`Cadena` y `servicio_verificacion`) que lo permite. Ver
   `PROGRESO.md`.
6. **Φ/depósito no se satisface en la corrida final, aun sin errores** — **NO RESUELTO.** Con los
   arreglos de 1–4 aplicados, la corrida final de tres procesos limpios llegó a la altura ~290 sin
   ningún rechazo pero sin fijar nunca el terminal. Se revisó el camino completo de depósito y
   maduración (`preparar_depositos`, `aplicar_garantia`, `Aplicador::promover`) sin encontrar el
   fallo por lectura; el mismo camino, con tres claves en un solo proceso, es lo que prueba en verde
   `tests/integracion.rs`. La hipótesis más probable —no confirmada— es que algo en la agregación de
   `Estado::garantias` entre las tres claves, cada una depositada por un proceso distinto, no cuenta
   como se esperaba. Ver `PROGRESO.md` para el detalle completo.

## Cambios a otros crates, uno a uno

| Crate | Archivo | Motivo |
|---|---|---|
| `zx-p2p` | `src/mensaje.rs` | Decisión 1: campo `justificacion` en `BloqueRed::Post` |
| `zx-p2p` | `src/codec.rs` | Decisión 1: códec PoST vía `zx_core::wire_dag` |
| `zx-p2p` | `src/limites.rs` | Decisión 1: `MAX_BLOQUE_RED_BYTES` incluye la justificación |
| `zx-p2p` | `tests/dos_nodos.rs` | Fixture `bloque_post` con el campo nuevo |
| `zx-cadena` | `src/cadena.rs` | Decisión 3: FC-3, `tips_pow`, `mejor_punta_pow`, `trabajo_pow` |
| `zx-cadena` | `tests/bifurcacion_pow.rs` (nuevo) | Prueba dedicada de FC-3 y congelación del terminal |
| `zx-cadena` | `tests/equivocacion.rs` (nuevo) | E-8 a nivel de `Cadena` (admite, sin castigo) |
| `zx-node` | `src/nodo.rs` | Decisiones 2, 3, 4; los 4 hallazgos corregidos |
| `zx-node` | `src/pow.rs` | Hallazgo 1: `CoinbasePropia.bloque`; nonce por clave (parte en `nodo.rs`) |
| `zx-node` | `src/regimen.rs` | Hallazgos 3 y 4: registro de padres ajenos, `SlotNoProgreso` |
| `zx-node` | `src/red/sync.rs` | Decisión 4: reintento periódico, disparo por punta desconocida |
| `zx-node` | `src/red/vista.rs` (+ test) | Decisión 3: `fijar_cabeceras_pow` |
| `zx-node` | `src/bin/zx-adversario.rs` | V7: escenarios PoST con el terminal real del objetivo |

Ningún cambio a `zx-consensus`, `zx-dag`, `zx-poas`, `zx-pot`, `zx-post`, `zx-farmer`,
`zx-storage`. Fronteras de crate (V9) verificadas sin excepción.

## Faltas de definición encontradas (registradas en `PROGRESO.md` antes de editar)

- Cinco hallazgos en vivo listados arriba (cuatro corregidos, dos sin resolver).
- Límite residual declarado: el marcado `depositada = true` no es sensible a la rama tras una
  reorganización (conservador, no inseguro — ver `PROGRESO.md`, decisión 3).
- `EstadoCabeceraConjunta::Invalida`/`Pendiente` se tratan igual (`Rechazar`) en la ruta de red de
  PoST; distinguirlos exigiría un tipo de error más rico en `admitir_post_interno`.
- `VistaRed` sigue asumiendo, para el propósito de `cuerpos_pow` (no para `cabeceras_pow`, ya
  corregido), una sola rama por altura; no se rehizo por completo (fuera de proporción para esta
  orden).

## No demostrado

- V4 de punta a punta con la versión **final** del código (cruce del corte con tres procesos,
  ≥ 60 PoST, 0 rechazos) — los hallazgos 5 y 6 lo bloquean. Sí se demostró con una versión
  intermedia (dos de tres procesos, > 100 PoST sin caerse; `logs/v4-real-1/`).
- V5 (nodo tardío) y V6 (partición y reunión con procesos reales): dependen de que V4 cierre.
- V7 con un objetivo que haya cruzado el corte de verdad (el objetivo de las corridas reales nunca
  llegó a producir PoST en la versión final).
- Que el diagnóstico de la decisión 4 agote el fenómeno original de `W06d2` (solo se confirma que
  la causa encontrada aquí, y su corrección, se sostienen en las corridas de esta orden).
- Medida de CPU por entrada inválida (V7, "amplificación"): no se llegó a medir con un objetivo en
  fase PoST real.

## Rutas relevantes

- Informe: `/home/katana/zeo/ZEROX/deepseek/W06d3/INFORME.md` (este archivo).
- Progreso detallado y los 6 hallazgos: `/home/katana/zeo/ZEROX/deepseek/W06d3/PROGRESO.md`.
- Parche y huellas: `/home/katana/zeo/ZEROX/deepseek/W06d3/cambios.patch`,
  `/home/katana/zeo/ZEROX/deepseek/W06d3/MIGRACION.sha256`.
- Horas: `/home/katana/zeo/ZEROX/deepseek/W06d3/HORAS.log`.
- Logs de V4 reales: `/home/katana/zeo/ZEROX/deepseek/W06d3/logs/v4-real-1/` (dos corridas
  conservadas: una con crash diagnosticado, otra con los tres procesos sin cruzar el corte).
- Log de V8: `/home/katana/zeo/ZEROX/deepseek/W06d3/logs/v8-reinicio-5x.log`.
- Log de la suite final: `/home/katana/zeo/ZEROX/deepseek/W06d3/logs/test-workspace-final.log`.
