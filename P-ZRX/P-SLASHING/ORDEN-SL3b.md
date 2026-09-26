# ORDEN-SL3b — Correcciones del oráculo de evidencia

- **ID:** SL-3b. **Fecha:** 2026-09-26. **Director:** Claude. **Ejecutor:** DeepSeek (Julia).
- **Zonas escribibles (solo):** `P-ZRX/P-TRANSICION/T01/` y `P-ZRX/P-DAG/T04/` (se lanza desde `P-ZRX/`).
- **Motivo:** `REVISION-SL3.md`.

## Qué hacer

1. **RAT-2′** (`CONTRATO-EVIDENCIA-v0.md`, al final): la recompensa del incluidor pasa a `suelo(C·2/8)`; lo
   quemado, `C − suelo(C·2/8)`. Test: para todo `C` de 0 a 1 000, pérdida del infractor `≥ 6/8·C`.
2. **Cobertura de T04:** el generador aleatorio produce también evidencia **contra clave sin saldo** (≥ 30 en
   los vectores); el contador `deshecha` pasa a contar solo evidencias **aplicadas en algún estado y luego
   deshechas por una reorganización** (≥ 30); documenta la definición de cada contador.
3. **T01:** el barrido de `run.jl` genera al menos 5 000 historias con evidencia (sin reducir el resto).
4. Reexporta `vectores-transicion-v0.4.txt` (T01) y `vectores-estado-dag-v0.5.txt` (T04) con `.sha256` y
   cobertura; relectura 0 discrepancias; los anteriores intactos. `Pkg.test()` y `run.jl` en verde.

Sección «SL-3b» en los `INFORME.md`/`PROGRESO.md`. **Prohibido Python.** Presupuesto 1 h, 1 hilo. DeepSeek
`deepseek-flash`, esfuerzo `high`; LINEO; sin commit ni push; sin secretos. Entrada congelada
`P-ZRX/P-SLASHING/ENTRADA-SL3b.sha256`.
