# Ronda 10b (D9) — El suelo de `F`: `F_carrera` y sus cinco palancas

**Encargo:** `research/scripts/d9-ronda10b/ENCARGO.md` · **Método:** `research/scripts/METODO-AGENTES.md`
· **Fecha:** 2026-09-08 · **Directorio:** `research/scripts/d9-ronda10b/` (no se toca nada fuera).

**Qué es `F_carrera`.** La `F` mínima tal que la probabilidad de que la carrera de bloques del Lema 10
(ventaja inicial `3k`, crecimiento honesto `(1−α)(1−δ)λ`, atacante `αλ`) revierta la cadena más allá de
`F` **en alguna** de las `365·86400/I · 10` épocas de diez años sea `< 10⁻¹⁰`. Es el suelo de `F`:
`F = max(F_carrera, I/(W/κ − 1))` (`auditoria-8c.md` §3), y con la revelación retardada el segundo
término desaparece, así que el suelo es enteramente éste.

**Instrumento.** `research/scripts/d9-ronda10b/r10b_lib.py` es una capa fina que **no reimplementa
nada**: importa `r9a_a3_frontera` (9a) y usa su `prev()` — que es literalmente
`d8-ronda8/d8_a1c_riesgo.py:29-40` = `research/scripts/verif_constantes.py:44-50` — y su `union10()`,
`delta_interp()` y el patrón «rejilla 0,005 + `brentq`» de `research/scripts/verif_frontera_vs_F.py`.
Dos globales del módulo de 9a se manipulan y hay que decirlo claro:

- `A.F_SEG`, `A.I_EP`/`A.EP_ANO`: `F` y las épocas por año (`EP_ANO = 365·86400/I`).
- **`A.K` aparece en `union10()` solo como `3*A.K`**, es decir, es la *ventaja inicial* de la carrera.
  Para B.1 se fija `A.K = ventaja/3`; eso **no** cambia el `k` físico del protocolo (que no entra en
  `prev()`), solo el desplazamiento de la carrera. B.2, donde sí cambia el `k` físico, mueve además
  `δ` y `λ` según el modelo que corresponda.
- `union_lam(a, hf, lam)` es `A.union10` con `λ` explícito (misma fórmula, mismo `prev`), necesario
  porque `A.union10` cablea `λ = 1` y el modelo `δ_real(k)` de `dag-poas-delta-real.md` §1 infla la
  tasa a `λ_real = k/(k−2Δ)`.

**Nada estocástico en esta ronda.** Todo es evaluación numérica determinista de una fórmula cerrada
(Skellam + ruina del jugador). La regla de las ≥ 12 semillas no aplica y `AUDITA_SCRIPTS.py` marcará
`T4` por ello; se declara aquí y se lee al final. El criterio `α` sí aplica y está en cada tabla.

---

## A · Control positivo — **VERIFICADO**

**Script:** `r10b_a_control.py` → `salida_a.txt` (49 s).

| Magnitud publicada | Fuente | Reproducido |
|---|---|---|
| frontera `δ=0`, `F=19 080 s`, `I=4 200 s` = **46,8784 %** | `d9-ronda9a/informe.md` §L5.1 | **46,8784 %** ✔ |
| frontera `δ` D8, ídem = **36,5431 %** | ídem | **36,5432 %** ✔ (5.ª cifra: rejilla 0,005 + `xtol=1e-5`, la misma diferencia que ya tiene `verif_frontera_vs_F.salida.txt` L1) |
| fila `F = 2 h`, `I = 851 s`: **44,57 % / 35,08 %** | bitácora `dag-poas-bitacora-2026-09-08.md` §11.4 | **44,57 % / 35,08 %** ✔ |
| unión 10 a a 33 % (`δ=0`) **1,4e-169**; a 35 % **5,6e-129**; a 33 % (`δ` D8) **3,1e-32** | ídem | **1,44e-169 / 5,62e-129 / 3,05e-32** ✔ |
| `F_carrera(33 %)` = **1 019 s = 0,28 h** (`δ=0`) y **3 547 s = 0,99 h** (`δ` D8) | ídem | **idénticos al segundo** ✔ |
| `F_carrera(35 %)` = **1 249 s = 0,35 h** / **6 900 s = 1,92 h** | ídem | **idénticos** ✔ |

