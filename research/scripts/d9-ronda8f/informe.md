# D9-f · ¿Tiene `m` cota superior? — informe de la ronda 8f

**Fecha:** 2026-09-08 · **Agente:** D9-f (refutación matemática) · **Directorio:**
`research/scripts/d9-ronda8f/`

> **Volcado incremental.** Este fichero se escribe a medida que salen los números. Lo que
> está aquí está ejecutado; lo que falta, se dice que falta.

---

## 0 · El resultado que reencuadra la pregunta — y que nadie ha escrito en cinco rondas

Antes de medir nada. La pinza de D9-d (`informe.md` L297, `r8c_steering.py`) es

```
g = c_m / √(αλI) ≤ 3,6 %        F = I/(W/κ − 1) = I/0,22
⇒  I = (c_m/g)² / (αλ)
```

y `c_m = E[máx de m normales estándar]`. Para `m` grande, `c_m ≃ √(2 ln m)`. Por tanto

```
I  ∝  c_m²  ≃  2 ln m          F ∝ ln m
```

**`I` y `F` crecen con el LOGARITMO de `m`, no con `m`.** Ejecutado
(`r8f_lib.constantes`, `c_m` de `r8c_steering.py`, contrastado con `c_2 = 0,564`,
`c_4 = 1,029` publicados; peor `α = 0,10` como en D9-d):

| `m` | `c_m` | `I` | `F` |
|---:|---:|---:|---:|
| 2,33 (D9-d) | 0,657 | 3 333 s (0,93 h) | **4,21 h** |
| 4 (publicada) | 1,029 | 8 176 s (2,27 h) | 10,32 h |
| 5,77 (D9-e) | 1,243 | 11 926 s (3,31 h) | **15,06 h** |
| 10 | 1,539 | 18 270 s (5,07 h) | 23,1 h |
| 30 | 2,043 | 32 198 s (8,94 h) | 40,7 h |
| 100 | 2,508 | 48 519 s (13,5 h) | 61,3 h |
| **151** (cota POR CONSTRUCCIÓN del ancla `slot`, §B4) | 2,652 | 54 248 s (15,1 h) | **68,5 h** |
| 1 000 | 3,241 | 81 072 s (22,5 h) | 102 h |
| 10 000 | 3,852 | 114 467 s (31,8 h) | 145 h |
| **815 617** (punto fijo determinista del ancla `blue_score`, §A3 Cota D) | 4,822 | 179 435 s (49,8 h) | **227 h** |

**Consecuencia:** la frase *«`m` no tiene cota superior conocida ⇒ `I`, `c`, `F` no están
dimensionadas»* es **literalmente cierta y prácticamente engañosa**. Para que `F` se
dispare a lo inaceptable hace falta que `m` crezca **exponencialmente**. La cota
**por construcción** del ancla `slot` —`m ≤ 1 + λ·S_max[s] = 151`, derivada abajo sin
ninguna simulación— ya dimensiona las tres constantes: `I = 15,1 h`, `F = 68,5 h`. Feo, pero
**finito, calculable y ajustable con `S_max`**. Y con el ancla `blue_score` vigente la cota
determinista es **`F ≈ 227 h ≈ 9,5 días`**: finita también, pero mala.

Lo que hay que decidir, entonces, no es «¿existe cota?» sino **«¿es la cota lo bastante
apretada para que `F` sea aceptable?»**. Esa es la pregunta que este informe contesta.

**Etiqueta: DEMOSTRADO** (aritmética sobre la fórmula que la propuesta ya usa; ejecutado en
`r8f_c_constantes.py`, salida en `salida_c.txt`).

---

## A1 · La `m` medida es monótona en la familia — por eso sube cada ronda

`m` medida por D9-c/d/e es

```
m(T) = | U_{e ∈ F} { seed(ancla(T, e)) } |
```

sobre una **familia dirigida `F` de estrategias**. Es una **unión**: `F ⊆ F′ ⇒ m(F) ≤ m(F′)`.
Que subiera 5,0 → 3,03 → 5,77 no es contradicción ni descubrimiento: es que las tres
familias son distintas y ninguna contiene a las otras. **La pregunta bien puesta es si la
sucesión `m(F_n)` CONVERGE cuando `F_n` crece por un parámetro.**

Instrumento: `r8f_a1_saturacion.py`, familias **anidadas por construcción** en tres
parámetros (`D` profundidad de `retro`, `W` semiancho de la ventana de eventos,
`C` copias del mismo billete). Cada nivel declara

- `nuevas` — estrategias que ese nivel **ejecuta por primera vez** (cobertura de rama: si
  es 0, el nivel no corrió y su fila **no dice nada**);
- `aporta/21` — en cuántos de los 21 umbrales ese nivel añadió al menos un `seed` **nuevo**.

`nuevas > 0` con `aporta = 0` es **saturación medida**.

### A1.0 · Un error mío, encontrado y corregido antes de firmar nada

Mi primera pasada del barrido `D` (`salida_a1_D.txt`, `P = 30`, horizonte 260 s) daba
saturación limpia en `D ≥ 32`… y era **artefacto**. `r8c_sim.py` implementa `retro n` como
`ch[max(0, len(ch) − 1 − n)]`: cuando `n` supera la longitud de la cadena **en el instante
del ataque**, todos los niveles apuntan a **génesis** y son literalmente la misma
estrategia. Con `P = 30` esa longitud es **31**, así que `D = 32, 64, 128, 256` eran un
solo experimento repetido cuatro veces. El contador `nuevas` no lo detectaba: las
estrategias son diccionarios **distintos**, aunque produzcan el **mismo DAG**.

Corregido: el barrido válido es `P = 120`, horizonte 700 s, donde la cadena en `tP` mide
**121** posiciones, y toda fila con `D ≥ |cadena(tP)|` va marcada **`DEGEN`** y no cuenta.
`salida_a1_D.txt` se conserva como registro del error.

### A1.1 · Barrido `D` (profundidad de `retro`) — `salida_a1_D_P120.txt`

`P = 120`, horizonte 700 s, `W = 30 s`, sin copias, 12 semillas, `|cadena(tP)| = 121`.

| `D` | `α=0` | `α=0,10` | `α=0,25` | `α=0,40` | `nuevas` (α=0,40) | `aporta` (α=0,40) |
|---:|---:|---:|---:|---:|---:|---:|
| 0 | 1,000 | 1,401 | 1,591 | 1,548 | 319 | 21,00 |
| 1 | 1,000 | 2,198 | 2,496 | 2,837 | 307 | 18,17 |
| 2 | 1,000 | 2,329 | 2,615 | 3,075 | 307 | 4,42 |
| 4 | 1,000 | 2,333 | 2,687 | 3,238 | 307 | 3,42 |
| 8 | 1,000 | 3,270 | 3,230 | 3,790 | 307 | 11,58 |
| 16 | 1,000 | 3,639 | 4,385 | 4,754 | 307 | 18,67 |
| **32** | 1,000 | **3,639** | 4,770 | **5,571** | 307 | 14,25 |
| **64** | 1,000 | **3,639** | **4,770** | **5,571** | **307** | **0,00** |
| 128 `DEGEN` | — | — | — | — | — | — |
| 256 `DEGEN` | — | — | — | — | — | — |

