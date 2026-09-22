# INFORME — P-POOLS

**Respuesta en una línea.** **Sí, hoy se puede**: con `SPEC.md` y `crates/` como están, un operador de pool hostil —o quien le haya comprometido el servidor— **que no tiene las claves de sus granjeros** puede producir bloques válidos para la rama que él elija con el espacio de ellos y **cobrar él la coinbase**, siempre que su protocolo de pool haga llegar al cliente del granjero un `pre_hash` que el cliente firme. Lo que lo impide no es una regla de consenso que exista hoy, porque **ninguna regla exige que quien firma el sello haya construido o validado el bloque** y **ninguna ata el destino de la recompensa a `sol.public_key`**. Lo cierra una **arquitectura** (el granjero valida el contexto, construye y firma; el pool solo recibe parciales para contabilizar, modelo de Chia) más, si Katana lo adopta, **una palanca de consenso** —atar la coinbase a `sol.public_key`— que quita el premio sin poder quitar la capacidad, y **una recomendación de implementación** —dominio separado para la parcial— que evita que una parcial valga jamás como autorización de bloque.

> **Etiquetas de este informe.** `[VF]` verificado en fuente · `[VF-ext]` verificado en fuente externa abierta · `[D]` derivado · `[P]` propuesto · `[NV]` no verificada · `[ND]` no determinado. Cada regla citada se ha leído **en su sección completa** (§6 de `PROMPT.md`); el detalle de qué se abrió está en `PROGRESO.md`.

---

## 0 · Alcance, correcciones al enunciado y una advertencia de método

### 0.1 · Tres precisiones a la frase «capturar un pool = controlar su espacio»

`[D]` La equivalencia del §0 del encargo es **correcta en las arquitecturas 2 y 3** y **falsa como afirmación general**, por una razón material: **la parcela no vive en el servidor del pool, vive en el granjero**. Lo que un servidor de pool captura es la **corriente de soluciones y de firmas**, no los bytes del espacio. Por eso el informe separa siempre dos capacidades que el enunciado mezcla:

- **Capacidad de probar** (producir una solución PoAS válida): la da la **parcela**, no una clave. `[VF]`
- **Capacidad de sellar** (firmar el `pre_hash` bajo `sol.public_key`): la da la **clave privada** del granjero. `[VF]`

Un pool que solo tiene la corriente de soluciones tiene la primera a medias y **no tiene la segunda**. Un pool que tiene una **copia de la parcela** tiene la primera entera y **sigue sin tener la segunda** — salvo que la parcela se haya ploteado a la clave del pool, que es un caso distinto (§1.2, arquitectura 2). Esta separación es la que decide el resultado.

`[D]` Las dos capacidades atan a **cosas distintas**: (a) la solución de espacio ata al **espacio** (la parcela); (b) el sello ata a la **clave**. Ninguna de las dos exige que quien construye el bloque sea el dueño de la otra, ni que ambas estén en el mismo sujeto. `[VF]` La validez absoluta de `C-FLU-13` (`SPEC.md:1701-1707`) enumera cuatro condiciones y **ninguna menciona identidad del productor**; la única atadura personal del protocolo es a una clave (`C-HDR-04`), no a una persona.

### 0.2 · El «solo pool blindado» del SPEC

`[VF]` Comprobado con `grep -n -i pool SPEC.md`: la palabra aparece en `mempool` (varias veces), en el HRP de `C-ENC-06` («mainnet, transparente» / «mainnet, blindada», `SPEC.md:183-193`) y en el *pool* blindado de la capa privada (§5, §9). **Ninguna es un pool de farming.** La afirmación del encargo es correcta en lo que importa; la formulación «solo» es imprecisa y se corrige aquí.

`[VF]` La ausencia llega más lejos de lo que el encargo supone: `P-ZRX/T-ZRX/AGUJEROS-Y-SOLUCIONES.md`, el mapa general de agujeros (425 líneas), **no menciona ni una vez** «pool» ni «operador hostil» — lo más cercano es el agujero **C1** («NO encarece alquilar una parcela ya madura, **su clave o su servicio remoto**», `AGUJEROS-Y-SOLUCIONES.md:67`) y el **C3** (mismo billete en ramas distintas, `:69`). Y `P-ZRX/P-PRESTAMO/investigacion/INFORME.md` tiene **cero** coincidencias de «pool», «operador», «custodia», «consentimiento» y «clave». El hueco que este encargo cierra es real y está en los tres sitios a la vez.

### 0.3 · Advertencia que sí afecta al expediente vecino

`[VF]` `P-ZRX/P-EQUIVOCACION/investigacion/DEFINICION-PROPUESTA.md:176-178` escribe:

> «1. **La firma.** Las condiciones (a)–(d) son **autenticadas por el sello**: no hay forma de producir el segundo sello sin la clave privada.»

`[D]` La frase es **literalmente cierta y estratégicamente incompleta**. Un pool hostil no necesita la clave privada: necesita que **el cliente que la tiene** firme el mensaje que él compone. Bajo firma ciega, el segundo sello se produce **con** la clave, no **sin** ella, y la evidencia resultante es indistinguible de una doble firma voluntaria. `FALSOS-POSITIVOS.md` §3.4.2 ya avisa de que «el firmante seguro es un filtro de accidentes honestos, **no un mecanismo de seguridad**», pero su catálogo no tiene la entrada que corresponde a este caso: **FP6 cubre «clave robada o compartida»** (`FALSOS-POSITIVOS.md:89-101`), es decir, un pool que **tiene** la clave. La variante en que el pool **no la tiene y aun así firma por el granjero** no está catalogada. Es un falso positivo nuevo, no un error de ese expediente; §1.2 lo documenta.

### 0.4 · Método

No se cita ninguna regla sin haber abierto su sección entera: `SPEC.md` §3.2, §4.5, §5, §6.1, §6.2, §7.1, §7.2, §8.2, §11 y §12 se han leído completas (líneas exactas en `PROGRESO.md`). Las mismas tres comprobaciones de entrada/salida pedidas por §3 del encargo están en `PROGRESO.md`. **No se ha ejecutado ningún instrumento de cálculo**: este encargo es análisis de reglas escritas, y el bloque de `veritas/LINEO.md` solo aplicaría si se comprobara algo con números (no ha hecho falta).

