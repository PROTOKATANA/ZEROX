# Tamaño de bloque dinámico estilo Monero — investigación para ZEROX

**Fecha:** 2026-09-04
**Motivo:** P-009. Katana eligió "dinámico estilo Monero" sobre un límite fijo. Antes de
poder escribir reglas en `SPEC.md` hay que saber qué es exactamente ese algoritmo, por qué
tiene la forma que tiene, y qué sigue roto en él.
**Método:** tres agentes en paralelo, divididos por fuente (spec/código, historia, código real).
Repos clonados y anclados a commit:
- `monero-project/monero @ 3d3920d7487b5df7ac388b6b8577fd04d505885f`
- `Cuprate/cuprate @ 4383f0d6ab36cfa067eb5d5d457d498c58474d06`

---

## 0 · Resumen ejecutivo — lo que cambia para ZEROX

1. **Existe una implementación de referencia en Rust.** `Cuprate` porta el algoritmo completo.
   No hay que traducir C++ a ciegas: hay dos implementaciones independientes que comparar.
2. **El sistema tiene DOS ventanas anidadas, no una.** Corta (100 bloques) para responder a
   demanda real; larga (100 000 bloques) que acota el crecimiento estructural. La ventana larga
   es el fix de 2019; sin ella, el sistema es vulnerable al *big bang attack*.
3. **Hallazgo crítico para nuestra cola de emisión:** en Monero el suelo de tail se aplica
   **antes** de la penalización cuadrática, no después. Un minero que exceda la mediana cobra
   **menos que la cola nominal**. Nuestra cola de 0,5 ZZK **no sería un suelo garantizado** si
   portamos la función tal cual. Ver §6 — requiere decisión explícita.
4. **Los parámetros no son sagrados.** Monero ya los revisó una vez (2,0× → 1,7× en 2022, tras
   tres años de datos). Deben ser ajustables por hard fork, no constantes de "día 1 para siempre".
5. **Advertencia metodológica del propio equipo de Monero:** ArticMine señaló en la reunión de
   MRL de 2019-02-04 que estaban comparando algoritmos *sin haber definido antes los parámetros
   de diseño*. Nosotros deberíamos fijar primero los objetivos cuantitativos (crecimiento anual
   máximo tolerable, coste mínimo para el atacante, tamaño de cadena aceptable) y luego elegir.

---

## 1 · El algoritmo, hoy (post hard fork v15)

Fuente: `src/cryptonote_core/blockchain.cpp:4438-4492` (`update_next_cumulative_weight_limit`).

```
Mlt  = max(ZONA_LIBRE, mediana(long_term_weight de los últimos 100 000 bloques))
Mst  = mediana(block_weight de los últimos 100 bloques)

M    = min( max(Mlt, Mst), 50 * Mlt )      # mediana efectiva
M    = max(M, ZONA_LIBRE)                  # suelo

LÍMITE_DURO = 2 * M                        # bloque con weight > 2M es INVÁLIDO
```

Cita literal del código (`blockchain.cpp:4468-4470`):

> *"effective median = short_term_median bounded to range [long_term_median, 50\*long_term_median],
> but it can't be smaller than the minimum penalty free zone"*

### Qué entra en la ventana larga

No el peso crudo del bloque, sino un valor ya amortiguado por bloque
(`get_next_long_term_block_weight`, `blockchain.cpp:4407-4436`):

```
# HF >= 15 (actual):
w' = max(block_weight, Mlt * 10/17)
long_term_weight = min(w', Mlt * 17/10)     # => clamp a [0.588·Mlt, 1.7·Mlt]

# HF 10-14 (versión original de 2019):
long_term_weight = min(block_weight, Mlt * 7/5)   # => [0, 1.4·Mlt]
```

Comentario del código, que enlaza el paper de origen:

> *"returns min(Mb, 1.7\*Ml) as per https://github.com/ArticMine/Monero-Documents/blob/master/MoneroScaling2021-02.pdf"*

Nótese que la versión moderna añadió un **suelo** (`10/17`) que la original no tenía: la mediana
de largo plazo ya no puede desplomarse arbitrariamente rápido, solo hasta 0,588× por bloque.

### Cálculo de la mediana

`epee::misc_utils::median` (`contrib/epee/include/misc_language.h:53-70`). Con número par de
elementos usa un promedio entero **a prueba de overflow**:

```cpp
T get_mid(const T &a, const T &b) {
  return (a/2) + (b/2) + ((a - 2*(a/2)) + (b - 2*(b/2)))/2;
}
```