**`m` SATURA en `D`.** El nivel `D = 64` ejecuta **91 / 191 / 307 estrategias nuevas** (una
por bloque del atacante de la ventana, más las globales) y **no aporta ni un `seed` nuevo
en ninguno de los 21 umbrales, en ninguna de las 12 semillas, en ninguna `α`**. Y el nivel
no es degenerado: `64 < 121 = |cadena(tP)|`. **Cobertura de rama satisfecha.**

`D = 4` (la familia de D9-d) da 2,333 a `α = 0,10`, que es la **2,33 de D9-d**: el
instrumento reproduce.

### A1.2 · Barrido `W` (ventana de eventos) — `salida_a1_W.txt`

`P = 30`, horizonte 260 s, `D = 16`, sin copias, 12 semillas.

| `W` (s) | `α=0` | `α=0,10` | `α=0,25` | `α=0,40` | `nuevas` (α=0,25) | `aporta` (α=0,25) |
|---:|---:|---:|---:|---:|---:|---:|
| 5 | 1,000 | 1,917 | 2,317 | 2,353 | 300 | 21,00 |
| 10 | 1,000 | 2,345 | 3,472 | 3,738 | 264 | 14,17 |
| 30 | 1,000 | 3,738 | 5,456 | 5,433 | 846 | 19,58 |
| **60** | 1,000 | 4,687 | **5,996** | 5,861 | 924 | 8,75 |
| **120** | 1,000 | **4,897** | **5,996** | **5,861** | **1 260** | **0,00** |
| **260** | 1,000 | **4,897** | **5,996** | **5,861** | **1 596** | **0,00** |

**`m` SATURA en `W`.** A `α = 0,25`, los niveles 120 y 260 ejecutan **2 856 estrategias
nuevas** y aportan **cero**. Ampliar la ventana de ataque de ±60 s a ±260 s —es decir, dejar
que el atacante manipule **todos** sus bloques del horizonte, no solo los del entorno del
cruce— **no añade una sola entropía al menú**.

**Techo libre medido, con las dos saturaciones: `m ≈ 6,0` de media, `12` como máximo sobre
12 semillas × 21 umbrales.**

### A1.3 · Barrido `C` (copias del mismo billete) — **NO SATURA**, y es la familia que refuta la saturación — `salida_a1b_copias.txt`

Las copias son la dimensión con la que D9-e subió `m_BS` de 4,62 a 5,77. **Y es la única de
las tres que NO satura.** Familia global de 8 estrategias (`pols_hasta(32)`, ventana ±30 s),
12 semillas, niveles anidados `C ∈ {0, 6, 14, 30, 60}`:

| `C` | `α` | `m_BS` medio / máx | `aporta_BS/21` | `m_SLOT` medio / máx | `aporta_SL/21` | `nuevas` |
|---:|---:|---:|---:|---:|---:|---:|
| 0 | 0,00 | 1,000 / 1 | 21,00 | 1,000 / 1 | 21,00 | 96 |
| 6-60 | 0,00 | 1,000 / 1 | **0,00** | 1,000 / 1 | **0,00** | 96 c/u |
| 0 | 0,10 | 3,087 / 6 | 21,00 | 1,857 / 4 | 21,00 | 96 |
| 6 | 0,10 | 3,187 / 7 | 1,92 | 1,925 / 4 | 1,42 | 96 |
| 14 | 0,10 | 3,694 / 8 | 8,58 | 2,155 / 5 | 4,00 | 96 |
| 30 | 0,10 | 4,278 / 9 | 10,58 | 2,171 / 5 | 0,33 | 96 |
| **60** | 0,10 | **4,806 / 10** | **9,75** | **2,250 / 6** | **1,67** | 96 |
| 0 | 0,25 | 4,008 / 6 | 21,00 | 1,925 / 3 | 21,00 | 96 |
| 6 | 0,25 | 4,889 / 8 | 13,58 | 2,143 / 4 | 4,33 | 96 |
| 14 | 0,25 | 6,179 / 10 | 16,67 | 2,353 / 5 | 4,42 | 96 |
| 30 | 0,25 | 7,155 / 11 | 16,00 | 2,377 / 5 | 0,50 | 96 |
| **60** | 0,25 | **7,464 / 11** | **6,50** | **2,452 / 6** | **1,58** | 96 |
| 0 | 0,40 | 3,996 / 6 | 21,00 | 2,325 / 5 | 21,00 | 96 |
| 6 | 0,40 | 5,254 / 9 | 16,17 | 2,508 / 5 | 3,50 | 96 |
| 14 | 0,40 | 7,254 / 12 | 18,83 | 2,976 / 6 | 8,83 | 96 |
| 30 | 0,40 | 8,429 / 14 | 16,00 | 2,980 / 6 | **0,08** | 96 |
| **60** | 0,40 | **8,849 / 16** | **7,08** | **2,980 / 6** | **0,00** | 96 |

**Y aquí está el resultado más limpio de todo el barrido: a `α = 0,40` el ancla `slot`
SATURA en copias y el `blue_score` NO.** Los niveles `C = 30` y `C = 60` ejecutan
**96 corridas nuevas cada uno**; para el ancla `slot` aportan **0,08 y 0,00** de 21 umbrales
—el menú se queda clavado en **2,980**—, mientras el del `blue_score` sigue subiendo
(8,429 → 8,849, aportando en 7,08 de 21). **La inundación de copias, que es el ataque con
el que D9-b rompió el primer ancla y con el que D9-e subió `m` a 5,77, se agota contra el
ancla por `slot`.**

**De `C = 0` a `C = 60`:**

| `α` | `m_BS` | `m_SLOT` |
|---:|---|---|
| 0,10 | 3,087 → 4,806 (**+56 %**) | 1,857 → 2,250 (**+21 %**) |
| 0,25 | 4,008 → 7,464 (**+86 %**) | 1,925 → 2,452 (**+27 %**) |
| 0,40 | 3,996 → 8,849 (**+121 %**) | 2,325 → 2,980 (**+28 %**, saturada) |

**El ancla `slot` aguanta la inundación de copias entre 2,7 y 4,3 veces mejor, y a `α=0,40`
directamente satura.**

**Etiqueta: REFUTADA la saturación en `C`.** A `C = 60` el nivel sigue aportando en 9,75 de
21 umbrales. **Ésta es la familia explícita, con parámetro, cuya `m` crece** que pedía el
encargo — y la doy yo, contra mi propio resultado de `D` y `W`.

**Pero crece en `log C`, y `F` crece en `ln m`.** Ajuste por mínimos cuadrados sobre los
cuatro puntos (`α = 0,10`):

```
m_BS = 1,881 + 0,491·log2(C)          (r8f_c_constantes / cálculo en línea)
```

| `C` | 60 | 120 | **180** (`mergeset_size_limit`) | 360 | 1 000 |
|---|---:|---:|---:|---:|---:|
| `m_BS` extrapolada | 4,78 | 5,27 | **5,56** | 6,05 | 6,77 |
| `F` | 12,5 h | 13,8 h | **14,5 h** | 15,7 h | 17,3 h |

**Multiplicar las copias por 17 (de 60 a 1 000) mueve `F` de 12,5 h a 17,3 h.** Ésa es toda
la fuerza de la familia que no satura: `F` crece como **`ln log C`**.

Y hay **dos reglas escritas** que la cierran:
- **`mergeset_size_limit = 180`** (R-FIN-12, `bps.rs:75-80`): ningún bloque fusiona más de
  180, luego por encima de ~180 copias por billete las sobrantes no entran en ningún
  mergeset.
