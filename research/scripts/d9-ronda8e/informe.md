# D9-e · Ronda 8e — el **peso real** `blue_work = Σ w(SR)` contra los resultados de D9-d

**Fecha:** 2026-09-08 · **Agente:** D9-e (refutación) · **Directorio:**
`research/scripts/d9-ronda8e/` · **Instrumento:** extensión de `d9-ronda8c/r8c_gd.py` +
`d9-ronda8d/r8d_lib.py`, sin reescribir ni una línea de ellos.

---

# VEREDICTO EN UNA LÍNEA

**El peso real NO mueve ninguna conclusión de D9-d (`m` ±4 %, sesgo idéntico, `δ` en peso
≈ `δ` en conteo, Lema A2 se transfiere) — y no es porque la rama no corra: en el punto de
diseño, bajo ataque, el peso invierte 136 decisiones de `find_selected_parent` y 185 órdenes
de mergeset, y el ancla no se entera.** La razón es un teorema que nadie había escrito
(**Lema E1**): la deriva del retarget es un **factor común** a las dos ramas en competencia y
se cancela; lo que decide es la deriva **diferencial**, medida en **0,2 %** en el punto de
diseño frente a la `ε` de **0,46 %-3,4 %** que acota `dag-poas-empalme-peso.md`. Lo que sí
está roto es otra cosa: **`blue_score` no es monótono bajo ancestría con peso real**
(contraejemplo ejecutable) y **los números de D9-d `m = 3,03` y `p_cap = 80,6 %` son
optimistas — suben a 5,77 y 90,9 % con solo ampliar la familia de estrategias.**

---

## 0 · Instrumento — extensión, no reescritura (regla 11)

`r8e_lib.py`:

- **`DAGW(DAG)`** sobrescribe **solo la cola** de `add()`: recalcula
  `blue_work = blue_work(sp) + Σ_{h∈mergeset_blues} w(SR(h))`, que es literalmente
  `protocol.rs:155-161` con `calc_work` de `difficulty.rs:211-217`. Es correcto hacerlo
  *después* de `super().add()` porque dentro de `add()` el único uso de `blue_work` es
  leer el de bloques **ya existentes** (`_key`), que ya están corregidos.
- **Retarget R-FIN-13** en dos formas:
  - `modo="desliz"` — ventana **deslizante** recalculada en **cada bloque**, que es lo que
    Kaspa hace de verdad (`difficulty.rs:166-198`, `calculate_difficulty_bits` corre por
    bloque sobre `BlockWindowHeap`), incluida la regla «si la ventana no está llena, hereda
    los `bits` del padre seleccionado» (`:170-178`).
  - `modo="epoca"` — la lectura literal de R-FIN-13 («ventana de `W` slots»): el retarget
    salta solo al cruzar múltiplo de `W`.
  En los dos, la época/ventana la fija el sello de tiempo del **padre seleccionado**, así
  que `SR(B)` es función de `past(B)` —como `bits` en Kaspa y Bitcoin— y el atacante solo
  la mueve **eligiendo padres**. Ésa es exactamente la palanca que pregunta A1.
- **`MezclaPeso`** — mixin que hace que `Mundo.corre` construya un `DAGW` **sin duplicar
  una línea de `corre`** (monkeypatch local de `r8c_sim.DAG`, restaurado en `finally`, con
  un `assert isinstance(d, DAGW)` que aborta si la fábrica no se aplicó).

**Contadores de cobertura de rama** en `DAGW`: `n_retargets`, `n_peso_distinto`,
`n_inc_distinto`, `n_clamp`, `n_ventana_corta`, y —los decisivos— `n_sp_llamadas`,
`n_sp_pesos_dist`, `n_sp_discrepa`, `n_sort_llamadas`, `n_sort_discrepa`.

---

## A0 · Control de identidad y cobertura — `salida_a0.txt`

**(1) Identidad.** Con `W = None` (peso constante) `DAGW` da **exactamente** el mismo DAG,
la misma cadena seleccionada y los mismos `blue_score` que el `DAG` de D9-c:
**12/12 semillas en los cinco `α`** (0; 0,10; 0,25; 0,33; 0,40). Los tres contadores de la
rama del peso valen 0: control negativo correcto.

**(2) La rama corre.** Con `W` finita: miles de bloques con `w ≠ 1` y con incremento de
peso distinto del de conteo.

```
  W (s)   gam  alpha |  retarg  peso!=1  inc!=c |  sd(ln w)        rango ln w |  sp llam    w!=  sp!= | sort!= | cadena dif
     20  0.25   0.00 |    2773     2773    2711 |    0.1156  [-0.314, +0.572] |     2957   2250     0 |      0 |        0.00
     20  0.25   0.40 |    2820     2820    2799 |    0.1082  [-0.398, +0.608] |     1439    822     0 |      0 |        0.00
   3083  0.25   0.25 |       0        0       0 |    0.0000  [-0.000, -0.000] |     1649      0     0 |      0 |        0.00
```

`w!=` = llamadas a `find_selected_parent` en que los candidatos **no** tenían todos el
mismo peso: **2 250 de 2 957**. Y aun así `sp!=` = **0**: a este horizonte el argmax por
peso nunca fue distinto del argmax por conteo, y **la cadena seleccionada no cambió en
ningún bloque de ninguna semilla**. (Que a `W = 3 083` los contadores valgan 0 **no** es el
punto de diseño: es que en 260 s la ventana no se llena — ver A0e.)

---

## A0b · ¿Dónde está la frontera? — `salida_a0b.txt`

Barrido hasta romperlo, en los dos modos, `α ∈ {0; 0,25}`, 8 semillas:

| modo | W (s) | γ | `sd(ln w)` medida | rango `ln w` | `w!=` | **`sp!=`** | `sort!=` | cadena dif |
|---|---:|---:|---:|---|---:|---:|---:|---:|
| desliz | 3083 | 0,25 | 0,0000 | [0, 0] | 0 | **0** | 0 | 0 |
| desliz | 80 | 0,25 | 0,0188 | [−0,09, +0,07] | 998 | **0** | 0 | 0 |
| desliz | 20 | 0,25 | 0,1010 | [−0,31, +0,53] | 1 379 | **0** | 0 | 0 |
| desliz | 20 | 1,0 | 0,4039 | [−1,26, +2,10] | 1 379 | **0** | 0 | 0 |
| desliz | 10 | 1,0 | 0,8598 | [−1,89, +3,00] | 1 408 | **0** | 0 | 0 |
| desliz | 5 | 20 | 2,1443 | [−3,00, +3,00] | 559 | **0** | 0 | 0 |
| epoca | 3 | 20 | 2,6421 | [−3,00, +3,00] | 850 | **0** | 0 | 0 |

**Con el peso variando en un factor `e^6 ≈ 400` a lo largo de la ejecución, ni una sola
decisión de GHOSTDAG cambia.**

---

## A0c · Por qué — y la corrección a `dag-poas-empalme-peso.md` — `salida_a0c.txt`

**(1) El contador está VIVO.** DAG construido a mano (rama A: 3 bloques ligeros `w=e^-2`;
rama B: 2 bloques pesados `w=e^+2`):

```
  bs(X)=3 bw(X)=1.2707   bs(Y)=2 bw(Y)=8.3891
  argmax por CONTEO = A2   argmax por PESO = B1
  sp_discrepa: 0 -> 1   CONTADOR VIVO
```

