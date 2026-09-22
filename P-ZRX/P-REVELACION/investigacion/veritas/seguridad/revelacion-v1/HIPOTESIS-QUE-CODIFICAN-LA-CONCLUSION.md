# Hipótesis que codifican la conclusión — REV-v1.0

Este fichero separa las **identidades** del instrumento de las **premisas** que aún necesitan
evidencia, y dice qué conclusión cae si cada una cae. Es el contrato de lectura del `INFORME.md`.

## Identidades (aritmética del modelo; no requieren evidencia)

1. **Recursión de barrera.** Con `τ_j` el instante en que la frontera de PoT del atacante completa
   el slot `t_j`:

   ```text
   τ_j = máx( τ_{j-1} + (t_j − 1 − t_{j-1})/ρ , e_j ) + 1/ρ        (cruce con coste)
   τ_j = máx( τ_{j-1} + (t_j − 1 − t_{j-1})/ρ , e_j )              (cruce gratis, 10a)
   ```

   y `e_j` = instante en que dispone de `entropía_j`. **Verificado por construcción** y contra el
   oráculo por slot en `Rational{BigInt}` (`test/runtests.jl` §1: 280 casos, diferencia exacta 0).

2. **`V(t) = Φ_a(t) − Φ_h(t)`** es exactamente el objeto `A = a(t) − h(t)` de ADL-v1.0 cuando las
   dos fronteras están por debajo de `Γ`: `a = mín(Φ_a,Γ) − D`, `h = mín(Φ_h,Γ) − D`. No hay dos
   definiciones de `A` en juego; lo que cambia es **qué es `Φ_a`**.

3. **Ancla propia sin espera.** Si el ancla es suya, `e_j` no espera a la decisión de la red y no
   necesita que el bloque exista: la semilla es `pot_output(I_j) = salida(f, s_j + D)`
   (`C-POT-05`), que conoce en cuanto su frontera alcanzó `slot s_j + D`. **Verificado** contra el
   oráculo, que usa la tabla de tiempos por slot.

4. **Propiedad del máximo.** `V` es lineal a trozos entre completaciones y topes de barrera, luego
   el máximo y el mínimo exactos están en ese conjunto finito. **Verificado** (mismo test).

## Premisas que necesitan evidencia

5. **La frontera honesta va `D` por delante de su frontera de bloques** (`lead_h = D`).
   Es la premisa 6 de ADL (`…/adelanto-v1/HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md:43-51`).
   **Aquí se puede comprobar, no suponer:** `C-POT-05` (`SPEC.md:1403-1417`) exige que el bloque del
   slot `s` lleve `salida(f, s+D)` y que su justificación cubra `(slot(sp)+D, s+D]`, luego quien lo
   produce **ha alcanzado `s + D`**. El simulador implementa las dos lecturas (`lead_h ∈ {D, 0}`) y
   publica las dos columnas (`F1.txt`). **Lo que decide:** `D` resta exactamente `D` slots de `V`
   (medido en `F2.txt`: diferencia 4,000 con `D = 4`). **No decide** ninguna otra cosa: no mueve el
   *steering* ni `ρ*`.
   **Corolario que sí es nuevo:** con `lead_h = D` la condición de puntualidad del honesto se
   aprieta a `Lrev ≤ L − W_dec − D` (y discreta, `−1`), no `Lrev ≤ L − W_dec`. Ver premisa 8.

6. **El adversario especula sobre todos los candidatos (ronda 10a) o espera la decisión (9c).**
   No hay medición de red que diga cuál usa un atacante real. El simulador implementa **las dos**
   (`espera ∈ {true,false}`). **Lo que decide:** `+W_dec` exactos de ventana (`F1.txt`: el que
   especula gana `W_dec = 20` clavados sobre el que espera). `A_core` es la forma del que espera.

7. **`Γ(t) = t + I + L − W_dec`** (horizonte de determinación del flujo). **No se usa** en este
   instrumento: la recursión por eventos deriva la frontera de las barreras y de los anclas, y
   `Γ` sólo entra como término de comparación (la forma de ADL). Por eso el resultado de aquí no
   hereda ese modelo.

8. **Puntualidad del honesto con (h).** La condición **continua** es `Lrev ≤ L − W_dec − lead_h`; la
   **discreta** del simulador es `Lrev ≤ L − W_dec − lead_h + off_j − 1` (el slot `t_j` hay que
   computarlo después de tener la entropía). Con `off_j = 0` y `Lrev = L − W_dec − D` el honesto se
   estanca **1 slot por época** y la invariante `n_stall_h` lo delata. **Medido**: `test/runtests.jl`
   §2 comprueba las dos ramas. Recomendación (h.1b) `Lrev = L − S_max` cumple la discreta con
   holgura mientras `S_max ≥ W_dec + D + 1`.

9. **Uniformidad de los sorteos.** `off_j` (geometric, λ = 0,2, truncada en `S_max`) y `propia_j`
   (Bernoulli `α`) son las dos fuentes de aleatoriedad; se publican semilla maestra y derivación por
   réplica (`StableRNG(semilla + id)`). **`α` es entrada, no resultado.**

10. **Los costes unitarios son entradas medidas, no resultados.** `prove = 1,561 s/slot` y
    `verify = 96,1 ms/slot` (`research/dag-poas-ancla-de-orden.md:342`, Ryzen 9 9950X3D). No se
    vuelve a medir AES.

## Lo que el instrumento **no** codifica

- **El VDF de revelación no se implementa.** Se modela su *coste temporal* `Lrev/ρ` en la línea
  paralela; no hay AES, ni `blake3`, ni `N(s)`. Todo lo que dice el informe sobre (h) es sobre la
  aritmética del adelanto, no sobre una implementación.
- **No hay red**: ni `Δ`, ni GHOSTDAG, ni `π_DAG`, ni reorganizaciones, ni competición entre
  soluciones del mismo slot. `W_dec` y `α` entran como símbolos.
- **No se modela la partición de flujo**: sólo se **cuenta** cuántos instantes `t_j` hay por unidad
  de tiempo, que es lo único que `F3` puede afirmar sin medir `Δ`.
- **`ρ` real por plataforma**: el techo 1,5-2,5× sigue siendo **estimación**
  (`research/pot-aes-asic-chacha.md:40-42`); el estudio de Supranational sigue sin localizar.
- **`L_suelo_slots`**: símbolo. Cuando `L_suelo_slots = 0` y `F ≤ S_max+1`, `L = S_max+1` y el
  término `manda_F` de `C-FLU-01` deja de mandar; el informe lo declara fila a fila.
