# ARQUITECTURA — propuesta de pool para ZEROX

> **Estatuto de este documento.** Es una **propuesta de arquitectura**, no texto de `SPEC.md`. No fija ningún parámetro de consenso, no cierra ningún `<<PENDIENTE>>` y no reabre ninguna decisión de Katana. Cada elemento lleva marcado si es **arquitectura/recomendación** o **regla de consenso propuesta**. La distinción es la que decide si algo protege de verdad contra un operador hostil: **una recomendación no impide nada a un operador hostil y no se presenta aquí como si lo hiciera.**

**Punto de partida.** `INFORME.md` establece que, con el SPEC actual, la **firma ciega** (arquitectura 3) permite a un operador hostil producir bloques para cualquier rama con el espacio de sus granjeros y cobrar él. Este documento describe la arquitectura que hace que eso **no ocurra**, y las dos reglas —una de consenso, una de implementación— que lo hacen **no rentable** y **no reutilizable**.

---

## 1 · Principios

`[D]`

1. **La parcela es la capacidad de probar; la clave privada es la capacidad de autorizar.** El diseño debe mantenerlas separadas en **manos distintas de las del pool**: el pool no tiene ninguna de las dos.
2. **El pool no compone cabeceras.** Si el pool nunca produce un `pre_hash`, nunca puede pedir una firma sobre uno. Ésta es la propiedad que de verdad impide la firma ciega; las demás la refuerzan o la hacen inútil.
3. **La parcial es contabilidad, no autorización.** Debe ser **imposible por construcción** que una firma de parcial verifique como sello de bloque.
4. **El pool no aparece en la parcela.** La parcela se plotea a la clave del granjero, nunca a la del pool.
5. **Nada de lo anterior es verificable en cadena.** El consenso no puede comprobar intención; solo puede atar consecuencias (a quién paga la coinbase) y hacer que ciertos mensajes no se confundan (separación de dominio).

---

## 2 · Reparto de funciones

`[P]` (propuesta; el reparto de Chia está `[VF-ext]` en `INFORME.md` §1.2, arquitectura 4, y sirve de precedente, no de autoridad para ZEROX).

| Función | Granjero | Pool | Por qué |
|---|---|---|---|
| Custodia de la parcela | **Sí** | **No** | Si el pool tiene copia, puede probar sin el granjero (`[VF]` `INFORME.md` §1.1.1) |
| Custodia de la clave del billete | **Sí** | **No** | Es lo único que autoriza |
| Auditoría de la parcela contra el reto del slot | **Sí** | No | Requiere lectura de la parcela |
| Elección de padres (`C-GD-10`) | **Sí** | **No** | Es política de producción, no verificable; si la elige el pool, el pool elige la rama |
| Construcción de la cabecera y del cuerpo | **Sí** | **No** | Es la propiedad clave (principio 2) |
| Elección de la coinbase | **Sí** | **No** | Quien la elige, cobra |
| Sello Ed25519 sobre `pre_hash` | **Sí** | **No** | `C-HDR-04` |
| Cálculo de `rango_solucion` contextual | **Sí** (su nodo) | No | `C-HDR-06` |
| Justificación PoT | la aporta el bloque; es pública | — | `C-HDR-07` |
| Verificación del bloque | **Sí**, antes de firmar | No (puede, pero no decide) | Es la validación que impide la firma ciega |
| Contabilidad de parciales y reparto | envía parciales | **Sí** | Es el cometido del pool |
| Anuncio/relé de puntas | su propio nodo | opcional | Si el pool es la única vista, puede servir una vista privada (`INFORME.md` §1.4.2) |

`[P]` **El granjero SHOULD ejecutar su propio nodo.** No es una regla de consenso; es lo que evita que el pool controle la vista desde la que el cliente valida. El modelo de Chia lo permite explícitamente en sentido contrario («The full node can either be run by the farmer…, or run by the pool operator», `[VF-ext]`); **en ZEROX esa comodidad reintroduce el problema**, porque el cliente validaría contra la vista del atacante.

---

## 3 · Protocolo, paso a paso: qué se firma y qué no

`[P]` Tres pasos. El **pool no participa en ninguno de los dos que producen autorización**.

### Paso 1 · Parcial (contabilidad)

El granjero audita su parcela contra el reto público del slot y, si encuentra una solución cuyo `solution_distance` cae dentro de un `partial_range` **más fácil** que el de consenso (`partial_range > solution_range`), envía:

