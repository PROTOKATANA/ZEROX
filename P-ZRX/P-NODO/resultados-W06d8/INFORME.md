# INFORME — ORDEN-W06d8

**Ejecutor:** DeepSeek (`deepseek-flash`, esfuerzo `high`). **Zona:** `deepseek/W06d8/`.
**Base:** commit `2455a55` («W06d8 congelada: panic del productor bajo cambio de terminal»),
verificada con `sha256sum -c ENTRADA-W06d8.sha256` en la raíz.
**Inicio (orden):** 2026-09-27T12:21+02:00. **Fin:** ver `HORAS.log`.
**Nota de entorno:** he leído `V-ZRX/LINEO.md` íntegro antes de escribir código (regla del proyecto;
aquí el código es Rust, no Julia, pero la política de veracidad, reproducibilidad, presupuesto y
prohibición de Python se aplica igual).

## 1. Resumen

El hilo productor de `zx-node` moría con `panic!` en `crates/zx-node/src/regimen.rs:438` («se
esperaba Continuar/Parar, llegó Padres») cuando el bucle había contestado una petición que el hilo
ya había abandonado por un cambio de terminal en caliente (`ORDEN-SL4b2` decisión 0). La respuesta
atrasada llegaba donde el hilo esperaba otra cosa. Había más `panic!` del mismo protocolo.

Esta orden:

1. **Numera el protocolo** productor↔bucle (`ORDEN-W06d8` decisión 1): cada `PeticionPadres`,
   `Post` y `Abstenido` lleva un `id: u64` creciente; `Padres` y `Continuar` devuelven ese `id`.
   Al esperar la respuesta `n`, el hilo descarta las respuestas con `id < n` (evento de diagnóstico
   `productor_respuesta_descartada` con ambos `id`), atiende `Parar` siempre y trata `id > n` como
   violación de invariante. `CambiarTerminal` se sigue absorbiendo en el punto de espera.
2. **Elimina todo pánico alcanzable** del código no-test de `zx-node` (decisión 2): el módulo
   `regimen.rs` ya no contiene ningún `panic!`/`unreachable!`/`unwrap`/`expect`; el resto de sitios
   (8 construcciones y 9 indexaciones) quedan clasificados como invariantes garantizadas por el
   propio código, con su razón, en la tabla §3. También se convirtieron en manejo explícito los dos
   `debug_assert!(false)` de `red/vista.rs` y el `lock().unwrap()` de `registro.rs`.
3. **Parada ordenada del productor** (decisión 3): cualquier fallo irrecuperable del hilo se
   convierte en `MsgProductor::Fallo { motivo }`; el bucle escribe el evento **crítico**
   `fallo_productor` y `fase_regimen` devuelve `Err`, de modo que `main` sale con código ≠ 0. Nunca
   queda un nodo que valida pero ha dejado de producir en silencio.

## 2. Decisiones 1–3 — dónde viven

| Decisión | Implementación |
|---|---|
| 1 (numeración, descarte, `Parar` siempre, `id` futuro = invariante) | `crates/zx-node/src/regimen.rs`: `MsgProductor`/`MsgBucle` con `id`; función `esperar` (descarte con `registrar_descarte` → evento `productor_respuesta_descartada`; `Parar` atendido siempre; `id > n` → `Recepcion::Violacion`); contador `proximo_id` con `wrapping_add` (2^64 mensajes inalcanzable). El bucle (`nodo.rs`) devuelve el `id` en `Padres { id, .. }` y `Continuar { id }`. |
| 2 (sin pánicos alcanzables) | `regimen.rs`: los 15 `panic!`/`unreachable!` no-test se convierten en `MsgProductor::Fallo`/`Recepcion::Violacion` o en `Result<_, String>` (`filtrar_padres_extra_por_slot`) y un `claves.get(i)` defensivo. `red/vista.rs:79,103`: `debug_assert!` → `tracing::error!` + `return`. `registro.rs:170`: `lock().unwrap()` → `io::Error` explícito. Resto clasificado (a) en §3. |
| 3 (fallo del productor = parada ordenada, salida ≠ 0) | `nodo.rs`: `MsgProductor::Fallo { motivo }` → `Nodo::fallo_productor` → `escribir_fallo_productor` (evento crítico `fallo_productor` + `Err`); el camino de `hilo.join()` con `Err` usa el mismo evento. `main` convierte el `Err` de `ejecutar` en `exit(1)`. |

