# INFORME — DS-2 · Matriz ataque × mecanismo para ZEROX, con costes absolutos y veredictos

**Ejecutor:** Sonnet (análisis; sin código salvo la aritmética de comprobación citada, ninguna
ejecutada aquí — todas las cifras numéricas de este informe son citas de instrumentos ya validados
por sus propios encargos, no mediciones nuevas). **Fecha:** 2026-09-26. **Marco:**
`P-ZRX/P-DISUASION/MARCO.md`. **Orden:** `P-ZRX/P-DISUASION/ORDEN-DS2-MATRIZ.md`, incluida su §5.

**Comprobación de entrada:** `sha256sum -c P-ZRX/P-DISUASION/ENTRADA-DS2.sha256` → **la suma
coincide** (comprobado al empezar). Se repite al final de este documento.

**Etiquetas usadas:** **hecho** (medido o citado de fuente primaria abierta y leída en esta
sesión) · **derivación** (álgebra o lectura sobre hechos) · **hipótesis** (sin medir, con alcance
declarado). Cuando una celda hereda un resultado de un encargo `P-ZRX/*` ya validado por Claude,
se marca **hecho (heredado)** con la ruta exacta.

---

## 0 · Regla de la orden: antes de contradecir una refutación anterior

Para toda celda que proponga que un mecanismo de PoStake o Filecoin encarece de forma exigible un
ataque que `D-ZRX/RFT-ZRX.md` da por cerrado, este informe responde primero, por escrito, **si el
mecanismo elimina exactamente la premisa explotada**. Se hace caso por caso en §3.2 (A1, A3, A4,
A5, A7, A8) y se resume aquí para las refutaciones más citadas:

- **RFT-01** (la rama privada no deja evidencia): la premisa es *ausencia de un objeto
  verificable*. Ningún mecanismo de PoStake o Filecoin catalogado en `MARCO.md` §3 crea ese
  objeto cuando el atacante no publica: M3/M4 (castigo con evidencia/correlacionado) necesitan que
  **algo se publique**; no la eliminan. **La refutación se hereda intacta** para el caso `κ=0`.
- **RFT-03/RFT-04/RFT-06** (un compromiso de valor no fecha nada; auditar no distingue guardado de
  regenerado; el sellado ligado a la rama no existe): la premisa es que el objeto ploteado de
  Autonomys es **determinista, público y paralelizable**. Ningún mecanismo de Filecoin (F1, F2,
  F3, F4, F5) cambia esa naturaleza del objeto: todos actúan **alrededor** de él (registro,
  auditoría, colateral), no lo sustituyen. `P-ZRX/P-COBERTURA/investigacion/INFORME.md` Corolario 4
  y `P-ZRX/P-SELLO/investigacion/INFORME.md` F3 lo demuestran para la clase entera de mecanismos
  «compromiso + auditoría». **Las refutaciones se heredan**; lo que cambia es el coste (§3.2, A3).
- **RFT-05** (toda regla por identidad se evade partiendo el espacio): la premisa es que crear una
  identidad nueva cuesta lo mismo por byte que usar una existente. M6 (requisito proporcional) y F1
  (registro de sectores) **no** cambian esa premisa si el requisito es proporcional al espacio
  (`φ(f)=σf`): la partición sigue siendo neutra. Solo un coste **no proporcional** (M1 fijo, F4
  colateral fijo por sector) rompe la premisa, y entonces el coste barato para el pequeño y
  regresivo para nadie que sea **proporcional** (P-TASA F4: «partir cuesta» y «ser regresivo» son
  la misma condición). **La refutación se hereda con esa condición exacta.**
- **RFT-09** (un VDF por rama no es rival): la premisa es que dos núcleos permiten dos líneas de
  VDF, una por rama. El PoT de ZEROX (`D-P10`, un solo flujo, ver §5.3) **no** elimina esa premisa:
  sigue siendo posible correr dos flujos completos en dos núcleos. **Se hereda.**

---

## 1 · Respuesta a la pregunta falsable

> «Al menos un mecanismo de PoStake o de Filecoin encarece de forma **exigible** uno de los
> ataques A1, A3, A4 o A5 frente a B0.»

**Respuesta: CONFIRMADA de forma parcial y estrecha, con matices que importan más que el titular.**

- **A4 (Sybil / partición de identidades):** ningún mecanismo la cierra por diseño (RFT-05
  intacta), pero **M1/F4 (requisito o colateral fijo por identidad/sector) SÍ son E-exigible** en
  el sentido literal de la definición del marco: recaen sobre el atacante haga lo que haga (es
  condición previa para producir), y **no dependen de detección**. Su límite, ya conocido, es que
  solo dominan por debajo de un tamaño de granja (RFT-05, R-5): frente al atacante grande del
  modelo de amenaza de Katana, el coste marginal por partición tiende a 0 según el atacante
  agrega espacio. **Es una mejora real y acotada, no un cierre.**
- **A1 (doble farmeo):** **ningún mecanismo de PoStake o Filecoin catalogado alcanza E-exigible**
  contra el atacante grande (`κ→0` con `m≥4`, P-EQUIVOCACION). Lo más cerca que llega el catálogo
  es M3+M5 (castigo con evidencia + retardo de retiro), y es **E-condicionado**, con una región
  `(ρ_ret,T_v)` que **excluye exactamente** los casos que importan bajo el modelo de amenaza:
  `κ=0`, censura de la prueba, `V` sin cota y claves nuevas rotadas (P-CLAVE F6). **La pregunta
  falsable, para A1, queda REFUTADA** frente a un atacante que no publica o que rota claves.
- **A3 (sembrador):** ningún mecanismo **cierra** el ataque sin cambiar el objeto ploteado (RFT-04
  intacta), pero **F1+F2+F4 (registro + auditoría + colateral) SÍ son E-exigible** en un sentido
  medido y no trivial: fuerzan al atacante a pagar **117,2 núcleos/TiB continuos** (o 5,79 máquinas
  agregadas por TiB) mientras dure el ataque, ≈1.524× la energía de solo almacenar
  (P-COBERTURA §5.4). **Es una mejora real, cuantificada y exigible en el sentido de la definición
  del marco** (recae sobre el atacante mientras sigue sembrando, no depende de que nadie lo
  denuncie: la auditoría periódica es automática). El límite es que, por debajo de `k=B≈181.092`
  aperturas por TiB, **la auditoría no detecta nada en absoluto** — el coste es real pero la
  *detección* es condicionada al diseño de `k`.
