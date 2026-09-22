**El validador tiene razón y la lectura de P-ADELANTO no se sostiene:** sin (h) el máximo exacto de la ventana es `A_core = (L − 1 − W_dec) + I(1 − 1/ρ)` —**no subestima, es exacto**, medido contra `a_core_semv1` hasta el último decimal en el estacionario— y el valor de ADL (`L + I − W_dec − D = 8 027`) es su **envolvente `ρ → ∞`**, que sobreestima en `≈ I/ρ`; con (h) y `Lrev = L` la ventana vale **`(L+I)(1 − 1/ρ)` exactos** (4 830,6 slots a `ρ = 2,5`, el `0,6·(L+I)` del validador), de modo que **`«sup A = 0 con ρ_max ≤ ρ*»` es FALSO** —`ρ*` es el umbral del *steering*, otro objeto— y **`«la edad M colapsa al margen»` también es FALSO**: (h) reduce la edad exigida por un **factor 1,2 a 4,6** según `F` y `ρ_max`, no la anula.

# INFORME — P-REVELACION · REV-v1.0

**Pregunta** (encargo): qué compra de verdad la revelación retardada `R-FIN-14(h)` y quién tiene
razón sobre el adelanto entre la ronda 7, la ronda 10a y `P-ADELANTO`.

**Instrumento:** `investigacion/veritas/seguridad/revelacion-v1/` (REV-v1.0, Julia 1.13.0, CPU
`znver5`, 16 hilos). **Categoría:** `seguridad` (dominante); `consenso` y `rendimiento`
secundarias. Motivo: la pregunta es cuánta ventana de retos futuros conoce el atacante y qué le
hace (h); las reglas que la restringen son de consenso y el precio de (h) se mide en núcleos/nodo.

**Presupuesto declarado antes de ejecutar:** 16 hilos, 8 GiB, 256 MiB de disco, 3 h de cómputo.
**No se agotó:** los barridos completos suman **81 s** de pared (`resultados/TIEMPOS.txt`), el mayor
62 s. Sin GPU (no la justifica: recursión escalar secuencial).

> **HUELLAS (encargo §6, primera línea).** `sha256sum -c P-ZRX/P-REVELACION/ENTRADA.sha256` →
> `PROMPT.md: OK` al empezar y al terminar. `git status --short` tiene las **mismas cinco** entradas
> al empezar y al terminar (` D ZEROX-EN-NUMEROS.md`, `?? .trash/`, `?? P-ZRX/`,
> `?? veritas/consenso/poda-post-v1/`, `?? veritas/consenso/prueba-recursiva-v1/`,
> `?? veritas/seguridad/`) y **no son mías**: son las que ADL-v1.0 ya declaró. No cambió nada ajeno.

---

## 1 · La respuesta, en cinco frases y cuatro tablas

### 1.1 F1 — sin (h): `A_core` es exacta, el tope de ADL es la envolvente

Rejilla: `L = 7 200`, `I = 851`, `W_dec = 20`, `D = 4`, offset 0, 1 500 épocas, `ρ ∈ [1,01; 9]`.
`resultados/F1.txt`.

| `ρ` | `V_max` (espera, `Φ_h = t`) | `A_core` | `V_max` (especula, `Φ_h = t`) | ronda 7 = `L+I(1−1/ρ)` | tope ADL | `V_min` régimen |
|---:|---:|---:|---:|---:|---:|---:|
| 1,01 | **7 187,4** | **7 187,4** | 7 207,4 | 7 208,4 | 8 027,0 | 7 175 |
| 2,00 | **7 604,5** | **7 604,5** | 7 624,5 | 7 625,5 | 8 027,0 | 7 175 |
| 3,00 | **7 746,3** | **7 746,3** | 7 766,3 | 7 767,3 | 8 027,0 | 7 175 |
| 9,00 | **7 935,4** | **7 935,4** | 7 955,4 | 7 956,4 | 8 027,0 | 7 175 |

- **`A_core` es el máximo exacto, al decimal, para todo `ρ` finito** bajo el adversario que espera
  la decisión y con la frontera honesta en su slot. No subestima: **coincide**.