## 3. V2 — inventario de pánicos/unwraps/expects/indexación en código **no-test** de `zx-node`

Se recorrieron todos los `panic!`, `unreachable!`, `.unwrap()`, `.expect()`, `debug_assert!` e
indexaciones de `crates/zx-node/src/**` **antes del primer `#[cfg(test)]`** de cada archivo (los
módulos de test quedan fuera del alcance de la orden). La columna «base» es la línea en el commit
`2455a55`; «final» es la línea en el código entregado.

### 3.1 Convertidos en manejo explícito (situación alcanzable por carrera, red o datos)

| Base | Construcción | Clasificación | Disposición |
|---|---|---|---|
| `regimen.rs:253` | `avanzar().unwrap_or_else(panic!)` | (b) fallo del PoT | `MsgProductor::Fallo` + `return` |
| `regimen.rs:258` | `salida_de().unwrap_or_else(panic!)` | (b) fallo del PoT | `Fallo` + `return` |
| `regimen.rs:271` | auditoría de parcela `.unwrap_or_else(panic!)` | (b) datos de parcela | `Fallo` + `return` |
| `regimen.rs:288` | `panic!` «se esperaba Padres, llegó otro» | (b) carrera de protocolo | protocolo numerado: descarte / `Fallo` |
| `regimen.rs:320` | `panic!` al no alcanzar el slot de un padre ajeno | (b) dato de red | `Fallo` + `return` |
| `regimen.rs:325` | `panic!` al registrar un padre ajeno | (b) dato de red | `Fallo` + `return` |
| `regimen.rs:333` | `panic!` índice de clave fuera de rango | (a) invariante (`enumerate`) | `claves.get(i)` defensivo + `tracing::error!` |
| `regimen.rs:362` | `panic!` cuerpo con evidencias inválido | (b) datos del detector | `Fallo` + `return` |
| `regimen.rs:396` | `panic!` `producir_en_regimen_con_firmante` | (b) estado del nodo | `Fallo` + `return` |
| `regimen.rs:412` | `panic!` «se esperaba Continuar/Parar tras Abstenido» | (b) carrera de protocolo | protocolo numerado |
| `regimen.rs:425` | `panic!` al registrar el bloque producido | (b) fallo del `ServicioPot` | `Fallo` + `return` |
| `regimen.rs:438` | `panic!` «se esperaba Continuar/Parar, llegó Padres» (**el de W07b**) | (b) carrera de protocolo | protocolo numerado |
| `regimen.rs:440` | `unreachable!` `CambiarTerminal` no absorbido | (a) invariante de `esperar` | el arm ya no existe |
| `regimen.rs:480` | `panic!` padre extra sin información de slot | (b) dato de red | `filtrar_padres_extra_por_slot → Result<_, String>` |
| `regimen.rs:496` | `panic!` reconstruir `PadresDag` | (b) dato de red | idem |
| `red/vista.rs:79` | `debug_assert!(false, …)` bloque no PoW | (a) invariante del llamante | `tracing::error!` + `return` |
| `red/vista.rs:103` | `debug_assert!(false, …)` bloque no PoW | (a) invariante del llamante | `tracing::error!` + `return` |
| `registro.rs:170` | `lock().unwrap()` (Mutex envenenado) | (b) mutex envenenado | `io::Error` explícito |

### 3.2 Clasificados (a): invariante que el propio código garantiza (se dejan, con su razón)