---

## 1.1 · Qué necesita exactamente un pool para funcionar

### Lo que hace falta para producir un bloque válido

`[VF]` Un bloque válido exige cinco piezas. Las cinco están en `SPEC.md`; la columna «¿quién la puede aportar?» es `[D]`.

| # | Pieza | Regla | Qué la aporta |
|---|---|---|---|
| 1 | **Solución PoAS válida** contra el reto del slot | `C-FLU-13` (`SPEC.md:1701-1707`), paso 5 de `C-POT-08` (`:1495`) | Quien tenga **lectura de la parcela** y la **clave pública** con que se ploteó |
| 2 | **Sello Ed25519** sobre `pre_hash` bajo `sol.public_key` | `C-HDR-03`/`C-HDR-04` (`SPEC.md:969-975`) | **Solo** el titular de la clave privada |
| 3 | **Cuerpo** con su **coinbase** (y por tanto `merkle_root`/`body_commitment`) | `C-HDR-01` (`:853-874`), `C-HDR-08` (`:960-961`), `C-EMIT-03` (`:2198-2199`) | **Quien ensambla el bloque**, libremente |
| 4 | **Justificación PoT** del rango exigido | `C-HDR-07` (`:930-958`) | Pública: se deriva del PoT y del pasado |
| 5 | **Contexto**: `rango_solucion`, padres, `slot` | `C-HDR-06` (`:902-922`), `C-GD-10` (`:2335-2356`), `C-GD-04` (`:2300-2303`) | Calculable por **cualquiera** con el pasado del candidato |

### 1.1.1 · Auditar y probar una parcela **no** exige ningún secreto

`[VF]` Ésta es la pieza que decide si «tener copia de la parcela» equivale a «tener el espacio». En el código fijado de Autonomys (`PDF/autonomys-subspace`, commit `f8842d0`), leído íntegro:

- **Auditoría.** `auditing.rs:57-63` y `:113-120`: las dos funciones de auditoría reciben **`public_key`**, **`global_challenge`** (desafío, público), **`solution_range`**, el **fichero de parcela** y los **metadatos de sector**. El *bound* del genérico es de solo lectura: `Sector: ReadAtSync` (`:65`, `:122`). No hay `SecretKey`, `Keypair`, `identity` ni `sector_key` en el fichero. `[VF]`
- **El desafío no lo elige el granjero.** Es un parámetro; su origen está en la verificación, que lo deriva del PoT: `subspace-verification/src/lib.rs:234-235` (`derive_global_randomness` → `derive_global_challenge(slot)`). `[VF]`
- **Proving.** `proving.rs:169-181`: `into_solutions` recibe **`reward_address`** (¡parámetro libre!), `kzg`, `erasure_coding`, `mode` y `table_generator`. El *bound* es de lectura (`:133`). La semilla PoS se **deriva**: `:252-254` (`self.sector_id.derive_evaluation_seed(piece_offset)`). **No hay ningún parámetro de clave privada, semilla secreta ni firma.** `[VF]`
- **La dirección de recompensa la elige quien prueba**: `:171` y se copia tal cual a la solución en `:319` (`reward_address: *self.reward_address`). `[VF]`
- **Verificación.** `subspace-verification/src/lib.rs:211-216`: `verify_solution` recibe la solución, el `slot`, los parámetros y el KZG. La clave pública **viaja dentro de la solución** y se usa solo para reconstruir el `SectorId` (`:228-232`). No hay clave privada ni `sign` en el fichero; la única operación de clave es **verificar** una firma (`:107-116`, `check_reward_signature`). `[VF]`

**Conclusión `[VF]`:** con (i) una **copia** de los ficheros de parcela, (ii) la **clave pública** con que se ploteó, (iii) los metadatos de sector y (iv) el desafío/PoT de la cadena, se generan **soluciones completas** sin ninguna clave privada. **La parcela es la capacidad de probar; la clave privada es la capacidad de sellar.**

`[VF]` Y la parcela **no se puede retargetear**: `SectorId::new(public_key.hash(), sector_index, history_size)` (`subspace-core-primitives/src/sectors.rs:56-68`, citado en la verificación `lib.rs:228-232`). El `sector_id` fija el reto de sector, el s-bucket, la semilla de evaluación y el índice de pieza. Una parcela construida para la clave de un granjero **no verifica** bajo la clave del pool: habría que volver a plotear. Esto es decisivo para el diseño (§`ARQUITECTURA.md`): **no se debe permitir plotear a la clave del pool**; hacerlo reintroduce la arquitectura 2.

`[VF]` **Alcance de esa premisa, dicho sin adornos.** Que el `sector_id` ate la prueba a la clave pública es **código del Autonomys fijado**, no una regla de `SPEC.md`. `SPEC.md:1328-1331` declara **pendiente** la «**validación conjunta** de solución de espacio, testigos KZG, distancia de solución y sello contra el reto derivado (el paso 5 de `C-POT-08`)». `[D]` Si esa validación se implementara sin el anclaje `sector_id ↔ public_key` del código fijado, la arquitectura 2 dejaría de estar cerrada por esta vía, y con ella la premisa de §1.1.1. Se marca porque **todo el análisis de arquitecturas 2 y 3 descansa en ella**, y porque `P-ZRX/P-SEMBRADOR/` ya demostró que la interfaz fijada admite variaciones de `public_key`, `sector_index`, `history_size` y `piece_offset` cuando el atacante puede recalcular la pieza.

### 1.1.2 · Qué entra en la cabecera y qué se firma: quién cobra y quién lo decide

`[VF]` La cabecera DAG (`SPEC.md:831-874`) lleva `sol.public_key` en `[112,144)` y, en el formato DAG, el compromiso del cuerpo y los padres antes del sello:

```text
prefijo_fijo_poas_sin_sello(492) ‖ body_commitment(32) ‖ parent_count(1)
  ‖ extra_parents(32·(P−1), o cero en génesis) ‖ sello(64)
```

