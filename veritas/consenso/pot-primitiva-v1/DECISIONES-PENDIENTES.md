# DECISIONES-PENDIENTES — P-POT

Decisiones que **no me tocaban a mí** (encargo §5): presentadas con lo que gana, lo que paga
y lo que cierra cada opción, y mi recomendación marcada. **D-1 y D-2 decididas por Katana el
2026-09-19** (veredictos registrados abajo); D-3, D-4 y D-5 siguen como están.

---

## D-1 · Hash de derivación del PoT: conservar blake3 (A) o pasar a H_d (B)

**DECIDIDA por Katana el 2026-09-19: Opción A — conservar `blake3` byte a byte, como
Autonomys.** Motivo registrado de Katana: el oráculo diferencial es lo único independiente que
acredita el port, y el SPEC ya tiene precedente de excepción documentada en C-NET-07. Coincide
con mi recomendación. El análisis completo se conserva abajo como registro de la decisión.

**Qué decide:** el hash de las cinco derivaciones del PoT — semilla con inyección (C-POT-01),
clave AES (`blake3(seed)[0..16)`, C-POT-02), aleatoriedad y reto (C-POT-03) y la entropía
futura (si se adopta la forma de Autonomys).

**Opción A — conservar `blake3` byte a byte, como Autonomys.**

- **Gana:** los 32 vectores diferenciales de `pot-estable` siguen valiendo tal cual
  (`prototipos/pot-estable/LEEME.md:26-37`), y con ellos la **única validación externa del
  port** (byte a byte contra `subspace` @ `f8842d0`, verificado por mutación). El `prove`/
  `verify` de la primitiva no cambia ni una línea. Comparación directa con la fuente en
  cualquier auditoría futura.
- **Paga:** rompe la convención `H_d = SHA3-256(tag ‖ m)` de C-HASH-06
  (`SPEC.md:374, 558-584`) en todo el dominio PoT. Las derivaciones quedan sin etiqueta de
  separación de dominio: las entradas `(entropía ‖ salida)`, `(aleatoriedad ‖ LE64(s))` y
  `(seed)` tienen longitudes fijas y prefijos distinguibles, pero no hay tag explícito.
- **Cierra:** pasar después a `H_d` sin regenerar vectores; la equivalencia byte a byte con
  la fuente queda atada a que se conserve blake3.
- **Precedente a favor:** el SPEC ya admite divergencias deliberadas de sus propias
  convenciones cuando hay motivo — C-NET-07 usa «SHA3-256 simple» para los IDs cortos
  (`SPEC.md:2552`, «divergencia deliberada»).

**Opción B — pasar a `H_d = SHA3-256(tag ‖ m)` con etiquetas nuevas (familia `ZZKPot…`).**

- **Gana:** coherencia total con C-HASH-06 y separación de dominio explícita para las cinco
  derivaciones.
- **Paga:** invalida la equivalencia con Autonomys — la clave AES ya no es
  `blake3(seed)[0..16)`, así que `prove`/`verify` de `pot-estable` cambian y los 32 vectores
  diferenciales **dejan de ser una validación**: hay que regenerar un juego propio de
  vectores (trabajo nuevo y la pérdida del contraste externo). SHA3-256 es más lenta que
  blake3 por byte (irrelevante: una pasada por slot frente a 92 ms de AES).
- **Cierra:** la comparación directa con la fuente y la reutilización sin cambios de
  `pot-estable`.

**Recomendación (mía, aceptada por Katana): Opción A.** La validación externa byte a byte es el
único respaldo independiente del port, y el precedente C-NET-07 muestra que el SPEC ya admite
divergencias deliberadas y documentadas. El coste real de B no es la coherencia estética sino
perder el oráculo: cada vector nuevo que se genere sin oráculo externo es un vector que solo
se autovalida. Si Katana elige B, propongo que la regeneración de vectores sea un encargo
separado con su propia verificación por mutación (mismo protocolo que el LEEME de
`pot-estable`).

---

## D-2 · Qué es el `pot_output` único de la cabecera

**DECIDIDA por Katana el 2026-09-19: Opción A — `pot_output = salida(f, s + D)` (la salida
futura).** Motivo registrado de Katana: conserva el ancla interna de Autonomys, y con la
corrección de la caché por slot su coste casi desaparece; C decide un parámetro (`D`) que
todavía no toca decidir. Coincide con mi recomendación. El análisis completo se conserva
abajo como registro de la decisión.

**Qué decide:** la cabecera DAG de ZEROX lleva **un solo** `pot_output` en `[88,104)`
(`SPEC.md:834`). Autonomys lleva dos en el pre-digest: `proof_of_time` (slot `s`) y
`future_proof_of_time` (slot `s + D`)
(`PDF/autonomys-subspace/crates/sp-consensus-subspace/src/digests.rs:56-86`). El SPEC **no
determina** cuál es el campo de ZEROX (C-HDR-07 no lo dice). Las tres opciones, con `D` =
retardo de autoría (símbolo):

