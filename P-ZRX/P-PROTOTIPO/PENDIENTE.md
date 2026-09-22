# P-PROTOTIPO — prototipo fuera del SPEC del paquete de registro y castigo · **TODAVÍA SIN ENCARGO**

**Fecha:** 2026-09-21 · **Autor:** Claude. **Aquí no hay `PROMPT.md` a propósito.** Es el paso 5 del plan
(`P-ZRX/T-ZRX/PLAN-ENCARGOS.md`) y **no se puede diseñar bien hasta que terminen y se validen** los cuatro
anteriores. Escribirlo hoy sería diseñarlo a ciegas: cada uno de ellos decide una pieza.

| Lo que el prototipo necesita saber | Quién lo decide |
|---|---|
| Qué baseline de umbral se puede dar por bueno y con qué palabras | `P-ZRX/P-CRP/` |
| Si el castigo es imprescindible o solo una capa, y qué `(ρ_ret, T_v)` hace falta | `P-ZRX/P-PRESTAMO/` |
| La definición de la infracción, la identidad de oportunidad y la evidencia mínima; el firmante seguro | `P-ZRX/P-EQUIVOCACION/` |
| Qué prueba de existencia y permanencia se prototipa (cobertura completa, aperturas, parciales) | `P-ZRX/P-PERMANENCIA/` |

**Alcance previsto** (de `P-ZRX/T-ZRX/SOLUCION-CANDIDATA-REUTILIZACION.md` y su anexo): registro por lote
(`PlotBatchId` que ligue la codificación a la clave y al lote), maduración, vínculo de cada solución al
lote, recompensas retenidas, verificador de fraude, castigo prospectivo y recompensa al denunciante,
firmante seguro, alta de quien entra sin monedas; y su comportamiento bajo **reorg, poda y
sincronización**. Fuera del SPEC, con mediciones de bytes, CPU, estado por nodo y altas por segundo.

**Decisión de Katana que lo precede:** aceptar un **registro de parcelas** revoca «sin registro de
sectores». Conviene tomarla con los cuatro informes delante.