- **U3″ dinámica** (R-FIN-11, reparada por D9-c A3 y verificada por D9-d A3): **una sola
  copia por identidad puede ser azul**. Y todas las copias de un bloque **comparten su
  `seed`** (`r8c_sim.py`, `corre(..., copias)`): una copia **nunca añade por sí misma una
  entrada al menú**, solo perturba la estructura.

**El ancla `slot` aguanta la misma familia 2,5 veces mejor:** de `C = 0` a `C = 60`,
`m_BS` sube **+56 %** (3,087 → 4,806) y `m_SLOT` **+21 %** (1,857 → 2,250).

**Confirmado con la familia COMPLETA** (global + bloque a bloque, `D=32`, `W=30`, 12
semillas, `salida_a1_C.txt`, 1 643 s):

| `C` | `α=0` | `α=0,10` | `α=0,25` | `α=0,40` | `nuevas` (α=0,25) | `aporta` (α=0,25) |
|---:|---:|---:|---:|---:|---:|---:|
| 0 | 1,000 | 3,246 | 4,464 | 4,532 | 693 | 21,00 |
| 6 | 1,000 | 3,337 | 5,306 | 5,770 | 693 | 13,00 |
| 14 | 1,000 | 3,909 | 6,762 | 7,913 | 693 | 17,00 |
| **30** | 1,000 | **4,698** | **8,385** | **9,536** | 693 | **18,58** |

`viol.banda = 0` en todo el barrido (Lema B1). **A `C = 30` sigue aportando en 18,58 de 21
umbrales: no satura.** Extrapolando con la pendiente medida hasta el techo
`mergeset_size_limit = 180`: `m_BS(180) ≈ 5,97` a `α = 0,10`.

---

## A2 · Por qué satura — el mecanismo, medido — `salida_a2_inercia.txt`

`retro d` aplicado a **todos** los bloques del atacante de la ventana; destino del bloque
en la vista honesta final, 12 semillas:

| `d` | `α=0,10` %cadena / %azul | `α=0,25` | `α=0,40` |
|---:|---|---|---|
| 0 (`sp`) | 100 % / 100 % | 100 % / 100 % | 100 % / 100 % |
| 1 | 22,8 % / 100 % | 16,5 % / 100 % | 16,0 % / 100 % |
| 2 | 0,0 % / 100 % | 0,5 % / 100 % | 0,3 % / 99,7 % |
| 4 | 0,0 % / 92,8 % | 0,0 % / 78,4 % | 0,3 % / 69,9 % |
| 8 | 0,0 % / 37,2 % | 0,0 % / 36,6 % | 0,3 % / 46,5 % |
| 16 | 0,0 % / **0,0 %** | 0,0 % / 12,4 % | 0,3 % / 34,7 % |
| 32 | 0,0 % / 0,0 % | 0,0 % / 11,8 % | 0,3 % / 34,7 % |
| 64 | 0,0 % / 0,0 % | 0,0 % / 11,8 % | 0,3 % / 34,7 % |

**Mecanismo, con la cita.** `check_blue_candidate` (`protocol.rs:250`,
`if new_block_data.mergeset_blues.len() as KType == k + 1 { red }`, y el bucle de
`blue_anticone_size`) tiñe de **rojo** todo candidato cuyo anticono azul supere `k`. Un
bloque con `sp = C_{h−d}` tiene en su anticono los azules que la cadena acumuló en esas `d`
posiciones. Y **«cadena seleccionada ⊆ azules»**: un rojo no puede ser bloque de cadena,
luego **no puede ser ancla**. A partir de `d ≈ 2` la probabilidad de acabar en la cadena ya
es < 1 %, y a partir de `d ≈ 16-32` el bloque ni siquiera es azul.

> Lo que queda a partir de `d = 32` (11,8 % / 34,7 % azules) son bloques cuya profundidad se
> **satura contra la propia longitud de la cadena** en el instante del ataque —el `DEGEN` de
> A1.0—, no una palanca nueva. Por eso `aporta = 0` de `D = 32` en adelante.

---

## A3 · La cota superior, por argumento

### Lema B1 (banda del ancla `blue_score`) — **DEMOSTRADO**

> Sea `A = I_T(Chn)` el primer bloque de la cadena con `blue_score ≥ T`. Entonces
> **`blue_score(A) − T ∈ [0, k]`**.
>
> *Prueba.* `A` es el primero, luego `blue_score(sp(A)) ≤ T − 1`. Y
> `blue_score(A) = blue_score(sp(A)) + |mergeset_blues(A)|` (`protocol.rs:153`, verificado en
> el clon `@c338d495`), con `|mergeset_blues| ≤ k + 1` porque `check_blue_candidate` corta en
> `len(mergeset_blues) == k + 1` (`protocol.rs:250`). Luego
> `blue_score(A) ≤ (T − 1) + (k + 1) = T + k`. ∎

**Verificado:** `viol.banda = 0` en los tres barridos de A1 (barridos `D`, `W` y `C`, 12
semillas × 21 umbrales × todos los niveles × 4 valores de `α`). Cero excepciones.

### Lema B2 (bloques de cadena en la banda) — **DEMOSTRADO**

> En **una** ejecución, a lo sumo `k + 1 = 31` bloques de la cadena seleccionada tienen
> `blue_score ∈ [T, T+k]`, porque `blue_score` crece por la cadena en `≥ 1` cada paso.

Esto acota el menú **dentro de una ejecución**, no la unión sobre estrategias — que es lo
que `m` mide.

### Cota C (ventana temporal) — **PLAUSIBLE, con la hipótesis dicha**

Un candidato a ancla tiene que ser (i) **azul** en la cadena final —si no, no es bloque de
cadena— y (ii) tener `blue_score ∈ [T, T+k]`. Si `λ_azul` está estabilizada por el retarget
(R-FIN-13; **medida 0,9728 → 0,9866 de `α = 0` a `α = 0,40`, plana**, `salida_b2_gran1.txt`),
un bloque creado en `t` tiene `blue_score ≈ λ_azul·t`, y ser azul exige que su anticono azul
—`≈ λ_azul·t − blue_score(B)`— no pase de `k`. Las dos condiciones encierran a los
candidatos en una ventana de tiempo real de ancho

```
Δt ≤ 2k/λ_azul ≈ 61 s        ⇒   m ≤ 1 + λ·2k/λ_azul ≈ 63
```

**Etiqueta: PLAUSIBLE.** Depende de que el retarget mantenga `λ_azul`; el propio D9-e
declaró LAGUNA en `δ` bajo retarget agresivo.

**Comprobada la predicción, no solo la conclusión** (`salida_a2_ventana.txt`, familia
saturada `D=32, W=60`, 12 semillas): para cada umbral se recogen los **bloques** candidatos
a ancla y se mide la **anchura temporal** del menú y el exceso `blue_score(ancla) − T`.

| `α` | `m` medio / máx | anchura media (s) | anchura máx (s) | máx `bs(ancla)−T` | `λ_azul` | `2k/λ_azul` | nº bloques en la ventana |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 0,00 | 1,00 / 1 | 0,00 | 0,00 | 8 | 0,9728 | 61,9 | 59,1 |
| 0,10 | 4,33 / 8 | 12,22 | 28,59 | 9 | 0,9793 | 61,5 | 60,0 |
| 0,25 | 4,90 / 8 | 17,54 | **32,93** | 8 | 0,9834 | 61,2 | 62,2 |
| 0,40 | 4,60 / 7 | 15,36 | **38,19** | **12** | 0,9866 | 61,0 | 62,4 |