- El adversario que **especula** (ronda 10a) gana `W_dec` exactos: `V_max = A_core + W_dec`. Su
  forma coincide con la de la **ronda 7** menos 1 (convención discreta).
- Con la frontera honesta `D` por delante (`C-POT-05`, premisa 6), `V_max = A_core − D`: **`D` resta
  exactamente `D`**.
- El tope de ADL **`8 027` no se alcanza para ningún `ρ` finito**: es `V_max(ρ→∞) + 1`. Sobreestima
  en `≈ I/ρ` (422,5 slots a `ρ = 2`, 91,6 a `ρ = 9`).
- `V` oscila en régimen entre **`V_min = L − W_dec − D − 1 = 7 175`** y `V_max`; amplitud
  `I(1−1/ρ)`. **No es un número, es una banda.**
- **Sobrevive de ADL lo esencial:** para cualquier `ρ > 1`, tras el *bootstrap*, la ventana es
  `≈ L` (entre `A_core − D` y `A_core − D + I`). **Acotar `ρ_max` no la reduce.**
- *Bootstrap* medido (hasta `0,9·L`): 180,09 h a `ρ=1,01` frente a `0,9L/(ρ−1) = 180,00` (razón
  1,000), 36,04/36,00 a 1,05, 3,65/3,60 a 1,5, 0,90/0,90 a 3,0 — reproduce 9c §E.1.

### 1.2 Comparación fila a fila con `A_frontera` de ADL-v1.0

`resultados/ADL.txt`; `A_frontera` se evalúa **incluyendo el fichero de ADL** (`…/adelanto-v1/src/modelo.jl`,
sin copiarlo a mano), `t = 10^6`, misma rejilla.

| `ρ` | `A_frontera` ADL | `V_max` sim (`D`) | `V_max` sim (`D=0`) | `A_core` | `V_max(D=0) − A_core` |
|---:|---:|---:|---:|---:|---:|
| 1,000 | 0,00 | 0,00 | 0,00 | 0,00 | 0 |
| 1,001 | 1 000,00 | 1 197,40 | 1 197,40 | (7 179,85) | transitorio |
| 1,008 | 8 000,00 | 7 181,75 | 7 185,75 | 7 185,75 | **0,00** |
| 2,000 | 8 027,00 | 7 600,50 | 7 604,50 | 7 604,50 | **0,00** |
| 3,000 | 8 027,00 | 7 742,33 | 7 746,33 | 7 746,33 | **0,00** |
| 9,000 | 8 027,00 | 7 931,44 | 7 935,44 | 7 935,44 | **0,00** |
| 100,000 | 8 027,00 | 8 017,49 | 8 021,49 | 8 021,49 | **0,00** |

**Las tres lecturas, juntas:** (1) `A_core` es exacta (diferencia 0,00 con el simulador en todo el
estacionario); (2) `A_frontera` de ADL **nunca acierta** en `ρ` finito, sobreestima y sólo se acerca
como `ρ → ∞`; (3) `A_frontera` también **falla en el transitorio** (a `ρ = 1,008` da 8 000 mientras
la escalera da 7 186: el modelo continuo concede de golpe la cota de flujo que las barreras no
dejan alcanzar).

### 1.3 F2 — con (h): `V` **no** se anula, y `ρ*` es *steering*

`resultados/F2.txt`. `L = 7 200`, `I = 851`, `W_dec = 20`, `D = 4`, `S_max = 150`.

| `ρ` | `V_max` (h, `Lrev=L`, espera) | `(L+I)(1−1/ρ)` | `A_con_h` de ADL |
|---:|---:|---:|---:|
| 1,01 | **79,7** | 79,7 | 0,0 |
| 1,50 | **2 683,7** | 2 683,7 | 0,0 |
| 2,00 | **4 025,5** | 4 025,5 | 0,0 |
| 2,50 | **4 830,6** | 4 830,6 | 0,0 |
| 3,00 | **5 367,3** | 5 367,3 | 0,0 |
| 9,00 | **7 156,4** | 7 156,4 | 0,0 |
| 9,25 (> `ρ*`) | — | — | ≈ 0 |

