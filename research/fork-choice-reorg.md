# Selección de cadena, reorgs y profundidad de confirmación — investigación para ZEROX

**Fecha:** 2026-09-04
**Motivo:** El SPEC validaba bloques aislados pero no tenía **ni una regla** que dijera cuál de dos
cadenas válidas gana. `DECISIONES.md` §2 fijaba "Nakamoto, mayor trabajo acumulado" en prosa y eso
nunca bajó a regla numerada.
**Anclas:** `bitcoin/bitcoin@master`, `ZcashFoundation/zebra@main`, `zcash/zcash@master`,
`monero-project/monero@master`.

---

## 1 · No es "la cadena más larga". Es trabajo acumulado

`bitcoin/bitcoin:src/chain.h` — y nótese que es un campo **solo en memoria**, derivado:

```cpp
//! (memory only) Total amount of work (expected number of hashes)
//! in the chain up to and including this block
arith_uint256 nChainWork{};
```

El trabajo de un bloque, `src/chain.cpp:120-133`:

```cpp
arith_uint256 GetBitsProof(uint32_t bits) {
    arith_uint256 bnTarget;
    bnTarget.SetCompact(bits, &fNegative, &fOverflow);
    if (fNegative || fOverflow || bnTarget == 0) return 0;
    // We need to compute 2**256 / (bnTarget+1) ...
    return (~bnTarget / (bnTarget + 1)) + 1;
}
```

Zebra (`zebra-state/.../chain.rs`) mantiene `partial_cumulative_work`, sumado y restado al conectar
y desconectar. Monero compara `cumulative_difficulty` — cosmética distinta, misma idea; su propio
log lo canta: *"REORGANIZE on height... with cum_difficulty ..."* (`blockchain.cpp:2139`).

**Matiz de Bitcoin que importa:** `FindMostWorkChain()` (`validation.cpp:3126-3179`) no se queda con
el máximo y ya. Camina hacia atrás desde el candidato comprobando que ningún ancestro esté
`BLOCK_FAILED_VALID`; si lo está, lo purga del conjunto de candidatos y repite. **El trabajo
acumulado es condición necesaria, no suficiente**: la validez de toda la ruta es una precondición
separada.

---

## 2 · El desempate — donde las implementaciones se separan

### Bitcoin: orden de llegada. No determinista.

`CBlockIndexWorkComparator` ordena por `nChainWork` y, en empate, por `nSequenceId`, un contador
asignado **en el orden de llegada local** (`pindex->nSequenceId = nBlockSequenceId++`,
`validation.cpp:3817`), con la dirección de puntero como último recurso.

Dos nodos que reciben los mismos dos bloques en distinto orden pueden mantener tips distintos.

### Zebra: menor hash de tip. Determinista, y se aparta de la spec a propósito.

`zebra-state/src/service/non_finalized_state/chain.rs:2334-2347`:

```rust
/// Chains with higher cumulative Proof of Work are Ordering::Greater,
/// breaking ties using the tip block hash.
///
/// Despite the consensus rules, Zebra uses the tip block hash as a
/// tie-breaker. Zebra blocks are downloaded in parallel, so download
/// timestamps may not be unique... This departure from the consensus
/// rules may delay network convergence, for as long as the greater hash
/// belongs to the later mined block. But Zebra nodes should converge as
/// soon as the tied work is broken.
```

El propio comentario cita la spec de Zcash para dejar constancia de que la incumple:
*"To break ties between leaf blocks, a node will prefer the block that it received first."*

**Laguna declarada:** el agente no pudo descargar el archivo exacto donde se declara
`CBlockIndexWorkComparator`; su caracterización viene de doxygen y búsqueda, no de lectura línea a
línea.

---

## 3 · Undo data y mecánica de reorg

### Bitcoin — `src/undo.h`, completo

```cpp
struct TxInUndoFormatter {
    void Ser(Stream &s, const Coin& txout) {
        uint32_t nCode = (uint32_t{txout.nHeight} << 1) | uint32_t{txout.fCoinBase};
        ::Serialize(s, VARINT(nCode));
        ::Serialize(s, Using<TxOutCompression>(txout.out));
    }
};
class CTxUndo   { public: std::vector<Coin> vprevout; };    // por tx no-coinbase
class CBlockUndo{ public: std::vector<CTxUndo> vtxundo; };  // "for all but the coinbase"
```

Por cada entrada gastada se guarda el `Coin` **completo** — importe, lock, altura de creación, flag
coinbase — suficiente para reconstruirlo sin releer el bloque de origen.

`DisconnectBlock` (`validation.cpp:2178-2247`) aplica en **orden estrictamente inverso**:

```cpp
// undo transactions in reverse order
for (int i = block.vtx.size() - 1; i >= 0; i--) {
    for (unsigned int j = tx.vin.size(); j > 0;) {
        --j;
        ApplyTxInUndo(std::move(txundo.vprevout[j]), view, out);
    }
}
```

### Monero — reorg transaccional en dos fases

`blockchain.cpp:1132-1250`:

```cpp
while (m_db->top_block_hash() != alt_chain.front().bl.prev_id) {
    block b = pop_block_from_blockchain(true);
    disconnected_chain.push_front(b);
}
auto split_height = m_db->height();
for (auto& bei : alt_chain) {
    if (!handle_block_to_main_chain(bei.bl, bvc) || !bvc.m_added_to_main_chain) {
        rollback_blockchain_switching(disconnected_chain, split_height);  // revertir TODO
        return false;
    }
}
```

Y las transacciones de bloques desconectados **vuelven al mempool** (`blockchain.cpp:612-636`).

---

## 4 · ⚠️ El bug de caché que este encargo buscaba — confirmado

`§6.5` de nuestro SPEC copia el diseño de medianas de Monero. Su mecanismo de invalidación **no es
un "invalidar" explícito, es una verificación de clave en cada lectura, y la clave es el HASH**:

`blockchain.cpp:1436-1493`, verificado línea a línea:

```cpp
uint64_t tip_height = start_height + count - 1;
crypto::hash tip_hash = m_db->get_block_hash_from_height(tip_height);
if (count == (size_t)m_long_term_block_weights_cache_rolling_median.size()) {
    cached = tip_hash == m_long_term_block_weights_cache_tip_hash;   // ← HASH, no altura
}
if (cached) return m_long_term_block_weights_cache_rolling_median.median();
// ... si no coincide: recompute completo
```

Y el caché de dificultad se resetea con un flag explícito **en los tres puntos de entrada de
reorg** (`pop_block_from_blockchain`, `rollback_blockchain_switching`,
`switch_to_alternative_blockchain`):

```cpp
m_timestamps_and_difficulties_height = 0;
m_reset_timestamps_and_difficulties_height = true;
```

**La lección, exacta:** si un caché de ventana se indexa por **altura** en vez de por **hash de
tip**, un reorg que reemplaza bloques a las mismas alturas produce lecturas contaminadas de la rama
vieja **sin que nada falle visiblemente**. Split silencioso.

---

## 5 · Profundidad máxima de reorg — las tres posturas

| | Límite | Qué pasa al excederlo |
|---|---|---|
| **Bitcoin Core** | Ninguno | Nakamoto puro |
| **Monero** | Ninguno en consenso (verificado por ausencia en `cryptonote_config.h`). Solo checkpoints fuera de consenso | Se acepta si tiene más trabajo. **Ocurrió de verdad**: reorg de 18 bloques el 14-15 sep 2025, 118 tx invalidadas |
| **zcashd** | **`MAX_REORG_LENGTH = COINBASE_MATURITY − 1 = 99`** (`src/main.h:64`) | **El nodo se apaga.** No rechaza y sigue: para y espera a un humano |

Mensaje literal de zcashd (`src/main.cpp:4727-4746`):

> *"A block chain reorganization has been detected that would roll back %d blocks! This is larger
> than the maximum of %d blocks, and so the node is shutting down for your safety... Please help,
> human!"*

Zebra usa el mismo 100 como **frontera de finalidad** entre estado no finalizado (en memoria,
varias cadenas candidatas) y finalizado (en disco, una sola):

> *"In Zcash, chain state is final once it is beyond the reorg limit, unlike Bitcoin which only has
> only probabilistic finality."*

**Dato que pesa para ZEROX:** el reorg real de 18 bloques de Monero demuestra que en cadenas
pequeñas los reorgs profundos **ocurren**. ZEROX nacerá siendo mucho más pequeña que Monero.

---

## 6 · Profundidad de confirmación segura

Nakamoto §11 dio la estructura; **Grunspan & Pérez-Marco (arXiv:1702.02867) encontraron un error
real en su fórmula** (usa `Q_z` donde debe ir `Q_{z+1}`, lo que **subestima el riesgo**) y dan la
forma cerrada exacta con la beta incompleta regularizada: `P(z) = I_{4pq}(z, 1/2)`.

### Confirmaciones para `P(doble gasto) < 0,1 %` — Grunspan & Pérez-Marco, Tabla 4

