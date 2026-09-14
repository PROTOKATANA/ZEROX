# DECISIONES-PENDIENTES — GDR-v0.2

Este documento no fija ninguna regla de consenso por sí solo. Registra dos cosas: los puntos que
Katana **ya decidió** (con la regla exacta y los contraejemplos que muestran que la decisión
importa) y los que **siguen abiertos**. El instrumento implementó primero las tres lecturas del
SPEC/Kaspa/Python como parámetro (`SpMode`/`MergeMode` en `src/modelo.jl`) para no elegir en
silencio; con la regla C decidida (TAREAS.md §1.3, 2026-09-14), esas tres siguen implementadas y
probadas como historia/comparación, pero ya no son candidatas — `Params()` usa `SP_ZEROX` por
defecto.

Fuentes cruzadas (fecha de lectura original: 2026-09-14; commit rusty-kaspa `c338d495`, ver
`METODO.md` para los sha256 recalculados en esta corrección): `SPEC.md` §7.2 (1208-1300), §7.3
(1315-1340), §11 (1543-1561), C-HDR-05 (857); `research/dag-poas-ancla-de-orden.md` R-FIN-6,
R-FIN-8′, R-FIN-10, R-FIN-11, R-FIN-12; `TAREAS.md` §1.2, §1.3 (bloque «Dirección de los
desempates — DECIDIDO POR KATANA»); `veritas/consenso/disponibilidad-causal-multivista-v1/CONTRATO.md`
(13, 24-27, 37-38, 167); `rusty-kaspa` `consensus/src/processes/ghostdag/{protocol,ordering,mergeset}.rs`,
`crypto/hashes/src/lib.rs`; `research/scripts/d9-ronda8c/r8c_gd.py` y `r8c_test_gd.py`.

## 0. La regla C (DECIDIDO POR KATANA, 2026-09-14 — TAREAS.md §1.3)

> **Orden del mergeset**, el mismo para colorear (U3″) y para aplicar (R-FIN-8′(4)):
> `(blue_work, solution_distance, hash)` ascendente, hash comparado byte a byte.
> **Padre seleccionado** (y punta virtual): el de mayor `blue_work`; en empate, el que iría
> PRIMERO en ese orden — menor `solution_distance`, luego menor hash (dirección MIXTA: máximo en
> `blue_work`, mínimo en `sd` e `id`).
> **`rank` para P1:** la misma tupla, ascendente; gana el menor.

Implementada como `SP_ZEROX` (`mejor_sp_zerox`, `src/modelo.jl`) + `MERGE_SPEC` (sin cambios: ya
era `(bw,sd,id)` ascendente). `rank`/`es_menor_rank` tampoco cambiaron: ya eran `cmp_orden`
ascendente. Esto **cierra D-1, D-2, D-3 y D-6** de la v0.1 (abajo, §2, marcados como decididos, con
el análisis histórico conservado porque explica POR QUÉ ningún modo anterior era C). **D-4 y D-5
siguen abiertos** (§3), igual que la pregunta de si el id final de P1 es redundante o se conserva
(§3, tercer punto).

## 1. Tabla de direcciones de desempate — histórica (superada por la regla C)

Se conserva para que quede constancia de por qué C no coincide con ninguna lectura anterior.

| Uso | Kaspa (real) | Python histórico (`r8c_gd.py`) | SPEC / research doc (antes de C) | Regla C (decidida) |
|---|---|---|---|---|
| (a) elección de `sp` | `max` sobre `(bw,hash)` asc.; empate → mayor hash. | `max(key=(bw,−sd,id))`; empate bw → menor sd; empate sd → mayor id. | No fijaba una regla explícita. | Mayor bw; empate → **menor** sd; empate → **menor** id. |
| (b) orden del mergeset (colorear) | `sort_blocks` asc. `(bw,hash)`; menor hash primero. | `sorted(key=(bw,−sd,id))`: empate bw → **mayor** sd primero (signo invertido respecto a (a) con la misma clave). | Ambiguo: R-FIN-11 no fijaba la dirección de `sd` para este uso. | `(bw,sd,id)` ascendente — **sin cambios respecto a `:spec`/`MERGE_SPEC`**. |
| (c) orden de aplicación R-FIN-8′(4) | Sin `sd`; asc. `(bw,hash)`. | Reutiliza (b): **mayor** sd primero. | Texto literal: «menor solution_distance» — contradecía a Python real. | Misma que (b): `(bw,sd,id)` ascendente. |
| (d) `rank` para P1 | No existe. | No implementado. | PENDIENTE explícito (SPEC.md:1285-1291). | `(bw,sd,id)` ascendente, gana el menor — **sigue siendo PROPUESTA de redacción**, no adoptada en el SPEC (D-4). |

