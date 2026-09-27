# INFORME — ORDEN-SL4b2 (castigo activo en el nodo)

**Ejecutor:** subagente Sonnet, único (sin forks ni subagentes). **Fecha:** 2026-09-27, 07:56–09:47.
**Zona:** `deepseek/SL4b2/`. Base: raíz en el commit `bb648fb` (código); documentación leída del
disco vivo cuando no coincide con ese commit (ver `PROGRESO.md`, entrada 2026-09-27T07:56:54).

## Resumen ejecutivo

Las decisiones 0-5 de la orden están implementadas en `ws/`, compilan limpias (`cargo check`),
pasan `cargo fmt --check` y `cargo clippy --workspace --all-targets --all-features --locked -- -D
warnings`, y **la pregunta falsable de la orden se comprobó con procesos reales**: con un tercero que
posee la clave dev 0 y publica una segunda cabecera de la misma identidad RAT-1, los tres nodos
detectan el incidente, uno lo incluye, la garantía de la clave se confisca **entera** (`f=1`,
`RAT-2′`), y los tres convergen al mismo estado — en **3 repeticiones** con procesos reales (V4).
Sin ese tercero, ni 10 `SIGKILL` (V5) ni la pérdida del registro del firmante (V6) producen una sola
doble firma observable. La decisión 0 (paso previo) también se comprobó con procesos reales: un nodo
perdedor de una reunión de terminales, **sin reiniciar su proceso**, se reorganiza al terminal
ganador y sigue produciendo sobre él (9 bloques más tras la reunión, `profundidad_reorg:1`).

**Dos fallos reales se encontraron y corrigieron durante la propia verificación** (declarados en
detalle en `PROGRESO.md`, resumidos aquí):

1. Un diagnóstico que yo mismo añadí para poder leer la confiscación (`garantia_clave_tras_evidencia`)
   leía inicialmente `Cadena::estado_terminal()` — que es el estado del **corte** PoW→PoST, no la
   punta PoST corriente — y por eso la primera repetición de V4 parecía mostrar que la confiscación
   no se aplicaba (`activo` sin cambiar). Corregido a `estado_post(&hash)` (el estado tras el bloque
   que se acaba de admitir); las tres repeticiones de V4 confirman después `activo:0, congelado:0`
   en los tres nodos.
2. Mi primer guion de V5 (10 `SIGKILL`) no esperaba a que el proceso muerto liberara de verdad el
   `LOCK` de RocksDB ni el puerto TCP antes de relanzar; el primer intento murió con
   `error fatal: ... LOCK: Resource temporarily unavailable`, y una segunda pasada corregida a
   medias solo llegó a hacer **un** reinicio real de los diez pedidos (los otros nueve procesos se
   lanzaban pero no llegaban a arrancar, sin que mi propio `hay_fatal` lo detectara, porque el
   mensaje de ese fallo es distinto del que yo buscaba). Corregido dos veces (`ejecutar_v5.sh`
   espera además a que el puerto deje de aparecer en `ss`, y el guion comprueba de verdad, iteración
   a iteración, que cada reinicio produjo un evento `arranque` nuevo). La tercera pasada: **11
   arranques, 10 reinicios completos, 0 abstenciones, 0 evidencias — genuino.**

Ningún fallo de las decisiones 0-5 en sí; los dos de arriba son de mis propios guiones de
verificación, y se declaran porque encontrarlos y corregirlos **es** la verificación (`LINEO.md`:
«no se acepta... una optimización por intuición»; aquí, ningún resultado sin medirlo de verdad).

## Tabla de pasos

