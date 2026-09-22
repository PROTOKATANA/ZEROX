# HIPÓTESIS QUE CODIFICAN LA CONCLUSIÓN — retencion-clave-v1

Toda cifra de este instrumento depende de las hipótesis de abajo. Ninguna es un hecho demostrado por
el propio instrumento: si una cae, la cifra que la usa **no se sostiene**. Formato: qué afirma · por
qué es necesaria · qué la refutaría · estado.

La distinción que más importa en este encargo: **H1 y H2 no son hipótesis económicas, son el modelo
de llegada de recompensas**, y de ellas salen (M3)–(M5) y `P(B=0) = e^{−θ}`. **H3 es la hipótesis
que decide la magnitud de la grieta**, porque convierte «una clave pequeña tiene saldo cero» en «qué
fracción del espacio está en claves pequeñas».

---

## H1 · Las recompensas de una clave llegan como un proceso de Poisson de tasa `λ·f`

**Afirma.** Los bloques que gana una clave con fracción `f` del espacio llegan según un proceso de
Poisson homogéneo de tasa `λf` por slot, con llegadas independientes de su historia.

**Por qué es necesaria.** Es lo que da `N ~ Poisson(θ)` con `θ = λfT_v`, y de ahí **todo** F1: (M3),
(M4), `P(B=0) = e^{−θ}` y la cola de los pequeños.

**Qué la refutaría.** Un proceso de llegadas no Poisson: pesos heterogéneos por bloque (`P-PRESTAMO`
§5.3, «compra de varianza», `R-FIN-13′`, **no especificada**), correlación temporal (una clave que
gana tiende a ganar), o un `solution_range` que haga la tasa dependiente del historial de la clave.
Con pesos heterogéneos y elección de `sr` por el atacante, **la cola se ensancha** y `P(B=0)` deja de
ser `e^{−θ}`; el sentido del cambio es **a favor del atacante**, no en contra.

**Estado.** `condicionado`. Es una idealización declarada del modelo de recompensas, no una medición.

---

## H2 · La liberación de la retención es lineal durante `T_v`

**Afirma.** Una recompensa de valor `I` aporta `ρ_ret·I·(1 − a/T_v)` al saldo confiscable cuando su
antigüedad es `a < T_v`, y 0 después.

**Por qué es necesaria.** Fija `E[B] = ρIθ/2` (factor `1/2`) y `Var[B] = ρ²I²θ/3` (factor `1/3`). Con
liberación en escalón (`Vesting.ESCALON`, implementada y seleccionable) los momentos son `ρIθ` y
`ρ²I²θ`: **alarga el saldo medio y no cambia la conclusión cualitativa**.

**Qué la refutaría.** Un esquema de liberación con acantilado (todo retenido hasta `T_v` y después
liberado) es `ESCALON`. Una liberación ligada a auditorías superadas no es una función del tiempo: si
el saldo se libera sólo al responder auditorías, el granjero que **borra** y regenera puede cobrar
igual (`P-PERMANENCIA` F1/F2: el muestreo de piezas no prueba almacenamiento) y la pérdida deja de
estar garantizada.

**Estado.** `condicionado`. Es una elección de diseño declarada, con la variante `ESCALON`
implementada.

---

## H3 · La distribución de tamaños de clave es una ley de potencias (Pareto truncada)

**Afirma.** La fracción de espacio de una clave sigue una Pareto en `[f_min, F_max]` con exponente
`α`: `P(f > x) = (x/f_min)^{−α}`, `x ∈ [f_min, F_max]`, y el espacio total se normaliza a 1 (por eso
`α > 2` para la versión no truncada, o `F_max` finito si `α ≤ 2`).

**Por qué es necesaria.** Sin ella no hay «qué fracción del espacio tiene saldo por debajo de `b`»:
SÓLO hay `P(B=0) = e^{−θ}` **por clave**. Toda cifra de F1 «en espacio», todo F2 y todo F3 la usan.
`f_min`, `F_max` y `α` son **entradas**, no constantes: `α` **mayor** ⇒ cola más pesada hacia los
pequeños ⇒ **más** grieta; `f_min` menor ⇒ más grieta; `T_v` menor ⇒ más grieta.