- Con (h) y `Lrev = L` la ventana es **exactamente `(L+I)(1−1/ρ)`**, la forma de la ronda 7. A
  `ρ = 2,5`, **4 830,6 slots = 0,6·(L+I)** — literalmente el número del validador.
- **`A_con_h` de ADL vale 0 en esa misma fila.** No son el mismo objeto: `A_con_h` es la **holgura
  de la carrera de *steering*** `ρ(I+W_dec) − (Lrev+I)`, cuyo cero es `ρ*`. El validador tiene razón.
- Con `Lrev = L − S_max` (la recomendación h.1b) la ventana **no baja**; a `ρ` bajo **sube**
  (203,2 a `ρ=1,01`, 4 865,6 a 2,5) porque el VDF cuesta menos reloj y el tope lo pone la
  disponibilidad del ancla.
- **`+D` resta exactamente `D`**: medido 4,000 en las diez filas (`F2.txt`).
- **`ρ*` simulado frente al cerrado** (`resultados/CONTROLES.txt`, bisección en log ρ, 32 réplicas,
  offset geométrico):

  | `(L, I, W_dec, Lrev)` | `ρ*` simulado | `(Lrev+I)/(I+W_dec)` | publicado (10a) |
  |---|---:|---:|---:|
  | (7 200, 851, 20, 7 200) | **9,250** | 9,243 | 9,24 |
  | (7 200, 851, 45, 7 200) | **9,010** | 8,985 | 8,99 |
  | (3 600, 851, 20, 3 600) | **5,123** | 5,110 | 5,13 |
  | (7 200, 851, 20, 7 050) | **9,089** | 9,070 | 9,07 |
  | (7 200, 851, 20, 3 600) | **5,123** | 5,110 | 5,11 |

  Con offset **uniforme** (conservador, como en 10a) el simulado sube a 9,525 / 9,250 / 5,214, es
  decir **+5 %**: el cerrado es *optimista*, no conservador, con la geométrica truncada.

### 1.4 Distribución de `V` en el tiempo con rachas

`resultados/F2.txt`, (h), `Lrev = L − S_max`, especula, honesto `D` adelante, `J = 2 000`,
96 réplicas, `ρ` en `[1, 3]` (9 puntos), cuantiles de la **masa de tiempo** agregada.

| `α` | q50 | q90 | q99 | q99,9 | máx `V` | `P(V ≥ L−W_dec)` |
|---:|---:|---:|---:|---:|---:|---:|
| 0,10 | 3 296 | 4 992 | 5 536 | 6 080 | 8 250,9 | 0,0000 |
| 0,25 | 3 360 | 5 120 | 5 984 | 6 944 | 9 943,7 | 0,0005 |
| 0,33 | 3 392 | 5 216 | 6 336 | 7 488 | 13 358,3 | 0,0018 |
| 0,40 | 3 424 | 5 312 | 6 656 | 8 032 | 13 358,3 | 0,0041 |

Las rachas **estiran la cola** (máx de 8 251 a 13 358 con `α` de 0,10 a 0,40) y la **tasa de
excedencia crece 40×**, pero siguen siendo **~10⁻³ del tiempo**, no el caso típico. La cola no está
acotada; los cuantiles sí.

### 1.5 F4 — cuánto reduce (h) la edad, en factor

`resultados/F4.txt`, `I = 851`, `W_dec = 20`, `D = 4`, `S_max = 150`, `α = 0,33`, `ρ ∈ [1, ρ_max]`
(9 puntos), 64 réplicas, `J = 1 200`.

| `F` | `ρ_max` | q99 sin (h) | q99 con (h) | **factor** |
|---:|---:|---:|---:|---:|
| 1 019 | 1,2 | 1 424 | 688 | **2,07×** |
| 1 019 | 2,5 | 2 624 | 2 208 | **1,19×** |
| 3 547 | 1,2 | 3 952 | 1 088 | **3,63×** |
| 3 547 | 2,5 | 5 152 | 3 616 | **1,42×** |
| 7 200 | 1,2 | 7 616 | 1 664 | **4,58×** |
| 7 200 | 2,5 | 8 800 | 5 712 | **1,54×** |
| 7 200 | 3,0 | 9 008 | 6 352 | **1,42×** |