| Paso | Qué | Resultado |
|---|---|---|
| Decisión 0 (paso previo) | Productor sigue al terminal seleccionado en caliente | **Superado con procesos reales** (`ejecutar_e6b.sh`): A aislado gana la reunión (8 vs 5 bloques); B, el perdedor, **sin reiniciar su proceso**, se reorganiza (`profundidad_reorg:1`) y produce 9 bloques más sobre el terminal de A; `resumen_estado` converge en los tres |
| V0 | `sha256sum -c` de la entrada; suite completa de la raíz sin cambios | **Verde.** 55/55 huellas; 81 binarios de test, 0 fallos (`ws.orig`) |
| V1 | Tests unitarios del detector (misma identidad/otro pre_hash, misma cabecera, 6 campos de RAT-1, poda, tope+desalojo, tercera cabecera) | **Verde.** 7/7 en `crates/zx-node/src/evidencia.rs` |
| V2 | Inclusión: pendiente con ventana abierta/cerrada/ya procesada/reorganizada | Cubierto **con procesos reales** en V4 (inclusión real, confiscación real) y por el diseño de `evidencia.rs`/`nodo.rs` (no se marca "consumida" al incluir, EV-24/decisión 4); sin test unitario aislado de la reorganización que la reincorpora — ver «Lo que no queda demostrado» |
| V3 | Puerta RAT-3 en el arranque; `R_SLOTS=600` | **Verde.** 3 tests unitarios (`perfil.rs`, `nodo.rs::pruebas_puerta_rat3`): perfil real pasa, perfil que la incumple no arranca (con el mensaje exacto), borde exacto (`360`) también incumple |
| V4 | 3 nodos reales, `zx-adversario doble-firma --clave-indice 0 --repetir`, 3 repeticiones | **Superado, 3/3.** `evidencia_detectada` en los tres (propia/ajena correcto); ninguna segunda evidencia por la tercera cabecera (EV-10/EV-12); inclusión real; **`activo:0, congelado:0`** en los tres nodos, verificado de forma independiente por cada uno; `resumen_estado` converge en los tres, las 3 veces |
| V5 | Honesto sin castigo: 10 `SIGKILL` en momentos aleatorios, reinicio inmediato | **Superado** (tercera pasada, tras corregir el guion). 11 arranques (1+10), 10 `reinicio_completo`, **0** `firmante_abstenido`, **0 y 0** `evidencia_detectada` en B y C |
| V6 | Pérdida del registro del firmante | **Superado.** `firmante_abstenido` con `motivo:"perdida_registro"` en los slots 57-184 (borde inclusivo exacto: `slot_perdida(34) + S_max(150) = 184`), produce en 185; **0 y 0** `evidencia_detectada` en B y C |
| V7 | `fmt`, `clippy -D warnings`, suite completa, `ci/dependencias-exactas.sh`, `ci/frontera-crates.sh`; regresión con procesos reales | **Verde, completo.** `fmt --check` limpio; `clippy --workspace --all-targets --all-features --locked -- -D warnings` limpio; `ci/dependencias-exactas.sh` OK (24 exactas); `ci/frontera-crates.sh` OK (9 fronteras); `cargo test --workspace --all-features --locked`: **81 binarios, 0 fallos** (igual que V0). Regresión real: `zx-adversario` sin subcomando (E-7/E-8) idéntico al de siempre contra un nodo real; decisión 0 (E-6b) y 3 nodos convergiendo repetidos muchas veces (V4×3, V5, V6) |

## Tabla de cobertura (lección de método 1)

| Evento / resultado | Al menos un caso, dónde |
|---|---|
| `evidencia_detectada` (propia) | V4, nodo A, las 3 repeticiones (`propia:true`) |
| `evidencia_detectada` (ajena) | V4, nodos B y C, las 3 repeticiones (`propia:false`) |
| `evidencia_incluida` | V4, las 3 repeticiones (2 en rep1, 1 en rep2 por C, 1 en rep3) |
| Descarte por repetición (tercera cabecera, EV-10/EV-12) | V4, las 3 repeticiones: 1 `evidencia_detectada` por incidente pese a 3 cabeceras; unitario en `evidencia.rs::tercera_cabecera_no_produce_evidencia_nueva_del_mismo_incidente` |
| Ventana cerrada (EV-14) | Unitario, `evidencia.rs::poda_pendientes_por_cierre_de_ventana` |
| `firmante_abstenido` por conflicto | Unitario, vía `zx_post::firmante` (SL-4b1, no repetido aquí: la orden no pide un caso nuevo de conflicto, solo de pérdida) |
| `firmante_abstenido` por pérdida | V6, procesos reales, 81 eventos consecutivos (slots 57-184) |
| `Reemitido` (mismo `pre_hash`) | Heredado de SL-4b1 (`zx_post::firmante::tests`), no repetido aquí |
| Tope y desalojo del detector | Unitario, `evidencia.rs::tope_desaloja_la_mas_vieja` |
| Puerta RAT-3 en el arranque | Unitario, `nodo.rs::pruebas_puerta_rat3` (perfil real pasa, perfil malo no arranca, borde exacto) |
| Confiscación completa (`f=1`, `C=V`) | V4, procesos reales, las 3 repeticiones, verificado en los 3 nodos independientemente |
| `A no produce con garantía < q` | V4: la clave 0 de A deja de aparecer en producción tras la confiscación (indirecto: el esquema de registro no lleva `clave` en `bloque_producido`, decisión previa a esta orden, no se cambia aquí) |