Hay un test que lo demuestra insertando `3<<62` dos veces
(`tests/unit_tests/rolling_median.cpp:TEST(rolling_median, overflow)`).

En producción la mediana de la ventana larga es **rodante e incremental** (doble heap min/max,
`contrib/epee/include/rolling_median.h`), no un `sort()` de 100 000 elementos por bloque.

---

## 2 · La fórmula de penalización

`src/cryptonote_basic/cryptonote_basic_impl.cpp:81-126`. Con `M` = mediana efectiva,
`x` = weight del bloque:

```
recompensa(x) = base_reward                       si  x <= M
recompensa(x) = base_reward · x·(2M − x) / M²     si  M < x <= 2M
BLOQUE INVÁLIDO                                   si  x > 2M
```

Es la parábola que vale `base_reward` en `x = M` (empalme continuo) y `0` en `x = 2M`.

**Aritmética obligatoria de 128 bits.** El código lleva un comentario de bugfix explícito:

> *"BUGFIX: 32-bit saturation bug (e.g. ARM7), the result was being treated as 32-bit by default."*
> — `cryptonote_basic_impl.cpp:111-112`

Monero lo resuelve con `mul128` manual (dwords de 32 bits, `contrib/epee/include/int-util.h:63-87`)
y `div128_64` vía `boost::multiprecision`. **En Rust esto es un no-problema**: `u128` nativo. Cuprate:

```rust
let multiplicand: u128 = ((2 * median_bw - block_weight) * block_weight).try_into().unwrap();
(((u128::from(base_reward) * multiplicand) / effective_median_bw) / effective_median_bw)
```

> ⚠️ **Trampa de portabilidad detectada en Cuprate.** `2 * median_bw - block_weight` es
> aritmética `usize`. Si se llamara a `calculate_block_reward` sin haber ejecutado antes
> `check_block_weight`, esa resta hace **underflow**. Monero no tiene el problema porque su
> `get_block_reward` devuelve `false` antes de llegar a la resta. Cuprate depende de un orden
> de invocación estricto (`consensus/rules/src/blocks.rs:267,273`).
> **Para ZEROX: el chequeo `x <= 2M` debe ser una precondición del tipo, no una convención de
> orden de llamada.** Esto es exactamente la clase de bug que nuestro `clippy deny unwrap_used`
> no atrapa.

---

## 3 · Zona libre de penalización

`get_min_block_weight(version)`, `cryptonote_basic_impl.cpp:67-74`.

| Constante | Valor | Vigente desde | Altura mainnet |
|---|---|---|---|
| `..._FULL_REWARD_ZONE_V1` | 20 000 | génesis | 0 |
| `..._FULL_REWARD_ZONE_V2` | 60 000 | HF2 | 1 009 827 (~mar 2016) |
| `..._FULL_REWARD_ZONE_V5` | **300 000** | HF5 | 1 288 616 (~abr 2017) |

Comentario del código: *"size of block (bytes) after which reward for block calculated using block size"*.

**LAGUNA:** no hay justificación textual en el repo del porqué de cada salto (20k→60k→300k).
Habría que buscarlo en el foro/MRL de la época. No inventamos una razón.

---

## 4 · Constantes completas

`src/cryptonote_config.h`

| Constante | Valor | Línea |
|---|---|---|
| `CRYPTONOTE_REWARD_BLOCKS_WINDOW` | 100 | :57 |
| `CRYPTONOTE_LONG_TERM_BLOCK_WEIGHT_WINDOW_SIZE` | 100 000 | :61 |
| `CRYPTONOTE_SHORT_TERM_BLOCK_WEIGHT_SURGE_FACTOR` | 50 | :62 |
| `CRYPTONOTE_BLOCK_GRANTED_FULL_REWARD_ZONE_V5` | 300 000 | :60 |
| `CRYPTONOTE_MAX_TX_SIZE` | 1 000 000 | :41 |
| `CRYPTONOTE_MAX_TX_PER_BLOCK` | 0x10000000 | :42 |
| `FINAL_SUBSIDY_PER_MINUTE` | 3·10¹¹ (→ 0,6 XMR/bloque) | :54 |

> **Corrección de escala para ZEROX.** 100 000 bloques × 120 s = 12 000 000 s = **138,9 días**
> (~4,6 meses), no "un año". Como el bloque de ZEROX es también de 120 s, las ventanas de Monero
> se trasladan 1:1 en tiempo de calendario: 100 bloques = 200 min, 100 000 bloques = 138,9 días.
> Si queremos una memoria larga de un año, harían falta ~262 800 bloques.

---

## 5 · Weight ≠ size

