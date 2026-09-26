# ORDEN-SL2b — Recalibración con la recompensa de 3/8 a quien incluye la evidencia

- **ID:** SL-2b. **Fecha:** 2026-09-26. **Director:** Claude. **Ejecutor:** DeepSeek (Julia).
- **Zona (única escribible):** `/home/katana/zeo/ZEROX/P-ZRX/P-SLASHING/SL2/` (el mismo proyecto de SL-2).
- **Motivo:** Katana decidió (`DECISIONES.md`, DS-L03) que **3/8** de lo confiscado vaya a la coinbase del
  bloque que aplica la `EvidenceTx` y **5/8** se quemen. SL-2 calibró sin esa recompensa.
- **Pregunta falsable:** «Con la recompensa de 3/8, la región de parámetros del caso central (reparto
  empírico de DS-6) sigue siendo no vacía para `α_atacante ∈ [0,20; 0,40]` y `ε_h ≤ 10⁻³`, incluso contra un
  atacante confabulado con quien incluye su evidencia.»

## Qué hacer

1. Añade al modelo de SL-2 la fracción `s = 3/8`: pérdida neta del infractor **confabulado** con quien
   incluye = `(1 − s)·f·V`; del **no confabulado** = `f·V`. Comprueba y deja escrito que la autodenuncia nunca
   es rentable (el infractor pierde al menos `(1 − s)·f·V > 0` si `f·V > 0`).
2. Repite la región (casos empírico y Pareto, las dos lecturas de unidades P1 y P2) para ambos atacantes y
   compárala con la de SL-2: qué celdas se pierden y cómo cambian los valores recomendados para la red dev.
3. Probabilidad de inclusión: con `s > 0` todo productor que vea la prueba gana `s·f·V` por incluirla;
   modela la inclusión como segura en cuanto un honesto la ve (hipótesis declarada) y señala qué cambia si la
   censura de la evidencia la controla una fracción `c` de la producción (barrido de `c`).
4. `Pkg.test()` con los casos nuevos (incluido `s = 0`, que debe reproducir SL-2); `run.jl` reproducible.

Sección «SL-2b» en `INFORME.md`; `HUELLAS.sha256` rehecho. **Prohibido Python.** Presupuesto: 1 h, 4
hilos. DeepSeek `deepseek-flash`, esfuerzo `high`; LINEO; nada fuera de la zona; sin commit ni push; sin
secretos. Entrada congelada `P-ZRX/P-SLASHING/ENTRADA-SL2b.sha256`.