**Por qué C no es ninguna de las tres lecturas anteriores.** (a) y (d) usan la MISMA dirección que
(b)/(c) — a diferencia de Kaspa/Python/​`:spec`, donde la selección de `sp` invertía uno o más
componentes respecto al orden del mergeset. `SP_SPEC` maximizaba la tupla ascendente completa
(mayor sd Y mayor id en empate); `SP_PYTHON` acertaba en `sd` (menor) pero no en `id` (mayor). Ver
D2′/D5′/D6′/D7′/D8/D9/D10 (`DERIVACIONES.md`) para los contraejemplos que muestran, con números,
en qué difiere cada modo histórico de C.

## 2. Puntos decididos (histórico conservado + regla aplicada)

### D-1/D-2 · Dirección de `solution_distance` (usos a, b, c) — DECIDIDO POR KATANA (2026-09-14), opción C

Mergeset/aplicación: `(bw,sd,id)` ascendente (sin cambios respecto a `:spec`). Padre
seleccionado/punta virtual: mayor bw, empate→menor sd, empate→menor id (dirección mixta, nueva).

- **Contraejemplos**: D5′ (`DERIVACIONES.md`, P/Q/R/S sd 10/1/5/3, k=2) — `sp(M)=Q` (menor sd,
  igual que `:python`, pero por la regla C); D2′ (diamante A/B) — `sp(D)=B`; D8 (tres hermanos en
  dos contextos) — muestra que el orden relativo entre los que NO ganan `sp` no depende de con
  quién compitan.
- Análisis histórico (v0.1, antes de C): la ambigüedad real era que el script Python histórico
  (`r8c_gd.py:103-106,218,291-301`) reutilizaba, para su `sort()` en (b)/(c), la misma clave
  `(bw,−sd,id)` diseñada para que `max()` en (a) premiara la menor `sd` — y esa clave, en un
  `sorted()` ascendente, produce el efecto contrario (mayor `sd` primero). El comentario del
  propio script («menor sd gana», línea 104) es cierto para (a) y falso para (b)/(c). Ninguna de
  las seis pruebas de `r8c_test_gd.py` lo ejercitaba. Este hallazgo sigue siendo válido como
  explicación de la laguna original; la regla C la cierra fijando UNA dirección para (a) y otra
  para (b)/(c), en vez de reutilizar la misma clave para las dos.

### D-3 · Dirección del hash/id como desempate final — DECIDIDO POR KATANA (2026-09-14), opción C

Menor id gana en TODOS los usos (mergeset, aplicación, Y AHORA TAMBIÉN `sp`) — a diferencia de
`:spec`/`:python`, donde `sp` premiaba el mayor id.

- **Contraejemplos**: D6′ (P y Q con `bw` y `sd` idénticos, solo el id decide) — bajo C,
  `sp(M)=P` (menor id), invertido respecto a D6 (`:spec`, donde ganaba Q); D9 y D10 (copias del
  mismo billete con `sd`/SR idénticos) — el id decide cuál copia se colorea azul primero y cuál(es)
  quedan `rojo_U3`, con el mismo criterio (menor primero) tanto si la copia compite por `sp` (D9a,
  D10a) como si no (D9b, D10b).
- Histórico: ni SPEC.md ni el research doc fijaban explícitamente la dirección del hash; Kaspa real
  y el prototipo Python coincidían en un patrón (hash ascendente en el mergeset, mayor hash gana en
  `max()` para `sp`) que la regla C **no** reproduce para `sp` — ahí es donde C se aparta más
  claramente de "el mismo patrón que Kaspa, con sd añadido".

### D-6 · Alcance de R-FIN-8′(4): ¿rige también el coloreo? — DECIDIDO POR KATANA (2026-09-14), opción C