**Qué la refutaría.** Una medición de la distribución real de tamaños de clave en ZEROX o en
Autonomys. **No existe.** Los operadores grandes suelen correr **muchas claves** en lugar de una
clave grande, lo que **desplaza masa hacia `f` pequeña** y **ensancha** la grieta; ése es el sesgo
más probable de H3, y va **en la dirección peligrosa**.

**Estado.** `hipótesis declarada`. **Es la hipótesis que decide la magnitud del resultado.** El
informe publica `α ∈ {2,05; 2,2; 2,5; 3}` y el resultado cualitativo (existe una cola grande) se
sostiene en todo el barrido; la **cifra** no.

**Justificación declarada del exponente.** No hay fuente en el repositorio. Las leyes de potencias
con exponente de cola ≈ 2–3 aparecen en distribuciones de riqueza y de tamaño de empresa
(«Pareto de riqueza», exponente de cola típicamente 1,5–2,5 según la definición y la muestra). Se
toma **`α = 2,2` como referencia** y se publican las sensibilidades. **No se cita ninguna fuente
externa como si fuese una medición de ZEROX.**

---

## H4 · El churn no depende de la edad, y la fracción «en arranque» es `1 − e^{−cT_v}`

**Afirma.** Las claves entran y salen a tasa `c` [fracción del espacio por slot], independiente de su
edad y de su tamaño, y el espacio de una clave no cambia con su edad.

**Por qué es necesaria.** Sólo para F1b (la fracción de espacio «siempre en arranque»).

**Qué la refutaría.** Que los grandes no abandonen (el churn esté concentrado en los pequeños), que
el espacio de una clave crezca con el tiempo, o que las salidas se correlacionen con los reorgs.

**Estado.** `condicionado`, y **no entra en ninguna conclusión**: el informe señala explícitamente
que la grieta de F1 **no** es el arranque (transitorio) sino la cola de los pequeños (`e^{−θ}`
permanente).

---

## H5 · El castigo es efectivo y prospectivo, con cobertura `κ` y probabilidad `q`

**Afirma.** Un granjero castigado pierde `ρ_ret·I·T_v + c_r + I·M`; el castigo alcanza la fracción
`κ` del doble farmeo **publicado**; la evidencia entra en la historia seleccionada con probabilidad
`q`; los pagos ya finalizados no se revierten.

**Por qué es necesaria.** Es el lado izquierdo de la condición de disuasión (F5) y toda la tabla de
adversarios de F6.

**Qué la refutaría.** `P-EQUIVOCACION` D14: quien publica **sólo la rama ganadora** no deja par de
bloques y **ninguna identidad de billete lo alcanza** ⇒ `κ = 0`. La censura de la prueba ⇒ `q = 0`.
`C-GD-07` deja escapar dos soluciones de la misma pieza con `chunk` distinto (`κ` de 1 a 0). Y `κ` no
es independiente de `α` (`P5`/`P6`).

**Estado.** `condicionado`. `κ` y `q` se barren como símbolos; la conclusión frente a `κ=0` y `q=0`
es estructural y **no depende del valor**.

---

## H6 · `ρ_ret` no cambia el reparto de bloques ni la probabilidad de ganar

**Afirma.** Retener una fracción de la recompensa **no** altera la tasa de bloques de la clave ni el
reparto de la carrera: sólo cambia **cuándo** se puede gastar la recompensa.

**Por qué es necesaria.** Es lo que permite tratar `ρ_ret` como un parámetro puramente económico,
independiente de `f` y de `λ`. `SPEC.md` `C-EMIT-05` (madurez) **sólo retrasa el gasto**: no autoriza
a confiscar, y por eso la madurez **no** es lo que se modela aquí.

**Qué la refutaría.** Que retener cambie la liquidez del granjero de forma que afecte a su capacidad
de operar (venta forzosa, impago de costes operativos), o que exista un mercado de recompensas
retenidas que las haga fungibles antes de `T_v` (adelanto, descuento, préstamo contra ellas). Si
existe ese mercado, **el saldo confiscable deja de ser el saldo del granjero** y el mecanismo se
esquiva con un descuento.

