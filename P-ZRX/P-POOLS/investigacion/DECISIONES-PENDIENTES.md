# DECISIONES-PENDIENTES — P-POOLS

Las bifurcaciones reales que este encargo deja a Katana. **Ninguna se decide aquí.** Cada una lleva: qué se decide, las opciones, qué cuesta cada una, qué evidencia falta (si falta) y el estatuto de lo que está en juego (consenso / producción / arquitectura). No se fija ningún parámetro.

Recordatorio de la distinción que gobierna todo el expediente: **una regla de consenso obliga a todos los verificadores; una recomendación de implementación no impide nada a un operador hostil.** Varias de las decisiones de abajo son de la segunda clase y no deben votarse como si fueran de la primera.

---

## D1 · ¿Se ata el destino de la coinbase a `sol.public_key`?

**Qué se decide.** Si se adopta `C-POOL-01` (`ARQUITECTURA.md` §4): en un bloque con `sol.public_key = P`, toda salida de la coinbase debe ser `PubKey(P)`.

**Opciones.**

| Opción | Contenido | Compra | Cuesta |
|---|---|---|---|
| **1 · C1** | toda salida de la coinbase a `P` (subsidio + fees) | el robo por firma ciega deja de pagar; no admite rodeo | el pool no puede cobrar comisión on-chain; nada de `MultiSig`/`Htlc` en coinbase |
| **2 · C1-a** | solo el subsidio a `P`; los fees libres | igual que C1, menos restrictiva | el pool abre una segunda salida y **se queda los fees**: reabre el robo por ahí |
| **3 · C0** | no hacer nada | no toca `C-EMIT-03` | **el pool cobra el bloque robado**: es el fallo que motiva el encargo |
| **4 · C1-c** | destino comprometido **en la parcela** (estilo `p2_singleton_puzzle_hash`) | cubre además la arquitectura 2 y la rotación de clave | o choca con `C-HDR-08` o cambia `sector_id` e **invalida las parcelas existentes** |
| **5 · C1-d** | **reclamo diferido** del subsidio, canjeable solo por la clave del billete | quita el pago directo en la coinbase | rediseño de §8, con contabilidad y madurez nuevas |

**Estatuto.** Regla de consenso (toca `C-EMIT-03`; **no** toca `C-HDR-08`, que sigue prohibiendo la dirección en la cabecera). C1, C1-a y C1-c **invalidan coinbases hoy legales** (`MultiSig`, `Htlc`, varios destinos), así que son cambios de consenso que tendrían que activarse como tales; no se decide aquí el procedimiento.

**Dos detalles que la redacción tiene que fijar, y no son cosméticos.** (i) «toda salida `PubKey(P)`» debe **excluir** cualquier otro `Lock`: `MultiSig{k=1,[P,pool]}` deja gastar al pool solo y un `Htlc{receiver=pool}` con preimagen elegida por el constructor también desvía; exigir solo «que aparezca `P`» no cierra nada. (ii) Si se elige C1-a, hay que decidir si los fees se atan o se acepta que el pool se los quede; hoy las tarifas entran en el tope de la coinbase (`C-EMIT-03`) y suman solo las transacciones aceptadas (`SPEC.md:2383-2384`).

**Lo que no resuelve ninguna opción.** El pool sigue pudiendo producir bloques para otra rama sin cobrar (equivocación, censura, sabotaje, griefing) y sigue pudiendo explotar parcelas ploteadas a su clave (`ARQUITECTURA.md` §5). `INFORME.md` §1.4.

**Evidencia que falta.** Ninguna medición; es una decisión de diseño. **No determinado:** el impacto económico de renunciar a la comisión on-chain no se ha estimado, y no se inventa.

---

## D2 · ¿El pool de farming forma parte del destino de ZEROX?

**Qué se decide.** Si ZEROX define un protocolo de pool, o si acepta implícitamente el que cada cual monte.

**Opciones.**

1. **Sin pool en el destino**: cada granjero produce sus bloques con su nodo. Es la opción más simple y **elimina la arquitectura 3 de raíz** (no hay tercero que componga `pre_hash`); deja intactas la custodia de clave y la venta de claves (arquitectura 1) y el alquiler de parcelas maduras (`AGUJEROS-Y-SOLUCIONES.md:67`, agujero C1).
2. **Pool Chia-like definido en `P-ZRX/`** (parciales + granjero construye y firma), con D1 y D4 encima. Es lo que propone `ARQUITECTURA.md`.
3. **Pool custodial tolerado**: el más barato de operar y el que entrega todo el espacio al operador. Es la línea base, no una recomendación.

**Estatuto.** Decisión de alcance del proyecto; la opción 2 incluye una regla de consenso (D1).