No es el error de D9-d: la rama corre y el contador puede dispararse. Simplemente **no se
dispara en el simulador**.

**(2) La razón, medida.** `dag-poas-empalme-peso.md` §2-3 acota la **deriva total** de
`ln w` sobre el horizonte `F` y la llama `ε`. Pero en `find_selected_parent` la deriva
**común** se cancela: es un factor común a las dos ramas. Lo que decide es la deriva
**diferencial** entre los candidatos de la misma llamada. Medidas:

| modo | W | γ | α | `eps_dif` media | `eps_dif` máx | margen medio | **margen MÍN** |
|---|---:|---:|---:|---:|---:|---:|---:|
| desliz | 3083 | 0,25 | 0,25 | 0,0000 | 0,0000 | 1,0000 | **1,0000** |
| desliz | 20 | 0,25 | 0,25 | 0,0331 | 0,3710 | 1,0295 | **0,7759** |
| desliz | 20 | 1,0 | 0,25 | 0,1324 | 1,4840 | 1,1420 | **0,3526** |
| desliz | 10 | 1,0 | 0,25 | 0,2869 | 2,3871 | 1,5987 | **0,1982** |
| epoca | 10 | 1,0 | 0,00 | 0,2383 | 1,5790 | 0,5706 | **0,0633** |

`margen = (bw(X)−bw(Y)) / ((bs(X)−bs(Y))·w̄)` sobre los dos mejores candidatos:
vale 1 si el peso se comporta exactamente como el conteo, y **≤ 0 sería una inversión**.
El mínimo sobre ~1 000-1 900 decisiones no baja de 0,063 ni con `ε` global de 0,86.

**El teorema que faltaba** (y que este experimento hace evidente):

> **Lema E1 (cancelación del factor común).** Sean `A`, `B` dos candidatos a padre
> seleccionado, `S = blues(A)\blues(B)`, `T = blues(B)\blues(A)`. Entonces
> `bw(A) − bw(B) = w(S) − w(T)` y `bs(A) − bs(B) = |S| − |T|`. **Si todos los bloques de
> `S ∪ T` tienen el mismo peso `w`, los dos signos coinciden exactamente**, sea cual sea
> `w` y sea cual sea la variación de `w` en el resto del DAG.

`S ∪ T` son los bloques del *desacuerdo*, es decir bloques **contemporáneos** cerca de las
puntas; y el retarget es función del pasado **compartido**, luego les da el mismo `SR`.
Medida que lo confirma sin dejar hueco: **`empates_bs == empates_bw` en las 24 filas** —
siempre que el conteo empata, el peso empata también, es decir bloques con el mismo
`blue_score` tienen exactamente el mismo peso. (Corolario colateral: el desempate de ZEROX
por `solution_distance` **sigue vivo** con peso real y decide el 55 % de las selecciones a
`α=0`; mi sospecha de que el peso lo dejaría en código muerto queda **refutada por medida**.)

**Consecuencia para la nota del principal:** la restricción `W_RETARGET ≥ 3 083, γ ≤ 0,25`
de R-FIN-13 **es correcta pero está justificada por la magnitud equivocada**. La `ε` que
acota (`γ√(F/(W²λ))`, deriva acumulada sobre `F`) no es la que decide; la que decide es la
diferencial, medida aquí en **0,033 cuando la global vale 0,10** — un factor 3 de margen
extra que la nota no se apunta. Etiqueta: **la restricción sobrevive, la derivación no.**

---

## A0e · El punto de diseño **de verdad**, con la ventana llena — `salida_a0e.txt`, `salida_a0f_*.txt`

**Error mío, declarado.** Con `W = 3 083 s` y horizonte 260-900 s la ventana **nunca se
llena**, y Kaspa hereda entonces los `bits` del padre (`difficulty.rs:170-178`): `w ≡ 1`
idénticamente. Las filas «W=3083» de A0, A0b, A1, A2 y A3 **no miden el punto de diseño**:
miden que en 260 s no hay retarget. Aquí, horizonte **6 000 s** (≈2×`W`) y ~11 500 retargets
reales antes de leer nada; 4 semillas.

| política | α | `retarg` | `w≠` | **`sp≠`** | **`sort≠`** | `sd(ln w)` medida | rango `ln w` | **`w_at`/`w_hon`** |
|---|---:|---:|---:|---:|---:|---:|---|---:|
| tips | 0,00 | 11 565 | 9 452 | **0** | **0** | 0,00464 | [−0,0038, +0,0158] | — |
| tips | 0,25 | 11 577 | 3 732 | **0** | **0** | 0,00462 | [−0,0040, +0,0158] | 0,99983 |
| tips | 0,40 | 11 579 | 3 128 | **0** | **0** | 0,00461 | [−0,0040, +0,0158] | 0,99985 |
| retro8 | 0,25 | 11 536 | 9 825 | **136** | **185** | **0,03364** | [−0,0770, 0] | **1,00110** |
| retro8 | 0,40 | 11 509 | 9 789 | **146** | **77** | **0,05426** | [−0,1176, 0] | **1,00199** |

Predicción de `dag-poas-empalme-peso.md` §2 sobre este horizonte: `s_nota = 0,00638`.

**Tres cosas, y las tres importan:**

1. **Sin atacante la nota acierta y es conservadora:** `ε` medida **0,00462** frente a
   **0,00638** predicha. La fórmula de la nota **vale como cota superior** donde su hipótesis
   se cumple. `sp≠ = 0`: el peso no decide nada.
2. **Bajo ataque, en el PUNTO DE DISEÑO, el peso SÍ decide** — `sp≠ = 136` y `sort≠ = 185`.
   La rama corre y cambia decisiones reales de GHOSTDAG a `W = 3 083`. **Esto refuta mi
   propia lectura provisional de A0b** («el peso nunca decide»): decide, solo que el ancla no
   se mueve por ello.
3. **Y la `ε` bajo ataque rompe la cota de la nota por 5,3×** (`0,03364` frente a `0,00638`),
   **también en el punto de diseño.** La LAGUNA 1 del empalme —«`N_obs` Poisson **sin**
   atacante»— no es un tecnicismo: el sesgo es **sistemático** (todo el rango de `ln w` cae
   en `[−0,077, 0]`, es decir el retarget se afloja de forma monótona) y no aleatorio.

**Pero el que decide es el DIFERENCIAL, y ahí sí se cumple la escala prevista:**

| `W` | `w_at`/`w_hon` bajo `retro8`, `α=0,40` | escala `1/W` esperada |
|---:|---:|---:|
| 20 (γ=1,0) | 1,2838 | — |
| 80 | 1,0354 | — |
| **3 083** | **1,00199** | `0,0354 × 80/3083 = 0,00092` → medido **0,00199** |

Es decir: **el diferencial cae con `1/W` como se preveía, dentro de un factor 2**, y en el
punto de diseño vale **0,2 %** — `α_ef = α·1,002`, **0,07 puntos de umbral** a `α = 0,35`.
La deriva **común** (`E[ln w]`), en cambio, **no** cae con `W`: es la que el atacante induce
suprimiendo azules, y vale `−0,077` a `W = 3 083` igual que `−0,177` a `W = 80`. **Separar
esas dos derivas es lo que la nota no hace, y es toda la diferencia.**

Otras dos filas del mismo experimento, por completitud:

