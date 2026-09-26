# INFORME — ORDEN-W06d4

**Ejecutor:** subagente Sonnet, único, sin subagentes. **Fecha:** 2026-09-26.
**Zona:** `/home/katana/zeo/ZEROX/deepseek/W06d4/`. **Entrada:** `ENTRADA-W06d4.sha256` verde al
empezar y al terminar.

## Veredicto

**SUPERADO PARCIALMENTE.** Las dos decisiones de código de la orden están implementadas,
diagnosticadas con evidencia (confirmando la hipótesis del director en la decisión 1/2), corregidas
y verificadas: la hipótesis del director (indicador local `depositada` no sensible a la rama) se
**confirma**; y la causa de `Pot(PasadoIncompleto)` (no resuelta en W06d3) se **encuentra y
corrige**. Suite completa: **723 pasan, 0 fallan, 2 ignorados** (721/0/2 antes — 2 tests nuevos, 0
perdidos). `fmt`/`clippy -D warnings --all-targets --all-features`/CI: verdes. **V4 (tres procesos
reales) SUPERADO** de forma limpia y sostenida (528+ bloques PoST, 0 rechazos, varios minutos). Lo
que no se cerró: **V5, V6(b) y V7** — cada uno con causa y evidencia registradas, ninguna de ellas
en el código de las decisiones 1/2 de esta orden. **V6(a) SUPERADO.**

## Tabla V1–V9 (adaptada a las decisiones de esta orden)