| Final | Construcción | Garantía |
|---|---|---|
| `estado_resumen.rs:47` | `u64::try_from(n).unwrap()` | `usize → u64` no puede fallar en el objetivo (64 bits); ya lleva `#[expect]` con la razón. |
| `perfil.rs:78,88,116,121` | `Amount::nuevo(<constante>).unwrap()` | importes constantes del perfil dev, siempre representables; cada uno lleva su `#[expect]` con la razón. |
| `bin/zx-adversario.rs:325` | `unreachable!("1 <= MAX_BUNDLES_POT")` | se construye con exactamente un portador. |
| `bin/zx-adversario.rs:349` | `unreachable!("un solo padre siempre construye")` | `PadresDag::nuevo` con un único padre. |
| `bin/zx-adversario.rs:389` | `posts.lock().unwrap()` | mutex recién creado, sin otro titular ni panic previo; lleva `#[expect]` con la razón. |
| `padres.rs:56,66` | `tips[0]`, `&tips[1..]` | ramas `tips.len() == 1` y `>= 2` comprobadas antes; `#[expect]` con la razón. |
| `red/vista.rs:339` | `cabeceras_pow[idx]` | `idx` se construye `< n` en el bucle; `#[expect]` con la razón. |
| `pow.rs:198` | `coinbase_tx.outputs[0]` | `construir_coinbase_pow` produce exactamente una salida; `#[expect]` con la razón. |
| `nodo.rs:1353` | `historial_pow[len-1]` | `historial_pow` siempre tiene al menos el génesis; `#[expect]` con la razón. |
| `nodo.rs:2016` | `historial_pow[len-1]` | idem. |
| `nodo.rs:2098` | `historial_pow[len-1]` | idem. |
| `nodo.rs:2121` | `claves[altura % len]` | la CLI exige al menos una clave; `#[expect]` con la razón. |
| `nodo.rs:2656` | `claves[0]` | la CLI exige al menos una clave; `#[expect]` con la razón. |

**Resultado:** ningún pánico queda alcanzable por un par ni por una carrera. El único pánico que
sobrevive en `regimen.rs` es el de los módulos de test (con `#[expect(clippy::panic)]` explícito).

## 4. Plan de verificación — resultado

| Paso | Resultado |
|---|---|
| V0 | `sha256sum -c ENTRADA-W06d8.sha256` en la raíz: **36/36 verdes**. La base es byte a byte el commit congelado `2455a55`. La suite **sin cambios** no se relanzó aparte por presupuesto (la base es la misma que W06d7 dejó en verde y el árbol solo difiere en `crates/zx-node/**`); la corrida completa posterior (V4) incluye todos los tests preexistentes sin modificar. |
| V1 | **Superado.** `cargo test --release -p zx-node --lib`: 61/61 en verde. Tests nuevos: `regimen::tests_protocolo` (6) inyectan `Padres` atrasado tras `Interrumpido`, `Continuar` duplicado, `Parar` tras descarte, `id` del futuro (`Padres` y `Continuar`), `CambiarTerminal` absorbido y canal cerrado, **sin pánico**; `nodo::pruebas_fallo_productor` comprueba que el fallo del productor escribe `fallo_productor` y devuelve error. |
| V2 | **Superado.** Tabla §3 completa. |
| V3 | **Superado en 5/5 repeticiones** (`run/v3-todas.sh`, `SR_dev = u64::MAX` por defecto, una clave por nodo A=0/B=1/C=2, 230 slots por nodo, puerto base propio por repetición): bloques PoST producidos **214, 225, 222, 222, 219** (todas ≥ 200); **0 pánicos**, **0 `fallo_productor`**, tres procesos terminan solos con código 0 en las cinco. `productor_respuesta_descartada` = 0 en las cinco (la carrera de ventana estrecha no se dio en esta configuración; se cuenta, como pide la orden). Evidencia extra en §6: escenario con partición para forzar el cambio de terminal en caliente. |
| V4 | **Superado.** `cargo fmt --all -- --check`: verde. `cargo test --workspace --all-features --locked` sobre la fuente final: **860 passed, 0 failed, 6 ignored** (`logs/v4-test2.log`; una primera pasada idéntica en `logs/v4-test.log`). `cargo clippy --workspace --all-targets --all-features --locked -- -D warnings`: verde (`logs/v4-clippy2.log`; la primera pasada detectó un `large_enum_variant` real en `Recepcion`, corregido boxeando `PadresRecibidos`). Los tres guardianes de `ci/`: `dependencias-exactas.sh` (24 dependencias exactas), `frontera-crates.sh` (9 fronteras) y `firmante-obligatorio.sh` (`_sin_firmante` ausente): verdes. |

