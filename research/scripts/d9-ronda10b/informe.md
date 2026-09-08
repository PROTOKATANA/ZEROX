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