- **Sin (h)** la edad exigida es `q99 ≈ L` (entre 1,05·L y 1,25·L): la ventana es ≈`L` para todo
  `ρ > 1`, así que **`M > margen` es imposible** y `M` está dominada por `L`, que `C-FLU-01` ata a `F`.
- **Con (h)** la edad baja por un **factor 1,2-4,6**, más cuanto menor es `F` y menor es `ρ_max`.
  **No colapsa al margen.** El margen de `ρ_max` que se gana es lo que hace el factor grande.
- La cota **debe** darse como cuantil con su tasa de excedencia, no como `sup`: las rachas de ancla
  propia no acotan `V` (máx observado 13 358 con `α = 0,40`, por encima del q99,9).

### 1.6 F3 — `C-FLU-01` con `I` recalibrado por (h.6)

`resultados/F3.txt`. `Lrev = L − S_max`, `W_dec = 20`, `S_max = 150`, `L = máx(F, 0, S_max+1)`,
`I* = (L − ρ_max·W_dec)/(ρ_max−1)` con `I > S_max` y `I ≥ ρ_max·W_dec`.

| `F` | `ρ_max` | `L` | `I*` | `q+1` | núcleos/nodo | `ρ*` | `V_max` | iny/h |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 019 | 1,5 | 1 019 | 1 978 | 2 | 0,146 | 1,425 | 1 094 | 1,82 |
| 1 019 | 2,5 | 1 019 | 646 | 3 | 0,248 | 2,275 | 1 054 | 5,57 |
| 3 547 | 2,5 | 3 547 | 2 331 | 3 | 0,242 | 2,436 | 3 582 | 1,54 |
| 7 200 | 2,5 | 7 200 | 4 767 | 3 | 0,241 | 2,469 | 7 235 | 0,76 |
| 7 200 | 1,2 | 7 200 | 35 880 | 2 | 0,115 | 1,196 | 7 300 | 0,10 |
| 7 200 | 3,0 | 7 200 | 3 570 | 4 | 0,290 | 2,958 | 7 225 | 1,01 |

- **La realimentación `F → L → ρ*` desaparece en `ρ*` una vez recalibrado `I`**, pero **reaparece en
  el coste**: con `ρ_max` fijo, `ρ*` es casi el mismo en todas las `F` (1,479 / 1,479 / 1,490 a
  `ρ_max = 1,5`) mientras **`I*` crece linealmente con `L`** (1 978 → 7 034 → 14 340) y por tanto
  `q+1` se queda en 2 y los núcleos también. **`F` deja de comprarse con protección y se compra con
  `I`.** La tabla de ADL que dejaba `ρ* = 2,147` mantenía `I = 851` fijo: al recalibrar, la misma
  fila da `ρ* = 2,275` y `I* = 646`.
- **Qué acota `I` por abajo:** `C-FLU-09` (`I > S_max`) y `R-FIN-14(f)` (`I ≥ ρ_max·W_dec`); el
  primero manda a `F = 1 019` y `ρ_max ≥ 9` (`I* = 104,9 < 151`), como ya vio ADL. **No hay una
  tercera** en las reglas escritas; sí hay un techo práctico: `ρ_max → 1` dispara `I*`
  (35 880 s a `ρ_max=1,2`, una inyección cada 10 h).
- **Lo que además cambia al encoger `I`:** los instantes `t_j` por hora, cada uno un punto donde
  puede nacer una partición de flujo. `I = 4 725 s → 0,76/h`; `I = 851 → 4,23/h`; `I = 300 → 12/h`.
  **No se estima la probabilidad de partición** (depende de `Δ`, no medida).

### 1.7 F5 — lo que (h) le cuesta al honesto

`resultados/F5.txt`; `verify = 96,1 ms/slot` y `prove = 1 561 ms/slot` **medidos**
(`research/dag-poas-ancla-de-orden.md:342`); `m = 1,83` menú medido por 9c a `α = 0,40`.

