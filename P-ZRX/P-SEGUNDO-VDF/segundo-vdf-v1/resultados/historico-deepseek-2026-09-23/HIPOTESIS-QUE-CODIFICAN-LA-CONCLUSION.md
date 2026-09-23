# Hipótesis que codifican la conclusión — SDV-v1

Separa las **identidades** (aritmética del modelo), las **premisas** que necesitan evidencia y
las **hipótesis nuevas de este instrumento**, y dice qué conclusión cae con cada una. Es el
contrato de lectura de `INFORME.md`.

## A · Identidades (no requieren evidencia)

1. **Recursión de barrera** (REV-v1.0, identidad 1; reimplementada aquí):
   `τ_j = máx(τ_{j-1} + (t_j − 1 − t_{j-1})/ρ, e_j) + 1/ρ`, con `t_j = s_j + L`, `s_j = T_j + off_j`,
   `T_j = j·I`. **Verificada** contra la forma cerrada max-plus en `Rational{BigInt}`:
   192 casos (con/sin `(h)`, espera/especula, cruce con coste/gratis, semilla presente/futura),
   discrepancia máxima `Δτ = 0`.
2. **`V(t) = Φ_a(t) − Φ_h(t)`** es el objeto `A = a(t) − h(t)` de ADL-v1.0 bajo su frontera
   `a = mín(Φ_a, Γ) − D`. El máximo y el mínimo exactos están en el conjunto finito de puntos de
   ruptura. **Verificado** (mismos tests).
3. **`ρ* = (Lrev + I)/(I + W_dec)`** es el umbral de *steering* de la ronda 10a, no una ventana.
4. **Calibración exacta**: `ρ* ≥ ρ_max ⇔ I ≤ (Lrev − ρ_max·W_dec)/(ρ_max − 1)` para `ρ_max > 1`;
   con `I` entero, `I_max = ⌊frontera⌋`. **Derivada aquí** con `Lrev = L − S_max`.
5. **Puntualidad honesta discreta** (peor caso sobre `off_j ∈ [0, S_max)`):
   `Lrev ≤ L − W_dec − D − 1`. **Verificada** por el contador `n_stall` del simulador.
6. **Cotas superiores de `ρ_max`** que impone la propia calibración:
   `I ≥ ρ_max·W_dec ⇒ ρ_max ≤ √(Lrev/W_dec)`; `I > S_max ⇒ ρ_max < (Lrev+S_max+1)/(W_dec+S_max+1)`.
   **Derivadas**; a `L = 7200`, `S_max = 150`, `W_dec = 20` la que manda es `√352,5 = 18,775`.

## B · Premisas que necesitan evidencia (heredadas)

1. **`ρ_max` real por plataforma.** El techo 1,5–2,5× es **estimación** de
   `research/pot-aes-asic-chacha.md:40-42` (estudio de Supranational no localizado). Todo el
   informe da `ρ` como símbolo. Si un ASIC superara `ρ_max = 18,775`, la calibración (h.6) deja de
   tener solución con `L = 7200` y `W_dec = 20`.
2. **Adversario monolineal o paralelo.** REV-v1.0 modela el coste `Lrev/ρ` **en el camino crítico**
   del atacante. La hipótesis nueva H3 (abajo) separa los dos regímenes; cuál usa un adversario
   real no está medido.
3. **`W_dec` y `α` en red real.** `W_dec ≤ 45 s` es máximo observado, no cota universal; `α` es
   entrada.
4. **`D`, `N(s)`, `I`, `Lrev`, `F`, `L_suelo`** siguen `<<PENDIENTE>>` (`MIGRACION.md:123`,
   `SPEC.md:2067/2087`). Este instrumento no los fija.
5. **Costes unitarios** `prove`/`verify` son medidas de la primitiva de **un slot** en un
   Ryzen 9 9950X3D, no de la segunda cadena.
6. **`Δ` simulada, no medida** (`TAREAS.md` §2.9(a)6); no hay red en este instrumento.
7. **Condición inicial de REV**: ambas fronteras parten a nivel en `t = 0`. Es una convención, no
   física; genera un transitorio de primera época que el informe cuantifica (control C4/C4b).

## C · Hipótesis nuevas de este instrumento, y qué cae con cada una

- **H1 (calibración).** Que la calibración publicada use `L` donde el criterio operativo usa
  `Lrev = L − S_max`. **Medido**: la fila histórica da `ρ* = 2,4686 < 2,5` (con el redondeo
  publicado a 4 767) y **no cumple su propio criterio**; la frontera correcta es `I ≤ 4 666,67`
  (`I_max = 4 666`), 100 slots por debajo. Si H1 cayera, el defecto 2 seguiría en pie.
- **H2 (escenarios mezclados).** Que la ventana publicada use `I = 851` y el coste `I ≈ 4 767`.
  **Medido**: es así. Al unificar, `ΔV/V_sin` pasa de 36,69 % a 28,27 % **con** el coste
  calibrado (0,2414 núcleos y 3 líneas). Si H2 cayera, el par beneficio–coste publicado sería
  válido y no habría nada que recalcular.
- **H3 (régimen de líneas).** Que un adversario con `⌈Lrev/I⌉` líneas AES dedicadas precomputa la
  revelación y **anula** la reducción. **Medido**: reducción 0,0000 en los dos escenarios;
  precio 9 líneas (`I = 851`) o **2 líneas** (`I = 4 666`), frente a las 10/3 del timekeeper.
  Si H3 cayera (el adversario fuera estrictamente monolineal), el beneficio sobreviviría con el
  factor medido.
- **H4 (semilla).** Que las dos semillas causales (C-FLU-12 `pot_output(s_j+D)` y h.1
  `salida(f, slot(I_j))`) dan la **misma** ventana. **Medido**: diferencia 0,0000 en los tres
  patrones de ancla (ajena, propia, mixta α=0,33). Si H4 cayera, la elección de semilla sería una
  palanca de seguridad.
- **H5 (primitiva).** Que la cadena `Lrev·N(slot)` **no es expresable** con la API pública de
  `zx-pot` (`NonZeroU32`, clave derivada del argumento). **Medido**: `Lrev ≤ 20` slots en una
  llamada con `N` nominal; `T = 1,456·10¹² = 339,1× u32::MAX` con `Lrev = 7050`. Si H5 cayera
  (se expusiera `aes::create`/`verify_sequential`), el coste de la segunda cadena sería medible y
  la decisión de adopción podría cerrarse.

## D · Lo que el instrumento **no** codifica

- No hay AES, ni `blake3`, ni red, ni partición de flujo, ni GHOSTDAG, ni reorganizaciones.
- No hay economía: `V` no se traduce a probabilidad de doble gasto ni a finalidad.
- No hay exclusividad de espacio: un segundo reloj paralelo es un **control negativo**, no una
  prueba de que el doble farmeo esté resuelto.
- No se modelan rachas de ancla propia como régimen estacionario: en el patrón «todas propias» `V`
  crece sin cota (`770 217` slots a `I = 851`), lo que confirma que la cota debe ser un **cuantil
  con su tasa de excedencia**, no un `sup`.
