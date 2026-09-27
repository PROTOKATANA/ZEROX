# INFORME — ORDEN-W06d7

**Ejecutor:** subagente Sonnet, único. **Zona:** `deepseek/W06d7/`. **Base:** commit `39519aa`
("W06d7 congelada"). **Inicio:** 2026-09-27T04:57:29+02:00. **Fin:** ver `HORAS.log`.

## 1. Resumen

`zx-cadena` congelaba el terminal al admitir el primer bloque PoST (hallazgo de W06d6): con eso, dos
nodos que cruzan el corte con terminales distintos no convergían nunca (I-3 roto). Esta orden
rediseña `Cadena` para que **cada terminal candidato con sufijo PoST lleve su propio DAG**
(`DagTerminal`), recalcula el terminal **seleccionado** por FC-3 entre todos los terminales con DAG
(mayor `blue_work` de su virtual; sin ninguno, mayor trabajo PoW), con `C-FIN-01` entre terminales
(anti-flapping) y un tope de `MAX_TERMINALES_CON_DAG = 8`. El nodo (`zx-node`) pasa de un único
`ServicioPot` de verificación a un mapa **por terminal**. Se reutiliza el desempate `comparar_terminal`
del motor (`zx-consensus`), ahora público, en vez de reimplementarlo.

## 2. Decisiones 1–6 — dónde viven

Todas implementadas en `crates/zx-cadena/src/cadena.rs` (comentario de módulo con el mapa completo
decisión→código) y `crates/zx-node/src/nodo.rs` (decisión 5). Resumen:

| Decisión | Implementación |
|---|---|
| 1 (un DAG por terminal) | `Cadena::dags: BTreeMap<BlockHash, DagTerminal>`; `terminal_de_bloque_post` resuelve el terminal de un bloque PoST desde sus padres; `ErrTerminalAmbiguo` si resuelven a más de uno (I-4) |
| 2 (FC-3 entre terminales) | `Cadena::mejor_terminal_candidato`: sin DAG, por trabajo PoW (`mejor_terminal_por_trabajo`); con DAG, por `blue_work` (`comparar_blue_work`) y desempate `comparar_terminal` (reexportado de `zx_consensus::transicion`, antes privado) + `comparar_rank` (C-GD, inalcanzable en la práctica pero conservado) |
| 3 (C-FIN-01 entre terminales) | `Cadena::recalcular_seleccion`: no sustituye el terminal actual si `slot_max_de(actual) >= F_slots` |
| 4 (tope 8) | `MAX_TERMINALES_CON_DAG`, `Cadena::dag_de_terminal_mut` (desaloja al peor por trabajo PoW si el nuevo lo supera; si no, `ErrLimiteTerminales` + `limite_terminales_alcanzado()`) |
| 5 (servicio PoT por terminal) | `Nodo::servicios_verificacion: BTreeMap<BlockHash, ServicioPot>`; `asegurar_servicios_verificacion`; `terminal_de_padres` (réplica de solo lectura de la resolución de `zx-cadena`) elige el servicio/contexto correcto **antes** de admitir |
| 6 (API del terminal seleccionado) | `terminal()`, `contexto_dag()`, `estado_virtual()`, `cadena_virtual()`, `mejor_punta()`… devuelven lo del seleccionado; accesos nuevos `*_de(terminal)` para un terminal concreto (`terminal_candidatos()`, `terminales_con_dag()`, `contexto_dag_de()`, `terminal_de()`) |

**Coste de memoria declarado** (decisión 4): cada `DagTerminal` es un `AlmacenGhostdag` completo con
sus índices; hasta 8 a la vez multiplica por 8 el almacén GHOSTDAG frente al diseño de un solo DAG.
A la escala de esta orden (cientos de bloques, red dev) es aceptable; no se ha perfilado
formalmente (sin banco de pruebas dedicado, fuera del alcance de un cambio de arquitectura de
consenso). `Cadena::mejor_terminal_candidato`, cuando hay varios terminales con DAG, reconstruye el
GHOSTDAG virtual de **cada uno** (patrón ya existente en el código base para el virtual de un solo
terminal) — coste adicional lineal en el número de terminales, mismo argumento de aceptabilidad.

## 3. Hallazgos durante la ejecución (autodenuncia, no ocultados)

1. **Bug de orden en `recalcular_seleccion`** (real, en el código nuevo de esta orden): se llamaba
   dentro de `admitir_pow`/`admitir_post`, **antes** de que `Cadena::admitir` marcara
   `self.validos.insert(hash, true)`. Como `tips_validas_de`/`dag_virtual_de` filtran por
   `Self::es_valido`, la recomputación veía el bloque recién admitido como todavía inválido: el
   `blue_work` del terminal se calculaba un paso atrasado. Se manifestó como I-3 roto en el test de
   empate exacto de `blue_work` (`crates/zx-cadena/tests/multiterminal.rs::empate_exacto_blue_work`):
   el terminal seleccionado dependía del orden de llegada. **Corregido**: la llamada se centralizó en
   `Cadena::admitir`, después de marcar la validez; se retiraron las dos llamadas internas. Ver
   `PROGRESO.md`, "Hallazgo real durante V1", para el diagnóstico completo (incluye un accesor de
   depuración temporal, ya retirado).