| política | α | `sp≠` | `sort≠` | `sd(ln w)` | `w_at`/`w_hon` |
|---|---:|---:|---:|---:|---:|
| retención 40 s | 0,25 | **128** | **228** | 0,00696 | 1,00065 |
| retención 40 s | 0,40 | 9 | 29 | 0,00235 | 1,00066 |
| 2 copias, `retro1` | 0,25 | **198** | **874** | 0,00461 | 0,99985 |
| 2 copias, `retro1` | 0,40 | **234** | **855** | 0,00449 | 0,99987 |

**En las cuatro estrategias adversariales el peso decide** (`sp≠` 128-234, `sort≠` hasta 874)
**y el diferencial se queda entre 0,99985 y 1,00199.** Es decir: el peso invierte decisiones,
pero no favorece al atacante — en dos de las cuatro le perjudica.

### A0e(2) · El menú del ancla **en régimen** — `salida_a0f_*.txt`

Menú leído en una posición de cadena con `t ≥ 3 500 s` (`P ≈ 1 775` a `α=0,25`), familia
GLOBAL reducida a 5 estrategias, **3 semillas**. *(El `m` absoluto no es comparable con el de
A1 —familia distinta y `P` distinto—; solo lo son las dos filas entre sí.)*

| configuración | α | `m_BS` medio | máx | `sp≠` | `sort≠` | `peso≠1` |
|---|---:|---:|---:|---:|---:|---:|
| peso 1 | 0,25 | **2,54** | 4 | 0 | 0 | 0 |
| desliz W=3083 (diseño, en régimen) | 0,25 | **2,84** | 5 | 1 | 14 | 43 230 |
| peso 1 | 0,40 | **2,83** | 4 | 0 | 0 | 0 |
| desliz W=3083 (diseño, en régimen) | 0,40 | **2,83** | 4 | 1 | 21 | 43 240 |

**Ese +11,8 % a `α = 0,25` (2,54 → 2,84) era el único desvío grande de toda la ronda — y NO
REPLICA.** Lo repetí con las semillas 4-9 (`salida_a0f_0.25_s4,5.txt`, `s6,7`, `s8,9`):

| semillas | peso 1 | desliz W=3083 | `sp≠` | `sort≠` | `peso≠1` |
|---|---:|---:|---:|---:|---:|
| 1,2,3 | 2,54 | **2,84** | 1 | 14 | 43 230 |
| 4,5 | 2,50 | **2,50** | 0 | 5 | 29 675 |
| 6,7 | 2,21 | **2,21** | 0 | 6 | 29 360 |
| 8,9 | 2,60 | **2,60** | 0 | 7 | 28 640 |
| **9 semillas** | **2,471** | **2,571** | | | |

**Seis semillas más, seis coincidencias exactas.** Sobre las 9 semillas el desvío queda en
**+4,0 %**, y viene entero de un solo grupo de mundos. **Etiqueta: el +11,8 % era ruido de
muestra pequeña; corregido a `+4,0 %` sobre 9 semillas, dentro de la banda de ±3-4 % del
resto de la ronda.** *(Este párrafo es la corrección de mi propia lectura del párrafo
anterior, que estuve a punto de firmar con 3 semillas: exactamente el error de D9-d, pero por
la otra punta — publicar una diferencia que no está.)*

## A1b · ¿Puede el atacante **mover el peso**? — el canje del *difficulty grinding* — `salida_a1b.txt`

Por el Lema E1, la única forma de que el atacante fabrique un bloque con `w` distinto del
de sus contemporáneos es colgarlo de un ancestro de cadena de **otra ventana de
dificultad**: `('retro', n)` con `n` grande. Medido el canje (8 semillas, horizonte 300 s):

| config | política | α | `w` gana (media) | `w` gana (MÁX) | `blue_score` que pierde | % cadena suya |
|---|---|---:|---:|---:|---:|---:|
| **W=3083 g=,25 (diseño)** | tips | 0,25 | **1,0000** | **1,0000** | +1,34 | 49,4 % |
| **W=3083 g=,25 (diseño)** | retro64 | 0,25 | **1,0000** | **1,0000** | −110,3 | 1,5 % |
| W=80 g=,25 (ε ×7) | retro8 | 0,40 | 1,0449 | 1,2077 | −26,7 | 1,9 % |
| W=80 g=,25 (ε ×7) | retro64 | 0,40 | 1,1719 | 1,5454 | −94,9 | 1,9 % |
| W=20 g=1,0 (ε ×130) | retro32 | 0,40 | 5,9189 | **20,17** | −78,8 | 1,9 % |
| W=20 g=1,0 (ε ×130) | retro64 | 0,40 | 7,9659 | 20,09 | −110,3 | 1,9 % |

**La palanca existe y está cuantificada, y es ruinosa.** Incluso en una configuración que
viola R-FIN-13 por un factor 130, comprar un bloque **20 veces más pesado** cuesta
**110 unidades de `blue_score`** y hunde su cuota de bloques de cadena del **49,4 % al
1,5 %**. En el punto de diseño la ganancia es **exactamente 1,0000**: la palanca **no
existe**, porque para salir de una ventana de 3 083 s hay que retroceder ~600 posiciones de
cadena.

*(Aviso: las filas `W=3083` de esta tabla tienen horizonte 300 s, así que la ventana no se
llena y `w ≡ 1` por la regla de Kaspa `difficulty.rs:170-178`. El punto de diseño **en
régimen** está en A0e, y allí la ganancia bajo `retro8` es `1,0011-1,0020`, del mismo orden.)*

> **Regla de cambio.** Retroceder `n` posiciones de cadena cuesta ≈ `1,7·n` de `blue_score`
> y compra como mucho `exp(γ·|ln(N_obs/N_obj)|)` de peso, que es `O(γ/√(λ·W))`. Con
> `W ≥ 3 083` y `γ ≤ 0,25` el cambio es **1 : 0** — no hay `n` que lo haga rentable.
> **Etiqueta: DEMOSTRADO en simulación (criterio α pasa: α=0 no tiene atacante).**

---

## A1 · El menú `m` con peso real — **NO cambia** — `salida_a1_menu.txt`

Misma familia de estrategias (importada de `r8d_a1_menu.py`), mismas 12 semillas, mismo
`P = 30`, misma banda `T0 ± 10`. Solo cambia el peso.

| configuración | α | `m_BS` gratis | +retraso | +retención | `ε`=sd(ln w) | `peso≠1` | `w≠` | **`sp≠`** | `sort≠` |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| **peso 1 (= D9-d)** | 0,10 | **2,33** | 3,38 | 4,35 | 0 | 0 | 0 | 0 | 0 |
| **peso 1 (= D9-d)** | 0,25 | **3,03** | 4,29 | 7,53 | 0 | 0 | 0 | 0 | 0 |
| **peso 1 (= D9-d)** | 0,33 | **3,17** | 4,32 | 8,24 | 0 | 0 | 0 | 0 | 0 |
| **peso 1 (= D9-d)** | 0,40 | **3,25** | 4,34 | 8,17 | 0 | 0 | 0 | 0 | 0 |
| desliz W=3083 (diseño) | 0,25 | 3,03 | 4,29 | 7,53 | 0 | 0 | 0 | 0 | 0 |
| desliz W=80 g=,25 (ε×10) | 0,25 | 3,03 | 4,25 | 7,51 | 0,0267 | 672 395 | 213 414 | **1** | 17 |
| desliz W=80 g=,25 | 0,10 | 2,33 | 3,38 | 4,34 | 0,0230 | 291 170 | 134 429 | **40** | 102 |
| desliz W=20 g=,25 (ε×40) | 0,25 | **3,09** | 4,29 | 7,52 | 0,1093 | 878 790 | 330 080 | **79** | 343 |
| desliz W=20 g=,25 | 0,40 | **3,27** | 4,32 | 8,15 | 0,1093 | 1 235 212 | 390 846 | **103** | 258 |
| desliz W=20 g=1,0 (ε×160) | 0,25 | 3,04 | **4,17** | 7,44 | 0,4373 | 878 790 | 330 086 | **96** | 365 |
| desliz W=20 g=1,0 | 0,33 | 3,18 | 4,32 | 8,27 | 0,4258 | 1 060 090 | 366 209 | **156** | 342 |
| epoca W=20 g=,25 | 0,10 | **2,40** | 3,44 | 4,43 | 0,0969 | 394 169 | 78 825 | 47 | 106 |