`[VF]` `pre_hash = H_d("ZZKBlkPreHash___", prefirma)` (`C-HDR-03`, `:969-972`) y en el código `crates/zx-core/src/preimage/dag.rs:396-400` con la prefirma escrita en `:356-379`. Los bytes que se firman incluyen: todo el prefijo PoAS de 492 B —y dentro de él el `merkle_root` en `[36,68)`, `C-HDR-01`— **más** el `body_commitment` como campo **directo** en `[492,524)` (`dag.rs:366`), el `parent_count` y los padres. La coinbase entra por dos vías: por su `txid` (que compromete las salidas) y por el `body_commitment`, que liga también la autorización. **El sello cubre la coinbase**: la firma del granjero autoriza el destino de la recompensa, la conozca o no.

`[VF]` **Nada ata ese destino a la clave que firma.** Ni una regla ni una línea de código: la validación de coinbase que existe hoy solo **suma importes** (`crates/zx-consensus/src/bloque.rs:217-235`, `salidas_coinbase = coinbase.outputs.iter().try_fold(...)`) y **no compara** el `pubkey` de un `Lock::PubKey` con `sol.public_key`. `C-HDR-08` solo prohíbe poner la dirección de recompensa **en la cabecera**; `C-EMIT-03` (`:2198-2199`) solo pide que la coinbase sea la primera transacción, sin entradas, con `Σ value(salidas) ≤ subsidio(H) + Σ fees`. **Quien construye el bloque elige a quién paga**, y ese constructor puede ser cualquiera. `[VF]`

### 1.1.3 · Elección de padres y contexto: no exigen autoridad de nadie

`[VF]` `C-GD-10` (`:2335-2356`) es **política de producción, no verificación** («un verificador **MUST NOT** rechazar un bloque por el conjunto de padres que eligió su autor mientras cumpla C-GD-04, C-GD-11, C-HDR-05, C-FLU-02 y C-FLU-14»). El barajado de la cola de candidatos es **la única regla no determinista a propósito** de §11. `[VF]` `C-HDR-06` exige que `rango_solucion` sea **exactamente** el esperado contextual, pero eso es una comprobación **del verificador**: un constructor hostil lo calcula para la rama que le convenga. `[VF]` La justificación PoT (`C-HDR-07`) no entra en `block_hash` y se deriva de datos públicos. `[VF]`

### 1.1.4 · La respuesta a «¿es la misma clave la que firma el sello y la del billete?»

**En el protocolo hay una sola `public_key`, y es la que firma el sello.** `[VF]` El vínculo con la identidad de billete es la **única lectura coherente** y a la vez **no está certificado**: el propio `SPEC.md` remite su certificación a un contrato que la deja abierta. Se separa lo demostrado de lo asumido.

**Demostrado.** `[VF]`

| Pieza | Cita |
|---|---|
| La cabecera tiene **un solo** campo de clave pública: `sol.public_key` en `[112,144)` | `C-HDR-01`, `SPEC.md:841`; `crates/zx-core/src/preimage/dag.rs:132-153` (`SolucionPoas.public_key`, con el comentario «Clave pública Ed25519 que firma el sello (C-HDR-04)») |
| El sello se verifica bajo ese campo | `C-HDR-04`, `SPEC.md:974-975`; `crates/zx-core/src/preimage/dag.rs:408-416` (`verificar_sello` usa `self.sol.public_key`) |
| La identidad de billete nombra `public_key` **sin calificar** | `C-GD-07`, `SPEC.md:2315-2316`; `R-FIN-11`, `research/dag-poas-ancla-de-orden.md:227-228` |
| El SPEC ata «dos firmas Ed25519 bajo la misma `public_key`» al dueño del billete | `SPEC.md:2013-2015`; `research/dag-poas-ancla-de-orden.md:360-361` («Solo el dueño del billete puede producir un `rojo_U3`») |

**Asumido, y hay que decirlo.** `[VF]` `SPEC.md:2013-2015` afirma que el vínculo «billete→oportunidad» tiene una «**propiedad real** [que] depende de `veritas/consenso/contrato-billete-v1/` y de C-HDR-03/04». Y ese contrato **no la certifica**: `veritas/consenso/contrato-billete-v1/CONTRATO.md:29-38` presenta la tupla como «**Punto de partida a estudiar, no tupla certificada**», y su `REVISION.md:30` lo cierra: «**REV-01** … **CBE-01/02 no certifican `TicketId`** ni el compromiso de padres/cuerpo/sello». Por tanto:

- `[VF]` **No existe en `SPEC.md` ninguna línea que iguale explícitamente la `public_key` de `C-GD-07` con `sol.public_key`.** Se han localizado las cuatro apariciones de `public_key` en el SPEC (`:841`, `:975`, `:2015`, `:2316`); ninguna hace la igualdad.
- `[D]` **La igualdad se sigue de que el campo es único**: la cabecera no tiene otra clave pública y `C-GD-07` no dice de dónde sale la suya. Es la única lectura coherente, y es la que `R-FIN-8′` presupone.
- `[ND]` **La certificación formal está pendiente** (`REV-01`). Este informe no la da por hecha.

`[D]` Consecuencia, y es la que gobierna todo el encargo: **la identidad de billete es una clave autocertificada que viaja en la cabecera; no hay registro previo, ni alta, ni vínculo con una persona o un lote**. Quien tenga esa clave **es** el billete para todo lo que el protocolo puede ver. Y lo contrario también: el protocolo **no tiene forma de saber quién sostuvo la clave** en el momento de firmar. Esto es lo que `P-ZRX/P-EQUIVOCACION/` ya trata como limitación (FP6) y lo que §1.2 convierte en ataque. `[D]` Si algún día se cambiara la identidad de billete (`IDV-01`/`CANDIDATA`), esa igualdad de campos es precisamente lo que se toca; el ataque de §1.2 **no depende** de qué tupla se elija, solo cambia su detectabilidad (`[VF]` `P-ZRX/P-PRESTAMO/investigacion/INFORME.md:333-343`).

### 1.1.5 · Lo que el granjero puede quedarse, y lo que eso vale

`[D]`

| Dato | ¿Público? | ¿Lo necesita el pool? | ¿Lo necesita el granjero? |
|---|---|---|---|
| Bytes de la parcela | No (pero no es secreto criptográfico, `[VF]` §1.1.1) | Solo en la variante «pool-almacén» | **Sí**, para probar |
| Reto del slot / PoT / challenge | **Sí** (`[VF]`) | Sí | Sí |
| Solución completa (prueba + metadatos) | Se difunde | **Sí**, es lo que la parcial transporta | La produce |
| Clave privada de `sol.public_key` | **No** | Solo el pool custodial | **Sí**, para sellar |
| `pre_hash`, padres, `slot`, coinbase | Se difunden con el bloque | **Sí**, los fija quien ensambla | Debería validarlos |
| `rango_solucion` | Se difunde | Calculable | Calculable |

