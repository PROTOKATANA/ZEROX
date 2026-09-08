# Ancla de orden — octava propuesta para un DAG sobre PoAS

**Fecha:** 2026-09-08 · **ESTADO (tras D9-f):** ancla **por `slot`** (índice de PoT) — la cuarta y la única con **`m` acotado por construcción**: `m ≤ 1 + λ·S_max[s]`. `F ∝ ln m`, así que las constantes **sí están dimensionadas, contra su cota**: **`I = 4 200 s`, `F = 5,3 h` medidos** (familia de D9-e), **`F ≤ 68,5 h` garantizado** (`S_max = 150 s`); **`c` desaparece**. Prop. 7 la cubre (Lema A4-slot). `τ ≈ 0,1 s`, R-FIN-1a **no estricta**, `S_max` **en segundos**. Ver `dag-poas-ancla-de-orden-auditoria-6.md`. **Pendiente: D8 sobre el diseño completo; la duración real del slot de PoT de Autonomys; `Δ`.** Es la **séptima propuesta**
(`dag-poas-ancla-de-finalidad.md`) con **una regla reescrita y cuatro constantes derivadas**. Nueve
de sus diez reglas se copian sin tocar. La meta-auditoría que motiva el cambio está en
`dag-poas-ancla-de-finalidad-metaauditoria.md`; sus scripts, en `/tmp/d9-ronda7/`.

**Qué cambia respecto a la ronda 7, y nada más:**

| | Ronda 7 | Aquí |
|---|---|---|
| **R-FIN-1** · inyector | ancestro en la **posición `c·j` de la cadena seleccionada** | ~~índice del orden total~~ → **revertido a la cadena seleccionada** (R-FIN-1, tras D9-b) |
| `k` | «punto fijo del retarget», sin cerrar frente a la ec. (2) | **25**, derivada |
| `I` (época) | dos puntos de ejemplo, «ninguno elegido» | **2 490 s**, derivada |
| `F` (finalidad) | 1 000 s / 4 300 s, ejemplos | **3,2 h**, derivada |
| Todo lo demás | — | **idéntico** |

---

## 0 · Por qué el ancla — ⚠️ SECCIÓN SUPERADA: el argumento de abajo llevó a un ancla grindable (D9-b A3). Se conserva como registro; la justificación vigente está en `dag-poas-solucion-ancla.md` §0

La ronda 7 leía la entropía de «el ancestro en la posición `c·j` de la cadena seleccionada». Leído
el paper de PHANTOM/GHOSTDAG en local: **«common prefix» aparece 0 veces; «prefix», 0; «stabiliz»,
0.** Todo lo que el paper demuestra que converge es **el orden** (§3.4 *Convergence of the order*,
Property 1, Prop. 7). Y sobre la cadena seleccionada afirma lo contrario:

> *«In Nakamoto Consensus… the score of a Bitcoin node increases monotonically. **In GHOSTDAG this
> no longer holds.** Indeed, there are cases where by learning of new blocks, the blue score of the
> virtual node actually **decreases**.»*

**El índice del orden total sí está cubierto.** La Definición 2 cuenta como «posterior a `B`» incluso
un bloque que aún no existe —*«we use the same notation `B ≺ C` when `B ∈ G` but `C ∉ G`»*—, así que
el evento de riesgo **incluye la inserción de bloques futuros por delante de `B`**. De donde:

```
índice(B) = |{C : C ≺ B}|
  Def. 2 + Prop. 7  ⇒  el conjunto de predecesores de B se estabiliza exponencialmente
                    ⇒  su cardinal también
                    ⇒  el índice del orden total se estabiliza exponencialmente
```

**Arqueología, para que no se pierda otra vez.** La **ronda 1, hallazgo A9**, ya lo propuso con la
razón correcta: *«Altura → posición en el orden total de GHOSTDAG… a profundidad > poda, **donde el
orden es inmutable**»*. La **ronda 2** lo objetó, pero (a) sobre `C-EXP-04` —caducidad de sectores—,
no sobre el inyector; (b) con estado **SOSPECHA**, *«sin escenario cerrado»*; y (c) su mitigación fue
*«fijar altura = blue_score de la cadena seleccionada»*. De la ronda 3 en adelante todo usó la cadena
seleccionada. **Se cambió la rama con teorema por la rama sin teorema, sobre una sospecha acerca de
otra regla.**

---

## 1 · Las cuatro constantes, derivadas

Ninguna es un ejemplo. Cada una sale de una restricción distinta, y **convergen**.

### 1.1 · `k = 25` — de resolver la ec. (2) de GHOSTDAG

La ec. (2) toma el **máximo de dos magnitudes que no son comparables**:

| Término | Qué es | Con `Dmax=4 s`, `λ=1`, `δ=0,01` exige |
|---|---|---:|
| `Σ_{j>k} e^{−2c}(2c)^j/j!` | `P(anticono > k)` — **probabilidad de fallo** | `k = 15` |
| `2c/(k+2c)` | el `δ` del **Lema 9** — **factor de merma** del crecimiento honesto | `k = 793` |

El 793 no sale de ninguna probabilidad: sale de exigirle `0,01` a un *cociente de crecimiento*. El
paper lo avisa: *«does not vanish exponentially fast with k… we leave this challenge to future
work»*.

Y `k` tiene un compromiso de **dos lados** que la ec. (2) ignora: subir `k` baja la merma (bueno)
pero sube la ventaja de *freeloading*, que el propio paper acota en **`3k`** (Lema 10:
*«up to 3k blocks which it can freeload»*, `score(C) ≤ score(B) + 3k`).

Con `δ(k) = 2c/(k+2c)` **autoconsistente** y ventaja inicial `3k` (`α = 0,25`, `t = 600 s`):

| `k` | 18 | 22 | **24** | **25** | 30 | 793 |
|---|---:|---:|---:|---:|---:|---:|
| `δ` | 0,308 | 0,267 | 0,250 | **0,242** | 0,211 | 0,010 |
| reversión | 2,45·10⁻⁷ | 7,87·10⁻⁸ | 6,59·10⁻⁸ | **óptimo** | 1,11·10⁻⁷ | **1,000** |

**`k = 25`.** Y la ronda 3 derivó `k = 24` por otra vía (punto fijo del retarget): dos caminos
independientes, el mismo valor.

> ⚠️ **Corregido el 2026-09-08 (`dag-poas-delta-real.md`): `k = 30`.** La tabla de arriba usa `δ = 0,2424`
> con `λ = 1/s`, pero bajo el sesgo sostenido del retarget (ronda 3 §7) la tasa real se infla a
> `λ_real = k/(k−2D)` y `δ_real = 2Dλ_real/(k+2Dλ_real)` = **0,320 a `k=25`**. Con `(λ_real(k), δ_real(k))`
> autoconsistentes, el óptimo de la reversión a 600 s es **`k = 30`** (`4,3·10⁻¹⁰`), el punto fijo del
> retarget lo admite (`k_Poisson = 22`), y `δ_real = 0,267`. Los dos umbrales mejoran ~2 puntos.

> **`k = 793` no es «la opción conservadora»: es la que deja mudo el teorema.** A `k=793` la cota de
> Prop. 8 permite 2 379 bloques de ventaja y la garantía no dice nada por debajo de 3,2 h.
> **Matiz:** `3k` es una **cota superior**, así que eso no prueba que el protocolo falle a `k=793`,
> prueba que **se pierde la garantía**. Basta para descartarlo.

### 1.2 · `I = 2 490 s` — del *steering*

Valor de elegir entre `m` entropías, como fracción del ingreso de la época (D9, ronda 4 §5):

```
g = c_m / √(α·λ·I)        c_4 = 1,029
```

Va como **`1/√I`**: **épocas cortas ⇒ más steering.**

| `I` | 16 s | 80 s | 249 s | **2 490 s** |
|---|---:|---:|---:|---:|
| `g` | 44,8 % | 20,1 % | 11,4 % | **3,6 %** |

> ✅ **DIMENSIONADAS CONTRA SU COTA (D9-f).** «`m` sin cota» era una sobreafirmación mía: `c_m ≃ √(2 ln m)`,
> luego **`I ∝ 2 ln m` y `F ∝ ln m`** (`m = 10⁴` ⇒ `F = 143 h`, no ∞). Con el ancla por `slot`: **medido**
> `m = 2,54` ⇒ `I = 4 200 s (1,17 h)`, `F = 5,3 h`; **garantizado por construcción** `m ≤ 1 + λ·S_max[s] = 151`
> ⇒ `F ≤ 68,5 h` (`S_max = 150 s`), o `35-41 h` con `S_max = 20-30 s`. **`c` ya no existe**: el ancla no
> es un contador. Los 2 490 s / 3,2 h / 3 330 s / 4,2 h anteriores quedan como registro.

`I = 2 490 s` es el punto donde `g = 3,6 %`, el nivel que la ronda 7 declaró aceptable
(*«del orden del 3 %, en ≤ 22 % de las épocas»*).

