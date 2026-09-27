# INFORME — W07b: mediciones reales de 0.0.1 (E-1…E-9)

**Fecha:** 2026-09-27. **Ejecutor:** subagente Sonnet, único (sin subagentes ni forks, según lo
exige la orden). **Orden:** `P-ZRX/P-MEDICION/ORDEN-W07b.md`. **Zona:**
`/home/katana/zeo/ZEROX/deepseek/W07b/`.

**Alcance honesto (repetido de `ESCENARIOS-0.0.1.md`):** procesos reales en `127.0.0.1`, un solo
reloj de la misma máquina, sin latencia de red real salvo la de un `localhost` real. Ningún
resultado se extrapola a producción ni a una red pública adversarial.

## 0. Resumen ejecutivo

- **E-0** (CI completa desde clon limpio): **SUPERADO** en los tres commits candidatos que se
  sucedieron durante la orden (`27dcfeb`, `26312ff`, `3d21b1f` — el último es el definitivo).
- **E-1, E-2, E-3, E-4** (R1, commit `26312ff`, 3 repeticiones): **SUPERADOS** en las 3.
- **E-5** (R2, commit `26312ff`, 3 repeticiones, nodo tardío): **SUPERADO** en las 3.
- **E-6** (R3, commit `3d21b1f`, 3 repeticiones, partición en fase PoST): **SUPERADO** en las 3.
- **E-6b** (R3, commit `3d21b1f`, 3 repeticiones, partición en fase PoW cerca del corte):
  **SUPERADO** en las 3, tras corregir un fallo de mi arnés que lo hacía estructuralmente
  imposible (ver §5.3).
- **E-7** (R4, commit `3d21b1f`, 3 repeticiones, entradas inválidas): **SUPERADO en el rechazo y
  la ausencia de cambio de estado**; la penalización de pares (`par_penalizado`/`limite_alcanzado`)
  **no se observó en ningún registro** — ver §5.6, hallazgo no resuelto a mi favor.
- **E-8** (R4, 3 repeticiones, doble firma con castigo activo): **SUPERADO** en las 3 (evidencia
  detectada e incluida, confiscación, mismo estado final verificado).
- **E-9** (R4, 3 repeticiones, retención del terminal): **descriptivo**, sin criterio de
  éxito/fracaso (`A-07` abierto); se reporta qué ocurrió en las 3.
- **Presupuesto de 8 h de reloj (`ORDEN-W07b.md` §5): SUPERADO** — la medición completa tardó
  ≈11 h de reloj (inicio `10:45:11`, fin de la CI final `21:31:18`, más el tiempo de escribir este
  informe). Declarado en `PROGRESO.md` en cuanto lo detecté, no al final.
- Tres candidatos de commit se sucedieron durante la orden porque aparecieron dos fallos reales
  del producto (no del arnés): un panic del hilo productor (`regimen.rs:438`, corregido por
  W06d8 → `26312ff`) y un fallo del productor por pérdida del portador PoT de la justificación
  (corregido por W06d9 → `3d21b1f`, commit definitivo). Ambos se dejan documentados como hallazgos
  reales, con la evidencia cruda conservada.

## 1. E-0: receta desde un clon limpio

Procedimiento exacto y resultado completo en `RECETA.md` (§1-§8). Tres pasadas de la CI local
completa (`cargo fmt`, `cargo clippy -D warnings`, `cargo build`/`test --workspace --all-features
--locked`, los tres guardianes de `ci/`, y `cargo build --release --locked -p zx-node`), una por
cada commit candidato:

| Commit | Motivo del candidato | E-0 | sha256 zx-node |
|---|---|---|---|
| `27dcfeb09e7e0a105c5c55a94766621b99fbfc57` | primer candidato de la orden | SUPERADO (2026-09-27T11:29) | `a9f0ffa1b42e3c7c3eaea0ba6a87a20f9a46dfd2118a3b761f4a26be58bf19e1` |
| `26312ffee1b9fd1aa74b1323e087caa1d64a5a77` | W06d8: corrige panic de `regimen.rs:438` | SUPERADO (2026-09-27T15:19) | `70b0cf2d521c5cbd1bdebd12bb47381c772a498c496861dd77e83d5911cddc01` |
| `3d21b1f44301991fb59737e2117cc26a66a4e93f` | W06d9: corrige fallo del productor por portador PoT no retenido | SUPERADO (2026-09-27T21:31, commit **definitivo**) | `e7ef7f19a701188237e38266f5d6361c16228620fcf4039e5a67d3b2339900de` |

