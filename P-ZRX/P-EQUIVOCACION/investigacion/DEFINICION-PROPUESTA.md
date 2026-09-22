# DEFINICION-PROPUESTA — infracción, identidad y evidencia mínima

> **Esto es una propuesta, no texto de SPEC.** No se redacta ninguna regla de consenso, no se fija
> ningún parámetro (`I`, `F`, `L`, `S_max`, `D`, `W_dec`) y no se activa nada. El SPEC lo redacta
> Claude y lo decide Katana (`PROMPT.md` §8).

---

## 1 · La infracción, propuesta

### 1.1 · Núcleo vérificable (lo que basta y no depende de ninguna rama)

```text
Dos cabeceras H₁ ≠ H₂ del formato de SPEC.md §6.1 (una de ellas, o las dos, puede ser DAG)
tales que:
  (a) pre_hash(H₁) ≠ pre_hash(H₂)
  (b) sello(H₁) y sello(H₂) son firmas Ed25519 válidas (ZIP-215) sobre su pre_hash respectivo
      bajo la MISMA sol.public_key
  (c) slot(H₁) = slot(H₂)
  (d) TicketId(H₁) = TicketId(H₂), con la identidad del §3
```

**Por qué `pre_hash` y no `block_hash`.** `block_hash = H_d("ZZKBlkHeader____", header_encoding)`
incluye el sello (`SPEC.md` C-HDR-09), y el sello Ed25519 **no es único para el mismo mensaje**:
`SPEC.md` C-HDR-04 lo declara explícitamente («C-HDR-04 no obliga al propietario a usar ese algoritmo
para elegir el nonce… puede producir firmas válidas distintas para la misma clave y mensaje») y la
regresión `crates/zx-core/tests/ed25519_no_unicidad.rs` lo comprueba con el verificador real ZIP-215
(dos firmas de 64 B distintas sobre el mismo mensaje de 32 B bajo una clave). Comparar `block_hash`
convertiría una única firma honesta en «dos bloques» y produciría **evidencia falsa**.

**Campos fuera de la prefirma.** `prefirma` es la cabecera **sin el sello**: en la base lineal
`[0, 492)`; en DAG, todo lo anterior al sello (prefijo fijo, `body_commitment`, `parent_count`,
`extra_parents`). Quedan **dentro** `prev_hash`, `merkle_root`, `slot`, `pot_output`,
`rango_solucion` y los campos de la solución (`SPEC.md` C-HDR-01, C-HDR-03). La **coinbase** no está
en la cabecera —`C-HDR-08`: «La cabecera **MUST NOT** contener la dirección de recompensa»— pero
entra por `merkle_root` (lineal) o por `body_commitment` (DAG). La **justificación PoT no entra** ni
en `pre_hash` ni en `block_hash` (`C-HDR-07`: «no entra en `block_hash`»), así que reemplazarla no
crea evidencia.

### 1.2 · Cláusula de contexto (opcional, y con su límite)

```text
(e) las dos cabeceras son válidas en su contexto (C-FLU-13)
```

**Se propone que (e) sea OPCIONAL y que la infracción dispare ya con (a)–(d).** Motivo, en
`PROPOSICIONES.md` `P4`: con validez absoluta (`C-FLU-13`) la validez de `B` es función de `past(B)`,
de modo que un nodo que sólo tiene la historia ganadora **no puede** comprobarla si la rama perdedora
no comparte flujo. Exigir (e) haría que la infracción fuese **inverificable exactamente en el caso
que la motiva**. Lo que (e) añade —que los dos bloques fueron reales y no fabricados— ya lo aporta
(b): sin la clave privada no hay segundo sello.

**Efecto de dejar (e) fuera, que hay que aceptar:** dos firmas honestas de una misma oportunidad
(FP1–FP5 de `FALSOS-POSITIVOS.md`) disparan la infracción. Por eso el **firmante seguro**
(`FALSOS-POSITIVOS.md` §3) no es un añadido: es la **condición de viabilidad** de la infracción.