**Por qué importa.** `INFORME.md` §0.2: hoy el pool de farming **no existe** ni en `SPEC.md`, ni en `TAREAS.md`/mapa de agujeros, ni en `P-PRESTAMO`. La ausencia es lo que hace que la arquitectura 3 esté a la vez posible e invisible.

**Coste de viabilidad que hay que mirar con la opción 2.** `[D]` Sin singleton ni lenguaje de script, en ZEROX **el pool no tiene vía de comisión on-chain**; Chia sí la tiene (el `p2_singleton_puzzle_hash` hasheado en el `plot_id`). Un modelo Chia-like en ZEROX exige decidir cómo cobra el pool: acuerdo privado, comisión fuera de cadena, o renunciar a ella. Si la comisión on-chain es un requisito, entonces la opción 2 choca con D1 y habría que ir a C1-b/C1-c, con su coste.

---

## D3 · ¿Se normativiza la etiqueta de dominio de la parcial?

**Qué se decide.** Si `ZZKPoolPartial__` (o el nombre que se elija) entra en la tabla de `C-HASH-06` (`SPEC.md:563-589`).

**Opciones.**

1. **No** (recomendación de implementación): la parcial se firma con `H_d` de etiqueta distinta y ya no puede confundirse con un sello. Efecto: ningún cliente que siga la recomendación usará el mismo dominio para las dos cosas, pero **nada lo obliga**.
2. **Sí** (regla de consenso): `C-HASH-05` declara que **añadir una etiqueta es un cambio de consenso** (`SPEC.md:384-385`). Compra interoperabilidad normativa; **no compra seguridad** (la seguridad ya la da usar dominios distintos).

**Estatuto.** Consenso, solo en la opción 2.

**Advertencia.** No presentar esta decisión como «la que cierra la firma ciega». **No la cierra.** `INFORME.md` §1.3, opción A.

---

## D4 · ¿Se exige que el cliente valide el bloque antes de firmarlo?

**Qué se decide.** Si se escribe, y dónde, el requisito de producción del paso 6 de `ARQUITECTURA.md`: **el cliente MUST construir y verificar el candidato con su propio pasado validado antes de emitir el sello, y MUST NOT firmar un `pre_hash` que no haya construido.**

**Opciones.**

1. **Requisito de producción, fuera del SPEC** (como el firmante seguro de `P-ZRX/P-EQUIVOCACION/investigacion/FALSOS-POSITIVOS.md:154-156`). No obliga a nadie, pero no finge que es consenso.
2. **Escrito en `SPEC.md` §0.4 / §16 como obligación de implementación** (no de consenso). Da cobertura documental; ningún verificador puede comprobarlo.
3. **No escribirlo.** Entonces la única barrera contra la arquitectura 3 es la ausencia de pools (D2) y el desincentivo (D1).

**Estatuto.** Producción / implementación, nunca consenso: **no es verificable en cadena**. Nadie puede distinguir en el bloque «firmé porque lo construí» de «firmé porque me lo mandaron».

**Relación con `P-ZRX/P-FIRMANTE/`.** Ese expediente existe y este informe no lo abre; si el «firmante» se concreta como componente, es su sitio natural.

---

## D5 · ¿Se prohíbe o se desaconseja plotear a la clave del pool?

**Qué se decide.** Si se escribe que la parcela **MUST NOT** plotearse a una clave que no controle el granjero.

**Opciones.**

1. **Recomendación de arquitectura** (no verificable hoy): se documenta que plotear a la clave del pool es entregar el espacio (arquitectura 2), y que ningún ahorro lo compensa.
2. **Regla de consenso, condicionada a un registro de parcelas**: hoy **no existe** el registro; `SPEC.md:1688-1690` deja abierta la puerta («si algún día se adopta un registro de parcelas contra el sembrador») y `P-ZRX/P-SEMBRADOR/` propone una familia (`A1+C1`) que **no está adoptada**. Sin registro, el consenso no puede saber a qué clave se ploteó, y la regla sería inaplicable.
3. **Nada.**

**Estatuto.** Arquitectura; consenso solo si algún día hay registro.

**Independencia de D1.** `C-POOL-01` **no** desincentiva esta vía: pagaría a la clave del pool, que es exactamente lo que el pool busca. Las dos medidas no se sustituyen.

---

## D6 · ¿Sigue siendo admisible el castigo automático por doble firma?

**Qué se decide.** Si el castigo prospectivo de `P-ZRX/P-EQUIVOCACION/` (pérdida de recompensas retenidas + inhabilitación del lote, `CANDIDATA.md:75-82`) se mantiene tal cual, sabiendo que **un pool hostil puede fabricar la evidencia sin poseer ninguna clave**.

**Opciones.**