```text
parcial := ( pool_id, identidad_de_oportunidad, slot,
             campos de la solución,          // public_key, sector_index, history_size,
                                             // piece_offset, chunk, testigos, proof_of_space
             nonce_de_sesión )
firma_parcial := Ed25519( clave_del_billete, H_d("ZZKPoolPartial__", serialización_canónica(parcial)) )
```

`[P]` Reglas del paso 1:

1. **La parcial se firma sobre un dominio propio** (`H_d` con etiqueta distinta de `ZZKBlkPreHash___`). Como los dos mensajes son distintos y `H_d` es inyectiva por prefijo fijo (`C-HASH-04`), **la firma de parcial no puede verificar jamás como sello de bloque**. `[VF]` la construcción de `H_d` está en `SPEC.md:374-382`; la etiqueta del sello, en `SPEC.md:586`.
2. **La parcial no autoriza nada.** El pool la usa para puntos/pagos; no la publica como bloque ni la reenvía como cabecera.
3. **El pool no responde con un `pre_hash`.** No hay ningún mensaje del pool que el cliente del granjero firme como sello de bloque. Ésta es la propiedad que cierra la firma ciega.
4. `[P]` El `nonce_de_sesión` evita que una parcial antigua se reutilice como prueba de trabajo presente; su forma queda abierta (no se fija aquí).

> `[P]` **Estatuto del paso 1.** El uso de un dominio propio es **recomendación de implementación**. Si Katana quiere que sea **normativo e interoperable**, la etiqueta `ZZKPoolPartial__` debe entrar en la tabla de `C-HASH-06` (`SPEC.md:563-589`), y como `C-HASH-05` (`:384-385`) declara que **añadir una etiqueta es un cambio de consenso**, eso convierte el paso 1 en un cambio de consenso. **No añade seguridad** —la seguridad ya la da usar etiquetas distintas—; añade que ninguna implementación pueda usar el mismo dominio para las dos cosas. Es una decisión de estilo normativo, no una defensa.

### Paso 2 · Bloque (autorización)

`[P]` El cliente del granjero, **desde su propio pasado validado**:

```text
1. Elegir padres con C-GD-10 sobre su propia cola de candidatos          // el granjero, no el pool
2. Calcular rango_solucion con C-HDR-06 desde past(B)                    // el granjero
3. Fijar slot y pot_output conforme a C-HDR-05 / C-HDR-07               // el granjero
4. Construir el cuerpo; la coinbase paga a sol.public_key (regla §4)     // el granjero
5. Ensamblar la prefirma y calcular pre_hash = H_d("ZZKBlkPreHash___", prefirma)
6. Verificar el candidato como lo haría un verificador (C-POT-08, C-FLU-13)
7. Consultar el registro del «firmante seguro» por (identidad_de_oportunidad, slot); persistir
   el pre_hash de forma durable y ATÓMICA; sólo entonces
8. Firmar pre_hash con la clave del billete  ->  sello
```

`[P]` Reglas del paso 2:

- **Paso 6 antes del 8.** Validar **antes** de firmar, no antes de publicar. Es la única propiedad que impide el hecho; los pasos 1 y 4 lo hacen además inútil.
- **Paso 7 es el firmante seguro** de `P-ZRX/P-EQUIVOCACION/investigacion/FALSOS-POSITIVOS.md:160-185`, con su registro durable anterior a la firma y la abstención de `S_max_slots` si se pierde. `[VF]` es una **propuesta de requisito de producción**, no una regla de consenso (`:154-156`).
- **No debe existir un servicio de firma genérico.** `[P]` Si por comodidad se expone un servicio remoto de firma (el patrón del nodo de Autonomys: el nodo compone el hash y el granjero lo firma), debe **rechazar** todo hash que no corresponda a una cabecera construida y verificada localmente —comparándolo con el registro del paso 7—. Un `sign(hash)` sin esa comprobación **es** la arquitectura 3.

### Paso 3 · Publicación

`[P]` El granjero publica el bloque él mismo (o lo entrega a un relé). El pool **puede** ser relé, pero entonces debe reenviar el bloque tal cual, sin reconstruirlo. Si el pool reconstruyera la cabecera, volvería a necesitar una firma.

`[D]` **Frontera y viabilidad, una línea cada una.** *Frontera:* si la parcial se definiera como «firma este `pre_hash`», los pasos 1 y 3 se anularían y la arquitectura sería la 3 — la protección no la da el nombre «Chia», la da que el mensaje firmado sea otro. *Viabilidad:* sin singleton ni lenguaje de script, **el pool no tiene vía de comisión on-chain**; Chia sí (el `p2_singleton_puzzle_hash`). Eso no toca la autorización, pero sí la adoptabilidad; va a `DECISIONES-PENDIENTES.md` D1/D2.