**Opción A — `pot_output = salida(f, s + D)` (la future).**

- **Gana:** la justificación se verifica de una pieza: el último checkpoint del último
  portador **MUST** ser `pot_output`, exactamente el ancla de Autonomys (`verifier.rs:259-262`),
  y `pot_bundle_count == slot(B) − slot(sp(B))` cuadra con el rango
  `(slot(sp)+D, slot(B)+D]` de R-FIN-14(d). La semilla del primer slot del rango es derivable
  del pasado validado sin tocar el candidato.
- **Paga:** el reto del slot `s` usa `salida(f, s)`, que **no** está ni en la cabecera ni en
  la justificación de `B`: sale de la caché por slot (C-NET-31) o del gossip. En el camino
  **bajo demanda** (C-NET-32), la justificación de `B` no basta para derivar el reto de `s`:
  hay que verificar el slot `s` aparte o retener el bloque.
- **Cierra:** derivar el reto del slot `s` de la propia cabecera de `B`.

**Opción B — `pot_output = salida(f, s)` (la proof del propio slot).**

- **Gana:** el reto del slot `s` se deriva directamente del campo de la cabecera del bloque
  del slot `s`.
- **Paga:** el reto dependería de un **campo declarado por el propio bloque**: para no
  violar R-FIN-14(e) (grindeo del reto) y el principio de C-HDR-06, `pot_output` tendría que
  comprobarse contra la caché del slot `s` **siempre**, con lo que la caché se vuelve
  necesaria también para el reto (lo que A paga solo en el camino bajo demanda). Y la
  justificación de `B` (rango `(sp+D, s+D]`) **no contiene** `salida(f, s)`: el ancla
  «último checkpoint == pot_output» deja de existir, y hay que derivar una regla de
  comprobación distinta para el campo (contra caché, y fuera de la cadena AES que B
  justifica). El campo queda como redundancia comprobada estilo C-HDR-06, pero verificado
  contra la caché en vez de contra la cadena que trae el propio bloque.
- **Cierra:** la verificación de la justificación con ancla interna (el patrón de Autonomys).

**Opción C — `D = 0`, una sola salida porque future = proof.**

- **Gana:** cuadra todo con una salida: el rango es `(slot(sp), slot(B)]`, el último
  checkpoint == `pot_output == salida(f, s)`, y el reto sale de la cabecera sin depender de
  un campo no comprobado por la cadena que el bloque trae.
- **Paga:** decide **el valor de `D`**, que es un parámetro fuera de mi alcance (encargo §4):
  pierde el retardo de autoría y el anclaje anticipado de la cadena `D` slots por delante
  (la razón de ser de la future en Autonomys, `slot_worker.rs:391-479`). No puedo
  recomendarlo sin que P-2.1 cierre `D`.
- **Cierra:** el anclaje anticipado; la pregunta se responde cambiando un parámetro, no
  eligiendo la semántica del campo.

**Recomendación (mía, aceptada por Katana): Opción A.** Es la única que conserva el ancla interna
«último checkpoint == `pot_output`» sin decidir `D` y sin hacer que el reto dependa de un
campo declarado por el propio bloque. Su coste —el reto del slot `s` sale de la caché— es un
coste que C-NET-31 **ya paga** de todos modos: el PoT se verifica por slot
independientemente de los bloques. B paga lo mismo y además debilita el ancla; C decide un
parámetro que no me toca.

---

## Otras bifurcaciones reales encontradas

**D-3 — Cómo se representa la inyección en el contexto del verificador.** La interfaz actual
(`ContextoVerificacionPot`, `crates/zx-core/src/wire_dag.rs:355-364`) no tiene entropía. La
propuesta fija que el contexto entrega la **semilla ya inyectada** por slot del rango (la
derivación blake3 de C-POT-01 queda dentro del contexto, no en el verificador). Alternativa:
entregar entropías crudas y dejar la mezcla al verificador. **Recomiendo la primera** (el
verificador nunca ve entropía; menos superficie), pero es una decisión de interfaz de nodo,
no de consenso: no bloquea el SPEC. No requiere decisión de Katana ahora.

**D-4 — Qué hace el nodo con un bloque `Pendiente` por presupuesto agotado** (retener sin
plazo, descartar con re-petición, o pedir el slot por gossip). La propuesta fija solo el
**estado** (`Pendiente`, nunca `Inválido`); la política de retención la cubre parcialmente
C-NET-32.2 y su calibración está en el v2b (Q5, `SPEC.md:3007-3009`). No la abro aquí.

**D-5 — La clave de la caché incluye el flujo completo de 32 B.** La propuesta usa el
identificador opaco completo (lo que el contexto ya entrega). Si un día el flujo se
representara como raíz de algo mayor, un prefijo bastaría; hoy no hay motivo para truncar y
truncar reintroduce el riesgo de colisión entre flujos. Decisión tomada en la propuesta; no
requiere a Katana.
