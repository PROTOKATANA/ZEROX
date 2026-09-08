# D9-d · Ronda 8d — refutación del ancla `blue_score`

**Fecha:** 2026-09-08 · **Agente:** D9-d (Opus 5), fresco, sin deferencia al principal.
**Objetivo:** `dag-poas-ancla-de-orden.md` §2, R-FIN-1..13 **tal como están hoy** — es decir, con
el **tercer ancla** (`blue_score` de la cadena seleccionada), R-FIN-11 = U2 + **U3″ dinámica**,
R-FIN-1a con `S_max` por fijar y R-FIN-12 completa.
**Directorio:** `research/scripts/d9-ronda8d/` (duradero, en el repo).

---

# VEREDICTO EN UNA LÍNEA

> **NO aguanta — pero aguanta MEJOR, y por una razón que el diseño no escribió: la protección que
> `blue_score` da sobre `pos` es exactamente `E[incremento de blue_score por bloque de cadena]`, y
> el atacante la **derriba de 4,81 a 1,49** inflando `λ_chain`, que es gratis. En el límite
> `incremento = 1`, `blue_score ≡ pos`.** Menú gratis medido **2,33-3,25** (frente a 4,50-5,25 del
> ancla `pos`); reactivo en línea **1,77-2,12**. Y aparece un canal nuevo que `pos` **no tenía**:
> con la cadena seleccionada **idéntica**, el ancla se mueve igual (menú 1,35-1,57), y el ancla
> está **sesgada hacia el atacante** (59,3 % de los umbrales a `α=0,25`, frente al 49,3 % de los
> bloques de cadena).

---

## 0 · Instrumento — EXTENSIÓN, no reescritura

`r8d_lib.py` importa **sin tocar** `r8c_gd.py` (GHOSTDAG fiel a `rusty-kaspa @ c338d495`, 6 pruebas
en `r8c_test_gd.py`) y `r8c_sim.py` (simulador de eventos, adversario del paper) de D9-c, y añade
solo tres lecturas: `ancla_bs` (primer bloque de cadena con `blue_score ≥ T`), `bs_chain` y
`wH` (score del bloque **virtual** honesto, que es la magnitud literal del Lema 9,
`phantom-ghostdag.txt` L1035-1037).

**Validación cruzada contra D9-c, en las mismas semillas y las mismas estrategias.** Mi lectura del
ancla `pos` reproduce sus números **exactamente**:

| medida | D9-c publicado | D9-d medido |
|---|---:|---:|
| `m` gratis, `pos`, α = 0,10 / 0,25 / 0,33 / 0,40 | 4,50 / 5,00 / 5,17 / 5,25 | **4,50 / 5,00 / 5,17 / 5,25** |
| `m` reactivo, `pos`, α = 0,10 / 0,25 / 0,33 / 0,40 | 2,08 / 2,92 / 2,50 / 2,17 | **2,08 / 2,92 / 2,50 / 2,17** |
| % de bloques de cadena del atacante, α = 0,25 | 49,2 % | **49,3 %** |
| `λ_chain` a α = 0 | 0,1988 | **0,2009** |

No estoy midiendo otra cosa. Todo lo que sigue usa el **adversario del paper**
(`phantom-ghostdag.txt` L1024-1027: *«suffers no internal delays or delays from or to honest
nodes»*), nunca uno retardado.

---

# A1 · ¿Es grindable `blue_score`? — **REFUTADO** (sí lo es), aunque menos que `pos`

Scripts: `r8d_a1_menu.py` (menú, tres niveles de coste), `r8d_a1b_reactivo.py` (menú realizable en
línea), `r8d_lib.py`. Salidas: `salida_a1_menu.txt`, `salida_a1b.txt`.

**Método.** Idéntico al de D9-c —números aleatorios comunes, familia dirigida de ~230 estrategias,
menú contado siempre sobre `seed` (fijado en la creación del bloque, jamás recalculado)— con una
sola diferencia: **en la misma ejecución se leen las dos anclas**, la de D9-c (`pos`) y la de ahora
(`blue_score`). El umbral no es un punto: `T` recorre una banda de **21 valores enteros** alrededor
del `blue_score` del ocupante honesto de referencia, y el menú se promedia sobre la banda. Así no
hay elección afortunada de `c·j`.

### A1.1 · El menú, medido

`P = 30`, 12 semillas, `k = 30`, `mp = 15`, U3″ dinámica, `Δ = 4 s`, horizonte 260 s:

| `α` | **m `pos`** (D9-c) | **m `blue_score`** | m_BS +retraso | m_BS +retención | m_POS +retención |
|---:|---:|---:|---:|---:|---:|
| 0,00 | 1,00 | **1,00** (0/12 con m>1) | 1,00 | 1,00 | 1,00 |
| 0,10 | 4,50 | **2,33** (máx 5) | 3,38 | 4,35 (máx 9) | 7,33 |
| 0,25 | 5,00 | **3,03** (máx 5) | 4,29 | 7,53 (máx 13) | 9,50 |
| 0,33 | 5,17 | **3,17** (máx 6) | 4,32 | 8,24 (máx 15) | 10,50 |
| 0,40 | 5,25 | **3,25** (máx 6) | 4,34 | 8,17 (máx 18) | 10,67 |

**Criterio α: PASA.** `α = 0` da exactamente 1,00 en 12/12 semillas en las dos lecturas, y el
resultado cambia con `α` en las seis columnas.

**Menú realizable EN LÍNEA** (atacante reactivo: solo usa bloques creados *después* de que ya
exista el candidato, y los publica al instante; sin retención, sin mirar al futuro):

