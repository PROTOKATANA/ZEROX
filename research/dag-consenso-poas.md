# Consenso por DAG sobre Proof of Space and Time — qué se sabe y qué no

**Fecha:** 2026-09-06 · Abre **P-038** · Cinco agentes por fuente (papers, Chia, Autonomys,
uso real, historia). Pregunta de Katana: «¿Qué implicaciones tiene aplicar un DAG Consensus en una
PoST space-time? ¿Es viable y posible añadirlo?»

## 1 · Lo que dicen los papers de DAG sobre su propio supuesto

Leídos íntegros: Inclusive (FC 2015, `fc15.ifca.ai/preproceedings/paper_101.pdf`), SPECTRE
(ePrint 2016/1159, v. 2018-01-15), PHANTOM/GHOSTDAG (ePrint 2018/104, v. 2021-11-10), Conflux
(arXiv:1805.03870, v. 2018-09-05).

Los cuatro modelan la creación de bloques como **un único proceso de Poisson sin memoria** cuya
tasa total se reparte entre honestos y atacante en proporción al recurso:

- SPECTRE §2, p. 3: *"PoW creation is modeled as a memoryless process."*
- GHOSTDAG §3.2, p. 6: αv es *"the probability that node v will be the creator of the next block
  in the system"*. El Lema 9 (p. 11), base del Teorema 4, hace crecer el conjunto azul honesto a
  `(1−α)(1−δ)rλ`. El parámetro `k` se calibra con la cola de Poisson (§4.2, ecs. 1-2).
- Conflux §3.2-3.3, p. 7-8: `λa = q·λh`.

**Ninguno de los cuatro contiene las palabras "double dipping", "costless simulation" ni "nothing
at stake"** (grep sobre el texto extraído). Conflux es el único que menciona PoS: *"can also work
with any other mechanism that can maintain a stable block generation rate"* (p. 4, p. 13), sin
demostrar que la no-reutilización del recurso entre ramas, que sus lemas necesitan, se conserve.

**Consecuencia:** no existe prueba de seguridad de ningún protocolo DAG bajo un recurso que
permite producir candidatos en varias ramas sin coste. Bajo PoSpace ese fenómeno existe y está
cuantificado: el greenpaper vigente de Chia (12-jun-2026, §2.2, p. 18-19) mide el *boost* del
atacante en `e ≈ 2,718` sin contramedida y `1,47` con ella. Un DAG donde cada bloque contribuye al
orden y al peso multiplica lo que el atacante gana con cada rama extra. Es investigación original,
no adopción.

## 2 · Lo que Chia hace, y lo que planteó y no hizo

`chia_rs` 0.48.0 (la estructura de bloque ya no vive en Python): `Foliage.prev_block_hash` es un
único campo (`chia-protocol/src/foliage.rs:45`); `blockchain.py:350-351` exige `height = padre+1`.
**No hay uncles, no hay inclusión de la prueba perdedora** (ausencia verificada en
`block_header_validation.py` y `reward_chain_block.rs`).

Los "16 bloques por desafío" no son un DAG: es el campo `deficit`
(`RewardChainSubSlot.deficit`, `slots.rs:37`; `chia/consensus/deficit.py:7-52`) que hace que el
desafío del slot dependa de un bloque de cada ≥16 — *correlated randomness*, la contramedida al
double dipping. Fork choice (`blockchain.py:504-535`): mayor peso, empate → menor `total_iters`.

El greenpaper §1.5, p. 11-12, sí plantea que en empate los granjeros trabajen sobre ambas ramas
(*"note that in a PoW based chain this is not possible"*) y lo deja como *"ongoing research"* y
*"social convention"*. No está implementado. Cero issues/PRs sobre GHOSTDAG o uncles en
`Chia-Network/chia-blockchain`.

## 3 · Lo que asume linealidad en Autonomys (`subspace @ f8842d0`)

| Componente | Asume linealidad | Cita |
|---|---|---|
| Archivador | **Sí.** Indexa por `client.block_hash(número)` = hash canónico; error duro si el padre archivado no coincide con la rama | `sc-consensus-subspace/src/archiver.rs:1209-1213, 1225-1229` |
| Slot creciente | Sí, por rama | `block_import.rs:368-369` |
| PoT por cabecera | **Sí.** Un solo `proof_of_time` en `PreDigest`; la semilla se deriva del único padre | `digests.rs:20-29, 60-66`; `sp-consensus-subspace/src/lib.rs:106-108` |
| Timekeeper | Sí: una sola cadena de PoT activa, reescrita en reorg | `sc-proof-of-time/src/lib.rs:27-30` |
| Era de reajuste | Sí: `block_number % EraDuration` | `pallet-subspace/src/lib.rs:761-762` |
| Fork choice | Sí en la práctica (ver `fork-choice-poas.md`); issue #3703 (sep-oct 2025) propone desempate por `solution_distance` y descarta el hash por el mismo motivo que ZEROX | `subspace-verification/src/lib.rs:195-206` |