---

## 4 · La regla de consenso propuesta: atar la coinbase a `sol.public_key`

**Por qué hace falta una regla y no basta la arquitectura.** `[D]` Aun con el paso 1 y el paso 2, un cliente mal implementado —o un binario modificado, o un firmante remoto descuidado— sigue pudiendo firmar `pre_hash` ajenos. La arquitectura impide que eso ocurra **en un cliente honesto**; **no puede impedir que ocurra**. La palanca de consenso más directa para que **no valga la pena** es decidir **a quién paga la coinbase**, que hoy elige libremente quien construye el bloque (`INFORME.md` §1.1.2, `[VF]` `C-HDR-08`, `C-EMIT-03`).

### Texto candidato (propuesta, no SPEC)

> **`C-POOL-01 (propuesta)` · Destino de la coinbase.**
> Sea `P = sol.public_key` del bloque `B`. **Toda** salida de la coinbase de `B` **MUST** ser un `Lock::PubKey` cuyo `pubkey` sea exactamente `P`. La suma de los valores de esas salidas **MUST** seguir cumpliendo `C-EMIT-03`. Cualquier otro tipo de `Lock` en una coinbase, o cualquier `pubkey ≠ P`, **MUST** rechazarse.

`[VF]` Es expresable y comprobable con lo ya definido: `Lock` es un enum cerrado con `PubKey`, `MultiSig`, `Htlc` (`SPEC.md:625-653`), la coinbase es la primera transacción sin entradas (`C-EMIT-03`, `:2198-2199`) y `sol.public_key` está en la cabecera en `[112,144)` (`C-HDR-01`, `:841`). **No requiere lenguaje de script.** `[VF]` Y la redacción «**toda** salida … `PubKey(P)`» es **deliberadamente excluyente**, no un «que aparezca `P`»: `MultiSig{k=1, [P, pool]}` deja gastar al pool solo, y un `Htlc{receiver=pool}` con preimagen elegida por el constructor también desvía. La regla tiene que prohibir **cualquier** `Lock` que no sea `PubKey(P)`. `[D]` Por eso es un **cambio de consenso** que invalida coinbases hoy legales (con `MultiSig`, `Htlc` o varios destinos) y tendría que activarse como tal; no se decide aquí. `[D]` Su verificación **no existe** hoy: la comprobación de coinbase implementada solo suma importes (`crates/zx-consensus/src/bloque.rs:217-235`) y la ruta activa usa una cabecera lineal sin `sol`, así que la regla solo sería comprobable en la ruta DAG, hoy sin cablear. `[VF]`

### Qué compra

`[D]`

1. **Quita el beneficio directo de la firma ciega.** El pool que consigue una firma sobre su `pre_hash` puede seguir produciendo un bloque válido, pero **la recompensa va a la clave del granjero**. Robar deja de pagar.
2. **Hace inútil la sustitución de la dirección de recompensa** en la variante de la arquitectura 3 (el precedente de Autonomys, donde `reward_address` es un campo libre de la solución y el servicio de firma no lo comprueba: `[VF]` `INFORME.md` §1.2, arquitectura 3).
3. **No necesita registro, ni singleton, ni comité.** Es una igualdad entre dos campos que ya viajan en el bloque.

### Qué NO compra

`[D]`

1. **No impide el hecho.** El pool puede producir bloques para otra rama —equivocación, censura, sabotaje, fabricar evidencia para confiscar el lote— aunque no cobre.
2. **No protege de la arquitectura 2.** Si la parcela se ploteó a la clave del pool, `P` **es** la clave del pool y el pago le corresponde. Por eso el principio 4 (no plotear a clave ajena) es **independiente** y necesario.
3. **Prohíbe el pool que cobra on-chain.** El modelo de Chia —7/8 al singleton del pool, que reparte— **no es expresable aquí** sin lenguaje de script ni registro. Con esta regla, un pool legítimo solo puede cobrar por acuerdo privado (fuera de la cadena), o renunciar a comisión. Es un coste real y va a `DECISIONES-PENDIENTES.md`.
4. `[ND]` Detalles abiertos: ¿se atan también los fees? ¿una sola salida o varias a `P`? ¿se prohíben `MultiSig`/`Htlc` en la coinbase? ¿qué pasa con la capa blindada de v1.1, que hoy no existe? No se deciden aquí. `[VF]` El **agujero de los fees** es concreto: si solo se ata el subsidio y se dejan libres los fees (C1-a), el pool abre una segunda salida y se los queda, porque las tarifas entran en el tope de la coinbase (`C-EMIT-03`) y suman solo las transacciones aceptadas (`SPEC.md:2383-2384`); el robo se reabre por ahí.
5. **No es la única palanca de consenso, y no se presenta como tal.** Un refutador independiente localizó dos alternativas, ambas más invasivas: (a) **comprometer el destino en la parcela** —el análogo del `p2_singleton_puzzle_hash` que Chia hashea en el `plot_id`—, que cubre además la arquitectura 2 y la rotación de clave, pero o choca con `C-HDR-08` o cambia la derivación de `sector_id` e **invalida las parcelas existentes**; (b) **reclamo diferido** del subsidio, canjeable solo por la clave del billete, que es un rediseño de §8. Están abajo como C1-c y C1-d.