---

## 2 · Dónde vive la infracción

**No** en la validez absoluta del bloque (`C-FLU-13`): un bloque que duplica un billete es **válido**
en su rama y así lo mide `veritas/seguridad/coste-rama-privada-v1/INFORME.md` §6 («Mismo billete en
dos ramas disjuntas: ambas válidas y azules en su propia rama»). La infracción es **económica**: vive
donde vive el castigo de `CANDIDATA.md` §6 (recompensas retenidas y habilitación del lote). Esto es
coherente con la decisión ya tomada de que el doble uso entre ramas **no es fraude hoy**.

**Alcance de la infracción, dicho sin adornos.** Castiga el doble uso **publicado**. Un atacante que
sólo publique la rama que va ganando no produce el par de bloques y **ninguna identidad de billete lo
alcanza** (`PROPOSICIONES.md` P10). La infracción no sustituye, por tanto, a la seguridad del consenso
base; es una capa de coste, exactamente como la describe `CANDIDATA.md` §«Lo que no debe prometer».

---

## 3 · Identidad de oportunidad recomendada

**Recomendación:** la de IDV-01, tal como está en
`veritas/consenso/identidad-disponibilidad-v1/CONTRATO-VALIDACION.md`, o la de `CANDIDATA.md` §3,
porque ambas son **más gruesas** que la de `C-GD-07` en la dirección que importa:

```text
TicketId := H_d( ETIQUETA_OPORTUNIDAD ‖ dominio_económico ‖ LE64(slot)
                 ‖ public_key ‖ LE(sector_index) ‖ LE(history_size) ‖ LE(piece_offset) )
```

**Por qué no la de `C-GD-07`/R-FIN-11.** Porque incluye `chunk` y **no** incluye `piece_offset`:

| Efecto | `C-GD-07` | IDV-01 / `CANDIDATA` |
|---|---|---|
| Misma pieza, dos soluciones ganadoras con `chunk` distinto | **TicketId distintos** → sin evidencia | **mismo TicketId** → evidencia |
| Dos `piece_offset` con el mismo `chunk` | **mismo TicketId** → falso positivo estructural | distintos → correcto |
| Medido en el enumerador (`misma-parcela`) | `κ_comun` cae de 1.000 a 0.000 según `m` | `κ_comun = 1.000` en toda la columna |

`chunk` es redundante **dentro de una clase validada con contexto fijo** —argumento condicionado a
binding KZG en `veritas/consenso/identidad-disponibilidad-v1/IDENTIDAD.md` §3— pero **no** lo es
**entre contextos** (§3, párrafo «La equivalencia entre soluciones de **distintos** C no queda
resuelta»), y la doble firma entre ramas es precisamente el caso entre contextos.
`piece_offset` **no** se puede omitir: cambia la semilla PoS y la selección de pieza
(`IDENTIDAD.md` §3, medido en `prototipos/poas-identidad/`).

**Pendiente que la propia fuente deja abierto y que aquí no se cierra:** «qué retos y raíces
alternativos del mismo slot pertenecen a la misma oportunidad en ZEROX»
(`CONTRATO-VALIDACION.md` §1, «Bloqueante pendiente»). La propuesta **no** mete el flujo ni el reto en
la clave. Hacerlo daría al atacante una salida gratis por el ancla (`P4`); no meterlo exige aceptar
que dos retos distintos del mismo slot con la misma pieza son la misma oportunidad, que es lo que
`P7` mide como favorable.

---

## 4 · Evidencia mínima verificable

### 4.1 · Qué hace falta, en bytes

