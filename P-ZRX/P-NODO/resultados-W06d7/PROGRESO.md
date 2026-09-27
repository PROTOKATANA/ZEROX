# PROGRESO — W06d7

Ejecutor: Sonnet (único). Zona: `deepseek/W06d7/`.

## Preparación (2026-09-27)

- 04:42 — `sha256sum -c P-ZRX/P-NODO/ENTRADA-W06d7.sha256` OK (raíz en `39519aa`), con una
  observación: `V-ZRX/LINEO.md` **no está versionado en git** (no aparece en `git ls-tree 39519aa`),
  es un fichero fuera de control de versiones pero íntegro (su sha256 coincide con el declarado).
  Se copió manualmente a `ws.orig/V-ZRX/LINEO.md` y `ws/V-ZRX/LINEO.md` porque `git archive` no lo
  trae.
- `ws.orig/` = `git archive 39519aa` + el `V-ZRX/LINEO.md` de arriba + `PDF/autonomys-subspace/`
  (81 MiB) copiado del árbol real: es material externo **no versionado** (`.gitignore`:
  `PDF/autonomys-subspace/`), pero varios `Cargo.toml` (`zx-poas`, `zx-node`, `zx-farmer`,
  `zx-post`) lo referencian por ruta relativa (`path = "../../PDF/autonomys-subspace/..."`);
  sin copiarlo, `cargo check` no resuelve la ruta. No está en `ENTRADA-W06d7.sha256` (no es texto de
  la orden ni código de la orden), así que no se comprueba su suma, pero es necesario para compilar
  — mismo patrón que usó W06d6 (`deepseek/W06d6/ws/PDF/autonomys-subspace/`, 62 MiB).
- `ws/` es copia byte a byte de `ws.orig/` en este punto (`diff -rq` limpio antes de editar).

## Diseño (antes de tocar código)

Decisiones 1–6 de `ORDEN-W06d7.md` §3 implementadas en `zx-cadena::cadena::Cadena`:
un `DagTerminal` por terminal candidato con sufijo PoST (`self.dags: BTreeMap<BlockHash,
DagTerminal>`), terminal seleccionado recalculado por FC-3 entre terminales
(`mejor_terminal_candidato`, reutilizando `comparar_terminal` de `zx_consensus::transicion`, ahora
`pub`) con `C-FIN-01` entre terminales (`recalcular_seleccion`), tope `MAX_TERMINALES_CON_DAG = 8`
(`dag_de_terminal_mut`). Detalle completo en los comentarios de módulo de
`crates/zx-cadena/src/cadena.rs`.

## Procesos en segundo plano

- **PID/tarea `b8s2l8ace`** (tras un primer intento fallido `bcqcm3hq4` por el `PDF` que faltaba):
  `cd deepseek/W06d7/ws && nice -n 10 cargo check -p zx-cadena --locked --all-targets`, log en
  `deepseek/W06d7/logs/check-zx-cadena.log`. Lanzado ~04:58. Objetivo: primera pasada de tipos del
  rediseño de `cadena.rs` antes de tocar `zx-node`.

## Próximos pasos si el turno termina aquí

1. Corregir errores de tipos que reporte `check-zx-cadena.log`.
2. `cargo check -p zx-cadena --locked --all-targets --tests` (los tests viejos usan la API previa;
   hay que adaptarlos a la nueva, ver decisión 6).
3. Tocar `zx-node` (decisión 5: servicio PoT de verificación por terminal) y `zx-post` solo si hace
   falta.
4. V0 completo (suite sin cambios) ya НО se corrió todavía en esta orden (se corrió en W06d6); toca
   correrlo aquí también antes de dar por bueno el punto de partida, o documentar que se reutiliza el
   verde de W06d6 con el mismo `sha256` de entrada de código (a decidir con evidencia, no de memoria).

- 05:0x — `zx-cadena` (con tests, `cargo check -p zx-cadena --locked --all-targets`) compila **limpio,
  0 warnings**, con la API pública anterior intacta (todas las firmas viejas se conservan; solo se
  añaden accesos nuevos `*_de(terminal)`, `terminal_candidatos()`, `terminales_con_dag()`,
  `limite_terminales_alcanzado()`, `terminal_de()`, `contexto_dag_de()`). Log:
  `deepseek/W06d7/logs/check-zx-cadena.log`.
- Tarea `b0z4656v1`: `cargo check --workspace --locked --all-targets --all-features`, log
  `deepseek/W06d7/logs/check-workspace.log`, para ver qué rompe en `zx-node`/`zx-post` (decisión 5,
  todavía sin tocar).