- **A5 (producir con espacio ajeno / pools):** **O4 (atar la coinbase a `sol.public_key`, tipo
  Chia) es E-exigible y cierra el incentivo económico** de la variante de firma ciega (arquitectura
  3), sin depender de detección: el pool que firma a ciegas ya no puede cobrar. **No cierra la
  capacidad** de producir en la rama que el pool elija (P-POOLS §1.3), y **no alcanza** la
  arquitectura Chia-like (O4 la hace innecesaria) ni la arquitectura de pool-firma (parcela
  ploteada a la clave del pool). Es la celda más limpia del catálogo: **E-exigible, sin condición
  de detección, con alcance exacto y documentado.**

**Conclusión operativa:** la pregunta falsable se confirma **para A3, A4 y A5** en el sentido
estrecho de que existe al menos una celda E-exigible medible; se **refuta para A1** frente al
atacante que el modelo de amenaza de Katana obliga a asumir (grande, con recursos, dispuesto a no
publicar o a rotar claves). Ninguna de las cuatro queda **cerrada**: RFT-01, RFT-04, RFT-05 y RFT-06
siguen aplicando en su alcance exacto.

---

## 2 · Respuesta a Baig y Pietrzak: ¿qué escapa a la imposibilidad, y es ZEROX de esa clase?

**Fuente:** Baig, Pietrzak, *On the (in)security of Proofs-of-Space based Longest-Chain
Blockchains*, FC 2025, arXiv:2505.14891, leído íntegro (22 páginas + apéndices) en
`deepseek/DS2/baig-pietrzak.pdf`. Todas las citas de esta sección son **hecho** (lectura directa).

### 2.1 · Qué dice literalmente el artículo sobre las salidas

El §3 («Discussion and Open Problem») es explícito:

> «Recall that our attacker can replot space and bootstrap the chain. Two existing PoSpace based
> chains, Chia and Filecoin, avoid our impossibility in **different** ways. Chia prevents
> bootstrapping by additionally using proofs of time... Filecoin avoids replotting by using a BFT
> (rather than longest-chain) type protocol.»

Y, sobre si bastaría con comprometerse al espacio sin comprobaciones periódicas (el régimen de
«disponibilidad dinámica» que es exactamente el de una blockchain de cadena más larga sin
autoridad central):

> «The answer is no: an adversary can simply plot and commit to many different proofs of space in
> the honest chain and then later replot them when launching an attack. Thus our result precludes
> PoSpace based Nakamoto like longest chain blockchain in both fully permissionless and dynamic
> availability setting.»

El ataque del Teorema 1 combina **dos** primitivas del atacante, definidas en §2.3: **bootstrapping**
(fabricar instantáneamente un prefijo de cadena con marcas de tiempo inventadas, extendiendo un
`C_0^j` conocido sin coste de reloj) y **replotting** (fingir tener `k` veces más espacio
replanteando la misma parcela `k` veces, a coste `k·ρ` pasos). El modelo del §1.2 («Attacks») lo
dice explícitamente: *«while there's no simple way to prevent replotting, to prevent bootstrapping
we need additional primitives like VDFs»* — es decir, el propio artículo identifica el VDF como el
supuesto adicional que ataca **la mitad bootstrapping** del vector, no la mitad replotting.

### 2.2 · Los dos supuestos adicionales, clasificados

| Supuesto adicional | Qué mecanismo del vector ataca | Efecto sobre el modelo del Teorema 1 |
|---|---|---|
| **VDF encadenado** (Chia) | **Bootstrapping**: el reto del bloque `i+1` depende computacionalmente (con coste de tiempo real) de la salida del bloque `i`. Fabricar un prefijo de golpe exige recorrer el VDF en tiempo real, no en un paso | Saca al sistema de la clase «prueba barata, sin coste de tiempo entre bloques» que el modelo de §1.2 supone al permitir bootstrapping. **No** ataca el replotting: el atacante sigue pudiendo replantear su propio espacio real, solo que ya no puede fingir marcas de tiempo pasadas de un tirón |
| **BFT + registro de espacio** (Filecoin) | **Replotting**: al exigir registro previo del espacio y pruebas periódicas continuas (`WindowPoSt`), solo el espacio **registrado** puede usarse para minar, y registrar más del que se controla exige probarlo constantemente | Cambia el **régimen** entero: dejamos la familia «cadena más larga, totalmente sin permiso» (el dominio exacto del Teorema 1) por una familia «cuasi-sin-permiso» (participantes conocidos, siempre disponibles) que el propio artículo (citando a Lewis-Pye & Roughgarden) declara **fuera** del alcance del resultado |

**Ninguna de las dos vías está demostrada segura por este artículo.** El artículo no prueba que
Chia o Filecoin sean seguros: solo dice que su combinación de primitivas **no está cubierta** por
la prueba de imposibilidad, porque cada una rompe una de las dos hipótesis usadas en la
construcción del adversario (bootstrapping sin coste, o espacio no registrado/no auditado).

### 2.3 · ¿Es el PoT de un solo flujo de ZEROX (D-P10) de la clase que escapa?

**Sí, para la mitad bootstrapping — y con las mismas palabras que usa el artículo para Chia.**

El PoT de ZEROX (`D-ZRX/SPEC-0.0.1.md` §4, D-P09…D-P11: «un solo flujo sin inyecciones», reto de
cada slot derivado de la salida del PoT del slot anterior, `zx-post::pot`) es estructuralmente la
descripción que el propio artículo da de Chia en su Introducción:

> «One can think of (a simplified version of) Chia as simply alternating PoSpace with VDFs, where
> the challenge for the next VDF (PoSpace) is computed from the previous PoSpace (VDF output).
> Bootstrapping such a chain is not possible as the main security property of a VDF requires that
> computing its output requires time.»

ZEROX encadena el reto del slot `s+1` a la salida del flujo PoT que incorpora el resultado del
slot `s` (`C-POT-03`, `SPEC.md` §7.1.1, citado en `P-ZRX/P-IDENTIDAD/investigacion/INFORME.md`
§2, E1: `reto(f,s) = blake3(aleatoriedad(f,s) ‖ LE64(s))`). Esto es exactamente el patrón
«VDF encadenado» que el artículo llama la salida de Chia. **Por tanto: el PoT de un solo flujo de
ZEROX escapa a la construcción específica del Teorema 1 en su componente de bootstrapping, por la
misma razón estructural que el artículo concede a Chia.**

**Pero eso no cierra A1 en ZEROX, y hay que decirlo con la misma precisión que exige la orden.**
El propio repositorio de ZEROX ya había llegado, por un camino independiente, a la distinción
exacta que el artículo hace entre bootstrapping y replotting:

> **RFT-09** (`D-ZRX/RFT-ZRX.md`): «Un VDF por rama se paraleliza entre ramas: dos núcleos, dos
> ramas; el segundo VDF no defiende del doble farmeo (sí sirve para la ventana de adelanto, otro
> problema).»