- **size** = bytes del blob serializado.
- **weight** = `Σ get_transaction_weight(tx)` sobre coinbase + txs. **La cabecera de bloque y la
  lista de hashes de tx NO cuentan** (`blockchain.cpp:4050-4051`, y Monero Book
  `consensus_rules/blocks/weights.html`).

Para tx con bulletproofs, `weight = blob_size + bp_clawback`
(`cryptonote_format_utils.cpp:79-97,573-587`):

```cpp
uint64_t bp_base = (32 * ((plus?6:9) + 14)) / 2;
uint64_t bp_clawback = (bp_base * n_padded_outputs - bp_size) * 4 / 5;
```

**Qué es el clawback y por qué existe:** una bulletproof agregada crece *logarítmicamente* con el
número de outputs. Sin corrección, meter 16 outputs en una prueba sale muchísimo más barato en
bytes que 8 pruebas de 2, y eso distorsiona tanto el límite de bloque como el mercado de fees.
El clawback recupera el 80 % de ese ahorro como "weight ficticio". Máximo 16 outputs por prueba
(`BULLETPROOF_MAX_OUTPUTS`, `cryptonote_config.h:205`).

El **weight** gobierna: medianas, penalización, fee por byte.
El **size** gobierna: `CRYPTONOTE_MAX_TX_SIZE` y la contabilidad de ancho de banda p2p.

> **Pregunta abierta para ZEROX (→ D1):** ¿necesita Orchard/Halo2 un clawback análogo? El bundle
> Orchard lleva **una sola prueba para todas las acciones**, y su tamaño no escala linealmente con
> el número de acciones. La distorsión económica que motivó el clawback de Monero podría existir
> igual, o podría no aplicar. **No lo sabemos y no hay que asumirlo.**

---

## 6 · ⚠️ Interacción con la cola de emisión — HALLAZGO CRÍTICO

Orden exacto dentro de `get_block_reward` (`cryptonote_basic_impl.cpp:81-126`):

1. `base_reward = (MONEY_SUPPLY − already_generated_coins) >> emission_speed_factor`
2. **Suelo de cola aplicado AQUÍ:** `if (base_reward < FINAL_SUBSIDY...) base_reward = FINAL_SUBSIDY...`
3. **Solo después**, la penalización cuadrática multiplica ese `base_reward` ya suelado.

Y el contador de emisión se incrementa con el valor **ya penalizado**
(`blockchain.cpp:4277-4278`):

```cpp
already_generated_coins = base_reward < (MONEY_SUPPLY - already_generated_coins)
                          ? already_generated_coins + base_reward : MONEY_SUPPLY;
```

**Consecuencia, verificada en código y no interpretada:** la cola **no es un suelo absoluto por
bloque**. Un minero cuyo bloque exceda la mediana efectiva cobra *menos* que la cola nominal,
tendiendo a 0 conforme `x → 2M`. Y la moneda no emitida simplemente no se emite.

**Para ZEROX (cola de 32 ZZK/bloque, fijada 2026-09-04):** si portamos la función bit a bit, un minero que llene su
bloque por encima de la mediana cobrará **menos de 0,5 ZZK**. Esto es una decisión de diseño
económico que hay que tomar a conciencia, no heredar por accidente. → **P-009f**.

Refuerzo histórico de esta preocupación: `monero-project/monero#1878` (2017-03-17, bigreddmachine)
ya advertía que *"the block reward penalty, as currently devised, becomes less effective the larger
the median block size gets and the smaller the block reward gets"* — es decir, con un subsidio en
decadencia, la penalización pierde fuerza disuasoria. En una cadena en cola permanente, el subsidio
está en su mínimo **para siempre**.

---

## 7 · Por qué existe: el *big bang attack*

**El diseño original** (CryptoNote): mediana simple de 100 bloques, sin techo de largo plazo.
Memoria del protocolo: unas horas.

**El ataque** — `noncesense-research-lab/Blockchain_big_bang` (Isthmus, sept 2018, act. ene 2019).
Condición: `net fee > coinbase` y `net size ≈ 2·mediana(100)`. Entonces el tamaño de bloque
**se duplica cada 51 bloques**, unas 14 veces al día, indefinidamente.

| Tiempo | Tamaño de bloque | Cadena | Coste para el atacante |
|---|---|---|---|
| 24 h | 9 830 400 kB | 689,2 GB | ~2376 XMR (~€118 800 entonces) |
| 36 h | 1 258 291 200 kB | ~88 TB | — |

> *"sustained high transaction volume (due to rapid adoption or a well-funded spammer) induces a
> rapid exponential increase in resource requirements"*