### Variantes, para comparar bajo el mismo riesgo

`[P]`

| Variante | Contenido | Lo que gana | Lo que pierde |
|---|---|---|---|
| **C1** (arriba) | **toda** salida de la coinbase a `P`, subsidio + fees | robo directo imposible | pool sin comisión on-chain; sin `MultiSig`/`Htlc` en coinbase |
| C1-a | solo el **subsidio** a `P`; los fees libres | menos restrictiva | el pool puede quedarse los fees con una segunda salida ⇒ **reabre el robo por los fees** |
| C1-b | subsidio a `P` **y** una salida extra a un compromiso de pool | conserva la comisión | necesita un mecanismo que hoy no existe (script o registro) → **no recomendada ahora** |
| C1-c | destino comprometido **en la parcela** (estilo `p2_singleton_puzzle_hash`) | cubre también la arquitectura 2 y la rotación de clave | o choca con `C-HDR-08` o cambia `sector_id` e **invalida parcelas**; es la más invasiva |
| C1-d | **reclamo diferido** del subsidio, canjeable solo por la clave del billete | quita el pago directo en la coinbase | rediseño de §8, con contabilidad y madurez nuevas |
| C0 (statu quo) | sin regla | ninguna restricción | **el pool cobra el bloque robado**: es el fallo que motiva el encargo |

`[P]` **Recomendación:** C1, con C1-a como alternativa si Katana quiere conservar un canal de comisión. Presentarlas juntas es lo que permite compararlas bajo el mismo escenario, como pide `AGENTS.md`.

---

## 5 · Arquitectura 2: por qué no se debe plotear a la clave del pool

`[VF]` `SectorId` se deriva de `public_key.hash()`, `sector_index` y `history_size` (código fijado, `subspace-core-primitives/src/sectors.rs:56-68`; verificación en `subspace-verification/src/lib.rs:228-232`). Una parcela **es** de la clave con que se ploteó y no se puede retargetear sin volver a plotear.

`[VF]` **Alcance de la premisa:** es una propiedad del **código fijado de Autonomys**, **no** una regla de `SPEC.md`. La «validación conjunta de solución de espacio, testigos KZG, distancia de solución y sello contra el reto derivado» está declarada **pendiente** (`SPEC.md:1328-1331`). Si ZEROX la implementara sin ese anclaje, esta sección perdería su base y la arquitectura 2 dejaría de estar cerrada por esta vía. `[D]`

`[D]` De ahí las dos únicas formas de que un pool use el espacio de un granjero:

- **Parcelas del granjero** (ploteadas a su clave): el pool solo puede usarlas si obtiene **soluciones + firmas**. Es el terreno de la arquitectura 3, y se cierra con §3 y §4.
- **Parcelas del pool** (ploteadas a la clave del pool, el modelo histórico de Chia con `pool_public_key`, `[VF-ext]`): el pool **es** el dueño del billete; con las soluciones le basta y firma él. **No hay ninguna regla que lo prohíba hoy**, porque no hay registro de parcelas ni el consenso puede saber a qué clave se plotearon. `[D]`

`[P]` Por tanto:

1. **Recomendación de arquitectura (no de consenso, hoy):** las parcelas **MUST NOT** plotearse a una clave que el granjero no controle; el granjero **MUST** plotear a su propia clave de billete. Cualquier pool que pida plotear a su clave está pidiendo, de hecho, la arquitectura 2.
2. `[D]` Esto **no** es verificable en cadena mientras no exista un registro de parcelas. `SPEC.md:1688-1690` ya deja abierta la puerta a «un registro de parcelas contra el sembrador»; si algún día se adopta, sería el sitio natural para exigirlo. **Hoy no existe y este documento no lo propone como regla de consenso.**
3. `[D]` La regla `C-POOL-01` **no** desincentiva la arquitectura 2: pagaría a la clave del pool, que es lo que el pool quiere. Las dos medidas son independientes y hacen falta las dos.