1. **Mantenerlo.** Coste declarado: griefing gratis de un pool (o de cualquiera que controle el mensaje a firmar) contra cualquier granjero; el granjero castigado no decidió nada.
2. **Mantenerlo, con el griefing declarado como riesgo aceptado** y sin defensa (hoy no hay defensa criptográfica: `FALSOS-POSITIVOS.md:187-200`).
3. **Retirar el castigo automático** y sustituirlo por incentivos/comisiones. Coste: se pierde la única defensa contra `β_d` bajo `C-GD-07`, que `P-PRESTAMO` §3.3 declara imprescindible en ese escenario (`P-ZRX/P-PRESTAMO/investigacion/INFORME.md:343`).
4. **Condicionarlo** a un mecanismo de atribución que hoy **no existe** (`INFORME.md` §1.4.5).

**Estatuto.** Decisión de diseño económico; cruza `P-EQUIVOCACION` y `P-PRESTAMO`.

**Lo que este expediente aporta al cruce.** El falso positivo nuevo: `FALSOS-POSITIVOS.md` FP6 cubre «clave compartida, robada o copiada» (`:89-101`); **no** cubre «el pool no tiene la clave y aun así obtiene la firma». No modifica ese expediente; lo señala.

`[D]` **Y hay un caso que no es de castigo sino de detección:** la variante silenciosa (§`INFORME.md` §1.2, arquitectura 3: el pool usa la oportunidad **solo** en su rama y no existe el bloque honesto) produce **una sola firma**, no hay infracción estrecha y **ningún esquema de castigo la alcanza**. Detección y castigo son problemas distintos, y este expediente no resuelve el primero.

---

## D7 · ¿Entra el canal «espacio capturado sin consentimiento» en el modelo de `P-PRESTAMO`?

**Qué se decide.** Si `P-ZRX/P-PRESTAMO/` añade a su reparto `(α, β_d, β_x)` un término para el espacio que trabaja para la rama del pool **sin que el granjero lo sepa**.

**Opciones.**

1. **Añadirlo** y declarar su coste de captura (que no es `b*·N_recl` sino, como máximo, comprometer un servidor), separando en el castigo el caso «firmó sabiendo» del caso «firmó su cliente».
2. **Dejarlo fuera y decirlo**, declarando que el modelo solo cubre granjeros conscientes y sobornados.

**Estatuto.** Modelo económico; **no se rehace aquí su trabajo** (encargo §2). Este informe solo nombra el hueco y no fija el valor.

**Evidencia que falta.** `[ND]` Cuánto espacio es capturable por esa vía **no está medido** y depende de cuota de pools y arquitectura, que hoy no existen. No se inventa un número.

---

## D8 · ¿Puede el pool ser el nodo del granjero?

**Qué se decide.** Si el protocolo de pool permite que el pool sea la única fuente de vista del DAG (como permite Chia, `[VF-ext]` `docs.chia.net/chia-blockchain/protocol/pool/pool-protocol/`: «The full node can either be run by the farmer…, or run by the pool operator»).

**Opciones.**

1. **No**: el granjero MUST ejecutar su propio nodo. Cuesta comodidad; cierra la vista privada.
2. **Sí, con validación local**: el pool puede servir anuncios, pero el cliente construye y valida desde su estado y **rechaza** una cabecera que no haya construido.
3. **Sí, sin más**: reintroduce la arquitectura 3 por la puerta de atrás (el cliente validaría contra la vista del atacante).

**Estatuto.** Arquitectura / requisito de producción.

---

## Tabla resumen

| # | Decisión | Estatuto | ¿Cierra la arquitectura 3? |
|---|---|---|---|
| D1 | Coinbase atada a `sol.public_key` | **Consenso** | Quita el premio; no el hecho |
| D2 | ¿Hay pool en el destino? | Alcance | La opción «sin pool» la cierra de raíz |
| D3 | Etiqueta de parcial en `C-HASH-06` | Consenso (opcional) | **No**; solo evita el *replay* |
| D4 | Cliente valida antes de firmar | Producción | **Sí, es la única que cierra el hecho** |
| D5 | No plotear a clave ajena | Arquitectura (consenso solo con registro) | Cierra la arquitectura 2 |
| D6 | Castigo por doble firma | Diseño económico | — (es donde el ataque hace daño) |
| D7 | Canal de espacio capturado en `P-PRESTAMO` | Modelo económico | — |
| D8 | ¿El pool puede ser el nodo? | Producción | Evita la vista privada |

**Lectura de conjunto.** Dos decisiones son de consenso (D1, y D3 si se quiere normativa); **ninguna de las dos impide la firma ciega**. La que la impide (D4) es de producción y no es verificable en cadena. Ésa es la conclusión que hay que retener: **el consenso puede quitar el premio, no la capacidad.**