`zx-adversario` no cambió de hash (`a8bcc9d09cf8d891b84212d367243885fc4e900777cec27e7ebecc0d6b906c38`)
en ningún commit: ninguno de los tres tocó ese binario.

R1 y R2 se midieron con `26312ff`. R3 y R4 se midieron con `3d21b1f` (el binario release se
construyó antes que la CI completa, para no bloquear la medición; la CI completa sobre el mismo
árbol se hizo al final y dio los mismos hashes de binario que ya estaban en uso — sin drift).

## 2. Calibración de `SR_dev` (E-2a, precondición del arnés)

Bisección logarítmica, ventanas de 200×τ segundos por punto (τ medido empíricamente porque a
`SR_dev` bajo no se producen bloques suficientes para usar el slot como proxy). τ medido =
**1.281552 s/slot** (con 3 nodos reales concurrentes en esta máquina; el perfil nominal es 1 s).

| punto | exponente | `SR_dev` | bloques/slot medidos |
|---|---|---|---|
| 1 | 60 | 1152921504606846976 | 0.2335 |
| 2 | 62 | 4611686018427387904 | 0.6507 |
| 3 | 63 | 9223372036854775808 | 0.7818 |
| 4 | 63.5 | **13043817825332783104** | **0.9946** (dentro de [0.8, 1.2]: elegido) |

4 puntos de 6 permitidos. **Forma de la curva:** no es monótona en sensibilidad — de 2^60 a 2^62
(×4 el rango) los bloques/slot casi se triplican (0.23→0.65); de 2^62 a 2^63 (×2) solo suben ~0.13;
de 2^63 a 2^63.5 (×√2) vuelven a subir ~0.21. Consistente con la combinatoria de "al menos una
solución entre 3 auditorías independientes", ni puramente exponencial ni lineal en el exponente.

`SR_dev = 13043817825332783104` se usó en **todos** los escenarios R1…R4, sin volver a calibrar.
Evidencia completa (incluidos 4 intentos fallidos de calibración por bugs de arnés, conservados sin
borrar) en `run/E2a-calibracion*/`.

## 3. Tabla escenario × repetición

**Nota de lectura, válida para toda la tabla:** el veredicto de "mismo estado" (E-3, E-4, E-5, E-6,
E-6b, E-8) es el de `verificar_estado_w07d.sh` — reposo (`--dejar-de-producir-en-slot` + 30 s sin
`cambio_punta`), relanzamiento AISLADO **sobre una copia** de `datos/` (nunca el original), y
comparación de `resumen_estado` **y** `compendio_bloques` leídos directamente del evento
`reinicio_completo` del binario W07d/3d21b1f. Es el único método decisivo (ver §5.2 para por qué
los métodos anteriores no lo eran). El campo `estado_final_igual` que reporta el instrumento
Julia (W07c/W07c-B) compara en cambio el ÚLTIMO evento del `registro.jsonl` **crudo, sin reposo**:
es descriptivo, no decisivo, y puede diferir del veredicto real (ver R1 en la tabla).

### R1 — E-1, E-2, E-3, E-4 (commit `26312ff`, 3 nodos A/B/C, una clave cada uno)

| rep | semilla | E-1 (corte) | E-2 (30 min régimen) | E-4 (SIGKILL+reinicio) | E-3 (mismo estado, veredicto REAL W07d) | `estado_final_igual` (instrumento, informativo) |
|---|---|---|---|---|---|---|
| 1 | 101 | SUPERADO, los 3 cruzan | SUPERADO, 0 rechazos, ≈1502 bloques PoST/≈1574 slots | SUPERADO, reinicio+puesta al día ≈118 s | **SUPERADO** (`resumen_estado=083e5cc0…a64e1e3`) | no (artefacto de corte del registro, ver §5.2) |
| 2 | 202 | SUPERADO | SUPERADO, 0 rechazos | SUPERADO | **SUPERADO** (`resumen_estado=59fcbed7…095cfc12e55a04`) — el método antiguo había dado DIVERGEN, refutado por este veredicto real | no |
| 3 | 303 | SUPERADO | SUPERADO, 0 rechazos | SUPERADO | **SUPERADO** (`resumen_estado=7bf46f47…4c2d9b38c2b94`) | no |

