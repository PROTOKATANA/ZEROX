# P-PARAMETROS — derivar `M`, retención y umbrales, y proponer texto de SPEC · **TODAVÍA SIN ENCARGO**

**Fecha:** 2026-09-21 · **Autor:** Claude. **Aquí no hay `PROMPT.md` a propósito.** Es el paso 6 y último
del plan (`P-ZRX/T-ZRX/PLAN-ENCARGOS.md`): solo tiene sentido **después** del prototipo
(`P-ZRX/P-PROTOTIPO/`), porque el propio repositorio prohíbe fijar una regla con un número inventado
(`AGENTS.md`: «una regla pendiente no se implementa inventando un número»).

**Lo que derivará, siempre como función o región y con su fuente:** la edad `M` como **cuantil** de la
ventana de adelanto con su tasa de excedencia (`P-ZRX/P-REVELACION/`: con rachas de anclas propias la
ventana no está acotada, así que «`M > sup`» no sirve); la fracción retenida `ρ_ret` y la duración `T_v`
(`P-ZRX/P-PRESTAMO/`); el umbral y el periodo de la prueba de permanencia (`P-ZRX/P-PERMANENCIA/`); y la
definición de la infracción (`P-ZRX/P-EQUIVOCACION/`).

**Mediciones que seguirán faltando y que condicionan esos números:** la ventaja de reloj real `ρ`
(estimación 1,5–2,5×, con el estudio de respaldo sin localizar), el retardo de red `Δ` (exige red
funcionando; de él depende `L_suelo_slots`) y la fracción `α` de anclas del atacante.

**Salida:** una `PROPUESTA-SPEC.md` para que Claude redacte y Katana decida. Nunca una edición directa
de `SPEC.md`.