| `F` | `I` | `L` | `q+1` | `m·q` | núcleos/nodo | puntualidad |
|---:|---:|---:|---:|---:|---:|---|
| 1 019 | 851 | 1 019 | 3 | 5 | 0,211 | sí |
| 3 547 | 851 | 3 547 | 6 | 11 | 0,497 | sí |
| 7 200 | 851 | 7 200 | 10 | 18 | 0,909 | sí |
| 7 200 | 4 725 | 7 200 | 3 | 5 | 0,243 | sí |
| 7 200 | 300 | 7 200 | 25 | 46 | 2,403 | sí |

La cadena principal sola cuesta 0,0961 núcleos: **(h) multiplica por `1 + L/I`** y añade `q+1`
líneas. Recalibrando `I` por (h.6) el precio de `ρ* = 2,5` es **0,24 núcleos y 3 líneas**, no 0,909
y 10. La condición de puntualidad honesta es **`Lrev ≤ L − W_dec − D`** (continua) y
`Lrev ≤ L − W_dec − D + off − 1` (discreta), **no** `Lrev ≤ L − W_dec`: la frontera honesta cruza la
barrera `D` slots antes y el slot de barrera cuesta uno más.

---

## 2 · El modelo por eventos, y por qué no es una forma cerrada

Fuente de verdad: **simulación por eventos escrita desde las reglas** (`src/modelo.jl`), no una
fórmula. Las formas cerradas son **controles** (§3), y cada una se evalúa contra algo que no sale
del simulador.

Épocas `j = 1…J`, `T_j = j·I`, `s_j = T_j + off_j` (`C-FLU-04`), `t_j = s_j + L` (`C-FLU-07`), ancla
propia con probabilidad `α`. El atacante avanza `ρ` slots por slot de pared **solo mientras tiene la
entropía**; para completar el slot `t_j` necesita haber llegado a `t_j − 1` **y** tener `entropía_j`.
La recursión es

```text
τ_j = máx( τ_{j-1} + (t_j − 1 − t_{j-1})/ρ , e_j ) + 1/ρ
```

con `e_j` = instante de disponibilidad de la entropía:

| variante | `e_j` |
|---|---|
| ancla ajena, especula (10a) | `s_j` |
| ancla ajena, espera la decisión (9c) | `s_j + W_dec` |
| ancla propia | instante en que su frontera alcanzó `s_j + D` (no espera, no necesita el bloque) |
| con (h) | `+ Lrev/ρ` (línea de revelación **en paralelo**) |

La frontera honesta se **simula con las mismas barreras** y su VDF a tasa 1: la puntualidad es una
**invariante observada** (`n_stall_h`), no un supuesto. `V(t) = Φ_a(t) − Φ_h(t)` se acumula en un
**histograma temporal exacto por tramos lineales** (en un tramo lineal la densidad de `V` es
uniforme; el tiempo por bin sale en forma cerrada).

**Representación:** `Config{T}` inmutable e `isbits`; `Buffers{T}` preasignados por réplica (4
vectores de puntos de ruptura, 1 vector de fusión, 1 histograma); RNG `StableRNG(semilla + id)` por
réplica; números aleatorios **comunes a toda la rejilla de ρ** (mismo `off_j`, mismas `propia_j`)
para localizar umbrales; reducción **en orden de id de réplica**. No hay `Dict`, `Set`, `Any` ni
closures en el camino caliente.

## 3 · Controles de regresión (encargo §4): todos reproducidos

| Control | Cifra publicada | Medido aquí | Razón |
|---|---|---|---|
| C1 tope sin (h) | `L + I − W_dec = 23 130` | 23 130 (cerrado) | exacto |
| C1 tope simulado | `L + I(1−1/ρ)` | idéntico en las 5 filas | **1,000000** |
| C1 *bootstrap* | 477,00 h (9c: 477,06, razón 1,000) | **477,69 h** | **1,001** |
| C2 ronda 7, 15 filas | `L+I(1−1/ρ)` y `(L+I)(1−1/ρ)` | idéntico | **1,000000** (15/15) |
| C3 `ρ ≤ 1 ⇒ 0` | 0,000 exacto | 0,000 (ρ=1 y ρ=1,001) | exacto |
| `ρ*` | 9,24 / 8,99 / 5,13 | 9,250 / 9,010 / 5,123 | 1,0008 / 1,0028 / 0,998 |
| `Lrev/L = 0,979 → 9,07`; `0,50 → 5,11` | 9,07 / 5,11 | 9,089 / 5,123 | 1,002 / 1,003 |
| rachas `α=0,33`, `ρ=2,5 → 3,914·10⁻³` | 3,914·10⁻³ | 4,354·10⁻³ [3,94; 4,77] | 1,113 |
| rachas `ρ=3 → 1,186·10⁻²` | 1,186·10⁻² | 1,238·10⁻² [1,17; 1,31] | 1,044 |
| `A_frontera` de ADL en mi rejilla | — | §1.2 | `A_core` exacta, ADL envolvente |