**El menú entero cabe dentro de la ventana predicha**: anchura máxima medida **38,2 s**
frente a los **61 s** de la cota, y el exceso de `blue_score` máximo es **12**, muy dentro
del `k = 30` del Lema B1. La ventana contiene ~62 bloques y el menú realizado son 4,6-4,9:
**la cota tiene un factor 13 de holgura, y la holgura está medida, no supuesta.**

### Cota D (determinista, sin ninguna hipótesis estadística) — **CORREGIDA POR MÍ MISMO**

> **Mi primer intento fue falso.** Escribí que `merge_depth_bound` acota la profundidad a la
> que el atacante puede colgar un bloque. **No la acota.** `check_bounded_merge_depth`
> (`post_pow_validation.rs:79-96`, leído en el clon `@c338d495`) recorre **solo
> `mergeset_reds`**: un bloque con **un único padre** —el bloque de cadena profundo— tiene
> mergeset **vacío** y pasa el chequeo sin más. `merge_depth_bound` acota lo que un bloque
> puede **fusionar**, no de dónde puede **colgar**.

Lo que sí lo acota, y es una regla, es la **finalidad**. En Kaspa,
`sink_search_algorithm` descarta como candidato a cadena todo bloque que no tenga el
`finality_point` como ancestro de cadena — literal, `processor.rs:1033`:
*«Finality Violation Detected. Block {} violates finality and is **ignored from Virtual
chain**»*. En ZEROX es **R-FIN-7** («una punta que lo exigiera se ignora»). Por tanto

```
un bloque creado más de F después del cruce NO puede ser bloque de cadena en ese cruce
⇒   m ≤ 1 + λ·F
```

y a la vez la pinza pide `F ≥ (c_m/g)²/(αλ·0,22)`. **La condición de consistencia
`F ≥ F(m(F))` tiene solución porque `c_m² ≃ 2 ln m`: el lado derecho crece como `ln F`.**
Punto fijo calculado (`r8f_c_constantes.punto_fijo`, `salida_c.txt` §5):

| `α` | `F*` | `m ≤` | `c_m` | `I*` |
|---:|---:|---:|---:|---:|
| 0,05 | **481 h** | 1 733 245 | 4,971 | 106 h |
| **0,10** | **227 h** | 815 617 | 4,822 | 49,8 h |
| 0,25 | 83 h | 299 166 | 4,618 | 18,3 h |
| 0,40 | 50 h | 178 262 | 4,509 | 10,9 h |

**Ese es el precio literal de no suponer NADA con el ancla `blue_score`: `F ≈ 227 h ≈ 9,5
días`.** Es finito y calculable —que es lo que se preguntaba—, pero es un número malo. Todo
lo que hay entre 4,8 (medido) y 815 617 (garantizado) es cuánto se cree uno la estadística.

**Y aquí está el argumento decisivo a favor del ancla `slot` (§B4): su cota determinista
NO necesita punto fijo, porque `S_max` es una regla independiente de `F`:**
`m ≤ 1 + λ·S_max[s] = 151 ⇒ F ≤ 68,5 h`. **Factor 3,3 en la garantía.**

---

# PARTE B · El ancla por `slot`

`I_j :=` el bloque de la cadena seleccionada de **menor `blue_work`** entre los de
`slot ≥ T_j`, con `T_j = j·I` un **índice de PoT fijo**. Como `blue_work` crece
estrictamente por la cadena (Lema A4b de D9-e, DEMOSTRADO), ese bloque **es el primero de
la cadena con `slot ≥ T_j`** — y eso vale **con o sin** monotonía de `slot`. Se implementa
así y se comprueba (`equiv≠`).

> **Aviso metodológico contra mí mismo.** `equiv≠ = 0` **no es evidencia**: es teorema del
> Lema A4b, igual que el `sp≠ = 0` que D9-e denunció en su propio modelo. Lo declaro como
> control de A4b, no como prueba del ancla. La evidencia de que la comparación no es vacía
> es `ancla≠` (§B2).

## B0 · Antes de medir nada: la granularidad del slot rompe R-FIN-1a — `salida_b0_granularidad.txt`

R-FIN-7 escribe `F = 11 520` **slots** para `F = 3,2 h`: en el diseño **1 slot = 1 s**. Con
`λ = 1 bloque/s` eso hace **infactible R-FIN-1a** (`slot(sp(B)) < slot(B)`, estricta):

| granularidad | `α = 0` | `α = 0,25` | `α = 0,40` |
|---|---:|---:|---:|
| **1 s** (lectura literal) | 0,80 % | **23,67 %** | **29,34 %** |
| 0,25 s | 0,00 % | 7,32 % | 8,95 % |
| 0,1 s | 0,00 % | 3,28 % | 4,14 % |
| 0,02 s | 0,00 % | 0,95 % | 1,36 % |

(aristas de la **cadena seleccionada** que violarían R-FIN-1a; 12 semillas, 2 055 aristas a
`α = 0,40`.)

**Con 1 slot = 1 s, R-FIN-1a invalidaría casi un tercio de la cadena bajo ataque.** No es un
problema del ancla nueva —es de R-FIN-1a—, pero hay que resolverlo antes, porque
`S_max = 150` **slots** y `F` **en slots** cambian de significado con la granularidad:

- si 1 slot = 1 s, R-FIN-1a estricta es infactible;
- si 1 slot = 0,02 s, R-FIN-1a es factible (1,4 %) pero `S_max = 150` slots **son 3 s**, y el
  hueco medio de cadena bajo ataque ya vale ~2 s con cola de 15 s: **R-FIN-1a mordería la
  operación normal**, no solo el DoS.

**Etiqueta: CONTRADICCIÓN MEDIDA en las unidades de R-FIN-1a / R-FIN-7 / R-FIN-13.**
`slot` aparece en tres reglas con tres escalas implícitas incompatibles. **LAGUNA para el
principal:** la duración real de un slot de PoT de Autonomys no está en ninguna fuente
del repositorio (ya declarada por D9-d).

## B3 · ¿Cubre la Prop. 7 el ancla por `slot`? — **SÍ, y con una hipótesis MENOS** — `salida_b3.txt`

> **Lema A4-slot.** Sea `Chn` la cadena en `t+r`, `Chn′` la de `s > t+r`, `I` el primer
> bloque de `Chn` con `slot ≥ S` e `I′` el de `Chn′`. Si `I ≠ I′`, las dos cadenas difieren
> en alguna posición `p ≤ idx(I)`.
>
> *Prueba.* Sea `q = idx(I)`. Si coincidieran en `0..q`: para `i < q`,
> `slot(Chn′[i]) = slot(Chn[i]) < S`; y `slot(Chn′[q]) = slot(Chn[q]) ≥ S`. Luego el primero
> de `Chn′` que cruza `S` es `Chn′[q] = Chn[q] = I`. Contrapositivo. ∎

