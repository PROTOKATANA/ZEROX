# Plan de encargos — reutilización del espacio entre ramas y paquete de registro y castigo

**Fecha:** 2026-09-21 · **Autor:** Claude, por orden de Katana. **Reparto:** Claude diseña los encargos y
valida los resultados; DeepSeek los ejecuta; Katana decide. Todos aplican `veritas/LINEO.md` (cada
`PROMPT.md` lleva copiado literalmente su §8). Contexto: `P-ZRX/T-ZRX/AGUJEROS-Y-SOLUCIONES.md` y
`P-ZRX/T-ZRX/SOLUCION-CANDIDATA-REUTILIZACION.md`. El orden es el que propuso Codex y Claude aceptó.

## Los pasos (seis del plan original, más el paso 0)

| Paso | Carpeta | Qué contesta | Hilos | Estado |
|---:|---|---|---:|---|
| 0 | `P-ZRX/P-CRP1/` | **¿Son reales los diez defectos que el encargo 07v2 atribuye a CRP-v0.1, y cuánto mueven sus cifras?** Entrega `CIFRAS.md` (una fila por cifra publicada: se sostiene / cambia / cae) y `DEPENDIENTES.md` (qué frases del SPEC, TAREAS y `T-ZRX` se apoyan en una cifra afectada). Añadido el 2026-09-21 a petición de Katana: Claude citó esos defectos leyéndolos del encargo, sin comprobarlos en el código | 4 | **listo para lanzar** |
| 1 | `P-ZRX/P-CRP/` | ¿Son válidas CRP-v0.2 y v0.3? ¿Qué se puede afirmar **hoy** del umbral de una rama privada, y con qué palabras? Entrega `BASELINE.md` | 8 | **listo para lanzar** |
| 2 | `P-ZRX/P-PRESTAMO/` | Con `α` propio y `β` prestado: cuánto baja el umbral, si el consenso base aguanta el doble farmeo barato, y **cuánta recompensa retener y cuánto tiempo** | 8 | **listo para lanzar** |
| 3 | `P-ZRX/P-EQUIVOCACION/` | ¿Alcanza la infracción estrecha a todo el doble farmeo que importa bajo el perfil 1a (`κ`)? ¿Qué honestos caerían? Firmante seguro y evidencia mínima | 4 | **listo para lanzar** |
| 4 | `P-ZRX/P-PERMANENCIA/` | ¿Qué prueba de existencia y permanencia aguanta la regeneración (0,8 s de núcleo por pieza)? ¿Pueden los parciales sustituir a la prueba de cobertura completa? | 4 | **listo para lanzar** |
| 4,5 | `P-ZRX/P-IDENTIDAD/` | **¿Qué se rompe si la identidad de billete deja de llevar `chunk`?** Inventario de todo lo que cuelga de ella (U2, U3″, unicidad pagable, contexto de reorg, retarget, `C-FLU-12`), cuántos bloques honestos se perderían, y si el doble farmeo deja de aportar peso **por construcción**. Añadido el 2026-09-21 tras P-PRESTAMO: **puede ahorrar el mecanismo de castigo entero** | 4 | **listo para lanzar** |
| 5 | `P-ZRX/P-PROTOTIPO/` | Prototipo fuera del SPEC del paquete entero | — | **sin encargo**: depende de 1–4 (`PENDIENTE.md`) |
| 6 | `P-ZRX/P-PARAMETROS/` | Derivar `M`, retención y umbrales; propuesta de texto para el SPEC | — | **sin encargo**: depende de 5 (`PENDIENTE.md`) |

Cada carpeta lanzable tiene `PROMPT.md` y `ENTRADA.sha256`; las de los pasos 2–4 tienen además
`CANDIDATA.md`, **copia congelada** de la solución candidata tal como estaba el 2026-09-21 (si el
documento de `T-ZRX` cambia después, los encargos siguen leyendo la misma versión). La huella de
`P-ZRX/P-CRP/` cubre además los **91 ficheros rescatados** de CRP-v0.2 y v0.3 y el encargo 07v2.