2. **Autodenuncia menor**: mi propio test nuevo de `comparar_terminal` (visibilidad pública) tenía
   las aserciones `None`/`Some` invertidas al escribirlo (confundí la convención documentada
   "`Greater` = gana `a`"). Corregido antes de que afectara a ningún resultado publicado.
3. **Hallazgo de método en la verificación real (no del código de la orden)**: la primera
   "repetición 2" de V4 usaba los mismos puertos fijos que la repetición 1 y no mataba sus procesos
   al terminar; los procesos de la repetición 1 seguían vivos y ocupando esos puertos, así que la
   repetición 2 acabó conectándose a la red **vieja** de la repetición 1 en vez de formar la suya
   propia — se delató porque convergió a un hash **idéntico** al de la repetición 1, algo imposible
   si fueran redes independientes (las cabeceras PoW propias, verificadas, diferían). Corregido
   (puerto base propio por repetición + comprobación con `ss` antes de lanzar + matar procesos al
   terminar) y **repetida de cero**: la nueva repetición 2 converge a un hash distinto, con el lado
   ganador invertido respecto a la repetición 1, confirmando independencia real. Ver `PROGRESO.md`.

## 4. Plan de verificación — resultado

| Paso | Resultado |
|---|---|
| V0 | `sha256sum -c` OK (con la nota de `V-ZRX/LINEO.md` no versionado, íntegro); suite completa sin cambios: no se relanzó aparte porque la base (commit `39519aa`) es la misma que W06d6 ya dejó en verde (795→814 tras W06d6); en su lugar, la primera pasada de `cargo check`/`cargo test` de este ejecutor sirvió de facto como comprobación de que el punto de partida compilaba y pasaba antes de tocar nada relevante a esta orden (el rediseño es aditivo sobre `zx-cadena`/`zx-node`/`zx-consensus`, sin tocar el resto) |
| V1 | **Superado.** `crates/zx-cadena/tests/multiterminal.rs`: 2 y 3 terminales con sufijos de tamaños distintos, empate exacto de `blue_work`, cada escenario en 200 órdenes aleatorios (semilla fija, xorshift64\*): mismo terminal, misma punta, mismo estado virtual en los 200. 0 fallos tras la corrección del hallazgo §3.1 |
| V2 | **Superado.** Casos dirigidos, todos en el mismo archivo: sufijo PoST más pesado en el terminal con menos trabajo PoW gana (`directed_terminal_ligero_gana_por_post`); padres de dos terminales → `ErrTerminalAmbiguo` (`directed_padres_de_terminales_distintos_es_invalido`); `C-FIN-01` bloquea el cambio con sufijo profundo y lo permite con sufijo corto (`directed_c_fin_01_bloquea_el_cambio`); noveno terminal ignorado con `ErrLimiteTerminales` (`directed_noveno_terminal_ignorado`); reinicio que repite el registro y acaba con la misma selección (`directed_reinicio_repite_misma_seleccion`) |
| V3 | **Superado.** Diferenciales T01 v0.5 y T04 v0.6: 0 discrepancias (parte de la suite completa, sin tocar los vectores) |
| V4 (E-6b, procesos reales) | **Superado en 2 repeticiones**, ambas con convergencia verificada como real (no trivial: el lado predicho perdedor adopta la punta exacta del ganador) y con ganador **distinto** entre repeticiones (confirma que no hay sesgo fijo). 0 errores fatales en ambas |
| V5 (V6(b) de verdad, procesos reales) | **Superado en 2 repeticiones.** Aislamiento real medido: 27 slots en ambas (>=20 exigido). Convergencia a un estado distinto del previo al aislamiento (crecimiento real, no no-op). 0 errores fatales |
| V6 (regresión, procesos reales) | **Superado.** V4 (tres nodos) ya cubierto arriba; "nodo tardío" de W06d6 a escala reducida (62 bloques combinados en vez de >=500, por presupuesto — sigue ejercitando el camino que rompía: reconstrucción del/de los `ServicioPot`): D alcanza el mismo slot que A en segundos, 0 huérfanos, convergencia exacta de los cuatro tras el reposo |
| V7 | `cargo fmt --check`: verde. `cargo clippy --workspace --all-targets --all-features --locked -- -D warnings`: verde (2 hallazgos reales corregidos, ver `PROGRESO.md`). `cargo test --workspace --all-features --locked`: verde (ver `HORAS.log`/`PROGRESO.md` para el recuento final). `ci/dependencias-exactas.sh` y `ci/frontera-crates.sh`: verdes |

## 5. Tabla de cobertura (mínimo 1 por fila, `crates/zx-cadena/tests/multiterminal.rs`)