| `α` | 0,00 | 0,05 | 0,10 | 0,15 | 0,25 | 0,33 | 0,40 |
|---|---:|---:|---:|---:|---:|---:|---:|
| m `pos` (D9-c) | 1,00 | 1,25 | 2,08 | 2,08 | 2,92 | 2,50 | 2,17 |
| **m `blue_score`** | **1,00** | **1,23** | **1,77** | **1,70** | **2,12** | **2,02** | **2,02** |
| semillas con m>1 | 0/12 | 6/12 | 12/12 | 11/12 | 12/12 | 12/12 | 12/12 |

> **El ancla `blue_score` NO es inmune. Reduce el menú un 30-45 %, no lo cierra.** Sigue muy por
> encima del `m ≈ 1,3-2,0` que el principal usó para derivar `I = 2 490 s`, y por encima incluso en
> la lectura más conservadora que existe (reactiva, en línea, gratis).

### A1.2 · **Por qué** reduce: y el atacante controla exactamente ese factor

La única cosa que `blue_score` tiene y `pos` no es la **granularidad**: entre dos bloques de cadena
consecutivos el `blue_score` sube `|mergeset_blues|`, no 1. Un desplazamiento de una unidad mueve el
ancla con probabilidad ~`1/E[incremento]`, mientras que con `pos` la mueve **siempre**.

Medido (`r8d_a2_cruce.py`, cadena entera, 12 semillas):

| `α` | 0,00 | 0,10 | 0,25 | 0,33 | 0,40 |
|---|---:|---:|---:|---:|---:|
| **E[incremento de `blue_score`]** | **4,81** | 2,89 | **1,93** | 1,66 | **1,49** |
| mediana | 5 | 2 | 1 | 1 | 1 |
| **P(incremento = 1)** | 0,040 | 0,420 | **0,633** | 0,704 | **0,755** |
| `λ_chain` medida | 0,201 | 0,323 | 0,506 | 0,597 | 0,661 |

`E[incremento] = λ_blue/λ_chain`, y **`λ_chain` la infla el atacante gratis** (D9-c A1.3: el
adversario del paper no sufre retardo, sus bloques cuelgan siempre de la punta más fresca y ganan
la carrera de `sp`). Luego:

> **La protección que `blue_score` ofrece sobre `pos` vale exactamente `E[incremento]`, y el
> atacante la derriba de 4,81 a 1,49 sin pagar nada. Con incremento 1 —el 75 % de los bloques de
> cadena a `α = 0,40`— `blue_score` y `pos` son la MISMA ancla.** Esto no está escrito en la
> propuesta, y es la razón por la que el tercer ancla no cierra lo que el segundo dejó abierto.

**Etiqueta: REFUTADO** («`blue_score`… no lo infla el atacante añadiendo saltos» es cierto, y aun
así el ancla es grindable, porque el atacante ataca la granularidad, no el salto).

### A1.3 · Lo que SÍ arregla, y hay que apuntárselo — la duración de la época

D9-c A1.4 encontró que con `pos` el atacante **acorta la época**: `c` se cuenta en posiciones,
`I′ = c/λ_chain`, y `λ_chain` pasa de 0,199 a 0,661 → la época dura hasta **3,3 veces menos** de lo
derivado, y `g ∝ 1/√I` sube en consecuencia. Con `blue_score`, `c` se cuenta en **azules** y el
retarget mide azules. Medido (`r8d_a5_deriva.py` §2, `wH` sobre 6 semillas):

| `α` | 0,00 | 0,05 | 0,10 | 0,15 | 0,25 | 0,33 | 0,40 |
|---|---:|---:|---:|---:|---:|---:|---:|
| **`λ_blue`** | 0,971 | 0,973 | 0,973 | 0,975 | 0,978 | 0,977 | **0,975** |
| `I′/I` con `blue_score` | 1,030 | 1,028 | 1,028 | 1,025 | 1,023 | 1,024 | **1,026** |
| `I′/I` con `pos` (D9-c) | 0,992 | 0,760 | 0,616 | 0,517 | 0,393 | 0,333 | **0,301** |

> **VERIFICADO: el tercer ancla cierra por completo el defecto A1.4 de D9-c.** `λ_blue` es plana en
> `α` (0,971-0,978) y la época real nunca se desvía más del **3 %** de la nominal. Es la mejora
> mayor del cambio de ancla, y **la propuesta no la reclama** (no está escrita en §2).
> **Salvedad:** con U3′-**filtro** en vez de U3″ dinámica, `λ_blue` sube a **1,63-1,83** (A3), y la
> época se **acorta a la mitad**. El resultado depende de que U3″ dinámica esté puesta.

---

# A2 · El cruce del umbral — **canal NUEVO, que `pos` no tenía**

Script: `r8d_a2_cruce.py`, `r8d_a2b_captura.py`, `r8d_a2c_sesgo.py`. Salidas `salida_a2*.txt`.

### A2.1 · Con la cadena seleccionada **idéntica**, el ancla se mueve igual

Menú acumulado contando **solo** las estrategias cuya cadena seleccionada final es la **misma lista
de bids** que la de referencia:

| `α` | m total | **m con la cadena CONGELADA** | máx | estrategias congeladas (de ~230) |
|---:|---:|---:|---:|---:|
| 0,00 | 1,00 | **1,00** | 1 | 13,0 |
| 0,10 | 4,35 | **1,35** | 2 | 9,5 |
| 0,25 | 7,53 | **1,47** | 3 | 26,2 |
| 0,33 | 8,24 | **1,52** | 3 | 33,8 |
| 0,40 | 8,17 | **1,57** | 3 | 44,8 |

> **Con `pos` esta columna vale 1 por definición** —`Chn[P]` de la misma sucesión de bloques es el
> mismo bloque, y da el mismo `seed`—. Con `blue_score` no: **la misma sucesión de bloques de
> cadena, en el mismo orden, cruza `c·j` en un bloque distinto** porque el atacante cambia cuántos
> azules fusiona cada uno. **Es un canal de grinding que el segundo ancla no tenía.** Vale 1,35-1,57
> por sí solo.