| Paso | Resultado |
|---|---|
| Decisión 1: causa del terminal que nunca se fija con 3 nodos | **CONFIRMADA** con evidencia: `depositada=true` se marcaba para cualquier bloque admitido (propio o ajeno, cualquier rama) que gastara la coinbase, sin comprobar si ese bloque seguía en la rama seleccionada. Test `nodo::pruebas_deposito_sensible_a_la_rama::preparar_depositos_vuelve_a_depositar_tras_perder_el_bloque_del_deposito`: falla antes del arreglo, pasa después |
| Decisión 2: corrección | `preparar_depositos` decide qué depositar leyendo directamente `estado.utxo`/`estado.garantias` de la punta seleccionada (`Cadena::estado_post`), sin ningún indicador local. `CoinbasePropia`/`Nodo.coinbases` eliminados |
| Decisión 3: `Pot(PasadoIncompleto)` | Causa encontrada: `ServicioPot::insertar_calculado` deja huecos a propósito (D-P10) cuando una rama salta a un slot posterior; el único camino para reconciliar un slot `<= slot_actual()` (`salida_de`) exigía una salida ya calculada y fallaba con `FueraDeVentana` para un hueco, dejando el bloque admitido en `Cadena` pero fuera de `pasado()` — causa directa de `PasadoIncompleto` en cualquier hijo. Corregido con `ServicioPot::declarar_salida_pasada` (rellena el hueco con un dato ya verificado; sigue detectando un conflicto real de D-P10). Test `zx_post::servicio_pot::pruebas::declarar_salida_pasada_rellena_un_hueco_dejado_por_otra_rama`: falla antes (vía `salida_de`), pasa después |
| V1 `fmt --check` | **OK** |
| V2 `clippy -D warnings --all-targets --all-features --locked` | **OK**, 0 errores (una corrida falló por `clippy::panic` en mi propio test nuevo — `panic!` dentro de `unwrap_or_else`, `nodo.rs:1845/1886` —, corregido con `#[expect(clippy::panic, ...)]` en el módulo de test, mismo patrón que el resto del workspace) |
| V3 `cargo test --workspace --all-features --locked` | **OK**: 723 pasan, 0 fallan, 2 ignorados (721/0/2 antes; +2 tests nuevos, 0 perdidos) |
| V9 `dependencias-exactas.sh`/`frontera-crates.sh`/lock | **OK**: 23 dependencias exactas; 9/9 fronteras; lock idéntico byte a byte a la raíz |
| V4 (3 procesos reales, ≥60 PoST, 0 rechazos) | **SUPERADO.** `EXITO_V4 total=69` a los ~35 s; dejado corriendo, llegó a **528 bloques PoST, 0 rechazos, 0 fatales**, los tres vivos varios minutos. Convergencia de `punta`/`resumen_estado` confirmada en 191/194 puntas comunes entre A y B (las 3 discrepancias, investigadas, son el estado *virtual* GHOSTDAG — depende del conjunto transitorio de puntas laterales conocidas, no una discrepancia de consenso; ver `PROGRESO.md`) |
| V5 (4.º proceso tardío sincroniza) | **NO SUPERADO.** El nodo D sincronizó correctamente (mismo par `punta`/`resumen_estado` que A/B/C en el mismo punto — prueba directa de que la decisión 3 funciona), pero murió con `ErrGarantia` fatal al intentar producir sin garantía propia (clave nueva, nunca depositó — límite arquitectónico: no hay depósito en fase PoST en este dev, y `main.rs` exige `Papel::Ambos` sin excepción). Cascada: A y B murieron segundos después con `Padres(SlotDePadrePosterior)` (un padre **extra** del *merge set* GHOSTDAG con slot adelantado, no cubierto por el filtro de `regimen.rs`, que solo mira el padre seleccionado). Dos hallazgos nuevos, con causa y evidencia, **fuera del alcance de las decisiones 1–3** |
| V6(a) (partición y reunión en fase PoW) | **SUPERADO.** A y B, con una sola clave cada uno, minaron aislados 20 s (33 bloques cada uno, 0 corte); C (tercera clave, puente) los reunió: corte cruzado, 52+ `cambio_punta`, `reorganizacion_pow` con profundidad en los tres, 0 fatales. 3 rechazos de red por `Pendiente→Rechazar`, simplificación ya declarada en W06d3, no nueva |
| V6(b) (partición y reunión en fase PoST, ≥20 slots) | **NO SUPERADO.** Partición de 137/141 bloques (bien por encima del mínimo); tras la reunión, B murió con `ErrMergeDepth` (RD-5, `F_SLOTS=600`). Causa: con `N_dev=2000` el `slot` (reloj PoT global) avanza muy rápido en tiempo real; los varios minutos reales de la sesión de pruebas hicieron que el `slot` más reciente superara en miles la ventana `F_SLOTS`. Calibración de la prueba, no bug de las decisiones 1–3 |
| V7 (`zx-adversario` contra un objetivo real) | **PARCIAL, no concluyente.** El objetivo nunca aceptó nada indebido ni se cayó; la intermitencia ya conocida de `zx-adversario` (publicación local antes de que la malla de gossipsub termine de formarse, ya diagnosticada en `W06d3`) impidió que la mayoría de los mensajes de la ráfaga E-7 llegaran de verdad a la red. Sí se observó una desconexión defensiva real tras la ráfaga |

## Decisión 1/2 — depósito sensible a la rama (hipótesis del director confirmada)

Ver `PROGRESO.md` para el detalle completo con líneas de código y razonamiento. Resumen: el
indicador local `CoinbasePropia.depositada` se marcaba para cualquier bloque admitido —propio o
ajeno, en cualquier rama— que gastara el `OutPoint` de la coinbase, sin comprobar si ese bloque
seguía en la rama seleccionada tras una reorganización FC-3. Con tres mineros reales compitiendo
antes del corte, las bifurcaciones son frecuentes: si el bloque del depósito queda descartado pero
la coinbase sigue viva en la rama nueva, el nodo nunca vuelve a depositar esa coinbase, y las
`K_min` claves con garantía activa que exige `Φ` nunca se reúnen — exactamente lo observado en
`REVISION-W06d3.md` (tres nodos minando 9 min hasta la altura ~290 sin fijar nunca el terminal).