> **Dos precisiones (2026-09-08).** (i) El «≤ 22 % de las épocas» **no es de este diseño**: la ronda 4
> lo midió para su mecanismo de voto (`dag-poas-voto-auditoria.md` L179, `voto_epifenomeno.py`,
> `α=1/3`, `V=120`, `m=2`: el atacante desplaza al ganador en ≥22 % de las inyecciones). Con el ancla
> en la cadena seleccionada el cualificador equivalente es la `m` con billetes genuinos que mide
> D9-c (A1), no ese 22 %. (ii) La fórmula completa de la ronda 4 es `g = c_m√(αλn)/(αλI)` con
> `n ≤ I` los slots que el atacante evalúa por flujo (L197-199): el `g = c_m/√(αλI)` de arriba es
> el caso `n = I`, es decir, la **cota superior**. Los números de esta sección son conservadores.

### 1.3 · `F = 3,2 h` — de la ventana de predicción

BDK+19 §2 define la ventana `W` en bloques y advierte:

> *«If the prediction window **W** is greater than the confirmation-depth **κ**, then the following
> **covert (undetectable)** attack becomes possible»* — ataques *«fatal»*, ejecutables sobornando
> *«an arbitrarily small total stake»*.

`W/κ = 1 + I/F`. Es `> 1` siempre (identidad: `I > 0`), así que la magnitud es lo único gobernable:

| `F` | 1 000 s | 1 h | **3,2 h** |
|---|---:|---:|---:|
| `W/κ` | 3,49 | 1,69 | **1,22** |

**Pinza:** el steering quiere `I` grande; la ventana la quiere pequeña. Solo se resuelve con `F`
grande. **Tres restricciones independientes —steering, ventana y la rama `k=793` de la ec. (2)—
convergen en `F ≈ 3,2 h`.** La ronda 7 ya lo había calculado en su §5.2.

**`F` es el límite de reorg, no el tiempo de confirmación.** Se confirma en minutos (§3).

### 1.4 · `c` — ⚠️ OBSOLETA (D9-f): con el ancla por `slot` no hay contador; la época es `I` en índices de PoT

`c` no es un parámetro libre: es `I` en unidades del ancla. A `q = 1`:

- **azules** (ancla `blue_score`, R-FIN-1 vigente): `c = I·λ_azul ≈ 2 490 × 0,758 ≈ 1 890` — **provisional**, `I` no derivada
- (anclas refutadas, solo para comparar: índices de orden `I·λ = 2 490`; posiciones de cadena `I·λ_chain = 500`)

---

## 2 · El algoritmo

Constantes: `k = 30`, `q = 1` **decidido**, `S_max ∈ [20, 150] s` (elección), `W_RETARGET ≥ 3 083`, **`τ = 1 s` (A″, decidido)** — y **`I = 4 200 s`, `F = 5,3 h` medidos** contra la familia de D9-e, **`F ≤ 68,5 h` garantizado** por construcción (`S_max = 150 s`). **No hay `c`.**
(§6). Estructura: GHOSTDAG (`rusty-kaspa @ c338d495`) con `blue_work = Σ⌊2^128/(SR+1)⌋` sobre azules,
desempate por menor `solution_distance` y nunca por hash, unicidad de billete **U3′-filtro** y **U2**
(R-FIN-11; corregidas tras D9 ronda 8, que refutó la forma posproceso), retarget por controlador multiplicativo sobre azules, un solo flujo de PoT
por gossip.

**R-FIN-1 · Inyector por `slot` — CUARTA ANCLA (2026-09-08, tras D9-f).**
`I_j(B) :=` el bloque de la cadena seleccionada de `B` con **menor `blue_work` entre los de `slot ≥ T_j`**, con
`T_j = j·I` un **índice de PoT** fijo (R-FIN-13). Único por cadena, siempre existe (si ningún bloque de cadena
tiene `slot ∈ [T_j, T_j + S_max)`, el primero posterior), sin campo de cabecera, función de `past(B)`.

> **Cota E, por construcción (D9-f, DEMOSTRADO el enunciado):** por R-FIN-1a, `slot(I_j) ∈ [T_j, T_j + S_max)` sin
> ninguna hipótesis estadística; como `slot` lo fija el PoT y `λ` el retarget, **`m ≤ 1 + λ·S_max[s]`** (PLAUSIBLE
> el conteo). Medido, mismas semillas y familia que D9-e: **`m = 2,54`** donde `blue_score` daba 6,05; con
> retención 3,64 ↔ 8,54. **Prop. 7 la cubre** (Lema A4-slot, 13 110/13 110, sin necesitar monotonía).

> **Historial de anclas.** (1) Índice del orden total: **cuenta rojos** (D9-b). (2) Posición de cadena: **cuenta
> saltos** (D9-c). (3) `blue_score`: cuenta azules, **no es un reloj** — el atacante fabrica bloques en la banda
> `[T, T+k]` cuando quiere; cota solo por finalidad, `F ≈ 227 h` (D9-f). (4) **`slot`: reloj infalsificable.**
> La lección: el inyector se lee de una magnitud que el atacante **no puede fabricar a coste cero**.