**Corrección a D9-e, a su favor.** D9-e apoyó el Lema A4 en la *monotonía estricta* de
`blue_score` por la cadena. **Esa hipótesis es innecesaria:** «el primer índice con la
propiedad» está determinado por el **prefijo** `0..q` y por nada más. El lema es por tanto
más robusto de lo que D9-e afirmó, y **se transfiere al `slot` aunque R-FIN-1a se relaje a
no estricta** — que es exactamente lo que B0 obliga a hacer.

Comprobado sobre reorganizaciones reales (horizonte 200 s, 40 vistas crecientes, 12
semillas, tres granularidades):

```
                        M1 bw monótono     M3 slot creciente   A2(i)      A2(ii)    A4 blue_score   A4 slot
 gran=1,0  α=0     227177/227177            478/483          4472/4472  4472/4472   13208/13208    10562/10562
 gran=1,0  α=0,10  230418/230418            681/796          1770/1770  1770/1770    2296/2296      2238/2238
 gran=1,0  α=0,25  233250/233250            922/1210          769/769    769/769      385/385        225/225
 gran=1,0  α=0,40  234626/234626           1106/1560          455/455    455/455      142/142         85/85
 gran=0,02 α=0,40  234626/234626           1543/1560          455/455    455/455      142/142         85/85
```

**A4-slot: 13 110/13 110 en total, cero excepciones**, y en particular **85/85 a `α = 0,40`
con `gran = 1 s`, donde el 29 % de las aristas de cadena NO cumple la monotonía estricta.**
Eso es la comprobación empírica de que el lema no la necesita.

**Criterio α: pasa** — las reorganizaciones caen de 13 208 (α=0) a 142 (α=0,40) y los
cambios de ancla de 10 562 a 85; la cuenta cambia con `α`.

**Etiqueta: DEMOSTRADO** (prueba + 13 110/13 110). La Prop. 7 cubre el ancla por `slot`
exactamente igual que al `blue_score`, encadenando con el Lema A2 de D9-c (A2(i) y A2(ii)
verificados 7 466/7 466 aquí) y el Lema A4b de D9-e (M1 925 471/925 471 aquí).

## B1 · La `m` del ancla `slot`, mismas semillas y misma familia que D9-e — `salida_b1_gran1.txt`

Familia **literal** de `r8e_a1c_copias.py` (`sp`, `retro` 1/2/4/8/16, global y bloque a
bloque, ventana ±30 s), 12 semillas (D9-e usó 8), 21 umbrales, adversario del paper sin
retardo, peso 1, `gran = 1 s`. **Las dos anclas se leen de la MISMA ejecución.**

| copias | `α` | `m_BS` medio / máx | `m_SLOT` medio / máx | `ancla≠` | `equiv≠` |
|---:|---:|---:|---:|---:|---:|
| 0 | 0,00 | 1,000 / 1 | **1,000 / 1** | 462/1 764 | 0 |
| 0 | 0,10 | 3,655 / 7 | **2,079 / 5** | 6 553/12 096 | 0 |
| 0 | 0,25 | 4,766 / 8 | **2,452 / 4** | 18 006/26 838 | 0 |
| 0 | 0,40 | 4,615 / 7 | **2,917 / 6** | 28 465/37 674 | 0 |
| **14** | 0,10 | 4,194 / 8 | **2,238 / 5** | 6 577/12 096 | 0 |
| **14** | 0,25 | **6,052** / 9 | **2,540 / 5** | 18 404/26 838 | 0 |
| **14** | 0,40 | 6,167 / 9 | **3,024 / 5** | 28 938/37 674 | 0 |

**Reproducción de D9-e.** La fila `copias=14, α=0,25` da `m_BS = 6,052` con 12 semillas
donde D9-e midió **5,77** con 8. Es la misma medida; la mía es más alta porque la unión
sobre más semillas es más ancha. **El instrumento reproduce y la regla de las 12 semillas
sube el número, no lo baja.**

**Capacidad del instrumento (regla 4).** `ancla≠` = **67 %** de los pares a `α = 0,25`
(18 006 de 26 838) y **26 %** ya a `α = 0`: las dos anclas caen en **bloques distintos** la
mayoría de las veces, luego las dos columnas **no** son la misma por construcción.
`equiv≠ = 0` **no se usa como evidencia** (es teorema del Lema A4b).

**Criterio α: pasa** — fila `α = 0` da `m = 1` en las dos anclas y `m` crece con `α` en las
dos.

**Resultado: el ancla por `slot` divide `m` por 2,4 en el régimen exacto que produjo el
5,77 de D9-e (6,05 → 2,54), y las copias —que suben `m_BS` un 27 %— solo la mueven un
3,6 %.**

## B2 · Los tres niveles de coste, y los ataques específicos — `salida_b2_gran1.txt`, `salida_b2_gran002.txt`

Familia saturada de A1 con retención, 12 semillas:

| nivel | `α` | `m_BS` | `m_SLOT` | razón |
|---|---:|---:|---:|---:|
| gratis | 0,10 | 3,655 | 2,079 | 1,76 |
| gratis | 0,25 | 4,766 | 2,452 | 1,94 |
| gratis | 0,40 | 4,615 | 2,917 | 1,58 |
| +retraso | 0,25 | 6,508 | 3,214 | 2,02 |
| +retraso | 0,40 | 7,639 | 3,623 | 2,11 |
| **+retención** | 0,25 | **8,544** | **3,639** | 2,35 |
| **+retención** | 0,40 | **10,163** | **4,504** | 2,26 |

**Los cuatro ataques que pedía el encargo, contestados:**

1. **¿Retener un bloque con `slot ≥ T_j` y soltarlo después?** Sí, y es la palanca que más
   sube `m_SLOT` (2,45 → 3,64 a `α=0,25`). Pero sube **menos** que en `blue_score`
   (4,77 → 8,54): la razón crece de 1,94 a **2,35**. El ancla `slot` **gana** cuando el
   atacante paga.
2. **¿Mover `λ_chain`?** La mueve —**0,2021 → 0,6610** de `α=0` a `α=0,40`, medido—, y con el
   ancla `blue_score` eso importaba porque `c` se cuenta en azules y la duración de la época
   es `c/λ_azul`. Con el ancla `slot` **`c` desaparece como constante**: `T_j = j·I` es un
   índice de PoT, y la época dura **exactamente `I`**, con cualquier `λ_chain`. Es una
   palanca **eliminada por construcción**, no reducida.
3. **¿Elegir cuál de sus billetes con `slot ≥ T_j` publica?** Sí — es exactamente lo que
   `m_SLOT = 2,08-4,55` mide. No desaparece; se reduce a la mitad.
4. **¿Y si NINGÚN bloque de cadena tiene `slot ∈ [T_j, T_j+S_max]`?** El ancla **existe
   siempre** (es «el primero con `slot ≥ T_j`», y la cadena crece sin cota), así que no hay
   fallo de vivacidad. Lo medido: `gap = slot(ancla) − T_j` vale **2,1 s de media y 15,9 s
   como máximo** sobre 114 786 lecturas a `α = 0,40`. Con `1 slot = 1 s` eso está muy dentro
   de `S_max = 150` (**0 rozaduras**). Con `1 slot = 0,02 s`, `S_max = 150` slots son **3 s**
   y el gap lo supera **42 761 veces de 114 786 (37 %) — y 2 828 veces de 7 056 incluso con
   `α = 0`**. Es el mismo choque de unidades de §B0, visto desde el otro lado.