**Enunciado exacto, comprobado aparte** (`r8d_a2d_precision.py`, porque «cadena idéntica» era
impreciso — ver *Mis propios errores* nº 5): congelar la sucesión de bloques de cadena **no**
congela sus padres. En 3-6 de esas ejecuciones **los padres de algún bloque de cadena difieren**, y
ese es el mecanismo: el atacante no cambia la cadena, cambia **el mergeset** de sus bloques.

```
 alpha |  n congeladas |  con PADRES distintos |  menu POS |  menu BS medio   max
  0.00 |           5.0 |                   0.0 |      1.00 |           1.00     1
  0.10 |           7.2 |                   3.0 |      1.00 |           1.35     2
  0.25 |          16.8 |                   5.2 |      1.00 |           1.47     3
  0.40 |          25.1 |                   6.1 |      1.00 |           1.57     3
```

El mecanismo, medido directamente: el atacante puede darle al **mismo** bloque de cadena de
referencia hasta **5,25 valores distintos de `blue_score`**, en un rango de **−22 a 0** unidades
(`α = 0,40`; a `α = 0` el rango es exactamente `{0}`).

### A2.2 · El ancla está **SESGADA** hacia el atacante — hallazgo no pedido

Si el ancla fuera neutral, la probabilidad de que caiga en un bloque del atacante sería su cuota de
**umbrales** (suma de sus incrementos / `blue_score` total), no su cuota de **bloques**. No lo es
(`r8d_a2c_sesgo.py`, cadena entera, sin ninguna estrategia — el atacante juega limpio):

| `α` | % de BLOQUES de cadena suyos | **% de UMBRALES suyos** | incr. medio atacante | incr. medio honesto |
|---:|---:|---:|---:|---:|
| 0,05 | 18,8 % | **20,7 %** | 4,11 | 3,64 |
| 0,10 | 30,9 % | **37,2 %** | 3,59 | 2,71 |
| 0,25 | **49,3 %** | **59,3 %** | 2,37 | 1,58 |
| 0,33 | 55,5 % | **65,2 %** | 1,96 | 1,30 |
| 0,40 | 59,7 % | **68,6 %** | 1,72 | 1,17 |

**La causa es el propio modelo del paper.** El atacante no sufre retardo (L1024-1027): ve **todas**
las puntas y las fusiona todas; el honesto es ciego durante `Δ`. Sus bloques de cadena fusionan
**1,5 veces más azules** que los honestos, y como cada bloque «posee» tantos umbrales como su
incremento, **se queda con 10 puntos más de los umbrales que de los bloques**.

> **Cambiar de `pos` a `blue_score` SUBE la probabilidad de que el ancla sea un bloque del atacante,
> de 49,3 % a 59,3 % a `α = 0,25`.** Es lo contrario de lo que el cambio pretendía.

Y **eligiendo padres**, gratis, sin retener nada (`r8d_a2b_captura.py`, tier 1):

| `α` | 0,00 | 0,05 | 0,10 | 0,25 | 0,33 | 0,40 |
|---|---:|---:|---:|---:|---:|---:|
| ancla suya **sin atacar** | 0,0 % | 21,8 % | 40,5 % | 65,1 % | 65,9 % | 71,0 % |
| ancla suya **eligiendo padres** | 0,0 % | 23,4 % | 48,8 % | **80,6 %** | 82,5 % | **88,1 %** |

**Matiz honesto, y es importante:** que el ancla sea *suya* no multiplica el menú por sí solo —la
entropía de un bloque es `blake3(chunk ‖ pot_output)`, fijada por el billete ganador, y no se muele.
Lo que mide esta tabla es **cuántas épocas eligen su entropía sin que la red honesta tenga voz**;
el valor de la elección sigue siendo `m`. Pero un diseño que dice «la entropía la aporta el bloque
que cruza el umbral» debería escribir que a `α = 0,25` ese bloque es del atacante en **4 de cada 5
épocas** si él lo quiere. **Etiqueta: VERIFICADO** (medida directa, criterio α pasa).

---

# A4 · `S_max` — **la cota existe, y ENTRA EN CONFLICTO con R-FIN-7**

Script: `r8d_a4_smax.py`. Salida: `salida_a4.txt`.

R-FIN-1a pide `slot(B) − slot(sp(B)) ≤ S_max` con `S_max` **por fijar** (D9-c A4). Se acota por los
dos lados y **se cruzan**.

### A4.1 · Suelo (a): operación normal — medido

Salto de slot entre bloques consecutivos de la cadena seleccionada:

| `α` | medio | p50 | p90 | p99 | máx observado |
|---:|---:|---:|---:|---:|---:|
| 0,00 | 4,97 | 4,7 | 6,2 | 8,2 | 12,3 |
| 0,25 | 1,97 | 1,4 | 4,8 | 7,4 | 10,9 |
| 0,40 | 1,50 | 1,0 | 3,8 | 6,4 | 10,9 |

La cola es geométrica, `P(salto > S) ≈ e^{−λ_chain·S}` con `λ_chain = 0,199` (el caso más lento, sin
ataque). Para que **ningún** bloque honesto sea inválido en 10 años (31,5 M bloques):

| objetivo | `10⁻⁶` | `10⁻⁹` | `10⁻¹²` |
|---|---:|---:|---:|
| `S_max ≥` | 69 slots | 104 slots | **139 slots** |

### A4.2 · Suelo (b): partición — y aquí está el conflicto

R-FIN-7 promete tolerar particiones de hasta `F`. Un lado con fracción `f` del espacio produce
bloques a tasa `f·λ` y el mayor hueco entre dos de ellos es el máximo de `f·λ·P` exponenciales.
`S_max` necesario para que ese lado **no fabrique ningún bloque inválido** con probabilidad ≥ 99 %
durante una partición de `F = 3,2 h`:

| `f` (espacio del lado) | 0,02 | 0,05 | **0,10** | 0,20 | **0,33** | 0,50 |
|---|---:|---:|---:|---:|---:|---:|
| mayor hueco esperado | 301 s | 139 s | 76 s | 42 s | 27 s | 18 s |
| **`S_max` necesario** | **522 s** | **222 s** | **119 s** | 65 s | **40 s** | 28 s |

### A4.3 · Techo: el DoS de verificación de PoT

`CLAUDE.md`: la verificación del PoT de Autonomys **no es sucinta** —recomputa una cadena AES—, así
que el coste es **lineal en slots**. En régimen la red verifica **1 slot/s**. Un atacante con
fracción `α` y `n_cop` bloques por billete fuerza `α·λ·n_cop·S_max` slots/s:

| `S_max` | ×`α`=0,10 | ×0,25 | ×0,40 | ×0,25 con 14 copias | ×0,40 con 14 copias | B/s que él envía |
|---:|---:|---:|---:|---:|---:|---:|
| 10 | 1 | 2 | 4 | 35 | 56 | 0,01 MB |
| **150** | 15 | 38 | **60** | 525 | **840** | 0,11 MB |
| 3 600 | 360 | 900 | 1 440 | 12 600 | 20 160 | 2,58 MB |
| **11 520** (= `F`) | 1 152 | 2 880 | **4 608** | 40 320 | **64 512** | 8,26 MB |

(La columna de bytes usa 128 B/slot de justificación de PoT, la cifra que ya está en
`dag-poas-inyeccion-auditoria.md` L425. El **valor absoluto de `slot_iterations` de Autonomys es una
LAGUNA**: no hay clon local del repositorio, así que todo lo de arriba está en **múltiplos del
presupuesto que la red ya gasta**, no en milisegundos.)

### A4.4 · La propuesta y su precio

> **`S_max = 150 slots`** (≈ 2,5 min). Cubre la cola de operación normal a `10⁻¹²` (139) con margen,
> cubre una partición de `F = 3,2 h` para cualquier lado con **`f ≥ 0,09`** del espacio, y deja la
> amplificación de DoS en **×60** a `α = 0,40` sin copias.

**Y esto es lo que hay que escribir en §4 de la propuesta, porque hoy no está:**

> **R-FIN-7 dice «tolerancia a particiones = `F` = 3,2 h». Con `S_max` finita eso es FALSO.** La
> tolerancia real es «`F`, **siempre que el lado conserve ≥ 9 % del espacio**». Por debajo de eso el
> lado minoritario se **para**: su primer bloque tras el hueco viola R-FIN-1a y es inválido, y no
> puede seguir su propia cadena. Las dos reglas se contradicen tal como están escritas: para
> cumplir R-FIN-7 al pie de la letra haría falta `S_max ≥ F·λ = 11 520`, que es una amplificación de
> DoS de **×4 608** (y de ×64 512 con copias). **No existe `S_max` que satisfaga las dos.**
> Hay que elegir, y la elección razonable es acotar `S_max` y **reescribir R-FIN-7** con la
> condición sobre `f`.

**Etiqueta: `S_max = 150` PLAUSIBLE** (derivada de dos medidas y una cota analítica);
**la contradicción R-FIN-1a ⊗ R-FIN-7 es DEMOSTRADA** (aritmética, no simulación).
**LAGUNA:** el coste absoluto en ms de un slot de PoT de Autonomys.

---

# A5 · Rederivar `I`, `c` y `F` — **SÍ EXISTE (I, F)**, y no son los publicados

Scripts: `r8d_a5_deriva.py`, `r8d_a5b_niveles.py`. Salidas: `salida_a5.txt`, `salida_a5b.txt`.
`c_m` se importa de `r8c_steering.py` de D9-c (integración numérica, contrastada con los valores
publicados `c_2 = 0,564`, `c_4 = 1,029`).

Pinza: `g = c_m/√(αλI) ≤ 3,6 %` **y** `W/κ = 1 + I/F ≤ 1,22`. Peor `α` en los dos casos: **0,10**
(porque `g ∝ 1/√α`, y a `α = 0,05` la `m` medida ya cae a 1,23-1,47).

| nivel de coste del atacante | peor `α` | `m` medida | `c_m` | **`I`** | **`F`** | `c` (azules) |
|---|---:|---:|---:|---:|---:|---:|
| reactivo (en línea, gratis) | 0,10 | 1,77 | 0,4344 | 1 456 s (0,40 h) | 6 619 s (**1,84 h**) | 1 420 |
| **gratis ex post** | 0,10 | 2,33 | 0,6573 | **3 333 s (0,93 h)** | **15 152 s (4,21 h)** | **3 250** |
| + retraso | 0,10 | 3,38 | 0,9159 | 6 472 s (1,80 h) | 29 419 s (8,17 h) | 6 310 |
| + retención | 0,10 | 4,35 | 1,0761 | 8 936 s (2,48 h) | 40 617 s (**11,28 h**) | 8 712 |
| *referencia:* ronda 8 publica | — | 4 asumida | 1,029 | 2 490 s (0,69 h) | 3,20 h | 2 490 |
| *referencia:* D9-c, ancla `pos` | 0,10 | 4,50 | 1,096 | 9 272 s (2,58 h) | 11,70 h | — |

> **RESPUESTA A LA PREGUNTA 4: sí existe.** Con el ancla `blue_score` y dimensionando contra el
> atacante **gratis** (el que no renuncia a nada):
>
> ```
> I = 3 330 s ≈ 55 min      c = 3 250 azules      F = 4,2 h      W/κ = 1,22      g = 3,6 %
> ```
>
> **Los publicados (`I = 2 490 s`, `F = 3,2 h`) NO se sostienen:** `I` se queda un 34 % corta y `F`
> un 31 %. Pero el ancla `blue_score` **sí compra algo grande**: con el ancla `pos`, D9-c pedía
> `F = 11,7 h`; aquí bastan **4,2 h**. Es el argumento a favor del tercer ancla, y es real.

