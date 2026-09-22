# PROPUESTA — CRP-v0.1

**Propuesta, no SPEC.** Nada de aquí es una regla de consenso. El SPEC lo redacta Claude. Se
enuncia la **propiedad** que R-FIN-13′ tendría que cumplir para que el umbral no baje por los
vectores medidos, y qué haría falta para cerrar lo no concluido.

## P1 · Acoplamiento rango-validez / rango-peso (MUST)

`w(B)` **MUST** calcularse con el **mismo** rango que gobernó la validez de la solución de `B`
(`rango_solucion`), como ya hace C-GD-01 + §7.1. Con `sr_val ≠ sr_peso`, el trabajo por slot se
multiplica por `sr_val/sr_peso` sin pagar espacio. **Medido:** con el acoplamiento el factor es 1;
desacoplado, la tabla de `--controladores` da amplificación `16×` para `sr_val/sr_peso = 16`.

> Redacción sugerida (no normativa): «el rango que pondera `w(B)` **MUST** ser el mismo campo
> `rango_solucion(B)` que se compara con `solution_distance(B)`; **MUST NOT** existir un segundo
> rango de cómputo de peso.»

## P2 · Anclaje al flujo canónico, no al pasado privado (MUST)

C-HDR-06 hace `rango_esperado(B) = controlador(past(B), …)`. Si el controlador sólo mira el pasado
de la **propia** rama, una rama privada **elige** su `sr`: puede fijarlo bajo (pocos bloques muy
pesados) y comprar **varianza**. **Medido:** con el mismo trabajo medio `α·T` y `α = 0,45`, la
probabilidad de superar a la honesta sube de `2,2 %` (`sr = sr0`) a `30,8 %` (`sr = sr0/64`).

Por eso R-FIN-13′ **MUST** anclar el conjunto de referencia del retarget al **flujo canónico** (los
bloques que cobran por R-FIN-8′, ya en R-FIN-13′), con una ventana no manipulable por un pasado
privado, de modo que la rama del adversario no pueda obtener un rango distinto del que le
corresponde por su espacio-tiempo acumulado.

## P3 · Pinning de la tasa de la rama (MUST)

Sea `ρ(B)` la razón entre el espacio-tiempo que la rama de `B` justifica y el que el controlador le
atribuye. El controlador **MUST** mantener `ρ ∈ [1−δ, 1+δ]` con `δ` acotado y declarado, y
**MUST NOT** permitir `ρ` grande. Equivalente operativo: el trabajo acumulado por slot
`d·blue_work/d slot ≈ s · λ0 · w(sr0)` **MUST** depender sólo de la fracción de espacio `s`, no del
historial de `sr`. Es exactamente la invariancia que `referencia.jl` certifica y que GDR mide.

## P4 · Lo que falta para cerrar (TAREAS §2.3)

Para pasar de «propiedad» a veredicto cerrado haría falta especificar, y reauditar:

1. **Arranque, ventana y redondeos** del controlador (`TAREAS.md` §2.3).
2. **Fusiones fuera de ventana** y **validación de ramas candidatas con pesos reales** (el pendiente
   que este encargo ataca). Sin esto, `P2` no se puede comprobar sobre una rama privada completa.
3. **Unicidad del flujo PoT** (un único flujo global anclado a finalidad) para eliminar el vector
   multistream de ATAQUE 2, con el coste declarado (adelanto de VDF, ATAQUE 1).
4. **Decisión sobre la varianza del rango**: si se admite un `sr` elegible por el productor, el
   umbral **medio** sigue en `1/2`, pero la curva corta depende de la varianza admitida.

## P5 · Recomendación de lectura del resultado

- `α_mínimo = 1/2` (media, ambos regímenes): ZEROX está **en la liga de PoW**; el problema de la
  poda/IBD es de **ingeniería** (como la *weak subjectivity*), no de umbral.
- El `SR` endógeno **no** baja el umbral medio (dirección irrelevante); su riesgo real es de
  **varianza/opcionalidad** y lo acotan P1–P3.
- El **multistream** (PoT), **si** el diseño lo permite, sí baja el umbral (`α_min = 1/(S+1)`); es
  el único resultado de este informe que rompería el consenso, y está **condicionado** al diseño
  del flujo, no demostrado.
