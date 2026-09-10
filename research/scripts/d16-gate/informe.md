# Gate de igual ε — ¿la confirmación adaptativa baja el baseline A IGUAL riesgo?

**2026-09-10 · ronda d16.** Instrumento: `gate_igual_eps.py` (salida en `salida_gate.txt`).
Modelo: el del proyecto, `prev()` de `research/scripts/d9-ronda9a/r9a_a3_frontera.py:37-49`
(carrera de Skellam con ventaja inicial `offset` en bloques). `k_ref` de
`research/scripts/d14-dagknight/salida_zerox2_crudo.txt`.

## 0 · Control positivo

| Número publicado | Instrumento | Razón |
|---|---|---|
| D.6: 871 s a `ε = 1e-12` (`α=0,33`, offset 3k) | 9,749e-13 | 0,975 |
| Hoja: 1 800 s a 7,1e-36 | 7,071e-36 | 0,996 |
| 600 s a `α=0,33` | 1,516e-06 | 1,000 |

**Discrepancia de la hoja:** «riesgo de reversión a 600 s = 4,3·10⁻¹⁰» corresponde a `α=0,30`
(2,93e-10), no a `α=0,33` (1,52e-6). La fila de la hoja no fija `α`.

## 1 · Tabla del gate (misma ε en las tres columnas)

| α | ε | baseline P | adapt P (media) | adapt P (máx) | adapt G (ruina) | ratio P | ratio G |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 0,10 | 1e-6 | 190,5 | 37,6 | 84,4 | 7,8 | 5,06 | 24,50 |
| 0,25 | 1e-6 | 356,3 | 92,1 | 119,2 | 17,3 | 3,87 | 20,56 |
| **0,33** | **1e-6** | **608,4** | **199,6** | 228,9 | 29,9 | **3,05** | 20,38 |
| **0,33** | **1e-12** | **870,5** | **425,4** | 455,7 | 59,7 | **2,05** | 14,58 |
| 0,40 | 1e-6 | 1 320,6 | 586,1 | 611,6 | 58,3 | 2,25 | 22,64 |
| 0,40 | 1e-12 | 2 044,3 | 1 252,1 | 1 278,1 | 115,0 | 1,63 | 17,78 |

- **baseline P** = `prev(α,1,t,3·30,1) = ε` (el modelo con el que el proyecto publicó D.6).
- **adapt P** = el MISMO modelo con el offset reducido a `3·k_ref` (≈0,66 a `α=0,33`).
- **adapt G** = `M = max(3k_ref, ⌈ln ε / ln(α/(1−α))⌉)`, la fórmula de la adaptación propia.

## 2 · El hallazgo decisivo: la fórmula de la adaptación mezcla dos modelos

Comprobación con el instrumento **original** en los cruces:

| Caso | `prev` calculado | Objetivo | Razón |
|---|---:|---:|---:|
| baseline `ε=1e-6`, t=608,4 s | 9,996e-07 | 1e-06 | 1,00 |
| adapt P `ε=1e-6`, t=199,6 s | 1,000e-06 | 1e-06 | 1,00 |
| baseline `ε=1e-12`, t=870,5 s | 1,002e-12 | 1e-12 | 1,00 |
| adapt P `ε=1e-12`, t=425,4 s | 1,004e-12 | 1e-12 | 1,00 |
| **adapt G `ε=1e-6`, t=29,9 s** | **5,514e-02** | 1e-06 | **55 141** |

**La fórmula `M = max(3k, m(α,ε))` no es válida bajo el modelo de riesgo del proyecto.** A los
29,9 s que predice, el riesgo real de reversión es **5,5 %**, no 10⁻⁶: se equivoca por un factor
55 141. Las cifras de «4–17 s» y «30–60 s» salen de esa fórmula y **no son publicables**.

La comparación honesta, a igual ε y bajo el mismo modelo en las dos columnas, es **adapt P**:
**3,05×** a `ε=1e-6` y **2,05×** a `ε=1e-12` para `α=0,33`.

## 3 · Criterio de muerte

| Comprobación | Mínimo | Umbral | Veredicto |
|---|---:|---:|---|
| ratio P a `ε=1e-6` | 2,25 (`α=0,40`) | ≥2 | **PASA** |
| ratio P a `ε=1e-12` | 1,63 (`α=0,40`) | ≥1,5 | **PASA** |

**Aritmética: PASA, con una ganancia de 2–3×, no de 20×.**

## 4 · Condición de seguridad (lo que la aritmética no decide)