Latencias de propagación (rep1, p50/p95 por par, ns): A→B 169 009 813/352 199 848, A→C
163 925 425/349 459 950, B→C 168 879 611/356 739 409 (orden de 150-350 ms, esperado en localhost
con verificación real de PoST); B→A y C→A muestran p95 anormalmente altos (20 s y 11,5 s) porque A
estuvo caído por el `SIGKILL` de E-4 y se puso al día con bloques represados — declarado, no
oculto. Divergencia (fracción del intervalo con puntas distintas antes de reconverger): 0.117 /
0.217 / 0.219 en rep 1/2/3 respectivamente, todos los episodios reconvergidos salvo 1 (de 1374) en
rep1. Recursos (RSS): 790 MiB–1,48 GiB de pico por nodo. Detalle completo en
`analisis/R1-rep{1,2,3}/`.

### R2 — E-5, llegada tardía (commit `26312ff`, nodo D arranca tras ≥500 bloques combinados)

| rep | semilla | IBD de D | huérfanos de D | E-5 (mismo estado, veredicto REAL W07d, 4 nodos) |
|---|---|---|---|---|
| 1 | 101 | ≈63.55 s | 7 | **SUPERADO** (`resumen_estado=67acba95…caaaa8225641ded0b`, incluye D) |
| 2 | 202 | ≈60.37 s | 15 | **SUPERADO** (`resumen_estado=305777f8…2a62dfa7eeffb4ef`) |
| 3 | 303 | (ver `EJECUCION.txt`) | 11 | **SUPERADO** (`resumen_estado=abce9207…770634d12348f51`) |

`latencia_propagacion D→*`: sin muestras dentro de la ventana medida (D solo se une tras el IBD,
no hay pares producción-D→admisión-en-otro en esta ejecución) — declarado, no oculto. Detalle en
`analisis/R2-rep{1,2,3}/`.

### R3 — E-6 y E-6b (commit `3d21b1f`, partición y reunión)

**E-6** (partición `{A}`/`{B,C}` en fase PoST, 3 claves ya repartidas 1 por nodo desde el
arranque, ambos lados conectados y produciendo desde el génesis antes de partir):

| rep | aislamiento verificado (0 contactos) | reunión | E-6 (mismo estado, veredicto REAL W07d) |
|---|---|---|---|
| 1 | sí | convergencia en vivo ≈12,17 s | **SUPERADO** (`resumen_estado=7a7e9a75…ccd5ac82d5914fe0e`) |
| 2 | sí | convergencia en vivo | **SUPERADO** (`resumen_estado=dd1111fe…c25538b0ddd9cb96`) |
| 3 | sí | convergencia en vivo | **SUPERADO** (`resumen_estado=92e29e77…c7bbfc8d296aef3a1`) |

Sin ningún panic ni `produccion_omitida` necesario en las 3 repeticiones (W06d9 corrige el defecto
que en el primer intento con este mismo escenario, sobre el commit anterior, mató el hilo
productor de C — ver §5.4).

**E-6b** (partición en fase PoW cerca del corte; A aislado desde el arranque con sus propias 3
claves `0,1,2`, B+C juntos con las otras 3 `3,4,5` — ver §5.3 sobre por qué esta repartición de
claves, distinta de E-6, es la correcta para este escenario):

| rep | blue_score pre-reunión (A vs. max(B,C)) | predicción FC-3 | aislamiento verificado | E-6b (mismo estado, veredicto REAL W07d) |
|---|---|---|---|---|
| 1 | A=8, BC=9 | BC | sí | **SUPERADO** (`resumen_estado=9a295d6d…cdcea35ad2e254cee`) |
| 2 | A=7, BC=9 | BC | sí | **SUPERADO** (`resumen_estado=afd1a8d9…e7fccebf640397b28`) |
| 3 | A=7, BC=11 | BC | sí | **SUPERADO** (`resumen_estado=85526d6a…5db87df34fc41c9a`) |

