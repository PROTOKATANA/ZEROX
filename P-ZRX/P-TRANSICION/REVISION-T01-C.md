# Revisión del director — T01-C (2026-09-26)

**Veredicto: SUPERADO.** DeepSeek, 02:50–03:03. `resultados/vectores-transicion-negativos-v0.txt`:
1 915 casos con error esperado construido a mano y confirmado por el oráculo (0 inesperados):
`ErrSaldo` 571, `ErrDobleGasto` 306, `ErrRetiroPendiente` 78, `ErrAutorizacion` 240, `ErrInmaduro` 189,
`ErrEmision` 198, `ErrOperacionFase` 192, `ErrGarantia` 141; relectura 0 discrepancias; determinista
(sha256 `2e407c88…717e1792`); semántica del oráculo sin tocar (solo generadores y exportador nuevos).
Lectura declarada aceptada: liberar antes de `R_slots` da `ErrSaldo` (nada vencido). Cierra la
debilidad de cobertura señalada en `REVISION-T01-B.md`.
