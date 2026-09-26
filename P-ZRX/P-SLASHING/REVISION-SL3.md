# REVISIÓN SL-3 — oráculo de evidencia y castigo en T01 y T04

**Revisor:** Claude (director). **Fecha:** 2026-09-26. **Ejecutor:** DeepSeek (Julia), 18:41–19:14.
**Veredicto: ACEPTADA CON CORRECCIONES** (`ORDEN-SL3b`).

## Comprobado por el director

- Informe: T01 `Pkg.test()` 176/176 (82 de SL-3), `run.jl` 737 280 historias sin fallos de I-1…I-7 con la
  conservación ampliada; T04 421/421 y `run.jl` 200 réplicas SUPERADO (3 000 historias base y 1 600 con
  evidencia). Vectores `vectores-transicion-v0.3.txt` (2 795 casos) y `vectores-estado-dag-v0.4.txt`
  (1 878) con relectura independiente 0 discrepancias; los anteriores intactos.
- Cobertura de T04 leída (`resultados/cobertura-v0.4.txt`, sección SL-3).

## Correcciones

1. **Redondeo de la recompensa (error del director en RAT-2):** con `techo(C·2/8)` el infractor puede perder
   menos de 6/8 (con `C = 11`, 8 < 8,25); lo detectó el ejecutor (AMBIGUEDAD-SL3-9). Corregido en el contrato
   como **RAT-2′**: `suelo(C·2/8)`.
2. **Cobertura de T04 incompleta:** falta el tipo «evidencia contra clave sin saldo» en los casos aleatorios
   (solo aparece en el dirigido D-18), y `deshecha = construida = 771` indica que el contador no mide «aplicada
   y luego deshecha por una reorganización».
3. En T01, `run.jl` solo generó 92 historias con evidencia de 737 280: la propiedad se ejercita poco en el
   barrido (los vectores sí la cubren); se amplía.
