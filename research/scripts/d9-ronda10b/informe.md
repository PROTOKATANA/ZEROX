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

**Casi nada estocástico en esta ronda.** Diez de los once scripts son evaluación numérica
determinista de fórmulas cerradas (Skellam + ruina del jugador; y la beta incompleta de Grunspan en
B.3): la regla de las ≥ 12 semillas no les aplica. El undécimo, `r10b_b2b_delta_k.py` (cierre de la
LAGUNA de B.2 (iii)), **sí lo es**: 12 semillas, 1 920 corridas, intervalos de confianza al 95 %.
`AUDITA_SCRIPTS.py` da **0 sospechas** sobre los once. El criterio `α` aplica a todos y está en cada
tabla. *(Esta cabecera decía en el primer intento que la ronda no tenía nada estocástico y que
`AUDITA` marcaría `T4`; ver «Errores propios» 2.)*

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

---

## B.4 · ¿Cuál es el modelo de `δ` correcto para diseñar `F`? — **DEMOSTRADO** que no es ninguno de los dos publicados

La pregunta del encargo es «`δ = 0`, la `δ` pesimista de D8, o algo intermedio». La respuesta corta:
**ninguna de las tres, tal como están planteadas. El modelo correcto es `δ = δ₀(Δ_ef)`** — el `δ` que
un atacante impone **sin gastar espacio**, en función del retardo honesto↔honesto efectivo. A
`Δ = 4 s` ese modelo **es** `δ = 0` (medido 0,0000), pero por una razón distinta de la que se le
atribuye, y con una condición de validez que `δ = 0` a secas no lleva escrita.

### Los cuatro candidatos, y por qué caen tres

| Candidato | Qué es | Veredicto |
|---|---|---|
| **`δ = 0`** (9a) | El `δ` no entra en la carrera | **Correcto como valor, incompleto como modelo.** Es el caso `Δ → 0` de M4, no un axioma |
| **`δ` de D8** (0,2867 a 33 %) | El `δ` parásito medido | **REFUTADO como modelo de la carrera:** es doble conteo |
| **`δ_real(k)`** (0,267) | El sesgo del retarget | **Anulado por regla:** R-FIN-13′ |
| **`δ₀(Δ)`** (9a A6) | El `δ` que compra un atacante de RED, gratis | **El correcto.** Es el único que no compite por el presupuesto de espacio |

**1. Por qué la `δ` de D8 no puede ir en la carrera — la fuente, literal.** La carrera del paper se
corre contra `w_H`, y `w_H` es el score del **bloque virtual honesto**, que ya suma los azules del
atacante: `research/fuentes/phantom-ghostdag.txt` **L1034-1036**, leído por el principal y transcrito
en `dag-poas-ancla-de-orden-auditoria-8a.md` §0. `(1−α)(1−δ)λ` es el ritmo de **bloques honestos
azules**, una magnitud distinta y menor. Poner esa `δ` en el denominador es contar el mismo `α` dos
veces: una para enrojecer honestos (exige bloques **publicados**) y otra para correr en privado
(exige bloques **retenidos**). **Y no es solo un argumento: 9a lo midió.** Repartiendo
`α = α_p + α_f` entre parasitar y correr, «la deriva máxima está en `α_p = 0` en las 5 filas»
(7 200 corridas, `auditoria-8a.md` §0 y §2): al atacante le conviene **no** parasitar. El modelo
pesimista describe a un atacante **estrictamente dominado**.

**2. Por qué `δ_real(k)` ya no aplica.** `dag-poas-delta-real.md` §1 lo deriva del sesgo que el Lema 9
mete en el retarget (`λ_obs = λ·k/(k+2Δλ)` ⇒ `λ_real = 1,364`, `δ_real = 0,267` a `k = 30`). La
ronda 9b lo cerró **por regla**: con **R-FIN-13′** el retarget cuenta un bloque por identidad, y la
inflación medida cae de **×1,45 a ×1,005** (`dag-poas-ancla-de-orden-auditoria-8b.md` §3, tabla
L73-78). Cita literal de esa auditoría, L80-82: *«Con R-FIN-13′ esa nota deja de aplicar:
`δ_real → δ` nominal (0,267 → 0,211), umbral de orden 40,0 → 41,7 %»*. El modelo M6 se conserva en la
tabla de C **solo como referencia histórica**.