**Discrepancia declarada, con su motivo.** El *bootstrap* de C1 sale **1,001** con el cruce de
barrera físico y **0,977** con la convención del instrumento histórico (`r10a_lib.py:167`, cruce
gratis). La diferencia es de **modelo, no de copia**: en `r10a_lib.py` la corrida hasta la barrera
cubre el slot `t_j` entero a razón `ρ` (`llegada_j = t_j/ρ`), mientras que la física para en
`t_j − 1`, espera la entropía y **luego** computa `t_j`; con `ρ = 1,01` eso son `j/ρ ≈ 394` slots de
ventaja regalada por época acumulada, y explica los 11 h de diferencia. **El tope no cambia**
(razón 1,000000 en las dos convenciones). El instrumento expone las dos (`cruce ∈ {true,false}`).

**Ningún test compara una fórmula consigo misma.** El kernel se contrasta con (a) un **oráculo por
slot** independiente en `Rational{BigInt}` —**diferencia exacta 0** en 280 casos aleatorios con
`ρ ∈ [9/8; 4]` y todas las banderas— y (b) las formas cerradas **externas** de 9c, ronda 7, ronda
10a y ADL-v1.0. `test/runtests.jl`: **143/143 en verde**.

## 4 · Rendimiento, determinismo y verificación numérica

**Caso representativo:** `J = 1 500` épocas × 12 valores de ρ × 64 réplicas = **1 152 000**
iteraciones de época, `L = 7 200`, `I = 851`, (h) activa.

| Hilos | Barrido, mediana | Barrido, mínimo | *speedup* (mín.) | Eficiencia | Asignaciones |
|---:|---:|---:|---:|---:|---:|
| 1 | 119,58 ms | 117,08 ms | 1,00× | 100 % | 1 634 |
| 2 | 81,80 ms | 65,83 ms | 1,78× | 88,9 % | 1 646 |
| 4 | 41,90 ms | 31,83 ms | 3,68× | 92,0 % | 1 656 |
| 8 | 27,51 ms | 17,45 ms | 6,71× | 83,9 % | 1 676 |
| **16** | **19,14 ms** | **12,26 ms** | **9,55×** | **59,7 %** | 1 716 |

El trabajo es de milisegundos, así que la mediana está dominada por el arranque de tareas; con el
mínimo, 16 hilos es la configuración que gana en tiempo absoluto y es la que se conserva. **Los
cuatro *checksums* (`hash` de `vmax`, `vmin`, `hist`, `n_pro`) son idénticos con 1, 2, 4, 8 y 16
hilos** ⇒ la reducción es determinista y no hay carreras.

**Asignaciones del núcleo:** `simular_replica!` (J = 1 500) → **0 asignaciones, 0 bytes**
(`@benchmark` y `@allocated`). Las asignaciones del barrido son las reservas por réplica, una vez.

**Optimización guiada por perfil.** `Profile` (`resultados/PERFIL.txt`) señala `llenar_rampa!`
(el reparto del histograma) como cuello real. Se añadió `con_hist = false` para los barridos que
sólo necesitan escalares: **mismos escalares** (comprobado) y **2,58× menos tiempo**
(80,13 → 31,09 ms; `resultados/OPTIMIZACION.txt`). El histograma se conserva donde hace falta.