**R-FIN-12 · Reglas de Kaspa, adoptadas COMPLETAS. (Corregida tras D9-c A4/A5.)** No solo los dos
límites (`max_block_parents = 15`, `mergeset_size_limit = 180` a `k=30`), sino también:
- **`pick_virtual_parents`** con presupuesto (`virtual_processor/processor.rs:1053`, `:974`): un honesto
  **nunca** emite `MergeSetTooBig` — el griefing no existe *si se adopta el algoritmo*.
- **`merge_depth_bound`** y **`pruning_depth`** (`params.rs:189`). **Corrección D9-f:** `merge_depth_bound` acota lo que un bloque **fusiona** (`check_bounded_merge_depth` recorre solo `mergeset_reds`, `post_pow_validation.rs:85`), **no de dónde cuelga**; lo que acota de dónde cuelga es la **finalidad** (`processor.rs:1033`), y es la finalidad la que acota la retrolectura de U2.
- **El `shuffle` de `pick_virtual_parents`** (`processor.rs:1069-1089`: mitad por `blue_work`, resto **al azar** «to ensure diversity between nodes»): **obligatorio**, no opcional. D9-d A3.1: el daño no viene del presupuesto de mergeset sino del tope de 15 padres frente a ~550 puntas; **sin el shuffle, 14-21 bloques honestos quedan fuera del DAG para siempre**.

**R-FIN-1a · Monotonicidad de slot en la cadena seleccionada — NO ESTRICTA (D9-f B0).** `slot(sp(B)) ≤ slot(B)`.
Un bloque cuyo padre seleccionado tenga slot mayor o igual es inválido. (D8 ronda 7, ataque A1;
D9 demostró que `≤` reabre el ataque.) **Se conserva:** aunque el inyector ya no se lea de la cadena
seleccionada, la monotonicidad sigue siendo necesaria para R-FIN-7.
**Y cota superior en SEGUNDOS: `slot(B) − slot(sp(B)) ≤ S_max`, con `S_max ∈ [20 s, 150 s]`.** D9-f B4bis: `S_max` **se co-determina con el steering** (`m ≤ 1 + λ·S_max[s]`): `≥ 20 s` por el gap medido de cadena (15,9 s a `α=0,40`), `150 s` para tolerar particiones con `f ≥ 0,09` (D9-d) a costa de garantía `F ≤ 68,5 h`; `20-30 s` da `F ≤ 35-41 h`. **Elección con etiqueta.**
Con `τ = 1 s` la versión estricta invalidaría el 23,7-29,3 % de las aristas de cadena bajo ataque (D9-f B0); con `τ ≈ 0,1 s` y `≤` queda el 4,1 %, que la relajación absorbe. `S_max` cubre además la cola de operación normal a `10⁻¹²` y deja el DoS de verificación de PoT en ×60 (D9-d).

**R-FIN-2 · Entropía e instante.** `entropía_j = blake3(chunk(I_j) ‖ pot_output(I_j))`;
`t_j = slot(I_j) + L`. Antes de `t_j` la entropía no se mezcla, así que durante `[slot(I_j), t_j)`
todos los candidatos a `I_j` producen el mismo flujo: **una sola lotería**.

**R-FIN-3 · Identificador de flujo.** `flujo(B, s) = H(flujo(B, t_{j−1}) ‖ entropía_j ‖ t_j)` para la
última inyección con `t_j ≤ s`. Dos linajes con las mismas parejas `(entropía, t)` son el mismo flujo.

**R-FIN-4 · Validez absoluta.** `B` es válido si su solución verifica bajo `flujo(B, slot(B))`, su
justificación de PoT cubre desde el slot futuro de `sp(B)` hasta `slot(B)` bajo ese flujo, todos los
bloques de `past(B)` son válidos, y cumple R-FIN-5. Función de `past(B)` y de nada más.

**R-FIN-5 · Pasado consistente de flujo.** Para todo `X ∈ past(B)`: `flujo(X, slot(X)) = flujo(B,
slot(X))`. Un bloque **MUST NOT** referenciar un bloque de otro flujo. Comprobación **estructural**,
antes de tocar ningún PoT: **un nodo honesto jamás verifica el PoT de un flujo ajeno.**

**R-FIN-11 · Unicidad de billete: U2 + U3″ DINÁMICA. (Corregida tras D9-c A3.)**
Identidad `(public_key, sector_index, history_size, chunk, slot)`.
- **U2:** misma identidad con `X ∈ past(B)` ⇒ `B` **inválido**. Consenso, no filtro de retransmisión.
- **U3″ dinámica:** una copia es candidata a azul solo si su identidad **no es azul en `past(sp)` ni
  ha sido ya coloreada de azul en este mismo mergeset** (el orden del mergeset es determinista:
  `sort_blocks` por `(blue_work, desempate)`, luego sigue siendo función de `past(B)`).