| Elemento | Tamaño | Fuente |
|---|---:|---|
| Cabecera mínima (`P = 1`), con sello | 589 B | `SPEC.md` C-HDR-01 |
| Cabecera máxima (`P = 15`), con sello | 1 037 B | `SPEC.md` C-HDR-01 |
| Sello Ed25519 | 64 B | `SPEC.md` §6.1 |
| `pre_hash` | 32 B | `SPEC.md` C-HDR-03 (salida de `H_d`) |
| Justificación PoT codificada, máxima | 19 201 B | `SPEC.md` C-HDR-09 (`1 + 150 × 128`) |

**Evidencia mínima con (a)–(d) — autocontenida:**

```text
2 cabeceras × (589 … 1 037 B)   =  1 178 … 2 074 B
+ 32 B de cada pre_hash (derivables, no hace falta transportarlos)
```

**Respuesta literal a la pregunta del encargo (¿bastan firma, solución PoAS y reto del slot?).**

| Con (a)–(d) | ¿Basta? |
|---|---|
| las dos **firmas** (sellos) | **sí y es imprescindible**: es lo que prueba la doble firma y lo que no se puede fabricar sin la clave |
| el **slot** | **sí**: es un campo de la prefirma (`[80, 88)`, `C-HDR-01`) y entra en la identidad |
| el **`TicketId`** | **sí**: sale de campos de la prefirma, no hace falta transportarlo |
| la **solución PoAS** y el **reto del slot** | **no hacen falta** para (a)–(d). Sólo hacen falta para (e), y sólo para la cabecera perdedora: la ganadora ya está validada en la historia del nodo |
| el **flujo** que da el reto | **no hace falta** para (a)–(d). Hace falta para (e), y **basta derivarlo de la historia del propio nodo si las dos ramas comparten flujo** (`P3`); si no lo comparten, (e) es **inverificable** para quien no tenga la rama perdedora |

Por eso se propone que (e) sea opcional: exigirla convierte la evidencia en algo que **sólo el
atacante y quien tenga su rama pueden comprobar**.

**Evidencia con (e) — no autocontenida:** hay que añadir la justificación PoT de la cabecera
perdedora (hasta **19 201 B**) y, para la solución PoAS, el contexto (raíz de historia, compromiso de
segmento, parámetros de retención) que `veritas/consenso/identidad-disponibilidad-v1/CONTRATO-VALIDACION.md`
§2 (IDV-02) exige resolver **desde la historia candidata autenticada**. Ese contexto **no lo tiene**
un nodo que sólo conserva la historia ganadora si el flujo no coincide.

### 4.2 · Coste de verificación

| Paso | Coste | ¿Necesita la rama perdedora? |
|---|---|---|
| Recalcular `pre_hash` de cada cabecera | 1 `SHA3-256` por cabecera | no |
| Verificar los dos sellos (ZIP-215) | 2 verificaciones Ed25519 | no |
| Comparar `slot` e `TicketId` | comparación de enteros y de campos | no |
| Comprobar (e) para la ganadora | ya está en la historia | no |
| Comprobar (e) para la perdedora | derivar `flujo(B', slot(B'))` del **pasado validado** (`C-FLU-14`, estructural, **sin AES**) + verificar la solución PoAS | **sí, salvo que los flujos coincidan** (entonces basta la historia del verificador, `P3`) |

La comprobación estructural del flujo es explícitamente **sin AES** (`SPEC.md` C-FLU-14, nota: «No
necesita AES, y está demostrado»). Lo que **sí** cuesta es recomputar cadena y flujo del sub-DAG
ajeno — superficie de DoS, bajo el presupuesto de `C-NET-33`, donde agotarlo da `Pendiente`, nunca
`Inválido`.

### 4.3 · Plazo tras la poda

- **Las firmas y (a)–(d) son verificables para siempre**: dependen sólo de las dos cabeceras. Un nodo
  que guarde 1 178–2 074 B por evidencia no necesita nada más.
- **(e) caduca con la historia.** `SPEC.md` §17 declara la **poda pendiente**: no hay profundidad de
  retención cerrada (`C-GD-11` tiene sus cinco valores `<<PENDIENTE>>`) ni regla que obligue a
  conservar la rama perdedora. Mientras eso siga así, el plazo de (e) es **indeterminado**, y decirlo
  es parte de la propuesta: **la infracción debe definirse sobre lo que no caduca**.