El punto 3 se recalcula por un camino **distinto** al del principal (`brentq` directo sobre `F` dentro
de `r10b_lib.f_carrera`, con `xtol = 0,5 s`, frente a su `brentq(g, 60, 60000, xtol=1)`): coinciden al
segundo. `prev()` **decrece** monótonamente con `F` (el déficit del atacante crece con el tiempo), así
que aquí `brentq` directo es legítimo — a diferencia del barrido en `α`, donde la función **no** es
monótona (error propio ya declarado por 9a en `r9a_a3_frontera.py:70-76`).

**Criterio `α`** (`salida_a.txt` §4, `δ=0`, `I = 851 s`): `F_carrera` = 0 s (α=0) · 267 s (0,10) ·
551 s (0,25) · **1 019 s (0,33)** · 1 249 s (0,35) · 2 462 s (0,40) · 8 352 s (0,45). Se mueve con `α`
y explota al acercarse a `r = 1`.

---

## B.1 · Palanca «ventaja inicial `3k`» — **VERIFICADO** (la palanca existe y es **débil**)

**Scripts:** `r10b_b1_ventaja.py` → `salida_b1.txt` (69 s); `r10b_b1_extremos.py` → `salida_b1_extremos.txt`.

### La fuente exacta del «máximo real 0,56·3k»

| Dónde | Qué dice |
|---|---|
| `research/scripts/d8-ronda8/salida_a6b.txt` **L14-18** (bloque `alpha = 0.33`) | fila `J = 64`: `ventaja MAX = 50`, `/k = 1.67`, **`/3k = 0.56`**, `n_medidas = 7144` |
| ídem **L2** (cabecera) | **condiciones**: `k=30, 3k=90, mp=15, lambda=1, Delta=4.0, horizonte 1800 s, 12 semillas, maniobra parasita` |
| `research/scripts/d8-ronda8/d8_a6b_lineas.py:73-80` | definición: `ventaja(t) = blue_work(punta privada) − blue_work(sp honesto)`, máximo sobre la corrida |
| `research/scripts/d8-ronda8/informe.md:427-430` | transcripción: «Máximo absoluto 50 = 1,67 `k` = 0,56 · `3k`» |
| `research/dag-poas-ancla-de-orden-auditoria-7.md:183` | «ventaja máxima real **50 = 0,56·3k**, incluso con la parásita» |
| `research/scripts/d9-ronda9a/informe.md` §L6 fila 9 | segunda medida, otra maniobra: `adv_max ≤ 43,4 < 3k = 90` (`salida_a4.txt`, 1 152 corridas) |

`1,68k = 0,56·3k = 50,4`; la medida entera es 50.

### `F_carrera` con cada ventaja (`k` físico = 30 en todas las filas, `I = 851 s`)

| Ventaja | valor | 33 %, `δ=0` | 35 %, `δ=0` | 33 %, `δ` D8 | 35 %, `δ` D8 |
|---|---:|---:|---:|---:|---:|
| **`3k`** (cota del paper) | 90 | **1 019 s = 0,28 h** | 0,35 h | **0,99 h** | 1,92 h |
| `2k` | 60 | 875 s = 0,24 h | 0,30 h | 0,89 h | 1,77 h |
| **`1,68k`** (lo medido) | 50,4 | **828 s = 0,23 h** | 0,29 h | **0,86 h** | 1,72 h |
| `k` | 30 | 723 s = 0,20 h | 0,25 h | 0,79 h | 1,62 h |
| *(ventaja 0, referencia)* | 0 | 559 s = 0,16 h | — | — | — |

**Criterio `α`** (`δ=0`): el ahorro de pasar de `3k` a `1,68k` es 27,4 % a `α=0,10`, 22,4 % a 0,25,
**18,7 % a 0,33**, 17,5 % a 0,35 y 13,9 % a 0,40 — se mueve con `α` y **decrece** cuando `α` sube, que
es lo esperado (cerca de `r=1` manda la deriva, no el desplazamiento inicial).