> **Por qué no U3′-filtro.** Miraba solo `past(sp)`: publicando las copias en el **anticono del `sp`**
> ninguna tiene su original en `past(sp)` y **todas son candidatas** — `filter` ≡ GHOSTDAG sin regla.
> Un billete = 14 azules (`max_block_parents−1`), 3 de 4 puntas honestas rojas (D9-c, contraejemplo
> determinista `r8c_a3_filtro.py`). U3″ deja 1 azul por identidad y 0 honestos rojos de más.
> **VERIFICADA en simulación de eventos (D9-d A3):** peor `δ_ef = 0,129` con U3″ (cotas 0,2105 / 0,267), frente a **0,379** con U3′-filtro. Que no reabra otra cosa: PLAUSIBLE.

**R-FIN-13 · Ventana del retarget. (NUEVA, 2026-09-08.)** `W_RETARGET ≥ 3 083 slots` con `γ ≤ 0,25`
(o `W ≥ 12 331` con `γ ≤ 1`). Es lo que hace que `φ_c`, probado sobre **conteo**, valga sobre
**peso** (`blue_work = Σ w(SR)`): la discrepancia sobre el horizonte `F` queda `< 1 %` y el umbral se
mueve `< 0,4` puntos. Derivación y tabla en `dag-poas-empalme-peso.md`. Es una elección de diseño,
con etiqueta.
**`slot` es el ÍNDICE DE PoT, no el sello de tiempo de la cabecera** (D9-e LAGUNA 5, cerrada): con el sello el
retarget es falsificable por *timewarp* y reaparece la palanca de heredar el `SR` de otra ventana (A1b). `N_obs`
cuenta azules del flujo canónico en la ventana de `W` índices de PoT.

**R-FIN-6 · Color.** El k-cluster de GHOSTDAG con `k = 25`, sin condición de color por flujo
(R-FIN-5 la hace innecesaria). «Cadena seleccionada ⊆ azules» se conserva —U3′ lo respeta, U3 no.