- Si se conserva la **caché de PoT por slot** (`C-POT-07`, clave contextual `(f, s, semilla, N)`) o
  los bloques de la rama perdedora, (e) sigue siendo verificable; ninguna de las dos está garantizada
  por una regla vigente.

### 4.4 · Qué impide fabricar una prueba contra un honesto

1. **La firma.** Las condiciones (a)–(d) son **autenticadas por el sello**: no hay forma de producir
   el segundo sello sin la clave privada. Alterar cualquier campo de la prefirma cambia `pre_hash` y
   **invalida** el sello existente; no se puede reciclar.
2. **La no unicidad del sello no ayuda al acusador.** Un tercero puede provocar dos sellos válidos
   sobre el **mismo** `pre_hash` (C-HDR-04)… pero eso **no** satisface (a), que exige `pre_hash`
   distintos. La no unicidad sólo obliga a comparar `pre_hash`.
3. **Lo que el firmante seguro NO impide, y hay que escribirlo:** un tercero que **obtenga** la clave
   (FP6) o que simplemente **presente** dos bloques que el honesto ya firmó sin mala fe (FP1–FP5) no
   está fabricando nada: la evidencia es real y el castigo caería sobre un inocente. La defensa
   contra esto **no es criptográfica**, es el firmante seguro + la decisión de castigo
   (`FALSOS-POSITIVOS.md` §3.4.2).
4. **Griefing por §7.2.** Un tercero no puede firmar por el honesto, pero el propio honesto produce
   el material del castigo al reusar su billete liberado por un reorg (FP7). De nuevo: se resuelve
   con el firmante seguro, no con criptografía.

---

## 5 · Qué reglas vigentes tocaría

> Propuesta. Ningún texto de abajo es SPEC.

| Regla / texto | Qué habría que decidir | Por qué |
|---|---|---|
| **`SPEC.md` §7.2** y el vector `fixture_reorg_libera_billete` | ⚠️ **RETIRADA — ver la «Nota de Claude» al final de este documento: NO es una contradicción.** Texto original: «Contradicción directa. Ese vector **es** la infracción estrecha. Hay que decidir: (i) la infracción manda y el firmante seguro **prohíbe** reusar el billete (coste: se pierde la recompensa de esos slots en cada reorg); (ii) §7.2 manda y la infracción **exime** el reuso posterior a un reorg, con lo que la exención se convierte en la vía de escape obvia; (iii) la exención exige prueba de que el bloque de la rama perdedora se firmó **antes** de conocer el reorg, que es una condición temporal no verificable en cadena. **Se recomienda (i)**, con el coste declarado. | `FALSOS-POSITIVOS.md` FP7 |
| **`C-GD-07` / R-FIN-11** (identidad de billete) | Sustituir la clave por una identidad con `dominio`, `slot`, `public_key`, `sector_index`, `history_size`, `piece_offset` y **sin `chunk`** (§3). Toca también la definición de U2/U3″ y la de «identidad pagable = el billete» de §7.2. | `P7`, `P8` |
| **`veritas/consenso/contrato-billete-v1/CONTRATO.md`** (CBE-v0.1) y la caché de evidencia IDV-03 | La caché **no** se indexa por `TicketId` a secas: `CONTRATO-VALIDACION.md` IDV-03 lo prohíbe («No se reutiliza por TicketId únicamente»). La infracción necesita el `TicketId` como **clave económica**, no como clave de caché; las dos cosas no se mezclan. | `CONTRATO-VALIDACION.md` §1 |
| **Producción (no consenso): firmante seguro** | Añadir el requisito de `FALSOS-POSITIVOS.md` §3 como condición de producción, con registro durable **antes** de firmar y abstención de `S_max_slots` tras perderlo. | FP1–FP5 |
| **`C-GD-10`** (elección de padres) | **NO tocar.** El barajado de la cola de candidatos es lo que evita perder 14–21 bloques honestos por slot; quitar el barajado para reducir FP1 cambiaría un falso positivo por una pérdida sistemática. `SPEC.md` C-GD-10 lo dice con medición. | FP1 |
| **`C-GD-11`** (*bounded merge depth*) | **Fijar su valor** (hoy `<<PENDIENTE>>`, cinco incógnitas) **antes** de evaluar la alcanzabilidad del escape de `P4`: la fusión de un bloque con `slot` muy anterior es justo lo que esa regla limita. | `PROPOSICIONES.md` `P10.3` |
| **CANDIDATA.md §6 (castigo)** | El castigo recae sobre «el lote». Para que eso sea operable, la identidad tiene que permitir **señalar el lote**: es lo que aporta `PlotBatchId` en la identidad de `CANDIDATA.md` y **no** la de IDV-01. Hay que decidir si la identidad económica lleva el lote o si el lote se resuelve aparte. | `CANDIDATA.md` §3 y §6 |
| **Nada de `SPEC.md` §6.1–§6.2** | El formato de cabecera, `pre_hash` y el sello **no** cambian: la evidencia se define sobre ellos tal cual están. | — |