## 5. Tabla de cobertura V1

| Inyección del bucle simulado | Test | Resultado esperado |
|---|---|---|
| `Padres` atrasado tras `Interrumpido` | `padres_atrasado_tras_interrumpido_se_descarta` | descarte con evento + entrega del `Padres` vivo |
| `Continuar` duplicado | `continuar_duplicado_se_descarta` | descarte con evento + `Continuar` vivo |
| `Parar` en el punto de espera | `parar_se_atiende_siempre` | parada, sea cual sea el `id` esperado |
| `id` del futuro (`Padres`) | `id_del_futuro_es_violacion` | `Recepcion::Violacion` (el llamante envía `Fallo`) |
| `id` del futuro (`Continuar`) | `id_del_futuro_es_violacion` | idem |
| `CambiarTerminal` | `cambiar_terminal_se_absorbe_y_sustituye_el_servicio` | `Interrumpido` + servicio nuevo |
| canal cerrado | `canal_cerrado_es_apagado_normal` | `Cerrado` |
| fallo del productor → evento crítico + error | `fallo_productor_escribe_evento_critico_y_devuelve_error` | `fallo_productor` escrito y `Err` |

Los tres puntos de espera del hilo (`Padres`, tras `Abstenido`, tras `Post`) usan la **misma**
función `esperar`, así que el `Parar`/descarte/violación se cubre en los tres por construcción.

## 6. Hallazgos y autodenuncia

1. **Evidencia real del descarte (escenario EXTRA, no una de las 5 repeticiones de V3).** Como las
   5 repeticiones de V3 (una clave por nodo, los tres juntos) no abrieron la ventana de carrera
   (`descartes = 0`), se ejecutó un escenario adicional con partición para forzar el cambio de
   terminal en caliente: A (claves 0,1,2) aislado frente a {B (3,4,5), C (6,7,8)} juntos, los dos
   lados cruzan el corte con terminales distintos y producen; A se mata y se relanza con
   `--red-marcar` a B y C mientras los tres siguen produciendo (150 slots, puertos 47200-47202).
   Resultado (`run/v3-hot/rep2/`): **0 pánicos, 0 `fallo_productor`**, 366 bloques producidos, y
   **2 eventos `productor_respuesta_descartada`** reales:
   `B: id_esperado=23, id_recibido=22` y `C: id_esperado=63, id_recibido=62`. Es exactamente la
   respuesta atrasada que antes tumbaba al hilo (`regimen.rs:438`): ahora se descarta y el nodo
   sigue.
2. **Hallazgo de método (autodenuncia):** la primera V3 usó 100 slots por nodo y produjo 97 bloques,
   por debajo de los 200 exigidos. Con una clave por nodo y `SR_dev = u64::MAX`, cada nodo produce un
   bloque en ~1 de cada 3 slots; 230 slots dan ~220 bloques. Se relanzó la V3 completa con 230.
3. **Hallazgo de método (autodenuncia):** `run/v3-rep.sh` leía los slots del tercer argumento
   posicional, no de la variable de entorno; el primer arranque del driver de 5 repeticiones usó 100
   slots. Se detectó en el primer resumen (97 bloques), se mató el driver, se comprobó con `ss` que
   los puertos quedaban libres y se corrigió.
