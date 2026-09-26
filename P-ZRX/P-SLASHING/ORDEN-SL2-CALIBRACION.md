# ORDEN-SL2 — Calibración del castigo: disuadir al que recluta sin castigar al honesto

## 1. Identidad y contexto

- **ID:** SL-2. **Fecha:** 2026-09-26. **Director:** Claude. **Ejecutor:** DeepSeek (Julia).
- **Zona (única escribible):** `/home/katana/zeo/ZEROX/P-ZRX/P-SLASHING/SL2/` (proyecto Julia propio; puede
  leer y copiar el código de `P-ZRX/P-DISUASION/DS3/`).
- **Objetivo único:** la región de parámetros del castigo (fracción confiscada `f`, retención `ρ_ret`,
  horizonte `T_v`, retardo de retiro `R_slots`, garantía `q`) que a la vez (a) hace que reclutar el espacio
  que falta para ganar una rama privada cueste más que lo que el atacante gana, y (b) mantiene la pérdida
  esperada anual del **honesto** por dobles firmas accidentales por debajo de una fracción de su ingreso.
- **Pregunta falsable:** «Para una tasa de doble firma accidental del honesto `ε_h ≤ 10⁻³` por año (con
  firmante seguro), existe una región de parámetros no vacía en la que el reclutamiento para `α_atacante`
  entre 0,20 y 0,40 no compensa y la pérdida esperada del honesto es ≤ 1 % de su ingreso anual.»

## 2. Método (LINEO)

1. Parte del modelo ratificado de DS-3 (`P-ZRX/P-DISUASION/resultados-DS2/MODELO.md`, `DS3/src/`) con sus
   correcciones (`REVISION-DS3.md`: la región de retención es `ρ_ret·T_v > V/N − c_r − I·M`, no «≳ 4.000»).
   **Sin castigo correlacionado** (DS-5).
2. El reparto del espacio entre claves: el **empírico** de DS-6 (`P-ZRX/P-DISUASION/resultados-DS6/`,
   `farmers-raw.csv`, convención de densidad corregida) como caso central, y la Pareto de DS-3
   (`α_dens ∈ [2,05; 3,0]`) como caso pesimista.
3. Barrido de `ε_h ∈ {10⁻⁴, 10⁻³, 10⁻², 10⁻¹}` por año (el último, sin firmante seguro), del valor del ataque
   `V` y de los parámetros; cada escenario con su etiqueta (medido, fuente, hipótesis) en un fichero.
4. Fórmulas cerradas **y** Monte Carlo independiente (`StableRNGs`, semillas no consecutivas) que coincidan
   en los casos de comprobación; `Pkg.test()`; `run.jl` reproducible con un comando.
5. Salidas: la región (tablas y CSV), qué restricción la cierra en cada borde, y una **recomendación de valores
   de desarrollo** para la red dev, etiquetada como tal (no son parámetros de producción).

**Prohibido Python.** Presupuesto: 2 h, 4 hilos, 8 GiB. DeepSeek `deepseek-flash`, esfuerzo `high`; LINEO
antes del código; nada fuera de la zona; sin commit ni push; sin secretos. Entrada congelada
`P-ZRX/P-SLASHING/ENTRADA-SL2.sha256`. Julia en `/home/katana/torio/.juliaup/bin`, con `JULIA_DEPOT_PATH`
en la zona (se puede copiar `P-ZRX/P-DISUASION/DS3/.julia-depot`).