**3. Por qué `δ₀(Δ)` sí sobrevive a las dos objeciones.** Es la única `δ` que **no consume el
presupuesto del atacante de espacio**: la impone un atacante de **red** (eclipse parcial, inundación)
que está fuera del modelo del paper (`phantom-ghostdag.txt` L1024-1027, adversario sin retardo) y que
no gasta ni un bloque. Por tanto se **compone** con la carrera privada sin doble conteo: el mismo `α`
corre en privado mientras la red honesta va lenta. 9a lo midió a `α = 0` precisamente para aislarlo
(`r9a_a6_frontera_delta.py:36-38`): 0,0000 a 4 s · 0,0020 a 8 s · 0,0828 a 12 s · 0,2858 a 16 s ·
0,4428 a 20 s. Y **eligió la medida y no la cola de Poisson** `P(Poisson(2Δλ) > k)`, que sobreestima
(a `Δ = 16` da 0,59 frente a 0,286 medido) — su propio comentario, `r9a_a6_frontera_delta.py:28-31`.

### La condición de validez que hay que escribir junto al número

El teorema de la ráfaga de 9a (`R < A ⟺ gana`), que es lo que permite tirar la `δ` parásita, **vale
mientras `2Δλ ≪ k`**. La propia 9a lo declara: *«la conservación `W_pub/H ≥ 1` se rompe con `Δ` grande
(`Δ = 20`, `α = 0,35`: 0,936)»* (`auditoria-8a.md` §4). Es decir: **a `Δ` pequeña, `δ₀` y la `δ`
parásita no se suman porque la segunda es dominada; a `Δ` grande, la separación deja de estar
demostrada.** Cómo se componen exactamente por encima de `Δ ≈ 16 s` es una **LAGUNA**: se cerraría
midiendo el reparto `α_p/α_f` (el A2 de 9a) con `Δ ∈ {12, 16, 20}` en lugar de 4 s. No se hace aquí
porque cae fuera del encargo y porque la conclusión de diseño no cambia: por encima de 16 s el diseño
ya está fuera de colchón por el propio `δ₀`.

### El modelo que se debe usar — **recomendación**

> **`δ = δ₀(Δ_diseño)`, con `Δ_diseño = 12 s` como valor central y `Δ = 16 s` como caso de esfuerzo.**

El porqué, en orden:

1. **`Δ = 4 s` es una hipótesis, no una medida.** `dag-poas-bitacora-2026-09-08.md` §5: «**`Δ`: sin
   medir**», y §6.2 lo pone como *«la primera medición que el diseño necesita»*. Diseñar `F` con
   `δ = 0` es diseñar con `Δ = 4 s` **exacto** y sin margen.
2. **El margen que hace falta no es en `δ`, es en `Δ`.** «Algo intermedio» entre 0 y 0,2867 no
   corresponde a ningún atacante: la interpolación no tiene significado físico. `δ₀(12 s) = 0,0828`
   sí lo tiene — es un retardo efectivo tres veces peor que el supuesto.
3. **Cuesta poco.** `F_carrera(33 %)`: 0,28 h a 4 s → **0,36 h a 12 s** → 0,98 h a 16 s. El margen
   central cuesta **5 minutos**; el de esfuerzo, 42 minutos.
4. **La `δ` de D8 sigue siendo útil, pero para otra cosa.** Como cota superior de «qué pasaría si el
   teorema de la ráfaga fallara», que es exactamente el régimen `Δ` grande. Es notable —y es lo que
   cierra el argumento— que **`δ` D8 (0,2867) y `δ₀(16 s)` (0,2858) coinciden a la tercera cifra**:
   `F_carrera` 0,99 h frente a 0,98 h. **El modelo pesimista de D8 y el modelo de red a `Δ = 16 s`
   dan la misma `F`.** Quien quiera el pesimista y quien quiera el margen de red hasta 16 s están
   pidiendo, numéricamente, la misma cosa. Esto convierte la discusión de B.4 en una sola pregunta:
   **¿hasta qué `Δ` se quiere aguantar?**

Etiqueta: **DEMOSTRADO** que la `δ` de D8 no va en el denominador de la carrera (fuente literal +
medida de dominancia de 9a) · **VERIFICADO** que `δ_real` queda anulada por R-FIN-13′ (9b, ×1,005) ·
**PLAUSIBLE** que `δ₀(Δ)` sea *toda* la `δ` que hay a `Δ ≥ 16 s` (ahí la separación no está
demostrada: LAGUNA declarada arriba).

---

## B.5 · Palanca `Δ` — **VERIFICADO** (y es, con diferencia, la que más pesa)