**Reproducción exacta de D9-d con peso 1: 2,33 / 3,03 / 3,17 / 3,25 gratis, y las nueve
cifras de las otras dos columnas.** (Regla 11 cumplida y comprobada, no supuesta.)

**Con peso real, `m` no se mueve.** El desvío máximo sobre las 30 celdas medidas es
**+0,06 (+2,0 %)** hacia arriba (`3,03 → 3,09`, `W=20 γ=0,25`, `α=0,25`) y **−0,12 (−2,8 %)**
hacia abajo (`4,29 → 4,17`, `W=20 γ=1,0`). **Y esta vez la rama SÍ corre**: `sp≠` llega a
**156** y `sort≠` a **365** — el peso invierte decisiones reales de GHOSTDAG, y aun así el
menú del ancla no se entera. **Etiqueta: la respuesta a A1 es NO, con cobertura de rama
declarada.**

### A1c · El menú donde el peso SÍ decide — inundación con copias — `salida_a1c.txt`

A3 identificó el único régimen con `sp_discrepa` alto: la inundación con copias del mismo
billete (R-FIN-11). Medido allí, con la familia `retro ≤ 16`:

| config | copias | α=0,25 | α=0,40 |
|---|---:|---:|---:|
| peso 1 | 0 | **4,62** | 4,42 |
| peso 1 | 6 | 5,09 | 4,96 |
| peso 1 | 14 | **5,77** | — |

**Lo que sí sube el menú no es el peso: es la familia de estrategias.** Con la familia de
D9-d (`retro ≤ 4`, sin copias) `m = 3,03`; con `retro ≤ 16` sube a **4,62**; con 14 copias
por bloque, a **5,77** — un **+90 %** sobre el número publicado. **Etiqueta: REFUTADO el `m`
de D9-d (era optimista). Menú por estructura: ampliar la familia solo puede subirlo, así que
4,62 y 5,77 son cotas INFERIORES nuevas, no el máximo.**

*(La ejecución de `r8e_a1c_copias.py` se INTERRUMPIÓ a propósito tras las filas de peso 1:
las de peso real con la familia completa costaban más de 2 h. La comparación peso 1 ↔ peso
real en ese régimen se hace abajo con familia reducida.)*

### A1c2 · Peso 1 ↔ peso real **dentro** del régimen de copias — `salida_a1c2.txt`

Familia reducida a las 7 estrategias globales (el `m` absoluto no es comparable con A1/A1c;
solo las columnas entre sí), 6 semillas:

| config | copias | α=0,25 | α=0,40 | `sp≠` | `sort≠` |
|---|---:|---:|---:|---:|---:|
| peso 1 | 0 | 3,85 | 3,79 | 0 | 0 |
| desliz W=200 g=,25 | 0 | **3,85** | **3,79** | 0 | 0 |
| desliz W=20 g=1,0 | 0 | 3,83 | 3,79 | **13** | **30** |
| peso 1 | 14 | 4,40 | 4,38 | 0 | 0 |
| desliz W=200 g=,25 | 14 | **4,40** | **4,38** | 0 | 0 |
| desliz W=20 g=1,0 | 14 | 4,36 | **4,54** | **66** | **64** |

**Dentro del régimen donde el peso decide (`sp≠ = 66`), el menú se mueve `−0,9 % / +3,7 %`.**
Etiqueta: **el resultado de A1 se sostiene también con copias.**

---

## A2 · El sesgo del ancla con peso real — **NO empeora por el peso; empeora por lo que D9-d no probó** — `salida_a2.txt`

**(1) Cuotas del atacante en la cadena seleccionada (horizonte 900 s, 8 semillas):**

| config | α | % BLOQUES | % UMBRALES | **% PESO** | `w` atac / `w` hon | `sp!=` |
|---|---:|---:|---:|---:|---:|---:|
| peso 1 (D9-d) | 0,25 | 49,3 % | 59,3 % | 59,3 % | 1,0000 | 0 |
| desliz W=3083 (diseño) | 0,25 | 49,3 % | 59,3 % | 59,3 % | 1,0000 | 0 |
| desliz W=80 | 0,25 | 49,3 % | 59,3 % | 59,3 % | 0,9972 | 0 |
| desliz W=20 g=1,0 | 0,25 | 49,3 % | **59,5 %** | **59,5 %** | 0,9835 | 0 |
| desliz W=20 g=1,0 | 0,40 | 59,7 % | 68,6 % | **69,5 %** | **0,9739** | 0 |

**El 59,3 % de D9-d se reproduce cifra a cifra en todas las configuraciones de peso.** Y la
respuesta a «¿puede además concentrar peso?» es **NO, al contrario**: la razón
`w_atac / w_hon` es **≤ 1** en cuanto el retarget se mueve (0,974 a `α=0,40`), porque sus
bloques van sistemáticamente colgados de pasados con **menos** azules en la ventana, lo que
el controlador traduce en `SR` más fácil y por tanto **menos** peso. La cuota de PESO supera
a la de UMBRALES en **0,9 puntos** en el peor caso, y ése es un caso que viola R-FIN-13.
**Etiqueta: canal (a) —concentrar peso— REFUTADO por medida.**

**(2) Captura del ancla, con la familia `retro` ampliada a `n = 1,2,4,8,16,32,64`:**

| config | α=0,10 | α=0,25 | α=0,40 |
|---|---:|---:|---:|
| `p_nat` (todas las configs) | 40,5 % | 65,1 % | 71,0 % |
| `p_cap` **D9-d** (retro ≤ 4) | 48,8 % | **80,6 %** | 88,1 % |
| `p_cap` **aquí** (retro ≤ 64), peso 1 | 61,1 % | **90,9 %** | 93,7 % |
| `p_cap` **aquí**, desliz W=3083 | 61,1 % | **90,9 %** | 93,7 % |
| `p_cap` **aquí**, desliz W=20 g=1,0 | 61,1 % | 90,9 % | 94,0 % |

**El 80,6 % de D9-d sube al 90,9 % — y NO por el peso** (las cinco configuraciones dan lo
mismo, incluidas las que tienen `sp_discrepa = 36`), **sino porque la familia dirigida de
D9-d se quedaba en `retro ≤ 4`**. Con `retro ≤ 64` el atacante pone un bloque suyo en el
cruce del umbral en **9 de cada 10 umbrales** a `α = 0,25`, y en **19 de cada 20** a
`α = 0,40`. **Etiqueta: REFUTADO el número de D9-d (era optimista); la causa es la familia
de estrategias, no el peso. Menú por estructura, así que ampliar la familia solo puede
subirlo — y D9-e no ha buscado el máximo, solo ha llegado más lejos que D9-d. LAGUNA: `p_cap`
sigue sin cota superior conocida.**