Corrección: `preparar_depositos` (`crates/zx-node/src/nodo.rs`) decide qué depositar iterando
`estado.utxo` de la punta PoW **seleccionada** (`Cadena::estado_post`), filtrando por
`Origen::CoinbasePow`, `Lock::PubKey` propia y madurez por `entrada.creada.como_altura() + m_cb`.
Sensible a la rama por construcción: una coinbase gastada en una rama descartada vuelve a aparecer
en `estado.utxo` de cualquier rama que no la gastara, sin ninguna poda aparte.

## Decisión 3 — `Pot(PasadoIncompleto)`

Ver `PROGRESO.md` para el detalle completo. Resumen: `ServicioPot::insertar_calculado` permite (a
propósito, D-P10: flujo único compartido por todas las ramas) saltar directamente a un slot
posterior sin calcular los intermedios. Si el salto lo produce un bloque de otra rama, un slot
anterior que otra rama sí usó de verdad queda como hueco. `Nodo::actualizar_servicio_verificacion`
solo sabía reconciliar un slot `<= slot_actual()` con `salida_de`, que exige que el slot ya tenga
una salida calculada: con un hueco, fallaba con `FueraDeVentana` aunque el bloque trajera su
`pot_output` real ya verificado — el bloque quedaba admitido en `Cadena` (la mutación ya había
ocurrido) pero nunca entraba en `pasado()` del servicio de verificación del bucle principal, así que
cualquier hijo que lo declarase padre fallaba después con `Pot(PasadoIncompleto)`.

Corrección: nuevo método `ServicioPot::declarar_salida_pasada` (`crates/zx-post/src/servicio_pot.rs`)
que rellena el hueco con el dato ya verificado, o detecta un conflicto real (`ErrorServicioPot::
SalidaPasadaDiscrepante`) si ya había una salida **distinta** para ese slot (D-P10 sigue protegido).

## V4–V7 con procesos reales: hallazgos nuevos encontrados (no resueltos, fuera del alcance de las decisiones 1–3)

1. **`ErrGarantia` fatal en el primer bloque propio de un nodo sin garantía** (V5): una clave nueva
   que se incorpora después del corte, sin haber depositado nunca, intenta producir en cuanto gana
   una solución PoAS (no hay cheque de `activo >= q` antes de intentarlo) y su propio bloque se
   rechaza en la verificación — fatal, por la decisión 4 general de `ORDEN-W06d1`. Agravado porque
   `main.rs` exige `Papel::Ambos` sin excepción, así que no hay forma de unirse solo como
   sincronizador. Corrección natural (no aplicada): comprobar `activo_de(clave) >= q` antes de
   `producir_en_regimen` y abstenerse de esa clave en ese slot si no llega, igual que ya se descarta
   una candidata por `SlotNoProgreso`.
2. **`Padres(SlotDePadrePosterior)` fatal, cascada en A y B tras la llegada de un cuarto proceso**
   (V5): el filtro de `regimen.rs` (arreglo de `ORDEN-W06d3`) descarta un padre **seleccionado**
   demasiado avanzado, pero no cubre los padres **extra** del *merge set* GHOSTDAG; con más
   concurrencia (4 procesos en vez de 3) la ventana de carrera se hizo alcanzable. No determinado si
   D fue la causa directa o si es una ventana latente ya presente con 3 procesos.
3. **`ErrMergeDepth` tras una partición larga en fase PoST** (V6b): con `N_dev` pequeño el `slot`
   avanza muy rápido en tiempo real; una partición y sesión de pruebas de varios minutos hace que el
   `slot` más reciente supere `F_SLOTS = 600` respecto a un miembro del *merge set* que arrastraba
   desde antes. Calibración de la prueba, pero expone el mismo patrón que 1 y 2: un rechazo
   **legítimo** del protocolo, al ser de un bloque propio, tira abajo el proceso entero.
4. **Intermitencia ya conocida de `zx-adversario`** (V7): publicación local de gossip antes de que
   la malla termine de formarse, ya diagnosticada en `W06d3`, no nueva.