**Script:** `r10b_b5_delta_red.py` → `salida_b5.txt` (149 s). `δ₀(Δ)` **medido**, de
`r9a_a6_frontera_delta.py:36-38`; interpolación lineal entre los puntos medidos, igual que
`A.delta_interp` hace con `δ(α)`.

**Control positivo: la tabla de fronteras de 9a (`auditoria-8a.md` §4) reproducida 5/5** —
46,8784 / 46,8268 / 44,6544 / 38,3337 / 32,3788 % a `Δ` = 4 / 8 / 12 / 16 / 20 s.

### `F_carrera` por `Δ` (`I = 851 s`, ventaja `3k = 90`, objetivo `10⁻¹⁰` a 10 años)

| `Δ` | `δ₀` medido | `r(0,33)` | `F_carrera` 33 % | 35 % | frontera a `F = 2 h` |
|---:|---:|---:|---:|---:|---:|
| **4 s** (diseño) | 0,0000 | 0,493 | 1 019 s = **0,28 h** | 0,35 h | 44,57 % |
| 8 s | 0,0020 | 0,494 | 1 024 s = **0,28 h** | 0,35 h | 44,52 % |
| **12 s** | 0,0828 | 0,537 | 1 314 s = **0,36 h** | 0,46 h | 42,30 % |
| **16 s** | 0,2858 | 0,690 | 3 524 s = **0,98 h** | 1,55 h | 35,87 % |
| 20 s | 0,4428 | 0,884 | 29 002 s = **8,06 h** | *sin cruce* | 29,86 % |
| 24 s, 32 s | 0,5401 · 0,6526 | 1,071 · 1,418 | **COTA VACUA (`r ≥ 1`)** | — | — |

*(**Error propio, declarado y corregido:** la primera ejecución imprimió 37,59 h para `Δ = 24 s` y
2,93 h para `Δ = 32 s` — no monótono, y una frontera de 48,92 % a `Δ = 32 s`. Son el artefacto del
recorte a `r^700` que D8 declaró y que aparece siempre que `r ≥ 1`: `prev()` cae a ~0 y la cota se
vuelve vacua. El script ahora calcula `Δ` donde `r(0,33) = 1` — **22,7 s** — y marca esas filas en
lugar de imprimir números.)*

### El hallazgo: **`F` no puede comprar `Δ`**

| `F` | `Δ_max` tolerable al 33 % | ganancia sobre `Δ = 4 s` |
|---:|---:|---:|
| 0,25 h | **ninguno** (ni con `Δ = 4 s`) | — |
| 0,50 h | 13,6 s | +9,6 s |
| 0,75 h | 15,2 s | +11,2 s |
| **1,00 h** | **16,1 s** | +12,1 s |
| 1,50 h | 17,3 s | +13,3 s |
| **2,00 h** | **18,0 s** | +14,0 s |
| 3,00 h | 18,8 s | +14,8 s |
| 5,30 h | 19,6 s | +15,6 s |

**Duplicar `F` de 1 h a 2 h compra 1,9 segundos de `Δ`. Quintuplicarla de 1 h a 5,3 h compra 3,5.**
El techo es duro: por encima de `Δ ≈ 22,7 s` la base de la carrera `r` pasa de 1 y **ninguna `F`
basta**, porque el atacante deja de perder la carrera en media. Alargar `F` es una palanca
**logarítmica** contra `Δ`, y `Δ` entra en `r` de forma **lineal**.

**Consecuencia de diseño, y es la más importante de toda la ronda:** discutir si `F` vale 1 h o 2 h
es discutir 1,9 s de tolerancia a `Δ`, mientras que `Δ` **no está medido** y la diferencia entre 4 s
y 16 s cambia `F_carrera` en un factor **3,5**. **La ronda correcta no es afinar `F`: es medir `Δ`.**

**Criterio `α`** (`salida_b5.txt`, última tabla): `F_carrera` a `Δ = 4/8/12/16/20 s` para
`α = 0,10` → 267/268/298/413/586 s; `α = 0,25` → 551/554/655/1 163/2 506 s;
`α = 0,33` → 1 019/1 024/1 314/3 524/29 002 s. Se mueve con las dos variables y explota hacia `r = 1`.

---

## C · Entrega — la `F` más corta con ≥ 2 puntos de colchón, y la recomendación

**Scripts:** `r10b_c_entrega.py` → `salida_c.txt` (435 s) y `r10b_c2_delta35.py` → `salida_c2.txt` (128 s).