Esto es la mitad del vector de Baig-Pietrzak que el VDF **no** ataca: un atacante con dos núcleos
puede correr **dos líneas completas de VDF en tiempo real**, una por rama, sin fabricar marcas de
tiempo falsas (no hay bootstrapping) y sin replantear nada más rápido de lo que permite el reloj
físico. Esa es precisamente la carrera de rama privada ordinaria de Nakamoto (RFT-01: la rama
privada no deja evidencia), que CRP-v0.1 ya modela con el umbral `α*` de §2.1 de este informe. **El
PoT de un solo flujo no toca esa carrera**: la elimina el requisito de que el atacante tenga que
computar su VDF en tiempo real igual que el honesto, no que no pueda tenerlo en absoluto.

Y hay un segundo matiz, propio de ZEROX y no del artículo, que la investigación previa del
repositorio ya cuantificó: la ventaja de reloj (`ρ>1`, un atacante con AES más rápido) **reabre**
una versión del mismo problema de fondo —fabricar el futuro antes que el honesto— aunque de forma
proporcional, no absoluta:

> **RFT-12**: «La tesis "sup A = 0 con ρ_max ≤ ρ*" y "la edad colapsa" son falsas: sin segundo VDF
> el adelanto ≈ L para todo ρ>1; con él, (L+I)(1−1/ρ).»

Es decir: el VDF de un solo flujo cierra el bootstrapping en el sentido estricto del Teorema 1
(marcas de tiempo fabricadas de un tirón, coste cero), pero **no** cierra la versión física del
mismo problema que aparece cuando el reloj del atacante es más rápido que el del honesto (§2 de
`AGUJEROS-Y-SOLUCIONES.md`, agujero B1): ahí la ventana de adelanto es proporcional a `1−1/ρ`, no
cero. Es una versión debilitada, medida y distinta del ataque de Baig-Pietrzak, no el mismo
ataque reabierto: el artículo asume relojes honestos idénticos y ataca con marcas de tiempo
inventadas; ZEROX, además, tiene que lidiar con relojes honestos que pueden ser más lentos que el
del atacante, algo que el artículo no modela.

### 2.4 · ¿Es `C-FIN-01` (finalidad) de esa clase?

**Parcialmente, y por la otra vía que el artículo menciona de pasada (checkpointing), no por la
vía BFT/registro de Filecoin.** El artículo, al describir la regla de selección de cadena más
pesada (§2.2), añade una nota que no desarrolla:

> «Most proposed and deployed longest-chain blockchains use a highest weight rule like this, **in
> some cases augmented with checkpointing or finality gadgets that prevent miners from replacing
> their current chain with another chain that forks too far in the past even if it has a higher
> weight**.»

`C-FIN-01` es exactamente eso: un nodo en línea rechaza sustituir su cadena por una que bifurque a
profundidad `d ≥ F_slots`, sea cual sea su peso (H-6, `ESTADO-DOBLE-FARMEO.md` §2). El artículo
**no** analiza formalmente esta familia — solo la menciona como excepción existente en sistemas
reales — así que **no hay una demostración de que cierre o abra la imposibilidad**; lo único que
puede decirse con la evidencia disponible es lo que el propio ZEROX ya midió: `C-FIN-01` acota el
**daño** (ninguna reorganización más allá de `F` se acepta) pero no cambia el `α*` de la deriva
dentro de la ventana (P-PRESTAMO §2: dentro de `F`, la probabilidad de ganar salta a orden 1
exactamente al cruzar `g=0`, no antes). **`C-FIN-01` no es la vía de escape de Baig-Pietrzak**:
no ataca ni el bootstrapping ni el replotting; es una salvaguarda estructural distinta
(equivalente a checkpointing) que limita el alcance temporal de cualquier ataque que sí tenga
éxito, y que el propio artículo no evalúa. Su límite conocido es el mismo que el de todo
checkpointing: solo protege a un nodo que permanece en línea (`AGUJEROS-Y-SOLUCIONES.md` D4, IPA
D4: un nodo que se reincorpora tras una partición mayor que `F` no tiene esa protección sin un
mecanismo de sincronización adicional).

### 2.5 · Qué cambia para A1 y A7

- **A1 (doble farmeo):** la construcción específica del Teorema 1 (bootstrapping + replotting para
  fabricar un fork de longitud `ℓ=O(ρ²φ²/ε)`) **no se aplica literalmente a ZEROX** porque el PoT
  de un solo flujo cierra el bootstrapping. **Pero A1 sigue abierto por la vía que RFT-01/RFT-09 ya
  habían identificado independientemente** (carrera de rama privada en tiempo real, sin
  bootstrapping): la refutación de A1 en ZEROX **no depende** del resultado de Baig-Pietrzak y
  **no la contradice ni la refuerza**; son dos vectores distintos que comparten familia (PoSpace de
  cadena más larga) pero no premisa. `C-FIN-01` acota el daño, no la posibilidad.
- **A7 (largo alcance):** aquí el artículo sí es más relevante, porque el ataque de largo alcance
  es, en esencia, fabricar una historia alternativa larga — el mismo tipo de objeto que el Teorema
  1 construye. El PoT de un solo flujo **encarece la fabricación de una historia alternativa larga
  en tiempo comprimido** (no se puede recorrer el VDF más rápido que en tiempo real, salvo con
  ventaja de reloj `ρ`), lo cual es una mejora real frente a un PoSpace puro sin VDF (que sí podría
  bootstrappear un prefijo entero de golpe). Pero el ataque de A7 en ZEROX no depende solo de
  fabricar bloques rápido: depende de **claves antiguas o retiradas** que ya no cuestan nada de
  reunir (RFT-ZRX no tiene una fila específica para A7 con PoStake, y `IPA-ZRX.md` A-07 declara el
  sesgo del terminal como problema abierto). El PoT ayuda a la parte «tiempo de cómputo» de A7; no
  toca la parte «disponibilidad de claves antiguas», que es el vector clásico de largo alcance en
  sistemas de stake (Ethereum: subjetividad débil; Casper: `≥1/3` de los validadores debe violar un
  mandamiento). ZEROX no tiene voto público de finalidad por stake, así que esa vía de defensa
  (§1.3 de `R-ZRX/LEGADO/stake/MAPA.md`) sigue bloqueada por `AGENTS.md` (sin comités).

**Resumen de la sección:** el PoT de un solo flujo de ZEROX **sí** es de la clase de supuesto
adicional que el artículo reconoce para Chia (VDF que impide bootstrapping), y esto se puede
afirmar con cita literal y sin necesidad de reinterpretar el artículo. `C-FIN-01` **no** es esa
clase: es un mecanismo de checkpointing que el artículo menciona sin analizar, y su efecto medido
en ZEROX (acotar el daño, no el umbral) es consistente con esa lectura. Ninguna de las dos cierra
A1 por la vía de la carrera de rama privada en tiempo real, que sigue siendo RFT-01/RFT-09 sin
modificar.

