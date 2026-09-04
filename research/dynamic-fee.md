# Tarifa mínima dinámica — investigación para ZEROX (P-011)

**Fecha:** 2026-09-04
**Motivo:** El SPEC fijaba `C-TX-15` como **regla de consenso**: *"El fee MUST ser ≥
MIN_RELAY_FEE_RATE × weight(tx)"*. La investigación demuestra que eso es **incorrecto**.
**Anclas:** `monero-project/monero@3d3920d7`, `Cuprate/cuprate@4383f0d6`.

---

## 0 · El hallazgo que corrige el SPEC

```
AFIRMACIÓN: En Monero la tarifa mínima NO es regla de consenso. Es política de mempool/relay,
            y se omite por completo cuando la transacción llega dentro de un bloque ya minado.
FUENTE:     src/cryptonote_core/tx_pool.cpp:137-166
CITA:       const bool kept_by_block = (tx_relay == relay_method::block);
            fee_good = kept_by_block || m_blockchain.check_fee(tx_weight, fee);
CONFIANZA:  alta
```

Cuprate lo clasifica igual, y de forma explícita en la estructura del repo: la función vive en
`binaries/cuprated/src/txpool/relay_rules.rs`, **fuera** del crate `consensus/`. Su doc-comment:

> *"Relay rules are rules that govern the txs we accept to our tx-pool and propagate around the
> network"*

Y UkoeHB, en `monero-project/research-lab#70`, lo dice con todas las letras:

> *"it is network consensus, not protocol consensus, to enforce the minimum fee"*

**Por qué importa.** Si la tarifa mínima fuera consenso:
- Un bloque con una transacción de fee bajo sería **inválido** → un minero no podría incluir
  transacciones gratuitas ni siquiera propias.
- Cambiar la política de tarifas exigiría un **hard fork**.
- Y aparece una circularidad: la tarifa depende de la mediana, que depende de los bloques.

El antispam a nivel de consenso ya lo tenemos por otra vía —la penalización cuadrática
(C-EMIT-06), el límite duro (C-WGT-09) y el tope por transacción (C-WGT-11)—, que es exactamente
el argumento de UkoeHB:

> *"It also ingrains this anti-spam mechanism directly into the penalty calculation, rather than
> the fee algorithm which is technically optional for nodes."*

---

## 1 · La fórmula, del código

`src/cryptonote_core/blockchain.cpp:3537-3556`

```cpp
uint64_t Blockchain::get_dynamic_base_fee(uint64_t block_reward, size_t median_block_weight)
{
  constexpr uint64_t min_block_weight = CRYPTONOTE_BLOCK_GRANTED_FULL_REWARD_ZONE_V5;
  if (median_block_weight < min_block_weight)
    median_block_weight = min_block_weight;
  lo = mul128(block_reward, DYNAMIC_FEE_REFERENCE_TRANSACTION_WEIGHT, &hi);
  div128_64(hi, lo, median_block_weight, &hi, &lo, NULL, NULL);
  div128_64(hi, lo, median_block_weight, &hi, &lo, NULL, NULL);
  assert(hi == 0);
  lo -= lo / 20;                       // el "0,95×", en entero
  return lo == 0 ? 1 : lo;
}
```

Es decir:

```
tarifa_por_byte = 0,95 · recompensa_base · REF_WEIGHT / M²
```

con `REF_WEIGHT = DYNAMIC_FEE_REFERENCE_TRANSACTION_WEIGHT = 3000` (`cryptonote_config.h:74`).

Detalles que **MUST** respetarse al portar:
- **Dos divisiones enteras sucesivas** por `M`, no una división por `M²`.
- El 0,95 es `lo − lo/20`, división entera. No es multiplicación en coma flotante.
- Aritmética de 128 bits obligatoria: `recompensa_base` (~10¹³) × 3000 desborda `u64`.
- Suelo en la zona libre antes de usar la mediana.
- El resultado nunca es 0: `return lo == 0 ? 1 : lo`.

Cuprate lo reproduce con `u128` nativo (`binaries/cuprated/src/txpool/relay_rules.rs:50-93`),
aunque **omite el `assert(hi == 0)`** de sanidad post-división que sí tiene Monero.

### Buffer de aceptación del 2 %

`blockchain.cpp:3559-3591` — la mempool acepta cualquier fee dentro del 2 % por debajo del mínimo:

```cpp
needed_fee = tx_weight * fee_per_byte;
needed_fee = (needed_fee + mask - 1) / mask * mask;   // cuantización hacia arriba
if (fee < needed_fee - needed_fee / 50) return false; // buffer del 2 %
```

---

## 2 · ⚠️ Dónde nace el *fee cliff*

En esa misma función, el argumento que se pasa como mediana es:

```cpp
get_dynamic_base_fee(base_reward, std::min<uint64_t>(median, m_long_term_effective_median_block_weight))
```

**`min(mediana_corta, mediana_larga)`.** Y como `tarifa ∝ 1/M²`, tomar el **mínimo** de las dos
significa tomar la que produce la **tarifa más alta**.

Consecuencia, en palabras de UkoeHB (`research-lab#70`, 2020-02-16):

> *"Transactions built before the short term median falls will be using the older fees, which will
> now be inadequate, and those tx will get stranded, even if they are using the 'normal' fee
> priority which is 5x the minimum fee."*

Tras un pico de demanda, cuando la mediana corta se desploma, `min()` la sigue hacia abajo, la
tarifa mínima **salta hacia arriba de golpe**, y las transacciones ya firmadas se quedan varadas.