**El dato más útil:** Autonomys ya tiene "soluciones extra por slot" y decidió que **no sean
bloques**. Son `Vote` (*"Equivalent to block number, but this is not a block"*,
`sp-consensus-subspace/src/lib.rs:178-186`), `EXPECTED_VOTES_PER_BLOCK = 9`
(`subspace-runtime/src/lib.rs:180`), solo recompensa (`pallet-subspace/src/lib.rs:595, 1116`).
Issue #2078 (oct-2023) prohibió que un voto tenga calidad de bloque porque *"they will likely
result in vote being included on both branches in case chain forks"*: empujaron el diseño **lejos**
de la ambigüedad de un DAG. No hay uncles (PR #414: *"we never had them in the protocol"*). La
equivocación se detecta y no se castiga (`verifier.rs:402`, `TODO`; PR #3072 retiró el slashing).

## 4 · Precedentes vivos de espacio + varios bloques por ronda

| Proyecto | Estructura | Estado 2026-09 | Lo que enseña |
|---|---|---|---|
| **Filecoin** | Tipsets: varios bloques por época con el mismo padre; peso ∝ poder × nº de tickets; desempate por menor ticket (`spec.filecoin.io/algorithms/expected_consensus/`) | Vivo | Umbral real de seguridad **≈ 20 %** de almacenamiento adversarial con `m = 5` bloques/ronda, no 50 % — *n-split attack*, demostrado ajustado (arXiv:2308.06955, AFT 2023, coautoría Protocol Labs). Degradación real de calidad de cadena desde la época ~2 750 000 (mar-2023). Tuvieron que añadir una capa BFT aparte, F3 (FIP-0086), activada el 29-abr-2025, dos años después de proponerla |
| **Spacemesh** | Mesh por capas, orden capa → id de bloque → índice; Hare (BFT rápido) + Tortoise (voto acumulado) | **Muerto de facto**: quiebra may-2025, red caída, token deslistado (postmortems de L. Rettig, 18-may y 22-sep-2025). Un pool llegó a >90 % del poder | El único PoST + malla que existió no sobrevivió; sus fallos fueron de incentivos e identidad, no de la malla en sí |
| **Kaspa** | GHOSTDAG, PoW, `k = 124` a 10 bloques/s (KIP-0014, may-2025) | Vivo | PoW puro; ninguna señal de adoptar espacio. Split de red a las dos semanas de mainnet (nov-2021), resuelto con checkpoint y génesis nuevo |

El survey arXiv:2411.10026 (SoK DAG, 2025) no cita ningún otro proyecto de espacio + DAG. Ningún
análisis publicado, ni en ethresear.ch, combina formalmente DAG con un recurso que permite double
dipping (laguna declarada por los dos agentes que lo buscaron).

## 5 · Historia: qué falló en los DAG por ser DAG

Avalanche: liveness/DoS explotando la dependencia de votos entre ancestros (arXiv:2210.03423,
2022; reconocido, la versión desplegada difiere del whitepaper). Conflux: *liveness attack* contra
la cadena pivote, mitigado con GHAST, el DAG pasa de 300-500K a >1M bloques bajo ataque. Nano:
spam desincroniza la red más de una semana (mar-2021). IOTA: coordinador central durante diez años
por el *parasite chain attack*; en may-2025 lo eliminó **abandonando el Tangle** por DPoS/MoveVM.
SPECTRE: sin orden total (ciclos de Condorcet), descartado por sus autores a favor de GHOSTDAG.

## 6 · Qué rompe en el SPEC de ZEROX

Con un DAG, "el bloque a la altura h" deja de existir, y estas reglas dependen de él:

- **C-HDR-02** (`height = padre + 1`), **C-HDR-05** (`slot > slot(padre)`): un solo padre.
- **C-EXP-02 / C-EXP-04**: la caducidad de sectores se deriva de `hash_bloque[altura_ploteo]`
  leído de la rama en validación. Con varios bloques por altura no hay un hash.
- **C-FORK-01..04, C-REORG-07, C-CHK-04**: peso acumulado, profundidad de reorg y "rama canónica"
  están definidos sobre una cadena. Bajo DAG hay que redefinir peso (¿cuentan los bloques
  paralelos?, Filecoin sí y por eso cae al 20 %), reorg (¿reordenación sin cambio de tips?) y ancla.
- **LWMA-1 sobre slots** (§7.3, DECISIONES §19, §23): cuenta un bloque por altura. Con inclusión de
  paralelos hay que reajustar sobre "bloques incluidos por slot", sin precedente en Autonomys.
- **PoT (C-HDR-07, §6.1 `pot_output`)**: una semilla por padre. Con varios padres, ¿de cuál?
  Es la pieza que Baig-Pietrzak (FC 2025) hace obligatoria; rediseñarla es tocar lo no negociable.
- **Archivado / cota (ii) de `MAX_REORG_LENGTH`** (`fork-choice-poas.md`): hay que linealizar el
  DAG antes de archivar, y una reordenación que no cambia tips reescribe historia ploteada.
- **UTXO y orden de tx**: hace falta regla de conflicto entre bloques paralelos (Conflux: se
  descarta la segunda). Coinbase por bloque paralelo cambia la curva de emisión (C-EMIT).
- **Cliente ligero (§26)**: verifica cabeceras; un DAG multiplica las cabeceras por ronda.

## 7 · Lo que un DAG compra, contra lo que ZEROX ha fijado

Un DAG compra rendimiento y menos huérfanos a tasas de bloque altas (GHOSTDAG Teorema 4: la
seguridad no depende de `D·λ ≪ 1`). ZEROX fijó `T = 120 s`, `Δ = 4 s` (C-SLOT-03), tasa de
huérfanos por colisión de slot < 2,5 % (C-SLOT-02), tamaño de bloque dinámico y la prioridad
«descentralización por encima de velocidad y escalabilidad» (P-036). El problema que el DAG
resuelve no es uno que ZEROX tenga con esos parámetros.

## Lagunas

- No hay prueba, ni a favor ni en contra, de seguridad de DAG + PoSpace: es terreno sin literatura.
- Causa técnica exacta del split de Kaspa de nov-2021, no verificada en fuente primaria.
- No se revisaron GitHub Discussions de Autonomys ni el foro completo, solo issues/PRs y el hilo de
  equivocación.
- El umbral del 20 % de Filecoin se leyó del abstract y discusión del paper AFT 2023, no de la
  demostración línea a línea.