**Y el precio, dicho entero:** si se dimensiona contra un atacante que **retiene** bloques —que es
lo que un atacante con presupuesto hace—, la `m` medida es 4,35 y hacen falta `I = 2,5 h` y
**`F = 11,3 h`**, casi lo mismo que pedía el ancla `pos`. **La ventaja del tercer ancla vive entera
en el supuesto de que el atacante no retenga.** Eso es una elección de modelo de amenaza y hay que
escribirla con esa etiqueta, no derivarla.

Sensibilidad (por si se mueven los techos, `salida_a5.txt` §4):

| techo `g` | `W/κ ≤ 1,10` | `W/κ ≤ 1,22` | `W/κ ≤ 1,50` |
|---|---|---|---|
| 2,0 % | I=2,99 h F=29,9 h | I=2,99 h F=13,6 h | I=2,99 h F=5,98 h |
| **3,6 %** | I=0,92 h F=9,22 h | **I=0,92 h F=4,19 h** | I=0,92 h F=1,84 h |
| 5,0 % | I=0,48 h F=4,78 h | I=0,48 h F=2,17 h | I=0,48 h F=0,96 h |

**Etiqueta: VERIFICADO** (la `m` está medida, `c_m` contrastado, criterio α pasa: `α = 0` da `m = 1`
y `c_m = 0`). **Cota, no realidad:** `m` sigue siendo una **cota inferior** por familia dirigida
(D9-c LAGUNA 2), así que `I` y `F` de arriba son **mínimos**.

---

# A3 · ¿Sobrevive el Lema 9 a U3″ dinámica? — **SÍ, DEMOSTRADO en simulación de eventos** (y U3′-filtro **no**)

Scripts: `r8d_a3_delta.py`, `r8d_a3b_optim.py`, `r8d_a3c_horizonte.py`, `r8d_a3d_kaspa.py`,
`r8d_a3e_diag.py`, `r8d_a3f_shuffle.py`, **`r8d_a3g_final.py`** (el definitivo).
Salidas: `salida_a3*.txt`.

Esta línea era la **LAGUNA 5 de D9-c** (*«`δ_ef` bajo U3′-filtro no lo he medido en simulación de
eventos, solo en el contraejemplo determinista»*). **Queda cerrada.**

**Magnitud medida.** Lema 9 (`phantom-ghostdag.txt` L1074-1077): `E[wH(t+r) − wH(t)] ≥ (1−α)(1−δ)rλ`.
Se mide el daño directo:
`δ_hon = 1 − (honestos de la ventana que acaban AZULES)/(honestos creados en la ventana)`.
Ventana `[80, 300] s`, horizonte 400 s, 10 semillas, `k = 30`, `mp = 15`, y
**`pick_virtual_parents` COMPLETO**: presupuesto + sustitución por ancestro + **shuffle**.

| `u3` | copias | política | `α=0,00` | `α=0,10` | `α=0,25` | **`α=0,40`** (medio / peor semilla) |
|---|---:|---|---:|---:|---:|---:|
| **dynamic** | 0 | tips | **0,0000** | 0,0000 | 0,0000 | **0,0000** / 0,0000 |
| dynamic | 6 | retro1 | 0,0000 | 0,0000 | 0,0032 | 0,0141 / 0,0752 |
| **dynamic** | 14 | retro1 | **0,0000** | 0,0009 | 0,0465 | **0,1293** / 0,1967 |
| dynamic | 14 | retro8 | 0,0000 | 0,0348 | 0,0790 | 0,0754 / 0,1475 |
| dynamic | 14 | retro1 +12 s | 0,0000 | 0,0153 | 0,0273 | 0,0481 / 0,0732 |
| **filter** | 14 | retro1 | 0,0000 | 0,1139 | **0,2519** | **0,3786** / 0,4848 |
| **off** (sin regla) | 14 | retro1 | 0,0000 | 0,1663 | 0,3769 | **0,4917** / 0,5789 |

> **U3″ dinámica: `δ_ef` máximo medido = 0,1293.** Por debajo del `δ = 0,2105` nominal (**39 % de
> margen**) y del `δ_real = 0,267` (**52 %**). Ninguna de las 11 estrategias lo supera.
> **U3′-filtro: `δ_ef` = 0,379 a `α = 0,40` y 0,252 a `α = 0,25`.** **Supera `δ_real = 0,267`** y
> queda al nivel de no tener ninguna regla de unicidad (0,492). **La refutación de D9-c se confirma
> en simulación de eventos, no solo en el contraejemplo determinista, y la reparación era necesaria.**

**Criterio α: PASA de forma exacta.** `α = 0` da **0,0000 en las 11 filas** —coherente con el
`1,2·10⁻⁶` que R-FIN-8 publica para `P(honesto acabe rojo)` a `k=30`—, y el resultado crece
monótonamente con `α` en las filas con copias.

### A3.1 · El mecanismo del daño **no es el que la propuesta supone** — y R-FIN-12 no lo nombra

`r8d_a3e_diag.py` instrumenta la selección de padres bajo inundación de copias (`α = 0,40`,
14 copias, semilla 3):

```
alpha=0.40 copias=14 retro1 | bloques=2532   puntas medias=547.8   max=1131
   corta_por_mp=232   corta_por_msl=0   SUSTITUCIONES=0   mergeset medio=18.3
   honestos en ventana=123  no fusionados=20  de ellos SIGUEN SIENDO PUNTA al final=20
```