**Robustez a la granularidad:** `m_SLOT` con `gran = 0,02 s` vale 2,079 / 2,437 / 2,885
frente a 2,079 / 2,452 / 2,917 con `gran = 1 s`. **Diferencia máxima 1,1 %.** El resultado no
depende de la escala del slot.

## B4 · La cota POR CONSTRUCCIÓN — lo que el `slot` tiene y el `blue_score` no

> **Cota E (menú del ancla `slot`).** Sea `τ` la duración de un slot de PoT. El ancla `A`
> cumple `slot(sp(A)) < T_j ≤ slot(A)` y, por **R-FIN-1a**,
> `slot(A) − slot(sp(A)) ≤ S_max`. Luego **`slot(A) ∈ [T_j, T_j + S_max)`**, sin ninguna
> hipótesis estadística. Y como `slot` es el **índice de PoT** —infalsificable, R-FIN-13—, el
> número de billetes con slot en esa ventana está fijado por el espacio total y vale
> `λ·τ·S_max` en media. Por tanto
>
> ```
> m_SLOT  ≤  1 + λ·τ·S_max
> ```

| `τ` | cota de `m` | `I` | `F` |
|---|---:|---:|---:|
| 1 s | 151 | 15,1 h | 68,5 h |
| 0,1 s | 16 | 6,7 h | 30,4 h |
| 0,02 s | 4 | 2,3 h | 10,3 h |

**Para el ancla `blue_score` no existe la análoga**, porque `blue_score` **no es un reloj**:
el atacante puede fabricar bloques con `blue_score ∈ [T, T+k]` en cualquier instante
posterior, y lo único que lo acota es la **finalidad**, que depende de `F` — el punto fijo
de la Cota D: `m ≤ 815 617`, `F ≈ 227 h`.

**Esa es la respuesta a la pregunta 1 en su forma útil: el ancla `slot` tiene cota superior
POR CONSTRUCCIÓN, `m ≤ 1 + λτS_max`, y es una cota que el diseñador AJUSTA moviendo `τ` y
`S_max`. La del `blue_score` es 24 veces peor y no la ajusta nadie.**

**Etiqueta: DEMOSTRADO** el enunciado `slot(A) ∈ [T_j, T_j+S_max)` (aritmética sobre
R-FIN-1a); **PLAUSIBLE** el paso «nº de billetes en la ventana = `λτS_max`» (usa que el PoT
fija el slot y que el retarget fija `λ`).

### B4bis · `S_max` deja de ser libre: se co-determina con el *steering*

En la Cota E lo que aparece es `τ·S_max`, es decir **`S_max` expresada en SEGUNDOS**, no en
slots. Luego la cota es `m ≤ 1 + λ·S_max[s]`, independiente de la granularidad. Y `S_max[s]`
tiene una **cota inferior medida**: el `gap` máximo observado es **15,9 s** a `α = 0,40`, así
que por debajo de ~20 s R-FIN-1a mordería la operación normal.

| `S_max[s]` | ¿cubre el gap medido (15,9 s)? | cota `m` | `F` garantizada |
|---:|---|---:|---:|
| 3 | **no** (37 % de rozaduras, `salida_b2_gran002.txt`) | 4 | 10,3 h |
| 15 | al límite (3-4 rozaduras de 114 786) | 16 | 30,4 h |
| **20-30** | sí | 21-31 | 35-41 h |
| 150 (D9-d) | sí, con holgura | 151 | 68,5 h |

**Constante nueva, derivada, no elegida:** con `S_max = 150 s` (el valor de D9-d, que sale de
la cola de partición a `10⁻¹²`), la **garantía determinista** del ancla `slot` es
`m ≤ 151 ⇒ F ≤ 68,5 h`; lo **medido** es `m = 2,5 ⇒ F = 5,0 h`. Bajar `S_max` a 20-30 s
bajaría la garantía a 35-41 h a costa de tolerar particiones más cortas. **Es una pinza
nueva entre R-FIN-1a y el steering que ninguna ronda había escrito.**

Y la granularidad, con las tres medidas juntas: **`τ ≈ 0,1 s`** (10 slots de PoT por
intervalo de bloque) es el único punto donde R-FIN-1a es casi factible (4,1 % de aristas
violan la estricta a `α=0,40`, frente al 29,3 % con `τ = 1 s`) y `S_max = 150` slots = 15 s
cubre casi todos los gaps (3-4 rozaduras de 114 786). El 4,1 % residual **obliga a relajar
R-FIN-1a a `slot(sp) ≤ slot(B)`** — que el Lema A4-slot **soporta**, porque no necesita
monotonía.

---

# VEREDICTO

## En una línea

**Sí, `m` tiene cota superior — y `I` y `F` crecen con `ln m`, así que incluso la cota más
cruda dimensiona las constantes.** (La única familia que **no** satura, las copias, hace
crecer `m` como `log C` y por tanto `F` como `ln log C`: multiplicar las copias por 17 mueve
`F` de 12,5 h a 17,3 h.) Con el ancla `blue_score` la cota determinista es el
punto fijo de la finalidad, `m ≤ 8·10⁵` ⇒ `F ≈ 227 h`; con el ancla **`slot`** es
`m ≤ 1 + λ·S_max[s] = 151` ⇒ **`F ≤ 68,5 h` garantizadas**, sin punto fijo y ajustable por
`S_max`. Medido, con la familia peor de todas las probadas (retención + copias hasta el
techo de `mergeset_size_limit`): `m = 2,6` ⇒ **`F = 5,3 h`** con el ancla `slot`, frente a
`m = 5,97` ⇒ **`F = 15,6 h`** con el `blue_score` vigente.

## Tabla de líneas