FC-3 (terminal decidido por peso PoST, nunca por trabajo PoW) predijo BC en las 3 repeticiones
(mayor `blue_score` en el momento de la reunión); las 3 convergieron tras reunir, consistente con
la predicción. Detalle en `analisis/R3-E6{,b}-3d21b1f-rep{1,2,3}/`.

### R4 — E-7, E-8, E-9 (commit `3d21b1f`)

**E-7** (`zx-adversario` contra A: nonce PoW malo, PoT con diferencia de slots, firma inválida
ZIP-215, en ráfaga) — resultado idéntico en las 3 repeticiones:

| rep | rechazos con motivo exacto | cambio de estado | par_penalizado / limite_alcanzado |
|---|---|---|---|
| 1/2/3 | 4 tipos distintos de rechazo, cada uno con su motivo (firma inválida, PoT no coincide ×2, bits de PoW incorrectos), 3-34 ms hasta el rechazo | **ninguno** (`resumen_estado` antes y después del ataque idénticos) | **0 eventos en ningún nodo** — ver §5.6 |

**E-8** (`zx-adversario doble-firma`, castigo activo, patrón SL-4b2 V4):

| rep | evidencia_detectada | evidencia_incluida (primer nodo) | E-8 (mismo estado, veredicto REAL W07d) |
|---|---|---|---|
| 1 (semilla 101) | B=1, C=1 | A | **SUPERADO** (`resumen_estado=0b0c6d03…be41fffe7`, `n_bloques_dag=96`) |
| 2 (semilla 202) | B=1, C=1 | C | **SUPERADO** (`resumen_estado=53ec53da…5648b5d08`) |
| 3 (semilla 303) | B=1, C=1 | C | **SUPERADO** (`resumen_estado=6e755a6a…07837b2c2`) |

Qué nodo incluye primero la evidencia varía por carrera de red (A en rep1, C en rep2/3) — no es un
fallo, el criterio es que ALGUIEN la incluya y confisque, cumplido en las 3.

**E-9** (retención del terminal, descriptivo, sin criterio de éxito/fracaso — `A-07` abierto): A
aislado retiene su corte, B+C cruzan juntos casi al mismo tiempo (Δ del orden de 1-2 ms entre
ambos T fijados); A publica tarde tras 60 s de producción adicional de B/C; en la reunión:

| rep | quién fija T primero | resultado de la reunión |
|---|---|---|
| 1 | A y BC casi simultáneos (Δ≈1,66 ms) | terminal de A gana por reorg, `profundidad_reorg=30`; los 3 convergen (`blue_score=182`) |
| 2 | BC ligeramente antes | reunión converge (mismo `punta`/`resumen_estado` en los 3, método informativo) |
| 3 | BC ligeramente antes | reunión converge (ídem) |

No hay criterio de éxito/fracaso para E-9 (descriptivo por diseño de la orden); se reporta el
dato para que quede constancia de qué determina en la práctica quién gana la reunión cuando ambos
lados fijan su T casi al mismo tiempo. Detalle completo en `analisis/R4-rep{1,2,3}-{e7e8,e9}/`.

## 4. Lo que 0.0.1 NO mide (repetido de `ESCENARIOS-0.0.1.md` §4, para que quede en el mismo
   documento)