---

## 3 · Matriz ataque × mecanismo

Convenciones: **I** imposible bajo los supuestos listados; **Ee** encarece, exigible; **Ec**
encarece, condicionado a detección/inclusión de evidencia; **N** neutro; **W** empeora. Cuando B1
ya incorpora el mecanismo (M1, M2, M5 — `MARCO.md` §1), la columna «B1» dice **ya-en-B1** y el
veredicto que sigue es el efecto **marginal** de añadir el resto del catálogo sobre esa base.

### 3.1 · Mecanismos de PoStake

| Ataque | M1 garantía mínima | M2 coinbase→garantía madura | M3 castigo con evidencia | M4 castigo correlacionado | M5 retardo de retiro | M6 requisito proporcional |
|---|---|---|---|---|---|---|
| **A1** doble farmeo | N (frente a B0: **Ee** débil — barrera de entrada, no de doble uso; ya-en-B1) | N (precondición de M3; sin M3 no disuade — P-PRESTAMO F3: «sin castigo, farmear doble es dominante y gratis»; ya-en-B1) | **Ec** — depende de κ; con `m≥4` (atacante grande) κ→0 ⇒ colapsa a N (P-EQUIVOCACION §1.2) | **Ec, no evaluado** — mismo problema de κ que M3; podría separar accidente de ataque coordinado pero nadie lo ha medido (`R-ZRX/LEGADO/stake/MAPA.md` §5.2) | N solo (precondición de M3; ya-en-B1); con M3: región estrecha, ver §3.2 | N — proporcional al espacio, no cambia con partir en dos ramas (RFT-05) |
| **A2** equivocación publicada | N | N | **Ec** — κ=1,000 si `m≤0,05`; 0,455 si `m=1`; **0,000 si `m=4`** (P-EQUIVOCACION, tabla exacta) | **Ec, no evaluado** | ya-en-B1 (retención necesaria para que la evidencia tardía alcance algo) | N |
| **A3** sembrador | **Ee** débil — barrera de entrada general, no ataca la regeneración (RFT-04 intacta) | N | N — la equivocación no es el vector del sembrador | N | N | N |
| **A4** Sybil/partición | **Ee**, con límite conocido: domina solo por debajo de un tamaño de granja (RFT-05, R-5); frente al atacante grande, coste marginal por partición → 0 | N | N | N | N | N — proporcional, no rompe la neutralidad de partir (RFT-05, R-9) |
| **A5** espacio ajeno/pools | N (M1 lo paga quien produce, sea granjero o pool) | N | **Ec**, y **solo si `C-GD-07` conserva `chunk`**: la doble firma queda atribuida al granjero, no al pool (P-POOLS §1.2) — **efecto adverso**, ver §4 | N, no evaluado | N | N |
| **A6** grinding de retos | N | N | N | N | N | N |
| **A7** largo alcance | N | N | **Ec, no evaluado en el repositorio para PoStake**: ningún informe cruza M3 con claves retiradas | N | **Ee condicional**: si `R_slots` obliga a mantener la garantía activa mucho más allá de la ventana de reescritura, encarece reunir claves «viejas todavía activas»; no evaluado con cifras | N |
| **A8** captura de la transición | N — M1/M2 son de fase PoST; A8 ocurre en la fase PoW | N | N | N | N | N |
| **A9** retención/censura DAG | N | N | **Ec** solo si la censura misma deja evidencia objetiva (no evaluado) | **Ec, no evaluado** | N | N |
| **A10** alta tardía/capacidad duplicada | **Ee** débil (barrera de entrada única, no distingue alta tardía de temprana) | N | N | N | N | N |
| **A11** eclipse | N — es capa de red, no de stake | N | N | N | N | N |
| **A12** efecto secundario (denuncias falsas, castigo a honestos) | — | — | **W** — P-EQUIVOCACION Parte B: *harvesters* redundantes, reinicio con pérdida de estado y reempaquetado producen la misma evidencia que un atacante; sin firmante seguro, el honesto cae con probabilidad no despreciable | **W** si se activa sin resolver el falso positivo correlacionado (nunca examinado) | **W** — retención confiscatoria si `ρ_ret·T_v·ν≥1` (P-CLAVE F5: cobra al honesto más que todo su ingreso) | N |

### 3.2 · Mecanismos de Filecoin

| Ataque | F1 registro/precompromiso | F2 auditorías periódicas | F3 sellado lento (PoRep/SDR) | F4 colateral por sector | F5 ciclo de vida |
|---|---|---|---|---|---|
| **A1** doble farmeo | N — RFT-06: el sellado/registro no ata el objeto a una rama; un sector registrado es válido en cualquier rama | N — audita «¿sigue guardado?», no «¿en qué rama?» | N — P-SELLO F3/F6: «vía muerta», dicotomía espacio/presupuesto sin solución para un objeto determinista-público | N — mismo argumento que M1/M4 (barrera de entrada, no de doble uso) | N |
| **A2** equivocación publicada | N | N | N | N | N |
| **A3** sembrador | **Ee** — obliga a poseer el lote durante `M` (edad) y a responder auditorías con el lote entero; con `k>B` (§2.9), coste medido: 117,2 núcleos/TiB continuos, 5,79 máquinas/TiB, ≈1.524× energía de almacenar. **No cierra**: la preexistencia sigue sin acreditarse (Corolario 4, P-COBERTURA) | **Ee, condicionado a `k>B`**: con `k≤B≈181.092` aperturas/TiB, **no detectable en absoluto**, independiente de `k` (frontera exacta, P-COBERTURA F4) | **I bajo supuestos**: si el sellado exige profundidad secuencial `>` ventana de adelanto, elimina la regeneración — pero exige **cambiar el objeto ploteado** (romper la clase determinista-pública), replotear toda la red y aceptar riesgo ASIC (P-SEMBRADOR ficha B, P-COBERTURA F3-ii) | **Ee** — mismo mecanismo que F1 en la práctica (colateral es el «precio» que hace rentable exigir F1+F2); coste medido igual que F1 | **Ee** débil — activación retardada añade la misma edad `M` que F1; expiración pseudoaleatoria ya existe en el formato base y no depende de este ataque |
| **A4** Sybil/partición | **Ee**, mismo límite que M1 si el depósito por sector es fijo; **N** si es proporcional al tamaño del sector (RFT-05) | N | N | **Ee**, mismo argumento que F1 | N |
| **A5** espacio ajeno/pools | N — F1 registra `SectorId` ligado a clave, no impide que el pool reciba soluciones | N | N | N | N |
| **A6** grinding de retos | N | N | N | N | N |
| **A7** largo alcance | **Ee, condicionado**: el registro con edad obliga a que un sector reescrito «desde hace un mes» tenga que volver a probarse desde su alta — pero eso exige llevar la cuenta desde el registro, no está modelado para ZEROX | N | **Ee — el mecanismo con cita literal más fuerte del catálogo**: *«mixing chain randomness in makes an attacker going back a month in time to try and create their own chain have to completely regenerate any and all sectors»* (Filecoin spec, DS-1 [P]). Ataca A7, no A1 (RFT-06 ya lo distingue) | **Ee, condicionado** — si `MIN_TERMINATION_FEE` u otra penalización se aplica a sectores cuya historia se reescribe, encarece el abandono de la rama vieja; no modelado para ZEROX | N |
| **A8** captura de la transición | N — F1-F5 son de fase PoST; A8 ocurre antes del corte | N | N | N | N |
| **A9** retención/censura DAG | N | **Ec** — un sector que deja de auditarse a tiempo por censura de red incurre en `Fault Fee` automático (Filecoin, DS-1 [P]); análogo no evaluado para ZEROX | N | **Ee** — el `Fault Fee` de Filecoin es automático y no depende de que un tercero denuncie (DS-1: «lo detecta el protocolo»); trasladable en principio, no evaluado con cifras de ZEROX | N |
| **A10** alta tardía/capacidad duplicada | **Ee** — el registro fecha el alta (aunque no la preexistencia, RFT-03); una capacidad «duplicada» tendría que registrarse dos veces, cada una con su edad | N | N | **Ee** — el colateral se paga por cada alta, incluida la duplicada | **Ee** — la activación retardada limita cuánta capacidad nueva puede entrar de golpe |
| **A11** eclipse | N | N | N | N | N |
| **A12** efecto secundario | — | **W** si `k` se fija sin medir falsos fallos domésticos (apagón, corte de red — P-CLAVE §10 lo señala como no medido) | **W** — coste de hardware/ASIC nuevo también lo paga el honesto, y el riesgo de ventaja ASIC no está evaluado | **W** si el colateral perdido por un fallo honesto (corte de red) no se distingue del sembrador (mismo problema que M3/A12) | N |