### La identidad que hace la cuenta, comprobada antes de usarla

«frontera(`F`) = 35 %» y «`F_carrera(35 %) = F`» son **la misma ecuación** (las dos dicen
`union10 = 10⁻¹⁰` en el punto `(F, 35 %)`), y por tanto **la `F` mínima con 2 puntos de colchón sobre
el 33 % es exactamente `F_carrera(35 %)`**. Vale mientras `r(0,35) < 1`, porque la frontera es el
*primer* cruce. **Comprobado numéricamente en los seis modelos** (`salida_c.txt`, CONTROL 2:
35,0005 / 35,0005 / 34,9995 / 35,0000 / 35,0000 / 35,0000 %). Y el CONTROL 1 reproduce la fila
`F = 2 h` de la bitácora: 44,57 % / 35,08 %, **OK**.

### TABLA C — la `F` mínima por modelo (`I = 851 s`, ventaja `3k = 90`, objetivo `10⁻¹⁰` a 10 años)

| Modelo | Qué supone | `F_carrera` (33 %) | **`F` MÍNIMA (+2 pts)** | `r(0,35)` |
|---|---|---:|---:|---:|
| **M1** `δ = 0` (9a) | `Δ = 4 s` **exacto**, sin margen | 0,28 h | **0,35 h = 21 min** | 0,538 |
| **M2** `δ₀(Δ=8 s)` = 0,0020 | `Δ` el doble del supuesto | 0,28 h | **0,35 h = 21 min** | 0,540 |
| **M3** `δ₀(Δ=12 s)` = 0,0828 | `Δ` el triple — **el modelo que B.4 recomienda** | 0,36 h | **0,46 h = 28 min** | 0,587 |
| **M4** `δ₀(Δ=16 s)` = 0,2858 | `Δ` cuádruple; el límite que `k = 30` aguanta | 0,98 h | **1,55 h** | 0,754 |
| **M5** `δ` de D8 (pesimista) | Que el teorema de la ráfaga de 9a **falle** | 0,99 h | **1,92 h** | 0,776 |
| **M6** `δ_real(k)` + `λ_real` | Que R-FIN-13′ **no** se aplique | 0,63 h | **0,96 h** | 0,735 |

### El colchón real de cada `F` candidata (frontera − 33 %)

| Modelo | `F = 0,5 h` | `0,75 h` | **`1 h`** | `1,5 h` | **`2 h`** | `3 h` |
|---|---:|---:|---:|---:|---:|---:|
| M1 `δ=0` | +5,0 p | +7,5 p | **+9,0 p** | +10,6 p | **+11,6 p** | +12,7 p |
| M2 `Δ=8 s` | +4,9 p | +7,5 p | +8,9 p | +10,6 p | +11,5 p | +12,6 p |
| **M3 `Δ=12 s`** | +2,6 p | +5,2 p | **+6,7 p** | +8,3 p | **+9,3 p** | +10,4 p |
| M4 `Δ=16 s` | **−4,2 p** | **−1,4 p** | +0,1 p | +1,9 p | **+2,9 p** | +4,0 p |
| M5 D8 | **−2,2 p** | **−0,8 p** | +0,1 p | +1,4 p | **+2,1 p** | +2,8 p |
| M6 `δ_real` | −1,3 p | +0,9 p | +2,1 p | +3,6 p | +4,4 p | +5,4 p |

**`F = 2 h` es, al segundo, la `F` más corta que conserva ≥ 2 puntos en TODOS los modelos, incluidos
los dos que las rondas 9a y 9b refutaron.** La elección provisional de Katana no era conservadora por
casualidad: es exactamente el mínimo de la columna «sobrevive a todo».

### Lo que hay que medir para poder bajarla — y es una sola cosa

| `Δ` medido | `δ₀` | `F_carrera` (33 %) | **`F` mínima (+2 pts)** |
|---:|---:|---:|---:|
| 4-8 s | ≤ 0,0020 | 0,28 h | **0,35 h = 21 min** |
| 10 s | 0,0424 | 0,32 h | 0,40 h = 24 min |
| **12 s** | 0,0828 | 0,36 h | **0,46 h = 28 min** |
| 13 s | 0,1336 | 0,44 h | 0,58 h = 35 min |
| 14 s | 0,1843 | 0,55 h | 0,75 h = 45 min |
| 15 s | 0,2350 | 0,71 h | 1,03 h = 62 min |
| **16 s** | 0,2858 | 0,98 h | **1,55 h = 93 min** |
| 18 s | 0,3643 | 2,00 h | 4,29 h = 257 min |
| 20 s | 0,4428 | 8,06 h | *sin cruce* |