- **El presupuesto de mergeset NUNCA se agota** (`corta_por_msl = 0`) y **la rama de sustitución de
  Kaspa nunca dispara** (`SUSTITUCIONES = 0`). El ataque de presupuesto de D9-a/D9-c A3b, en
  simulación de eventos con `mergeset_size_limit = 180`, **no se materializa**.
- Lo que se agota es **`max_block_parents = 15`** frente a **548 puntas de media y 1 131 de pico**.
  Las copias son **rojas al colorear** bajo U3″, pero conservan su **propio `blue_work`** como
  candidatas a padre, y desplazan a las puntas honestas del conjunto de 15. **20 bloques honestos
  quedan como puntas para siempre: nunca entran en el DAG.**
- **Control de horizonte** (`r8d_a3c_horizonte.py`): con la ventana fija en `[80, 300] s` y el
  horizonte a 400, 800 y 1 200 s, `δ_hon` es **idéntico**. El daño es **permanente**, no «pendiente
  de fusionar».

**La contramedida existe en Kaspa y R-FIN-12 no la menciona.** `processor.rs:1069-1089`, comentario
literal: *«Prioritize half the blocks with highest blue work and pick the rest **randomly** to ensure
diversity between nodes»* — se conservan `max_block_parents/2 = 7` por `blue_work` y el resto se
elige al azar entre `max_block_parents·3 = 45` candidatos (`:975-980`). Medido
(`r8d_a3f_shuffle.py`):

| escenario | `α` | sin shuffle | **con shuffle** |
|---|---:|---:|---:|
| dynamic, 14 copias retro1 | 0,25 | δ=0,181 · 14,0 honestos fuera | **δ=0,119 · 0,0 fuera** |
| dynamic, 14 copias retro1 | 0,40 | δ=0,203 · 20,6 fuera | **δ=0,156 · 2,2 fuera** |
| filter, 14 copias retro1 | 0,40 | δ=0,447 · 25,2 fuera | δ=0,396 · 5,2 fuera |

> **El `shuffle` —la LAGUNA 1 de D9-c, que ellos descartaron como «no puede aumentar `m`»— resulta
> ser la contramedida contra la inundación de puntas.** Sin él se pierden 14-21 bloques honestos
> para siempre; con él, 0-2. **R-FIN-12 tiene que adoptarlo explícitamente**, junto con
> `pick_virtual_parents`, `merge_depth_bound` y `pruning_depth`.

### A3.2 · ¿Reabre U3″ algo que U3′-filtro no tenía?

**No he encontrado nada, y digo por dónde busqué.** U3″ marca la copia **roja antes** de llamar a
`check_blue_candidate`, así que —a diferencia de la forma `post` que D9-a refutó— **no consume hueco
en `mergeset_blues` ni incrementa `blues_anticone_sizes` de los pares**: es estrictamente menos
dañina que `filter` y que `post` en todas las medidas de arriba. La dependencia nueva que introduce
es del **orden del mergeset** (`sort_blocks` por `(blue_work, desempate)`), que sigue siendo función
determinista de `past(B)` (R-FIN-4 se cumple) y que el atacante puede usar para elegir **cuál** de
sus copias sobrevive como azul — pero las copias de un mismo billete comparten `chunk` y `slot`,
luego **comparten entropía** (R-FIN-2), y elegir entre ellas **no añade ninguna entrada al menú**.
**Etiqueta: PLAUSIBLE que no reabra nada; no DEMOSTRADO.**

---

# VEREDICTO

> **NO aguanta. El ancla `blue_score` es grindable —menú gratis 2,33-3,25, reactivo en línea
> 1,77-2,12— y además está SESGADA hacia el atacante (59,3 % de los umbrales a `α = 0,25` frente al
> 49,3 % de los bloques). Pero es el mejor de los tres: reduce el menú un 30-45 %, cierra por
> completo el defecto de la duración de época que hundía al ancla `pos`, y con él SÍ existe un
> `(I, F)` que cumple la pinza: `I ≈ 3 330 s`, `F ≈ 4,2 h`, `c ≈ 3 250 azules` —no los
> `I = 2 490 s`, `F = 3,2 h` publicados.**

| Línea | Etiqueta | Qué queda |
|---|---|---|
| **A1** · ¿grindable `blue_score`? | **REFUTADO** (sí lo es) | `m` gratis **2,33-3,25**, reactiva en línea **1,77-2,12**, con retención 4,35-8,24. La protección sobre `pos` **vale `E[incremento]`, y el atacante la baja de 4,81 a 1,49 gratis**: a incremento 1, `blue_score ≡ pos`. **A favor:** `λ_blue` es plana (0,971-0,978), la época real nunca se desvía > 3 % — el defecto A1.4 de D9-c queda **cerrado** |
| **A2** · el cruce del umbral | **REFUTADO** · canal NUEVO | Con la cadena seleccionada **idéntica** el ancla se mueve igual: menú **1,35-1,57** (con `pos` esta columna vale 1 por definición). Y el ancla es **suya** el 59,3 % de los umbrales sin atacar y el **80,6 %** eligiendo padres, a `α = 0,25` |
| **A3** · ¿sobrevive el Lema 9 a U3″? | **DEMOSTRADO que sí** (en las estrategias probadas) | `δ_ef ≤ 0,1293` con U3″ dinámica y `pick_virtual_parents` completo: **39 % de margen** sobre `δ = 0,2105` y **52 %** sobre `δ_real = 0,267`. **U3′-filtro sí lo rompe: 0,379.** LAGUNA 5 de D9-c **cerrada**. El mecanismo del daño **no es el presupuesto de mergeset** sino el tope de padres, y lo cierra el **`shuffle`** que R-FIN-12 no nombra |
| **A4** · `S_max` | **`S_max = 150` PLAUSIBLE**; **contradicción DEMOSTRADA** | 150 slots cubre la cola normal a `10⁻¹²` y una partición de `F` para `f ≥ 0,09`, con DoS ×60 a `α=0,40`. **R-FIN-1a y R-FIN-7 no pueden cumplirse a la vez**: literalmente, R-FIN-7 exige `S_max ≥ 11 520` = DoS ×4 608 |
| **A5** · rederivar `I`, `c`, `F` | **VERIFICADO** | **Existe:** `I = 3 330 s (0,93 h)`, `F = 4,21 h`, `c = 3 250` azules, dimensionando contra el atacante **gratis**. Contra uno que **retiene**: `I = 2,48 h`, `F = 11,28 h`. Los publicados (2 490 s / 3,2 h) **no se sostienen** |