### 3.3 · Otros mecanismos (O1–O5)

| Ataque | O1 PoW de arranque | O2 PoT/VDF (D-P10) | O3 finalidad C-FIN-01 | O4 coinbase→firmante (tipo Chia) | O5 otras fuentes |
|---|---|---|---|---|---|
| **A1** doble farmeo | N tras el corte (RFT-09: aditivo no baja nunca V; multiplicativo diluye solo si el honesto compra mayoría de hash, que el atacante también puede comprar) | N para la carrera en tiempo real (RFT-09); **Ee para el bootstrapping instantáneo** (§2.3, escapa a Baig-Pietrzak en ese componente exacto, no en el de la carrera) | **Ee estructural** (no depende de detección): acota el daño a `d<F_slots`; no cambia el umbral `α*` dentro de la ventana (P-PRESTAMO §2) | N — ata la recompensa, no el peso | Spacemint «punishment tx»: **Ec, igual que M3** — exige que se publiquen los dos bloques (DS-1, confirmado) |
| **A2** equivocación publicada | N | N | N | N | Ethereum slashing por doble voto: **Ec** — misma dependencia de evidencia que M3 (DS-1) |
| **A3** sembrador | N | N — el PoT no ata el objeto ploteado a nada; RFT-04 intacta | N | N | Spacemesh ATX+NIPoST: **I bajo supuestos** de cambio de formato — mismo estatuto que F1+F3 combinados (P-SEMBRADOR ficha G); Chia: **no aporta nada** (no compromete bytes, DS-1 §1.2) |
| **A4** Sybil/partición | N | N | N | N | N |
| **A5** espacio ajeno/pools | N | N | N | **Ee, sin condición de detección — la celda más limpia del catálogo**: quita el premio de la firma ciega (arquitectura 3); no quita la capacidad ni cierra la arquitectura 2 ni la de pool-firma (P-POOLS §1.3) | Chia-like (parciales, el granjero construye y firma): **I por arquitectura** — el pool nunca recibe una firma sobre `pre_hash`; exige rediseño de protocolo de pool, no es una regla de consenso (P-POOLS Arquitectura 4) |
| **A6** grinding de retos | N | **Ee estructural** — el PoT de un solo flujo ya elimina el grinding de reto que dependería del padre elegido (RFT-08: aplica solo si el reto puede re-muestrearse gratis; con PoT encadenado, no) | N | N | N |
| **A7** largo alcance | **Ee condicional** (RFT-13: mientras dure el prefijo PoW, reescribirlo exige `W_min` de trabajo; tras el corte no aplica) | **Ee** — ver §2.5: encarece fabricar una historia alternativa larga en tiempo comprimido, no la disponibilidad de claves antiguas | **Ee estructural** — mismo mecanismo que para A1: acota `d<F_slots`; es la defensa dominante de ZEROX contra A7 en el sufijo PoST | N | Ethereum weak subjectivity / checkpoint de confianza: **Ec** — depende de que el nodo consulte una fuente externa, que `AGENTS.md`/IPA D4 tratan como «ayuda al operador, nunca regla de consenso» |
| **A8** captura de la transición | **Ee, medido**: reescribir `k` bloques antes del corte es la carrera de Nakamoto (`h`,`k`); con `h=0,25,k=6`: éxito ≈0,039 (RFT-13, T02-A). Censura de depósitos con `h=0,9,M_dep≥6`: domina 81–99,98 % (IPA A-08) | N — el PoT es de fase PoST, A8 ocurre en fase PoW | N — `C-FIN-01` no aplica antes del primer bloque PoST | N | N |
| **A9** retención/censura DAG | N | N | **Ee, con signo mixto** (H-6/D2 de AGUJEROS-Y-SOLUCIONES): acota reorgs, pero una `F` corta también facilita el eclipse — «F tiene signo opuesto en el doble farmeo y en el eclipse», no evaluado como interacción cuantitativa | N | N |
| **A10** alta tardía/capacidad duplicada | N | N | N | N | Spacemesh ATX por época: **Ee condicionado** a migración completa (mismo estatuto que F5+F1, P-SEMBRADOR ficha G) |
| **A11** eclipse | N | N | **W parcial** (ver A9: `F` corta ayuda al doble farmeo pero facilita el eclipse) | N | Pares ponderados por stake: **no evaluado** (`R-ZRX/LEGADO/stake/MAPA.md` §2.1, fila «eclipse»); es capa de red, no de consenso |
| **A12** efecto secundario | N | N | N — `C-FIN-01` no genera denuncias, no aplica | N — O4 no depende de evidencia, no genera falsos positivos | Penalización por correlación (Ethereum): **hipótesis sin medir** en ZEROX; es la pieza que `R-ZRX/LEGADO/stake/MAPA.md` §5 señala como «nadie la ha examinado» y que resolvería el falso positivo catastrófico que mató la propuesta 7b |