**Estado.** `condicionado`. Es una hipótesis de economía, y el mercado secundario de recompensas
retenidas **no se modela**.

---

## H7 · El granjero reclutado es racional y conoce su saldo

**Afirma.** El reclutado acepta el soborno `b` si `b > κ·q·(pérdida) − ganancia_extra`, con
`ganancia_extra = 0` (el granjero ya cobra su bloque en la rama que prevalece: unicidad pagable,
`SPEC.md` §7.2), y conoce su propio saldo.

**Por qué es necesaria.** Es el criterio de aceptación del reclutamiento, y la razón de que el
atacante pueda **ordenar por saldo**: si el granjero no supiera su saldo, el atacante no podría
seleccionar por él.

**Qué la refutaría.** Racionalidad imperfecta, información asimétrica (el atacante no conoce el saldo
de cada clave), o que el granjero no sepa que lo van a castigar. **Con información imperfecta del
atacante, la grieta se estrecha** (no puede seleccionar exactamente las claves de saldo cero), pero
no se cierra: la fracción de espacio con saldo casi cero es tan grande que **una selección al azar
dentro de ella** ya basta. Ésa es la comparación que publica F2 (`azar` vs `elegir`).

**Estado.** `condicionado`. Es la hipótesis más favorable al **defensor** dentro de este encargo: el
atacante conoce el saldo, y aun así gana.

---

## H8 · El instrumento no modela el puente espacio → tasa (y por eso no lo necesita)

**Afirma.** Todas las cifras de este encargo se calculan en **unidades de emisión** a partir de la
tasa de bloques de la clave (`λ·f`), sin derivar `λ·f` de la geometría de la parcela (distancia
circular, `sd ≤ SR/2`, chunks ganadores).

**Por qué es necesaria.** Para **no** depender de H-PUENTE, el defecto C1/D4 abierto de
`P-ZRX/P-CRP/auditoria/DEFECTOS.md` desde CRP-v0.2/v0.3. `P-PRESTAMO` tuvo que condicionar toda su F2
a H-PUENTE; aquí no.

**Qué la refutaría.** Nada dentro de este encargo: la relación «una clave con fracción `f` gana
bloques a tasa `λf`» es una **entrada** del modelo económico, y el instrumento mide el reparto del
saldo **dado** ese reparto de bloques. Si el reparto real de bloques no fuese proporcional a `f`, la
grieta cambiaría de tamaño pero **no de existencia**: seguiría habiendo claves con saldo cero (las
que no ganan bloques).

**Estado.** `condicionado`, y **declarado como no usado**. Ésta es una ventaja metodológica de este
encargo sobre su predecesor, y se dice.

---

## Lo que NO es una hipótesis de este instrumento

- **(M3), (M4) y `P(B=0) = e^{−θ}`** son consecuencias **exactas** de H1 y H2, y se comprueban por
  integración numérica independiente (68 controles). No son hipótesis.
- **La frontera de deriva `β_d > 1 − 2α`** es aritmética del reparto declarado, comprobada con
  `deriva(α, 1−2α, 0, 1, 1) = 0` y signo estricto a los dos lados. **No es una hipótesis.**
- **La forma `C(β) = max(0, β − B(ε))·coef`** es exacta en el modelo, porque `coef·f_min ≪ b` en
  todo el rango relevante y el tope por clave nunca se alcanza. Comprobado por la vía muestreada.
- **`L_h/(ingreso) = ν·ρ_ret·T_v`** es álgebra directa de la pérdida de un slot, no una hipótesis.
- **Que el greedy por ratio no sea óptimo** es un **hecho** (contraejemplo medido) y una propiedad
  NP-dura del problema, no una hipótesis.
- **Que las identidades sean gratis y el ploteo lineal en bytes** es `verificado en fuente`
  (`research/dag-poas-balizas-auditoria.md` §2, D9), no una hipótesis.