`[D]` **Lo único que el granjero conserva y que el pool no puede fabricar es la clave privada.** Si su cliente la usa para firmar cualquier cosa que el pool le mande, esa ventaja **no se traduce en autoridad**: se convierte en una máquina de sellar. Ése es el núcleo del problema.

---

## 1.2 · El modelo de amenaza y las arquitecturas

**Adversario.** Un operador hostil, o quien le ha comprometido el servidor, **sin las claves privadas de sus granjeros**. `[VF]` (enunciado del encargo, `PROMPT.md:105`). Distinguimos dos sub-capacidades, porque el resultado cambia: **(S)** recibir las soluciones que los granjeros producen, y **(P)** disponer de copias de las parcelas. Nadie le da **(K)** las claves.

### Arquitectura 1 · Pool custodial (el granjero entrega la clave)

`[D]` El pool **es** el granjero. Puede probar, sellar, construir y cobrar; para cualquier rama. **Evidencia:** la actividad es indistinguible de la del titular legítimo; no hay doble firma salvo que el pool la provoque. Es la línea base: mide todo lo que las demás ganan.

`[VF]` El expediente vecino ya lo identifica exactamente: **FP6** («Clave compartida: *pool* custodial, clave robada o copiada», `FALSOS-POSITIVOS.md:89`), con la consecuencia de seguridad escrita: «Un tercero que obtenga la clave (o un *pool* negligente) puede por tanto **provocar la confiscación** del lote ajeno firmando dos veces. Es una vía de **griefing** que el diseño candidato no trata» (`:98-101`).

### Arquitectura 2 · Pool que firma con una clave del pool

`[D]` Aquí el pool construye y sella con **su propia** clave. Para que la solución verifique, la parcela tiene que haberse **ploteado a la clave del pool**, porque `SectorId` se deriva de `public_key.hash()` (`[VF]` §1.1.1). Es exactamente el modelo de *pool plots* de Chia antes de los plot NFTs (`[VF-ext]` la propia documentación de Chia lo describe en pasado: «**Instead of farmers using a `pool_public_key` when plotting**, they now use a puzzle hash…», `docs.chia.net/…/pool-protocol/`).

- **Qué puede hacer el operador hostil:** todo sobre ese espacio —auditar, probar, sellar, elegir padres, elegir la coinbase— **si recibe las soluciones** (no tiene la parcela; **(S)** lo basta, porque la solución lleva `public_key`, `sector_index`, `history_size`, `piece_offset`, `chunk`, testigos y `proof_of_space`, y el sello lo pone él con su clave). `[D]`
- **Qué no puede:** nada sobre el espacio **ploteado a la clave del granjero** (otra parcela, otro `sector_id`). `[VF]` §1.1.1.
- **Evidencia que queda:** la identidad del billete es la **clave del pool**, así que la infracción estrecha de `P-EQUIVOCACION` **no** alcanza al granjero: el granjero no tiene billete en esa parcela. `[D]` Esto es *peor* que la arquitectura 3 desde el punto de vista de la atribución — no hay ni rastro.
- **Por qué no lo cierra el SPEC:** nada impide plotear a la clave de un tercero. `[D]`

### Arquitectura 3 · Firma ciega (la peligrosa, y la que el encargo quiere cerrar)

`[D]` El granjero conserva la clave y la parcela. Su cliente **firma el `pre_hash` que el pool le manda**, sin validar el contexto ni comprobar la coinbase. El pool construye el bloque entero: padres, `slot`, cuerpo, **coinbase a su favor**.

- **Qué puede hacer el operador hostil:** producir un bloque **válido** para **la rama que elija**, con el espacio del granjero, y cobrar él; tantas veces como quiera y en tantas ramas como quiera. `[D]` `[VF]` Además, como `C-HDR-04` **no obliga a un nonce concreto**, puede pedir **varias firmas válidas del mismo `pre_hash`** y variar con ellas el `block_hash` sin cambiar la solución ni el cuerpo (`SPEC.md:980-988`; vector real en `crates/zx-core/tests/ed25519_no_unicidad.rs:18-57`): grinding sobre el identificador del bloque. `[D]`
- **Qué no puede:** nada que exija la clave privada **para otra cosa**: no puede generar la solución si no la recibe (no tiene la parcela), ni reutilizar una solución bajo otra clave. `[VF]` §1.1.1. `[D]` Tampoco puede re-dirigir una solución ya publicada a una rama de **flujo divergente**: `C-FLU-13(1)` exige que la solución verifique bajo `reto(flujo(B, slot(B)), slot(B))` y `C-FLU-14` prohíbe referenciar bloques de otro flujo (`SPEC.md:1701-1707`, `:1718-1726`). **Pero el matiz es blando**: dentro de la ventana de época, `flujo(B, s)` no depende del ancla (`SPEC.md:1616-1620`), así que **cualquier rama privada del mismo flujo sirve**; y si el pool es además el nodo del granjero, le sirve la vista privada directamente. `[VF]` §1.3, opción B.
- **Variante silenciosa, y es peor que la anterior:** si el pool usa cada oportunidad **solo en su rama** y el bloque honesto de ese `(billete, slot)` no llega a existir —porque el pool retiene la solución o el granjero no produce—, **solo hay un sello**: la infracción estrecha **no se dispara** y no queda **ninguna** evidencia. El robo es invisible, no solo mal atribuido. `[D]`
- **Evidencia que queda:** `mismo TicketId y slot + dos pre_hash distintos + dos sellos válidos` — la **infracción estrecha** de `CANDIDATA.md:61-70`. Pero bajo firma ciega el segundo sello lo produjo **el cliente del granjero** a petición del pool. `[D]` El castigo de `CANDIDATA.md` §6 («se pierden las recompensas aún retenidas; el lote queda inhabilitado», `:75-82`) recae sobre **el granjero**, que no hizo nada: `[VF]` `FALSOS-POSITIVOS.md:98-99` («el castigo cae sobre el lote y las recompensas retenidas, no sobre una persona»). El pool, si quiere, puede además **no cobrar y solo provocar la confiscación** — griefing gratis.
- **Por qué no lo cierra el SPEC:** porque **la validez de un bloque no dice nada de quién lo montó**. El verificador comprueba `pre_hash`, sello, solución, PoT, flujo y rango (`C-POT-08`, `C-FLU-13`), y todos son consistentes con un bloque ensamblado por el pool con una firma obtenida del granjero. `[D]`