---

## 4 · Análisis detallado: A1, A3, A4, A5, A7, A8

### 4.1 · A1 — Doble farmeo

**Qué es exigible, qué depende de detección, y si el atacante puede trasladarlo.** El único
paquete que se acerca a E-exigible es M2+M3+M5 (recompensa en vesting + castigo con evidencia +
retardo de retiro), y es **condicionado por construcción**: la evidencia (`κ`) solo existe si el
atacante publica ambos bloques con el mismo billete (identidad `C-GD-07`), y `κ→0` exactamente
cuando el atacante tiene `m≥4` soluciones ganadoras esperadas por slot — el régimen del atacante
grande, no del pequeño (P-EQUIVOCACION, tabla §1.2). Incluso en la región donde `κ>0` nominalmente,
P-CLAVE F3 demuestra que existe una fracción de espacio (67,5 % con `T_v=3.600`, `ε=0,01`,
`α=0,33`) reclutable a **coste de soborno cero** porque son claves con saldo casi nulo — y esa
fracción **supera** el `β_d` que cruza la deriva (`1−2α=0,34`). El atacante **no necesita
trasladar** este coste: simplemente lo evita usando claves nuevas o rotando antes de que acumulen
saldo confiscable (P-CLAVE F4, coste de rotación: ×11 en ploteo con `T_rot=360` sobre `T_v=3.600`,
que es precio de bytes, no de saldo). `C-FIN-01` (O3) es la única pieza del catálogo que actúa sin
condicionarse a detección, pero acota el **daño** (profundidad de reorg), no el **umbral**: dentro
de la ventana, la probabilidad de éxito salta a orden 1 exactamente al cruzar la deriva, no antes
(P-PRESTAMO §2). **Conclusión: A1 no tiene, en el catálogo de PoStake/Filecoin, ninguna celda
E-exigible contra el atacante del modelo de amenaza de Katana.** Coincide con y no contradice
RFT-01/RFT-09.

### 4.2 · A3 — Sembrador

**Premisa exacta que hay que verificar antes de proponer un cierre (regla del mandato):** RFT-04
dice que, para el formato PoAS actual (objeto determinista, público, paralelizable por unidad),
ningún esquema con verificación sucinta distingue «guardado» de «regenerado dentro del plazo».
**F1+F2+F4 no eliminan esa premisa**: siguen operando sobre el mismo objeto determinista-público
(P-COBERTURA Corolario 4: un compromiso sobre el *valor* de un objeto es invariante en el tiempo, y
eso no cambia por añadir registro o auditoría). **Por tanto la refutación se hereda**, y lo único
que F1+F2+F4 aportan es **coste**, no imposibilidad — exactamente lo que el criterio de Katana
(`MARCO.md` §0) cuenta como mejora real. El coste medido: `almacenamiento_forzado = max(0,1−B/N)`
con `B=R·(w·τ+D_a)`; para 1 TiB con `w∈[7.175;8.030]` sin segundo VDF, `B≈181.092…202.492`
unidades — **el atacante que farma sembrando paga, si sigue sembrando, 117,2 núcleos/TiB
continuos** (5,79 máquinas agregadas, 6,9 GPU-equivalentes en el escenario 17× **no medido**),
≈1.524× la energía de solo almacenar (P-COBERTURA §5.4). **Es exigible sin depender de que nadie
lo denuncie** (la auditoría periódica es automática, análoga al `Fault Fee` de Filecoin que DS-1
confirma «lo detecta el protocolo»), pero la **detección** sí depende del parámetro `k`: con
`k≤B`, ninguna auditoría —por muchas veces que se repita— detecta absolutamente nada (frontera
exacta, no aproximada, P-COBERTURA F4). El atacante **puede trasladar** parcialmente el coste
comprando GPU en vez de CPU (hipótesis 17×, no medida) o esperando a que el hardware baje de
precio (el cruce de sustitución hardware↔TiB es de ≈9,8 días de ventaja de precio 1:1, P-COBERTURA
§5.4) — el coste es real y absoluto en núcleos·TiB, pero su traducción a dinero depende de precios
no verificados en este encargo (§3, `MODELO.md`). **La única vía que elimina, no solo encarece,
exige cambiar el objeto ploteado** (F3-ii sellado secuencial o F3-iv semilla secreta): ninguna
conserva el formato actual, y P-SELLO/P-COBERTURA documentan que replotear la red entera cuesta
235,65 h·núcleo/TiB.

### 4.3 · A4 — Sybil / partición de identidades

Aquí el mandato exige la comprobación explícita de si el mecanismo elimina la premisa exacta de
RFT-05: *que crear una identidad nueva cueste lo mismo por byte que usar una existente*. **M1 (y
F1/F4 si son fijos por sector/entidad, no proporcionales) sí eliminan esa premisa**, porque
imponen un coste **por identidad** que no escala con el tamaño (P-TASA §1.2, teorema de
exclusividad: el coste debe ser no-proporcional al espacio que la identidad representa). Es
**E-exigible** sin condición de detección: recae sobre cualquiera que quiera producir, lo declare
o no. Pero P-TASA F4 (demostrado, no hipótesis) añade la condición que decide si esto sirve como
defensa: *«partir cuesta» y «ser regresivo» son la misma condición* — la única cuota que **no** es
regresiva es la proporcional al espacio (variante :A, que es staking puro y `AGENTS.md` la
prohíbe). Consecuencia: un `q` o colateral **fijo** por identidad protege contra la partición
**exactamente en la medida en que castiga más a la granja pequeña que a la grande** —
`τ_min ∝ f*` (tamaño de la granja marginal): la defensa **exime casi exactamente al adversario del
modelo de amenaza de Katana** (grande, con recursos) mientras cobra una fracción no despreciable
del ingreso de un granjero doméstico. **El atacante puede trasladar el coste** distribuyendo el
requisito fijo entre menos identidades más grandes (que es justo la respuesta racional a un coste
regresivo). **Conclusión: M1/F4 son E-exigible frente a A4, con el límite exacto que RFT-05/R-5 ya
predecían — no hay forma de escapar de esa disyuntiva dentro de la familia de cuotas.**

### 4.4 · A5 — Producir con espacio ajeno (pools)