Lo grave no es que sea posible: es la **asimetría económica**. Decenas de TB de daño
infraestructural por unos miles de dólares, y el atacante recupera parte vía fees.

**LAGUNA:** no se encontró el hilo original donde Isthmus presentó esto a la comunidad, ni una
respuesta pública fechada de un mantenedor.

---

## 8 · Cómo se decidió el fix (reunión MRL 2019-02-04)

Se evaluaron **tres** propuestas, no una:

> sarang: *"1) The double median 2) The double median with smooths change 3) My last proposal that
> moneromooo implemented in PR 5124"*

Objeción explícita de suraeNoether:

> *"PR 5124 concerns me for a couple of reasons. firstly, demonstrating the long-term stability of
> it… is difficult"* — *"if all proposals have the same total consequence for the blockchain and the
> same approximate cost for the attacker, there is zero reason to use something complicated"*

Cota de eficacia, del propio sarang:

> *"Given an unbounded adversary, all proposals allow chain bloat of O(10-100 GB) over, say, a
> weeklong sustained max-bloat attack"*, con coste `O($1-10M)`.

**Ninguna propuesta elimina el ataque. Todas lo encarecen y lo ralentizan.**

Y la autocrítica de ArticMine:

> *"This all comes back to suraeNoether point what are our design parameters? We have not formally
> defined them"*

**LAGUNA:** no se encontró justificación documentada de por qué se eligió la opción más compleja
sobre las dos más simples, pese a la objeción de suraeNoether.

Durante la revisión del PR, iamsmooth tuvo que pedir explícitamente documentación:
> *"Can we get a comment describing the intended algorithm or a link to such a document."*

---

## 9 · Cronología de los dos hard forks

| Evento | PR | Autor | Merge | HF | Altura | Fecha |
|---|---|---|---|---|---|---|
| Se introduce la mediana de largo plazo (crecimiento 1,4×/2,0× anual) | #5124 | moneromooo (propuesta ArticMine) | 2019-03-04 (fluffypony) | v10 "Boron Butterfly" | 1 788 000 | 2019-03-09 |
| Ajuste "MoneroScaling2021": 1,7×, clamp con suelo 10/17, penalización reescrita | #7819 | moneromooo | 2022-04-18 (luigi1111) | v15 "Fluorine Fermi" | 2 688 888 | 2022-06-30 |

Motivo del segundo: SamsungGalaxyPlayer cuestionó que el parámetro previo permitía *"32x annual
block growth"*; ArticMine defendió 1,7× ≈ **14,2× de expansión anual**, citando datos empíricos de
Bitcoin/Litecoin/Dogecoin (crecimientos de 8×–80× en 6 meses) y el precedente de Dogecoin como
adopción dañada por subidas súbitas de fee.

La migración se implementa **in-línea** con ramas `if (hf_version < HF_VERSION_...)` en el mismo
archivo. No hay binario ni repo separado.

---

## 10 · Lo que sigue roto (críticas vigentes)

### 10.1 · El "acantilado de fee" — `monero-project/research-lab#70` (2020-02-16, UkoeHB)

Si la mediana de largo plazo sube mucho y luego el volumen se desploma, la fee mínima puede
dispararse de golpe:

> *"Transactions built before the short term median falls will be using the older fees, which will
> now be inadequate."*

La mediana larga acota el crecimiento, pero **introduce un nuevo modo de fallo en el sentido
contrario**. Para ZEROX: la transición de fees debería ser gradual en **ambas** direcciones.

### 10.2 · Flooding real de marzo 2024

De 15–25k tx/día a 115–140k tx/día (4–27 marzo 2024), analizado por Rucknium (MRL) como probable
*black marble flooding attack*. **El sistema de tamaño de bloque hizo su trabajo**: no hubo
explosión de cadena. Pero el ataque expuso que para una moneda de privacidad el eje de daño no es
solo el tamaño: es que un atacante puede pagar fees indefinidamente para **degradar el anonimato
de los demás**, y este mecanismo no está diseñado para eso.

Mitigaciones discutidas y **no aplicadas** a fecha de esta investigación: una tercera mediana
"ultra-long-term sanity", PoW por transacción a nivel p2p (sin hard fork), y — la recomendación de
Rucknium — que **subir el ring size es más coste-efectivo que subir fees** contra ese ataque.

> Relevancia directa para ZEROX: nuestro pool blindado es Orchard, no ring signatures. El vector
> "black marble" no traslada igual (Orchard no tiene conjunto de anonimato por ring). Pero el
> principio sí: el límite de bloque no protege la privacidad, solo el disco. → nota para D8.