| línea | etiqueta | evidencia |
|---|---|---|
| **0** · `I, F ∝ ln m` | **DEMOSTRADO** | `c_m ≃ √(2 ln m)`; `I = (c_m/g)²/(αλ)`. `m` de 5,77 a 10 000 mueve `F` de 15 h a 145 h, no a infinito. Ejecutado, `salida_c.txt` |
| **A1** · ¿satura `m`? | **SÍ en `D` y `W` — MEDIDO, con la rama corriendo. NO en `C` para `blue_score` — REFUTADO por mí mismo. SÍ en `C` para `slot` a `α=0,40`** | Barrido `D`: el nivel `D=64` ejecuta **307 estrategias nuevas** y aporta **0** en los 21 umbrales × 12 semillas × 4 `α`, con `64 < 121 = |cadena(tP)|`. Barrido `W`: los niveles 120 y 260 ejecutan **2 856 nuevas** y aportan **0**. **Barrido `C`: a `C = 60` el `blue_score` sigue aportando en 7-10 de 21** — `m_BS = 1,881 + 0,491·log2(C)`, `F ∝ ln log C` (de `C=60` a `C=1000`, 12,5 h → 17,3 h)—, **mientras el ancla `slot` se clava en 2,980 con `aporta = 0,00`**. Techo libre medido `m ≈ 6,0` (máx 12) |
| **A1.0** · error propio | **DECLARADO** | Mi primer barrido `D` saturaba por **degeneración del simulador** (`retro n` se satura contra la longitud de la cadena), no por el protocolo. Corregido con `P = 120` y marca `DEGEN` |
| **A2** · mecanismo | **DEMOSTRADO + MEDIDO** | `check_blue_candidate` (`protocol.rs:250`) tiñe de rojo el bloque `retro` en cuanto su anticono azul pasa de `k`; «cadena ⊆ azules» ⇒ no puede ser ancla. Medido: `%en cadena` cae de 100 % a 0,3 % en `d = 2`; `%azul` a 0 % en `d = 16` |
| **B1 (lema)** · banda | **DEMOSTRADO** | `blue_score(ancla) − T ∈ [0, k]` por `protocol.rs:153` + `:250`. **0 violaciones** en los tres barridos |
| **A3** · cota por argumento | **PLAUSIBLE (63) / DETERMINISTA (punto fijo)** | Ventana `2k/λ_azul ≈ 61 s` con `λ_azul` medida plana (0,9728 → 0,9866) y **anchura del menú medida 38,2 s máx**: factor 13 de holgura. Sin esa hipótesis, el punto fijo de la finalidad da `F ≈ 227 h`. **Corregido un error mío: `merge_depth_bound` NO acota de dónde cuelga un bloque** |
| **B0** · unidades del `slot` | **CONTRADICCIÓN MEDIDA** | Con `1 slot = 1 s` (lectura literal de R-FIN-7), R-FIN-1a estricta **invalidaría el 23,7-29,3 % de las aristas de cadena** bajo ataque. `τ ≈ 0,1 s` es el único punto viable, y aun así hay que relajar R-FIN-1a a no estricta |
| **B1/B2** · `m` del ancla `slot` | **MEDIDA, mitad que `blue_score`** | 12 semillas, misma familia y mismas semillas que D9-e: `m_BS = 6,05` ↔ `m_SLOT = 2,54` en el régimen del 5,77. Con retención: 8,54 ↔ 3,64. Robusta a la granularidad (±1,1 %) |
| **B3** · ¿Prop. 7 cubre el `slot`? | **DEMOSTRADO — y con una hipótesis MENOS** | Lema A4-slot: **13 110/13 110**, cero excepciones, incluidos **85/85 a `α=0,40` donde el 29 % de las aristas viola la monotonía estricta**. La monotonía que D9-e creyó necesaria **no lo es** |
| **B4** · cota por construcción | **DEMOSTRADO (banda) / PLAUSIBLE (conteo)** | `slot(ancla) ∈ [T_j, T_j+S_max)` por R-FIN-1a, sin estadística. `m ≤ 1 + λ·S_max[s]` |
| **B4bis** · `S_max` co-determinada | **PINZA NUEVA** | `S_max[s] ≥ 20` por el gap medido (máx 15,9 s) y `S_max[s] ≤ 30` si se quiere `F ≤ 41 h` de garantía. Con el `S_max = 150` de D9-d: garantía `F ≤ 68,5 h`, medido `F = 5,0 h` |

## Las constantes — `salida_c.txt`

Peor `α` de la pinza = **0,10** (`g ∝ 1/√α`), como en D9-d.

| ancla | nivel de amenaza | `m` | `c_m` | `I` | `F` | `c` |
|---|---|---:|---:|---:|---:|---|
| `blue_score` | gratis, familia saturada en `D` y `W` | 3,655 | 0,966 | 2,00 h | 9,10 h | 7 054 azules |
| `blue_score` | + 14 copias | 4,194 | 1,055 | 2,39 h | 10,85 h | 8 415 azules |
| `blue_score` | + retención | 4,813 | 1,138 | 2,78 h | 12,62 h | 9 785 azules |
| `blue_score` | + 30 copias, familia completa | 4,698 | 1,125 | 2,73 h | 12,40 h | 9 553 azules |
| **`blue_score`** | **+ copias al techo `C=180` (extrapolada)** | **5,97** | 1,264 | **3,42 h** | **15,57 h** | 11 960 azules |
| **`slot`** | **gratis, familia saturada** | **2,079** | 0,587 | **0,74 h** | **3,35 h** | — (`c` no existe) |
| `slot` | + 14 copias | 2,238 | 0,631 | 0,85 h | 3,88 h | — |
| `slot` | + retención | 2,548 | 0,719 | 1,11 h | 5,03 h | — |
| **`slot`** | **+ copias al techo `C=180` (extrapolada)** | **2,60** | 0,733 | **1,15 h** | **5,24 h** | — |

**Recomendación, marcada como tal:** dimensionar contra el atacante que **retiene** (es lo
que hace un atacante con presupuesto — el argumento es de D9-d y lo suscribo) y con el
**ancla `slot`**:

```
I = 4 200 s (1,17 h)      F = 5,3 h      W/κ = 1,22      g = 3,6 %
c  NO EXISTE: T_j = j·I es un índice de PoT
garantía determinista con S_max = 150 s:  m ≤ 151  ⇒  F ≤ 68,5 h
```

(el `m = 2,6` de la fila «copias al techo», que domina a la de retención: 2,548).

Con el ancla `blue_score` vigente y el mismo criterio: `m = 5,97`, `I = 3,42 h`,
**`F = 15,6 h`**, `c = 11 960` azules — que es, casi exactamente, **el `F ≈ 15,5 h` que D9-e
dejó escrito como «y subirá»**. No sube más: ése es el número, y ahora tiene cota.

**El ancla `slot` compra un factor 3,0 en `F` (15,6 h → 5,3 h), un factor 3,3 en la garantía
determinista (227 h → 68,5 h), elimina la constante `c` y elimina la palanca de `λ_chain`.**

---

# Lo que hay que cambiar, en orden

1. **Escribir en `dag-poas-ancla-de-orden.md` que `I ∝ ln m`**, y con ello retirar la frase
   «`I`, `c`, `F` NO están dimensionadas». Lo que hay que declarar es **contra qué cota se
   dimensiona**, con etiqueta.
2. **Cambiar el ancla a `slot`** (índice de PoT). Gana en las cuatro dimensiones: `m` medida
   se reduce a la mitad (2,5 frente a 4,8-6,1), la cota determinista pasa de 227 h a 68,5 h,
   **`c` desaparece como constante** y la palanca de `λ_chain` desaparece con ella. La
   Prop. 7 lo cubre con **una hipótesis menos** que al `blue_score` (§B3).
3. **Resolver las unidades de `slot`** antes que nada (§B0): R-FIN-1a, R-FIN-7 y R-FIN-13
   usan «slot» con tres escalas implícitas incompatibles. Punto viable medido: `τ ≈ 0,1 s`,
   con R-FIN-1a **relajada a `slot(sp) ≤ slot(B)`** —que el Lema A4-slot soporta— y `S_max`
   expresada en **segundos**, no en slots.
4. **Añadir la pinza `S_max ↔ steering`** (§B4bis): `S_max[s] ≥ 20` por el gap medido,
   y la garantía determinista es `F ≤ (c_{1+λS_max}/g)²/(0,022·α)`.
5. **Corregir el Lema A4 de D9-e**: no necesita la monotonía estricta de `blue_score`. La
   versión correcta es más fuerte y es la que permite el traslado al `slot`.
6. **Corregir la afirmación de D9-c A4** de que `merge_depth_bound` acota la retrolectura:
   acota lo que un bloque **fusiona**, no de dónde **cuelga** (`post_pow_validation.rs:85`,
   el bucle es sobre `mergeset_reds`). Lo que acota de dónde cuelga es la **finalidad**
   (`processor.rs:1033`).

# Mis errores

