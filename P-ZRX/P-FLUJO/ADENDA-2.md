# ADENDA 2 al encargo P-FLUJO — D-F2…D-F5 DECIDIDAS por Katana

**De:** Claude (diseñador y validador), 2026-09-20. **Solo lectura.** Regístrala en `PROGRESO.md`.
Completa a la `ADENDA-1` y **prevalece sobre su §2**: lo que allí era «PROVISIONAL — pendiente de Katana»
pasa a **DECIDIDO**. Retira esa marca de las reglas y de `DECISIONES-PENDIENTES.md`.

| | Decisión de Katana | Cómo se redacta |
|---|---|---|
| **D-F2** | **A** | Identificador de flujo con `H_d = SHA3-256(etiqueta ‖ m)` y una **etiqueta nueva de 16 bytes**. Propón la etiqueta y declara que hay que **ampliar C-HASH-06** (hoy lista cerrada). El resto del dominio PoT sigue en `blake3` (D-1 = A): di en una línea por qué aquí no aplica el argumento del oráculo externo |
| **D-F3** | **C, acotada al enunciado** | Regla de finalidad **nueva en el SPEC**, en slots, con la semántica de R-FIN-7: un nodo **MUST NOT** reorganizar por debajo de `F_slots`; la punta que lo exija **se ignora** y el proceso **no se detiene**. `F_slots` va como **símbolo** (el SPEC ya lo usa como provisional en §7.3). **Alcance estricto: solo el enunciado.** La reconciliación con el código que hoy se detiene, con `COINBASE_MATURITY` y con el techo de archivado **NO entra**: decláralo como pendiente y remite a lo que el SPEC ya dice (`SPEC.md:1891-1899`, `SPEC.md:2050-2054`). No intentes reconciliar `C-REORG-07`: es transitoria y sigue siéndolo |
| **D-F4** | **A** | La desigualdad, **escrita de forma explícita**: qué comparación prohíbe la reorganización y cuál activa la inyección, de modo que dos implementaciones no puedan discrepar en el borde. Conserva tu demostración de que el punto de bifurcación queda estrictamente por debajo de `T_j` |
| **D-F5** | **Mejorada: ya NO es «sin legislar»** | Escribe **explícitamente** que **un nodo sin cadena previa aplica la selección ordinaria de GHOSTDAG** (la rama de mayor `blue_work`, reglas C-GD vigentes) y que **la regla de finalidad solo obliga a quien ya tiene una cadena que reorganizar**. No es un mecanismo nuevo: es cerrar un hueco de redacción, para que dos clientes no lo implementen distinto. Añade el alcance: en el caso realista (una minoría aislada) el recién llegado cae en el lado mayoritario; el ataque de largo alcance está acotado por la secuencialidad del PoT y, en el arranque, por los checkpoints C-CHK —**cítalos, no los amplíes**—. Y mantén la **regla operativa** de la ADENDA-1: el nodo **detecta** que ha quedado fuera del flujo mayoritario y **lo señala**; es comportamiento de nodo, no validez de bloque |

**Lo que sigue declarado y no legislado:** que un granjero puede producir en un flujo que no ha
seleccionado. No se puede prohibir criptográficamente (identidades gratis,
`research/dag-poas-balizas-auditoria.md`); va a «Lo que esta propuesta NO resuelve».

**Estado final de decisiones que debe reflejar `DECISIONES-PENDIENTES.md`:** decididas DF-1…DF-4, D-1,
D-2, el perfil 1a (reconfirmado), el suelo de `L`, y D-F1…D-F6. **No queda ninguna provisional.** Si al
redactar aparece una bifurcación nueva, ábrela como D-F7 en adelante; no la resuelvas tú.

Al terminar: actualiza los tres entregables, las dos comprobaciones de siempre en `PROGRESO.md`, y avisa
con un resumen de **qué reglas cambiaron** respecto de tu primera entrega.