**Sensibilidad:** `dF_carrera/d(ventaja) ≈ 4,6-5,6 s por bloque` a `α = 0,33`. Los 40 bloques que hay
entre `3k` y `1,68k` valen **191 s = 3,2 minutos**.

### ¿Es legítimo diseñar con la ventaja medida? — **NO. Etiqueta: PLAUSIBLE que no lo sea, y en todo caso IRRELEVANTE**

Tres razones, en orden de peso:

1. **No compra casi nada.** 3,2 minutos de `F` en el modelo `δ=0` y 7,8 min en el pesimista. Cambiar
   una cota **demostrada** por una medida para ganar tres minutos es un mal negocio de auditoría.
2. **El paper no usa `3k` como «la ventaja típica», sino como una hipótesis explícitamente saturada.**
   `research/fuentes/phantom-ghostdag.txt` **L1234-1238**: *«the Freeloader Bound guarantees that if the
   selected tip at time t was freeloading, adv(t) is bounded by a constant 3k. Therefore, **by assuming
   the attacker always manages to saturate this constant, so that their advantage never goes below 3k**,
   we can shift the process adv′(t) by 3k and analyze it as a block race»*. La cota es lo que hace que
   el resto del análisis sea una carrera de Nakamoto limpia. Sustituirla por una medida obliga a rehacer
   el argumento de Lema 10, no solo a cambiar un número.
3. **La medida es un máximo sobre 6 h de tiempo simulado; `F_carrera` es una unión sobre 10 años.**
   D8 observó `12 × 1 800 s = 21 600` bloques; diez años son `3,15·10⁸`, **14 600×** más. La cola de
   `adv` es geométrica de base `r` (el propio L1232-1236), luego el máximo crece como `ln N/ln(1/r)`:

   | `α` | `r` (`δ=0`) | medido (1 800 s) | incremento a 10 años | máx. 10 años estimado | vs `3k=90` |
   |---:|---:|---:|---:|---:|---|
   | 0,10 | 0,111 | 17 | +4,4 | 21,4 | por debajo |
   | 0,25 | 0,333 | 30 | +8,7 | 38,7 | por debajo |
   | **0,33** | 0,493 | **50** | **+13,5** | **63,5** | por debajo |
   | 0,40 | 0,667 | 41 | +23,6 | 64,6 | por debajo |

   El margen a `α = 0,33` no es de 40 bloques (90−50) sino de ~26 (90−63,5), y a `α = 0,40` de 25. La
   cota **sigue sin saturarse**, lo que confirma que es conservadora — pero **1,68k no es el número que
   habría que poner** si se decidiera diseñar con la ventaja real: sería ~2,1k, y con una extrapolación
   PLAUSIBLE, no medida.

**Recomendación B.1: mantener `3k`.** Es la única de las cinco palancas que se puede tocar sin coste
externo y es la que menos da. Se anota como colchón oculto: el diseño está pagando ~3 min de `F`
por conservar una cota demostrada, y ese es un precio bueno.

---

## B.2 · Palanca `k` — **VERIFICADO** (y la palanca **cambia de signo** según el modelo)

**Script:** `r10b_b2_k.py` → `salida_b2.txt` (56 s). **Control del modelo (ii)** contra la tabla
publicada en `research/dag-poas-delta-real.md` **L30-33**: `k=25 → λ_real 1,471 / δ_real 0,320`;
`k=30 → 1,364 / 0,267`; `k=40 → 1,250 / 0,200`. **Los tres OK** antes de usarlo.

`k` entra en la carrera por **tres sitios distintos** y hay que decir en cuál se cree:

| Modelo | Qué depende de `k` | Fuente |
|---|---|---|
| (i) `δ = 0` (9a) | **solo** la ventaja `3k` | `d9-ronda9a/informe.md` §L5.1 |
| (ii) `δ_real(k)`, `λ_real(k)` | ventaja `3k` **+** `δ` **+** `λ` | `dag-poas-delta-real.md` §1 |
| (iii) `δ` de D8 | solo la ventaja `3k`; el `δ` está **medido a `k = 30` y solo ahí** | `d8-ronda8/salida_a1b.txt` |