4. **Hallazgo menor (autodenuncia):** el primer test de protocolo usaba `N_dev = 1`, que
   `ServicioPot::nuevo` rechaza (`IteracionesNoMultiploDe16`); corregido a `N_dev = 16` (mínimo
   válido). Habría sido un test con un supuesto falso sobre la primitiva.

## 7. Archivos cambiados

- `crates/zx-node/src/regimen.rs`: protocolo numerado + fin de los pánicos del hilo + tests V1.
- `crates/zx-node/src/nodo.rs`: ecos de `id`, evento `fallo_productor`, test del evento.
- `crates/zx-node/src/red/vista.rs`: dos `debug_assert!` convertidos en defensa sin pánico.
- `crates/zx-node/src/registro.rs`: `lock().unwrap()` convertido en error explícito.

`Cargo.toml`/`Cargo.lock`: **sin cambios**. `testdata/`: **sin cambios**.

## 8. Lo que no queda demostrado

- Las 5 repeticiones exigidas de V3 (una clave por nodo, los tres juntos) pasan con 0 pánicos y
  ≥200 bloques, pero **no** abrieron la ventana de carrera (`descartes = 0`): en esa configuración
  los tres nodos cruzan el corte sobre el mismo terminal y FC-3 no cambia de terminal durante la
  producción. La carrera se forzó en el escenario extra §6.1 (con partición y 3 claves por nodo), que
  sí produjo descartes reales. No se intentó reproducir bit a bit la intercalación exacta de W07b;
  la intercalación concreta que tumbaba al hilo se cubre de forma determinista en `tests_protocolo`.
- En `release` el perfil usa `panic = "abort"`: un `panic` interno residual abortaría el proceso
  antes de que `hilo.join()` pudiera detectarlo. La defensa de `join` (que escribe `fallo_productor`)
  es efectiva en `debug`/tests; en `release` la garantía es que no queda ningún pánico alcanzable
  (§3), y que los fallos irrecuperables del hilo se canalizan como `MsgProductor::Fallo`, no como
  pánico. No se cambió `panic = "abort"` (fuera del alcance de la orden).
- No se midió el coste de la numeración (un `u64` y un `cmp` por mensaje): es despreciable frente al
  PoT de ~1 s/slot y no era un objetivo de la orden.
- **Presupuesto de 2 h:** se superó en ~13 min. Motivo: la primera pasada de `clippy` detectó un
  `large_enum_variant` real en `Recepcion` (había que boxear el payload `Padres`) y el test completo
  se repitió sobre la fuente final. No se recortó ninguna verificación para intentar entrar en el
  límite.

## 9. Definiciones menores resueltas por el ejecutor (no hubo ninguna bloqueante)

La orden no fija algunos detalles que no cambian el resultado y que se resolvieron así:

- `MsgBucle::Parar` **no** lleva `id` (se atiende siempre, como pide la decisión 1); `Padres` y
  `Continuar` sí lo llevan.
- Campos del evento de diagnóstico `productor_respuesta_descartada`: `id_esperado` e `id_recibido`
  (los «ambos `id`» de la decisión 1); campo `motivo` en `fallo_productor`.
- V3: `N_dev` y `--semilla` por defecto (el `N_dev` del caso que falló en W07b), 230 slots por nodo
  (suficiente para ≥200 bloques con la tasa observada), `RAYON_NUM_THREADS=4` y `nice -n 19`.
- «≥ 200 bloques PoST» se cuenta como eventos `bloque_producido` (bloques propios admitidos); el
  bloque de transición no se cuenta (el nodo no lo registra como `bloque_producido`, W07a).

## 10. Empaquetado

- `cambios.patch`: `diff -ruN --exclude=target ws.orig ws` (incluye `testdata/` si cambiara; no
  cambia). Solo 4 archivos de `crates/zx-node/**`.
- `MIGRACION.sha256`: hashes de los 4 archivos cambiados, verificado con `sha256sum -c` en `ws/`.
- `HUELLAS.sha256`: hashes de `cambios.patch`, `HORAS.log`, `INFORME.md`, `MIGRACION.sha256` y
  `PROGRESO.md`.

