# Chia: recorrido completo de docs.chia.net + auditoría de chiapower.org

**Fecha de consulta de todas las URLs:** 2026-09-05. **Clon local para contraste de código:**
`PDF/chia-blockchain/`, checkout `f87270c0` (`2.7.4-rc2-16-gf87270c0`, según
`research/chia-parcelas-comprimidas.md`).

Este informe recorre por primera vez completas las dos fuentes web de
`PDF/repositorio.txt` que hasta ahora solo se habían pescado sueltas: `docs.chia.net/chia-blockchain/`
(oficial) y `chiapower.org/chia-proofs-of-space/PoST` (terceros). La tercera línea del fichero
—el repositorio— ya está cubierta en `chia-parcelas-comprimidas.md` y no se repite aquí salvo para
contrastar.

**Prelación de fuentes aplicada:** código local (`PDF/chia-blockchain/`) > `docs.chia.net` (oficial)
> `chia.net` (blog oficial de la empresa, no docs) > `chiapower.org` (terceros, sin afiliación con
> Chia Network — ver §5). Donde una afirmación de `docs.chia.net` se pudo contrastar contra el código,
> se hizo, porque el propio proyecto de Chia advierte que hay funciones cuya especificación real está
> en el código y no en la prosa (ver §2, la reformulación 32 vs 64).

---

## 1 · El recorrido completo de un desafío — con los números y sus dos fuentes

### 1.1 · La sorpresa: la prosa de la doc dice «32», el código dice «64»

`docs.chia.net/chia-blockchain/consensus/chains/challenges/` (consultado 2026-09-05, sin fecha de
versión declarada en la página) dice, verbatim:

> *"The difficulty adjusts automatically to target 32 winning proofs for the entire network in each
> sub-slot, or about one winner every 18.75 seconds on average (32 winners per 600 seconds)."*

Leído aislado, esa frase se presta a confundir «32» con el número de signage points por sub-slot.
**No lo es.** El código lo separa en dos constantes distintas:

```python
# chia/consensus/default_constants.py:14  (chia-blockchain 2.7.4)
SLOT_BLOCKS_TARGET=uint32(32),
# chia/consensus/default_constants.py:17
NUM_SPS_SUB_SLOT=uint8(64),  # Must be a power of 2
# chia/consensus/default_constants.py:38
SUB_SLOT_TIME_TARGET=uint16(600),  # The target number of seconds per slot, mainnet 600
# chia/consensus/default_constants.py:39
NUM_SP_INTERVALS_EXTRA=uint8(3),  # The number of sp intervals to add to the signage point
```

`SLOT_BLOCKS_TARGET = 32` es el número de **bloques** (proofs ganadoras) que la dificultad apunta a
producir por sub-slot. `NUM_SPS_SUB_SLOT = 64` es el número de **signage points** por sub-slot —el
doble. La página de retos no usa la palabra «signage point» junto a un número propio en ningún punto
del texto recuperado; solo aparece en la mención "block 0 was created at signage point 2" (ver 1.4).

**AFIRMACIÓN:** un signage point llega cada `SUB_SLOT_TIME_TARGET / NUM_SPS_SUB_SLOT = 600/64 =
9,375 s` de media (el sub-slot completo se autoajusta para durar ~600 s; el signage point no tiene
constante propia de tiempo, es una fracción de iteraciones VDF).
**CLASE:** regla de consenso.
**ARCHIVO:** `chia/consensus/default_constants.py:17,38` (chia-blockchain 2.7.4) +
`chia/consensus/pot_iterations.py:22-24`.
**CÓDIGO:**
```python
def calculate_sp_interval_iters(constants, sub_slot_iters):
    assert sub_slot_iters % constants.NUM_SPS_SUB_SLOT == 0
    return uint64(sub_slot_iters // constants.NUM_SPS_SUB_SLOT)
```
**PARA ZEROX:** esto es exactamente el número que `PREGUNTAS-PARA-KATANA.md` P-034(a) necesita como
precedente. Chia desacopla el intervalo de *desafío* (signage point, ~9,4 s) del intervalo de
*bloque* (18,75 s de media, con `SLOT_BLOCKS_TARGET=32` bloques repartidos entre 64 signage points,
así que aproximadamente 1 de cada 2 signage points produce un ganador en la red agregada). El
intervalo de desafío **no es** el intervalo de bloque — son dos constantes distintas y Chia las
mantiene separadas a propósito. P-034(a) ya proponía desacoplar el intervalo de desafío de `T` en
ZEROX; este es el precedente real, con números.
**CONFIANZA:** alta (código + coherencia aritmética con la propia frase de la doc: 600/32=18,75
para bloques, 600/64=9,375 para signage points).

### 1.2 · Cuánto tiempo tiene el granjero — confirmado por dos fuentes independientes

`docs.chia.net/chia-blockchain/consensus/attacks-and-countermeasures/` (consultado 2026-09-05):

> *"Short Range Replotting Attack — an attacker could create plots after signage point release but
> before infusion (28 seconds)."*

El código da el mismo número por una vía completamente distinta — no es la misma fuente citándose a
sí misma:

**AFIRMACIÓN:** cada prueba ganadora se "infunde" (se hace válida para construir el bloque) no en su
propio signage point sino `NUM_SP_INTERVALS_EXTRA = 3` intervalos de signage point más tarde. Con el
intervalo de 9,375 s de arriba: `3 × 9,375 = 28,125 s` ≈ los 28 s que cita la documentación.
**CLASE:** regla de consenso.
**ARCHIVO:** `chia/consensus/pot_iterations.py:33-51` (chia-blockchain 2.7.4).
**CÓDIGO:**
```python
def calculate_ip_iters(constants, sub_slot_iters, signage_point_index, required_iters):
    sp_iters = calculate_sp_iters(constants, sub_slot_iters, signage_point_index)
    sp_interval_iters = calculate_sp_interval_iters(constants, sub_slot_iters)
    ...
    return uint64((sp_iters + constants.NUM_SP_INTERVALS_EXTRA * sp_interval_iters
                   + required_iters) % sub_slot_iters)
```
**PARA ZEROX:** es la respuesta directa a "cuánto tiempo tiene el granjero": el margen es una
constante de consenso explícita (`NUM_SP_INTERVALS_EXTRA`), no un simple "tan rápido como pueda". El
margen cubre: tiempo de lectura de disco del harvester + red harvester→farmer→timelord + margen de
seguridad. Si ZEROX define un intervalo de desafío corto (P-034a), necesita esta misma clase de
constante — un colchón fijo de intervalos, no de segundos absolutos, para que escale si el intervalo
cambia.
**CONFIANZA:** alta — cruzado entre prosa oficial y código, con coincidencia aritmética exacta.

### 1.3 · Los "overflow" signage points

**AFIRMACIÓN:** los últimos `NUM_SP_INTERVALS_EXTRA = 3` signage points de cada sub-slot (índices 61,
62, 63 de 64) se tratan como "overflow": sus pruebas se infunden ya en el sub-slot **siguiente**.
**CLASE:** regla de consenso.
**ARCHIVO:** `chia/consensus/pot_iterations.py:16-19`.
**CÓDIGO:**
```python
def is_overflow_block(constants, signage_point_index):
    if signage_point_index >= constants.NUM_SPS_SUB_SLOT:
        raise ValueError("SP index too high")
    return signage_point_index >= constants.NUM_SPS_SUB_SLOT - constants.NUM_SP_INTERVALS_EXTRA
```
**PARA ZEROX:** consecuencia mecánica de 1.2 — el mismo colchón que da tiempo al granjero obliga a
que los últimos signage points de cada ventana "empujen" su resultado a la ventana de al lado. Es el
tipo de detalle de borde que aparece tarde si no se diseña desde el principio (ver H-005/H-007 de
`DECISIONES.md`, la misma familia de error: un offset/índice que hay que derivar y no fijar a mano).
**CONFIANZA:** alta.

### 1.4 · El resto de la cadena de un desafío: filtro → quality string → prueba → iteraciones

Con las tres fuentes cruzadas (docs oficial, código, y `pos_quality`/`pot_iterations`), la cadena
completa para **PoSpace 1.0 (lo desplegado)** es:

1. El timelord publica un desafío de 256 bits al final/durante el sub-slot
   (`docs.chia.net/.../chains/challenges/`: *"Challenges are 256-bit hashes"*).
2. Cada plot local se somete al **filtro de parcela** (detalle completo en §2). Solo pasa 1 de cada
   512 en V1 hoy.
3. Para las parcelas que pasan, el harvester calcula un **quality string** de 256 bits mirando "una
   rama del árbol" (dos de los 64 x-values), sin construir la prueba completa todavía —optimización
   de disco, no un paso de seguridad distinto.
   `docs.chia.net/chia-blockchain/consensus/proof-of-space-1.0/` (consultado 2026-09-05, cita
   "Chia 1.2.7" y una especificación de septiembre de 2022 como versión de referencia):
   > *"hashed to produce a random 256-bit 'quality string'"*
4. `calculate_iterations_quality` (`chia/consensus/pot_iterations.py:90-122`) convierte esa quality
   string en un número de iteraciones VDF requeridas: **más iteraciones = respuesta más lenta =
   proof "peor"**. La fórmula es determinista: `difficulty × DIFFICULTY_CONSTANT_FACTOR × quality /
   (2^256 × tamaño_esperado_de_plot)`.
5. Solo si el número de iteraciones requerido es menor que el intervalo entre signage points
   (`sp_interval_iters`, ver 1.1) la prueba es competitiva; si no, se descarta sin construir la
   prueba completa.
6. Para las que sí compiten, se reconstruyen los 64 x-values completos (256 bytes en k32) y se firma.
7. El bloque se "infunde" `NUM_SP_INTERVALS_EXTRA` intervalos después (§1.2/1.3).