La reducción del offset de `3k=90` a `3·k_ref≈0,66` solo es legítima si `k_ref` captura la
cadena oculta del atacante. **D8b demostró que no:** con retención + cadena privada el ataque
captura **12/12** a `Δ=16` (`d14-dagknight/informe3.md`, `d15-avalanche/audita-d8c.md`); a `Δ≤4`
la manipulación es débil. Y las medidas de `k_ref` usaron peso unitario, no `blue_work` real.

**El gate pasa CONDICIONADO a:**
1. cerrar el ataque de retención + cadena privada;
2. repetir con `blue_work` real;
3. medir `Δ` y que su percentil normativo quede donde `k_ref` es seguro.

Si `Δ ≥ 16` y el ataque sigue abierto, el offset vuelve a ~3k y **A no compra nada**: la decisión
queda en baseline + C.

## Veredicto

| Punto | Conclusión | Etiqueta | Número |
|---|---|---|---|
| Control positivo | El instrumento reproduce los números publicados | VERIFICADO | razones 0,975–1,000 |
| Aritmética del gate | A baja el baseline 2–3× a igual ε bajo el modelo del proyecto | VERIFICADO | 3,05× / 2,05× (`α=0,33`) |
| Fórmula de la adaptación | La `m` de ruina no vale bajo el modelo del proyecto | **REFUTADO** | riesgo real 5,5 % donde dice 1e-6 |
| Seguridad | La reducción del offset no está justificada con retención | **ABIERTA** | captura 12/12 a `Δ=16` |
| Decisión | A sobrevive solo condicionada; las cifras publicables son ~200 s / ~425 s, no 4–17 s | PLAUSIBLE condicionado | baseline 608 s / 870 s |

## Errores propios

1. La primera versión del script colgaba por `skellam.pmf` con medias grandes en las llamadas de
   brentq; reescrito con tabla vectorizada y control positivo contra el instrumento original.
2. La ronda 14 presentó como latencia de la regla la fórmula `m` de ruina sin comprobarla contra
   el instrumento de riesgo del proyecto. Este gate lo corrige: el error era de 55 141×.

---

## Auditoría D9 (`audita-d9-gate.md`)

**Correcciones que cambian el veredicto:**

1. **El 4,3·10⁻¹⁰ a 600 s no es `α=0,30`.** Es **`α=0,25` con `λ_real=1,381/1,364` y
   `δ_real=0,276/0,267`** (offset 3k) → 4,307e-10 / 4,339e-10 (`dag-poas-delta-real.md` §4;
   r11a A.1). El 2,93e-10 de este informe no redondea a 4,3e-10. La fila de la hoja sí tiene
   un modelo más fino que el del gate.
2. **El criterio de muerte no pasa con el peor `k_ref` de la misma ronda.** Con `retro500`
   (Δ=20) `α=0,40` da **1,66 / 1,39 → NO PASA**; con el máximo del propio fichero, el mínimo es
   **2,16 / 1,60** (margen del 6,7 % a 1e-12), no 2,25 / 1,63.
3. **El error de la fórmula `m` está subestimado:** con el `k_ref` máximo de `α=0,33`, a 29,9 s
   el riesgo es **0,2564 (2,56·10⁵×)**, no 5,514e-2 (55 141×).
4. **Break-even del offset** (hasta dónde puede subir sin matar la ganancia): `α=0,40` → 8,0/11,8;
   `α=0,33` → 20,6/29,0; `α=0,25` → 27,0/37,7; `α=0,10` → 32,9/45,0 bloques.

**No demostrado:** que el `k` del *Freeloader Bound* (`phantom-ghostdag.txt:1235-1238`) sea el
rank medido `k_ref`; la reducción del offset con retención (12/12 a Δ=16) y con `blue_work` real;
el origen de los umbrales 2× y 1,5×.

**Veredicto corregido:**

| Punto | Conclusión | Etiqueta |
|---|---|---|
| La fórmula `M = max(3k, m)` como regla de espera | Inconsistente con `prev`; error 2,56·10⁵× con el `k_ref` máximo | **REFUTADA** |
| Variante con la espera fijada por `prev` (offset reducido) | 3,05× / 2,05× con la media; 2,16× / 1,60× con el máximo; 1,66× / 1,39× con el peor de la ronda | **PLAUSIBLE, frágil** |
| Seguridad de la reducción del offset | Abierta y contradicha a Δ≥16 (retención 12/12) | **ABIERTA** |

**Conclusión revisada:** A **como está diseñada está refutada**. Lo que sobrevive es una variante
(espera fijada por el modelo del proyecto con offset reducido) con una ganancia de 2–3× que
**falla el criterio de muerte con el peor `k_ref` medido** y cuya condición de seguridad está
abierta. No es base para escribir consenso: es, como máximo, una línea de investigación.