**R-FIN-7 · Finalidad en tiempo, sin `exit`.** Un nodo **MUST NOT** reorganizar su cadena
seleccionada por debajo de `F` segundos de slot; una punta que lo exigiera se **ignora**, nunca
apaga el proceso. Sustituye a C-REORG-07 en el DAG.
> **Reescrita tras D9-d A4.** «Tolera cualquier partición `< F`» es **falso** con `S_max` finita: la
> letra exigiría `S_max ≥ F = 11 520` (DoS ×4 608). **Tolerancia real: una partición de hasta `F`,
> siempre que el lado conserve ≥ 9 % del espacio** (`S_max=150`). No existe `S_max` que cumpla
> R-FIN-1a y la letra antigua de R-FIN-7 a la vez — **contradicción DEMOSTRADA**.
> **Escala (D9-f B0):** `F` se expresa en **segundos** (`F = 5,3 h` medido; `≤ 68,5 h` garantizado), **no en slots**:
> «slot» aparecía en R-FIN-1a, R-FIN-7 y R-FIN-13 con tres escalas incompatibles. Punto viable: **`τ ≈ 0,1 s`**
> (10 slots de PoT por intervalo de bloque). **LAGUNA CERRADA (2026-09-08, fuente):** en Autonomys mainnet
> `SLOT_DURATION = 1000` ms, `SLOT_PROBABILITY = (1, 6)` (un bloque cada 6 slots), `BLOCK_AUTHORING_DELAY = 4`,
> `POT_ENTROPY_INJECTION_INTERVAL = 50` bloques (≈ 300 s), `POT_ENTROPY_INJECTION_LOOKBACK_DEPTH = 2`,
> `POT_ENTROPY_INJECTION_DELAY = 15` slots, con `const_assert!(INTERVAL > DELAY)` y `const_assert!(DELAY >
> AUTHORING_DELAY + 1)` (`/home/katana/zeo/fuentes/subspace/crates/subspace-runtime/src/lib.rs:145-165`,
> `subspace-runtime-primitives/src/lib.rs:48,147`). **Autonomys tiene 6 slots por bloque con τ = 1 s;** ZEROX
> a `λ = 1 bloque/s` con `τ = 1 s` tendría **1 slot por bloque** — justo el régimen donde R-FIN-1a estricta
> invalida el 24-29 % de la cadena (D9-f B0). **Elección real:** `τ ≈ 0,1-0,17 s` (6-10 slots por bloque, la
> proporción de Autonomys) **o** `λ ≈ 1/6` bloques/s. Comparación directa: Autonomys `I = 300 s`, `L = 15 s`,
> lookback 2 intervalos; ZEROX `I = 4 200 s`, `F = L = 5,3 h`. **El «11 s» que citaban siete rondas es**
> **`DELAY − AUTHORING_DELAY = 15 − 4 = 11` slots.**
> **Las dos ramas, con número (`verif_tau_vs_lambda.py`, óptimo autoconsistente con punto fijo de Poisson):**
> (A) `λ = 1/s`, `τ ≈ 0,1-0,17 s` (6-10 slots/bloque): `k* = 29`, `δ_real = 0,276`, reversión a 600 s
> **`4,3·10⁻¹⁰`**, 21,5 GB/año, latencia 1 s; coste: ×6-10 slots de PoT por segundo (justificación y
> verificación de PoT, y el DoS de `S_max` se mide en slots de PoT). (B) `λ = 1/6`, `τ = 1 s` (la de Autonomys):
> `k* = 7`, `δ_real = 0,190`, reversión a 600 s **`1,3·10⁻²`** (600 s son ~100 bloques), 3,6 GB/año (cliente
> ligero 850× Bitcoin en vez de 5 100×), latencia 6 s. **(B) tira la ventaja de reversión del DAG (7 órdenes)**
> y obliga a rederivar `I`, `F`, `m` con `λ = 1/6`. **Recomendación (autónoma): (A).** Es una bifurcación de
> Katana. **DECIDIDO por Katana (2026-09-08): rama (A).** Y dentro de (A), la variante **(A″): `λ = 1/s`, `τ = 1 s`,
> R-FIN-1a `≤`** — medida (`research/scripts/verif_a2prima.py`, instrumento de D9-f, 12 semillas, adversario del
> paper): con `≤`, **0 violaciones** de R-FIN-1a a `τ = 1 s` en `α = 0 / 0,25 / 0,40`; lo que D9-f B0 contaba
> como «invalida 24-29 %» son **empates** (0,6 % / 24,4 % / 30,1 %), que `≤` admite; salto máximo 10,9 s ≪
> `S_max`. Y `m = 2,54` ya estaba medido **a `gran = 1`** (`salida_b1_gran1.txt`). Coste de PoT (128 B/slot,
> ronda 2 L425): **(A″) 1 slot/s, 4,0 GB/año** — el de Autonomys —; `τ = 1/6 s`: ×6, 24,2 GB/año; `τ = 0,1 s`:
> ×10, 40,4 GB/año. **(A″) domina.** Residuo declarado: con 1 slot por bloque varios bloques de cadena
> comparten slot; el ancla los resuelve por `menor blue_work` (bien definido, Lema A4b), y el steering está
> medido en ese régimen.
> **Coste del slot, con fuente:** `pot_slot_iterations = 206 557 520` en mainnet, *«About 1s on 6.2 GHz Raptor Lake
> CPU (14900KS)»* (`subspace-node/src/chain_spec.rs:128-130`). Es el coste del **timelord** por slot; el de
> **verificar** (`aes::verify_sequential`, paralelizable por `PotCheckpoints`) se está midiendo en esta máquina
> (`cargo bench -p subspace-proof-of-time --bench pot`). De él dependen `C-NET-03/04` y el ×60 de `S_max`.

**R-FIN-8 · Rojos.** Ni la coinbase ni las transacciones de un bloque rojo se aplican al estado.
Cierra la inflación ×10 (ronda 1) y el espacio de bloque gratis (ronda 3). **Coste medido:**
`P(bloque honesto acabe rojo) = P(Poisson(2λΔ) > k) = 1,2·10⁻⁶` a `q=1` — ~37 huérfanos honestos al
año de 31,5 M bloques, frente al **80 %** que pierde una cadena lineal a la misma tasa.

**R-FIN-9 · Recalibración del PoT.** Los cambios de `slot_iterations` se leen también del índice `c·j`
y se aplican en `t_j`.

**R-FIN-10 · `C-EXP-04` sobre la cadena seleccionada. (Corregida tras D9-e A4b.)** `altura := blue_work` de la
cadena seleccionada —**no** `idx` ni `blue_score`—, porque `blue_work` es monótono bajo ancestría con peso real
(Lema A4b) y `blue_score` no lo es. `altura_ploteo ≤ blue_work(punta) − F·λ·w̄` para que el mapeo sea inmutable.
Responde a la SOSPECHA de la ronda 2 con profundidad, ahora sobre la magnitud monótona. `VIDA_MINIMA` y
`DISPERSION` se rederivan en tiempo.

---

## 3 · Lo que compra