Esta es la celda más clara del catálogo completo. **P-POOLS demuestra que la premisa explotada es
doble**: (a) auditar y probar una parcela no exige ningún secreto (el pool puede recibir
soluciones sin la clave privada), y (b) nada ata el destino de la coinbase a `sol.public_key`
(§1.1.2 de P-POOLS, verificado en fuente: la validación actual de coinbase solo suma importes, no
compara claves). **O4 (atar la coinbase a `sol.public_key`) elimina exactamente la premisa (b)**:
un pool que induce al cliente del granjero a firmar a ciegas ya no puede redirigir la recompensa a
su propia dirección (P-POOLS §1.3, tabla de veredicto). Es **E-exigible sin condición de
detección**: la regla de consenso comprueba la coinbase de todo bloque, no depende de que nadie
denuncie nada. **Lo que NO cierra, y hay que decirlo con la misma precisión:** (i) no cierra la
premisa (a) — el pool sigue pudiendo producir bloques válidos para la rama que elija con el
espacio del granjero (equivocación, censura, sabotaje); (ii) no protege contra la arquitectura 2
(parcela ploteada directamente a la clave del pool, donde `P` ya es la clave del pool y el pago le
corresponde legítimamente); (iii) hay una variante silenciosa peor que cualquier falso positivo: si
el pool usa cada oportunidad solo en su propia rama y el bloque honesto de ese `(billete, slot)`
nunca llega a producirse, **hay un solo sello**, la infracción estrecha no se activa y no queda
evidencia — es un robo sin castigo, no un falso positivo (P-POOLS §1.2.2). **El atacante no puede
trasladar el coste de O4** (es una regla de consenso, no un precio), pero **puede evitarlo por
completo** cambiando de arquitectura (pool-firma o abandonando el pool para ploteo directo a su
propia clave y vendiendo acceso, que es el caso ya cubierto — y sin defensa — por C1 de
`AGUJEROS-Y-SOLUCIONES.md`: «NO encarece alquilar una parcela ya madura, su clave o su servicio
remoto»).

### 4.5 · A7 — Largo alcance

**Premisa explotada:** reescribir historia con claves antiguas o ya retiradas, o con espacio que ya
no se posee, aprovechando que nada ata el cómputo de un bloque a que ocurriera en el momento que
dice. **F3 (sellado lento con aleatoriedad de cadena) elimina esa premisa de forma literal**, con
la cita más fuerte de todo el catálogo (DS-1 [P], `spec.filecoin.io`): *«an attacker going back a
month in time to try and create their own chain would have to completely regenerate any and all
sectors»*. Es un mecanismo **ajeno** al catálogo de PoStake (no depende de garantía ni de
evidencia) y **exigible sin condición de detección**: el atacante que quiera reescribir un mes de
historia tiene que volver a sellar todos los sectores de ese periodo, lo sepa alguien o no. **El
coste es absoluto y trasladable solo parcialmente**: en Filecoin, el sellado (PoRep/SDR) exige
horas por sector y RAM ≥128 GiB (DS-1, lotus.filecoin.io), y el propio sellado **lo paga también el
honesto** una vez — no hay forma de evitarlo sin dejar de sellar. **El PoT de un solo flujo de
ZEROX aporta un mecanismo distinto para la misma familia de ataque** (§2.5): encarece fabricar una
historia alternativa **en tiempo comprimido** (no se puede recorrer el VDF más rápido que en
tiempo real salvo con ventaja de reloj medida `ρ∈[1,01;2,5]`), pero no toca la disponibilidad de
**claves antiguas** que ya cumplieron su madurez y podrían reutilizarse para firmar un pasado
alternativo — ZEROX no tiene un mecanismo de eliminación de claves antiguas ni de subjetividad
débil (weak subjectivity), y adoptar uno (checkpoint de confianza) choca con la clasificación de
IPA D4 («ayuda al operador, nunca regla de consenso»). **`C-FIN-01` es la defensa dominante de
ZEROX contra A7 dentro de su alcance** (acota cualquier reorganización a `d<F_slots` para un nodo
en línea), con el límite ya conocido de que no protege a un nodo que se reincorpora tras una
partición mayor que `F` sin sincronización adicional.

### 4.6 · A8 — Captura de la transición

Este ataque ocurre **antes** del corte, en la fase PoW, donde ni PoStake ni Filecoin aplican (son
mecanismos de la fase PoST). El único mecanismo relevante es **O1 (PoW de arranque)** frente a sí
mismo: T02-A (`P-ZRX/P-TRANSICION/T02/INFORME.md`, citado en RFT-13) mide que reescribir `k`
bloques antes del corte es la carrera de Nakamoto ordinaria, con éxito `≈0,039` para `h=0,25,k=6` y
que la censura de depósitos domina (81–99,98 % en `10⁴ T_pow`) con `h=0,9` y `M_dep≥6` (IPA A-08,
confirmado por T02-A E4). **El acoplamiento A8↔M1 que pide el encargo:** si el atacante obtiene sus
tokens **minando el prefijo PoW** (en vez de comprarlos), el coste de cumplir el requisito de
garantía M1 tras el corte se paga con el mismo hash que usó para intentar capturar la transición —
es la misma pata de recursos, no dos costes independientes. Con las cifras de A10-M1 (hecho,
medido): una GPU GTX 1070 (hardware de 2016, cota **inferior** de una GPU actual) rinde 7,6× una
CPU de 16 núcleos en reposo y consume `1,94·10⁻⁷ J/hash`; el PoW de arranque «dev» actual **no
protege nada por diseño** (`PERFIL-DEV-v0.md`, citado en la propia revisión), y para producción
faltan hash alquilable y precios (IPA A-10, parcial). **No hay ningún mecanismo de PoStake o
Filecoin que module A8**: la defensa completa depende de `H_corte_min`, `W_min` y `Φ` (predicado de
activación), todos símbolos sin valor fijado (`P-ZRX/P-TRANSICION/CONTRATO-v0.md` §1).

---

## 5 · Efectos adversos (A12 y exclusión de honestos, IPA C-07)

Todo mecanismo que salió **E** en la matriz, con su efecto adverso documentado:

| Mecanismo | Efecto adverso | Evidencia |
|---|---|---|
| **M1 (garantía mínima)** | Excluye al granjero que aporta espacio sin tokens (`C-BOT-03`, IPA C-07); en el arranque, sin oferta circulante, `requisito=0` es la única salida sin exigir compra previa (`R-ZRX/LEGADO/stake/MAPA.md` §4) | IPA-ZRX.md fila C-07; MAPA.md §4 |
| **M3+M5 (castigo con evidencia + retención)** | *Harvesters* redundantes, reinicio con pérdida de estado y reempaquetado producen la **misma** evidencia que un ataque; sin firmante seguro persistente, el honesto cae con probabilidad no despreciable (P-EQUIVOCACION Parte B); y si `ρ_ret·T_v·ν≥1`, la retención cobra al honesto **más que todo su ingreso** — deja de ser castigo y pasa a ser confiscación (P-CLAVE F5) | P-EQUIVOCACION §2 (Parte B); P-CLAVE §6.1 |
| **M3 aplicado con `C-GD-07`** | La firma ciega de un pool (A5) hace que la infracción estrecha **castigue al granjero**, no al pool: el granjero no hizo nada y pierde el lote (P-POOLS §1.2.2, FP6 ampliado) | P-POOLS §1.2, §1.2.2 |
| **F1+F2 (registro + auditoría)** | Si `k` se fija sin medir falsos fallos domésticos (apagón, corte de red), un honesto puede fallar una auditoría por causas ajenas al almacenamiento — no medido en ningún informe (P-CLAVE §10 lo señala como pendiente) | P-COBERTURA §8 (no resuelto); P-CLAVE §10 |
| **F3 (sellado secuencial)** | El coste de sellado (horas por sector, RAM alta) lo paga también el honesto una vez; introduce ventaja ASIC no evaluada, y rompe la regeneración determinista que hoy permite restaurar un sector desde el historial | P-COBERTURA §4.2 |
| **O3 (`C-FIN-01`)** | Signo mixto con el eclipse: una `F` corta ayuda contra el doble farmeo pero facilita que una partición de red gane la carrera antes de que el nodo se reincorpore (`AGUJEROS-Y-SOLUCIONES.md` D2); no hay modelo cuantitativo de la interacción | AGUJEROS-Y-SOLUCIONES.md §1.2, D2 |
| **O4 (coinbase→firmante)** | Ninguno detectado en la investigación disponible: es la celda más limpia porque no depende de evidencia ni de un umbral — pero tiene coste de **viabilidad**: un pool que quiera cobrar comisión on-chain no puede hacerlo sin un mecanismo tipo singleton de Chia, que ZEROX no tiene (P-POOLS §1.3, Opción C) | P-POOLS §1.3 |
| **Cualquier mecanismo de M-familia con requisito fijo (no proporcional)** | Regresivo por construcción (P-TASA F4, demostrado): la misma cuota que disuade la partición cuesta más del 100 % del ingreso de una granja menor que la marginal y exime casi exactamente a la grande | P-TASA §4 |

---

## 6 · Especificación del modelo para DS-3

Ver `deepseek/DS2/MODELO.md`: variables, fórmulas cerradas (§2), parámetros de escenario
declarados como hipótesis (§3) y casos de comprobación obligatorios para el Monte Carlo (§4).

---

## 7 · Respuesta a la pregunta de Katana (tabla corta, §3.5 de la orden)

| Mecanismo | Problema que resuelve o encarece | Cuánto (orden de magnitud absoluto) | ¿Exigible o condicionado? | Recomendación de evaluación siguiente |
|---|---|---|---|---|
| **M1** garantía mínima (`q`) | A4 (Sybil): barrera de entrada por identidad | Depende de `q`; regresivo — cuesta más del 100 % del ingreso de la granja marginal (P-TASA F4) | **Exigible**, sin condición de detección | Fijar `q` por escenario y medir la fracción de espacio doméstico excluida (C-07) antes de adoptarlo como defensa de A4 |
| **M3+M5** castigo con evidencia + retención | A1/A2 (doble farmeo/equivocación): solo el atacante pequeño (`m≤0,05`) | Región `(ρ_ret,T_v)` con `ρ_ret·T_v≳4.000`; frente al grande (`m≥4`), `κ≈0` | **Condicionado** a `κ>0` y a claves con saldo confiscable | No usarlo como defensa de A1 contra el atacante del modelo de amenaza; evaluar M4 (correlación, nunca examinado) como complemento antes de descartar la familia entera |
| **F1+F2+F4** registro + auditoría + colateral (Filecoin, sectores) | A3 (sembrador): no elimina, encarece mientras el atacante sigue sembrando | **117,2 núcleos/TiB continuos**, ≈1.524× la energía de almacenar; con `k≤181.092` aperturas/TiB, detección **cero** | **Exigible** (el coste), **condicionado** (la detección, a `k>B`) | Fijar `k` con el presupuesto de I/O del granjero doméstico en mente (P-COBERTURA §5.2: 3.018 lecturas/s por TiB, un SSD lo sirve, un HDD no) antes de prometer detección |
| **F3** sellado lento (PoRep/SDR) | A7 (largo alcance): reescribir historia exige regenerar todos los sectores del periodo | Horas por sector, RAM ≥128 GiB (Filecoin, DS-1); ZEROX no lo tiene implementado | **Exigible**, sin condición de detección, **si se adopta** (exige cambiar el objeto ploteado) | Evaluar como línea de investigación criptográfica separada (P-SEMBRADOR ficha B); no confundir con defensa de A1 |
| **O4** coinbase atada a `sol.public_key` | A5 (pools con firma ciega): quita el premio del robo | Coste de implementación bajo (cambio de una regla de coinbase); no cierra la capacidad de producir en rama ajena | **Exigible**, sin condición de detección — la celda más limpia del catálogo | Adoptar ya como regla de consenso candidata; combinar con recomendación de arquitectura (no plotear a clave ajena) para cerrar también la arquitectura 2 |
| **O2** PoT de un solo flujo (D-P10) | A1/A7: cierra el *bootstrapping* de Baig-Pietrzak (fabricar historia falsa de un tirón); no cierra la carrera de rama privada en tiempo real | Cualitativo: saca a ZEROX del alcance literal del Teorema 1 en ese componente | **Exigible** para el componente que cierra; **no aplica** al resto de A1 | No presentarlo como cierre de A1; sí como justificación de por qué ZEROX no hereda automáticamente la imposibilidad completa de Baig-Pietrzak |
| **O3** finalidad `C-FIN-01` | A1/A7: acota el daño (profundidad de reorg), no el umbral | Estructural (`d<F_slots`); efecto sobre `α*` nulo dentro de la ventana | **Exigible**, estructural, sin condición de detección | Medir `Δ` real para fijar `F_slots` con fundamento (bloqueante conocido desde 2026-09-08); evaluar la interacción con el eclipse (signo mixto, no cuantificada) |

---

## Comprobación de entrada, repetida al terminar

```
$ cd /home/katana/zeo/ZEROX && sha256sum -c P-ZRX/P-DISUASION/ENTRADA-DS2.sha256
P-ZRX/P-DISUASION/MARCO.md: La suma coincide
P-ZRX/P-DISUASION/ORDEN-DS2-MATRIZ.md: La suma coincide
P-ZRX/P-DISUASION/REVISION-DS1.md: La suma coincide
P-ZRX/P-DISUASION/resultados-DS1/INFORME.md: La suma coincide
```

## Rutas de entrega

- `deepseek/DS2/INFORME.md` (este documento).
- `deepseek/DS2/MODELO.md` (especificación cuantitativa para DS-3, §3.4 de la orden).
- `deepseek/DS2/baig-pietrzak.pdf`, `deepseek/DS2/spacemint.pdf`,
  `deepseek/DS2/filecoin-electricity.pdf` — los tres PDF exigidos por la §5 de la orden,
  descargados con `curl` y leídos íntegros con el lector de ficheros.