## Mi `m` frente a la de D9-c

| lectura | D9-c (`pos`) | **D9-d (`blue_score`)** | reducción |
|---|---:|---:|---:|
| reactivo en línea, `α = 0,10` | 2,08 | **1,77** | −15 % |
| reactivo en línea, `α = 0,25` | 2,92 | **2,12** | −27 % |
| gratis ex post, `α = 0,10` | 4,50 | **2,33** | **−48 %** |
| gratis ex post, `α = 0,25` | 5,00 | **3,03** | −39 % |
| gratis ex post, `α = 0,40` | 5,25 | **3,25** | −38 % |
| con retención, `α = 0,25` | 9,50 | **7,53** | −21 % |
| con retención, `α = 0,40` | 10,67 | **8,17** | −23 % |

**Sí baja `m` sustancialmente en la lectura gratis (−38 a −48 %) y eso se traduce en `F`: 11,7 h con
`pos` frente a 4,2 h con `blue_score`. El ancla aporta. Lo que no hace es cerrar el ataque.**

## Salida de `AUDITA_SCRIPTS.py`

```
$ python3 /home/katana/zeo/ZEROX/research/scripts/AUDITA_SCRIPTS.py \
          /home/katana/zeo/ZEROX/research/scripts/d9-ronda8d/
Scripts analizados: 17

======================================================================
Sospechas totales: 0
```

**Hubo una marca antes de limpiarla, y la declaro:**
`[T3b] r8d_a2_cruce.py L44: ['acum_all','acum_frz'] = MISMA expresión: {T: set() for T in Ts}`
— dos acumuladores **independientes** inicializados con el mismo literal. Falso positivo (dan
resultados distintos: 4,35-8,17 frente a 1,35-1,57), pero los separé y **volví a ejecutar el
script** para no publicar números de una versión distinta de la que está en el repositorio.

**Criterio α, tabla completa:**

| medida | `α = 0` | 0,10 | 0,25 | 0,40 |
|---|---:|---:|---:|---:|
| menú `blue_score`, gratis | **1,00** (0/12 con m>1) | 2,33 | 3,03 | 3,25 |
| menú `blue_score`, reactivo | **1,00** (0/12) | 1,77 | 2,12 | 2,02 |
| menú con cadena congelada | **1,00** | 1,35 | 1,47 | 1,57 |
| desplazamiento de `blue_score` del mismo bloque | **{0}** | [−12,0] | [−17,0] | [−22,0] |
| E[incremento de `blue_score`] | **4,81** | 2,89 | 1,93 | 1,49 |
| `λ_blue` | **0,971** | 0,973 | 0,978 | 0,975 |
| ancla del atacante, sin atacar | **0,0 %** | 40,5 % | 65,1 % | 71,0 % |
| `δ_hon`, U3″ + 14 copias | **0,0000** | 0,0009 | 0,0465 | 0,1293 |
| `δ_hon`, U3′-filtro + 14 copias | **0,0000** | 0,1139 | 0,2519 | 0,3786 |

---

# Mis propios errores

1. **Mi hipótesis de partida era falsa, y por poco no la compruebo.** Predije que `blue_score`
   dividiría `m` por `E[incremento] ≈ 5`. Sale **1,5-1,7×**. La razón —que el atacante colapsa el
   incremento inflando `λ_chain`— solo apareció porque medí la granularidad **por separado**
   (`r8d_a2_cruce.py` (1)). Si me hubiera quedado en el menú habría publicado «reduce poco» sin
   saber **por qué**, y sin ver que a `α = 0,40` el ancla **degenera en la refutada**.

2. **Una comparación mía fue una TAUTOLOGÍA, y casi la firmo.** `r8d_a3d_kaspa.py` comparaba
   `pick_virtual_parents` con y sin la rama de **sustitución** de Kaspa y daba resultados
   **idénticos hasta la cuarta cifra** en 16 filas. Iba a escribir «R-FIN-12 completa no cambia
   nada». Instrumenté (`r8d_a3e_diag.py`) y la razón era otra: **la rama de sustitución no dispara
   NUNCA** (`SUSTITUCIONES = 0`, `corta_por_msl = 0`), porque el presupuesto de mergeset no se agota.
   La comparación no medía nada.
   > **Propongo un detector nuevo para `AUDITA_SCRIPTS.py`, porque el criterio `α` NO lo caza:**
   > cuando un script compara A con B, hay que **comprobar que la rama que distingue a B se
   > ejecuta**. Aquí el criterio `α` pasaba —los números cambiaban con `α`— y aun así la
   > comparación era vacía.

3. **Normalicé `δ` por la esperanza y publiqué ruido de Poisson como daño.** En
   `r8d_a3_delta.py`/`a3b`/`a3c`/`a3d`/`a3f` usé `(1−α)λr` como denominador; el número de honestos
   realmente creados en la ventana es Poisson y con 5 semillas fluctúa ~3 %, así que a `α = 0`
   salía `δ_hon = 0,031` cuando el valor verdadero es **0,0000**. Corregido en `r8d_a3g_final.py`
   normalizando por los honestos **realmente creados**. Todos los números de A3 del informe son los
   corregidos; los de las salidas intermedias quedan en el repositorio con esta advertencia.