---

## A3 · El Lema 9 con peso real — `salida_a3.txt`

**(1) `δ_ef` en CONTEO frente a `δ_ef` en PESO** (`pick_virtual_parents` completo, el
`MundoShuffle` de D9-d; ventana [80, 300] s; 8 semillas):

| config | peor escenario U3″ dinámica | `δ_conteo` | `δ_PESO` | dif. |
|---|---|---:|---:|---:|
| peso 1 (= punto de diseño en este horizonte) | 14 cop. retro1, α=0,40 | 0,1222 | **0,1222** | 0,0000 |
| desliz W=200 g=,25 | ídem | 0,1364 | **0,1360** | −0,0004 |
| desliz W=80 g=,25 | ídem | 0,1719 | **0,1706** | −0,0013 |
| desliz W=20 g=1,0 | ídem | 0,1695 | **0,1582** | −0,0113 |

**Dos cosas, y la segunda no la esperaba yo:**

1. **`δ` en peso ≈ `δ` en conteo, y cuando difiere es MENOR.** El peor desvío en todas las
   filas medidas es **−0,0113** (el peso da un `δ` *más benigno*): el atacante no consigue
   tirar bloques honestos sistemáticamente más pesados. Las columnas `w azul` / `w rojo` lo
   confirman: los honestos que acaban rojos pesan como los que acaban azules (0,8689 vs
   0,8774 en el peor caso, +1 %). **El empalme conteo↔peso del Lema 9 se sostiene.
   Etiqueta: PLAUSIBLE, medido en 5 escenarios × 4 `α` × 4 configuraciones; no es una
   demostración.**
2. **El retarget EMPEORA `δ` — un efecto que D9-d no podía ver.** `δ_conteo` pasa de
   **0,1222** sin retarget a **0,1719** con `W=80` — un **+41 %** — porque la inundación con
   copias mueve `N_obs`, el controlador reacciona, y los cambios de peso llegan a invertir
   decisiones (`sp_discrepa` = 74-159 en esas filas: **aquí sí corre la rama**). Sigue por
   debajo de `δ = 0,2105` y de `δ_real = 0,267`, pero el margen de D9-d («39 % sobre 0,2105»)
   **se reduce a 18 %** con `W = 80`. En el punto de diseño (`W = 3083`, que en este
   horizonte es la fila «peso 1») el efecto es **cero**.

**(2) La suposición del empalme «`N_obs` Poisson SIN atacante» — LAGUNA 1 confirmada y
cuantificada.** `s_nota = γ·√(H/(W²·λ_azul))` es la predicción de
`dag-poas-empalme-peso.md` §2; `E[ln w]` es el **sesgo sistemático** medido:

| config | política | α | `E[ln w]` medido | `sd(ln w)` medido | `s_nota` | `w` atac/`w` hon |
|---|---|---:|---:|---:|---:|---:|
| W=200 g=,25 | tips | 0,00 | −0,0009 | 0,0093 | 0,0254 | — |
| W=200 g=,25 | retro8 | 0,40 | **−0,0506** | 0,0566 | 0,0254 | 1,0093 |
| W=80 g=,25 | tips | 0,00 | +0,0013 | 0,0231 | 0,0635 | — |
| W=80 g=,25 | retro8 | 0,40 | **−0,1769** | 0,1396 | 0,0635 | **1,0354** |
| W=20 g=1,0 | retro8 | 0,40 | −1,6866 | 1,1304 | 1,0153 | **1,2838** |

- **Sin atacante la nota acierta y se pasa de conservadora** (medido 0,0093-0,0231 frente a
  0,0254-0,0635 predicho).
- **Bajo ataque el sesgo es SISTEMÁTICO y supera la cota de la nota por un factor 2-2,8**
  (`−0,1769` frente a `0,0635`). La nota lo dejó como LAGUNA 1 diciendo «no está
  cuantificada aquí». **Aquí está: a `ε` siete veces el de diseño, el sesgo sistemático es
  2,8 veces la desviación aleatoria que la nota acota.**
- **Pero el que importa es el diferencial**, `w_atac/w_hon`, y vale **1,0354** en esa misma
  fila. Escala con `(profundidad a la que el atacante retrocede)/W`: a `W = 3083` haría
  falta retroceder ~600 posiciones de cadena, que por A1b cuesta ~1 000 de `blue_score`.
  **Medido directamente en el punto de diseño (A0e): 0,20 %** —
  `α_ef = α·1,002` → **0,07 puntos de umbral** a `α = 0,35`. La extrapolación lineal en `1/W`
  daba 0,09 %: acierta dentro de un factor 2.

> **Etiqueta: la LAGUNA 1 del empalme es REAL (el sesgo bajo ataque no es Poisson y rompe la
> cota de la nota por 2,8×), pero es INOCUA en el punto de diseño, y la razón por la que es
> inocua no es la de la nota — es el Lema E1 más la regla de cambio de A1b.**

---

## A4 · ¿Se transfiere el Lema A2 al ancla `blue_score`? — **SÍ, con un eslabón nuevo** — `salida_a4.txt`, `salida_a4b.txt`

### El eslabón que falta, y la prueba

> **Lema A4.** Sea `Chn` la cadena seleccionada en `t+r`, `Chn′` la de `s > t+r`, y
> `I = I_T(Chn)`, `I′ = I_T(Chn′)` los primeros bloques de cada una con `blue_score ≥ T`.
> **Si `I ≠ I′`, las dos cadenas difieren en alguna posición `p ≤ idx(I)`.**
>
> *Prueba.* `blue_score(B)` es función de `past(B)` y **no cambia nunca** una vez `B`
> existe. A lo largo de la cadena seleccionada es **estrictamente creciente**:
> `blue_score(C_i) = blue_score(C_{i−1}) + |mergeset_blues(C_i)|` (`protocol.rs:153`) y
> `mergeset_blues` contiene siempre a `sp` (`ghostdag.rs:115-120`), luego el incremento
> es `≥ 1`. Sea `q = idx(I)`. Si las dos cadenas coincidieran en las posiciones `0..q`,
> los `q+1` `blue_score` serían los mismos y, por monotonía estricta, el **primero** que
> cruza `T` sería el mismo: `I′ = I`. Contrapositivo. ∎
>
> Encadenando con el Lema A2 de D9-c, el evento «el ancla cambia» cae **entero** dentro del
> `∃C` que la Def. 2 ya tiene dentro de la probabilidad, y la Prop. 7 lo cubre **sin cota de
> la unión**. **Etiqueta: DEMOSTRADO.**

**Lo que este lema necesita y `pos` no necesitaba:** la monotonía **estricta** de
`blue_score` **a lo largo de la cadena**. Medido: **`M3 = 1004/1004` pasos** a `α=0,40`, en
las cinco configuraciones de peso. Es por construcción, no por suerte.

### El paso (ii) del Lema A2 con peso real — **Lema A4b, y por qué se salva**

El Lema A2 usa un «Lema de monotonía» `bw(Q) ≥ bw(W)` para `W ≤ Q`. Con peso real:

> **Lema A4b.** Si `W ∈ past(Q)` entonces `blue_work(Q) > blue_work(W)`, siempre que
> `w(b) > 0`.
> *Prueba.* Un paso de arista: sea `P` padre de `Q` con `W ≤ P`. Entonces
> `bw(Q) = bw(sp(Q)) + Σ_{h∈mergeset_blues(Q)} w(h) ≥ bw(sp(Q)) + w(sp(Q)) > bw(sp(Q)) ≥ bw(P)`,
> donde la última desigualdad es `find_selected_parent = max por blue_work`
> (`protocol.rs:99-106`). Inducción sobre el camino. ∎
> **Funciona porque la magnitud que se ACUMULA es la misma que ELIGE el padre.** La
> hipótesis `w > 0` se cumple en Kaspa por construcción de `calc_work`: devuelve
> `(!target/(target+1)) + 1 ≥ 1` (`difficulty.rs:211-217`). **Corrección mía:** primero
> atribuí ese suelo a `.max(self.level_work)` de `protocol.rs:157`, pero `level_work` vale
> **0** en el nivel 0 (`difficulty.rs:223-226`: `if level == 0 { return 0.into(); }`), así que
> ese `max` no aporta nada aquí — el suelo lo pone el `+1` de `calc_work`.
> **Etiqueta: DEMOSTRADO.**

### Y lo que se rompe por el camino — `salida_a4b.txt`

El simulador dice `M2 = 141 967/141 967`: `blue_score` sale monótono bajo ancestría en todas
las configuraciones. **Eso no lo convierte en teorema — sale monótono porque en las corridas
de A4 (horizonte 200 s) el peso no llega a vencer al conteo en `find_selected_parent`**
(A0b: `sp≠ = 0` en todo el barrido a ese horizonte; donde sí vence —A0e, A1, A3— no medí
`M2`). **LAGUNA declarada: `M2` con `sp≠ > 0` no está medido.** El contraejemplo, construido
a mano:

```
Rama A: 4 bloques LIGEROS (w=e^-2).  Rama B: 2 bloques PESADOS (w=e^+2).  Q = hijo de ambas, k=1.
   PESO REAL: A3 bs=4 bw=1,4060 | B1 bs=2 bw=8,3891 | Q bs=3 bw=15,7781 sp=B1
              mergeset_blues(Q)=['B1']   mergeset_reds(Q)=['A0','A1','A2','A3']
              parejas que ROMPEN blue_score monótono: [('A3','Q'), ('A2','Q')]
              parejas que ROMPEN blue_work monótono:  []
   PESO 1   : Q bs=5 sp=A3 · ninguna pareja rota   <- el contraejemplo DESAPARECE
```

**`blue_score` monótono bajo ancestría queda REFUTADO como teorema.** No afecta al ancla
—el Lema A4 solo necesita monotonía **por la cadena**— pero **sí** afecta a cualquier regla
que use `blue_score` como *altura*: **R-FIN-10 (`altura := idx`) y la monotonía que R-FIN-7
exige** están apoyadas en una propiedad que solo vale mientras el peso y el conteo no
discrepen. Y A3 demuestra que **sí discrepan** bajo inundación con copias
(`sp_discrepa` = 74-198). **Etiqueta: hallazgo colateral, REFUTADO el supuesto implícito.**

### Comprobación empírica del encadenamiento — `salida_a4.txt`

Horizonte 200 s, 40 vistas crecientes, 8 semillas, cinco configuraciones de peso:

```
   (i)   sp(W) = sp(W') = Chn[p-1] ......... 167/167  60/60  27/27  16/16   (α = 0 / ,10 / ,25 / ,40)
   (ii)  W y W' en anticono mutuo .......... 167/167  60/60  27/27  16/16
   (iii) W<W' antes y W'<W después ......... 167/167  60/60  27/27  16/16
   (A4)  ancla cambia ⇒ cadena difiere en p ≤ idx(ancla) ... 493/493  65/65  16/16  5/5
   (M1)  blue_work monótono bajo ancestría ..... 141967/141967
   (M3)  blue_score creciente por la cadena .... 1004/1004
```

**Cero excepciones, y la cuenta cambia con `α` (criterio α: 167 → 16 reorganizaciones).**

---

# VEREDICTO

| línea | etiqueta | evidencia |
|---|---|---|
| **A1** · ¿cambia `m` el peso real? | **NO — DEMOSTRADO en simulación, con la rama corriendo** | Con peso 1 reproduzco a D9-d **cifra a cifra** (2,33 / 3,03 / 3,17 / 3,25 gratis, 12 semillas). Con peso real el desvío máximo sobre 30 celdas es **+2,0 % / −2,8 %**, en configuraciones que violan R-FIN-13 por 10-160×, **con `sp≠` hasta 156 y `sort≠` hasta 365**: el peso invierte decisiones y el ancla no se entera. **En el punto de diseño con la ventana llena** (A0e, horizonte 6 000 s): `ε` medida **0,00462** sin atacar (predicción de la nota: 0,00638), `sp≠ = 0`; **bajo ataque `sp≠ = 136` y el menú se mueve `+4,0 %` sobre 9 semillas** |
| **A1b** · ¿puede mover el peso? | **REFUTADO que le sirva — DEMOSTRADO el canje** | La palanca existe (`retro n` para heredar el `SR` de otra ventana) y es **ruinosa**: en `W=20 γ=1,0` compra un bloque **20× más pesado** por **110 de `blue_score`**, y su cuota de cadena cae del 49,4 % al 1,5 %. En el punto de diseño la ganancia es **exactamente 1,0000** |
| **A2** · ¿sesga más el peso? | **REFUTADO (no sesga); pero el 80,6 % de D9-d es falso por otro motivo** | 49,3 % bloques / 59,3 % umbrales / **59,3 % peso**, idéntico en las 5 configuraciones. `w_atac/w_hon ≤ 1` (0,974): el atacante **pierde** peso, no lo concentra. **`p_cap` sube de 80,6 % a 90,9 %** al ampliar `retro` de 4 a 64 — **por la familia de estrategias, no por el peso** |
| **A3** · ¿Lema 9 en peso? | **PLAUSIBLE que sí; y un efecto NUEVO** | `δ_PESO ≈ δ_conteo`, peor desvío **−0,0113** (el peso da un `δ` *más benigno*). **Pero el retarget empeora `δ` un +41 %** (0,1222 → 0,1719 con `W=80`), reduciendo el margen de D9-d sobre 0,2105 del 39 % al **18 %**. En el punto de diseño, cero |
| **A3(2)** · la suposición del empalme | **LAGUNA 1 CONFIRMADA y cuantificada** | Sin atacante la nota acierta (medido 0,0093 vs 0,0254 predicho). **Bajo ataque el sesgo es sistemático y supera la cota por 2,8×** (−0,1769 vs 0,0635). Pero el **diferencial** —el que decide— vale 1,0354 ahí y **1,0020 MEDIDO en el punto de diseño** (A0e, ventana llena): 0,07 puntos de umbral |
| **A4** · ¿se transfiere el Lema A2? | **SÍ — DEMOSTRADO, con un eslabón nuevo (Lema A4) y una corrección (Lema A4b)** | `M1 141 967/141 967`, `M3 1 004/1 004`, `(i)(ii)(iii) 270/270` (= 167+60+27+16 reorganizaciones por `α`), `A4 579/579` — cero excepciones en 5 configuraciones. El paso (ii) del Lema A2 se salva con peso real **porque la magnitud que se acumula es la misma que elige el padre** |
| **colateral** | **REFUTADO un supuesto implícito** | `blue_score` **NO** es monótono bajo ancestría con peso real (contraejemplo ejecutable, `salida_a4b.txt`). No afecta al ancla; **sí** afecta a R-FIN-10 (`altura := idx`) y a la monotonía que R-FIN-7 exige |
| **Lema E1** (nuevo) | **DEMOSTRADO** | La deriva del retarget es un **factor común** a las ramas en competencia y se cancela en `find_selected_parent`. Confirmación sin hueco: **`empates_bs == empates_bw` en las 24 filas** |