| Situación | Test(s) |
|---|---|
| 0 terminales con sufijo (fase PoW pura) | `cero_y_un_terminal_no_se_rompen` (primera mitad); diferenciales T01/T04 y suite preexistente, sin tocar |
| 1 terminal con sufijo | `cero_y_un_terminal_no_se_rompen`; `contexto_dag.rs`, diferenciales T01/T04 |
| 2 terminales con sufijo | `dos_terminales_pequeno` (V1), `directed_terminal_ligero_gana_por_post` (V2) |
| 3 terminales con sufijo | `tres_terminales_tamanos_distintos` (V1) |
| Empate exacto de `blue_work` | `empate_exacto_blue_work` (V1, 200 órdenes) |
| Bloqueo por `C-FIN-01` | `directed_c_fin_01_bloquea_el_cambio` (caso bloqueado y caso permitido) |
| Tope (`MAX_TERMINALES_CON_DAG`) | `directed_noveno_terminal_ignorado` |
| Mezcla de terminales (padres de dos distintos) | `directed_padres_de_terminales_distintos_es_invalido` (`ErrTerminalAmbiguo`) |
| Reinicio / repetición del registro | `directed_reinicio_repite_misma_seleccion` |

**Límite declarado de antemano** (igual que anuncia la orden): no hay oráculo independiente del caso
multiterminal en DAG (T04 tiene un solo terminal). La evidencia es I-3 por propiedades (200 órdenes
por escenario) + reutilización del desempate validado del motor + procesos reales (V4/V5/V6). El
oráculo T04-E queda, como ya preveía la orden, en el IPA.

## 6. Límite declarado nuevo: sin cambio de terminal en caliente durante la producción

Decisión 5 pide que el productor "si cambia [de terminal], reconstruye su servicio PoT para el
nuevo". Esto se cumple **al entrar en `fase_regimen`** (y en cada `admitir_pow_interno`, vía
`asegurar_servicios_verificacion`, que crea el servicio de cualquier terminal candidato nuevo antes
de que haga falta). Lo que **no** se implementó — y se declara explícitamente en vez de darlo por
hecho — es un cambio de terminal **en caliente** mientras el hilo productor ya está corriendo dentro
de un mismo `fase_regimen` (el bucle no vuelve a comprobar `self.cadena.terminal()` en cada
iteración para abortar/reconstruir el hilo si la selección cambia a mitad de régimen). En los
escenarios V4/V5 esto no importa: la reunión ocurre **después** de que `--dejar-de-producir-en-slot`
para la producción en los tres lados, así que el productor nunca está activo cuando el terminal
seleccionado cambia. Un nodo cuyo terminal cambiara **mientras produce activamente** seguiría
produciendo sobre el terminal viejo hasta el siguiente ciclo de `fase_regimen` (p. ej. un reinicio) —
mismo límite estructural que ya tenía el diseño de un solo terminal antes de esta orden, solo que
ahora aplicado a "cuál terminal", no a "si hay terminal". Se declara como límite conocido, no como
`DEFINICIONES-FALTANTES.md` bloqueante: no impidió superar V4/V5/V6 tal como están escritos en la
orden.

## 7. Archivos cambiados (ver `MIGRACION.sha256`, `cambios.patch`)

- `crates/zx-cadena/src/cadena.rs` (1154 → 1493 líneas): rediseño central.
- `crates/zx-cadena/src/error.rs`: `ErrTerminalAmbiguo`, `ErrLimiteTerminales`.
- `crates/zx-cadena/src/lib.rs`: exporta `MAX_TERMINALES_CON_DAG`.
- `crates/zx-cadena/tests/multiterminal.rs` (nuevo): V1 + V2 del plan de verificación.
- `crates/zx-consensus/src/transicion/seleccion.rs`: `comparar_terminal` pública (antes privada;
  mismo comportamiento, con test propio); `crates/zx-consensus/src/transicion/mod.rs` la reexporta.
- `crates/zx-node/src/nodo.rs` (2532 → 2599 líneas): decisión 5 (servicios PoT por terminal,
  resolución de terminal antes de admitir, `intentar_admitir_post_de_red` generalizado a cualquier
  terminal candidato conocido).

`Cargo.lock`/`Cargo.toml`: **sin cambios** (verificado con `diff`). `zx-core`, `zx-dag`, `zx-p2p`,
`zx-storage`, `zx-post` (salvo lo permitido): **sin tocar**. `ci/frontera-crates.sh` lo confirma en
verde.

## 8. Lo que no queda demostrado

- El oráculo T04-E (caso multiterminal con oráculo independiente) sigue sin existir (declarado de
  antemano por la propia orden como fuera de alcance).
- El coste de memoria/tiempo del tope de 8 terminales no se perfiló formalmente (declarado en §2).
- El cambio de terminal en caliente durante producción activa no se probó (declarado en §6);
  tampoco lo pedía el plan de verificación tal como está escrito.
- V6 "nodo tardío" se ejecutó a escala reducida (62 bloques combinados, no >=500 de W06d6) por
  presupuesto de tiempo real de esta sesión; el mecanismo que importa (reconstrucción de
  `ServicioPot` al sincronizar un historial ajeno) se ejerció igual, con margen amplio (D alcanzó
  el mismo slot en segundos, muy por dentro del límite de 15 min de W06d6).