### (i) `δ = 0` — `k` grande **empeora** `F` (`I = 851 s`)

| `k` | `3k` | `F_carrera` 33 % | 35 % |
|---:|---:|---:|---:|
| 20 | 60 | 875 s = **0,24 h** | 0,30 h |
| 25 | 75 | 948 s = 0,26 h | 0,32 h |
| **30** | 90 | **1 019 s = 0,28 h** | 0,35 h |
| 40 | 120 | 1 157 s = 0,32 h | 0,39 h |

Es la palanca de B.1 con otro nombre: 20 → 40 mueve `F_carrera` **282 s**. Débil.

### (ii) `δ_real(k)` y `λ_real(k)` autoconsistentes — `k` grande **mejora** `F`, y mucho

| `k` | `λ_real` | `δ_real` | `k_Poisson` | ¿admisible? | `F_carrera` 33 % | 35 % | `r(0,33)` |
|---:|---:|---:|---:|:---:|---:|---:|---:|
| 20 | 1,667 | 0,400 | 26 | **NO** | 6 600 s = 1,83 h | 5,64 h | 0,821 |
| 25 | 1,471 | 0,320 | 24 | sí | 2 996 s = 0,83 h | 1,47 h | 0,724 |
| **30** | 1,364 | 0,267 | 22 | sí | **2 267 s = 0,63 h** | 0,96 h | 0,672 |
| 40 | 1,250 | 0,200 | 21 | sí | **1 885 s = 0,52 h** | 0,72 h | 0,616 |

Dos hallazgos:

1. **`k = 20` no es admisible**: el punto fijo del retarget exige `k ≥ k_Poisson(2Δλ_real) = 26`
   (`dag-poas-delta-real.md` §1, condición «`k ≥ k_Poisson(2Dλ_real, 10⁻³)`»). La fila está para
   mostrar que si se bajara `k` para acortar `F` en el modelo (i), en el modelo (ii) `F_carrera`
   **se multiplicaría por 6,5**. Bajar `k` es la peor idea de las cinco palancas.
2. **Subir `k` de 30 a 40 acorta `F_carrera` un 17 %** (0,63 → 0,52 h) en el modelo pesimista
   coherente, y lo **alarga** un 14 % en el modelo `δ=0`. **La palanca `k` no tiene un signo: lo
   tiene el modelo de `δ`.** Por eso B.4 (elegir el modelo) manda sobre B.2.
   Y `k=40` tiene coste propio fuera de esta cuenta: `3k = 120` en la ventaja, `mergeset_size_limit`
   y `max_block_parents` (`R-FIN-12`: `max(10,⌊k/2⌋)`, `max(180,2k)`) y una `Δ` tolerable mayor.

### (iii) `δ` de D8, con `k` movido — **LAGUNA declarada**

| `k` | `δ(0,33)` | `F_carrera` 33 % | 35 % |
|---:|---:|---:|---:|
| 20 | 0,2867 *(no recalibrada)* | 0,89 h | 1,77 h |
| 25 | 0,2867 *(no recalibrada)* | 0,94 h | 1,84 h |
| **30** | 0,2867 *(la medida)* | **0,99 h** | 1,92 h |
| 40 | 0,2867 *(no recalibrada)* | 1,08 h | 2,06 h |

Aquí `k` solo mueve `3k`, porque el `δ` de D8 **no se ha vuelto a medir con otro `k`**. Es una
**LAGUNA**: para cerrarla habría que re-correr `d8_a1b_umbral.py` con `k ∈ {20,25,40}` (~5 min por `k`
según `salida_a6b.txt`, 280 s con 4 `J` y 5 `α`). No se hizo por presupuesto y porque B.4 concluye que
ese modelo no es el correcto para diseñar.

**Criterio `α`** en el modelo (ii) con `k=30`: `F_carrera` = 0 · 292 · 797 · **2 267** · 3 463 ·
28 916 s para `α` = 0 · 0,10 · 0,25 · 0,33 · 0,35 · 0,40. Se mueve, y explota hacia `r=1` (0,909 a 0,40).