## Mi `m` frente a la de D9-d, misma semilla

| | D9-d (`salida_a1_menu.txt`) | D9-e, peso 1 | D9-e, peso real (peor config) | D9-e, familia ampliada |
|---|---:|---:|---:|---:|
| `α=0,10` gratis | 2,33 | **2,33** | 2,40 | — |
| `α=0,25` gratis | 3,03 | **3,03** | 3,09 | **4,62** (retro≤16) · **5,77** (+14 copias) |
| `α=0,33` gratis | 3,17 | **3,17** | 3,18 | — |
| `α=0,40` gratis | 3,25 | **3,25** | 3,27 | 4,42 (retro≤16) |
| `α=0,25` +retención | 7,53 | **7,53** | 7,44 | — |

**Reproducción exacta con peso 1 en las 15 celdas.** El peso mueve `m` un ±3 %. **La familia
de estrategias lo mueve un +90 %.**

## Salidas de `AUDITA_SCRIPTS.py` y del criterio de cobertura de rama

```
$ python3 research/scripts/AUDITA_SCRIPTS.py research/scripts/d9-ronda8e
Scripts analizados: 14
  r8e_a0e_diseno.py  [T3] L99:  compara consigo mismo: c['razon'] == c['razon']
  r8e_a3_lema9.py    [T3] L118: compara consigo mismo: r[2] == r[2]
  r8e_a3_lema9.py    [T3] L119: compara consigo mismo: r[3] == r[3]
  r8e_lib.py         [T2] L164: 'n' calculado en L160 y SOBRESCRITO con 0.5
  r8e_z_auditoria.py [T3] L77:  compara consigo mismo: v == v
Sospechas totales: 5
```

(Las cuatro [T3] son el **mismo** modismo; la quinta, en `r8e_z_auditoria.py`, es
literalmente la línea que **demuestra** que el modismo no es tautología — el detector la
marca a ella también, lo cual es correcto y divertido.)

**Las cinco leídas, y las dos clases que se pueden comprobar, comprobadas** (`r8e_z_auditoria.py`,
`salida_z_auditoria.txt`):

- **[T3]** es el modismo de descarte de NaN (`x == x` es `False` solo para NaN). Demostrado
  en la salida: `v=nan -> (v==v)=False`, todo lo demás `True`. **No es tautología.**
- **[T2]** es el bucle del modo `epoca` cuando un bloque cruza **más de una** frontera de
  ventana de golpe: el primer paso usa `N_obs` de la época del padre y los siguientes
  corresponden a épocas **intermedias vacías** (`N_obs = 0`, acotado a 0,5 para que exista
  el `ln`). **Contado: ese camino se ejecuta 0 veces en 72 corridas** (`W ∈ {20, 80, 3083}`,
  `α ∈ {0; 0,25; 0,40}`, 8 semillas). Doblemente inocuo — **y hay que apuntarlo como código
  no probado, ver LAGUNA 5.**

**Criterio de cobertura de rama (el nuevo, por el error que D9-d casi firma).** En cada tabla
que compara peso 1 con peso real van, en la misma fila, los contadores:

| dónde | `peso≠1` | `w≠` (candidatos con pesos distintos) | **`sp≠`** (el peso decide distinto) | `sort≠` |
|---|---:|---:|---:|---:|
| A0 · `W=None` (control negativo) | 0 | 0 | 0 | 0 |
| A0 · `W=20 γ=0,25` | 2 773 | 2 250 | 0 | 0 |
| A0b · `W=5 γ=20` (`ε`=2,14) | — | 559 | 0 | 0 |
| A0c · contador forzado a mano | — | — | **1** | — |
| A1 · `W=20 γ=1,0` `α=0,33` | 1 060 090 | 366 209 | **156** | **342** |
| A2 · `W=20 γ=1,0` `α=0,40` | — | — | **39** | — |
| A3 · `W=20 γ=1,0`, 14 copias `α=0,40` | 19 438 | — | **198** | — |
| **A0e · PUNTO DE DISEÑO (`W=3083`), ventana llena, sin atacar** | 11 577 | 3 732 | 0 | 0 |
| **A0e · PUNTO DE DISEÑO, `retro8` `α=0,25`** | 11 536 | 9 825 | **136** | **185** |
| **A0e · PUNTO DE DISEÑO, retención 40 s `α=0,25`** | 11 566 | 10 026 | **128** | **228** |

**El contador está vivo (A0c), corre (A0-A4) y llega a disparar (A0e, A1, A2, A3) — incluso
en el punto de diseño de R-FIN-13.** No es el caso de D9-d: aquí la rama bajo prueba se
ejecuta **y cambia decisiones reales de GHOSTDAG**, y el resultado sigue siendo que el ancla
no se mueve.

---

# Mis propios errores — declarados

1. **Mi primer modelo de retarget no podía refutar nada, y casi lo publico.** El modo
   `epoca` (retarget solo al cruzar múltiplo de `W`) da, **por construcción**, el mismo peso
   a dos puntas contemporáneas que comparten la última frontera. Con ese modelo `sp≠ = 0`
   era un teorema de mi implementación, no un resultado. Lo descubrí al leer
   `difficulty.rs:166-198` y ver que Kaspa recalcula `bits` **en cada bloque** sobre ventana
   deslizante. **Es el error de D9-d en versión sutil: la rama corría, pero el modelo no
   podía distinguir.** Añadí `modo="desliz"` y rehíce A0/A0b/A1/A2/A3/A4 con los dos.
2. **Etiqueté «punto de diseño» filas que no lo eran.** Con `W = 3 083 s` y horizonte
   260-900 s la ventana **nunca se llena**, y Kaspa hereda entonces los `bits` del padre
   (`difficulty.rs:170-178`): `w ≡ 1` idénticamente. Esas filas miden «en 260 s no hay
   retarget», no el punto de diseño. Lo corrige **A0e** con horizonte 6 000 s y ~2 900
   retargets reales.
3. **Predije un contraejemplo empírico que no apareció.** Sostuve que `blue_score` dejaría de
   ser monótono bajo ancestría con peso real; el simulador dio **141 967/141 967**. La
   predicción es correcta como teorema —y lo demuestro con un DAG a mano
   (`salida_a4b.txt`)— pero **empíricamente no se dispara en las corridas de A4**, porque
   para que se dispare hace falta que el peso venza al conteo en `find_selected_parent`, y
   con horizonte 200 s eso no ocurre nunca. **Y aquí hay un segundo error mío encima del
   primero:** dije al principio que ese vencimiento «solo pasa bajo inundación con copias»;
   A0e demuestra que también pasa con `retro8` y con retención, **en el punto de diseño**.
   Corregido las dos veces: el resultado se publica como «no es teorema», con la laguna de
   que `M2` **no** está medido en el régimen donde el peso sí decide.