### Estado real de la mitigación

```
AFIRMACIÓN: El issue del fee cliff sigue ABIERTO. La mitigación implementada actúa solo sobre la
            suavidad estructural de la mediana larga, no como colchón para transacciones ya firmadas.
FUENTE:     gh api repos/monero-project/research-lab/issues/70 → "state":"open"
CONFIANZA:  alta
```

Lo que la comunidad discutió como solución (comentario de ArticMine marcado como resolutorio) fue
**2× de crecimiento y 0,5× de decaimiento**. Lo que se mergeó en PR#7819 fue **1,7× / 1÷1,7**.
Y hay una divergencia documental dentro del propio repo: el comentario de cabecera en
`blockchain.h:675` sigue documentando el 2×/0,5× propuesto, mientras el código de
`blockchain.cpp:4405-4436` ejecuta 1,7×. **Portar desde el comentario en vez del código
reproduciría constantes que nunca se activaron.**

```
AFIRMACIÓN: No se encontró en Monero ni en Cuprate ningún mecanismo de suavizado BIDIRECCIONAL de
            la tarifa mínima que evite el varado de transacciones ya firmadas.
CONFIANZA:  media (negativo declarado; no se inspeccionaron Wownero, Beam ni Grin)
```

---

## 3 · Niveles de prioridad

**Antes de HF15:** multiplicadores puros de wallet, tabulados por época
(`src/wallet/wallet2.cpp:8466-8479`):

```cpp
{ fee_priority::Elevated, {1, 2, 3} },
{ fee_priority::Elevated, {1, 20, 166} },
{ fee_priority::Priority, {1, 4, 20, 166} },
{ fee_priority::Priority, {1, 5, 25, 1000} },
```

**Desde HF15:** cambio estructural. Ya no es un multiplicador sino **cuatro fórmulas distintas**
calculadas por el nodo y expuestas por RPC (`blockchain.cpp:3594-3628`):

```cpp
const uint64_t Mfw = std::min(Mnw, Mlw);
const uint64_t Fl = base_reward * REF / (Mfw * Mfw);
const uint64_t Fn = 4 * base_reward * REF / (Mfw * Mfw);
const uint64_t Fm = 16 * base_reward * REF / (ZONA_LIBRE * Mfw);
const uint64_t Fh = std::max(4*Fm, 4*Fm*Mfw / (32*REF*Mnw / ZONA_LIBRE));
```

Bajo y normal escalan con el **inverso del cuadrado** de la mediana; medio y alto con el **inverso
simple**. Sigue siendo política de wallet/RPC, no de bloque.

---

## 4 · Cuantización de la tarifa

`blockchain.h:650-660` + `cryptonote_config.h:64,198`

```cpp
static uint64_t get_fee_quantization_mask()
{ return tools::PowerOf<10, CRYPTONOTE_DISPLAY_DECIMAL_POINT - PER_KB_FEE_QUANTIZATION_DECIMALS>::Value; }
```

Con 12 decimales y 8 de cuantización → máscara = **10⁴ unidades atómicas**. La tarifa se redondea
**hacia arriba** al múltiplo: `fee = (fee + mask − 1) / mask * mask`.

**Motivación:** reducir la granularidad de la tarifa como huella identificatoria — una tarifa con
todos sus dígitos permite estimar el momento de construcción de la transacción. Documentado por
UkoeHB en el issue de investigación; el comentario del código productivo solo dice *"mask out the
last decimal places"*. **Confianza media en la motivación, alta en la mecánica.**

---

## 5 · Historia

| Cambio | HF | Constante |
|---|---|---|
| Tarifa dinámica | v4 | `HF_VERSION_DYNAMIC_FEE = 4` |
| De por-kB a por-byte | v8 | `HF_VERSION_PER_BYTE_FEE = 8` |
| "2021 scaling" — todo anclado a la mediana larga, 4 fórmulas de prioridad | v15 | `HF_VERSION_2021_SCALING = 15` |

PR#7819 *"Fee changes from ArticMine"*, mergeado 2022-04-18, `2b999f5398426d2c4452e001cfebad34abb686ff`.

---

## 6 · Vectores de prueba

`tests/unit_tests/scaling_2021.cpp`:

| Test | Qué cubre |
|---|---|
| `relay_fee_cases_from_pdf` (36-45) | 6 pares exactos de `get_dynamic_base_fee`. P. ej. `get_dynamic_base_fee(1200000000000, 300000) == 38000` |
| `wallet_fee_cases_from_pdf` (47-90) | 5 escenarios `(base_reward, Mnw, Mlw)` con sus 4 salidas `Fl,Fn,Fm,Fh` |
| `rounding` (92-144) | ~25 casos límite de `round_money_up`, incl. overflow esperado |

Cuprate **no** reproduce estos vectores. No hay verificación cruzada ejecutable entre las dos
implementaciones.

---

## 7 · Lagunas

- No se inspeccionaron Wownero, Beam ni Grin para el suavizado bidireccional.
- No hay test unitario de `check_fee()` en sí, ni de `get_fee_quantization_mask()` aislado.
- La afirmación de que el 1,7× "resuelve" el cliff es de diseño (ArticMine), no verificada por
  simulación.
- No se recorrió el historial de cada hard fork para descartar que la tarifa mínima pasara a
  consenso en alguna versión; en HEAD sigue siendo política de relay.
