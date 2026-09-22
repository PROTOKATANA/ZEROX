# ADENDA 1 al encargo P-2.1 v3 — rendimiento y punto de control

**De:** Claude (diseñador), 2026-09-18 ~22:00. **Para:** el ejecutor. **Solo lectura**, como el encargo.
El `ENCARGO.md` no cambia (sus huellas siguen en `ENTRADA.sha256`); esta adenda **prevalece** sobre él
solo en lo que dice aquí. Regístrala en `PROGRESO.md` al leerla.

## 1 · Hecho medido: el patrón de tu código v1 no escala, no lo copies tal cual

Medido por el validador sobre `deepseek/P-2.1/…/ancla-inyeccion-v1` (T=600, obs=100, Dmax=12, JIT
calentado **fuera** del cronómetro, `@timed`):

| hilos | core-s por réplica | tiempo en GC | asignado |
|---|---|---|---|
| 1 | 0,56 | 33 % | 0,53 GiB por réplica |
| 8 | 2,20 | 28 % | |
| 24 | 3,70 | 44 % | 75,8 GiB en 22 s |

El coste por réplica se multiplica por **6,6** de 1 a 24 hilos: 24 hilos rinden como 3,6. Cuadra con
tu corrida real (1 514 s × 24 / 10 000 = 3,63 core-s). Causa: asignación masiva en el bucle interno
(`Dict` por corte y por `D`; vectores nuevos de `cadena_seleccionada`/`cadena_global` por observador y
corte; `Int[...]` de padres). Tu tabla de escalado de la v1 no lo mostraba porque cronometraba también
la compilación. **LINEO §3-§4 y §6 ya lo exigen: bucle interno sin asignaciones, y escalado medido con
el JIT fuera del cronómetro.**

## 2 · Tres mejoras algorítmicas que valen más que cualquier hardware

Tu `MODELO.md` mide **una época por réplica de 1 300 slots**, recalculando la cadena de cada observador
en cada corte. Las tres siguientes conservan el resultado; **valida cada una contra tu referencia
simple en instancias pequeñas** (LINEO §8.3-§8.5) antes de usarla:

1. **Varios umbrales por réplica.** `T_j` es solo un índice de slot: coloca un umbral cada ~200 slots
   tras el calentamiento y mide `W_obs` de cada uno. **La unidad estadística sigue siendo la réplica**
   (IC por clúster de réplica), así que no supones independencia entre umbrales.
2. **Evaluación incremental del ancla.** El ancla de un observador solo cambia si su cadena
   seleccionada cambia **por debajo del cruce de `T_j`**. Tras cada inserción basta recorrer desde la
   punta hacia atrás hasta `slot < T_j`: coste `O(d)`, no `O(longitud de la cadena)`, y sin vector nuevo.
3. **Parada temprana por umbral:** cuando todos los observadores coinciden con el ancla de la vista
   de latencia cero y han pasado `d_calma` slots sin cambio, deja de evaluar ese umbral **pero sigue
   simulando**; al final del horizonte comprueba una vez el ancla definitiva. Si difiere, esa época se
   reevalúa completa (no se descarta ni se trunca: sería sesgar la cola). Declara `d_calma`.

**No propongas GPU.** GHOSTDAG es cómputo irregular, con saltos dependientes de datos y estructuras
enlazadas: lo contrario de lo que acelera una GPU. Las réplicas son independientes, que es justo lo que
24 núcleos hacen bien cuando no se pisan en el asignador. Además LINEO §5.7 obligaría a reescribir
GDR en C++/CUDA y se perdería el oráculo. El lenguaje tampoco es el problema: lo es el patrón de memoria.

## 3 · Punto de control obligatorio — no recorta el encargo, lo ordena

**Primera pasada** (objetivo: horas, no un día):

- **4.0 completa.**
- **4.A «de forma»:** por celda, las épocas necesarias para medir la cola directamente hasta `~10⁻³`
  (no `10⁻⁵`), con IC por clúster. Lo que decide es **si la cola es exponencial y con qué tasa** por
  `α`, por `Δ` y por vía de ataque —en particular A3, entrega selectiva—, contrastada con la tasa
  calibrada `r = (√((1−α)λ) − √(αλ))²`. Si la cola es exponencial con tasa del orden de la calibrada,
  `G(L)` a `L` de cientos o miles de slots queda decenas de órdenes por debajo de cualquier `ε`, y
  medir más hondo **no cambia ninguna decisión**. Lo que sí la cambiaría es una vía de ataque que
  vuelva la cola **pesada**: búscala.
- Antes del lote: publica en `PROGRESO.md` core-s por réplica a 1 y 24 hilos, recuento de celdas y
  presupuesto por celda.

**Al terminar la primera pasada: PARA, escribe un `INFORME.md` parcial con 4.0 y 4.A, y avisa.** La
medición honda de la cola (hasta `10⁻⁵`), y 4.B, 4.C y 4.D, **se lanzan después**, con lo aprendido.
La cola honda solo si la forma no es exponencial, si la tasa discrepa de la calibrada, o si alguna
vía de ataque la ensancha.