1. **El barrido `D` original saturaba por artefacto.** `r8c_sim.py` implementa `retro n` como
   `ch[max(0, len(ch)−1−n)]`: cuando `n` supera la longitud de la cadena en el instante del
   ataque, todos los niveles apuntan a génesis. Con `P = 30` esa longitud es 31, así que
   `D = 32, 64, 128, 256` eran **un solo experimento repetido**. Mi contador `nuevas` no lo
   veía porque las estrategias son diccionarios distintos aunque produzcan el mismo DAG.
   Detectado al medir el mecanismo (A2: `%azul` idéntico a `d = 32, 64, 128`), corregido con
   `P = 120` y con la marca `DEGEN`. `salida_a1_D.txt` se conserva como registro.
   **Habría firmado una saturación falsa.**
2. **Estuve a punto de presentar `equiv≠ = 0` como evidencia.** No lo es: es **teorema** del
   Lema A4b («menor `blue_work` con `slot ≥ S`» = «el primero con `slot ≥ S`» porque
   `blue_work` crece por la cadena). Es exactamente el defecto que D9-e denunció en su propio
   modelo. Lo declaro como control de A4b y apoyo la comparación en `ancla≠`.
3. **Primera versión de los umbrales del ancla `slot`:** los espaciaba **un slot**, así que
   con `gran = 0,02 s` los 21 umbrales cubrían 0,4 s en vez de 21 s y no eran comparables con
   los 21 umbrales de `blue_score`. Corregido: los umbrales van separados **un segundo de
   PoT** sea cual sea la granularidad.
4. **`gap` medido en slots y comparado con `S_max = 150` sin convertir.** Con `gran = 0,02`
   eso mezclaba unidades. Corregido: `gap` en segundos, `S_max` en slots, y la discusión de
   unidades es ahora el hallazgo B0/B4bis.

# LAGUNAS

1. **La saturación es de MIS familias.** `D` y `W` saturan; **`C` no** (§A1.3), aunque solo
   logarítmicamente y con dos reglas que la cierran. Una familia que no se me haya ocurrido
   podría subir `m`. Lo que **no** depende de la familia son las Cotas C, D y E
   —son restricciones sobre qué bloque *puede* ser ancla, no sobre qué estrategia se
   prueba—, y ésas son el resultado que sostiene el veredicto.
2. **El simulador no ofrece la dimensión «subconjunto de puntas como padres»** (solo `tips`,
   `sp`, `retro n`). Añadirla exige tocar `Mundo.corre`, y la regla 13 lo prohíbe. **No está
   medida.**
3. **`λ_azul` plana está medida a horizonte 260-700 s y con peso 1**, sin retarget activo. La
   Cota C depende de ella. D9-e ya declaró LAGUNA sobre `δ` bajo retarget agresivo.
4. **La finalidad y `pruning_depth` nunca se alcanzan** en un horizonte de 700 s. La Cota D
   (punto fijo) está **argumentada sobre la regla y calculada, no ejecutada en simulación**.
5. **El DAG del simulador NO impone R-FIN-1a** (ni la monotonía estricta ni `S_max`). Imponerla
   solo puede **quitar** cadenas, luego `m_SLOT` medida es una **cota superior** de la que
   habría con la regla puesta — pero no lo he verificado.
6. **Todo lo de esta ronda es con peso 1.** D9-e demostró que el peso real mueve `m` un ±3-4 %;
   lo doy por bueno y lo declaro, no lo he repetido.
7. **La duración real de un slot de PoT de Autonomys sigue sin fuente** (LAGUNA heredada de
   D9-d). B0 y B4bis dependen de ella para pasar de slots a segundos.
8. **`c_interp` interpola linealmente** `c_m` entre enteros (heredado de `r8c_steering.py`).
   El error frente a la integral exacta es < 1 % y no cambia ninguna conclusión, pero está.

# Salidas de auditoría

```
$ python3 research/scripts/AUDITA_SCRIPTS.py research/scripts/d9-ronda8f
Scripts analizados: 8
======================================================================
Sospechas totales: 0
```

**Criterio α, script por script:** `r8f_a1_saturacion.py` y `r8f_a1b_copias.py` (fila
`α=0` ⇒ `m=1` en los tres barridos, en todos los niveles y en las dos anclas), `r8f_a2_mecanismo.py` (`α=0` ⇒ «sin datos»: no hay bloques
del atacante), `r8f_b1_slot.py` y `r8f_b2_ataques.py` (`α=0` ⇒ `m=1` en las dos anclas),
`r8f_b3_prop7.py` (las reorganizaciones caen de 13 208 a 142 al subir `α`),
`r8f_c_constantes.py` (§4 de `salida_c.txt`: `α=0` ⇒ `c_m=0`, `I=0`).

**Cobertura de rama:** `nuevas` > 0 en todos los niveles de saturación declarados (91-2 874
estrategias nuevas por nivel), `ancla≠` entre 26 % y 91 % de los pares leídos.

**Capacidad del instrumento:** el instrumento **sí** detecta lo que busca — `m` crece de 1,0
a 6,0 al ampliar la familia (A1), distingue el bloque del ancla `slot` del de `blue_score`
en el 67 % de las lecturas (B1), y detecta las violaciones de monotonía de `slot` que la
granularidad produce (B3, `M3` cae de 1 543/1 560 a 1 106/1 560 al pasar de `τ=0,02` a
`τ=1`).

# Mis errores (continuación)

5. **Cota D, primera versión: falsa.** Escribí que `merge_depth_bound` acota la profundidad
   a la que el atacante puede colgar un bloque, y **no la acota**:
   `check_bounded_merge_depth` (`post_pow_validation.rs:79-96`) solo recorre
   `mergeset_reds`, y un bloque de un solo padre tiene mergeset vacío. Lo detecté al ir a
   citar la línea. La cota correcta es el **punto fijo de la finalidad**, y es **peor**
   (227 h frente a los 126 h que había escrito). **Lo digo yo primero: mi cota cruda era
   optimista por un factor 1,8.**

# Ficheros de esta ronda

| script | qué hace | salida |
|---|---|---|
| `r8f_lib.py` | lectura de las dos anclas en una pasada, familias anidadas, `c_m`, constantes | — |
| `r8f_a1_saturacion.py` | barridos de saturación `D`, `W`, `C` | `salida_a1_D.txt` (con el error), `salida_a1_D_P120.txt`, `salida_a1_W.txt`, `salida_a1_C.txt` |
| `r8f_a1b_copias.py` | barrido `C` reducido, hasta 60 copias, con las dos anclas | `salida_a1b_copias.txt` |
| `r8f_a2_mecanismo.py` | inercia por profundidad; ventana temporal del menú | `salida_a2_inercia.txt`, `salida_a2_ventana.txt` |
| `r8f_b1_slot.py` | `m` de las dos anclas, familia y semillas de D9-e, con copias | `salida_b1_gran1.txt` |
| `r8f_b2_ataques.py` | tres niveles de coste, gap, `λ_chain`, granularidad | `salida_b2_gran1.txt`, `salida_b2_gran01.txt`, `salida_b2_gran002.txt` |
| `r8f_b3_prop7.py` | Lema A4-slot, Lema A2, M1/M3 | `salida_b3.txt` |
| `r8f_c_constantes.py` | mapa `m → (I, c, F)`, punto fijo | `salida_c.txt` |
| (en línea) | colisiones de slot bajo R-FIN-1a | `salida_b0_granularidad.txt` |