Sí: la regla C declara explícitamente "el mismo [orden] para colorear (U3″) y para aplicar
(R-FIN-8′(4))" — una sola función (`MERGE_SPEC`/`orden_merge_ref`) para ambos usos, tal como el
instrumento ya asumía por simplicidad (`modelo.jl`, antes de esta decisión). D7′ (color contextual)
confirma que coloreo y aplicación siguen coherentes entre sí bajo C: el mismo bloque (W) es azul
cuando lo colorea una cadena y `rojo_k` cuando lo colorea otra, y el orden de aplicación de ambas
cadenas usa la misma regla de mergeset.

## 3. Puntos que SIGUEN abiertos

### D-4 · Redacción de `rank` en el SPEC (SPEC.md:1285-1291, PENDIENTE)

- El instrumento implementa `cmp_orden`/`es_menor_rank` sobre `(blue_work, solution_distance, id)`
  ascendente — coincide con la dirección de la regla C para (b)/(c)/(d), así que ya no hereda
  ninguna ambigüedad de D-1/D-2/D-3. Sigue siendo **PROPUESTA de texto normativo**
  (`PROPUESTA-SPEC.md` §7.2), no una edición de `SPEC.md`.
- **Totalidad**: demostrada por escrito (producto de órdenes totales; `PROPUESTA-SPEC.md` §7.2,
  demostración (i)) y verificada exhaustivamente para todo DAG con n≤6 —10 105 DAGs, y desde
  Corrección 1 también sobre TODOS los pares de bloques, no solo padre-hijo (testset «rank:
  totalidad y causalidad», `test/runtests.jl`)— más muestreo aleatorio para n medio.
- **Compatibilidad causal**: demostrada por escrito (`PROPUESTA-SPEC.md` §7.2, demostración (ii):
  `bw(B) ≥ bw(sp)+w(sp) > bw(sp) ≥ bw(A)` para todo padre `A`, usando `sp(B)∈blues(B)` y
  `w(x)≥2^64>0`) y verificada empíricamente en el mismo universo exhaustivo/aleatorio, incluyendo
  ahora la premisa `sp(B)∈blues(B)` como invariante comprobado por separado.
- **Implicación para Katana**: adoptar esta definición de `rank` resuelve TAREAS.md §1.2. Ya no
  depende de que se cierre D-1 (eso ya ocurrió con la regla C) — el único paso que falta es
  trasladar el texto de `PROPUESTA-SPEC.md` §7.2 a `SPEC.md`.

### D-5 · Política de desbordamiento de `blue_work` (SPEC.md §11:1543-1561, PENDIENTE)

- **Opción A — dominio fijo de 256 bits con error explícito** (implementada, `BW256`): sencilla,
  rápida, pero falla con `OverflowError` si algún DAG real supera 2^256. La cota correcta
  (Corrección 1, tarea 3.5; ver `PROPUESTA-SPEC.md` §11) es `bw(B) < n·2^128` — **158 bits para
  n=10^9**, no 163: la cifra anterior tenía un factor `(k+1)` de más, sin justificación (cada
  bloque cuenta como mucho una vez en `past(B)∪{B}`, el `(k+1)` no aparece en ningún paso de esa
  suma). Muy por debajo de 256, pero sigue siendo la cota de un argumento de conteo, no una prueba
  de que ningún DAG adversarial la supere con una construcción distinta de `blue_work`.
- **Opción B — `BigInt` sin límite** (oráculo, `peso_big`): nunca desborda; inviable a escala de
  producción por asignación de memoria.
- **Opción C — envolver/truncar silenciosamente**: descartada (LINEO.md prohíbe desbordamiento
  silencioso en reglas de consenso).
- Sigue sin resolverse cuál dominio numérico exacto y qué política de fallo adopta el SPEC para
  producción; este instrumento mide y demuestra la cota, no elige.

### Redundancia del id final en P1 (3.4 (iii), `PROPUESTA-SPEC.md` §7.2)

Con `rank` total (D-4), la clave `(color, rank)` ya distingue cualquier par de bloques del mismo
billete — el id final de P1 nunca se necesita para desempatar, porque `rank` ya termina en `id`.
Evidenciado (no demostrado para todo n) por el testset «P1: desempate por id redundante»
(`test/runtests.jl`, 100 DAGs aleatorios n∈[60,120)). **Queda para Katana** decidir si P1 se
redacta sin el desempate final por id (más corto, pero pierde la red de seguridad textual si
`rank` cambiara de definición) o si se conserva marcado explícitamente como redundante bajo la
definición actual de `rank`.