**Verificación numérica.** El kernel rápido y el oráculo comparten el modelo pero **no el
acumulador**: el oráculo reconstruye la posición de cada frontera desde una tabla por slot y evalúa
`V` en la unión de puntos de ruptura; con `Rational{BigInt}` la igualdad es exacta
(`maxdiff = 0.0`). No se usa `@fastmath` en ninguna parte. `@code_warntype` sobre
`construir_trayectorias!`, `simular_replica!` y `acumular!`: **cero `::Any`/`::Union`**; JET
`report_call` sobre los tres: **sin diagnósticos**.

**Comando reproducible** (`~/.julia` es de solo lectura en esta máquina; la caché de compilación va
a `/tmp`, como en ADL-v1.0):

```bash
cd /home/katana/zeo/ZEROX/P-ZRX/P-REVELACION/investigacion/veritas/seguridad/revelacion-v1
export JULIA_DEPOT_PATH="/tmp/dsh-julia-depot:$HOME/.julia"
/home/katana/torio/.juliaup/bin/julia --project=. --threads=16,0 run.jl --modo todo   # 81 s
JULIA_NUM_THREADS=4 /home/katana/torio/.juliaup/bin/julia --project=. --threads=4,0 test/runtests.jl
```

Semilla maestra `0x5a5a`, derivación `StableRNG(0x5a5a + id_réplica)`. Entorno en
`resultados/ENTORNO.txt`; git `49c6ffa7a29a2237fb19c341d1d9fb79755f15a1`.

## 5 · Qué cae de P-ADELANTO, en una línea cada cosa

Detalle y fila de evidencia en `CORRECCIONES-A-P-ADELANTO.md`. Resumen: **caen las dos
conclusiones que Katana iba a usar** (`A` no depende de ρ; `A_core` subestima; con (h) `sup A = 0` y
la edad colapsa al margen), **sobrevive** la realimentación `F ↔ L ↔ ρ*` y el aviso de que bajar `F`
sin fijar `L_suelo_slots` deja `ρ*` en el borde del techo físico, y **sobrevive, corregida**, la
afirmación de que sin (h) la ventana es ≈`L` para cualquier `ρ > 1` tras el *bootstrap*.

## 6 · Lo que esta investigación NO resuelve

1. **`ρ_max` real por plataforma.** El techo 1,5-2,5× sigue siendo estimación
   (`research/pot-aes-asic-chacha.md:40-42`). Todo el informe da `ρ` como símbolo.
2. **Qué adversario es el real** (espera o especula). Se publican los dos; el que especula gana
   exactamente `W_dec`.
3. **`W_dec` y `α` en red real.** `W_dec ≤ 45 s` es máximo observado, no cota universal; `α` es
   entrada.
4. **La probabilidad de partición de flujo con `I` pequeño.** Sólo se **cuentan** los instantes
   `t_j` por hora; la probabilidad depende de `Δ`, que en este repositorio sigue **simulada**
   (`TAREAS.md` §2.9(a) 6).
5. **El VDF de revelación no se implementa.** Se modela su coste temporal `Lrev/ρ`; no hay AES, ni
   `blake3`, ni `N(s)`, ni checkpoints, ni DoS de verificación.
6. **El coste económico del intento dirigido del sembrador** sigue sin medir: esto entrega la cota
   temporal (`V`), no la económica.
7. **`L_suelo_slots` sigue símbolo.** Cuando `L_suelo = 0`, `C-FLU-01` colapsa `L` a `máx(F, S_max+1)`
   y `ρ*` se ata a `F`; con `L_suelo = 3 600` la contradicción de ADL desaparece. **La decisión de
   `L_suelo_slots` no la toma este informe.**
8. **No se modela red**: `Δ`, GHOSTDAG, `π_DAG`, reorganizaciones, retarget durante el ataque, ni
   competición entre soluciones del mismo slot.
9. **La cola de las rachas a `ρ` bajo no está medida**: a `ρ = 1,5` y `α = 0,33` la tasa cerrada es
   `2·10⁻⁸` por época y el presupuesto no la alcanza (0 eventos en 512 000 épocas). Se declara
   **derivada, no medida**.
10. **Ninguna regla del SPEC se ha modificado**: (h) sigue siendo una opción, y `C-FLU-12` la regla
    que habría que sustituir.