---

## Nota de Claude (validador), 2026-09-21 — la fila de `SPEC.md` §7.2 NO es una contradicción

`DEFINICION-PROPUESTA.md` §199 y `INFORME.md` §250 registran como **«contradicción directa»** que el
vector `fixture_reorg_libera_billete` de `SPEC.md` §7.2 «es» la infracción estrecha, y plantean elegir
entre (i) que mande la infracción o (ii) que mande §7.2. **Leído el párrafo entero de §7.2, esa
disyuntiva no existe y la fila se retira.**

Lo que dice §7.2, completo: la identidad pagable es el billete; paga **exactamente una vez** en toda la
historia seleccionada; el conjunto de billetes consumidos se arrastra por la cadena y **en reorg se
reconstruye desde el génesis** sobre la rama que prevalece, retirando íntegros los efectos de la
abandonada. Liberar el billete de la historia abandonada es **la consecuencia necesaria** de esa
reconstrucción: si no se liberase, quedaría quemado por una historia que ya no existe. Su conclusión
literal es que **«un billete no puede cobrar dos veces ni siquiera a través de un reorg»**.

Son **dos capas distintas**, y conviven sin tocar §7.2:

| | `SPEC.md` §7.2 | La infracción estrecha |
|---|---|---|
| Qué regula | **contabilidad**: quién cobra, sobre la historia seleccionada | **conducta**: firmar dos veces la misma oportunidad |
| Cuándo actúa | al reconstruir la proyección económica tras un reorg | al existir dos `pre_hash` firmados |
| Efecto | libera el billete para que pueda cobrar en la rama que prevalece | castigo prospectivo sobre el lote |

**Lo que sí queda, y es menor:** el escenario que §7.2 describe —el mismo billete ganando en dos ramas
competidoras— **es indistinguible, por sí solo, de la conducta que se quiere castigar**. No hay que
cambiar §7.2: hay que **añadir** lo que separa un caso del otro, y este mismo informe ya lo entrega —el
**firmante seguro** de `FALSOS-POSITIVOS.md` §3 (un productor honesto que cambia de rama no vuelve a
firmar ese slot) y el catálogo de conductas honestas que producirían la misma evidencia—. Es un
**requisito de producción por escribir**, no una decisión entre dos reglas del SPEC.

**Procedencia del error.** Lo introdujo Claude al citar §7.2 por una línea suelta («vuelve a estar
disponible») en vez de abrir el párrafo entero, y el encargo lo heredó. Es el mismo fallo de método que
`P-ZRX/T-ZRX/AGUJEROS-Y-SOLUCIONES.md` §10 registra en su rectificación nº 7.
