# REVISIÓN DS-3 — calculadora y Monte Carlo del coste mínimo de los ataques

**Revisor:** Claude (director). **Fecha:** 2026-09-26. **Ejecutor:** DeepSeek (Julia), 08:52–09:19.
Evidencia: `P-ZRX/P-DISUASION/DS3/` (sin la caché `.julia-depot`). **Veredicto: ACEPTADA con reparos.**

## Comprobado por el director

- `ENTRADA-DS3.sha256` 6/6; `HUELLAS.sha256` de la zona se verifica; `Pkg.test()` en verde con los siete
  casos de `MODELO` §4 (p. ej. `117,238` núcleos/TiB, `B(ε) = 0,675466`); cuatro vías independientes
  coinciden en 4 216 celdas (error 1,1·10⁻¹⁵); Monte Carlo con `StableRNGs` dentro del intervalo de
  Wilson; `run.jl` en 1,4 s con 4 hilos.
- **Dos discrepancias del modelo, bien detectadas:**
  - F10: la región de retención. La desigualdad da `ρ_ret·T_v > 400 − 10 − 20 = 370`; el «≳ 4.000» que
    DS-2 copió ya era **incoherente en su fuente** (`.trash/zerox/P-ZRX/P-PRESTAMO/investigacion/INFORME.md`
    línea 49 escribe «≳ 4.000» y pone como ejemplos 0,10 × 3.000 y 0,25 × 1.200, producto 300). Manda la
    desigualdad. **Error mío** al ratificar DS-2 sin rehacer la cuenta.
  - F7: la cota de Baig y Pietrzak transcrita en `MODELO` §2.11 da 4.253, no «≈ 1.233 + 140»; el resumen
    del artículo da `φ²ρ/ε = 1.600`. Mismo orden de magnitud; se publica como reserva y no se usa como
    cifra de ZEROX.

## Resultado

- **A1 (doble farmeo) con castigo + retención (M3 + M5): Δ de coste = 0** para toda probabilidad de éxito
  ≤ 0,5: el atacante compra en la cola de claves pequeñas el espacio que cruza la deriva
  (`β_d ≤ 0,585 < B(ε) = 0,675`) sin soborno. Lo que decide si el castigo muerde **no** es `ρ_ret` ni
  `T_v`, sino **la distribución de tamaños de clave** (no medida en ZEROX).
- **A3 (sembrador) con registro + auditoría + colateral:** 117,238 núcleos por TiB en continuo (≈ 7,1
  GTX 1070 por TiB con DS-4), exigible; detección nula si la auditoría abre ≤ 181 092 posiciones por TiB.
- **A4 (Sybil) con garantía mínima:** exigible y regresiva (con los escenarios hipotéticos, 165 % del
  ingreso semanal de una granja de fracción 10⁻³).
- **A5 con O4 (coinbase atada a la clave de la solución):** exigible, sin detección y sin coste en tokens.
- A7, A8, A9, A10 y M4: no cuantificables con el modelo ratificado (declarado).

## Reparos

1. En la tabla por mecanismo, «1000 u.e./identidad» (M1, F4) es el **capital exigido**, no un coste
   consumido: el coste real de X es el de oportunidad (`r·q·T`) y el de adquirir los tokens; y el «coste
   del honesto» que se da (pérdida accidental esperada) omite su propio capital inmovilizado. La
   conclusión cualitativa (exigible, regresiva) no cambia.
2. Todos los precios y `q` son **escenarios hipotéticos** (`escenarios.tsv`): las cifras en u.e. son
   sensibilidades, no predicciones.