### (iii-bis) La LAGUNA de (iii), CERRADA: el `δ` de D8 re-medido a cada `k` — **VERIFICADO**

**Error propio.** El párrafo anterior cerraba (iii) con «no se hizo por presupuesto». La regla 3 del
método (`METODO-AGENTES.md:8-13`, 2026-09-08) lo prohíbe: *LAGUNA nunca por falta de tiempo*. Se ha
medido.

**Script:** `r10b_b2b_delta_k.py` → `salida_b2b.txt` (69 s, **1 920 corridas**, 32 procesos).
Reutiliza `d8_lib.MundoL9` y `d8_lib.delta_hon` **sin reescribirlos** y repite el protocolo exacto de
`d8-ronda8/d8_a1b_umbral.py:60-95`: 12 semillas, `J ∈ {16,31,48,64,96}` tomando el `J` que
**maximiza** `δ`, horizonte 1 800 s, ventana `[60, 1 740]`, `modo='parasito'`, `d_fork=1`. Único
cambio: `k` es parámetro y con él viajan las constantes que R-FIN-12 le ata
(`mp = max(10,⌊k/2⌋)`, `msl = max(180,2k)`, `dag-poas-delta-real.md:88-90`). A `k = 30` eso da
`mp=15, msl=180`, los de D8: la fila `k = 30` es **control positivo**.

**Control: las 8 filas de `k = 30` reproducen `d8-ronda8/salida_a1b.txt` exactamente**
(`salida_b2b.txt` L30-37: 0,0000 / 0,1544 / 0,2079 / 0,2867 / 0,3065 / 0,3448 / 0,4366 / 0,5834, las
ocho marcadas `OK`). Cobertura: `raf` > 0 en toda fila con `α > 0` (la maniobra se ejecuta), `rech = 0`.

| `α` | `δ` (`k=20`) | `δ` (`k=25`) | **`δ` (`k=30`)** | `δ` (`k=40`) |
|---:|---:|---:|---:|---:|
| 0,00 | 0,0005 | 0,0000 | **0,0000** | 0,0000 |
| 0,25 | 0,1498 | 0,1528 | **0,1544** | 0,1553 |
| 0,30 | 0,2035 | 0,1897 | **0,2079** | 0,2187 |
| **0,33** | 0,2425 `[0,2145; 0,2706]` | 0,2824 `[0,2594; 0,3055]` | **0,2867 `[0,2650; 0,3085]`** | 0,2514 `[0,2197; 0,2831]` |
| 0,35 | 0,2903 | 0,3279 | **0,3065** | 0,3171 |
| 0,40 | 0,4022 | 0,3915 | **0,4366** | 0,4619 |

*(intervalos de confianza al 95 %, `t₀,₉₇₅;₁₁ = 2,201`, 12 semillas)*

**Hallazgo: el `δ` parásito NO depende de `k` de forma medible.** Los cuatro intervalos al 33 % se
solapan (`[0,2145; 0,3085]` es la envolvente). La variación aparente entre `k` (0,2425 → 0,2867)
**es ruido de semilla**, no una tendencia. Así que en el modelo (iii) `k` actúa **solo** por `3k`,
que es justo lo que la tabla (iii) suponía: **la suposición era correcta, y ahora está medida.**

**`F_carrera` con el `δ` medido a cada `k`** (`r10b_b2c_iii.py` → `salida_b2c.txt`):

| `k` | `3k` | `δ(0,33)` medido | `F_carrera` 33 % | 35 % | *(tabla anterior, `δ` no recalibrada)* |
|---:|---:|---:|---:|---:|---:|
| 20 | 60 | 0,2425 | 2 374 s = **0,66 h** | 1,49 h | 0,89 h |
| 25 | 75 | 0,2824 | 3 269 s = **0,91 h** | 2,38 h | 0,94 h |
| **30** | 90 | 0,2867 | 3 547 s = **0,99 h** | 1,92 h | 0,99 h |
| 40 | 120 | 0,2514 | 3 097 s = **0,86 h** | 2,32 h | 1,08 h |