---

## 11 · Adopción por otras cadenas

Único caso concreto encontrado: **Wownero** (fork de Monero) adoptó una versión ajustada en
v0.11.0.0 "Kunty Karen", 2023-04-01 — **cuatro años después** del HF v10 de Monero. Esperó a que
el diseño madurara en producción.

**No se encontró ningún caso documentado de una cadena que lo adoptara y luego lo abandonara.**
Esto se registra como laguna, no como ausencia confirmada.

---

## 12 · Vectores de prueba disponibles (oro para D6)

| Archivo | Qué aporta |
|---|---|
| `tests/unit_tests/block_reward.cpp` | 11 casos. Vector confirmado `17592186044415` ("from neozaru, confirmed by fluffypony"). Fracciones exactas de penalización: `63/64`, `3/4`, `15/64` |
| `tests/unit_tests/long_term_block_weight.cpp` | 10 casos, incl. `ceiling_at_30000000`, `long_growth_spike_and_drop`, `pop_invariant_random`, `cache_matches_true_value` |
| `tests/unit_tests/rolling_median.cpp` | Incl. test de overflow explícito con `3<<62`; `series` con 10 000 valores contra fuerza bruta |
| `tests/unit_tests/mul_div.cpp` | Vectores hex exactos de `mul128`/`div128_64` |
| `tests/block_weight/{block_weight.cpp,block_weight.py,compare.py}` | **Test cruzado C++ ↔ Python byte-idéntico**, registrado como CTest. El script Python es una *tercera* implementación independiente mantenida en el propio repo como oráculo (atribuida a Sarang Noether) |
| `tests/core_tests/block_reward.cpp` | Integración end-to-end generando cadena real |

**Cuprate NO reproduce estos vectores.** Solo tiene un `proptest` de propiedad (`tail_emission`,
`consensus/rules/src/miner_tx.rs:216-228`). **No existe suite cruzada Monero↔Cuprate que garantice
consenso byte a byte.** Eso es un riesgo asumido por Cuprate que nosotros no deberíamos heredar:
si adoptamos este algoritmo, portamos también los vectores fijos.

---

## 13 · Mapa de código de referencia

| Pieza | Monero (C++) @3d3920d7 | Cuprate (Rust) @4383f0d6 |
|---|---|---|
| Mediana efectiva + límite | `src/cryptonote_core/blockchain.cpp:4438-4492` | `consensus/context/src/weight.rs:311-360` |
| Peso de largo plazo | `blockchain.cpp:4407-4436` | `consensus/context/src/weight.rs` |
| Penalización de recompensa | `src/cryptonote_basic/cryptonote_basic_impl.cpp:81-126` | `consensus/rules/src/miner_tx.rs:44-74` |
| Chequeo de límite | (dentro de `get_block_reward`) | `consensus/rules/src/blocks.rs:158-167` |
| Promedio sin overflow | `contrib/epee/include/misc_language.h:45-49` | `helper/src/num.rs:71-79` (portado línea a línea, con URL de origen citada) |
| Mediana rodante | `contrib/epee/include/rolling_median.h` (doble heap, O(log n)) | `VecDeque` + `Vec` ordenado con `binary_search` (O(n)) |
| Constantes | `src/cryptonote_config.h:52-62,184,190,196` | — |
| Alturas de hard fork | `src/hardforks/hardforks.cpp:62-76` | `monero-book.cuprate.org/consensus_rules/hardforks.html` |

---

## 14 · Lagunas de esta investigación

- No se compiló ni ejecutó `ctest` ni `cargo test`: todo es lectura estática de código y tests.
- No se leyó el diff completo de PR#5124 ni #7819 línea a línea (solo resúmenes vía WebFetch).
- No se leyó íntegro el research bulletin de Rucknium sobre marzo 2024.
- No se verificó si `CRYPTONOTE_MAX_TX_SIZE` se re-chequea al aceptar un bloque ya ensamblado, o
  si es solo política de admisión a mempool/relay. **Vector asignable a D8.**
- No se verificó independientemente (p. ej. por simulación) las cifras de Isthmus de 2018.
- No se inspeccionaron variantes de constantes en forks de Monero (Wownero et al.).
- No se encontró justificación del salto histórico de la zona libre 20k→60k→300k.

---

## 15 · Decisiones de consenso que esto abre → PREGUNTAS-PARA-KATANA.md P-009

Ninguna constante de Monero se adopta por defecto. Sub-decisiones abiertas: **P-009a..g**.