| | DAG (`k=25`, `q=1`) | Cadena lineal (`q=120`) |
|---|---:|---:|
| Riesgo de reversión a **600 s**, `α = 0,25` | **6,59·10⁻⁸** | **0,140** |
| Ventaja | **6,3 órdenes de magnitud** | — |
| Latencia a inclusión | 120 s | 120 s |
| Huérfanos honestos | ~0 (`1,2·10⁻⁶`) | 80 % a la misma tasa de bloques |
| Varianza del granjero pequeño | `/q` | — |

Cota autoconsistente: crecimiento honesto `(1−α)(1−δ)` con `δ = 0,242`, ventaja inicial `3k = 75`.
**No** la fórmula lineal (que daría `4,6·10⁻³⁷` y es la columna equivocada de `reversal.py`).

Y **no toca el PoT ni la prueba de espacio**: cambia de dónde se lee el inyector y cuándo se aplica.

---

## 4 · Lo que cuesta, sin rodeos

1. **Cliente ligero: no sobrevive.** GHOSTDAG no tiene SPV; `blue_work` en cabecera es una
   afirmación. A `q = 1`, 17,5 GB/año de cabeceras solo para colorear. **Estructural: no lo arregla
   ningún parámetro.** Es el coste más grande.
2. **Lookahead 3,89 h**, margen **10,6×** frente a `A*` (41,1 h, escenario que favorece al atacante)
   y **1,05×** frente a un plotter hipotético 10× mejor que la extrapolación. **Ese 1,05× es el
   número delgado del diseño.**
3. **`W/κ = 1,22`:** sigue dentro del régimen que BDK marca, aunque un 22 % en vez de un 250 %. **Es
   una elección, no una derivación**, y hay que escribirla con esa etiqueta.
4. **Umbral ~40,7 %** (`Lema 9 ⊗ φ_c`, `δ = 0,242`). Menor que el 50 % de Nakamoto. Chia está en
   40,5 %. Es la factura de la familia PoST.
5. **Tolerancia a particiones = `F` = 3,2 h.** Más allá, split permanente entre flujos.
6. **Cabeceras y coinbases** a `q = 1`: 17,5 GB/año y 31,5 M salidas/año (~1,3 GB/año de UTXO).
7. **Rojos sin aplicar:** una transacción que solo esté en un bloque rojo hay que reincluirla.
8. **Previsión propia:** todo granjero conoce sus victorias `L` por adelantado. Sin efecto conocido
   en consenso; sí en mempool.
9. **Poda:** sin niveles de PoW. Sigue sin resolver.

---

## 5 · Lo que NO está demostrado

1. **Prop. 7 y Def. 2 están probadas sobre GHOSTDAG *puro*.** Esta propuesta añade U3′, R-FIN-5 y
   R-FIN-8. Que el orden total siga convergiendo bajo las tres **no está comprobado**. Es la deuda
   principal, y es la misma clase de error que la ronda 1 ya señaló sobre U3: *«el coloreado sigue
   siendo función determinista del DAG, pero **no es el objeto sobre el que está el teorema**»*.
2. **`c_a = c_h` en unidades de índice de orden.** La ronda 3 lo demostró (BDK Lema 13) contando
   sobre *la cadena seleccionada del propio pasado*; el índice del orden cuenta otra cosa.
   **Consecuencia acotada:** las tres lecturas dan umbrales de 40,7 %, 41,2 % y 41,9 % — la laguna
   mueve **1,2 puntos**, no decide.
3. **El empalme `φ_c` ⊗ `δ` de GHOSTDAG:** `φ_c` está probado sobre **conteo**, `blue_work` es
   **peso**. Sin demostración. Cota conservadora: usar el valor de conteo.
4. **Desplazamiento de índice por rojos cerca de la punta:** acotado por `α·λ` y de la clase que
   `φ_c` tarifa, pero sin cerrar. Responde a la SOSPECHA de la ronda 2.
5. **Que `3k` sea la ventaja real y no solo una cota superior.** Todo el cálculo de `k` usa la cota.
6. **El presupuesto económico:** precios supuestos; ignora el almacenamiento de ganadores.
7. **`Dmax` sigue sin medir.** Todo usa `Δ = 4 s`, y `λ_chain`, `δ`, `I` y `F` dependen de él.
8. **Timelord único (B7):** vulnerabilidad de vivacidad, sin fallback. Informe:
   `timelord-redundancia-informe.md`.

---

## 6 · `q = 1` — DECIDIDO por Katana, 2026-09-08

`λ = 1/q` con slot de 1 s, así que el tiempo entre bloques **es `q` segundos**. (La ronda 7 escribe
«latencia a inclusión `120/q` s»: es un desliz de unidades — la ronda 1 lo dice bien, `120/q` es el
**factor de mejora** sobre la lineal, no los segundos.)