- Relevo de transacciones entre nodos (0.0.1 solo incluye los depósitos propios de cada nodo).
- Latencia de red WAN (todo se midió en `127.0.0.1`, mismo reloj, misma máquina).
- Más de ~5 nodos (el máximo medido en esta orden fue 4, en E-5).
- Un adversario con más espacio o más hash que los honestos (no simulado en esta orden).
- Sectores Filecoin (`SEC-0`).
- `C-EVP`/`C-SLA` como mecanismo GENERAL: en esta orden concreta `C-EVP` (evidencia/castigo de
  doble firma) **sí estaba activo** para E-8 por instrucción explícita de `ORDEN-W07b.md` §3.4/§3.7
  ("con castigo activo: se exige lo de SL-4b2 V4"), lo cual **contradice** la descripción de
  `ESCENARIOS-0.0.1.md` §3 (fechado 2026-09-26, un día antes), que decía "`C-EVP` está inactivo en
  0.0.1: no hay castigo y se declara como límite". Ambos documentos son del mismo P-ZRX/P-MEDICION;
  seguí la instrucción más reciente y explícita de la orden que rige esta medición
  (`ORDEN-W07b.md`), y lo señalo aquí para que quien lea ambos documentos no vea una contradicción
  sin explicar.

## 5. Hallazgos

### 5.1. Tres claves por nodo hace imposible cruzar el corte para 2 de 3 nodos (arnés, corregido)

Mi arnés inicial daba 3 claves a cada nodo (copiando un patrón de otra orden con distinto
objetivo). Con `K_min=3` (garantía de 3 claves DISTINTAS para cruzar el corte, `PERFIL-DEV-v0.md`
§3) y 3 claves en un solo nodo, ese nodo cruza él solo en cuanto gana la mayoría del minado PoW —
verificado en vivo (un nodo minó 26/31 bloques PoW propios, los otros 2 nunca depositaron lo
suficiente). Sin relevo de transacciones en 0.0.1, los otros 2 nodos **nunca** pueden alcanzar
`K_min` por su cuenta: no es variación entre ejecuciones, es estructural. Corregido a una clave
por nodo en los 6 guiones del arnés (`r1.sh`, `r2.sh`, `r3_e6.sh`, `r3_e6b.sh`, `r4.sh`,
`calibrar_sr_dev.sh`).

### 5.2. Ningún método de "mismo estado" basado en el registro crudo es decisivo hasta W07d

Evolucionó en 3 iteraciones, cada una refutada por evidencia real antes de confiar en la
siguiente:
1. Comparar el `resumen_estado` del último `cambio_punta` tras el `SIGKILL` final: R1 rep2 dio
   `DIVERGEN` en C con la misma `punta` que A/B — resultó ser que `resumen_estado` solo se escribe
   EN `cambio_punta`, y un bloque lateral admitido después del último cambio de punta (antes del
   corte del registro) altera el estado virtual sin dejar un resumen nuevo escrito. Artefacto de
   CUÁNDO se escribió el último resumen, no una divergencia de consenso real.
2. "Último `cambio_punta` tras un reinicio aislado": el director comprobó en el código
   (`nodo.rs:1241`) que también puede quedar desfasado por el mismo motivo.
3. **Definitivo (W07d):** el propio binario añade `resumen_estado`, `punta`, `n_bloques_dag` y
   `compendio_bloques` (SHA3-256 de todos los hashes persistidos) directamente al evento
   `reinicio_completo`/`parada`, calculados sobre el estado FINAL tras la parada ordenada — ya no
   hace falta adivinar con eventos intermedios. Este es el único método usado para los veredictos
   de esta tabla. Además, siempre se opera sobre una COPIA de `datos/` (`cp -a`), nunca el
   original: reabrir un nodo escribe en su RocksDB (confirmado con `find -newer` en un incidente
   temprano donde por error se reabrió el original directamente).

### 5.3. K_min es POR LADO en un escenario de partición previa al corte (E-6b, E-9)

"Una clave por nodo" (§5.1) es correcta cuando los nodos están conectados desde el arranque (las 3
claves se suman entre los 3). Pero en E-6b y E-9, la red se **parte antes** del corte: cada lado
necesita sus PROPIAS 3 claves para cruzar por separado. Con 3 claves repartidas 1+1+1 entre 3
procesos y una partición de 2 vías, ningún lado llega nunca a `K_min=3` — confirmado en vivo: un
nodo aislado minó 206 bloques PoW sin cruzar jamás (`run/R3-E6b-3d21b1f-rep1-kmin-imposible/`,
conservado). Corregido dando al lado de un solo proceso sus 3 claves completas (`0,1,2`) y
repartiendo las otras 3 (`3,4,5`) entre los procesos del otro lado — exactamente el patrón ya
validado con procesos reales en `deepseek/SL4b2/ejecutar_e6b.sh` (lectura permitida por la orden).
Aplicado también, preventivamente, a E-9 en `r4.sh` antes de lanzarlo (misma topología partida),
evitando un intento fallido.