| `q` atacante | `z` correcto | `z` de Nakamoto (optimista) | Tiempo a T=120 s |
|---|---|---|---|
| 10 % | 6 | 5 | 12 min |
| 15 % | 9 | 8 | 18 min |
| 20 % | 13 | 11 | 26 min |
| 25 % | 20 | 15 | 40 min |
| 30 % | 32 | 24 | 1 h 04 |
| 35 % | 58 | 41 | 1 h 56 |
| 40 % | 133 | 81 | 4 h 26 ⚠ |
| 45 % | 539 | 340 | ~18 h ⚠⚠ |

### Riesgo con pocas confirmaciones — Rosenfeld, arXiv:1402.2009, Tabla 1

| `q` | n=1 | n=2 | n=3 | n=4 | n=6 |
|---|---|---|---|---|---|
| 0,10 | 20 % | 5,6 % | 1,71 % | 0,546 % | 0,059 % |
| 0,20 | 40 % | 20,8 % | 11,58 % | 6,67 % | 2,33 % |
| 0,30 | 60 % | 43,2 % | 32,6 % | 25,2 % | 15,6 % |
| 0,40 | 80 % | 70,4 % | 63,5 % | 57,96 % | 49,3 % |
| 0,45 | 90 % | 83,5 % | 77,7 % | 74,1 % | 68,3 % |

A T=120 s, `z` confirmaciones cuestan **5× menos tiempo real** que las mismas `z` en Bitcoin.

---

## 7 · P-006 y un hallazgo nuevo sobre LWMA

### 7.1 · El `(N−1)/N` de zawy probablemente no aplica

`zawy12/difficulty-algorithms#58` propone `Hashes = sum(difficulty) * (N-1)/N`, porque la
distribución exponencial de solvetimes sesga al alza la **estimación** de hashrate. Wuille, citado
en #82: *"hashrate = sum(work in window) / (window duration)... is correct even when hashrate and
difficulty are changing."*

**Derivación de D2, no cerrada:** el sesgo afecta al **cociente** trabajo/tiempo, no al
**acumulador** de fork choice. Cada `2^256/(target+1)` ya es la esperanza incondicional de hashes
para *ese* bloque (falta de memoria de la geométrica), independiente de `N`. Sumar términos ya
insesgados no introduce el sesgo.

**No se cierra P-006 con esto**: los resúmenes de #58/#82 se obtuvieron vía WebFetch, no lectura
verbatim del hilo completo. Requiere relectura + confirmación de D9.

### 7.2 · ⚠️ Hallazgo nuevo: el atacante tiene su propio LWMA

Derivación de D2 combinando reglas ya fijadas, **no cubierta por ningún issue de zawy encontrado**:

`C-DIFF-01` establece que el retarget se evalúa sobre la **cadena candidata**. Por tanto **la rama
privada de un atacante tiene su propio LWMA**, calculado sobre sus propios timestamps. Con `N=90`
(~3 h a 120 s), un atacante minoritario que mina en solitario más despacio que la red verá que,
tras completar su propia ventana, **su dificultad se ajusta a la baja** para reflejar su ritmo real.

En Bitcoin esto no pasa dentro de una carrera de doble gasto porque el retarget es cada 2016
bloques.

Las tablas de §6 **asumen dificultad constante e idéntica en ambas ramas**. Ese supuesto se
sostiene para `z ≲ N = 90` (hasta `q ≈ 30 %`), pero los casos `q=40 %` (`z=133`) y `q=45 %`
(`z=539`) **cruzan una y hasta seis ventanas completas de LWMA**. Si el razonamiento es correcto,
**esas filas subestiman el riesgo real para ZEROX**. El suelo `T_FLOOR` (C-DIFF-05) acota la bajada
a ×10 por ventana, lo que limita el efecto sin eliminarlo.

**Encargo formulado para D9:** simular la carrera con `q=0,40` y `q=0,45` con LWMA-1 evaluado de
forma independiente en cada rama, y comparar el `z` resultante contra los 133 y 539 de la tabla. Si
diverge, es una divergencia real ZEROX-vs-Bitcoin-clásico que hay que registrar.

---

## 8 · Lagunas

- No se leyó verbatim el hilo completo de `zawy12#58`/`#82` — solo resúmenes.
- No se leyó línea a línea el `struct CBlockIndexWorkComparator` de Bitcoin.
- Faltan los `z` para umbrales `P<1 %` y `P<10 %` con `q` alto: la tabla de Rosenfeld llega a `n=6`.
  **No se rellenaron a ojo.**
- No se revisó el mecanismo de Zebra para las cachés de note-commitment trees en reorg → D4, Fase 6.
- No se encontró PR/issue de Zcash discutiendo cambiar `MAX_REORG_LENGTH` desde 2016.