Y al revés, el `Δ` que cada `F` compra (`salida_c2.txt`; control 3/3 contra B.5):

| `F` | `Δ_max` al 33 % | **`Δ_max` con +2 pts (35 %)** |
|---:|---:|---:|
| 0,35 h | 11,4 s | 8,0 s |
| 0,5 h | 13,6 s | 12,4 s |
| **1 h** | 16,1 s | **14,9 s** |
| **2 h** | 18,0 s | **16,6 s** |
| 5,3 h | 19,6 s | 18,3 s |

### ⚠️ Corrección al encuadre del encargo: por debajo de `Δ ≈ 14 s`, **el suelo de `F` NO lo pone la carrera**

`F = max(F_carrera, I/(W/κ − 1))` (`dag-poas-ancla-de-orden-auditoria-8c.md:87`), con `W/κ = 1,22`
(bitácora §5). El segundo término vale `4,545·I` y **no depende de `Δ` ni de la carrera**:

| Configuración | `I` | `F` por *steering* = `I/(W/κ−1)` | `F` por carrera (+2 pts), `Δ ≤ 12 s` | **`F` = max** |
|---|---:|---:|---:|---:|
| `ρ_max = 1` | 491 s | **0,62 h** | 0,35-0,46 h | **0,62 h** ← manda el *steering* |
| **`ρ_max = 1,5`** | 602 s | **0,76 h** | 0,35-0,46 h | **0,76 h** ← manda el *steering* |
| `ρ_max = 3` | 851 s | **1,07 h** | 0,35-0,46 h | **1,07 h** ← manda el *steering* |
| Revelación retardada | libre | **0** | 0,35-0,46 h | **0,35-0,46 h** ← manda la carrera |

*(las `F` por steering son las de `auditoria-8c.md:76-78`, reproducidas: `491/0,22 = 2 232 s = 0,62 h`)*

