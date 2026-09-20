# ADENDA 3 al encargo P-FLUJO — D-F7, D-F8 y D-F9 DECIDIDAS por Katana

**De:** Claude (diseñador y validador), 2026-09-20. **Solo lectura.** Regístrala en `PROGRESO.md`.
Tu respuesta a la objeción queda **aceptada entera**, incluida la retirada de la conclusión (c): el
validador la había dado por buena y era falsa; `P-2.1/SINTESIS.md` §8 ya lo recoge.

| | Decisión de Katana | Qué hay que hacer |
|---|---|---|
| **D-F7** | **B** | Renombra **`C-FLU-19` → `C-FIN-01`** en toda la propuesta (hoy aparece 16 veces y `C-FIN-01` ninguna: la decisión no te había llegado). Familia nueva `C-FIN`; declárala en el índice |
| **D-F8** | **C** | **No se congela la vista.** `C-FLU-03` queda como está y **`C-FLU-21`** (la inyección ya activada **se hereda, no se recalcula**) pasa a regla propuesta firme. Deja escrito por qué congelar reabre E1 |
| **D-F9** | **C** | **Se permite adoptar el flujo rival dentro de la ventana, con presupuesto.** DF-2 («ninguna regla de adopción») queda **sustituida**. Redáctalo como regla nueva |

## Lo que la regla de adopción tiene que decir, como mínimo

1. **Qué es adoptar.** Una rama de otro flujo es **válida en términos absolutos** (C-FLU-13): no se puede
   **fusionar** (C-FLU-14) pero sí **seleccionar**. Adoptar es la **selección ordinaria de GHOSTDAG**
   (mayor `blue_work`, desempates de C-GD-03) entre ramas válidas, **limitada por `C-FIN-01`**: solo
   mientras la profundidad de la reorganización sea `< F_slots`. Di con precisión **desde qué punto se mide
   esa profundidad** y demuestra cuánto mide la ventana.
2. **La congelación es simultánea:** todos los nodos con cadena cruzan el umbral a la vez. Cita, con su
   alcance y etiquetado como resultado de `P-PUERTA/veritas/consenso/puerta-cobertura-v1/` (validado), el
   riesgo residual de bloqueo divergente por desfase de vista, `arcsin(√(τ/F))/π`, y el canal del nodo que
   sincroniza después; enlázalo con `C-FLU-18` y `C-FLU-17`.
3. **Orden y coste.** La comprobación estructural va **siempre primero** (paso 1b). El PoT del flujo rival
   se verifica **solo cuando hace falta para adoptar** (la rama rival va por delante) y **bajo presupuesto**:
   agotarlo da `Pendiente`, **nunca** `Inválido` (C-POT-07); sin validez comprobada no se adopta.
4. **R-FIN-5 cambia de motivo.** La frase «un nodo honesto jamás verifica el PoT de un flujo ajeno» deja de
   ser cierta a la letra. Escribe la versión exacta: **nunca para fusionar; solo para adoptar, dentro de la
   ventana y bajo presupuesto.**
5. **El DoS, demostrado o refutado, no supuesto.** Afirmación del validador, **sin revisar**: como el flujo
   se **deriva** del pasado y no se declara, presentar un flujo rival que obligue a gastar AES exige la
   misma rama privada más pesada dentro del corte que tu vía A2 —es decir, es igual de improbable—.
   **Compruébalo**: si hay una forma más barata de forzar verificaciones de PoT ajeno, ese es el hallazgo.
6. **Lo que la adopción NO cura.** El nacimiento realista de una partición es un corte de red más largo que
   `L`: ahí las cadenas divergen **antes** de `t_j`, la profundidad supera `F` y **no hay adopción
   posible**. La regla cura el nacimiento **espontáneo** (latencia, vía A2), que es el improbable. Dilo así,
   para que nadie lea esta regla como «las particiones se curan».
7. **No extiendas `C-FLU-20`** al periodo anterior a `t_j`: tu razonamiento sobre (h.3) se mantiene.

## Cierre

- `DECISIONES-PENDIENTES.md`: **D-F1…D-F9 decididas.** Si al redactar aparece otra bifurcación, ábrela como
  **D-F10** y no la resuelvas.
- En «Lo que esta propuesta NO resuelve», añade que **la vía A2 no está medida** y que el instrumento que
  podría medirla es ANCLA-v0.2.
- Repasa que **ningún pasaje** siga afirmando que la ventana de adopción es vacía.
- Avisa con un resumen de **qué reglas cambiaron** respecto de la revisión 4, y con las dos comprobaciones
  de siempre. `?? P-ZRX/` es de Katana: no es tuyo y no hay que tocarlo.
