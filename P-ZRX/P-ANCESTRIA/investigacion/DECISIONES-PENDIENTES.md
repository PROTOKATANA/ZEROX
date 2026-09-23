# DECISIONES-PENDIENTES — P-ANCESTRIA / ANR-v0.1

Bifurcaciones reales para Katana. Ninguna la resuelve este instrumento: varias exigen fijar una
política de seguridad, y una exige un dato que no está medido. Se ordenan por lo que desbloquean.

Las cifras citadas salen de `veritas/consenso/ancestria-reto-v1/resultados/`.

---

## D-A · ¿Se acepta la profundidad de anclaje que el flujo **ya** tiene?

**Qué se decide.** Si la ventana de reto compartido del flujo —`(0, I_slots + L_slots]` slots,
*derivado de las reglas vigentes* (`C-FLU-03`/`04`/`10`/`21`), no medido— se declara suficiente como
cumplimiento de P4, o se quiere acortar.

**Por qué importa.** Es la diferencia entre «ZEROX ya paga el recurso por ancestría a esa
profundidad» y «hay que añadir un eje de anclaje». Todo lo demás de este encargo cuelga de aquí.

| Opción | Qué cuesta | Qué falta para decidirla |
|---|---|---|
| **A1 · Dejarlo como está y declararlo** | cero reglas nuevas; la ventana queda como cota, sin valor | saber si `I_slots + L_slots` es corto frente a la duración de un ataque de doble gasto, que depende de `Δ` real (no medida) |
| **A2 · Acortar la ventana bajando `L_slots` y/o `I_slots`** | menos margen frente al desacuerdo honesto y a particiones; `L_slots` ya está atado a `F_slots` por `C-FLU-01` | la cola de desacuerdo de cadena seleccionada a la `ε` elegida, y una cota de `Δ` **medida en red real**; hoy `Δ` es simulada |
| **A3 · Añadir ancla a profundidad `d` explícita** | `umbral(d) < 1/2` para todo `d` finito, y ventana `d+1` bloques; pipeline del productor invertido; `C-FLU-10/12`, `C-HDR-06`, `C-GD-10`, `C-FLU-20/21` reescritas | aceptar un umbral objetivo (D-B) |

**Recomendación del instrumento, y su límite:** A1 es lo único que **no** baja el umbral, y es
gratis en reglas. No es una recomendación de seguridad: es que A3 no puede mejorar el umbral y A2
exige un dato que no existe. **No se fija `L_slots` ni `I_slots`.**

---

## D-B · Si se elige A3: ¿qué umbral se acepta?

**Qué se decide.** El umbral objetivo `β` de `umbral(d) = 1/(1+φ_{d+1}) ≥ β`. Es una decisión de
política, no derivable: el instrumento da el **tipo de cambio** y no puede elegir el punto.

| `β` objetivo | `c = d+1` mínimo | ventana de reto compartido |
|---:|---:|---:|
| 0,30 | 2 | 2 bloques |
| 0,35 | 5 | 5 |
| 0,40 | 14 | 14 |
| 0,45 | 86 | 86 |
| 0,48 | 798 | 798 |
| 0,49 | 4 019 | 4 019 |
| 0,495 | 19 457 | 19 457 |
| 0,500 | **no alcanzable con `c` finito** | — |

**Lo que hay que decir en voz alta:** `0,5` **no es alcanzable** con ningún `d` finito; es el valor
del diseño vigente. Elegir A3 es elegir pagar umbral.

---

## D-C · ¿Se escribe en el SPEC la profundidad de anclaje efectiva del flujo?

**Qué se decide.** Si `C-FLU-10`/`C-FLU-13` incorporan una frase del tipo «dos ancestrías que
difieren sólo por debajo de `T_j + L_slots` comparten reto», o se deja implícito en las reglas.

**Por qué importa.** Es exactamente la propiedad que el repositorio **no** tenía escrita y que hizo
que el encargo partiese de una dicotomía incompleta (`PROMPT.md:151-153`). Sin la frase, la próxima
auditoría vuelve a deducir «`d = ∞`, transferibilidad sin límite». **Es una decisión de redacción con
consecuencia de seguridad**, no cosmética.

**Coste:** ninguna regla de consenso cambia; no se fija ningún parámetro. **Riesgo:** escribir una
cota como si fuera un valor.

---

## D-D · §6.1: ¿se reabre o no? (discrepancia declarada)

**Qué se decide.** Si el anclaje del reto a `anc_d(B)` obliga a reabrir la cabecera.

`veritas/consenso/poda-post-v1/INFORME.md:144-147` anticipa que sí. Este informe sostiene que **no**:
`anc_d(B)` es derivado de `past(B)` (`C-GD-09`) y `C-HDR-06` ya deriva el rango esperado de
`past(B)` y del flujo, sin campo nuevo. El ejemplo que ese informe da («el desafío dependa del hash
de los padres») sí podría exigir campo; `σ(B)` no.

**Qué hace falta para cerrarlo:** una revisión de `C-HDR-06` y de las entradas del retarget
(§7.2 / `P-ZRX/P-RANGO/`) por alguien distinto del autor de este informe. **No lo decido yo.**

---

## D-E · El valor de `L_suelo_slots`

**Qué se decide.** `C-FLU-01` deja `L_suelo_slots` como `<<PENDIENTE>>` (líneas 1546-1550) y
`L_slots := máx(F_slots, L_suelo_slots, S_max_slots + 1)`. La ventana de F5 depende de `L_slots`
linealmente.

**Qué falta.** (a) la cola de desacuerdo de cadena seleccionada a una `ε` elegida explícitamente;
(b) una cota de `Δ` **medida en red real**. Mientras no exista (b), cualquier valor es provisional
—lo dice la propia regla— y esta investigación **no lo estima**.

---

## D-F · ¿Se modela el PoT y sus flujos, que es lo que la revisión pedía?

**Qué se decide.** Si se encarga el modelo que `poda-post-v1/PROCEDENCIA.md:117-119` señala y que
este instrumento **no** hace: el PoT y sus flujos como objetos que pueden ramificarse, «donde
historias distintas podrían generar retos distintos».

**Qué se sabe ya, de este informe.** El flujo **no** es un objeto único intocable: se ramifica, y lo
hace en el primer corte de vista que cruza la divergencia (§F5.2). Lo que falta es modelar la
ramificación del **PoT** en los puntos de inyección, que es una fuente de divergencia **distinta** de
la del DAG y que aquí se trata como supuesto.

**Coste:** encargo nuevo; el instrumento de este encargo no lo cubre.

---

## Lo que este informe deja **inconcluso** a propósito

- Si `I_slots + L_slots` slots es «suficientemente corto»: **inconcluso con esta evidencia**, y falta
  la `Δ` medida en red real y la cola de desacuerdo a la `ε` elegida.
- Si la regla **literal** (reto dependiente de ancla **y** slot) se identifica con la c-correlación
  de BDK+19: **no determinado**; se declara la dirección del error (el umbral publicado es cota
  superior de la seguridad).
- El coste de I/O del productor honesto bajo ancla a `d`: **no medido** (no hay granja).
- El grinding público por elección del inyector de la cadena pública: **no modelado** por BDK ni por
  este instrumento; sigue abierto desde la ronda 4 de la investigación.
