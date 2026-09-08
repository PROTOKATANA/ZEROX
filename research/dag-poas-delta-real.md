# El `δ` real bajo el sesgo del retarget — y sus tres consecuencias

**Fecha:** 2026-09-08 (madrugada, modo autónomo) · **Origen:** LAGUNA 1 de `dag-poas-empalme-peso.md`
§4 y ronda 3 §7 (*«sostenibilidad del sesgo del Lema 9: PLAUSIBLE, NO DEMOSTRADO»*).
**Scripts:** `research/scripts/verif_retarget_sesgo.py`, `verif_delta_real.py`.

> **Todos los umbrales de las rondas 7-8 usaban `δ = 2Dλ/(k+2Dλ)` con `λ = 1/s`. Pero el retarget
> mide azules, y el Lema 9 le esconde una fracción `δ` del crecimiento: para que el observador vea
> `λ_obj = 1/s`, la tasa real se infla. A `k = 25`: `λ_real = 1,47/s` y `δ_real = 0,320`.** Es el
> modelo de la ronda 3 (§7), que la propia ronda 3 aplicó para pasar de `k=18` a `k=24` y que nadie
> propagó a los umbrales.

---

## 1 · El modelo (ronda 3 §7, sin cambios)

```
λ_obs = λ · k/(k + 2Dλ)                        (el Lema 9 le quita (1−δ) al observador)
controlador: λ_obs → λ_obj = 1/q = 1/s          ⇒   λ_real = k·λ_obj / (k − 2D·λ_obj)
existencia:  λ_obj < k/(2D)                     (si no, SR → SR_MAX)
δ_real = 2D·λ_real / (k + 2D·λ_real)
punto fijo:  k ≥ k_Poisson(2D·λ_real, 10⁻³)
```

| `k` | techo `k/2D` | `λ_real` | inflación | `δ` nominal | **`δ_real`** | `k_Poisson` | autoconsistente |
|---:|---:|---:|---:|---:|---:|---:|---|
| 18 | 2,25 | 1,800 | ×1,80 | 0,308 | 0,444 | 27 | **no** (la ronda 3 ya lo vio) |
| 24 | 3,00 | 1,500 | ×1,50 | 0,250 | 0,333 | 24 | sí |
| **25** | 3,12 | **1,471** | **×1,47** | 0,242 | **0,320** | 24 | sí |
| **30** | 3,75 | **1,364** | **×1,36** | 0,211 | **0,267** | 22 | sí |
| 40 | 5,00 | 1,250 | ×1,25 | 0,167 | 0,200 | 21 | sí |

**Matiz de cota:** el sesgo `δ` del Lema 9 es el **caso peor** del paper, y que sea **sostenible** en
todo instante por un atacante con `α < 1/2` sigue siendo **PLAUSIBLE, NO DEMOSTRADO** (ronda 3, L222).
`δ_real` es por tanto el valor **bajo ataque sostenido**; `δ` nominal, el valor sin ataque. **Hay que
publicar los dos, y diseñar con el primero.**

## 2 · Consecuencia (a): el umbral de **orden** baja

`α* = (1−δ)/(φ₅₀₀ + 1−δ)`, `φ₅₀₀ = 1,1023`:

| | `k = 25` | `k = 30` |
|---|---:|---:|
| `δ` nominal | 40,7 % | 41,7 % |
| **`δ_real`** | **38,2 %** | **40,0 %** |

## 3 · Consecuencia (b): el umbral de **flujo único** baja

Base de la carrera `r = α/((1−α)(1−δ))`; unión sobre 10 años (`F = 3,2 h`, `I = 2 490 s`):

| `α` | `r` nominal | P(partición, 10 a) nominal | **`r` real** | **P(partición, 10 a) real** |
|---:|---:|---:|---:|---:|
| 0,25 | 0,440 | 3·10⁻²⁴⁵ | 0,490 | 2·10⁻²¹² |
| 0,33 | 0,650 | 2·10⁻⁸⁵ | 0,724 | 3·10⁻⁶⁶ |
| **0,35** | 0,711 | 3·10⁻⁵² | **0,792** | **1·10⁻³²** |
| 0,38 | 0,809 | 3·10⁻¹⁷ | 0,901 | **7·10⁻³** |
| 0,40 | 0,880 | 2,6·10⁻³ | 0,980 | **1** |

`r = 1` en `α = (1−δ)/(2−δ)`: **43,1 % nominal → 40,5 % real** (`k=25`); con `k=30`, 42,3 %.
**La región de operación con `P(partición) < 10⁻¹⁰` en 10 años sigue siendo `α ≲ 0,35`**, pero
`0,38` pasa de despreciable a **7·10⁻³**.

## 4 · Consecuencia (c): el óptimo de `k` se mueve a **30**

Óptimo de la reversión a 600 s con `(λ_real(k), δ_real(k))` **autoconsistentes**, `α = 0,25`:

| `k` | 20 | 22 | 24 | 25 | 26 | 28 | **30** | 35 | 40 |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| `λ_real` | 1,667 | 1,571 | 1,500 | 1,471 | 1,444 | 1,400 | **1,364** | 1,296 | 1,250 |
| `δ_real` | 0,400 | 0,364 | 0,333 | 0,320 | 0,308 | 0,286 | **0,267** | 0,229 | 0,200 |
| reversión | 6,1·10⁻⁸ | 6,7·10⁻⁹ | 1,6·10⁻⁹ | 9,8·10⁻¹⁰ | 6,9·10⁻¹⁰ | 4,6·10⁻¹⁰ | **4,3·10⁻¹⁰** | 1,0·10⁻⁹ | 5,8·10⁻⁹ |

(La reversión a 600 s **mejora** respecto al modelo nominal —`6,6·10⁻⁸`— porque `λ_real > 1`: hay
más bloques por segundo y 600 s son más profundos en bloques. Es coherente, no un error.)

**`k = 25` no era el óptimo: era el óptimo del modelo con el `δ` equivocado.** De las «dos vías
independientes» de `dag-poas-ancla-de-orden.md` §1.1, una usaba `δ = 0,2424` y la otra (ronda 3)
pedía `k ≥ 24` pero no fijaba el valor. Con el modelo realista, **la reversión pide `k = 30`, el
punto fijo del retarget lo admite (`k_Poisson = 22 ≤ 30`), y los dos umbrales mejoran ~2 puntos.**

**DECISIÓN (autónoma, con el mandato de Katana): `k = 30`.** Consecuencias en R-FIN-12:
`max_block_parents = max(10, ⌊k/2⌋) = 15`, `mergeset_size_limit = max(180, 2k) = 180` (sin cambio).
La ventaja de *freeloading* `3k` sube de 75 a 90; ya está dentro de la optimización de arriba.

## 5 · Los dos umbrales del sistema, versión honesta

| | con `k = 30`, **`δ_real`** | referencia |
|---|---:|---|
| Umbral de **orden** (reversión de transacciones) | **40,0 %** | Chia desplegado 40,5 %; Bitcoin 50 % |
| Umbral de **flujo único** (10 años, `P < 10⁻¹⁰`) | **~35 %** | el más restrictivo; es el que se publica |

## 6 · LAGUNA que queda, con etiqueta

Que el sesgo máximo del Lema 9 sea **sostenible** por un atacante real: el paper lo da como caso
peor; nadie ha construido la estrategia que lo sostiene con `α < 1/2`. Si **no** es sostenible, los
números nominales son los correctos y `k = 25` bastaba. Diseñar con `δ_real` es la elección
conservadora, y cuesta ~2 puntos de umbral que `k = 30` recupera.