**Y el dato que importa para C: la incertidumbre de la medida pesa más que la palanca.** Moviendo `δ`
entre los extremos del IC95 a `k = 30`, `F_carrera` va de **0,85 h a 1,16 h** (±0,15 h = ±9 min).
La palanca B.1 entera (de `3k` a `1,68k`) valía 3,2 min. **El ruido de la medida de `δ` es tres veces
mayor que la mejor palanca de ventaja.**

---

## B.3 · Palanca «objetivo de riesgo» — **VERIFICADO** (y el objetivo actual es extremadamente conservador)

**Script:** `r10b_b3_riesgo.py` → `salida_b3.txt` (97 s).

### Controles positivos, los tres pasados antes de mirar nada

| Control | Resultado |
|---|---|
| **Tabla 4 de Grunspan & Pérez-Marco** (`research/fork-choice-reorg.md:199-208`), `z` con `P < 10⁻³` para `q = 10…45 %` | **8/8 OK** con `P(z) = I₄ₚq(z, ½)` (`scipy.special.betainc`) |
| **Tabla 1 de Rosenfeld** (`research/fork-choice-reorg.md:212-215`), `q ∈ {0,10; 0,20}`, `n ∈ {1,2,3,4,6}` | **10/10 OK** |
| `F_carrera(33 %)` del instrumento de esta ronda | 1 019 s / 3 547 s **OK** |

**Estado de la fuente primaria de Bitcoin: LAGUNA parcial, declarada.** El PDF de Nakamoto **no está**
en `research/fuentes/` (solo hay `bdk19` y `phantom-ghostdag`), así que no se cita §11 directamente:
se cita la transcripción del repositorio (`fork-choice-reorg.md:193-208`) **y se reproduce su tabla
entera desde la fórmula cerrada**, que es la forma más fuerte de validar una transcripción sin el
original. Para cerrarla del todo haría falta `bitcoin.pdf` en `research/fuentes/`. Lo mismo con
Grunspan y Rosenfeld: los arXiv (1702.02867, 1402.2009) están citados, los PDF no están.

### Qué garantiza de hecho cada uno, en sus propias unidades

| Sistema | Garantía real | Fuente |
|---|---|---|
| **Bitcoin, práctica** | 6 confirmaciones a `q = 10 %` → `P = 5,91·10⁻⁴` **por transacción**, ~60 min | `fork-choice-reorg.md:199-201`, reproducido |
| Bitcoin a `q = 33 %`, 6 conf. | `P = 2,34·10⁻¹` — el `10⁻³` **desaparece por completo** | calculado |
| Bitcoin a `q = 33 %` para `P < 10⁻³` | `z = 45` bloques = **7,5 h** | calculado |
| **GHOSTDAG (el propio paper)** | *«an attacker with α ≤ 0.25, and an allowed error of **ε = 0.1 %**»* → 45 s | `research/fuentes/phantom-ghostdag.txt:827-830` (literal) |
| **Chia** | 6 bloques (~2 min) natural; **32 bloques (~10 min)** contra *foliage re-org*, bajo «< 42,7 % colluding». **No publica ningún `ε`** | `research/chia-documentacion-oficial.md:308-321` |
| **ZEROX hoy** | unión a 10 años `< 10⁻¹⁰` ⇒ **2,70·10⁻¹⁶ por época** | `verif_frontera_vs_F.py` |

**ZEROX se está imponiendo un objetivo `2,2·10¹²` veces más estricto por evento que la práctica de
Bitcoin, y `4·10¹²` veces más estricto que el `ε` del propio paper de GHOSTDAG.**

### Los dos sistemas bajo el MISMO criterio (unión a 10 años)

`I = 851 s` ⇒ 370 576 épocas en 10 años; Bitcoin, 525 600 bloques.