| | **`q = 1`** | `q = 10` | lineal (`q=120`) |
|---|---:|---:|---:|
| Tiempo entre bloques | **1 s** | 10 s | 120 s |
| Cabeceras/año | 21,5 GB | 2,2 GB | 0,18 GB |
| Frente a Bitcoin (4,2 MB/año) | 5 100× | 510× | 44× |
| Huérfanos honestos | 1,2·10⁻⁶ | 1,8·10⁻⁴ | 80 % |
| **`g` (steering) con `I = 2 490 s`** | **3,6 %** | **11,4 %** | — |
| **`I` para `g = 3,6 %`** | **2 476 s** | **24 758 s (6,9 h)** | — |
| **`W/κ` con `F = 3,2 h`** | **1,21** ✓ | **3,15** ✗ | — |

**Por qué `q = 1` y no `q = 10`.** `q = 10` **no compra lo que parecía comprar**: no salva el cliente
ligero —510× Bitcoin sigue sin ser una cartera de móvil— y **sí rompe el punto de diseño**, porque
`g = c_m/√(αλI)` con `λ = 1/q` triplica el steering, y corregirlo exige épocas de 6,9 h que disparan
`W/κ` a 3,15. Paga los dos costes y no cobra el beneficio.

**Corrección de dato:** los 17,5 GB/año que citaba la ronda 7 son la cota con **un solo padre**. Con
`λΔ = 4` puntas simultáneas la cabecera lleva ~4 padres (32 B cada uno): **~683 B y 21,5 GB/año.**

### Lo que se acepta al elegir `q = 1`, escrito sin adornos

**Ninguna cartera de ZEROX podrá verificar sus propios pagos sin confiar en un servidor o correr un
nodo completo.** SPV sin confianza no existe en GHOSTDAG y no lo arregla ningún parámetro.

El modelo pasa a ser el de Zcash, que **ya estaba en el plan de crates** (`zx-lightwalletd`,
`zx-scanner`): la cartera habla con un servidor que hace el trabajo pesado. El servidor **no puede
robar** —no tiene las claves— pero **sí puede mentir**: ocultar pagos o afirmar confirmaciones
falsas.

**Y sí: quien no quiera confiar puede montar su propio servidor.** Es cierto y es la respuesta
correcta. Pero conviene escribir su precio, porque *«monta tu propio servidor»* significa
**«corre un nodo completo»**:

| Suelo de la autosoberanía | Coste |
|---|---|
| Bitcoin, SPV en un móvil | **71 MB**, sin confiar en nadie |
| ZEROX `q=1`, lightwalletd propio | **nodo completo: >21,5 GB/año, 59 MB/día solo de cabeceras, coloreado GHOSTDAG a 1 bloque/s, 24/7** |

Las dos opciones son **sin confianza**. Lo que cambia es el **precio de entrada**: de un móvil a una
máquina permanente. Es una propiedad de descentralización (P-036), no un detalle de producto, y hay
que anotarla como tal. La experiencia de Zcash es el dato relevante: casi nadie corre su propio
`lightwalletd`.

---

## 7 · Lo que D9 y D8 tienen que intentar refutar

**Criterio de aceptación, obligatorio para toda simulación adversarial de esta ronda:**

> **El resultado debe cambiar al cambiar `α`.** Si con `α = 0` y con `α = 1` sale lo mismo, no es una
> simulación: es una tautología. Ese solo criterio habría cazado los cinco defectos de la auditoría
> de la ronda 7 (`r7_q1`, `r7_q7`, `r7b_q1`, `r7_q2`, `d8b_b3`). El detector automático está en
> `/tmp/d9-ronda7/AUDITA_SCRIPTS.py`; pásalo antes de entregar.

En orden de importancia:

1. **§5.1 · ¿Sobrevive Prop. 7 a U3′ + R-FIN-5 + R-FIN-8?** Es lo que sostiene R-FIN-1. Si cae, cae
   la propuesta.
2. **§5.2 · `c_a` en unidades de índice de orden.** Rehacer BDK Lema 13 con el ancla nueva.
3. **§5.4 · Desplazamiento de índice por rojos** cerca de la punta, con la SOSPECHA de la ronda 2
   delante.
4. **Acuerdo honesto sobre `I_j` en `t_j`** — con dos vistas **distintas** de verdad, no una
   compartida (el defecto de `d8b_b3`).
5. **La derivación de `k = 25`:** ¿es `3k` alcanzable, o muy pesimista? ¿Cambia el óptimo con `α`
   distinto de 0,25?
6. **El margen de 1,05×** frente al plotter 10×: ¿aguanta si se incluye el almacenamiento de
   ganadores?
7. **`W/κ = 1,22`:** ¿porta el ataque de soborno de BDK a PoAS, dado que U3′ impide equivocar y
   R-FIN-7 impide reorgs por debajo de `F`?