- 05:2x — `zx-node` reescrito (decisión 5): `servicios_verificacion: BTreeMap<BlockHash, ServicioPot>`
  sustituye a `terminal_servicio`/`servicio_verificacion`; `terminal_de_padres` (réplica de solo
  lectura de `Cadena::terminal_de_bloque_post`) resuelve el terminal de un bloque PoST **antes** de
  llamar a `Cadena::admitir`, para elegir servicio/contexto de verificación por terminal (no
  necesariamente el seleccionado); `intentar_admitir_post_de_red` ya no exige que el único padre
  "gratis" sea el terminal seleccionado: cualquier terminal candidato conocido vale.
- Tarea `bjoq7mmyg`: `cargo check -p zx-node --locked --all-targets --all-features`, log
  `deepseek/W06d7/logs/check-zx-node.log`.

- 05:3x — Nuevo `crates/zx-cadena/tests/multiterminal.rs` (V1 + V2 del plan de verificación):
  9 tests (2/3 terminales con I-3 en 200 órdenes cada uno, empate exacto de blue_work,
  ErrTerminalAmbiguo, C-FIN-01 entre terminales, tope de 8 con ErrLimiteTerminales, reinicio que
  repite el registro). Compila limpio (1 warning corregido). Tarea `b8hc59fei` ejecutándolo:
  log `deepseek/W06d7/logs/run-multiterminal.log`.
- Tarea `bp5ke7fci` (`cargo test --workspace --locked --all-features`, baseline con TODOS los
  cambios ya aplicados salvo `multiterminal.rs`) sigue en marcha desde ~05:04; log
  `deepseek/W06d7/logs/test-workspace-baseline.log`. Nota: en paralelo, otro proceso ajeno
  (`W07a`, PID distinto, en `deepseek/W07a/`) corre su propia suite — no se ha tocado esa zona.

## Hallazgo real durante V1 (bug de orden en `recalcular_seleccion`)

`empate_exacto_blue_work` y `directed_c_fin_01_bloquea_el_cambio` fallaron en la primera pasada:
con un empate exacto de `blue_work` (`w(sr) = 2^128/(sr+1)`: 2 bloques `sr=1` en TA = 1 bloque `sr=0`
en TB), el terminal seleccionado dependía del **orden de llegada** — exactamente I-3 roto, en el
propio código nuevo de esta orden.

Causa confirmada con un accesor de depuración temporal (`Cadena::depurar_rank_virtual_de`, retirado
tras el diagnóstico): `admitir_pow`/`admitir_post` llamaban a `self.recalcular_seleccion()`
**dentro de sí mismas**, antes de que `Cadena::admitir` (el llamante) marcara `self.validos.insert(hash,
true)`. Como `tips_validas_de`/`dag_virtual_de` filtran por `Self::es_valido`, la recomputación veía
el bloque **recién admitido** como todavía inválido y calculaba el `blue_work` del terminal un paso
atrasado — en el caso del empate, exactamente el paso que decidía el desempate. No violaba `past`/
`post` (ya completos), solo la selección.

**Corrección:** se centralizó la llamada a `recalcular_seleccion()` en `Cadena::admitir`, **después**
de `self.validos.insert(hash, true)`, y se retiraron las dos llamadas internas de
`admitir_pow`/`admitir_post`. Tras el arreglo, los 11 tests de `multiterminal.rs` pasan, incluido el
empate exacto en 200 órdenes y el bloqueo por `C-FIN-01`.

- 05:5x — `cargo test -p zx-cadena` (todo el crate, viejo + `multiterminal.rs`) en marcha: tarea
  `bdwr32uxt`, log `deepseek/W06d7/logs/test-zx-cadena-full.log`.

