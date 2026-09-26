# CORRECCIÓN DS6-A — convención del exponente y cálculo empírico directo de B(ε)

**Fecha:** 2026-09-26. **Director:** Claude. Mismo ejecutor, zona `deepseek/DS6/` y límites.

## Qué evidencia falló

1. **Convención.** `src/analisis.jl` estima `dist_alpha_hat = n / Σ ln(x/xmin)` y prueba el ajuste con
   `cdf = 1 − (xmin/x)^α`: es el exponente de la **cola** (convención de Wikipedia). La fórmula de DS-3
   que se aplica después (`DS3/src/modelo.jl`, `masa_prob`: `b = 2 − α`, y «`α ≤ 2`: `E[f]` diverge»)
   usa el exponente de la **densidad** (`p(f) ∝ f^−α`, media finita solo si `α > 2`). Densidad = cola + 1.
   Con la convención correcta, la cola óptima es `α_dens ≈ 1,856 [1,81; 1,91]` y, con `ε = 0,01`,
   `T_v = 3.600`, `f_min = 10⁻⁸`, `F_max = 1`: **`B(ε) ≈ 0,095 [0,060; 0,151]`** (cálculo del director),
   no `4,4·10⁻⁷`. El global pasa a `α_dens ≈ 1,111` y `B ≈ 1,1·10⁻⁵`. La afirmación de que DS-3 usa la
   convención de Wikipedia es incorrecta.
2. **Método.** `B(ε)` es la fracción del espacio en claves con fracción de red `f < x = ε/(λ·T_v)`,
   ≈ 2,8·10⁻⁶ con los valores de DS-3: depende de las claves **pequeñas**, justo las que el ajuste de la
   cola (el 37 % mayor) no describe y el ajuste global describe mal (KS 0,397).

## Qué se espera cambiar

1. Corrige la conversión y recalcula la tabla con `α_dens = α_cola + 1` (punto e intervalo).
2. **Calcula `B(ε)` empíricamente, sin ajustar ninguna ley:** con el espacio de cada granjero de
   `crudo/farmers-raw.csv` y un denominador de red declarado (el *netspace* de Chia en la fecha de
   descarga, con fuente; y, como sensibilidad, el espacio del propio pool), la fracción del espacio del
   pool en granjeros con `f < x` para `T_v ∈ {3.600; 100.000}` y `ε ∈ {0,001; 0,01; 0,1}`. Intervalo por
   *bootstrap* sobre granjeros.
3. Compara con el umbral de DS-3 `1 − 2·α_atacante` para `α_atacante ∈ {0,20; 0,25; 0,33; 0,40}` y di,
   para cada combinación, si la grieta queda abierta o cerrada **y con qué margen**.
4. Declara el sesgo de que un pool no es la red (los granjeros en solitario no aparecen) y en qué
   sentido mueve `B(ε)`.

Añade «Corrección A» al `INFORME.md`, sin borrar lo anterior. Presupuesto: 45 min.