**CLASE:** todo el punto 2-7 es regla de consenso (dos nodos que difieran en la fórmula de
`calculate_iterations_quality` o en el número de x-values divergen). El punto 3 (mirar "una rama del
árbol" antes de construir la prueba completa) es **detalle de implementación**: un harvester podría
construir la prueba completa siempre y llegaría al mismo resultado, solo que más lento en disco.
**CONFIANZA:** alta para 1-2 y 4-7 (código); media para el detalle exacto de "dos de los 64
x-values" en el punto 3, que viene de la paráfrasis de la doc y no se contrastó línea a línea contra
`chiapos`/`chia_rs` (fuera del alcance de este informe, que se centra en las dos fuentes web).

---

## 2 · El filtro de parcela — completo, con el matiz que la investigación previa no tenía

`research/chia-parcelas-comprimidas.md` ya trataba las parcelas comprimidas y PoS2, pero no había
leído el mecanismo exacto del filtro de parcela. Se cierra aquí con el código, más completo que lo
que dice la prosa de la documentación.

### 2.1 · V1 — lo desplegado hoy

**AFIRMACIÓN:** una parcela pasa el filtro si los primeros `N` bits de `SHA256(plot_id ‖
challenge_hash ‖ signage_point)` son cero. `N = 9` en el arranque de la red (mainnet), lo que
descarta 511 de cada 512 parcelas (2⁹ = 512) por desafío.
**CLASE:** regla de consenso.
**ARCHIVO:** `chia/types/blockchain_format/proof_of_space.py:233-267` +
`chia/consensus/default_constants.py:29-31` (chia-blockchain 2.7.4).
**CÓDIGO:**
```python
NUMBER_ZERO_BITS_PLOT_FILTER_V1=uint8(9),  # H(plot signature of the challenge) must start
                                            # with these many zeroes, for v1 plots
...
def passes_plot_filter(prefix_bits, plot_id, challenge_hash, signage_point):
    if prefix_bits == 0:
        return True
    plot_filter = BitArray(calculate_plot_filter_input(plot_id, challenge_hash, signage_point))
    return plot_filter[:prefix_bits].uint == 0

def calculate_plot_filter_input(plot_id, challenge_hash, signage_point):
    return std_hash(plot_id + challenge_hash + signage_point)
```
La doc oficial confirma el mismo número en prosa —
`docs.chia.net/chia-blockchain/consensus/proof-of-space-1.0/` (consultado 2026-09-05):
> *"the hash of the plot ID, challenge, and signage point starts with 9 zeros"* ... *"excluding 511
> out of every 512 plots"* ... *"effectively reduces the amount of resources required for farming by
> 512x"*.

**PARA ZEROX:** este es el mecanismo que hace barato auditar que el encargo pedía. Sin él, cada
granjero tendría que leer **todas** sus parcelas en cada desafío; con él, solo 1/512 necesita
lectura de disco real, y el resto se descarta con un hash de 32 bytes de entrada fija (sin acceso a
disco). Es la pieza de anti-DoS de la que ZEROX (Autonomys/PoAS, tras el pivote de `§14`) no tiene
equivalente decidido — Autonomys, al no depender de "parcelas" arbitrarias sino de sectores que
archivan historia real, resuelve el problema de otro modo (auditoría por posición, no por hash-y-
descarta). Si ZEROX alguna vez reconsidera un esquema tipo Chia, este filtro —con su compensación
exacta en la fórmula de iteraciones (ver 2.3)— es la pieza a estudiar primero.
**CONFIANZA:** alta — código + doc coinciden exactamente.

### 2.2 · El filtro **se ablanda con el tiempo**, por altura, y es regla de consenso ya escrita

Esto no estaba en ningún informe previo de ZEROX y solo aparece leyendo el código, no la prosa de
`docs.chia.net` (la página de PoS1.0 no lo menciona).

**AFIRMACIÓN:** el número de bits exigidos por el filtro V1 **baja** en tres alturas ya fijadas en
el código, sin más contramedida que el propio calendario:

| Altura | Fecha comentada en el código | Bits exigidos |
|---|---|---:|
| genesis → `HARD_FORK_HEIGHT` | — | 9 |
| `HARD_FORK_HEIGHT` | (hard fork 1, ya activo) | 8 |
| `PLOT_FILTER_128_HEIGHT = 10 542 000` | *"June 2027"* (comentario del código) | 7 |
| `PLOT_FILTER_64_HEIGHT = 15 592 000` | *"June 2030"* | 6 |
| `PLOT_FILTER_32_HEIGHT = 20 643 000` | *"June 2033"* | 5 |

**CLASE:** regla de consenso (la altura y el valor son parte de la validación: `calculate_prefix_bits`
se llama con la altura del bloque y decide cuántos bits exige `passes_plot_filter`).
**ARCHIVO:** `chia/types/blockchain_format/proof_of_space.py:250-263` +
`chia/consensus/default_constants.py:90-95` (chia-blockchain 2.7.4).
**CÓDIGO:**
```python
def calculate_prefix_bits(constants, height, plot_param):
    prefix_bits = int(constants.NUMBER_ZERO_BITS_PLOT_FILTER_V1)
    if height >= constants.PLOT_FILTER_32_HEIGHT:
        prefix_bits -= 4
    elif height >= constants.PLOT_FILTER_64_HEIGHT:
        prefix_bits -= 3
    elif height >= constants.PLOT_FILTER_128_HEIGHT:
        prefix_bits -= 2
    elif height >= constants.HARD_FORK_HEIGHT:
        prefix_bits -= 1
    return max(0, prefix_bits)
```
**PARA ZEROX:** ni el greenpaper vigente ni `docs.chia.net/.../proof-of-space-1.0/` documentan este
calendario de ablandamiento en la prosa que se pudo leer — es lastre/decisión operativa visible solo
en el código, con las fechas puestas como comentario, no como constante nombrada (`HARD_FORK2_HEIGHT`
en cambio sí tiene su propio nombre y ya es sabido que no tiene altura real, ver `chia-parcelas-
comprimidas.md`). **Por qué se ablanda:** no se encontró una explicación oficial verificable en las
páginas recorridas; la hipótesis no verificada más plausible es que compensa el crecimiento del
netspace total (más plotters ⇒ mismo número esperado de parcelas por desafío exige menos filtro
relativo), pero **no se pudo confirmar con una fuente primaria que lo diga explícitamente** — LAGUNA.
**CONFIANZA:** alta en los números (código); baja en el motivo (no confirmado).

### 2.3 · PoS 2.0 (no desplegado) cambia el filtro de naturaleza: de probabilístico a "predecible"

Confirma y amplía lo ya sabido por `chia-parcelas-comprimidas.md` de que PoS 2.0 no corre en mainnet
(`HARD_FORK2_HEIGHT = 0xFFFFFFFA`), y aporta el detalle nuevo de **cómo** cambia el filtro si algún
día se activa.

**AFIRMACIÓN:** en V2 el filtro deja de ser "hashea y compara con cero" para pasar a ser una
igualdad exacta módulo una máscara, indexada por una ventana de 16 signage points, y el umbral de
paso depende de una "fuerza de parcela" (`plot_strength`, 2 a 17) elegida por el granjero, que
también entra en la fórmula de iteraciones para no dar ventaja neta a quien elige una fuerza alta.
**CLASE:** propuesta, no regla de consenso activa (no hay altura de activación).
**ARCHIVO:** `chia/types/blockchain_format/proof_of_space.py:270-332` (chia-blockchain 2.7.4).
**CÓDIGO:**
```python
FILTER_WINDOW_SIZE: int = 16       # SPs per filter window (64 SPs / 4 windows)
MAX_EFFECTIVE_PLOT_FILTER_BITS: int = 13  # 8192 effective plot filter cap

def passes_plot_filter_v2(plot_group_id, meta_group, group_strength,
                           filter_challenge, signage_point_index, window_size=16):
    challenge_index = signage_point_index % window_size
    mask = (1 << group_strength) - 1
    effective_filter = int.from_bytes(std_hash(plot_group_id + filter_challenge)[:4], "big") & mask
    target = (challenge_index ^ meta_group) & mask
    return effective_filter == target
```
Y el propio calendario de ablandamiento de V2 (`PLOT_FILTER_V2_RELATIVE_HEIGHT`, `chia/consensus/
default_constants.py:97-107`) está expresado en **alturas relativas a `HARD_FORK2_HEIGHT`** —de
`10 101 000` (+~6 años) a `50 494 000` (+~31 años)— lo cual es surrealista de citar como "fecha" real
mientras `HARD_FORK2_HEIGHT` en sí sea `0xFFFFFFFA`: son offsets sobre un ancla que no existe.
**PARA ZEROX:** no aplicable directamente (ZEROX no usa parcelas de Chia, per `§14`), pero es un caso
de manual sobre lo que el propio `CLAUDE.md` de este proyecto pide vigilar: código que existe y no
corre. **Confirma, con más detalle del que había, la advertencia de `chia-parcelas-comprimidas.md`
§1**: hasta el calendario de "cuándo se ablanda el filtro" de la propuesta está escrito con offsets
relativos a una altura que hoy es literalmente el máximo `uint32` menos 5.
**CONFIANZA:** alta en el código; el propio `docs.chia.net/chia-blockchain/consensus/proof-of-
space-2.0/new-proof-introduction/` (consultado 2026-09-05, "Updated: March 3, 2026") lo confirma en
prosa sin ambigüedad: *"This is a long-term project which is not expected to be finalized until
2027"* y *"The documents in this section describe a technology that is still being developed.
Everything you read here is subject to change."* — **es la propia Chia Network diciendo, en su doc
oficial, que esto no está desplegado y puede cambiar.** No hace falta inferirlo del código; lo dice
la página.

---

## 3 · Qué garantiza la documentación oficial sobre PoST — y dónde contradice a los informes previos

### 3.1 · No hay finalidad garantizada, nunca — coincide con lo ya sabido

`docs.chia.net/chia-blockchain/consensus/analysis/` (consultado 2026-09-05, sin fecha propia en la
página):

> *"There is no guaranteed finality, but the more confirmations a transaction has, the safer it
> is."*

**CLASE:** propiedad de diseño / regla de consenso (el fork-choice de cadena más pesada no da
finalidad determinista, igual que Nakamoto-PoW; esto no es una debilidad exclusiva de PoST).
**PARA ZEROX:** coincide con el modelo Nakamoto que ZEROX ya adoptó (`DECISIONES.md` §2, "consenso
Nakamoto — cadena de mayor trabajo acumulado"). No hay contradicción.
**CONFIANZA:** alta.

### 3.2 · Los umbrales de confirmación, con sus supuestos explícitos

**AFIRMACIÓN:** la doc recomienda 6 bloques (~2 min) de confirmación frente a reorgs naturales, y 32
bloques (~10 min, un sub-slot entero con `SLOT_BLOCKS_TARGET=32`) frente a ataques de "foliage
re-org" con soborno de ganadores, **bajo el supuesto explícito de que la parte colusoria pesa menos
del 42,7 % (ajustado por ventaja de VDF)**, y que el requisito real es sobre espacio **no colusorio**,
no sobre espacio honesto:

> *"a transaction needs a certain number of confirmations for a receiver to assume that it cannot
> be re-orged, under the < 42.7% (* vdf advantage) colluding assumption"*
>
> *"It's worth noting that the 54% requirement only pertains to non-colluding space, rather than
> honest farming space."*

**CLASE:** regla de consenso (los umbrales) + supuesto de seguridad declarado (regla de política de
wallet/exchange sobre cuántas confirmaciones esperar, no de protocolo).
**ARCHIVO:** `docs.chia.net/chia-blockchain/consensus/analysis/`, consultado 2026-09-05.
**PARA ZEROX:** aquí aparece una **tercera cifra de umbral**, distinta de las dos que
`proof-of-space-tiempo.md` ya había marcado como contradicción no resuelta entre documentos
oficiales de Chia (42-46 % en 2022, 40,5-43 % en 2024). Esta página (`consensus/analysis/`, sin fecha
propia, pero parte del sitio vigente 2026) da **54 % de espacio no colusorio** y **42,7 % ajustado
por VDF** como los números que gobiernan hoy los umbrales de confirmación recomendados. La misma
página de Attacks and Countermeasures (§3.3 más abajo) da además **40,5 %** para otro escenario. Son
como mínimo **tres cifras distintas en la documentación oficial vigente** (54 %, 42,7 %, 40,5 %),
cada una para un supuesto distinto (colusorio vs no colusorio, con vs sin ventaja de VDF, "deja de
tener sentido atacar" vs "umbral matemático de reversión"). **No son necesariamente incompatibles
entre sí** —miden preguntas distintas— pero la documentación no las junta en una sola tabla en
ningún punto que se haya encontrado, y eso es exactamente el patrón de "cifra dispersa sin fuente
única" que ya preocupaba a `proof-of-space-tiempo.md`. Se amplía esa laguna, no se cierra.
**CONFIANZA:** alta en las citas; baja en poder reconciliar las tres cifras en un único marco —
**LAGUNA**, ver cierre.

### 3.3 · Los supuestos que atacan directamente las cuatro idealizaciones del greenpaper (§1.6)

El encargo pide vigilar en particular la tercera idealización del greenpaper (ningún compromiso
tiempo-memoria en las pruebas de espacio). La documentación operativa de `docs.chia.net` confirma que
Chia Network **sabe** que esa idealización es falsa y construye contramedidas alrededor de esa
falsedad, no alrededor de suponerla cierta:

- **Sobre el timelord más rápido** — `docs.chia.net/chia-blockchain/consensus/timelords/`
  (consultado 2026-09-05): *"any user with a CPU can be a timelord, to provide fallbacks"*, y el nodo
  temporal *"broadcasts [proofs] to the network as they are reached"*; el consenso solo usa la cadena
  de mayor peso, así que el resultado práctico —confirmado por `proof-of-space-tiempo.md` §4 ya
  citando la propia doc: *"only the fastest timelord on the network will broadcast proofs at any
  given time"*— es que **el timelord más rápido decide**. No se encontró en `docs.chia.net` ninguna
  declaración que contradiga esto; al contrario, `attacks-and-countermeasures/` construye media
  página de análisis alrededor de "qué pasa si el atacante tiene el timelord más rápido" (§3.4).
  **Esto confirma, con fuente oficial, la segunda idealización falsa del §1.6 del greenpaper** (el
  adversario SÍ puede tener una VDF más rápida en la práctica, y de hecho la propia Chia Network
  operó timelords ASIC propios entre 2023 y su descontinuación — ya documentado en
  `proof-of-space-tiempo.md` §4, no repetido aquí).

- **Sobre el compromiso tiempo-memoria en el espacio** — ninguna de las páginas de `docs.chia.net`
  recorridas para este informe (`proof-of-space-1.0`, `proof-of-space-2.0/new-proof-introduction`,
  `attacks-and-countermeasures`, `analysis`) usa las palabras "grinding", "compressed plot" ni
  "time-memory trade-off" en el texto que se pudo extraer. **Esto es una laguna real de la
  documentación operativa**, no una confirmación ni una negación: el problema que motivó PoS 2.0
  (ya documentado con fuente primaria — el blog de abril de 2026 citado en
  `proof-of-space-tiempo.md` §5 y `chia-parcelas-comprimidas.md` §2) **no aparece mencionado en las
  páginas de consenso de la documentación de referencia** que se pudieron leer. Quien llegue a
  `docs.chia.net/chia-blockchain/consensus/` sin conocer el blog de abril de 2026 no se enteraría de
  que el filtro de parcela y el modelo de seguridad completo asumen algo que la propia empresa ya
  reconoció como falso. **Se marca en rojo, tal como pide el encargo**: es la misma trampa de "el
  documento describe un diseño idealizado sin decir que lo es", esta vez no en el greenpaper sino en
  la documentación de consenso operativa.

**CLASE:** hallazgo de auditoría documental, no una regla.
**CONFIANZA:** alta en lo que se leyó (ausencia verificada por búsqueda de términos); no se puede
descartar que otras páginas de `docs.chia.net` no recorridas en este informe sí lo mencionen —
LAGUNA declarada abajo.

### 3.4 · La ventaja del timelord rápido, cuantificada — coincide exactamente con lo ya sabido

`docs.chia.net/chia-blockchain/consensus/attacks-and-countermeasures/` (consultado 2026-09-05, cita
netspace de diciembre de 2021 como ejemplo pero sin versión propia declarada) da una tabla de
escenarios que **confirma cifra por cifra** la tabla que ya traía `proof-of-space-tiempo.md` §4 desde
el paper/greenpaper:

| Escenario del timelord del atacante | Espacio honesto/no-colusorio necesario |
|---|---|
| 0,5× (más lento) | 66,7 % |
| 1× (igual) | 50,0 % |
| 2× | 33,3 % |
| 2× con "double dip" infinito, ataque corto | 25,4 % |
| 2× con "double dip" infinito, >1 época | 27,1 % |

**CLASE:** regla de consenso / propiedad de seguridad derivada.
**PARA ZEROX:** no contradice nada de lo ya escrito; **refuerza con una segunda fuente independiente**
(la doc de consenso, no solo el greenpaper matemático) que el umbral de seguridad de Chia depende
multiplicativamente de la velocidad relativa del VDF, y que valores razonables de ventaja de VDF
(2-3×) bajan el requisito de espacio honesto muy por debajo de "mayoría" en el sentido de Bitcoin.
**CONFIANZA:** alta.

---

## 4 · chiapower.org — auditoría de la fuente secundaria

**Quién la publica.** Confirmado en el pie de página y en la navegación: autoría atribuida a la
cuenta de Twitter/X `@LebanonJon`, repositorio `github.com/jmhands/chiapower.github.io`, copyright
"© 2023 Chiapower". **No hay ninguna afiliación declarada con Chia Network Inc.** — de hecho el pie
de página incluye el aviso de marca registrada estándar ("Chia Network Inc., CHIA™... son marcas
registradas de Chia Network Inc."), que es la fórmula habitual de un sitio de fan/tercero que usa el
nombre y quiere dejarlo explícito. Confirma lo que el encargo ya advertía.

**Qué hay realmente en la página.** `chiapower.org/chia-proofs-of-space/PoST` es una única página
(la categoría "Chia Proofs of Space" del sitio no tiene ninguna otra entrada) centrada en el **lado
de almacenamiento/hardware** del farming, no en el protocolo de consenso: plotting, harvesting,
patrones de I/O de disco, y por qué la carga de trabajo de Chia (lectura aleatoria, sin datos de
usuario, baja tasa de transferencia) permite reutilizar hardware de disco que no serviría para otros
usos. Cita dos fuentes primarias reales: el documento de construcción de pruebas de espacio de Chia
(v1.1) y el paper *Beyond Hellman* (`eprint.iacr.org/2017/893.pdf`) — el mismo que ya está en
`PDF/time-memory-tre-off-proof-space.pdf` y cubierto en `research/time-memory-tradeoff.md`.

**Veredicto sobre la trampa del precursor 2019 — NO aplica aquí, y hay que decirlo con precisión.**
La página **no menciona el greenpaper en ningún momento** (ni el precursor de 2019 ni el vigente de
2026), no cita ningún porcentaje de seguridad (ni 61,5 %, ni 59,5 %, ni 42-54 %), no habla de
signage points, filtro de parcela, VDF, timelords ni intervalos de desafío. Es decir: **no describe
el mecanismo de consenso en absoluto**, ni el desplegado ni el precursor — describe una capa distinta
(ingeniería de almacenamiento) que es ortogonal a la pregunta de qué versión del diseño describe. No
hay nada que contrastar contra `docs.chia.net` en el terreno de consenso porque la página
simplemente no entra ahí.

**Qué explica que la oficial no explique — lo poco que hay, es real y útil.** Un matiz operativo que
no aparece en las páginas de `docs.chia.net/chia-blockchain/consensus/` recorridas para este informe:
la caracterización explícita de la carga de trabajo de farming como *"read-only, completely random
distribution, and a low amount of data transferred"*, con la consecuencia de que **los requisitos de
durabilidad y tasa de error del almacenamiento son mucho más laxos que para datos de usuario**, lo
que "puede constituir una nueva clase de medio de almacenamiento y promover hardware usado que de
otro modo no sería apto". Es una observación de ingeniería de producto, no de consenso.
**CLASE:** detalle de implementación / observación de producto, no regla de consenso — y sin cita
`archivo:línea` posible porque es prosa de un sitio de terceros, no código.
**PARA ZEROX:** si algún día se considera un esquema de espacio tipo Chia (hoy descartado por `§14`
en favor de Autonomys), esta caracterización de carga de trabajo es relevante para el
dimensionamiento de `zx-miner`/hardware de granjero: los discos para farming pueden ser más baratos
que discos de propósito general. Hoy, con PoAS/Autonomys ya decidido, es información de contexto, no
accionable.
**CONFIANZA:** alta en lo que dice la página (se leyó dos veces, con extracción de tabla de contenido
y reproducción verbatim); alta también en que **no** dice lo que el encargo temía que pudiera decir
(no reproduce la trampa del precursor 2019, simplemente porque no toca ese terreno).

---

## 5 · Arranque de la red — lo que Chia hizo de verdad en 2021

**AFIRMACIÓN:** mainnet se lanzó el 19 de marzo de 2021, con el desafío de génesis distribuido a las
7 AM PDT (14:00 UTC) mediante lo que Chia llamó su proceso "green flag".
**CLASE:** hecho histórico, no regla de consenso.
**ARCHIVO:** `chia.net/2021/03/17/chia-1-0-mainnet/` (blog oficial de la empresa, no `docs.chia.net`;
consultado vía búsqueda 2026-09-05) — *"The genesis challenge will be distributed using our green
flag process at 7AM PDT (14:00 UTC) on Friday March 19, 2021"*. Coincide con
`docs.chia.net/chia-blockchain/resources/faq/` (consultado 2026-09-05): *"Chia launched mainnet on
March 19, 2021."*
**CONFIANZA:** alta — dos fuentes oficiales independientes coinciden en la fecha exacta.

**AFIRMACIÓN:** hubo un **periodo restringido de seis semanas** tras el lanzamiento en el que las
transacciones estaban congeladas y los granjeros solo acumulaban recompensa sin poder gastarla; el
propio soft fork que habilitaba gastar (v1.1) era una actualización **obligatoria** antes de que
terminara la ventana.
**CLASE:** política de lanzamiento (no es una regla de consenso permanente, es una restricción
temporal decidida para el arranque).
**ARCHIVO:** `chia.net/2021/03/17/chia-1-0-mainnet/`, consultado 2026-09-05.
**CÓDIGO/CITA:** *"There is an initial six week period where transactions will be frozen and farmers
will only be receiving farming rewards."* ... *"We will soft fork in final transaction capabilities
during this period in a 1.1 release. That will be a required upgrade before the six week period
ends."*
**PARA ZEROX:** es el precedente real más directo que el encargo pedía para la decisión "aparcada" de
cómo lanzar ZEROX. Chia **no** lanzó con transacciones activas desde el bloque 0: lanzó con
coinbase-only durante 6 semanas mientras terminaba de escribir la capa de gasto, y forzó la
actualización antes de abrir transacciones. Es un dato a favor de que "arrancar con capacidades
reducidas y forzar upgrade" es un patrón real de proyecto serio, no una improvisación — aunque el
motivo de Chia (código de transacciones aún no terminado) es distinto de cualquier motivo que ZEROX
pudiera tener (p.ej. ventana frágil de PoAS, `§14`/`§15`/`§17` de `DECISIONES.md`).
**CONFIANZA:** alta.

**AFIRMACIÓN sobre la dificultad inicial — NO CONFIRMADA, se declara laguna explícitamente.** Una
búsqueda encontró referencias de terceros (agregadores, no `docs.chia.net` ni `chia.net`) a una
dificultad inicial fijada "para 100 PB" con reseteos en 24-48h. **No se pudo verificar esta cifra
contra `docs.chia.net`, `chia.net` ni el propio repositorio clonado** (el `DIFFICULTY_STARTING=7` que
hoy vive en `chia/consensus/default_constants.py:16` es la constante vigente en 2026, no
necesariamente la usada el día del lanzamiento en 2021, y el propio comentario del código no dice a
qué tamaño de red correspondía). **No se cita el número de 100 PB como hecho.** LAGUNA.
**CONFIANZA:** no aplica — se declara explícitamente no verificado.

**AFIRMACIÓN:** el desafío de génesis de Chia se derivó de una fuente de aleatoriedad externa: el
hash del bloque 675 317 de Bitcoin concatenado con una frase de Bram Cohen.
**CLASE:** detalle de implementación del génesis (no es una regla de consenso reutilizable — es un
valor hardcodeado, análogo a lo que `DECISIONES.md §7` fija para el génesis de ZEROX: "coinbase cero
+ mensaje simbólico").
**ARCHIVO:** `docs.chia.net/chia-blockchain/consensus/chains/challenges/`, consultado 2026-09-05.
**CÓDIGO/CITA:** *"Chia's mainnet genesis challenge derives from hashing a preimage containing
Bitcoin block 675317's hash and a message from Bram Cohen"*, con el hash resultante
`ccd5bb71183532bff220ba46c268991a3ff07eb358e8255a65c30a2dce0e5fbb` — que coincide, verificado
directamente en el clon local, con `AGG_SIG_DATA` en
`chia/consensus/default_constants.py:11` (`bytes32.fromhex("ccd5bb71183532bff220ba46c268991a3ff07eb...")`,
truncado en el fetch web a 33 caracteres hex por un error de la página o del extractor — el valor
completo está en el código y es de 32 bytes).
**PARA ZEROX:** anclar el génesis a un bloque de otra cadena pública es una técnica real usada por un
proyecto serio para probar que no hubo pre-minado oculto (nadie puede fabricar retroactivamente un
bloque de Bitcoin de una altura concreta). ZEROX no tiene una decisión equivalente en
`DECISIONES.md §7` más allá de "timestamp = fecha de lanzamiento" — es una idea barata a considerar,
sin que sea una regla de consenso que haya que copiar literal.
**CONFIANZA:** alta.

---

## 6 · Contraste con `research/chia-parcelas-comprimidas.md` — confirma, no contradice, y añade

No se encontró ninguna afirmación en `docs.chia.net` que **contradiga** al informe previo sobre
parcelas comprimidas o el estado de PoS 2.0. Lo que se encontró **confirma y añade precisión**:

- **Confirmado, con la propia doc oficial ahora citada explícitamente (antes solo se tenía el
  código):** PoS 2.0 no está desplegado. `docs.chia.net/chia-blockchain/consensus/proof-of-space-2.0/
  new-proof-introduction/` (consultado 2026-09-05, "Updated: March 3, 2026") dice literalmente que
  es *"not expected to be finalized until 2027"* y que el contenido *"is subject to change"*. Antes
  esto se inferí­a solo de `HARD_FORK2_HEIGHT = 0xFFFFFFFA`; ahora hay declaración textual oficial
  de que ni siquiera el diseño está cerrado.
- **Añadido, no estaba en el informe previo:** el filtro de parcela V1 tiene un calendario de
  ablandamiento ya escrito en código con tres alturas y fechas en comentario (§2.2 arriba) — detalle
  que no se había leído porque el informe previo se centró en `default_constants.py` para las
  constantes de tamaño de parcela y compresión, no para el filtro.
- **Ninguna mención en `docs.chia.net`** al ~50 % de reducción vía *grinding* tipo DrPlotter ni a las
  parcelas comprimidas oficiales C0-C9 en las páginas de consenso recorridas (§3.3 arriba) — la
  laguna que `chia-parcelas-comprimidas.md` ya declaraba ("no se pudo determinar qué fracción del
  netspace actual usa parcelas comprimidas") **sigue abierta**; `docs.chia.net` no la cierra.

---

## Cierre

**YA EN RUST:** nada nuevo que añadir a lo que ya recoge `proof-of-space-tiempo.md` §6 y
`chia-parcelas-comprimidas.md` §5 (`chia_rs` cubre `compute_plot_id_v2`, `create_v2_plot`,
`validate_proof_v2`, `Prover`; el filtro de parcela V1/V2 leído aquí vive en `chia/types/
blockchain_format/proof_of_space.py`, que es Python puro en el repo, no delega en `chia_rs` para la
lógica de filtro — solo `Verifier().validate_proof(...)` delega en la FFI de `chiapos`/`chia_rs` para
la verificación criptográfica de la prueba en sí). No cambia la recomendación ya cerrada de `§14`:
ZEROX no adopta el formato de parcela de Chia de todos modos.

**LASTRE:** el calendario de ablandamiento del filtro V1 (§2.2), con fechas concretas (2027, 2030,
2033) escritas para una red que ya pesa exabytes — no tiene sentido para una red que empieza en cero
y no debe copiarse sin rederivar desde cero el motivo (que ni siquiera se pudo confirmar aquí, ver
LAGUNAS). El calendario de PoS2 expresado como offset relativo a `HARD_FORK2_HEIGHT` (§2.3) es
lastre de manual: fechas relativas a un ancla que hoy es `0xFFFFFFFA`.

**CHOCA CON:** nada de lo encontrado aquí choca con decisiones ya cerradas de ZEROX. Refuerza, con
una segunda fuente independiente de la doc de consenso (no solo el greenpaper), la base de `§14`
(el timelord más rápido decide, la tercera idealización del greenpaper es falsa en producción) y da
un número concreto y con dos fuentes cruzadas (código + doc) para alimentar P-034(a): el intervalo de
desafío de Chia (~9,4 s) es 64× más corto que su sub-slot (600 s) y ~2× más corto que su intervalo de
bloque medio (18,75 s) — la relación exacta que P-034(a) necesita fijar para ZEROX una vez se derive
`ρ` (tiempo de replot en bloques) con la implementación real de Autonomys, no con la de Chia.

**LAGUNAS:**
- Dificultad inicial real del lanzamiento de mainnet (marzo 2021): la cifra de "100 PB" circula en
  fuentes de terceros pero no se pudo confirmar contra `docs.chia.net`, `chia.net` ni el repositorio.
- Por qué el filtro de parcela V1 se ablanda con la altura (§2.2): el mecanismo está confirmado en
  código, el motivo no se encontró declarado en ninguna página recorrida.
- Reconciliar las tres cifras de umbral de seguridad que da hoy la documentación oficial vigente
  (54 % no-colusorio, 42,7 % ajustado por VDF, 40,5 % en Attacks-and-Countermeasures) en un marco
  único — cada una parece medir una pregunta distinta, pero ninguna página las junta.
- Si alguna página de `docs.chia.net` fuera de las recorridas (`Coin Set Model`, `Keys`, `Protocol`,
  `Resources`, `Architecture`, `Forks`) sí menciona explícitamente el grinding/parcelas comprimidas
  en términos operativos — no se recorrió el árbol completo de esas secciones, solo `Consensus` y las
  páginas de introducción/recursos más relevantes al encargo. El árbol de `Consensus` sí se recorrió
  completo (10 de 10 páginas listadas en su índice).
- Derivación matemática exacta de "un 5090 mimetiza 20 TB" (techo teórico de compresión de PoS2, ya
  declarada como laguna en `chia-parcelas-comprimidas.md`): sigue sin verificarse, no se encontró
  nueva fuente en este recorrido.
