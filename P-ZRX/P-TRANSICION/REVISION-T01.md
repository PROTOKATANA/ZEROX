# Revisión del director — T01 (2026-09-26)

**Veredicto: SUPERADO.** DeepSeek, 01:03–02:07. Oráculo Julia de referencia del contrato de
transición v0 en `P-ZRX/P-TRANSICION/T01/`.

- Rejilla reducida completa: **147 456 puntos**, 200 réplicas por punto: **29 491 200** historias,
  183 406 080 undos exactos, 4 155 744 permutaciones de I-3 (muestreadas 1/200 en `run.jl`;
  exhaustivas en los tests para ≤ 7 bloques): **0 fallos** en I-1…I-7. X-01…X-20 pasan en todos
  los puntos donde aplican.
- Comprobado por el director: los tests dirigidos comparan con el error **esperado construido a mano**
  en cada escenario (`escenarios_rechazo`, campo `esperado`), no con el propio oráculo; X-19 construye
  la rama sin depósito y exige `ErrGarantia` y undo exacto por hash canónico; el final de
  `run-reducida.log` dice `VEREDICTO = SIN FALLOS`, `RUN_EXIT=0`.
- Datos para D-T03: en el propio oráculo, FC-1 = FC-3 en las historias de `run.jl` (sin ramas PoW
  tardías), FC-2 difiere en 30 720 casos (CUT-W); X-18 separa FC-1 (96 000 diferencias).
- **13 ambigüedades** documentadas antes de escribir código y resueltas con la lectura restrictiva o
  compatible: **ratificadas** en `CONTRATO-v0.md` §«Ratificaciones v0.1» (R-1…R-15), con una
  excepción: la lectura de AMBIGÜEDAD-6 (coinbase aplicada primero en cualquier posición) se
  **sustituye** por R-6 (la coinbase debe ser la primera), que T01-B implementará antes de exportar.
- Presupuesto: `run.jl` tardó 38,8 min (> 30 min previstos por la orden); se perfiló antes de
  optimizar, como exige LINEO; declarado.

**Límites:** abstracción sin criptografía, sin PoW/PoAS/PoT reales, GHOSTDAG como cadena (`k = 0`),
sin red ni latencia (lo dice el propio informe).
