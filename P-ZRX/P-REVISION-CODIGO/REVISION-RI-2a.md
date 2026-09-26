# REVISIÓN RI-2a — revisión independiente de `zx-cadena` y del modo fusión

**Revisor de la revisión:** Claude (director). **Fecha:** 2026-09-26. **Ejecutor:** subagente Sonnet
(≈ 14 min). Evidencia: `resultados-RI-2a/` (informe y diff del test de reproducción). **Veredicto:
ACEPTADA.** Un hallazgo alto confirmado; dos bajos. Descartó por lectura varias sospechas (reparto de
`peso_sufijo`, propagación del terminal, RD-2/RD-7/RD-10) y el diferencial contra T04 pasa en su copia.

| # | Hallazgo | Comprobación del director | Decisión |
|---|---|---|---|
| 1 (alta, CONFIRMADO) | `Cadena::admitir` (`crates/zx-cadena/src/cadena.rs:207-235`) guarda **cualquier** error, también `ErrSinPadre`: un bloque admitido antes que su padre queda inválido para siempre aunque el padre llegue después. El `resolver` que reintenta solo lo usan los tests | Leído: el `match` final inserta `validos = false` y el motivo sin distinguir errores transitorios; el reintento devuelve el guardado | **Corrección dentro de W06d2** (avisada a su ejecutor a mitad de ejecución): no guardar como definitivo un error por padre ausente; test hijo-antes-que-padre |
| 2 (baja, PLAUSIBLE) | `mapear_error_dag` (`cadena.rs:987-999`) traduce cualquier otro error de `zx-dag` a `ErrSinPadre`, lo que puede ocultar una incoherencia interna | Leído | Con la corrección de #1, pasa a importar: un error interno **no** debe tratarse como transitorio. Se añade a W06d2 si hay tiempo; si no, orden propia |
| 3 (nota) | La madurez de la garantía está duplicada en `cadena.rs::activo_promovido` y en `Aplicador::promover` | Leído; hoy equivalentes | Riesgo de deriva: un test que las compare, en la próxima orden que toque `zx-cadena` |