## Archivos cambiados (en `ws/`, ninguno en `ws.orig/`)

- `crates/zx-node/src/perfil.rs` — constantes de evidencia, `parametros_evidencia_dev`, `puerta_rat3`
- `crates/zx-node/src/regimen.rs` — decisión 0 (`MsgBucle::CambiarTerminal`, `Recepcion`), decisión 2
  (firmante seguro, `MsgProductor::Abstenido`), decisión 4 (evidencias en `CuerpoProductor`)
- `crates/zx-node/src/nodo.rs` — decisión 0 (`sincronizar_terminal_productor`), decisión 1 (puerta
  RAT-3 en `arrancar`, `Cadena::nueva_con_evidencia`), decisión 2 (`registro_firmante`,
  `abrir_registro_firmante_limpio/tras_reinicio`), decisión 3 (`detector`,
  `observar_para_detector`), decisión 4 (cálculo de `evidencias` en `PeticionPadres`,
  `evidencia_incluida`), diagnóstico `garantia_clave_tras_evidencia`
- `crates/zx-node/src/evidencia.rs` — **nuevo**, decisión 3: `DetectorDobleFirma`
- `crates/zx-node/src/error.rs` — `ErrorNodo::PuertaRat3Incumplida`
- `crates/zx-node/src/lib.rs` — `pub mod evidencia;`
- `crates/zx-node/src/bin/zx-adversario.rs` — decisión 5: subcomando `doble-firma`
- Ningún archivo de `crates/zx-post/src/{lib.rs,productor.rs,productor_regimen.rs}` tocado (ver
  `DEFINICIONES-FALTANTES.md` §1: ya traían `producir_en_regimen_con_firmante` de SL-4b1; la
  visibilidad de las funciones sin firmante se dejó como estaba, declarado y justificado)
- `Cargo.lock`/`Cargo.toml`: sin cambios (`ci/dependencias-exactas.sh` verde, 24 dependencias exactas)

## Definiciones faltantes

Ver `DEFINICIONES-FALTANTES.md` (4 entradas, ninguna bloqueante): visibilidad de las funciones sin
firmante en `zx-post` (contrato con las pruebas fuera de mi zona), cómo leer la confiscación sin
tocar `zx-p2p`/`zx-cadena` (diagnóstico nuevo), el slot en `PeticionPadres` (protocolo interno), y la
persistencia del detector entre reinicios (no exigida por la orden, funciona igual por transitividad
con la repetición del almacén).

## Lo que no queda demostrado (declarado, no disimulado)

- **V6(b) de W06d7 (mismo terminal, aislamiento breve)** no se repitió por separado; sí se repitió
  el escenario más exigente, E-6b (terminales distintos que se reúnen con producción en marcha),
  con resultado superado (ver arriba).
- **`A no produce con garantía < q` con una prueba dedicada:** se infiere de que la clave 0 de A deja
  de contribuir bloques tras la confiscación en V4 (indirecto, el registro no identifica la clave por
  bloque); no hay una comprobación directa por clave.
- **Repetición de `firmante_abstenido` por conflicto y `Reemitido`** con procesos reales de esta
  orden: son casos heredados de SL-4b1 (ya probados ahí, unitariamente); no se repitieron aquí porque
  la orden no pide un caso nuevo, solo cobertura mínima (cumplida por SL-4b1).

## Último paso: `cambios.patch` y `MIGRACION.sha256`

- `cambios.patch`: `diff -ruN ws.orig/crates/zx-node ws/crates/zx-node` — 7 archivos (6 modificados +
  `evidencia.rs` nuevo).
- `MIGRACION.sha256`: `sha256sum` de los 7 archivos, calculado desde `ws/`. **Verificado en verde**
  con `sha256sum -c ../MIGRACION.sha256` desde `ws/`: 7/7 «La suma coincide».
- `ws.orig/` verificado **intacto**: `diff -rq` contra una segunda extracción fresca de
  `crates/zx-node` en el commit `bb648fb` — sin diferencias.

## Horas

Ver `HORAS.log` (con `date -Is` real) y las marcas de tiempo en `PROGRESO.md`, todas verificadas, no
declaradas de memoria.