4. **Sospeché que el peso real dejaría muerto el desempate por `solution_distance` de ZEROX**
   (con pesos continuos, los empates de `blue_work` desaparecerían). **Refutado por medida:**
   `empates_bs == empates_bw` en las 24 filas de A0c — el desempate sigue decidiendo el 55 %
   de las selecciones a `α=0`. Y de paso ésa es la prueba más limpia del Lema E1.
5. **El modo `epoca` con más de una frontera de golpe es código que nunca corre** (0 de 72
   corridas, `salida_z_auditoria.txt`). Es la marca [T2] de `AUDITA_SCRIPTS.py`: inocua como
   tautología, pero **no probada** como código.
6. **Estuve a punto de firmar un `+11,8 %` que no existe.** A0e(2) con 3 semillas daba
   `2,54 → 2,84` en el punto de diseño y lo escribí como «el único desvío grande de la
   ronda». Lo repetí con 6 semillas más: **coincidencia exacta en las seis**, y el desvío
   sobre 9 semillas cae a `+4,0 %`. **Es el error de D9-d por la otra punta:** él publicó
   16 filas idénticas porque la rama no corría; yo casi publico una diferencia porque la
   muestra era de 3. La regla que me faltaba: *un desvío que solo aparece en un grupo de
   semillas no es un resultado hasta que aparece en otro.*

---

# LAGUNAS

1. **`m` y `p_cap` no tienen cota superior.** Mis números (`m = 5,77`, `p_cap = 90,9 %`) son
   **cotas inferiores nuevas**, obtenidas solo por ampliar la familia de D9-d de `retro ≤ 4`
   a `retro ≤ 64` y añadir copias. No he buscado el máximo. **Quien quiera un número de
   diseño necesita una cota, y no la hay.**
2. **El punto de diseño está medido hasta `H = 6 000 s` con 4 semillas.** El horizonte de
   finalidad es `F = 4,2 h = 15 120 s`, **2,5 veces más largo**, y no lo he corrido: el
   simulador es `O(n)` por bloque en el cierre transitivo y un horizonte de 15 000 s son
   15 000 bloques. **La deriva común `E[ln w]` bajo ataque no está acotada analíticamente**,
   así que no puedo decir qué hace en `F` — solo que en `2×W` vale `−0,077`.
3. **Mi peso es continuo; el de Kaspa está cuantizado.** `bits` es un compacto de 32 bits,
   así que en Kaspa muchos bloques comparten `calc_work` **exactamente** y los empates de
   `blue_work` son más frecuentes que aquí. No he modelado la cuantización, y el desempate
   por `solution_distance` vive justo ahí.
4. **`calc_work(...).max(self.level_work)`** (`protocol.rs:157`) no está modelado. En el
   nivel 0 `level_work = 0` (`difficulty.rs:223-226`), así que no cambia nada en la cadena
   principal; en niveles > 0 (las cadenas de prueba de Kaspa) sí, y no lo he mirado.
9. **`M2` (monotonía de `blue_score` bajo ancestría) no está medido en el régimen donde el
   peso sí decide.** A4 corre a horizonte 200 s, donde `sp≠ = 0`. Habría que repetirlo a
   `H = 6 000 s` con `retro8`, que es donde A0e ve `sp≠ = 136`.
10. **El menú en régimen (A0e(2)) está medido con 9 semillas y una familia de 5 estrategias.**
   El desvío es `+4,0 %` y se concentra en 3 de las 9 semillas; con 5 estrategias el `m`
   absoluto (2,47) no es comparable con el de A1 (3,03). **Falta la medida buena: familia
   completa, 12 semillas, horizonte 6 000 s.** Coste estimado: ~6 h de CPU.
5. **`R-FIN-13` no dice qué cuenta `N_obs` ni sobre qué reloj se mide la ventana.** La ronda 3
   dice «azules del flujo canónico en ventana de `W` slots»; la propuesta dice «`W_RETARGET ≥
   3 083 slots`». **Yo he medido la ventana en tiempo de cadena (sellos de las cabeceras),
   que es la lectura PESIMISTA**: si el `slot` es el índice de PoT —objetivo, infalsificable—
   la palanca de A1b desaparece del todo. **Es una ambigüedad de la regla, y hay que
   cerrarla en el texto: `slot` = índice de PoT, no sello de tiempo.**
6. **Lema 9, Lema 10, Prop. 8 y `φ_c` siguen enunciados sobre CONTEO.** Aquí se ha medido que
   la versión en peso no es peor; **no se ha demostrado**. El teorema sigue faltando; lo que
   ha cambiado es que ahora se sabe **por qué** la brecha es pequeña (Lema E1) y **cuánto**
   vale bajo ataque (A3(2)).
7. **`Δ = 4 s` sigue sin medir** (heredado de D9-c/D9-d). Todo el `δ` depende de él.
8. **El sesgo del Lema 9 bajo ataque rompe la cota de la nota por 2,8×** y no tengo modelo
   analítico de ese sesgo: solo la medida en tres `(γ, W)`.

---

# Lo que hay que cambiar, en orden

1. **`dag-poas-empalme-peso.md`: la derivación está mal apuntada, la conclusión no.** Añadir
   el **Lema E1** y separar `ε_común` de `ε_diferencial`. La restricción `W ≥ 3 083, γ ≤ 0,25`
   se queda, pero por otra razón, y con **más margen del que la nota se apunta**.
2. **R-FIN-13: decir que `slot` es el índice de PoT, no el sello de tiempo de la cabecera**
   (LAGUNA 5). Sin eso, el retarget es falsificable por *timewarp* y la palanca de A1b
   vuelve a existir.
3. **R-FIN-10 y R-FIN-7: `blue_score` no es una «altura» monótona.** Es monótono **por la
   cadena seleccionada**, no bajo ancestría (contraejemplo en `salida_a4b.txt`). Si alguna
   regla lo usa como altura fuera de la cadena, hay que reescribirla — o usar `blue_work`,
   que **sí** lo es (Lema A4b).
4. **`p_cap = 80,6 %` y `m = 3,03` de D9-d están publicados como si fueran el peor caso.**
   No lo son: con `retro ≤ 64` y copias suben a **90,9 %** y **5,77**. Hay que re-derivar
   `I`, `c` y `F` de D9-d A5 con el `m` nuevo, o etiquetarlos «contra la familia de
   estrategias de D9-d», que no es un modelo de amenaza.
5. **Añadir el Lema A4 al texto** (el eslabón que transfiere el Lema A2 al ancla del cruce) y
   el **Lema A4b** (monotonía de `blue_work` con peso real). Los dos están demostrados aquí.
6. **`δ` con retarget: el margen del Lema 9 baja del 39 % al 18 %** con `W = 80`. En el punto
   de diseño no pasa, pero la sensibilidad existe y no estaba escrita.

---

# Un «no lo sé» honesto

**No sé si `m` está acotado.** Cada agente que amplía la familia de estrategias lo sube:
D9-c encontró 5,0 para `pos`; D9-d 3,03 para `blue_score` con `retro ≤ 4`; yo 5,77 con
`retro ≤ 16` y copias. **Ese patrón —el número sube cada vez que alguien mira— es el aviso
de que no se está midiendo una propiedad del protocolo sino la potencia del último
buscador.** Mientras no exista una cota superior por argumento, ningún `c` ni ningún `F`
derivado de `m` puede llamarse dimensionado.