`[VF]` Y hay precedente **en el código fijado**: en Autonomys el nodo construye la cabecera y **pide al granjero la firma del hash que él mismo compone**; el servicio de firma del granjero solo comprueba que la clave pública coincide y firma. La lectura delegada del árbol completo (fuera de los tres ficheros del encargo, marcada como tal) localiza `sc-consensus-subspace/src/slot_worker.rs:850-884` (`sign_reward`) y `subspace-farmer/src/single_disk_farm/reward_signing.rs:20-28` (`if identity.public_key().to_bytes() != *public_key { continue; } let signature = identity.sign_reward_hash(&hash);`). Es **arquitectura 3 en producción**, no una hipótesis. `[VF]` (rutas de un directorio vendored, leídas por lectura delegada; no forman parte de los tres ficheros que el encargo manda abrir — se citan como precedente, no como regla de ZEROX).

### Arquitectura 4 · Chia-like (parciales + el granjero construye y firma)

`[VF-ext]` Documentación oficial de Chia, abierta el 2026-09-22 (se indica en cada cita la página exacta; no se atribuye a una lo que dice otra):

- «**the protocol only handles distribution of rewards, and it protects against pools or farmers acting maliciously**» (`docs.chia.net/chia-blockchain/protocol/pool/pool-protocol-specification/`, §11.2).
- «The farmer chooses which transactions to include from their full node and **creates transaction blocks** in a decentralized way» (`docs.chia.net/chia-blockchain/protocol/pool/pool-protocol/`, resumen).
- «Farmers also have a **private key**, which is used for **both signing blocks** when a winning proof is found, **as well as for signing partial proofs**, which are then sent to pools» (`docs.chia.net/chia-blockchain/architecture/farmers/`).
- «A *partial* is a proof of space with some additional metadata and authentication info from the farmer» y «These "partial" proofs, however, are **not sent to the full node to create a block**. They are instead only sent to the pool» (ambas en `…/pool-protocol/`).
- `POST /partial`: «This is a 2/2 BLS signature of the hashed serialization of the payload: `sha256(PostPartialPayload)` signed by the private keys of the following keys … 1. `plot_public_key` 2. `authentication_public_key`» (`…/pool-protocol-specification/`): un mensaje **distinto** de la cabecera de bloque y con otro esquema.
- La parcela se liga al singleton por `p2_singleton_puzzle_hash` hasheado en el `plot_id`, «and cannot be changed after creating the plot» (`…/pool-protocol/`); `target_puzzle_hash` es «the target of where rewards will be sent to from the singleton. **Controlled by the pool**», y `payout_instructions` las fija el granjero (`…/pool-protocol-specification/`).

`[D]` En ZEROX, la traducción es: **el pool recibe la solución (o una parcial) y solo la contabiliza; el granjero construye, valida y firma su bloque**. El pool no puede construir el bloque porque **no recibe ninguna firma sobre un `pre_hash`** y **no tiene la parcela** para generar la solución con otra clave. Ésta es la única de las cuatro arquitecturas en que el operador hostil **no** puede producir bloques para otra rama.

`[D]` **La frontera exacta, porque de ella depende todo:** esto vale mientras la parcial **no sea** una firma sobre el `pre_hash` verdadero. Si el protocolo de pool define la parcial como «firma este `pre_hash`», la arquitectura **colapsa en la 3** y esta protección desaparece. No la da el nombre «Chia»: la da que el mensaje firmado sea otro. `[D]` Y hay un coste de viabilidad que la propia fuente exhibe: en ZEROX un pool Chia-like **no tiene forma de cobrar comisión on-chain** (no hay singleton ni script); Chia sí, por el `p2_singleton_puzzle_hash`. Eso no afecta a la autorización, pero sí a que el modelo sea viable.

### 1.2.1 · Tabla comparativa

`[D]` salvo las citas ya marcadas.

| Arquitectura | ¿Produce bloques para otra rama? | ¿Cobra él? | Evidencia que queda | ¿La cierra una regla de consenso? |
|---|---|---|---|---|
| 1 · Custodial | **Sí** | Sí | Indistinguible del titular; FP6 | No (el granjero entregó la clave) |
| 2 · Pool firma | **Sí**, sobre parcelas ploteadas a su clave | Sí | Billete = clave del pool; **ninguna** sobre el granjero | **Sí, por diseño**: no permitir plotear a clave ajena (§`ARQUITECTURA.md`) |
| 3 · **Firma ciega** | **Sí** | Sí | Doble firma **atribuida al granjero**; FP nuevo | **No** (ver §1.3) |
| 4 · Chia-like | **No** | No | Ninguna | No hace falta |

### 1.2.2 · Cruce pedido con `P-ZRX/P-EQUIVOCACION/`

`[VF]` La evidencia estrecha es idéntica para los cuatro: `FALSOS-POSITIVOS.md:3-5`. La pregunta del encargo —«¿la doble firma resultante sería atribuible al granjero o al pool?»— tiene una respuesta incómoda y clara:

> `[VF]` **Al granjero.** El pool no aparece en ninguna parte. `DEFINICION-PROPUESTA.md:64`: «La infracción es **económica**: vive donde vive el castigo de `CANDIDATA.md` §6 (recompensas retenidas y habilitación del lote)». Y `:205`: el castigo recae sobre «el lote».

`[D]` Ni siquiera hace falta el pool: `DEFINICION-PROPUESTA.md:182-186` ya reconoce que «un tercero que **obtenga** la clave (FP6) o que simplemente **presente** dos bloques que el honesto ya firmó sin mala fe (FP1–FP5) no está fabricando nada: la evidencia es real y el castigo caería sobre un inocente». La firma ciega añade un caso que no exige obtener nada: **basta con ser el que manda el mensaje a firmar.** Es un quinto camino a la misma injusticia, y el único cuyo actor puede ser un **tercero comercial** (el pool) sin comprometer ninguna clave.