**Síntesis transversal de 1–3**: la política de decisión 4 de `ORDEN-W06d1` («bloque propio
rechazado ⇒ fatal») no distingue un bug interno de un rechazo legítimo del protocolo ante un caso de
borde real (garantía insuficiente, padre extra adelantado, fusión demasiado profunda). Con 3+
procesos reales sostenidos, estos casos de borde ocurren; cada uno tira abajo el proceso entero en
vez de descartar la candidata y seguir. Queda para un encargo futuro.

## Cambios a los crates, uno a uno

| Crate | Archivo | Motivo |
|---|---|---|
| `zx-node` | `src/nodo.rs` | Decisión 1/2: `preparar_depositos` reescrito sobre `estado.utxo`/`estado.garantias`; campo `coinbases`/rastro local eliminados; import `Origen` añadido. Decisión 3: `actualizar_servicio_verificacion` usa `declarar_salida_pasada`. Dos módulos de test nuevos |
| `zx-node` | `src/pow.rs` | Decisión 1/2: struct `CoinbasePropia` eliminada; `construir_deposito` cambia de firma (`txid_coinbase`, `valor_coinbase` en vez de `&CoinbasePropia`) |
| `zx-post` | `src/servicio_pot.rs` | Decisión 3: nuevo método `declarar_salida_pasada`, nueva variante `ErrorServicioPot::SalidaPasadaDiscrepante`, test nuevo |

Ningún cambio a `zx-consensus`, `zx-dag`, `zx-poas`, `zx-pot`, `zx-cadena`, `zx-farmer`, `zx-p2p`,
`zx-storage`. Fronteras de crate (V9) verificadas sin excepción.

## Faltas de definición encontradas (registradas en `PROGRESO.md` antes de editar)

Ninguna faltó definir para las decisiones 1–3: la orden y `REVISION-W06d3.md`/`PROGRESO.md` de
`W06d3` daban la hipótesis, el límite exacto y la línea aproximada de cada uno.

## No demostrado

- Que los hallazgos 1–3 de V4–V7 (arriba) agoten todas las condiciones bajo las que ocurren: se
  encontró la causa por lectura y se confirmó con evidencia de una corrida real, pero no se
  construyó un test unitario dirigido para cada uno (fuera de presupuesto, y fuera del alcance
  explícito de esta orden).
- V5 y V6(b) de punta a punta (bloqueados por los hallazgos 1/2 y 3 respectivamente).
- V7 concluyente (bloqueado por la intermitencia ya conocida de la propia herramienta).
- Que la convergencia de `resumen_estado` (estado virtual GHOSTDAG) sea idéntica en **todo**
  instante entre nodos: se demostró que `punta` (la seleccionada) sí converge siempre, y que
  `resumen_estado` converge en el 98%+ de los puntos comparados, con las discrepancias explicadas
  por el carácter transitorio del estado virtual, no por una reproducción exhaustiva de que nunca
  hay una discrepancia real de consenso.

## Rutas relevantes

- Informe: `/home/katana/zeo/ZEROX/deepseek/W06d4/INFORME.md` (este archivo).
- Progreso detallado, con las cuatro corridas V4–V7 completas y sus PIDs/comandos/logs:
  `/home/katana/zeo/ZEROX/deepseek/W06d4/PROGRESO.md`.
- Parche y huellas: `/home/katana/zeo/ZEROX/deepseek/W06d4/cambios.patch`,
  `/home/katana/zeo/ZEROX/deepseek/W06d4/MIGRACION.sha256` (generados como último paso).
- Horas: `/home/katana/zeo/ZEROX/deepseek/W06d4/HORAS.log`.
- Logs de V4–V7 reales: `/home/katana/zeo/ZEROX/deepseek/W06d4/run/` (`v4-intento1-{A,B,C}`,
  `v5-intento1-D`, y los directorios `A`/`B`/`C`/`C2` de V6/V7, con `stdout.log`/`stderr.log`/
  `registro.jsonl` de cada proceso) y `/home/katana/zeo/ZEROX/deepseek/W06d4/logs/` (suite
  completa, `fmt`, `clippy`, scripts de observación).