---

## 6 · ¿Hace falta alguna regla de consenso para que la firma ciega no sea posible?

**Respuesta directa.** `[D]`

- Para que la firma ciega **no sea posible**: **no existe tal regla de consenso.** La firma ciega es un comportamiento del cliente; el consenso no ve intenciones. Lo único que la hace imposible es que **el pool no componga `pre_hash`** (§3, principio 2) y que el cliente **valide antes de firmar** (paso 6). Eso es **arquitectura + requisito de producción**.
- Para que una firma de parcial **no valga nunca** como autorización de bloque: **basta con el dominio separado**; la regla de consenso (etiqueta en `C-HASH-06`) solo lo vuelve normativo e interoperable.
- Para que la firma ciega **no pague**: **`C-POOL-01`**, y **sí es una regla de consenso**.

**Resumen del estatuto de cada pieza:**

| Pieza | Estatuto | ¿Protege contra un operador hostil? |
|---|---|---|
| Parcela y clave en el granjero | Arquitectura | **Sí** (le quita las dos capacidades al pool) |
| El pool no compone `pre_hash` | Arquitectura | **Sí** (es la que cierra el hecho) |
| Cliente valida antes de firmar | Requisito de producción | **Sí**, en clientes honestos; no verificable en cadena |
| Dominio separado de la parcial | Recomendación de implementación | Cierra el *replay*; **no** cierra la firma ciega |
| Firmante seguro (registro) | Requisito de producción | **No** es mecanismo de seguridad (`[VF]` `FALSOS-POSITIVOS.md:192-194`) |
| `C-POOL-01` (coinbase a `sol.public_key`) | **Regla de consenso propuesta** | **Sí**: quita el premio |
| No plotear a clave ajena | Recomendación de arquitectura | **Sí** contra la arquitectura 2; no verificable en cadena hoy |

---

## 7 · Efecto sobre `P-ZRX/P-EQUIVOCACION/`: una consecuencia que hay que mirar de frente

`[VF]` El diseño candidato de ese expediente castiga la infracción estrecha —`mismo TicketId y slot + dos pre_hash distintos + dos sellos válidos`— con pérdida de las recompensas retenidas y **inhabilitación del lote** (`CANDIDATA.md:61-82`), y reconoce que «un tercero que obtenga la clave… puede por tanto provocar la confiscación del lote ajeno firmando dos veces» (`FALSOS-POSITIVOS.md:98-101`).

`[D]` **La firma ciega no requiere obtener la clave.** Con un pool de por medio, cualquier granjero puede recibir la confiscación de su lote por una firma que emitió su propio cliente a petición de otro, sin haber decidido nada. Consecuencias que la propuesta debe asumir:

1. **El castigo automático sobre evidencia de doble firma es un arma de griefing** en cuanto exista un pool hostil. `[D]`
2. `[P]` Si se adopta `C-POOL-01`, el pool **no gana** con la firma ciega, pero **sigue pudiendo** provocar la confiscación: el griefing no desaparece, solo se le quita el beneficio económico directo. `[D]`
3. `[P]` Cualquier esquema de castigo que se adopte debería declarar explícitamente que **no distingue tenedor de clave de autor**, y decidir si eso es aceptable. Este documento **no propone** un mecanismo nuevo de atribución: no lo tiene.

---

## 8 · Lo que esta arquitectura deja fuera de alcance

`[D]`

1. **La capa blindada (v1.1).** Si introduce un pool blindado con reglas propias, habrá que rehacer el cruce; aquí no se toca.
2. **El pool como custodio voluntario** (arquitectura 1): nada lo evita.
3. **El pool como único nodo del granjero**: se recomienda lo contrario, pero no se puede impedir.
4. **La comisión del pool**: `C-POOL-01` la deja sin vía on-chain. Conservarla exigiría un mecanismo (script o registro) que hoy no existe y que este documento no diseña; queda como decisión en `DECISIONES-PENDIENTES.md` D1.
5. **Cualquier activación**: hoy no hay ningún pool en ZEROX (`INFORME.md` §0.2) y este documento no propone activar nada ni fijar ningún parámetro.