## Dependencias y orden de lanzamiento

- **El paso 1 primero.** El «`α = 1/2`» que ha servido de base todo el 2026-09-21 es de CRP-v0.1, y el
  encargo que originó CRP-v0.2 le enumera **diez defectos**; v0.2 y v0.3 declaran el umbral protocolario
  **inconcluso**. El paso 2 lee `P-ZRX/P-CRP/auditoria/BASELINE.md` **si existe**; si no, parametriza.
- **Los pasos 3 y 4 son independientes** de todo lo demás y pueden ir en paralelo con el 1.
- **El paso 2 usa `κ` (del paso 3) como símbolo**: no se bloquea, pero sus conclusiones se afinan cuando
  el 3 entregue.
- **El paso 0 es independiente y pequeño**; conviene lanzarlo **con el 1 o antes**: si un defecto resulta no
  ser real, el paso 1 lo lee y se ahorra «corregirlo». **Las dos cifras de CRP-v0.1 en las que se apoya
  `T-ZRX`** —la compra de varianza (2,2 % → 30,8 %) y la tabla del multistream— **quedan en revisión hasta
  que el paso 0 entregue.**
- **Los cinco a la vez NO caben**: `4 + 8 + 8 + 4 + 4 = 28 > 24`. Lo natural es lanzar **0, 1, 3 y 4 juntos
  (20 hilos)** y el **2 después**, que además se beneficia de leer `BASELINE.md`.
- **El paso 4,5 (`P-ZRX/P-IDENTIDAD/`) sale de P-PRESTAMO y va ANTES del prototipo**: si cambiar la definición de
  identidad cierra el doble farmeo por construcción, el paquete de castigo deja de ser imprescindible y el
  prototipo es otro. Es análisis de reglas, barato, y no depende de nada más.
- **Se pueden lanzar los pasos 1–4 a la vez** si se prefiere velocidad: `8 + 8 + 4 + 4 = 24` hilos, el tope
  de LINEO. **Ninguno mide tiempos como resultado** (no es el caso de `P-ZRX/P-INTENTO/`), así que
  compartir máquina no contamina sus conclusiones; sus benchmarks de LINEO sí, y cada encargo obliga a
  anotar `uptime` y a etiquetarlos «medido con carga ajena».
- Orden recomendado si se lanzan de uno en uno: **0 → 1 → 3 → 4 → 2**.

## Cómo se lanza cada uno

Al agente ejecutor se le da **la ruta del prompt**, p. ej. `P-ZRX/P-CRP/PROMPT.md`, y nada más. Cada
encargo le obliga a criticar el planteamiento **antes** de empezar, a escribir solo en su zona, y a
comprobar las huellas al principio y al final.

## Qué hará Claude al validar cada entrega

Huellas y zona · horas declaradas contra `mtime` · citas abiertas una a una · aritmética rehecha aparte ·
buscar tests que comparen una fórmula consigo misma · contrastar el modelo central con las fuentes
históricas **antes** de darlo por bueno (lección de `P-ZRX/P-ADELANTO/`). **La reejecución de código se
ofrece y se hace solo con un sí de Katana**, y nunca mientras otro encargo esté midiendo tiempos.

## Lo que este plan NO incluye (sigue pendiente, de `AGUJEROS-Y-SOLUCIONES.md` §9)

- Especificar el controlador de rango **R-FIN-13′** con P2/P3 (el otro vector medido que mueve el umbral).
- **`PRESUP_NODO` y el vector C4** con el segundo VDF dentro; decidir **`ρ_max`**.
- **Red y eclipse**: integrar y validar para el protocolo vigente lo modelado en la ronda 11b.
- **`ρ` real**: localizar el estudio de Supranational o estimar el ASIC de AES con fuente.
- **Re-medir `P-ZRX/P-INTENTO/`** con la máquina en reposo y con acceso a la GPU; **reejecutar
  `P-ZRX/P-REVELACION/`**.