`[ND]` Cuánto empeora el ataque la definición vigente de identidad de billete está declarado en `P-PRESTAMO` y **no lo decide este informe**: con `C-GD-07` (identidad **con** `chunk`) dos soluciones de la misma pieza y slot con `chunk` distinto son **dos billetes** y no dejan evidencia; con `IDV-01`/`CANDIDATA` (sin `chunk`, con `piece_offset`) **sí** la dejan (`P-ZRX/P-PRESTAMO/investigacion/INFORME.md:333-343`, tabla de §3.3). La firma ciega no depende de esa decisión, pero su **detectabilidad** sí.

`[D]` Y hay un caso **peor que el falso positivo**: el **robo sin evidencia**. Si el pool usa la oportunidad **solo** en su rama —retiene la solución o el granjero no llega a producir su bloque de ese `(billete, slot)`— existe **un solo sello**: la infracción estrecha **no se activa** y no hay nada que atribuir. Con `IDV-01`/`CANDIDATA` tampoco: esa identidad agrupa, pero solo cuando hay **dos** firmas que comparar. `[D]`

---

## 1.3 · La pregunta central: ¿se puede impedir por diseño la firma ciega?

`[D]` Se examinan las tres opciones que pide el encargo. El resumen es: **una es necesaria y suficiente para el *replay* pero no para la firma ciega; otra no puede expresarse como regla de consenso; la tercera es la única palanca de consenso real, y quita el premio, no la capacidad.**

### Opción A · Separación de dominio de la parcial

`[VF]` ZEROX ya usa separación de dominio con prefijo fijo de 16 bytes (`C-HASH-04`, `SPEC.md:374-382`) y una tabla cerrada de etiquetas (`C-HASH-06`, `:563-589`), donde añadir una etiqueta **es un cambio de consenso** (`C-HASH-05`, `:384-385`). En esa tabla **no hay** ninguna etiqueta de parcial. `[VF]`

`[D]` Si la parcial se firma sobre `H_d("ZZKPoolPartial__", …)` y el sello sobre `H_d("ZZKBlkPreHash___", prefirma)`, **una parcial no puede ser jamás un sello de bloque**: son mensajes distintos y `H_d` es inyectiva por construcción. Esto cierra el *replay* de la parcial como autorización.

`[D]` **Pero no cierra la firma ciega.** El pool no necesita reutilizar la parcial: pide al cliente del granjero la firma del `pre_hash` verdadero. La separación de dominio protege contra un accidente/protocolo mal diseñado, no contra un operador que controla el flujo de mensajes.

`[P]` **Estatuto:** es **recomendación de implementación**, no regla de consenso. Añadir la etiqueta a la tabla de §4.5 la volvería interoperable y normativa, pero no añadiría seguridad: la imposibilidad de confundir los dos mensajes ya se sigue de usar etiquetas distintas. **No presentarla como la defensa** sería el error a evitar; presentarla como la única defensa sería peor.

### Opción B · Que el `pre_hash` comprometa algo que el pool no pueda fijar

`[D]` **No es expresable como regla de consenso.** Todo lo que entra en la prefirma —`prev_hash`, `merkle_root`/`body_commitment`, `timestamp`, `height`, `slot`, `pot_output`, `rango_solucion`, los campos de la solución, `parent_count` y los padres— lo fija **quien ensambla la cabecera**. El pool controla el ensamblaje. Cualquier campo que el cliente del granjero «ponga por su cuenta» a partir de su propio estado también es influible si el pool controla la vista que el cliente consume (por ejemplo, si el pool es su nodo, cosa que el propio modelo de Chia permite: «The full node can either be run by the farmer…, or run by the pool operator», `[VF-ext]`).

`[D]` La única cosa que un verificador **no** puede comprobar es la intención: no existe una regla que distinga «firmé esto porque lo construí» de «firmé esto porque me lo mandaron». Por tanto esta opción **no es una regla**, es una **propiedad del cliente**: firmar solo cabeceras que él mismo ha construido y validado. Eso sí cierra el hecho — no es verificable en cadena, y por eso **no puede ser una regla de consenso**, solo un requisito de producción/implementación (el mismo estatuto que el «firmante seguro» de `FALSOS-POSITIVOS.md` §3, `:154-156`).

### Opción C · Atar la recompensa a una clave que el pool no controla

`[VF]` Es la **única** de las tres que puede ser regla de consenso, y encaja en las estructuras ya definidas: la coinbase es la primera transacción, sin entradas, con salidas de tipo `Lock` cerrado (`PubKey`, `MultiSig`, `Htlc`; `[VF]` `SPEC.md:625-653`, `:2198-2199`). Véase la regla candidata exacta en `ARQUITECTURA.md`.

`[D]` Qué hace y qué no hace:

- **Quita el premio del robo.** Si la coinbase de un bloque con `sol.public_key = P` **tiene que** pagar a `P`, el pool que firma ciegamente no puede redirigir la recompensa a su dirección. `[D]`
- **No quita la capacidad.** El pool sigue pudiendo producir bloques válidos para otra rama con el espacio del granjero: equivocación, censura del bloque honesto, fabricación de evidencia para confiscar el lote, sabotaje. `[D]`
- **No protege de la arquitectura 2** (parcela ploteada a la clave del pool): ahí `P` es la clave del pool y el pago le corresponde. `[D]`
- **Tiene coste y contradice un modelo posible de pool:** el pool no puede recibir la recompensa on-chain para repartirla después. Es exactamente la mitad del modelo de Chia (el 7/8 va al singleton del pool, `[VF-ext]`). En ZEROX no hay singleton ni lenguaje de script, así que no hay forma de expresar «paga al pool y el pool reparte» **sin un registro**. `[D]`
- `[ND]` Detalles a decidir: subsidio frente a fees (¿se atan también los fees?), `MultiSig`/`Htlc` (¿se prohíben en la coinbase?), varias salidas (¿todas a `P`?), la capa blindada de v1.1 (que no existe) y el pool legítimo que quiera cobrar comisión (no tendría vía on-chain en el bloque; sí fuera, por acuerdo privado).
- `[VF]` **Dos agujeros finos que la regla tiene que tapar, y no basta con «incluir a `P`».** (i) `MultiSig{k=1, [P, pool]}` y `Htlc{receiver=pool}` permiten gastar al pool sin su concurso: la regla debe **excluir todo `Lock` que no sea `PubKey(P)`**, no solo exigir que `P` aparezca. (ii) Si solo se ata el **subsidio** y se dejan libres los **fees** (variante C1-a), el pool abre una segunda salida y **se queda los fees**: el robo se reabre por esa vía, porque las tarifas entran en la suma permitida de la coinbase (`C-EMIT-03`) y suman solo las transacciones aceptadas (`SPEC.md:2383-2384`). `[VF]`