**El cruce está en `Δ ≈ 14 s` para `ρ_max = 1,5`** (ahí `F_carrera(+2 pts) = 0,75 h ≈ 0,76 h). Es
decir: **la afirmación «el suelo de `F` lo pone la carrera» de la bitácora §11.4 es cierta con el `δ`
pesimista y a `Δ ≥ 14 s`, y falsa con el modelo de diseño a `Δ ≤ 12 s`**, donde el suelo lo pone el
*steering* y acortar `F_carrera` no compra nada. Solo con **revelación retardada** (R-FIN-14 (h)) la
carrera vuelve a ser el único suelo — y entonces, y solo entonces, `F = 21-28 min` es alcanzable.

### El peso de `I` — **medido: es despreciable**

`I` entra **solo** por el número de épocas de la unión (`EP_ANO = 365·86400/I`), no en `prev()`:

| `I` | épocas/año | épocas en 10 años | `F_carrera` 33 % (M1) | `F` mín. M1 | `F_carrera` 33 % (M5) | `F` mín. M5 |
|---:|---:|---:|---:|---:|---:|---:|
| **300 s** | 105 120 | 1 051 200 | 1 037 s | 1 273 s | 3 625 s | 7 065 s |
| 491 s | 64 228 | 642 281 | 1 028 s | 1 262 s | 3 588 s | 6 987 s |
| 602 s | 52 385 | 523 854 | 1 025 s | 1 257 s | 3 573 s | 6 955 s |
| **851 s** | 37 058 | 370 576 | 1 019 s | 1 249 s | 3 547 s | 6 900 s |
| 4 200 s | 7 509 | 75 086 | 990 s | 1 213 s | 3 428 s | 6 648 s |

**De `I = 851 s` a `I = 300 s` (2,84× más épocas) `F` sube 24 s en M1 y 165 s en M5: +1,9 % y
+2,4 %.** Todo el rango `I ∈ [300, 4 200]` (14×) mueve `F` un **4,7 %**. La razón es que el número de
épocas entra en logaritmo (`F ∝ ln N / ln(1/r)`) mientras `Δ` y `α` entran en `r`. **`I` no es una
palanca de `F` por la vía de la carrera**; lo es, y mucho, por la vía del *steering* (`4,545·I`), que
es la tabla de arriba.

### RECOMENDACIÓN

> **`F` provisional: 2 h. Mantener, sin cambios.** Es la `F` más corta con ≥ 2 puntos de colchón en
> los seis modelos, incluidos M5 y M6 (refutados por 9a y 9b, pero no medidos en red). Supone
> únicamente `Δ ≤ 16,6 s`, y no depende de que 9a ni 9b tengan razón. Cuesta 1,24 h sobre lo que el
> modelo de diseño pediría, y ese es el precio de no haber medido `Δ`.
>
> **`F` de producción: 1 h**, con **`ρ_max = 1,5`, `I = 602 s`** (`F` por steering 0,76 h ⇒ 1 h la
> cubre con holgura). Condiciones que hay que cumplir **antes** de bajarla, todas comprobables:
> 1. **`Δ` medido en red con carga y con verificación de PoT dentro, y `Δ_p99 ≤ 14,9 s`.** Es la
>    condición dura: a `Δ = 14,9 s` el colchón es exactamente 2 puntos; a 16 s cae a +0,1 p.
> 2. **R-FIN-8′ y R-FIN-13′ en vigor** (precondición del 46,9 % y de que M6 no aplique).
> 3. Objetivo de riesgo `10⁻¹⁰` a 10 años y ventaja `3k` **conservados** (B.1 y B.3: cambiarlos
>    ahorra 3,2 y 4,1 minutos respectivamente; no vale la pena tocarlos).
> 4. `k = 30` (B.2: bajarlo es la peor idea de las cinco palancas; `k = 20` ni siquiera es admisible).
>
> **`F` de 21-28 min: solo con revelación retardada** (R-FIN-14 (h)) **y `Δ ≤ 12 s`**. Sin ella, el
> término de *steering* impide bajar de 0,62-1,07 h aunque la carrera lo permita.
>
> **Suelo absoluto:** ninguna `F` conserva el 33 % por debajo de **0,28 h** ni siquiera en M1, y por
> debajo de **0,35 h** ninguna conserva los 2 puntos. `F = 20 min` (la fila de la bitácora §11.4)
> está **por debajo del suelo en todos los modelos**.

### La palanca que más pesa, en una tabla

| Palanca | Rango explorado | Movimiento de `F` a 33 % | Veredicto |
|---|---|---:|---|
| **`Δ`** | 4 → 16 s | **0,28 h → 0,98 h (×3,5)** | **domina todo** |
| Modelo de `δ` (B.4) | M1 → M5 | 0,28 h → 0,99 h (×3,5) | *es la misma palanca*: `δ` D8 ≡ `δ₀(16 s)` |
| `k` (modelo `δ_real`) | 30 → 40 | 0,63 h → 0,52 h (−17 %) | real pero el modelo está anulado |
| **Incertidumbre de la medida de `δ`** | IC95 a `k=30` | 0,85 h → 1,16 h (±9 min) | mayor que las dos siguientes juntas |
| Objetivo de riesgo | `10⁻¹²` → `10⁻⁶` | −4,1 min (M1) / −17,4 min (M5) | barata de conservar |
| Ventaja inicial | `3k` → `1,68k` | −3,2 min (M1) / −7,8 min (M5) | la más débil; **no tocar** |
| `I` (vía carrera) | 4 200 → 300 s | +4,7 % | despreciable |
| `I` (vía *steering*) | 851 → 491 s | **1,07 h → 0,62 h** | la segunda que más pesa |

---

## Revisión del trabajo heredado del primer intento

Los puntos **A, B.1 y B.2** los escribió un intento anterior de esta misma ronda, interrumpido y
commiteado. Antes de continuar se revisaron y **se re-ejecutaron los cuatro scripts heredados**:

| Script | Salida | Resultado |
|---|---|---|
| `r10b_a_control.py` | `salida_a.txt` | **IDÉNTICA** línea a línea (salvo el tiempo) |
| `r10b_b1_ventaja.py` | `salida_b1.txt` | **IDÉNTICA** |
| `r10b_b1_extremos.py` | `salida_b1_extremos.txt` | **IDÉNTICA** |
| `r10b_b2_k.py` | `salida_b2.txt` | **IDÉNTICA** |

**Lo que sí estaba recortado, y se ha completado:** la tabla (iii) de B.2 cerraba con una LAGUNA
declarada «por presupuesto» (ver «Errores propios» 1). Es la única. Ni A, ni B.1, ni las tablas (i) y
(ii) de B.2 recortaron filas, `α` ni modelos: A barre siete `α`, B.1 las cuatro ventajas del encargo
más dos de referencia y seis `α`, B.2 los cuatro `k` en los tres modelos. Cada número tiene su script
y su salida en el directorio.

## AUDITA_SCRIPTS

```
$ python3 research/scripts/AUDITA_SCRIPTS.py research/scripts/d9-ronda10b/
Scripts analizados: 11

======================================================================
Sospechas totales: 0
```

**Cada marca, leída: no hay ninguna.** Los 11 scripts (`r10b_lib`, `a_control`, `b1_ventaja`,
`b1_extremos`, `b2_k`, `b2b_delta_k`, `b2c_iii`, `b3_riesgo`, `b5_delta_red`, `c_entrega`,
`c2_delta35`) pasan T1, T2, T3, T3b y T4. En particular:

- **T1 (parámetro del atacante muerto):** 0. Toda función que recibe `a`/`alpha` lo usa; el criterio
  `α` está además comprobado a mano en cada punto, con tabla que se mueve con `α`.
- **T4 (< 12 semillas):** 0. El único script estocástico de la ronda es `r10b_b2b_delta_k.py`, con
  `SEMS = [1..12]` literales (12) y 1 920 corridas. **Corrección a la cabecera de este informe**,
  escrita en el primer intento: decía que `AUDITA` marcaría T4 «porque nada es estocástico»; al
  cerrar la LAGUNA de B.2(iii) la ronda sí tiene una medida estocástica, con 12 semillas e IC95, y
  no hay marca.
- Los otros diez scripts son evaluación numérica determinista de fórmulas cerradas (Skellam + ruina
  del jugador, y la beta incompleta de Grunspan): la regla de las 12 semillas no les aplica.

## Veredicto

| Punto | Etiqueta | Número que se lleva |
|---|---|---|
| **A** · control | **VERIFICADO** | 46,8784 % / 36,5432 %; `F = 2 h` → 44,57 % / 35,08 %; `F_carrera(33 %)` = 1 019 s / 3 547 s, idénticos al segundo por un camino distinto |
| **B.1** · ventaja inicial | **VERIFICADO** (palanca débil) · **REFUTADO** que convenga usar la medida | `3k → 1,68k` ahorra **191 s = 3,2 min**. Fuente del 0,56·3k: `d8-ronda8/salida_a6b.txt` L14-18. Extrapolada a 10 años la ventaja real sería ~2,1k, no 1,68k (PLAUSIBLE) |
| **B.2** · `k` | **VERIFICADO** | `k` **no tiene signo propio**: con `δ=0`, `k`↑ alarga `F` (+282 s de 20 a 40); con `δ_real(k)`, `k`↑ la acorta 17 %. `k = 20` **inadmisible** (`k_Poisson = 26`) |
| **B.2 (iii)** · LAGUNA | **CERRADA — VERIFICADO** | `δ` re-medido a `k ∈ {20,25,30,40}` (1 920 corridas, 12 semillas; `k=30` reproduce `salida_a1b.txt` 8/8): **`δ` no depende de `k`** (IC95 solapados). La incertidumbre de la medida vale **±9 min** de `F` |
| **B.3** · objetivo de riesgo | **VERIFICADO** | Bitcoin bajo el criterio de ZEROX pediría **46 h** a `q=33 %` (5,7 h a 10 %). Relajar `10⁻¹²→10⁻⁶` ahorra **4,1 min**. `ε` de Chia: **LAGUNA** (no publica). PDF de Nakamoto ausente: **LAGUNA parcial**, mitigada reproduciendo su tabla 8/8 |
| **B.4** · modelo de `δ` | **DEMOSTRADO** (la `δ` de D8 no va en la carrera) · **PLAUSIBLE** (que `δ₀` sea toda la `δ` a `Δ ≥ 16 s`) | Diseñar con **`δ = δ₀(Δ)`**, `Δ_diseño = 12 s`, esfuerzo 16 s. Y `δ` D8 (0,2867) ≡ `δ₀(16 s)` (0,2858): **son el mismo número** |
| **B.5** · `Δ` | **VERIFICADO** | `F` **no compra `Δ`**: de 1 h a 2 h son **1,9 s**; techo duro en `Δ = 22,7 s` (`r = 1`). Control 5/5 contra `auditoria-8a.md` §4 |
| **C** · entrega | **VERIFICADO** | `F` mínima (+2 pts): **0,35 h** (M1/M2) · **0,46 h** (M3) · **1,55 h** (M4) · **1,92 h** (M5) · 0,96 h (M6). `I` por la carrera pesa **+4,7 %** en todo el rango. Por debajo de `Δ ≈ 14 s` **el suelo lo pone el *steering*, no la carrera** |
| **Recomendación** | — | **`F` provisional 2 h (mantener)**; **`F` producción 1 h** condicionada a `Δ_p99 ≤ 14,9 s` medido; **21-28 min solo con revelación retardada** |

## Errores propios

1. **LAGUNA declarada por falta de tiempo** (B.2 (iii), primer intento): «No se hizo por presupuesto».
   La regla 3 del método lo prohíbe explícitamente. **Corregido:** medido en 69 s con 1 920 corridas y
   32 procesos. El resultado no cambia la tabla (el `δ` no depende de `k`), pero **eso había que
   medirlo, no suponerlo**, y el IC95 que la medida trae resultó ser mayor que dos de las cinco
   palancas del encargo.
2. **Cabecera equivocada:** el primer intento escribió que la ronda no tenía nada estocástico y que
   `AUDITA` marcaría T4. Al cerrar (iii) sí lo tiene, con 12 semillas, y `AUDITA` da 0 sospechas.
3. **`f_carrera` usada para un criterio por evento** (B.3 §4): pedí `F` con `ε = 10⁻³` *por
   transacción* pasándole `obj = 10⁻³·N_épocas > 1`, que la unión satura en 1 y devolvió 0 s en las
   cuatro filas. **Corregido** con `f_evento` (`r10b_b3_riesgo.py:60-70`), que exige `prev < ε` sin
   unión: 7,7-37 min, no 0.
4. **Barrido de `Δ` por encima de `r = 1`** (B.5, primera ejecución): imprimí 37,59 h para `Δ = 24 s`
   y 2,93 h para `Δ = 32 s` —no monótono— y una frontera de 48,92 %. Es el artefacto del recorte a
   `r^700` que D8 ya había declarado, y `delta_max` devolvía 32,0 s para `F ≥ 3 h` por la misma causa.
   **Corregido:** el script calcula `Δ` donde `r = 1` (22,7 s al 33 %; 20,8 s al 35 %) y marca esas
   filas como **cota vacua** en vez de imprimir números.
5. **Encuadre heredado y no comprobado hasta C:** trabajé los puntos B.1-B.5 dando por buena la frase
   del encargo «el suelo de `F` lo pone la carrera». Es cierta solo con el `δ` pesimista o con
   `Δ ≥ 14 s`; con el modelo que yo mismo recomiendo en B.4 el suelo lo pone el término de *steering*
   `I/(W/κ−1)`, y eso cambia la lectura de tres de las cinco palancas (dejan de comprar nada). Lo vi
   al construir la tabla de C, no antes.
6. **Un `.pyc` commiteado.** El commit de C se llevó `__pycache__/r10b_b5_delta_red.cpython-313.pyc`
   (y el índice arrastraba además el `r10b_lib.cpython-313.pyc` del primer intento). Es exactamente
   el fallo que 9a tuvo que corregir en su ronda. **Sacados del índice** en el commit siguiente.

## Lagunas que quedan, con lo que haría falta para cerrarlas

1. **`Δ` no está medido.** Es la única palanca que decide, y la única que no se puede medir sin
   `zx-node` corriendo el DAG. Hace falta: decenas de instancias, latencias inyectadas, carga, la
   verificación real del PoT (96,1 ms/slot) dentro del camino, y la cola **p99**, no la media.
2. **Composición de `δ₀(Δ)` con la `δ` parásita a `Δ ≥ 16 s`.** El teorema de la ráfaga de 9a vale
   mientras `2Δλ ≪ k`, y la propia 9a midió `W_pub/H = 0,936 < 1` a `Δ = 20 s`. Haría falta repetir
   el A2 de 9a (reparto `α_p/α_f`, 7 200 corridas) con `Δ ∈ {12, 16, 20}` en vez de 4 s.
3. **Fuentes primarias ausentes:** `bitcoin.pdf` (Nakamoto), Grunspan & Pérez-Marco (1702.02867) y
   Rosenfeld (1402.2009) no están en `research/fuentes/`. Mitigado reproduciendo sus dos tablas
   (8/8 y 10/10) desde la forma cerrada; se cierra descargándolos.
4. **El `ε` de Chia no existe públicamente.** Solo hay profundidades recomendadas (6 y 32 bloques)
   y tres umbrales distintos (54 %, 42,7 %, 40,5 %) que su propia documentación no reconcilia
   (`chia-documentacion-oficial.md:325-334`).
