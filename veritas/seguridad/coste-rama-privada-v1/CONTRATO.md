# CONTRATO — CRP-v0.1 · coste de una rama privada

**Categoría propuesta:** `seguridad` (dominante); `consenso` (secundaria). **Ruta de trabajo:**
`veritas/seguridad/coste-rama-privada-v1/`. **Ejecutor:** DeepSeek. **Origen:**
`deepseek/ENCARGO-07-coste-rama-privada.md`.

## Qué calcula

La **curva** `α_mínimo` con que un adversario que controla una fracción `α` del espacio puede
construir, en privado, una historia cuyo `blue_work` **supere** el de la honesta, en dos regímenes
separados (corto/doble gasto y largo/IBD), y bajo el mismo criterio para tres protocolos: PoW
lineal (Bitcoin), GHOSTDAG sobre PoW (Kaspa) y PoST-DAG (ZEROX). Además:

- umbral medio de trabajo y su independencia del reajuste de rango (`sr`);
- el efecto del `SR` endógeno (familia de controladores) sobre el `blue_work`;
- la curva corta `α_mínimo(d, ε)` y la contribución de la granularidad del DAG (varianza);
- cuantificación separada del **umbral** y del **coste económico** (doble uso / nothing-at-stake);
- multiplicidad de billetes `m` (D6) recalculada para esta pregunta;
- comportamiento contextual de U2/U3″ **entre ramas disjuntas**, comprobado contra el oráculo.

## Qué NO acredita

- **No decide ninguna regla de consenso.** No fija `k`, `λ`, `S_max`, `W` de fusión, `sr0`,
  ventanas ni constantes de producción: entran como función/parámetro.
- **No especifica R-FIN-13′.** Modela una **familia** de controladores y entrega la **propiedad**
  que el controlador debería cumplir (`PROPUESTA.md`).
- **No usa `F = 2 h`.** No hay ninguna cifra que dependa de él.
- **No mide una granja real.** El espacio, `C`, `M` y `sr` son del modelo; el acoplamiento
  espacio↔solución (`MODELO.md` §1) se toma como supuesto declarado, no re-derivado criptográficamente.
- **No audita el PoT** (flujos, inyección, VDF rápido) ni el multistream como hecho: el ATAQUE 2 se
  cuantifica como **escenario condicional** al diseño del flujo. Se apoya, sin reabrirlo, en
  `research/dag-poas-auditoria.md` (ATAQUE 2).
- **No hereda veredictos** de los encargos 05/06. D6 se recalcula aquí; la imposibilidad de
  selección (PRV §1.2) se usa sólo como contexto y no se cita como prueba de coste.
- **No publica una cifra sin artefacto** en `resultados/` ni una fuente cuya existencia no se haya
  comprobado con ruta desde la raíz (`run.jl --fuentes`).

## Presupuesto declarado (antes de ejecutar)

| Recurso | Tope | Uso real |
|---|---|---|
| RAM | 64 GiB | < 2 GiB (DAG ≤ pocos miles de bloques) |
| Hilos | 24 de 32 lógicos | se mide 1…24; se conserva 24 (menor tiempo) |
| Disco | 4 GiB | < 50 MiB |
| Tiempo | 6 h | < 1 h de cómputo total |

Si se agota, checkpoint y **inconcluso**, con entrada mínima reproducible. Ningún timeout se
convierte en evidencia de falsedad (LINEO §7).

## Criterio de éxito (idéntico para los tres protocolos)

Una rama alternativa **gana** si su trabajo acumulado (`blue_work` observable) supera
**estrictamente** el de la rama honesta en el momento de la decisión. `α_mínimo` es el ínfimo de
`α` con probabilidad de ganar ≥ criterio declarado (media para el régimen largo; `ε` para la curva
corta). El adversario retiene su rama; publicar en la honesta está dominado y se cuantifica.