### 5.4. Dos fallos reales del producto encontrados y corregidos durante la orden (no del arnés)

1. **Panic del hilo productor** (`crates/zx-node/src/regimen.rs:438`, commit `27dcfeb`): al cruzar
   el corte con `SR_dev` muy bajo (deliberado, para la calibración), varios nodos producen bloques
   PoST distintos para el mismo slot casi simultáneamente, con reorganizaciones inmediatas
   (`profundidad_reorg:33` visto). El hilo productor de un nodo recibió un mensaje
   `MsgBucle::Padres` en un punto donde el código solo esperaba `Continuar`/`Parar`, y hace
   `panic!` explícito sin rama de recuperación. Corregido por W06d8 → commit `26312ff`.
2. **Fallo del productor por portador PoT no retenido** (commit `26312ff`/`27dcfeb`): el nodo solo
   registraba el ÚLTIMO portador PoT de la justificación de un bloque de red; si el portador
   correcto no era el último anotado, el hilo productor moría con «servicio PoT: no hay portador
   retenido para el slot N» al intentar producir justo tras una partición (encontrado en el primer
   intento de E-6 con aislamiento real, `run/R3-E6-rep1-26312ff-panic-contaminado/`, conservado).
   Corregido por W06d9 → commit `3d21b1f` (registra TODOS los portadores; si aun así no puede
   justificar, emite `produccion_omitida` y sigue, no muere). Verificado sin reaparecer en las 3
   repeticiones de E-6 con el commit definitivo.

Ambos se declararon como hallazgos del producto en cuanto se identificaron, con la evidencia cruda
conservada tal cual (nunca borrada, solo renombrada para no contaminar intentos posteriores).

### 5.5. `bloques_por_slot`/`padres_por_bloque`/`fracción de rojos` del instrumento contaban por
   evento, no por bloque (W07c-B, corregido)

Hallazgo del director al revisar R1 rep1: el instrumento W07c contaba un evento
`bloque_producido`/`bloque_red_admitido` **por nodo** (cada bloque real ×3 con 3 nodos) y excluía
los slots vacíos de la distribución — daba una mediana de 3 bloques/slot cuando los datos crudos
dan ≈0,95 bloques DISTINTOS por slot. Corregido por la orden W07c-B (2026-09-27, DeepSeek): cada
bloque cuenta una vez por `hash`, se incluyen todos los slots del intervalo (también los vacíos), y
se añade `media_bloques_por_slot`. Verificado con 525 aserciones en verde (incluida la nueva suite
`V1(h)`) antes de usarlo. **Las 18 ejecuciones válidas de W07b se analizaron (o re-analizaron)
íntegramente con esta versión corregida**; ninguna cifra de este informe usa la versión antigua.

### 5.6. Penalización de pares en E-7: no observada en el registro

`ORDEN-W07b.md` exige, para E-7, que "el par penalizado según los límites `C-NET`". En las 3
repeticiones, los 4 tipos de rechazo se registraron con motivo exacto y sin cambio de estado
(criterio principal cumplido), pero **ningún nodo registró un evento `par_penalizado` ni
`limite_alcanzado`** en ningún momento (confirmado listando todos los tipos de evento distintos
presentes en los registros: no aparecen). No se investigó la causa exacta (podría ser que el
binario aún no implemente penalización de pares para estos vectores concretos, que el umbral de
penalización no se alcanzara con una sola ráfaga, o que `zx-adversario` no se registre como un
"par" sujeto a puntuación de la misma forma que un nodo normal) — se declara como hallazgo abierto,
no se ajusta el criterio a posteriori ni se oculta.

### 5.7. Dos bugs de arnés en `scripts/analizar.sh` (Julia resuelve rutas relativas en SU cwd, no
   en el mío)