`[D]` **No es «la única» palanca de consenso, y decir lo contrario inflaría el resultado.** Un refutador independiente localizó al menos otras dos, ambas más invasivas:

- **Comprometer el destino en la parcela**, el análogo del `p2_singleton_puzzle_hash` que Chia hashea en el `plot_id` (`[VF-ext]`): ata la recompensa a un destino **fijado al plotear**, no a la clave que firma. Cubre además la arquitectura 2 y la rotación de clave; su coste es que o choca con `C-HDR-08` (la dirección no puede ir en la cabecera) o cambia la derivación de `sector_id`, **invalidando las parcelas existentes**.
- **Reclamo diferido**: el subsidio no se paga en la coinbase, se acumula como un derecho canjeable solo por la clave del billete. Es un rediseño de §8, no una regla pequeña.
- `[D]` Y **ninguna de las tres quita el incentivo general**, solo el premio: un pool que quiera una rama privada para doble gasto, censura o fabricar la confiscación del lote puede pagar la coinbase a la clave del granjero y aun así producirla. Eso ya está dicho en el primer punto de «Qué no compra».

### Veredicto de §1.3

`[D]`

| Medida | ¿Impide la firma ciega? | Estatuto |
|---|---|---|
| **Dominio separado para la parcial** | No. Impide el *replay* de la parcial como sello | **Recomendación de implementación** (normativa solo si se añade la etiqueta a §4.5) |
| **`pre_hash` con algo que el pool no fije** | No es expresable; no existe tal campo | — (no es una opción real) |
| **Cliente que construye y valida antes de firmar** | **Sí, es la única que la impide** | **Requisito de producción / arquitectura**; no verificable en cadena |
| **Coinbase atada a `sol.public_key`** | No impide el hecho; **quita el beneficio** | **Regla de consenso** (propuesta, requiere decisión de Katana) |
| **No plotear a clave ajena** | Cierra la arquitectura 2 | **Recomendación de arquitectura** (podría ser regla de producción) |

**Respuesta literal a la pregunta del encargo:** **no, no se puede impedir por diseño —entendido como regla de consenso— que la arquitectura (3) sea posible.** Lo que sí se puede, y basta, es (i) hacer que una firma de parcial **no valga nunca** como autorización de bloque (dominio separado: recomendación, y se cumple por construcción), y (ii) hacer que la firma ciega **no pague** (coinbase atada a la clave: regla de consenso, si Katana la adopta). La imposibilidad del *hecho* la da la arquitectura 4, que es una decisión de arquitectura, no una regla de consenso. **Ninguna recomendación impide nada a un operador hostil, y este informe no la presenta como si lo hiciera.**

---

## 1.4 · Qué NO cierra

`[D]` Ninguna arquitectura evita, y hay que decirlo sin adornos:

1. **Que el propietario colabore voluntariamente** y entregue la clave (arquitectura 1). Tampoco lo evita que use un binario modificado que firme lo que le manden, ni un firmante remoto que no valide. `FALSOS-POSITIVOS.md:192-194` lo dice para el firmante seguro: «El registro es **local**: quien quiera doble-firmar borra el registro (o usa un binario que no lo consulte)… **es un filtro de accidentes honestos, no un mecanismo de seguridad**».
2. **Que el pool sea el nodo del granjero y le sirva una vista privada** (Chia lo permite explícitamente, `[VF-ext]`). Con la opción C el pool no cobra, pero puede inducir al granjero a producir en una rama que nadie ve.
3. **Que el pool retenga o censure** las soluciones/bloques del granjero. Es un ataque de disponibilidad, no de autorización, y no lo cierra nada de esto.
4. **La reutilización de una solución en dos ramas.** Si los retos coinciden (mismo flujo), la solución es **la misma** —mismo `chunk`, misma identidad de billete— y basta con que el cliente firme una **segunda cabecera** para dejar la infracción estrecha en la cadena. Bajo `C-GD-07` (identidad **con** `chunk`), si los retos difieren el `chunk` difiere y son **dos billetes**: no hay evidencia. Es decir: el coste de fabricar la evidencia que condena al granjero es **una firma**, no un bloque nuevo. `[D]` (`[VF]` la tabla de identidades en `P-ZRX/P-PRESTAMO/investigacion/INFORME.md:333-343`.)
5. **La variante silenciosa: robo sin evidencia.** Si el pool usa cada oportunidad **solo** en su rama y el bloque honesto de ese `(billete, slot)` no llega a existir, hay **un solo sello** y la infracción estrecha **no se activa**. No es un falso positivo: es un **falso negativo**, y es peor — ni se detecta ni se puede atribuir. `[D]`
6. **La atribución.** Aunque todo lo anterior se cierre, el protocolo seguirá sin poder distinguir tenedor de clave y autor. `[VF]` `DEFINICION-PROPUESTA.md:182-186`.

---

## 2 · Lo que esto cambia en el modelo económico de `P-PRESTAMO`

`[VF]` El modelo de `P-ZRX/P-PRESTAMO/investigacion/INFORME.md` es explícito: reparte el espacio en `α` (propio del atacante), `β_d` (honesto que trabaja en **las dos** ramas) y `β_x` (alquilado que **abandona** la pública), con `Leales = 1 − α − β_d − β_x` (`:56-58`); la frontera de deriva es `α* = (η_h − η_a·β_d − (η_h + η_a)·β_x)/(η_h + η_a)` (`:74-76`); y **el granjero es un reclutado al que hay que pagar un soborno** `b* = κ·q·(ρ_ret·ingreso·T_v + c_r + ingreso·M) − ganancia_extra` por reclutado, con `N_recl` reclutados (INFORME §3.2, §4.1; `:311`, `:318-326`). La pregunta que ese informe responde es: **cuánto hay que retener para que un granjero no acepte el soborno**. `[VF]`