4. **Mi primera ventana de medida podía contar como «rojo» a un honesto solo «aún no fusionado»**
   (`[0,20T ; 0,95T]` con la lectura en `T`). Lo cacé yo con el control de horizonte
   (`r8d_a3c_horizonte.py`): el daño resultó **permanente** y el número no cambió, pero la ventana
   estaba mal y la corregí a `[0,20T ; 0,75T]`.

5. **Escribí «con la cadena idéntica» cuando lo que congelaba era la lista de bids.** Lo precisé con
   `r8d_a2d_precision.py`: la lista de bids es **la misma sucesión de bloques y de `seed`** sobre la
   cadena —que es justo lo que el menú cuenta—, pero **los padres de los bloques de cadena sí
   difieren** en 3-6 de esas ejecuciones, y ese es el mecanismo. El enunciado exacto es:
   > *con la misma sucesión de bloques de cadena, `pos` devuelve siempre el mismo ancla (1,00 en
   > 12/12 semillas, por construcción) y `blue_score` devuelve hasta 3 anclas distintas.*

---

# LAGUNAS

1. **`blue_work = blue_score` en el simulador** (peso 1 por bloque). En el diseño real
   `blue_work = Σ⌊2^128/(SR+1)⌋` es **peso**, no conteo, y es lo que elige el padre seleccionado —
   o sea, **la cadena entera**. R-FIN-13 argumenta que la discrepancia sobre `F` queda < 1 %
   (`dag-poas-empalme-peso.md`), pero **eso está probado para el umbral, no para el `m` del
   steering**. Todo A1/A2 está medido con peso uniforme. **Es la laguna mayor de esta ronda.**
2. **`m` es una COTA INFERIOR.** Familia dirigida de ~230 estrategias, heredada de D9-c. **No he
   rehecho la curva de saturación** (D9-c la midió para `pos`: satura entre 200 y 400 estrategias).
   Otra familia puede encontrar más.
3. **Mi `shuffle` usa un único RNG para toda la red honesta.** El argumento de Kaspa es *«to ensure
   diversity **between nodes**»* (`processor.rs:1071`): su valor depende de que **nodos distintos**
   barajen distinto, y mi simulador tiene un solo nodo honesto. **La mitigación medida en A3.1 puede
   ser optimista o pesimista; no lo sé.**
4. **`δ_ef` está medido sobre 11 estrategias, no optimizado.** Que ninguna supere 0,2105 **no
   demuestra** que no exista una que lo haga. Etiqueta correcta: *no he encontrado ninguna*.
5. **El coste absoluto de un slot de PoT de Autonomys es desconocido.** No hay clon local del
   repositorio (`/home/katana/zeo/fuentes/` solo tiene `rusty-kaspa`), así que **todo A4 está en
   múltiplos del presupuesto que la red ya gasta**, nunca en milisegundos. El 128 B/slot viene de
   `dag-poas-inyeccion-auditoria.md` L425, no de fuente primaria leída por mí.
6. **No he vuelto a auditar la Prop. 7 con el ancla nueva.** El **Lema A2 de D9-c** (la cadena
   converge a cada profundidad `p` por la Def. 2, sin cota de la unión) **debería transferirse**,
   porque `blue_score(B)` es función de `past(B)` y por tanto **inmutable una vez `B` existe**: si
   el prefijo de cadena se estabiliza, el bloque que cruza `c·j` también. **Pero no lo he
   demostrado ni comprobado, y A2.1 enseña que el ancla se mueve por caminos que el Lema A2 no
   mira.** LAGUNA.
7. **Sigue en pie la objeción (c) de D9-a**, heredada por D9-c y no tocada por mí: `Risk_u = 1`
   permanente por desacuerdo de flujo (R-FIN-5/R-FIN-7). Si `Risk = 1`, ni la Prop. 7 ni el Lema A2
   dicen nada. **Es anterior a todo esto.**
8. **`k = 30` en todo.** No he rehecho nada con `k = 25`/`mp = 12`.
9. **`Δ = 4 s` sigue sin medir** (laguna §5.7 de la propuesta). `λ_chain`, `E[incremento]`, `δ`,
   `S_max` y `I` dependen de ella.

---

# Lo que hay que cambiar, en orden

1. **Escribir en R-FIN-1 lo que `blue_score` protege y lo que no.** La protección es
   `E[incremento] = λ_blue/λ_chain`, el atacante la baja de 4,81 a 1,49, y **a incremento 1 el ancla
   es la refutada**. Sin ese párrafo, la propuesta afirma una inmunidad que no tiene.
2. **`I = 3 330 s`, `c = 3 250` azules, `F = 4,2 h`** — o decir explícitamente que se dimensiona
   contra un atacante que no retiene, porque contra uno que retiene son `2,5 h` y **11,3 h**.
3. **`S_max = 150` y reescribir R-FIN-7.** «Tolerancia a particiones = `F`» es falso con `S_max`
   finita: es «`F`, si el lado conserva ≥ 9 % del espacio». **No existe `S_max` que cumpla las dos
   reglas tal como están escritas.**
4. **R-FIN-12 tiene que nombrar el `shuffle`** (`processor.rs:1069-1089`) además de
   `pick_virtual_parents`, `merge_depth_bound` y `pruning_depth`. Es lo que evita que 14-21 bloques
   honestos queden fuera del DAG **para siempre** bajo inundación de puntas.
5. **U3″ dinámica se queda.** `δ_ef ≤ 0,129` frente a **0,379** con U3′-filtro: es la diferencia
   entre respetar y romper el `δ_real = 0,267` con el que están calculados todos los umbrales.
6. **Medir `Δ`.** Es la laguna que mueve todos los números de esta ronda.