`run.jl` hace `abspath()` de sus argumentos en el directorio de trabajo de Julia (el del
instrumento, tras el `cd` del guion), no en el directorio desde el que se invoca el guion.
Encontrado dos veces, con el mismo patrón, en dos argumentos distintos:
1. `--ejecucion` (hallado al analizar R1-rep1): una ruta relativa como `run/R1-rep1` se resolvía
   contra `analisis-instrumento/run/R1-rep1` (inexistente). Corregido resolviendo `EJ` a absoluta
   ANTES del `cd`.
2. `--salida` (hallado al analizar R4-rep1/e7e8): el mismo problema con el 3er argumento; el
   resultado real aterrizó en `analisis-instrumento/analisis/R4-rep1-e7e8` en vez de
   `analisis/R4-rep1-e7e8`. Ningún dato se perdió, solo quedó mal ubicado; trasladado a mano y
   corregido `analizar.sh` para resolver también `SALIDA` a absoluta antes del `cd`.

### 5.8. Presupuesto de 8 h de reloj superado, y de 50 GiB de disco superado y corregido

**Reloj:** ver §0. Declarado en cuanto se detectó (`PROGRESO.md`), con los motivos identificables:
dos candidatos de commit nuevos a mitad de sesión que obligaron a repetir E-0 y partes de la
medición, la evolución del método E-3 en 3 iteraciones, y el hallazgo de K_min-por-lado que obligó
a rehacer E-6b/E-9 con las claves corregidas. Duración real: ≈10 h 52 min de las 8 h de
`ORDEN-W07b.md` §5.

**Disco:** al hacer la comprobación final de la zona (`du -sh .`) encontré **83 GiB** frente al
presupuesto de 50 GiB — no lo comprobé en tiempo real durante la sesión, un descuido mío. Casi
todo (63 de los 83 GiB) era `target/debug/` de las 3 pasadas de CI completa (`cargo
build`/`test --workspace --all-features`, un clon por commit candidato) — artefactos de
compilación de depuración, no evidencia de medición; los binarios `release` realmente usados para
medir son solo 1,1 GiB por clon. Corregido de inmediato: borrado `target/debug/` de los 3 clones
(nunca `run/`, `verif/` ni `analisis/`), verificando antes y después que los `sha256` de los 3
binarios `release` no cambiaron. Zona final: **21 GiB**, dentro de presupuesto.

## 6. Evidencia y reproducibilidad

- `RECETA.md`: receta completa de E-0 para los 3 commits, con hashes de binarios.
- `scripts/`: arnés completo en bash (sin Python en ningún momento salvo un incidente aislado,
  declarado y corregido de inmediato sin usar su resultado — ver `PROGRESO.md`).
- `run/<escenario>/<rep>/`: registros crudos (`registro.jsonl` por nodo), CSV de recursos,
  `EJECUCION.txt` con commit/hashes/parámetros/semilla/`uname`/carga, `W07D-VERIFICACION.txt` con
  el veredicto real de estado. Incluye también las ejecuciones fallidas/conservadas (paneles,
  contaminaciones, el intento K_min-imposible) — nada se borró, solo se renombró para preservar la
  evidencia.
- `verif/<rep>/<nodo>/`: copias aisladas usadas para el veredicto W07d (nunca el `datos/`
  original).
- `analisis/<rep>/`: salidas del instrumento W07c-B (RESUMEN.md, metricas.tsv, convergencia.tsv,
  latencias.tsv, rechazos.tsv, admision-vs-profundidad.tsv) para las 18 ejecuciones válidas.
- `HUELLAS.sha256`: sha256 de todo `run/` (ver nota al final de este documento sobre su alcance).
- `PROGRESO.md`: bitácora completa, cronológica, de todo lo anterior con PID/PGID de cada proceso
  largo, cada hallazgo y cada corrección, tal como se fue descubriendo.
- `HORAS.log`: hitos con `date -Is` real.

**Este informe no oculta ningún fallo.** Los dos fallos reales del producto (§5.4), el hallazgo de
penalización de pares no observada (§5.6) y el desbordamiento de presupuesto (§5.8) se reportan tal
cual, sin ajustar los criterios de éxito a posteriori.