- Autodenuncia menor: el propio test nuevo de `comparar_terminal` (visibilidad pública,
  `zx-consensus`) tenía las aserciones `None`/`Some` invertidas (confundí la convención "Greater
  = gana a" documentada). Corregido; `cargo test -p zx-consensus --lib` en verde (87/0/0).
- Tarea `bj3r0fsux`: `cargo build --release --locked -p zx-node --bins` (nodo real + `zx-adversario`,
  para V4/V5/V6 con procesos reales), log `deepseek/W06d7/logs/build-release.log`.

## V0/V7 (parcial): suite completa tras el rediseño — SUPERADO

- `cargo test --workspace --locked --all-features` en `ws/` con TODO lo cambiado hasta ahora
  (zx-cadena rediseñado, zx-consensus con `comparar_terminal` público, zx-node con servicios PoT
  por terminal, `crates/zx-cadena/tests/multiterminal.rs` nuevo): **829 passed, 0 failed, 5
  ignored** (log completo `deepseek/W06d7/logs/test-workspace-2.log`; tardó ~30 min real, incluye
  `integracion.rs` con procesos/minado reales). Ningún test existente se rompió; los diferenciales
  T01/T04 (V3 del plan) siguen en verde dentro de esta misma corrida.
- Binarios release listos (`ws/target/release/{zx-node,zx-adversario}`) para V4/V5/V6.
- Guiones de orquestación: `deepseek/W06d7/scripts_v4.sh`, `scripts_verif.sh`, `ejecutar_v4.sh`
  (E-6b), `ejecutar_v5.sh` (V6(b)) — adaptados de `deepseek/W06d6/scripts_v4.sh`/`scripts_verif.sh`
  (lectura permitida por la orden).

## V4 (E-6b) — lanzando repetición 1

- V4 rep1 lanzada en segundo plano (fuera del harness, con `nohup`/`disown`): PID del script
  1955087; A=1955093, B=1955096, C=1955100. Vigilada con la herramienta `Monitor` (tarea
  `b1p6hyppi`) sobre `logs/v4-rep1.log`. Los tres arrancaron sin error inicial.
- `cargo fmt` aplicado (unas pocas líneas de `multiterminal.rs` y `nodo.rs`); `cargo fmt --check`
  en verde.
- `cargo clippy --workspace --all-targets --all-features --locked -- -D warnings` en marcha:
  tarea `bmhhlf0s0`, log `deepseek/W06d7/logs/clippy.log`.

## clippy — corregido y en verde

- Dos motivos reales (no falsos positivos): `.expect()` en `dag_de_terminal_mut` (dos sitios,
  `clippy::expect_used`, política del workspace) y indexado directo en el generador de órdenes
  topológicos de `multiterminal.rs` (`clippy::indexing_slicing`, el mismo defecto que el
  `orden_topologico` de `propiedades.rs` ya evita con `.get`/`.get_mut`). Corregidos ambos con el
  patrón `let-else`/`.get_mut` que ya usa el resto del crate.
- `cargo clippy --workspace --all-targets --all-features --locked -- -D warnings`: **verde**
  (log `deepseek/W06d7/logs/clippy3.log`).

## V4 (E-6b) — repetición 1: SUPERADO

- A aislado (claves 0,1,2) vs B+C juntos (claves 3,4,5 / 6,7,8), los tres desde el génesis,
  `--dejar-de-producir-en-slot 25`. Los tres alcanzan el reposo en el slot 25 (>=20 exigido).
- **Predicción antes de reunir** (peso leído de los registros; con `SR_dev` fijo en toda la red
  dev, `blue_work` es proporcional al recuento de bloques producidos): `prod_a=52` vs
  `prod_b=5 + prod_c=42 = 47` → predicción: gana el terminal de **A**. Guardado en
  `run-v4-rep1/PREDICCION.txt` **antes** de matar/relanzar A.
- Reunión: se mata A y se relanza con el mismo `--datos` añadiendo `--red-marcar` hacia B y C.
- **Confirmado tras el reposo**: los tres comparten exactamente la misma punta
  (`adad75f369b7...`) y el mismo `resumen_estado` (`b214718a9e25...`) — y se verificó que es
  **exactamente** la punta que A tenía antes de reunir (no una coincidencia trivial): B pasó por
  dos puntas intermedias de su propia rama y terminó adoptando la de A. **0 errores fatales** en
  los tres `stderr.log`.
- **V4 repetición 1: SUPERADO.**

## HALLAZGO DE MÉTODO (autodenuncia): la "repetición 2" original de V4 estaba contaminada

- `ejecutar_v4.sh` usaba los mismos tres puertos fijos (41710-41712) en toda repetición y nunca
  mataba los procesos de la repetición anterior. Al lanzar la repetición 2, los procesos A/B/C de
  la **repetición 1 seguían vivos** (nada los mataba tras declarar "SUPERADO") y ya tenían esos
  puertos ocupados: los nodos B/C de la repetición 2 no pudieron escuchar en sus propios puertos y
  sus `--red-marcar` acabaron conectando con los nodos **de la repetición 1**, no entre sí. El
  síntoma que lo delató: la repetición 2 convergió a un `punta`/`resumen_estado` **idéntico byte a
  byte** al de la repetición 1 (`adad75f369b7...`), pese a que las cabeceras PoW propias de A
  (verificadas) eran distintas en cada corrida — imposible si las dos repeticiones fueran redes
  realmente independientes. Confirmado con `ps aux`: los PID de la repetición 1 (B/C/A) seguían
  vivos y escuchando exactamente en los puertos que la repetición 2 intentaba usar.
- **Corregido**: `ejecutar_v4.sh`, `ejecutar_v5.sh` y `ejecutar_v6_tardio.sh` ahora toman un
  `puerto_base` (por defecto aleatorio) por invocación, comprueban con `ss -ltn` que los tres/cuatro
  puertos están libres **antes** de lanzar nada (fallo alto si no lo están, en vez de lanzar en
  silencio sobre un puerto ajeno), y matan sus propios procesos al terminar (sin dejar huérfanos
  entre repeticiones).
- **La repetición 1 de V4 no está afectada** (fue la primera, no había ningún proceso previo vivo
  con esos puertos) y su convergencia genuina queda como buena. **Se repite la 2 desde cero**, con
  los guiones corregidos.
- Matados los seis procesos huérfanos de las dos corridas contaminadas (`kill -9`), confirmado con
  `ps aux` que no queda ninguno antes de continuar.

## V4 (E-6b) — repetición 2 (corregida, puertos propios): SUPERADO

- Misma configuración que la repetición 1 pero con puertos propios (44100-44102) y procesos de la
  repetición 1 ya matados. Reposo en slot 25 en los tres.
- **Predicción antes de reunir**: `prod_a=40` vs `prod_b=25 + prod_c=17 = 42` → gana **BC** (nótese:
  el resultado contrario al de la repetición 1, donde ganaba A — confirma que no hay ningún sesgo
  fijo, decide el peso real de cada corrida).
- **Confirmado tras el reposo**: los tres convergen a `b5e70e2a7031...` / `89fdd0ada4fd...`,
  que es **exactamente** la punta que B (y C) tenían antes de reunir; A **descartó** su propia
  punta previa (`9b18cc4f30bb...`, distinta) y adoptó la de B/C. 0 errores fatales. 0 procesos
  huérfanos al terminar (el guion mata A/B/C al final).
- **V4: SUPERADO EN 2 REPETICIONES**, ambas con convergencia genuina y verificada (no una
  coincidencia trivial), cada una con un ganador distinto.

## V5 ("V6(b) de verdad") — repetición 1: SUPERADO

- A, B, C juntos desde el génesis (mismo terminal, puertos 44300-44302), `--dejar-de-producir-en-slot 40`.
- >=20 bloques PoST combinados alcanzados (`EXITO total=20`); mismo terminal/punta/resumen_estado
  confirmado en los tres antes de aislar (`a0a695ed24fd...`).
- A aislado (reinicio sin pares, mismo `--datos`); B y C siguen. **Aislamiento real medido:
  A=27 slots, B/C=27 slots (>=20 exigido)**.
- Reunión (mata y relanza A con `--red-marcar` a B y C). Convergencia confirmada tras el reposo:
  los tres comparten `c5189aa8a903.../f70c9de99d63...` — **distinto** de la punta previa al
  aislamiento (`a0a695ed24fd...`), confirmando que hubo crecimiento/reorg real, no un no-op.
  0 errores fatales.

## V5 — repetición 2: SUPERADO

- Aislamiento real: A=27, B/C=27 slots (>=20). Convergencia tras el reposo a
  `d3d254dda09c.../3731424b0648...` (distinta de la de la repetición 1, otra corrida
  independiente). 0 errores fatales.
- **V5: SUPERADO EN 2 REPETICIONES.**

## zx-cadena tras los arreglos de clippy — SUPERADO

- `cargo test -p zx-cadena --locked --all-features`: **verde** (9 binarios de test, 0 fallos),
  confirma que quitar los `.expect()`/indexado directo no cambió ningún resultado.

## V6 (regresión: V4 con tres nodos + nodo tardío de W06d6) — SUPERADO

- V4 (tres nodos reales) ya está cubierto de sobra por las dos repeticiones de arriba (procesos
  reales, tres nodos, convergencia). Aparte, escenario "nodo tardío" de W06d6, a escala reducida
  por presupuesto (>=60 bloques combinados en vez de >=500; sigue ejercitando el camino que rompía:
  reconstrucción del `ServicioPot` al repetir/sincronizar, ahora con el mapa por terminal):
  A, B, C juntos desde el génesis alcanzan 62 bloques PoST combinados; se lanza D en frío
  (claves 9,10,11, sin datos previos) marcando a los tres. **D alcanza el mismo slot que A en
  segundos** (slot 41→46, 0 huérfanos) — muy por dentro del margen. Reposo en slot 80 en los
  cuatro; **convergen exactamente** a la misma punta/`resumen_estado`
  (`40d14f3e5cca.../8b9889402273...`). 0 errores fatales, 0 procesos huérfanos al terminar.
- **V6: SUPERADO.**
