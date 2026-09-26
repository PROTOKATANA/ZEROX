# REVISIÓN SL-2 — calibración del castigo

**Revisor:** Claude (director). **Fecha:** 2026-09-26. **Ejecutor:** DeepSeek (Julia), 16:54–17:12.
Evidencia: `P-ZRX/P-SLASHING/SL2/` (sin la caché `.julia-depot`). **Veredicto: ACEPTADA.**

## Comprobado por el director

- `HUELLAS.sha256` de la zona en verde; entrada 8/8; `Pkg.test()` 39/39; fórmulas cerradas y Monte Carlo
  independiente coinciden en los casos de comprobación; `run.jl` en 2,4 s con 4 hilos.
- `resultados/recomendacion-dev.csv` y `sensibilidad-P2.csv` leídos.

## Resultado

- **Caso central (reparto empírico de DS-6): región no vacía en las 2 880 celdas** barridas con
  `ε_h ≤ 10⁻³` por año, `α_atacante ∈ [0,20; 0,40]`, `V ≤ 10⁶`: el castigo disuade al que recluta y el honesto
  con firmante seguro pierde menos del 1 % de su ingreso.
- **Caso pesimista (Pareto de DS-3):** región solo con horizontes de retención largos (`T_v` de 6,7·10⁴ a
  8,6·10⁵ slots, 1,2 h a 10,4 días); con `ε_h ≥ 10⁻²` (sin firmante seguro) y `α_dens ≥ 2,5` se vacía.
- **Refutado para el honesto diminuto** (`f_h ≲ 10⁻⁵`): una garantía **por identidad** le cuesta más que
  su ingreso (regresividad ya vista en DS-2/DS-3). Recomendación para SL-1: garantía **por unidad de
  espacio** (IPA C-02).
- **Valores recomendados para la red dev (no producción):** confiscación total `f = 1`, `ρ_ret = 0,10`,
  `T_v = 10⁵` slots (≈ 1,2 días), `R_slots ≥ F_slots`, `q = 20`; variante robusta que cubre también el caso
  pesimista: `ρ_ret = 0,25`, `T_v = 9·10⁵` (≈ 10,4 días).

## Hallazgo sobre el modelo ratificado (F5)

`MODELO.md` de DS-2 mezcla dos magnitudes: el saldo retenido **por clave** (`ρ_ret·I·λ·f·T_v/2`, depende
del tamaño `f`) y la pérdida **por reclutado** (`ρ_ret·I·T_v`, sin `f`). Yo ratifiqué el modelo sin verlo.
SL-2 calcula las dos lecturas: **el veredicto no cambia**, cambia la escala de `T_v`. Afecta a las cifras
absolutas en u.e. de DS-3 y DS-5 (p. ej. los 510 570 u.e. de soborno evitado de DS-5 usan la lectura
literal); no a sus conclusiones, que son estructurales (la grieta depende de `B(ε)`; el castigo
correlacionado no puede quitar saldo inexistente).