`[D]` La vía del pool **no es un caso particular de ese juego: es otro juego.**

1. **`b* = 0` para el espacio capturado.** En la arquitectura 3 el granjero no decide nada: no hay soborno que pagar, ni `N_recl` que reclutar, ni `ρ_ret` que disuada. El canal del pool es una vía **nueva** que el reparto `(α, β_d, β_x)` no contiene: la llamo aquí **`β_p`** (espacio honesto que trabaja para la rama del pool **sin participación del granjero**), y **no es un símbolo que este informe fije**: es la observación de que falta un término, no una propuesta de valor. `[D]`
2. **`β_p` se comporta como `β_d`** en la cuenta de deriva (la pública conserva `1−α−β_x` bloques, porque el granjero sigue publicando lo que el pool le deja publicar) y, si el pool puede **retener** soluciones, se comporta como `β_x` (la pública pierde peso). Es decir: **el pool puede elegir entre los dos regímenes**, y el modelo de `P-PRESTAMO` no contempla a un actor que elija. `[D]`
3. **La retención `ρ_ret·T_v` pasa de disuasoria a confiscatoria.** El granjero castigado no aceptó nada: su lote se inhabilita y sus recompensas retenidas se pierden por una firma que su cliente emitió a petición de otro. `[VF]` `FALSOS-POSITIVOS.md:98-99`; `CANDIDATA.md:75-82`. **Esto es un cambio de signo, no un ajuste de constante.**
4. **Lo que tendría que cambiar en ese modelo, sin rehacerlo:** (a) añadir el canal `β_p` y declarar su coste de captura —que **no** es `b*·N_recl` sino, como máximo, comprometer un servidor—; (b) separar en la cuenta del castigo el caso «el granjero firmó sabiendo» del caso «firmó su cliente»; (c) reconocer que `ρ_ret·T_v` **no** protege contra la vía del pool y que, en cambio, es lo que hace rentable el **griefing** del punto 3 (el pool provoca la confiscación gratis). `[D]`
5. `[ND]` El valor de `β_p` alcanzable **no está medido** y este informe no lo estima: depende de cuánta cuota de pools tenga la red y de qué arquitectura usen, y hoy **no existe** ningún pool de farming en ZEROX ni parámetro de red fijado (`SPEC.md` §7.3). No se inventa un número.

---

## 3 · Huellas y comprobaciones

Las tres comprobaciones de entrada y las de salida (idénticas, desde la raíz) están transcritas con su salida literal en `PROGRESO.md`, junto con el presupuesto declarado y la lista de fuentes abiertas. Entrega: `INFORME.md` (este), `ARQUITECTURA.md`, `DECISIONES-PENDIENTES.md` y `PROGRESO.md`, todos en `P-ZRX/P-POOLS/investigacion/`.

---

## Lo que esta investigación NO resuelve

`[D]`

1. **No mide `β_p`.** No cuantifica cuánto espacio podría capturar un pool hostil, ni su efecto sobre la frontera `α*`, porque no hay pools ni parámetros de red fijados y no se inventa un número.
2. **No decide la identidad de billete.** La elección entre `C-GD-07` (con `chunk`) y `IDV-01`/`CANDIDATA` (sin `chunk`) cambia la **detectabilidad** de la firma ciega, pero es una decisión abierta de `P-PRESTAMO` y `P-EQUIVOCACION`; aquí solo se cruza.
3. **No propone texto de SPEC ni fija ningún parámetro.** Las reglas candidatas de `ARQUITECTURA.md` son propuestas, con su estatuto marcado; ningún `<<PENDIENTE>>` se cierra.
4. **No ha auditado la implementación por completo.** Lo que se afirma sobre el código se limita a la **cabecera y al camino de consenso**, que es donde el encargo lo pide. Tres precisiones que salieron de una verificación independiente y que acotan lo afirmado: `[VF]` (a) el sello está implementado (`crates/zx-core/src/preimage/dag.rs:412-416`) pero **sin cablear**: `verificar_sello` solo aparece en su definición y en tests, y `ci/reglas-sin-cablear.txt` declara `C-HDR-05`, `C-HDR-06`, `C-HDR-07` y `C-HDR-09` (`:45-48`) **pero no** `C-HDR-03`/`C-HDR-04` — un punto ciego del inventario, que es un `grep` y no un grafo de llamadas; (b) la validación de la solución PoAS real (`C-FLU-13`) y `C-FLU-14`/`C-GD-10` están declaradas **sin código** (`ci/reglas-sin-codigo.txt:249-250`, `:275-276`, `:180`); (c) la ruta de validación activa usa una **cabecera lineal sin `sol`** (`crates/zx-consensus/src/bloque.rs`), de modo que una regla sobre `sol.public_key` solo sería comprobable en la ruta DAG, hoy sin cablear. En `crates/` el término «pool» existe con otros sentidos (el módulo de mempool, `zx-mempool`); **ninguno es un pool de farming**.
5. **No ha verificado el flujo completo del nodo de Autonomys.** El precedente de arquitectura 3 (el nodo pide la firma del hash que compone) se apoya en rutas vendored leídas por lectura delegada y **fuera de los tres ficheros que el encargo manda abrir**; está marcado como tal y no se usa como regla de ZEROX.
6. **No cierra el griefing ni la detección.** Aun adoptando todo lo propuesto, un pool hostil puede seguir provocando la confiscación del lote de un granjero que no hizo nada (puntos 1.4.5 y 2.3). Y la **variante silenciosa** (§1.2, arquitectura 3) no deja evidencia alguna: si el pool nunca produce el bloque honesto de ese `(billete, slot)`, no hay dos firmas que comparar. Definir una infracción que distinga autor de tenedor de clave **no es posible** con las herramientas actuales, y un mecanismo que detecte el uso exclusivo en una rama privada **tampoco existe**; este informe no propone ninguno.
7. **No trata la capa blindada.** Si v1.1 introduce un pool blindado con reglas propias, la interacción con lo anterior está fuera de alcance por decisión del encargo.