| Objetivo (10 años) | ZEROX `F_carrera` `δ=0` | ZEROX `δ` D8 | **Bitcoin `z` (33 %)** | **Bitcoin horas** | Bitcoin `z` (10 %) | horas |
|---:|---:|---:|---:|---:|---:|---:|
| `10⁻⁶` | 852 s = **0,24 h** | 0,79 h | 203 | **33,8** | 25 | 4,2 |
| `10⁻⁸` | 936 s = 0,26 h | 0,89 h | 239 | 39,8 | 29 | 4,8 |
| **`10⁻¹⁰`** | **1 019 s = 0,28 h** | **0,99 h** | **276** | **46,0** | 34 | 5,7 |
| `10⁻¹²` | 1 100 s = 0,31 h | 1,08 h | 313 | 52,2 | 38 | 6,3 |

**Bitcoin, sometido al criterio que ZEROX se aplica a sí mismo, necesitaría 46 horas de confirmación
a `q = 33 %` — y 5,7 h incluso a `q = 10 %`.** ZEROX lo cumple con 0,28-0,99 h. La comparación no es
retórica: es la misma unión, el mismo horizonte y el mismo objetivo, calculados con la fórmula exacta.

### La palanca: bajar el objetivo casi no compra nada

| | `δ = 0`, 33 % | `δ` D8, 33 % | `δ = 0`, 35 % | `δ` D8, 35 % |
|---|---:|---:|---:|---:|
| `10⁻⁶` → `10⁻¹⁰` | +167 s | +720 s | +212 s | +1 476 s |
| **todo el rango `10⁻⁶`…`10⁻¹²`** | **+248 s = 4,1 min** | +1 044 s = 17,4 min | +317 s | +2 196 s |

**Relajar el objetivo cuatro órdenes de magnitud (de `10⁻¹²` a `10⁻⁶`) ahorra 4,1 minutos de `F` en el
modelo verificado y 17,4 en el pesimista.** Es la palanca más barata de todas y por eso la más
peligrosa de tocar: se paga muy poco por conservarla. La razón es estructural: `p_F` cae
exponencialmente en `F`, así que cuatro décadas de riesgo son cuatro décadas de exponencial, es decir,
un múltiplo pequeño y constante del tiempo característico `1/ln(1/r)`.

**Criterio `α`** (`δ=0`): el coste `10⁻⁶ → 10⁻¹²` es 0 s (α=0) · 44 s (0,10) · 116 s (0,25) ·
**248 s (0,33)** · 317 s (0,35) · 702 s (0,40). Se mueve con `α` y crece al acercarse a `r = 1`.

### Y al revés: qué `F` bastaría con el criterio POR EVENTO que usan Bitcoin y el paper

*(error propio: la primera versión pidió esto con `f_carrera`, que aplica la unión y satura en 1;
corregido con `f_evento`, que exige `prev` por época `< ε` sin unión — `r10b_b3_riesgo.py:60-70`)*

| `α` | modelo | `F` con `ε = 10⁻³` (el de Bitcoin y el del paper) | `F` con `ε = 10⁻⁶` |
|---:|---|---:|---:|
| 0,33 | `δ = 0` | 460 s = **7,7 min** | 608 s = 10,1 min |
| 0,33 | `δ` D8 | 1 298 s = 21,6 min | 1 869 s = 31,1 min |
| 0,35 | `δ = 0` | 541 s = 9,0 min | 727 s = 12,1 min |
| 0,35 | `δ` D8 | 2 221 s = 37,0 min | 3 383 s = 56,4 min |

**Con el criterio de Bitcoin, `F` sería de 8 a 37 minutos.** La diferencia entre 8 min y 2 h **no es
física, es la elección del objetivo**: unión sistémica sobre toda la historia frente a riesgo por
transacción. Las dos son defendibles; hay que decir cuál se está comprando.

**Recomendación B.3: mantener `10⁻¹⁰` a 10 años, y publicar las dos cifras.** Cuesta 4 minutos sobre
`10⁻⁶` en el modelo de diseño, y a cambio da una propiedad que Bitcoin no da: *ninguna* reversión más
allá de `F` en toda la vida de la cadena, no solo *esta* transacción a salvo. Lo que **sí** hay que
corregir es la retórica: `F` no es «lo que Bitcoin llama 6 confirmaciones»; es varios órdenes de
magnitud más fuerte, y conviene decirlo cuando se compare con Chia (10 min) o con Bitcoin (60 min).
