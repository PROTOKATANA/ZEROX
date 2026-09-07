# Estructura no lineal NATIVA de PoAS — investigación y propuesta

**Fecha:** 2026-09-07 · Responde a la segunda pregunta de **P-038** («¿un DAG adaptado a PoST en vez
de PoST adaptado al DAG? ¿qué se modifica, el DAG o el PoST?») · Refuerza **P-039** · Cinco agentes
en Opus por fuente: literatura (specs), Chia, Autonomys, implementaciones desacopladas, D2.
`subspace @ f8842d0`, `chia-blockchain 2.7.4-rc2+16`, `chia_rs 0.48.0`, `prism-rust @ cdd913aa`,
`OHIE @ e8c45556`, ePrint 2018/1119, 2017/573, 2018/378, 2017/300, arXiv 1810.08092, 2010.08154,
2411.10026.

## 0 · La respuesta

**Se modifica el DAG, no el PoST.** Las cinco fuentes convergen sin haberse leído: ninguna deriva
la entropía de un orden total reciente. O la entropía es el propio sorteo del recurso costoso
(Prism, OHIE, Parallel Chains sobre PoW; inaplicable bajo PoST, donde no queda aleatoriedad
posterior al sorteo), o hay un beacon de época con periodo silencioso sobre **una cadena** (Praos,
Parallel Chains sobre PoS, Leios), o hay un acuerdo bizantino explícito fuera de la estructura
(Spacemesh, red caída), o **un solo bloque por slot inyecta entropía dentro de una cadena de VDF y
la parte no lineal se define para no tocar el desafío** (Chia, la única en producción sobre espacio).

D2 lo formula como teorema de estructura: R1 (flujo único de PoT) + R2 (inyector estable a 15
slots) + R3 (rezago acotado) obligan a que exista una **espina lineal** que sea la única fuente de
entropía, reajuste, caducidad de sectores (C-EXP-04) y archivado. El paralelismo solo puede vivir
en capas que sean función de la espina. Prism llama a lo suyo «a structured DAG»; Chia marca qué
bloques llevan transacciones; Autonomys convierte el billete sobrante en voto sin payload anclado
a `height−1`.

Corolario honesto para Katana: **las ventajas de rendimiento de un DAG verdadero (confirmación
rápida, throughput por bloques paralelos con peso) no son alcanzables bajo PoAS sin un Proof-of-Time
distinto.** Lo alcanzable es un DAG estructurado de profundidad 1: latencia a **inclusión** y
reparto de recompensa. La latencia a **confirmación** no la mueve ninguna estructura; la mueven
§13, C-REORG-07, o una capa de finalidad aparte (precedente: Filecoin F3, dos años de despliegue).

## 1 · Lo que dicen las fuentes (verificado en código o paper)

| Fuente | Qué es lineal | Qué es paralelo | De dónde sale la entropía | Usa que el bloque costó |
|---|---|---|---|---|
| Chia (greenpaper 2026-06-12, código) | **Todo**: cadena estricta; foliage = subcadena | Nada estructural; desacople temporal (36 % de bloques llevan tx) | Solo el bloque con `deficit = 15`; si el slot tiene <16 bloques el desafío **no se actualiza** (`block_header_validation.py:247-256`) | **No**: `is_transaction_block` sale de `total_iters` (tiempo del VDF), no del hash |
| Autonomys (f8842d0) | Cadena; votos anclados a `height−1` sin payload | Votos (9/bloque esperados), peso cero | `blake3(chunk ‖ pot_output)` del bloque `50j`, **no el hash del bloque** (`subspace-verification/src/lib.rs:444-446`) | No: la clase bloque/voto la fija `solution_distance` |
| Prism (prism-rust cdd913aa) | Árbol proposer + m árboles voter | Transaction blocks (capacidad), voters (seguridad) | Hash del PoW → tipo de bloque (`config.rs:118-136`) | **Sí, críticamente** |
| OHIE (e8c45556) | Ninguna: k cadenas simétricas | Las k | Hash del PoW → `chain_id` | Sí; el prototipo **no tiene PoW ni UTXO** |
| Parallel Chains PoS (2018/1119 §5) | Ninguna: orden por `(slot, cadena, posición)` | m cadenas | `η_j = H(η_{j−1} ‖ j ‖ VRFs de las m cadenas hasta 2R/3)` + stake de j−2 | No (stake); sin implementación |
| Praos (2017/573) | La cadena | — | VRF de los primeros 16k/f de 24k/f slots; 8k/f de silencio | No (stake); Cardano |
| Spacemesh | Contador de capas | Malla | Beacon por BA de 3 fases, una época de rezago | No (PoST); red muerta |

**Divergencias paper/código que conviene tener escritas:** Chia dice «cota inferior de 16 bloques
por slot» y el código implementa «no se actualiza el desafío»; `MAX_SUB_SLOT_BLOCKS` es 128 en
código y 64 en el paper; el greenpaper dice que «el timelord decide» qué bloque es de transacciones
y el código lo hace condición de validez calculable por cualquiera (`:723-744`). prism-rust tiene
los tests del ledger y del líder **comentados**; OHIE lee el rango del mensaje del emisor sin
recomputarlo. Los únicos vectores ejecutables reales son los de Chia.

## 2 · Hallazgos sobre la inyección de Autonomys que ZEROX no tenía (→ P-039)

Fuente: foro (Chen_Feng 1615, Barak 1639, dariolina 1615 #7), PR #1986 (2023-09-21), issues
#2141/#2193, `pallet-subspace/src/lib.rs:938-981`.

1. **La inyección cumple dos funciones distintas, documentadas**: *c-correlación* contra
   nothing-at-stake (BDK+19, arXiv 1910.02218: el mismo φ_c de D9) y *VDF débil* contra ataques
   de largo alcance. Acotar al timelord rápido es consecuencia («speed gains are not cumulative»),
   no objetivo; #2141 y #2193 se cerraron como riesgo aceptado.
2. **`c = 50` se eligió por φ_c** («tolerate up to 3 % more adversarial storage» que c=20). Es
   una magnitud **en bloques**, y así debe quedar.
3. **`lookback_in_blocks = 100 = K`, la profundidad de archivado.** Es el invariante que
   mantuvieron al pasar de 20/5 a 50/2. ZEROX debe fijar `interval × depth == K`, no «2 intervalos».
4. **`DELAY = 15` no tiene derivación escrita** en ningún sitio; solo `const_assert!`
   (`> BLOCK_AUTHORING_DELAY + 1` y `< INTERVAL`). Lo relevante es la ratio delay/intervalo **en
   tiempo** (15 s / 300 s en Autonomys).
5. **A `T = 120 s`, `target_slot = slot(50j) + 15` cae ANTES del bloque siguiente.** Una reorg
   de profundidad 1 sobre el bloque inyector bifurca el flujo de PoT. En Autonomys el inyector
   lleva ~3 confirmaciones cuando la inyección surte efecto. Esto **agrava** P-039: no es solo un
   rezago de 3,3 h, es que el momento de inyección queda sin ninguna confirmación.
6. **La entropía es `blake3(chunk ‖ pot_output)`, no el hash del bloque** (decisión explícita de
   Barak 1639 para que no se pueda moler con el contenido). Dos bloques con la misma solución y
   cuerpos distintos dan la misma entropía. Grado de libertad real para cualquier diseño.
7. **La validez del PoT depende solo de `past(B)`**: cada bloque transporta los checkpoints desde
   el slot futuro de su padre hasta el suyo (`block_import.rs:460-477`). El flujo viaja con la
   cadena; la best chain solo la usa el timekeeper local. Matiza el §0 de la auditoría: dos ramas
   con flujos distintos son ambas válidas relativas a sí mismas, sin cota, y solo el peso decide.
8. **Objeción interna sin cerrar** (dariolina, 2023-08-22): la cota φ_c del Lema 13 se aplica a la
   frecuencia de **inyección** y el diseño solo garantiza la de **muestreo**. Sin PR ni respuesta.
9. **Cero tests** de inyección de entropía y cero de reorg de PoT en todo el monorepo.
10. Un voto **no puede llevar payload** (`Vote::V0`, seis campos). #2078 prohibió soluciones de
    calidad de bloque en votos porque «will likely result in vote being included on both branches
    in case chain forks»: el voto es *deliberadamente* incluible en varias ramas, y por eso no
    puede valer como bloque. Identidad de voto `(public_key, sector_index, piece_offset, chunk, slot)`,
    sin `reward_address`; misma clave y firma distinta = equivocación, se revocan las recompensas
    del bloque actual (`:1633-1657`); impuesto al proponente 10 % (`ProposerTaxOnVotes = (1,10)`).

## 3 · La propuesta: espina + fardos (candidato A de D2, corregido con las fuentes)

**Qué es.** La espina es la cadena lineal de hoy, sin cambios: 556 B, un `prev_hash`, LWMA-1 sobre
slots, q = 120, inyección de entropía, archivado, caducidad de sectores. Los billetes del anillo
`SR/2 < solution_distance ≤ RANGO_FARDO/2`, que hoy se descartan, producen **fardos**: cabecera
propia con la misma solución y sello, sin `prev_hash` elegible, anclados a un bloque de espina
concreto, **con transacciones** y **con peso cero** en fork choice. Es exactamente el voto de
Autonomys con payload, y la clase bloque/fardo la fija la distancia de solución, como en Chia la
fija el tiempo del VDF: **no depende de que el bloque haya costado nada**, que es lo que mata a
Prism/OHIE/Parallel Chains bajo PoST.

**Por qué respeta R1-R7.** No toca el PoT ni la inyección (R1-R3: rezago añadido = 0). Anillos
disjuntos ⟹ un billete es bloque o fardo, nunca ambos (R4). Solo la espina pesa (R5). Orden total =
orden de la espina; dentro del bloque: coinbase, tx propias, fardos en orden determinista, tx de cada
fardo en su orden; conflicto = gana la primera aparición, las demás se descartan sin invalidar el
bloque (R6; construcción de Prism §5.2.3 / Conflux; deroga C-BLK-09 para fardos). §26 verifica la
espina como hoy; la prueba de pago de una tx en fardo son dos saltos de Merkle (R7).

**Lo que las fuentes obligan a cambiar del borrador de D2:**

- **Chia, Objective 5**: el autor de un objeto paralelo **no conoce el estado** sobre el que
  valida cuando firma. Un fardo se construye contra el estado del ancla; el bloque de espina que lo
  incluye lo aplica contra su propio estado y descarta lo que ya no sea válido. Chia prefirió tirar
  el payload entero (`block_creation.py:483-487`); ZEROX tendría que aceptar payload parcialmente
  inválido, que es el modelo de Prism/Conflux. Es la regla C-FRD-06 y es la que más trabajo de
  validación añade.
- **Autonomys #2078**: un fardo es incluible por el hijo del ancla o por el nieto (alturas n, n−1),
  igual que un voto. Con peso cero eso es inocuo para la seguridad; para el ledger significa que un
  fardo puede aparecer en dos ramas con contextos distintos, y la regla de conflicto lo absorbe.
- **Autonomys, equivocación**: identidad `(public_key, sector_index, history_size, chunk, slot)`;
  misma identidad con payload distinto = equivocación ⟹ se revocan las recompensas del firmante en
  ese bloque. D9 ya mostró que «pasado con dos identidades → inválido» particiona; la regla debe
  ser de recompensa, no de validez de la cadena.
- **Entropía**: como es `blake3(chunk ‖ pot_output)` y los fardos no son bloques `50j`, un fardo
  **no puede tocar la inyección** por construcción. No hace falta regla.

**Lo que compra y lo que cuesta** (σ = 1 s, Δ = 4 s, 556 B, 1,32 ms/cabecera, ~350 B/tx, zona
libre 100 KB; F = 9 fardos esperados por bloque como Autonomys, número a derivar, no a copiar):

| | Lineal hoy | Espina + fardos |
|---|---:|---:|
| Latencia a inclusión (objeto respaldado por espacio) | ~120 s | **~13 s** |
| Latencia a confirmación | sin cambio | **sin cambio** |
| Granjeros que cobran por bloque | 1 | **~10** (varianza ÷10) |
| Throughput | 2,38 tx/s | ×(1+F) solo si se amplía la zona libre; ×1 si no |
| Cabeceras extra | — | 1,31 GB/año |
| CPU extra por bloque | — | 11,9 ms (9 × 2 KZG) |
| Reglas del SPEC que cambian | — | C-BLK-01/09, C-EMIT (reparto), C-WGT (peso incluye fardos), C-NET (topic, dedup), §26 |
| Constantes nuevas a derivar | — | `FACTOR_RANGO_FARDO`, `MAX_FARDOS`, ventana `W`, reparto del subsidio, impuesto al proponente |
| Qué se pierde de Autonomys como referencia | — | Nada del PoT ni del PoS; los votos con payload son extensión propia |

**El ataque abierto: robo de tarifas.** Si el fardo cobra las tarifas de sus tx, el productor de
espina puede no referenciarlo y copiarle las transacciones (el problema de los microbloques de
Bitcoin-NG). La única salida vista es la de Autonomys: pagar al fardo desde el **subsidio**, no
desde las tarifas, con impuesto al proponente por incluirlo. C-EMIT-01 lo permite barato porque
lee `emitido`, no la altura: el subsidio se puede partir y lo no reclamado no se emite (C-FRD-07).
Pero el reparto es un parámetro de incentivos **sin derivar**, y decide si la capa vive o muere.

**Reglas candidatas (D2, numeración provisional, NO escribir en el SPEC aún):** C-FRD-01 anillo
disjunto; C-FRD-02 identidad; C-FRD-03 ancla con `slot(ancla) < slot(fardo) ≤ slot(ancla) + W`;
C-FRD-04 referencia ≤ `MAX_FARDOS` en orden determinista; C-FRD-05 peso solo espina; C-FRD-06 orden
y conflicto por primera aparición; C-FRD-07 lo no reclamado no se emite.

## 4 · Los otros dos candidatos, y por qué no

- **B · Espina + m ramas de voto (Prism).** Compra confirmación rápida, pero Prism ec. (18):
  `m = 2CD/(1−2β) − 1`, y su ventaja es exponencial **en m**. Con cabeceras de 556 B: m = 4 → 4,4
  GB/año, m = 100 → 88,5 GB/año. Al presupuesto de una moneda de pago m cae en 4-10, donde un
  atacante con α = 0,25 captura ramas enteras. Además la reducción de Prism exige que el minero no
  conozca su rol antes de minar; bajo PoST lo conoce 4 s antes (no puede moverlo, pero la prueba no
  cubre ese caso).
- **C · m canales de desafío con un solo PoT** (`desafío_i = blake3(PoT ‖ slot ‖ i)`), la variante
  que sí modifica el PoST en una línea. Compra latencia `120/m` y throughput ×m con cabeceras
  baratas, pero multiplica por m el coste de auditoría del granjero: 4 TiB pasa de 4 161 a 16 644
  lecturas/slot con m = 4; 20 TiB de 20 807 a 83 228, al borde de los ~100k IOPS de un SSD. Paga
  descentralización (P-036, prioridad 1) por latencia. Y congelar un canal congela el orden total.

## 5 · Orden de trabajo recomendado

1. **P-039 antes que nada**, con o sin fardos: fijar `interval × depth == K` (no «2 intervalos»),
   derivar `DELAY` en tiempo de modo que el inyector tenga confirmaciones cuando la inyección surta
   efecto (hoy a T = 120 s no tiene ninguna), y decidir si `c = 50` se queda en bloques (φ₅₀ = 1,2815).
   Es un defecto del diseño lineal actual.
2. Si Katana quiere fardos: D9 sobre los cinco puntos de D2 (invariancia del anillo, φ₅₀ con rango
   ensanchado, `MAX_FARDOS` por cola de Poisson, LWMA con peso de fardos, rezago de inyección
   inalterado) y D8 sobre los cinco ataques (robo de tarifas, spam de fardos a 1,32 ms cada uno,
   equivocación de payload, censura selectiva, ocultación en §26). Antes de escribir una regla.
3. Fardos son una **actualización de red** posible después de la beta transparente: la espina no
   cambia, así que se pueden añadir a una altura por C-UPG, como el pool blindado.

## 6 · Lagunas

- Nadie ha trasladado formalmente a una estructura con capa paralela el argumento de estabilidad
  por prefijo común de Praos; D2 lo evita dejando la capa paralela a peso cero, que es una elección
  de diseño, no un teorema.
- `s_bucket` frente a `chunk` en la identidad (¿varios chunks ganadores por bucket?): sin verificar
  en `proving.rs`.
- `Dmax` real sigue sin medir; todas las latencias usan Δ = 4 s como proxy.
- Patente US 12,182,103 de Chia («extending a proof-of-space-time blockchain», cadenas paralelas
  como mitigación del double dipping): no leída; es patente, no spec.
- El reparto del subsidio y `FACTOR_RANGO_FARDO` no tienen número y no se inventan.

---

## Anexo · Los cinco informes íntegros


---

### A · Literatura (zx-specs, Opus)

# Consenso no lineal sobre recursos "gratis" con reloj de slots: cómo obtienen la aleatoriedad

Contexto leído: `/home/katana/zeo/ZEROX/research/dag-poas-auditoria.md` §0–§0.4 y `/home/katana/zeo/ZEROX/research/dag-consenso-poas.md`. Textos extraídos en `/tmp/claude-1000/-home-katana-zeo/0cfccf9e-55ae-4058-bcf4-31f0987f1dbd/scratchpad/src/` y `.../papers/`.

---

## 1 · Parallel Chains (Fitzi–Gaži–Kiayias–Russell) — el precedente más directo

```
AFIRMACIÓN: La variante PoS ejecuta m cadenas en paralelo con UNA sola aleatoriedad de época
            compartida, derivada del contenido de las m cadenas de la época j−1 truncado a 2R/3,
            y una distribución de stake tomada del final de la época j−2.
FUENTE:     Fitzi, Gaži, Kiayias, Russell, "Parallel Chains…", ePrint 2018/1119, versión
            30-nov-2018, §5.2, Fig. 2 paso 2 (p. 10) y §5.2 texto (p. 11).
            https://eprint.iacr.org/2018/1119
CITA:       "To compute ηj∗, collect the blocks B = (c,st,d,sl,πB,ρ,σ) ∈ Cc belonging to epoch
            ej∗−1 up to the slot with timestamp (j∗−2)R + 2R/3 in any of the currently held
            c-chains Cc for c ∈ [m], concatenate the values yρ (from each ρ) into a value v in
            some fixed predetermined order, and let ηj∗ = H(ηj∗−1‖j∗‖v)."
CONFIANZA:  alta
```

```
AFIRMACIÓN: La lotería de líder es INDEPENDIENTE por cadena porque el índice de cadena c entra
            en la entrada del VRF; un mismo "billete" de un slot no sirve para las m cadenas.
FUENTE:     ibíd., Fig. 2, paso 3(a)(ii) y paso 4(a)-(b) (p. 10).
CITA:       "Fvrf responds to (Verify,sid,ηj‖c‖sl‖TEST,y,π,vvrf_s)…" · "Send (EvalProve,sid,
            ηj‖c‖sl‖NONCE) to Fvrf".
CONFIANZA:  alta
```

```
AFIRMACIÓN: En PoS NO hay componente lineal privilegiado: el orden total se extrae del índice de
            slot. En PoW SÍ hace falta una "cadena de sincronización" C1 porque el bloque PoW no
            lleva marca de tiempo verificable.
FUENTE:     ibíd., §1 "Our results" (p. 2) y Fig. 4 GetValidTX (p. 11); §6 (p. 17-19).
CITA:       "An additional complication arises in the PoW setting as blocks do not carry a
            verifiable time-stamp (that, in the PoS setting, is provided for 'free' by our
            construction). This prohibits the use of the same simple blockchain combine algorithm
            used in the PoS setting. Instead, we use the following mechanism: we identify one of
            the m blockchains as the synchronisation chain and we have every block refer to a
            block of that chain which will play the role of a timestamp."
CONFIANZA:  alta
```

Orden total en PoS: `GetValidTX` ordena por «(a) slot index sl from the block B containing the transaction; (b) chain number c from the block B; (c) position of the transaction within B» (Fig. 4). Garantía: Teorema 2 (Robustness) — `(αH−ν)(1−f)^Δ ≥ (1+ξ1)/2`, error `εrob = m·εPraos + Pr[¬MaxDelay_Δ]`; la prueba es unión sobre m ejecuciones "implícitas" de Praos. **Recurso asumido: stake.** No hay implementación conocida de este protocolo.

En la variante PoW, la asignación de cadena sale del hash: `ch(B) := 1 + H(B) mod m`, «random and becomes known to the miner only after the PoW has been completed» (§6, p. 17-18). Eso es exactamente lo que un recurso gratuito no provee.

---

## 2 · Ouroboros Praos / Genesis — el mecanismo de beacon en sí

```
AFIRMACIÓN: El nonce de época se simula con un oráculo aleatorio sobre valores VRF incluidos en
            los bloques de los primeros 16k/f slots de una época de 24k/f, dejando un periodo
            "silencioso" de 8k/f slots para que el nonce se estabilice antes de usarse.
FUENTE:     David, Gaži, Kiayias, Russell, "Ouroboros Praos", ePrint 2017/573, versión
            27-abr-2023, §5 (p. 27) y Fig. 10 πRLB (p. 31). https://eprint.iacr.org/2017/573
CITA:       "This hash function is applied to the concatenation of VRF values that are inserted
            into each block during the first 16k/f slots of an epoch that lasts 24k/f slots in
            entirety. (The 'quiet' period of the final 8k/f slots in each epoch will ensure that
            the nonce is stable before the next epoch begins.)"
CONFIANZA:  alta
```

La estabilidad **no** viene de un orden total reciente: viene de que el prefijo usado queda enterrado bajo 8k/f slots, y de que common-prefix + chain-quality garantizan que al menos un bloque honesto entra en la ventana media. Cita literal (§5.2, Lema 5, p. 31): *"by chain growth and chain quality at least one honest block in the middle 8k/f slots of an epoch will be included in the chain of all honest parties and contribute to the calculation of the hash."*

```
AFIRMACIÓN: El grinding NO se elimina; se acota contando las consultas al RO que el adversario
            puede pagar, modelándolo como un beacon "resettable" con r = 8tqk/f reseteos.
FUENTE:     ibíd., §1 (p. 3), §5 (p. 28) y Lema 5 (p. 31).
CITA:       "implementing the beacon via hashing VRF values will make feasible a type of
            'grinding attack' where the adversary can trade hashing power for a slight bias of
            the protocol execution to its advantage. We show how this bias can be controlled by
            suitably increasing the relevant parameters".
CONFIANZA:  alta
```

Ouroboros Genesis (ePrint 2018/378, versión 22-feb-2019) mantiene la misma derivación de nonce (`ηj‖sl‖NONCE`, Fig. 9, p. 27) y solo cambia la regla de selección de cadena a `maxvalid-bg` por densidad; **no aporta un beacon distinto**. Implementación: Cardano (Praos en producción desde 2020).

---

## 3 · Prism / OHIE — el orden lo da la estructura, la aleatoriedad la da el PoW

```
AFIRMACIÓN: Prism reparte cada bloque minado entre 1 bloque proposer, 1 de transacciones y m
            de voto mediante sortition determinista sobre el hash del PoW; ese sortition es lo
            que impide al adversario concentrar su poder en una estructura concreta.
FUENTE:     Bagaria, Kannan, Tse, Fanti, Viswanath, "Prism", arXiv:1810.08092v4 (2-oct-2019),
            CCS 2019, §2 "Sortition" (p. 3-4) y §4.2 (p. 5).
CITA:       "The sortition of blocks into the three types of blocks, and further into blocks of
            different voting trees, can be accomplished by using the random hash value when a
            block is successfully mined. This sortition splits the adversary power equally across
            the structures and does not allow it to focus its power to attack specific
            structures."
CONFIANZA:  alta
```

```
AFIRMACIÓN: El componente que sostiene la seguridad es la cadena más larga de CADA árbol de
            votantes; los bloques de transacciones y los proposer no necesitan ser lineales.
FUENTE:     ibíd., §2 "Deconstruction" (p. 3).
CITA:       "The valid voter blocks are the ones in the longest chain of the voter tree, and this
            longest chain maintains the security of the whole system."
CONFIANZA:  alta
```

Garantía: seguridad hasta β<50 % de hashrate, throughput hasta la capacidad C, latencia ∝ D con error exponencial en CD (§1). Implementación: `prism-rust` (Zhang et al., NSDI'20), clonado en el scratchpad. **No existe análisis de Prism sobre PoS ni PoSpace**: el string "stake" no aparece en el paper salvo en referencias, y "space" solo como "Due to space…".

OHIE (Yu, Nikolić, Hou, Saxena, S&P 2020) usa el mismo truco: asignación de cadena por hash, y un orden total por pares `(rank, next rank)` sin cadena de sincronización. El SoK lo clasifica como PoW.

---

## 4 · Meshcash / Spacemesh — la malla por capas

```
AFIRMACIÓN: La moneda débil (weak coin) de Meshcash, que es su única fuente de aleatoriedad, se
            construye SOBRE el PoW: hashes como salida de un oráculo aleatorio y publicación de
            bloques como proceso de Poisson proporcional al poder de cómputo.
FUENTE:     Bentov, Hubáček, Moran, Nadler, "Tortoise and Hares Consensus: the Meshcash
            Framework", ePrint 2017/300, §3.3.1 (p. 11).
CITA:       "We can implement a weak common coin based on any proof-of-work protocol (assuming
            the PoW hashes are the output of a random oracle) in which block publication can be
            modeled as a Poisson process with rate proportional to computational power."
CONFIANZA:  alta
```

El paper ofrece una alternativa off-chain sin PoW basada en firmas únicas (Micali), con `pcoin = 1/3` y requisito de 2/3 de honestos entre los generadores de bloques (§6.1, p. 33-34). El tortoise **no** usa elección de líder: *"our tortoise protocol does not rely on leader-election… we use ideas from asynchronous byzantine agreement protocols to gradually converge to a consensus"* (Abstract). El componente que debe ser "lineal" es solo el **contador de capas** con consenso débil (§3.4.5, p. 15-16).

Spacemesh, ya con PoST, **tuvo que añadir un beacon que el paper no tenía**:

```
AFIRMACIÓN: Spacemesh calcula un beacon por época mediante un protocolo de 3 fases (propuesta,
            consenso por rondas con moneda débil, salida) sobre salidas VRF de ATXs; el beacon de
            la época N se genera durante la época N−1.
FUENTE:     spacemeshos/protocol, `beacon_protocol.md` y `beacon_overview.md` (rama master,
            consultado 2026-09-07). https://github.com/spacemeshos/protocol
CITA:       "The spacemesh protocol requires a source of randomness to introduce unpredictability
            in the eligibility of making proposals and participating in the Hare protocol." ·
            "A smesher must declare a beacon value in their first ballot (a.k.a the reference
            ballot) of an epoch and will not be able to change it for the rest of the epoch."
CONFIANZA:  media (documentación de proyecto, no spec formal; no hay paper del beacon)
```

Rezago: una época completa (2 semanas en mainnet). El beacon **no se deriva de un orden total reciente**: se deriva de un acuerdo bizantino explícito sobre propuestas VRF, anclado en ATXs recibidas antes del fin de la época anterior. El PoET aporta el paso del tiempo dentro de la ATX, no la aleatoriedad. Implementación: `go-spacemesh` — red **muerta de facto desde may-2025** (ya documentado en `dag-consenso-poas.md` §4).

---

## 5 · Chia — linealidad selectiva: el trunk lleva la entropía, el foliage no

```
AFIRMACIÓN: El desafío de PoSpace depende de UN SOLO bloque por slot (el primero), aunque el
            slot admita hasta 64 bloques; los demás bloques existen, se recompensan y llevan
            transacciones, pero NO afectan al desafío.
FUENTE:     Chia Green Paper (greenpaper vigente, 12-jun-2026), §1.7 (p. 13-14), §5.5 (p. 33-34)
            y Design Choice 4 (p. 34). Texto en .../scratchpad/greenpaper_vigente.txt
CITA:       "(CC) If this happens to be the first block whose signage points are in the current
            slot, then μrc_sp (but not σ) is infused into the challenge chain CC at the end of
            the current slot. This way the challenge chain depends only on one block per slot."
CONFIANZA:  alta
```

```
AFIRMACIÓN: Infusionar el bloque entero en la cadena de desafío rompería la seguridad frente a
            double dipping; por eso se infusiona solo el PoSpace σ.
FUENTE:     ibíd., Security Notice 1, §5.5 (p. 34).
CITA:       "Had we infused the entire βT (as we do into RC), the challenges would depend on all
            blocks (as μrc_sp depends on RC which infuses all blocks) and we would not get
            security against double dipping."
CONFIANZA:  alta
```

Y el foliage con múltiples bloques existe explícitamente: *"only a subset of the foliage blocks are included in the foliage chain FC"*; el timelord decide cuál lo es (*"The time lord will add the foliage of a block – and thus make this block a transaction block – if no other transaction block was infused between the signage and infusion point of that block"*, Design Choice 5, §5.6, p. 35-36). Resultado medido por el propio paper: **36 % de los bloques llevan transacciones**, uno cada ~51,95 s (§5.7). Es decir: Chia ya separa "bloque que inyecta entropía" (1 por slot, lineal, ungrindeable) de "bloque que ordena transacciones" (cadena de foliage secuencial) de "bloque que se recompensa" (hasta 64 por slot en RC). **Recurso: espacio; el diseño asume explícitamente que producir un bloque es gratis** (§1.8: *"challenges due to 'nothing at stake' (aka. costless simulation)"*). Implementación: `chia-blockchain`, mainnet desde 2021.

---

## 6 · Ouroboros Leios — el híbrido vivo (diseño, no producción)

```
AFIRMACIÓN: Leios mantiene la cadena Praos como capa de ranking que da el orden total y la
            aleatoriedad; los endorser blocks son la capa paralela y solo entran al ledger vía
            un certificado anclado en un ranking block.
FUENTE:     input-output-hk/ouroboros-leios, docs/leios-design/README.md (rama main, consultado
            2026-09-07); CIP-0164 "Ouroboros Linear Leios".
CITA:       "Only EBs that achieve a high threshold of stake-weighted votes become certified and
            can be included in the ledger through exclusive anchoring of a certificate in the
            subsequent block."
CONFIANZA:  media (documento de diseño en evolución; el CIP-0164 sustituyó variantes previas con
            input blocks, y el README no especifica el sortition nuevo, lo difiere al CIP)
```

---

## 7 · Adyacente: PoSAT — aleatoriedad con VDF bajo recurso gratuito (pero cadena lineal)

PoSAT (Deb, Kannan, Tse, arXiv:2010.08154v2, 19-feb-2021, FC 2021) sustituye el hash por un VDF aleatorizado para recuperar la impredecibilidad del PoW bajo stake, y **reduce la tasa de actualización de la aleatoriedad para acotar el grinding**: *"Instead of updating the block randomness at every level of the blocktree, we only update it once every c levels (called an epoch)"* (§2, p. 5). Teorema 1: seguro si `λc_h(t)/(1+λmax·Δ) > φc·λa(t)`, con `φc → 1` cuando `c → ∞`, pero `c` debe ser finito. Es **cadena lineal**, no DAG; lo incluyo porque es la única fuente que trata explícitamente el trade-off «rezago de la entropía ↔ grinding» bajo un recurso sin coste.

---

## 8 · Estado del arte declarado

El SoK de DAGs (Raikwar, Polyanskii, Müller, arXiv:2411.10026v2, 22-abr-2025) clasifica en su Tabla I (p. 6) **ningún protocolo DAG sobre proof of space**: Prism/OHIE/GHOSTDAG/Meshcash como PoW, Parallel Chains como "PoW/PoS", Expected Consensus (Filecoin) como "PoS … adapted consensus for storage resource", Tangle 2.0 como PoS. Reconoce el problema pero sin tratarlo: entre las acciones adversariales lista *"Producing blocks beyond the protocol's allowed rate (relevant in PoS, committee-based, and permissioned systems, but generally not in PoW protocols)"* (§V.A, p. 12). **No hay sección sobre beacons, grinding ni costless simulation.**

---

## Tabla comparativa

| Protocolo | Componente que DEBE ser lineal | Fuente de aleatoriedad | Rezago / estabilidad | Recurso asumido | Implementación |
|---|---|---|---|---|---|
| **Parallel Chains PoS** (2018/1119 §5) | Ninguno; el orden sale del slot + índice de cadena | `ηj = H(ηj−1‖j‖v)`, v = valores VRF de las m cadenas en época j−1 hasta 2R/3; stake del fin de j−2 | ≥ R/3 slots (tercio silencioso) + 1 época para el stake | Stake (VRF por (η,c,sl)) | No |
| **Parallel Chains PoW** (§6) | Cadena de sincronización C1 (hace de reloj) | Hash del PoW: `ch(B)=1+H(B) mod m` | Ninguno (instantáneo) | Trabajo: el hash es el sorteo | No |
| **Ouroboros Praos / Genesis** | La cadena (es lineal) | VRF de bloques de los primeros 16k/f de 24k/f slots | 8k/f slots de "quiet period"; grinding acotado por r = 8tqk/f | Stake | Cardano |
| **Prism** (1810.08092v4) | Cadena más larga de cada uno de los m árboles de votantes | Hash del PoW (sortition en m+2 roles) | Ninguno | Trabajo | prism-rust (NSDI'20) |
| **OHIE** | Ninguna; orden por (rank, next rank) | Hash del PoW | Ninguno | Trabajo | Prototipo del paper |
| **Meshcash** (ePrint 2017/300) | Solo el contador de capas (consenso débil) | Weak coin: LSB del hash mínimo de la capa (PoW) o firmas únicas Micali (pcoin=1/3) | 1 capa (T) | Trabajo (o 2/3 honestos si Micali) | — |
| **Spacemesh** | Capa + ATX por época | Beacon por BA explícito de 3 fases sobre VRF de ATXs | 1 época completa (~2 semanas) | Espacio-tiempo (PoST+PoET) | go-spacemesh; red caída may-2025 |
| **Chia** (greenpaper 2026-06-12) | Trunk: CC/RC (VDF) + cadena de foliage secuencial | Primer bloque del slot infusionado en CC (solo σ) + iCC | 1 slot; enterrado por VDF al revelarse | Espacio + tiempo (VDF) | chia-blockchain, mainnet |
| **Leios / CIP-0164** | Cadena de ranking Praos | Nonce de época de Praos | Igual que Praos | Stake | En diseño (IOG) |
| **PoSAT** (2010.08154v2) | Cadena (lineal) | VDF aleatorizado sobre la aleatoriedad del bloque, actualizada cada c niveles | c bloques | Stake | No |

---

```
LAGUNAS:
- No he encontrado NINGÚN protocolo no lineal (DAG, cadenas paralelas, proposer/voter, malla)
  cuyo recurso sea proof of space (o space-time) Y que tenga análisis publicado de su fuente de
  aleatoriedad. El único caso real (Spacemesh) documenta su beacon solo en el repo de protocolo,
  sin paper ni teorema, y su red está caída.
- No pude verificar el sortition de Ouroboros Leios: el README lo difiere al CIP-0164 y no lo
  especifica. Tampoco pude leer CIP-0164 completo en esta sesión.
- No pude extraer el texto de la patente US 12,182,103 (Chia, "Methods for extending a
  proof-of-space-time blockchain"), que según el resumen del buscador propone cadenas paralelas
  como mitigación del double dipping. Queda como pista NO verificada; es además una patente, no
  una spec.
- El paper de Meshcash extraído no lleva fecha de versión visible; cito el número de ePrint sin
  poder fijar la revisión.
- No he encontrado tratamiento formal del rezago mínimo de un beacon derivado de cadena en un
  DAG (frente a "prefijo de época" en cadena). Praos lo resuelve con common-prefix sobre una
  cadena; ninguna fuente lo traslada a un DAG.

AMBIGÜEDADES:
- Parallel Chains PoS afirma que la seguridad se hereda "except that the leader selection in
  epoch j is based on… all m chains", con un factor m por cota de unión, pero solo da un
  "Proof (sketch)" (§5.3, p. 11-12) para el paso crítico: que derivar η de m cadenas no rompe el
  argumento de Praos. No hay demostración completa de que la superficie de grinding no crezca
  con m.
- Chia dice "the challenge chain CC should only depend on the first block in every slot" pero
  acto seguido introduce dos excepciones (la infusión de la reward chain cada sub-época por
  replotting, §5.5; y los time-stamps del foliage que recalibran el parámetro de tiempo,
  Objective 2). El propio texto dice "(almost) only Depends" y "(almost) Ungrindeable". Además
  §5.5 tiene un "shifted XXX back" — un placeholder sin rellenar en el documento vigente.
- Spacemesh: "The beacon must be generated recently enough to make it difficult for adversaries
  to prepare for an attack, yet allow ample time for the network to reach consensus" no fija un
  criterio verificable; el mismo trade-off que la auditoría D9 identificó como irreconciliable
  para ZEROX queda aquí enunciado sin resolver formalmente.

CONTRADICCIONES:
- Parallel Chains PoW y Prism/OHIE resuelven la asignación a estructura con el hash del PoW
  ("random and becomes known to the miner only after the PoW has been completed"). Chia establece
  lo contrario para su recurso: el granjero conoce su solución antes y la única decisión que
  puede tomar es publicar o no ("the only decision that influences the trunk should be whether to
  add a block or not", Objective 2). Las dos afirmaciones no se contradicen entre sí, pero SÍ
  hacen inaplicable el sortition por hash a un recurso tipo PoSpace: no queda aleatoriedad
  posterior al sorteo con la que asignar estructura.
- El SoK clasifica Meshcash como PoW (Tabla I, p. 6), mientras que el proyecto que lo implementó
  (Spacemesh) usa PoST. El SoK describe el paper, no el despliegue; conviene no citarlo como
  evidencia de "DAG sobre espacio".
```

**Patrón común a todas las fuentes.** Ninguna deriva la entropía de un orden total *reciente*. O bien (a) la entropía es el propio sorteo del recurso costoso y no hace falta beacon (Prism, OHIE, Parallel-Chains-PoW, Meshcash), o bien (b) hay un beacon con rezago de época y periodo silencioso apoyado en common-prefix sobre **una cadena** (Praos, Genesis, Parallel-Chains-PoS, Leios), o bien (c) hay un beacon por acuerdo bizantino explícito, fuera de la estructura de bloques (Spacemesh), o bien (d) la entropía la fija **un solo bloque por slot dentro de una cadena lineal de VDF**, y la parte no lineal (foliage, bloques extra del slot) se define explícitamente para **no** tocar el desafío (Chia).

Sources: [ePrint 2018/1119](https://eprint.iacr.org/2018/1119) · [ePrint 2017/573](https://eprint.iacr.org/2017/573) · [ePrint 2018/378](https://eprint.iacr.org/2018/378) · [arXiv:1810.08092](https://arxiv.org/abs/1810.08092) · [arXiv:2411.10026](https://arxiv.org/abs/2411.10026) · [arXiv:2010.08154](https://arxiv.org/pdf/2010.08154) · [spacemeshos/protocol](https://github.com/spacemeshos/protocol) · [ouroboros-leios](https://github.com/input-output-hk/ouroboros-leios/blob/main/docs/leios-design/README.md) · [CIP-0164](https://cips.cardano.org/cip/CIP-0164)

---

### B · Chia (zx-chia, Opus)

## Informe — la arquitectura trunk/foliage de Chia frente a la pregunta del DAG

Fuentes: clon local `chia-blockchain 2.7.4` (`/home/katana/zeo/ZEROX/PDF/chia-blockchain/`), `chia_rs 0.48.0` (`665176a`, en `/tmp/claude-1000/-home-katana-zeo/32d96f16-.../scratchpad/pos/chia_rs`), greenpaper vigente (`/tmp/claude-1000/-home-katana-zeo/0cfccf9e-.../scratchpad/greenpaper_vigente.txt`).

**Conclusión de encabezado, para que no se pierda abajo:** Chia **no** tiene una estructura no lineal. El trunk es una cadena estricta (`height = prev+1`, y el RC-VDF encadena *todos* los bloques), y el foliage es una **subcadena** del trunk, no un DAG. Lo que Chia sí tiene es (a) aislamiento del desafío respecto de la mayoría de bloques y (b) un **orden total determinista por contenido** (`total_iters`) entre bloques que comparten desafío. Esos dos mecanismos son separables del resto y son la parte reutilizable.

---

### 1 · Qué influye en la challenge chain y qué no

```
AFIRMACIÓN: El CC solo cambia por el "challenge block": deficit == MIN_BLOCKS_PER_CHALLENGE_BLOCK-1 = 15.
CLASE:      regla de consenso
ARCHIVO:    chia_rs 0.48.0 crates/chia-protocol/src/block_record.rs:70-72
CÓDIGO:     `self.deficit == min_blocks_per_challenge_block - 1`
            (constantes: default_constants.py:15 `MIN_BLOCKS_PER_CHALLENGE_BLOCK=uint8(16)`,
             :14 `SLOT_BLOCKS_TARGET=uint32(32)`, :17 `NUM_SPS_SUB_SLOT=uint8(64)`,
             :39 `NUM_SP_INTERVALS_EXTRA=uint8(3)`, :16 `MAX_SUB_SLOT_BLOCKS=uint32(128)`)
PARA ZEROX: el desafío no depende del bloque anterior sino de un bloque designado ≥16 bloques atrás.
CONFIANZA:  alta
```

La cadena de designación es: `deficit` baja 1 por bloque (`consensus/deficit.py:44-51`); al llegar a 0 se queda en 0 hasta que termina un sub-slot; al cruzar el sub-slot se reinicia a 16 si el bloque es overflow y a 15 si no (`deficit.py:36-43`). Deficit 15 = challenge block. El ICC arranca en `curr.challenge_block_info_hash` (`block_header_validation.py:178-180`, `:1060-1064`), donde `ChallengeBlockInfo = {proof_of_space, cc_sp_vdf, cc_sp_signature, cc_ip_vdf}` (`chia_rs .../slots.rs:11-16`) — **no** incluye el foliage ni el RC. Y el hash del ICC entra en el CC **solo si el deficit llegó a 16 al final del slot**:

```
ARCHIVO:    consensus/block_header_validation.py:247-256   (2g / 2h)
CÓDIGO:     `if sub_slot.reward_chain.deficit == constants.MIN_BLOCKS_PER_CHALLENGE_BLOCK:`
            → exige `infused_challenge_chain_sub_slot_hash` en el CC; en cualquier otro deficit
              exige que sea `None`.
```

Es decir: si en un slot hubo menos de 16 bloques, el CC **no** recibe nada y sigue siendo VDF puro. El greenpaper (p. 34, *Design Choice 4*) presenta esto como «cota inferior de 16 bloques por slot»; el código **no** impone tal cota — la implementa como «el desafío no se actualiza». Divergencia paper/código, y a favor del código: es más simple y no necesita rechazar bloques.

**El aislamiento no es total, por diseño.** Una vez por sub-época (`SUB_EPOCH_BLOCKS=uint32(384)`, `default_constants.py:25`, ≈2 h) el CC incorpora `subepoch_summary_hash`, y el `SubEpochSummary.reward_chain_hash` es el hash de fin de slot del RC (`make_sub_epoch_summary.py:82-89`; struct en `chia_rs .../sub_epoch_summary.rs:10-18`), que encadena **todos** los bloques. Greenpaper *Objective 3* (p. 34) lo dice explícito: si el CC dependiera solo del primer bloque, habría ataques de replot a largo alcance. **REGLA DE CONSENSO.**

**Qué pasa si un bloque no-desafío se retiene y se publica tarde: no entra, nunca.** No es política, es estructural:

```
AFIRMACIÓN: El RC infunde TODOS los bloques; el reto del RC-IP-VDF de un bloque es el hash del
            RewardChainBlock completo de su padre, y el número de iteraciones es la diferencia
            exacta de total_iters.
CLASE:      regla de consenso
ARCHIVO:    block_header_validation.py:954-958 ; full_block_to_block_record.py:153
CÓDIGO:     `rc_vdf_challenge = prev_b.reward_infusion_new_challenge`
            `ip_vdf_iters = uint64(header_block.reward_chain_block.total_iters - prev_b.total_iters)`
            y `reward_infusion_new_challenge := block.reward_chain_block.get_hash()`
PARA ZEROX: el punto de infusión de un bloque está fijado por su contenido
            (ip_iters = sp_iters + 3·spi + required_iters, pot_iterations.py:51). Publicarlo tarde
            no lo mueve: solo permite construir una RAMA que lo contenga y excluya a los que
            se infundieron entretanto. Retener == bifurcar.
CONFIANZA:  alta
```

Efectos colaterales de retener un bloque no-desafío: (i) su rama pierde 1 unidad de peso frente a la honesta; (ii) desplaza en 1 la cuenta atrás del `deficit`, lo que **solo** cambia la identidad del challenge block si el slot tiene ≈16 bloques o menos (con 32 de objetivo, el deficit llega a 0 mucho antes del borde y el challenge block es el primer no-overflow del slot siguiente, sea cual sea el conteo); (iii) si era transaction block, el bloque siguiente pasa a serlo (§3). Nada más. Confianza media en (ii): es deducción sobre `deficit.py:36-43` + `:44-51`, no hay comentario que lo diga.

---

### 2 · Cómo se elige el challenge block

Es **determinista por contenido**, no por el reloj del timelord. `deficit` es función pura de `(altura, deficit del padre, overflow, nº de sub-slots terminados)` (`deficit.py:7-51`); `overflow` es función pura del `signage_point_index` (`pot_iterations.py:16-19`: `signage_point_index >= NUM_SPS_SUB_SLOT - NUM_SP_INTERVALS_EXTRA`, o sea índices 61-63). Dos nodos con la misma cadena calculan el mismo challenge block. Greenpaper p. 33-34 lo formula igual: `β_j` con `j = min{k : β_k.d > 3·spi}`, el primer bloque infundido en el slot pasado el 3.º signage point — que es exactamente lo que consigue el descarte de los overflow.

Lo que **sí** puede hacer un atacante es **no publicar** su bloque ganador para que el challenge block sea otro. Greenpaper §2.1 (líneas 540-543 del texto extraído): *«the only choice a farmer has to influence the challenge is by withholding a winning block»*. Eso es el double dipping, acotado por el factor 1,47 con k=16 (greenpaper §2.2, p. 18-19, sobre [BDK+19]).

La ventana 3-4 signage points **no acota eso**; acota otra cosa, y es el mecanismo más interesante para ZEROX:

```
AFIRMACIÓN: ip_iters = (sp_iters + NUM_SP_INTERVALS_EXTRA·spi + required_iters) mod sub_slot_iters
CLASE:      regla de consenso
ARCHIVO:    consensus/pot_iterations.py:51
PARA ZEROX: entre el SP (donde el granjero firma) y el IP (donde se infunde) hay de 3 a 4
            intervalos (28,125-37,5 s en Chia). En esa ventana el PADRE del bloque todavía no
            está decidido: `Foliage.prev_block_hash` es un puntero NO firmado que se rellena
            en la infusión.
CONFIANZA:  alta
```

`chia_rs .../foliage.rs:41-45`: *«for unfinished blocks, the prev_block_hash is the prev from the signage point, and can be replaced with a more recent block»*; y el reemplazo real en `block_creation.py:513-521` (`prev_block_hash=prev_block.header_hash`). La firma del granjero cubre `foliage_block_data` (que contiene `unfinished_reward_block_hash`), no el puntero al padre. Traducido: **el bloque queda atado a todo lo anterior a su SP (vía el reto del RC-SP-VDF) y libre respecto de lo infundido entre su SP y su IP.** Ese es el «espacio de paralelismo» real de Chia, y mide 3-4 SP.

---

### 3 · Transaction blocks: por qué solo uno

```
AFIRMACIÓN: Un bloque es transaction block SI Y SOLO SI su sp_total_iters es mayor que el
            total_iters del último transaction block de su cadena.
CLASE:      regla de consenso
ARCHIVO:    block_header_validation.py:723-744 (check 15) ; y check 24b en :834-843
CÓDIGO:     `while not curr.is_transaction_block: curr = blocks.block_record(curr.prev_hash)`
            `if (our_sp_total_iters > curr.total_iters) != (…foliage_transaction_block_hash is not None):
                 return None, ValidationError(Err.INVALID_IS_TRANSACTION_BLOCK)`
            `if not header_block.foliage_transaction_block.prev_transaction_block_hash == curr_b.header_hash:`
PARA ZEROX: no es una decisión del timelord —el greenpaper dice «the time lord will add the
            foliage» (p. 35-36), el código lo convierte en condición de VALIDEZ calculable por
            cualquiera. Divergencia narrativa paper/código, resuelta a favor del determinismo.
CONFIANZA:  alta
```

El motivo está escrito: greenpaper *Objective 5* (p. 35): *«Every block of transactions added must refer to the previous block of transactions. This way we avoid having to deal with transactions that are invalid due to previous transactions that were added but were not known to the creator of the current transaction block.»* Es decir: la regla existe **para que el autor de un bloque de transacciones conozca con certeza el estado UTXO sobre el que valida**. Un granjero que gana en el SP `i` firma un cuerpo contra un estado que solo se decide 3-4 SP después; si dos bloques del mismo intervalo llevaran cuerpo, ninguno de los dos sabría cuál va primero al firmar.

Qué se rompería si todos llevaran transacciones: (i) los cuerpos se construyen antes de conocer el orden, así que habría que revalidar y descartar conflictos en el momento de la infusión, o aceptar bloques con transacciones parcialmente inválidas (modelo Kaspa/PHANTOM); (ii) desaparece `prev_transaction_block_hash` como ancla de estado; (iii) el pago de recompensas cambia (§5). Chia paga hoy el coste opuesto: el granjero **construye el cuerpo entero y lo tira** si otro se le adelantó — `block_creation.py:483-487` pone `new_foliage_transaction_block = None`, `new_generator = None`. Es trabajo desperdiciado, deliberado.

Fracción resultante: greenpaper §5.7 (p. 36), `1/(e^0,5−1)+4 ≈ 5,54` slots, ≈52 s, **36 % de los bloques**. La documentación oficial confirma que los bloques paralelos del mismo SP se incluyen **todos** y que *«el que se incluye primero es el de menor `required_iters`»* ([docs.chia.net/consensus-multiple-blocks](https://docs.chia.net/consensus-multiple-blocks/)).

**No encontré discusión en Chia sobre foliage-como-DAG.** Cero issues/PRs sobre GHOSTDAG o uncles (coincide con lo ya registrado en `dag-consenso-poas.md` §2). Es LAGUNA, no ausencia demostrada.

---

### 4 · Orden entre bloques del mismo sub-slot

Sí existe, y es determinista **por contenido**: `total_iters`.

```
ARCHIVO:    block_header_validation.py:581-603 (check 10, total_iters exacto y verificado)
            pot_iterations.py:51 (ip_iters) y :90-122 (required_iters ← hash de calidad)
            blockchain.py:521-526 (fork choice: mayor peso; empate → menor total_iters)
CÓDIGO:     `if block_record.weight == peak.weight and peak.total_iters <= block_record.total_iters:
                 return [], None`
```

`required_iters` sale de `std_hash(quality_string ‖ cc_sp_output_hash)` escalado por dificultad y tamaño de plot (`pot_iterations.py:104-121`) — es un valor de 256 bits derivado de la prueba, **no molible sin replotear** y con colisión despreciable. Por tanto, dos bloques que comparten `signage_point_index` se ordenan por `required_iters` y ese orden es idéntico en todo nodo. Es exactamente el análogo del desempate por `solution_distance` que ZEROX ya barajaba.

Matiz que importa: `total_iters` no es función solo del bloque, sino de `total_iters` del inicio del sub-slot (`:586-595`), que depende de la rama. Comparar `total_iters` entre ramas distintas solo tiene sentido si comparten el sub-slot. **REGLA DE CONSENSO** el valor de `total_iters` (check 10); el uso como desempate en fork choice es regla de convergencia, no de validez.

---

### 5 · Peso

```
AFIRMACIÓN: TODOS los bloques suman exactamente `difficulty`, sean o no transaction blocks,
            sean o no challenge blocks.
CLASE:      regla de consenso
ARCHIVO:    block_header_validation.py:924-927
CÓDIGO:     `if header_block.weight != prev_b.weight + expected_vs.difficulty:`
PARA ZEROX: el peso es conteo de bloques × dificultad, no una función de la calidad de la prueba.
            Chocaría con el peso de ZEROX `floor(2^128/(rango+1))`, que sí es por calidad.
CONFIANZA:  alta
```

Y las recompensas de los bloques no-transaction se emiten como monedas en el **siguiente** transaction block: `block_body_validation.py:308-326` recorre hacia atrás `while not curr_b.is_transaction_block` y añade `pool_coin` + `farmer_coin` de cada uno. Ningún bloque pierde recompensa por no llevar transacciones. **REGLA DE CONSENSO** (`Err.INVALID_REWARD_COINS`, `:335-339`).

Retención selectiva y fork choice: retener un bloque cuesta a su rama 1×`difficulty` y le regala esa ventaja a la rival. No hay ninguna regla que obligue a incluir un bloque conocido — el greenpaper §1.5 (p. 11) lo admite: *«a malicious timelord controlling the fastest VDF could simply skip infusing any blocks they want»*, y remata que las reglas de granjeros y timelords *«are more of a social convention rather than a specification of the chain»*. Censurar bloques es posible y no es detectable como invalidez; solo cuesta peso. La única cota dura es `MAX_SUB_SLOT_BLOCKS` (`block_header_validation.py:471-480`, valor 128; el greenpaper *Design Choice 4* dice 64 — **divergencia paper/código en el valor**).

---

### 6 · Timelord árbitro (Chia) vs. entropía cada N bloques (Autonomys)

La diferencia es de **qué atestigua el VDF**, y es la respuesta central a la pregunta del hilo:

- **Chia:** hay dos cadenas VDF paralelas. El **RC infunde cada bloque** (`full_block_to_block_record.py:153` + `block_header_validation.py:955`): la salida del RC a profundidad *d* depende de todos los bloques infundidos antes de *d*. El RC es a la vez reloj **y prueba de precedencia**: aceptar el RC es aceptar el orden. El **CC casi no infunde nada** (§1), y por eso los desafíos son ungrindeables. La linealización la hace el VDF, no el grafo de padres.
- **Autonomys/ZEROX:** un solo flujo de PoT que recibe entropía cada 50 bloques. El PoT es **solo reloj**: no atestigua la existencia ni la precedencia de ningún bloque salvo los inyectores. El único orden disponible es el puntero al padre.

Consecuencia directa: la capacidad de Chia para tener «muchos bloques por desafío sin ambigüedad de orden» **no viene de su estructura de bloques**, viene de que el timelord encadena cada bloque en el RC. Un diseño que quiera bloques paralelos *sin* infundirlos todos en el VDF no hereda esa propiedad de Chia. Y a la inversa: el mecanismo de Chia que **sí** es trasplantable sin timelord-por-bloque es el orden por `required_iters`/`total_iters` (§4), que es puramente por contenido.

Segunda consecuencia, relevante para la auditoría D9: en Chia el punto de inyección al CC está a **≥16 bloques + 1 frontera de slot** de profundidad, y el valor inyectado se retrasa además con un VDF hasta el final del slot (greenpaper p. 33-34, `t = cc_ip_i,0.D − rc_ip(β).D`) — o sea, la entropía se revela lo más tarde posible **pero se compromete lo antes posible**. Ese es justo el par de exigencias que el informe de ZEROX declaró irreconciliable a profundidad de finalidad (§0 de `dag-poas-auditoria.md`): Chia lo resuelve poniendo la profundidad en **16 bloques**, no en la finalidad, y pagando el precio con el factor 1,47.

---

```
YA EN RUST:   chia_rs 0.48.0 (665176a) — chia-protocol: BlockRecord (`block_record.rs`, con
              `is_challenge_block`, `sp_iters_impl`), slots.rs (ChallengeBlockInfo,
              ChallengeChainSubSlot, InfusedChallengeChainSubSlot, RewardChainSubSlot),
              foliage.rs, sub_epoch_summary.rs. Toda la ESTRUCTURA de bloque ya es Rust,
              Apache-2.0. La lógica de validación de cabecera sigue en Python
              (`consensus/block_header_validation.py`, 1120 líneas) — eso NO está portado.

LASTRE:       · `HARD_FORK2_HEIGHT` y todo el condicionado por altura (`get_block_challenge.py:227-255`,
                `post_hard_fork2`), `FILTER_WINDOW_SIZE`, `calculate_base_plot_filter_bits` /
                `strength_v2` (`pot_iterations.py:106-115`): compatibilidad con plots v1/v2 y con
                cadena vieja.
              · `normalized_to_identity` en las pruebas VDF (doble camino de verificación en
                `block_header_validation.py:983-999`): optimización de sus timelords.
              · `MAX_SUB_SLOT_BLOCKS=128` vs. 64 del paper: parámetro heredado sin justificación
                en el código.
              · `pool_public_key` / `pool_contract_puzzle_hash` (dos esquemas de pool coexistiendo,
                `:791-808`).
              · `skip_overflow_last_ss_validation`: complejidad que existe solo porque los overflow
                cruzan el borde de slot.

CHOCA CON:    1. Peso. Chia: `weight = prev + difficulty`, todos los bloques igual
                (`block_header_validation.py:925`). ZEROX: `floor(2^128/(rango+1))`, por calidad.
                Son modelos distintos; el 1,47 de [BDK+19] está calculado sobre CONTEO de bloques,
                no sobre peso por calidad (ya señalado en el veredicto A7 de D9).
              2. Slot. Chia: sub-slot = 600 s con 64 signage points y 32 bloques esperados
                (`default_constants.py:38,17,14`). ZEROX: slot = 1 s, un desafío por slot. El
                «sub-slot» de Chia es el análogo de la ÉPOCA de inyección de ZEROX (50 bloques),
                no del slot. Comparar «16 bloques por desafío» con «50 bloques por inyección»
                exige mapear sub-slot↔época, no slot↔slot.
              3. Puntero al padre no firmado y decidido en la infusión (`foliage.rs:41-45`,
                `block_creation.py:518`). ZEROX firma la cabecera entera con un sello de 64 B y
                un solo `prev_hash` (SPEC §6.1). Adoptar la ventana 3-4 SP implicaría dejar el
                padre fuera de la firma, lo que a su vez afecta a la identidad del billete.
              4. Un solo transaction block por ventana ⇒ el 64 % de los bloques no llevan cuerpo
                y sus recompensas se emiten diferidas (`block_body_validation.py:308-326`).
                Choca con C-HDR-08 / dirección de recompensa en la solución.

LAGUNAS:      · No hay ninguna discusión en Chia (issues/PRs/greenpaper) sobre foliage como DAG,
                uncles o inclusión de bloques en conflicto. Busqué en el clon y en docs.chia.net;
                no encontré nada. NO LO SÉ si existe en el foro o en Keybase.
              · El greenpaper deja un `XXX` literal sin rellenar en Objective 2 (p. 34-35): la
                ventana desplazada para el recalibrado del parámetro de tiempo. El valor real
                hay que leerlo en `difficulty_adjustment.py`; no lo verifiqué en esta pasada.
              · No verifiqué si existe alguna regla que impida a un timelord infundir un bloque
                cuyo SP es muy antiguo (equivalente a «slot(B) > slot(p)»). El binding vía
                RC-SP-VDF lo hace estructuralmente imposible, pero no encontré un check explícito.
                Confianza media.
              · Reglas de selección de cadena del timelord: son código de `chia/timelord/`, no de
                `consensus/`, y el greenpaper las declara convención social (p. 12). No las auditté.
```

**Fuentes web citadas:** [Multiple Blocks — Chia Docs](https://docs.chia.net/consensus-multiple-blocks/), [Signage and Infusion Points — Chia Docs](https://docs.chia.net/chia-blockchain/consensus/chains/signage-and-infusion-points/)

---

### C · Autonomys (zx-autonomys, Opus)

He leído `dag-poas-auditoria.md` §0-§0.4 y P-038/P-039. Informe abajo. Clon `subspace @ f8842d0` (rama `main`, 2026-08-18); clon superficial (392 commits), así que la historia anterior la saqué por `gh api`.

---

# Inyección de entropía y votos en Autonomys — grados de libertad del PoT

## 1 · Razón de ser de la inyección: hay justificación escrita, y es doble

**AFIRMACIÓN:** la inyección cumple *dos* funciones distintas, documentadas y separadas por su propio equipo de investigación.
**CLASE:** regla de consenso (el efecto) · justificación en foro/docs (la razón).

La fuente primaria es el foro. Chen_Feng (investigador de Autonomys), *A new perspective on PoT*, 2023-08-21 ([forum.autonomys.xyz/t/a-new-perspective-on-pot/1615](https://forum.autonomys.xyz/t/a-new-perspective-on-pot/1615) #1):

> «our PoT mechanism is a bit involved to understand mostly because it **couples two roles**, namely, **c-correlation** (to mitigate nothing-at-stake attacks) and a **weaker version of VDF** (to mitigate long-range attacks)»

y las tres propiedades que esperan probar: crecimiento honesto ≥ λ_h/(1+λ_hΔ), **crecimiento del árbol privado ≤ φ_c·λ_a**, e imposibilidad de «go back in time». El paper de c-correlación es **arXiv 1910.02218** (BDK+19) — el mismo del que D9 sacó `φ₅₀ = 1,2815`. El de referencia del esquema es POSAT, arXiv 2010.08154.

Es decir: la respuesta a tu pregunta es **(a) primero**, pero no como «impedir precomputar desafíos lejanos» sino como **acotar el double dipping / simulación sin coste** (nothing-at-stake). Y **(b) está documentado como consecuencia, no como objetivo de diseño**: dariolina en issue #2141 (2023-10-25) responde a «un timelord más rápido gana»:

> «the speed gains are not cumulative: there is **entropy injection every ~5 min that resets their advantage**»

y nazar-pc en #2193 (2023-11-02): «This is partially mitigated by entropy injection, so they **can't create proofs infinitely into the future**». Ambos issues se cerraron como **riesgo inherente aceptado**, no resuelto. La doc oficial lo recoge (academy.autonomys.xyz, `llms-full.txt` líneas 1064, 1069-1070): «Speed gains are not cumulative… the attacker's advantage is reset»; «Attackers can only predict slot challenges in advance if they have a faster timekeeper, and **even then, they only last until the next injection**»; y bias-resistance estilo **Ouroboros Praos**.

Hay una cuarta razón, y es la que más importa para el largo plazo: **atar la cadena de bloques a la cadena de tiempo** para que un ataque de largo alcance tenga que reevaluar el VDF (Barak, *On the construction of the timechain: blockchain injection*, 2023-08-27, [forum 1639](https://forum.autonomys.xyz/t/on-the-construction-of-the-timechain-blockchain-injection/1639)). Ese hilo también decide **qué** se inyecta, y descarta el hash de bloque explícitamente:

> «injecting the block hash gives rise to an issue where an attacker … can **grind on the block content** … resulting in the possibility to run different timechains and choose a favourable one»

Y así está implementado: la entropía **no es el hash del bloque**.

```
ARCHIVO: crates/subspace-verification/src/lib.rs:444-446  (subspace @ f8842d0)
pub fn derive_pot_entropy(chunk: &ScalarBytes, proof_of_time: PotOutput) -> Blake3Hash {
    blake3_hash_list(&[chunk.as_ref(), proof_of_time.as_ref()])
}
```

**PARA ZEROX:** la entropía sale de la *solución* (chunk + salida de PoT), no del cuerpo. Dos bloques hermanos con la misma solución y cuerpos distintos producen **la misma entropía**. Ese es un grado de libertad real: la entropía no es moldeable por transacciones. Confianza: **alta**.

### Los números 50 / 2 / 15

**El único documento que justifica los valores es el PR #1986** (2023-09-21, *Increase injection interval and reduce lookback depth*, cuerpo íntegro):

> «Increasing injection interval *c* to 50 blocks allows us to **tolerate up to 3 % more adversarial storage**. Also, the ratio between injection delay and injection interval becomes much smaller **15/300 vs 15/120** and is closer to original PoSaT paper analysis. Lookback depth is subsequently reduced to 2 intervals instead of 5, **so that it stays 100 blocks, the archiving depth**.»

Tres cosas que ZEROX no sabía:

1. `c = 50` se eligió por el **φ_c** del paper de c-correlación (+3 % de espacio adversario tolerado frente a c=20). Es una magnitud **en bloques**, no en tiempo.
2. La ratio relevante es **retardo/intervalo en tiempo**: 15 s / 300 s. A `T = 120 s` y `c = 50`, ZEROX tendría 15 s / 6000 s — aún más pequeña, sin problema por ese lado.
3. **`lookback_in_blocks = 100` no es arbitrario: es igual a la profundidad de archivado K.** El invariante que mantuvieron al cambiar 20/5 → 50/2 fue exactamente ese producto. Esto responde a P-039: el número a preservar no son «2 intervalos» sino «`interval × depth == K`».

Valores iniciales: 20/20/15 (commit `a4caa927`, 2023-09-06); 20/5/15 tras revisión de dariolina («Looks like a copying typo», PR #1939); 50/2/15 en `6a49b673`.

**LAGUNA:** el valor **15 para `POT_ENTROPY_INJECTION_DELAY` no tiene derivación escrita en ningún sitio**. Lo único que lo acota es un `const_assert` (`crates/subspace-runtime/src/lib.rs:161-165`): debe ser `> BLOCK_AUTHORING_DELAY + 1 = 5` y `< INTERVAL = 50`. Por qué 15 y no 6 o 40: no encontrado en PRs, issues, foro ni docs.

---

## 2 · Qué garantiza cada rezago, y la alternativa que sí se discutió

`pallet-subspace/src/lib.rs:938-981`. Mecánica exacta, confirmada:

- En el bloque `n` múltiplo de 50: se **muestrea** entropía de *este* bloque y se guarda en `PotEntropy[n]`.
- `maybe_entropy_source_block_number = floor(n/50)*50 − 50·2 = n − 100`.
- Se fija `PotEntropy[n−100].target_slot = pre_digest.slot() + 15` — **slot del bloque `n`, no del `n−100`** (`:963-966`).
- El log `PotParametersChange { slot: target_slot, entropy }` se emite en *todos* los bloques del intervalo `[50j, 50j+49]` (`:986-1015`).

**Rezago 1 (100 bloques, contenido):** garantiza que la fuente de entropía está **a profundidad de archivado K**. Ningún reorg que el nodo pueda seguir la cambia: el archivador aborta con error duro si la reorg cruza K (`crates/sc-consensus-subspace/src/archiver.rs:1224-1233`, `"Attempt to switch to a different fork beyond archiving depth, can't do it"`). Clase: **regla de consenso** por su efecto (la entropía entra en el flujo de PoT que todos validan) aunque el mecanismo de defensa sea de implementación.

**Rezago 2 (15 slots sobre `slot(50j)`, momento):** garantiza que la inyección cae **después** de las pruebas futuras ya comprometidas en el bloque padre — el comentario del `const_assert` lo dice: *«or else we may include invalid future proofs in parent block, +1 ensures we do not have unnecessary reorgs that will inevitably happen otherwise»*. Y `INTERVAL > DELAY` garantiza **como mucho una inyección pendiente a la vez** (nazar-pc, PR #1939, 2023-09-11: «it is possible that we have more than one entropy injection known and scheduled at a time, which requires us to expose it in all APIs»).

**La alternativa que preguntas SÍ se discutió y se rechazó.** Es la *Design choice 1* del hilo 1615 #2: entropía del ancestro de altura `mc`, momento de inyección `t_mc + T` — es decir, **slot de la fuente + constante**, exactamente lo que planteas. nazar-pc la rechaza en #3 (2023-08-21):

> «I'm also not sure why would we use $t_{mc} + T$ when $(m+1)c$ is already known (and getting an **edge-case that it might be before the next block, in which case we skip injection completely**).»

Lo implementado es la *Design choice 2* con lookback. Y hay una objeción de su propia gente que sigue **sin cerrar**: dariolina, hilo 1615 #7 (2023-08-22):

> «We guarantee a *sample* every c blocks. However, when we *inject* we are currently **not guaranteed c blocks**. This makes the Lemma 13 and godfather-blocks notion … about the **injection event frequency, not sampling**.»

Es decir: **el propio equipo señaló que la cota φ_c del paper se aplica a la frecuencia de inyección, y su diseño solo garantiza la de muestreo.** No he encontrado respuesta ni PR que lo resuelva. Confianza: **alta** (cita literal), laguna: **abierta**.

---

## 3 · Reorgs del PoT

**AFIRMACIÓN 3.1 — la validez del PoT de un bloque depende SOLO de `past(B)`, nunca de la best chain.** Esto corrige un matiz de §0 del informe D9.

```
ARCHIVO: crates/subspace-service/src/lib.rs:349-383  (extensión PotExtension)
  pot_parameters = client.runtime_api().pot_parameters(parent_hash)
  pot_input = PotNextSlotInput::derive(.., parent_slot, parent_pre_digest.pot_info().proof_of_time(), ..)
  pot_verifier.is_output_valid(pot_input, Slot::from(slot) - parent_slot, ..)
ARCHIVO: crates/sc-consensus-subspace/src/block_import.rs:460-477
  if seed != correct_input_parameters.seed { return Err(InvalidSubspaceJustificationContents) }
  if checkpoints.len() as u64 != (*future_slot - *parent_future_slot) { ... }
```

**Cada bloque transporta en su justificación exactamente los checkpoints de los slots que van desde el slot futuro de su padre hasta el suyo.** El flujo de PoT es una función lineal de la cadena de bloques y viaja con ella. **CLASE: regla de consenso. CONFIANZA: alta.**

**AFIRMACIÓN 3.2 — la dependencia de la best chain está solo en el timekeeper local.**
`crates/sc-proof-of-time/src/source.rs:221` — `if !import_notification.is_new_best { continue; }`. **CLASE: política de nodo** (dos nodos que discrepen no se bifurcan; producen bloques distintos, que luego se resuelven por peso).

**Cuántos slots se recomputan:** ninguno «se recomputa» en el sentido de reprobar el pasado. `PotState::update` (`source/state.rs:118-185`) reposiciona `next_slot_input` al `future_proof_of_time` del nuevo mejor bloque (slot = `slot(B)+4`) y avanza cuanto pueda con checkpoints **ya cacheados** (`state.rs:33-41`). Los slots que el timekeeper debe volver a **evaluar secuencialmente** son `slot_punta_PoT − (slot(nuevo mejor)+4)`, a ~1 s/slot de AES: no puede recuperarse más rápido que el tiempo real salvo que la gossip le dé checkpoints ya verificados. La **verificación** de la rama nueva sí es barata y paralela (`sc-consensus-subspace/src/verifier.rs:305-333`, `into_par_iter`).

**Profundidad mínima de reorg que bifurca el flujo:**

| Qué cambia | Reorg necesaria | En Autonomys (T=6 s) | En ZEROX (T=120 s, σ=1 s) |
|---|---|---|---|
| `target_slot` (momento) | reemplazar el bloque `50j` | ≥ ~3 bloques (15 slots ≈ 2,5 bloques) | **≥ 1 bloque** (15 slots = 0,125 bloques) |
| `entropy` (contenido) | reemplazar el bloque `50j−100` | ≥ 100 bloques = K → el archivador aborta | ≥ K bloques |

**Esto agrava el hallazgo §0.1-3 de D9:** a `T = 120 s`, la inyección surte efecto **antes de que exista el bloque siguiente**, así que cualquier reorg de profundidad 1 sobre el bloque inyector bifurca el flujo de PoT. En Autonomys el bloque inyector tiene ~2 confirmaciones cuando el flujo cambia. **CONFIANZA: alta** (aritmética sobre constantes citadas).

**Ventana con dos flujos válidos:** **no hay regla que la acote.** Ambas ramas son válidas relativas a su propia cadena indefinidamente; solo el peso resuelve (`block_import.rs:741`, `ForkChoiceStrategy::Custom(total_weight > last_best_weight)`). El límite práctico es K vía el archivador. Observación de campo: nazar-pc, [forum 2175](https://forum.autonomys.xyz/t/proof-of-time-chain-reorgs-drop-farmers-out-of-sync-for-1s/2175) (2023-11-17): *«PoT chain reorg never happens during normal operation, it only primarily happens after chain sync»*.

**Tests: NO EXISTEN.** `sc-proof-of-time/src/source/state.rs` no tiene módulo de tests. `verifier/tests.rs` tiene 2 tests (`test_basic`, `parameters_change`), ambos sobre el encadenado aritmético, ninguno sobre reorg. `pallet-subspace/src/tests.rs` tiene 25 tests, **ninguno de inyección de entropía** (17 son de votos, 1 de `set_pot_slot_iterations`). **LAGUNA confirmada por búsqueda exhaustiva.**

---

## 4 · Votos

**AFIRMACIÓN 4.1 — un voto no puede llevar payload de ningún tipo.** `crates/sp-consensus-subspace/src/lib.rs:178-197`: `Vote::V0 { height, parent_hash, slot, solution, proof_of_time, future_proof_of_time }`. Seis campos, ninguno de datos. **CLASE: regla de consenso. CONFIANZA: alta.**

**Qué se valida** (`pallet-subspace/src/lib.rs:1389-1650`, `check_vote`): altura ∈ {n, n−1} (`:1421-1425`); `parent_hash == block_hash(height−1)` (`:1431`); `slot ≤ current_slot` (`:1444`); `slot > parent_slot` (`:1470`); firma de recompensa (`:1476`); commitment de segmento conocido (`:1512`); `history_size` y expiración del sector (`:1519`); solución dentro de `vote_solution_range`; y **`solution_distance > solution_range/2` o `QualityTooHigh`** (`:1550-1553`); PoT del slot válido respecto de `parent_hash` (`:1563-1570`); PoT futuro en `slot+4` (`:1576-1584`).

**AFIRMACIÓN 4.2 — issue/PR #2078 prohibió soluciones de calidad de bloque en votos.** Razón textual (nazar-pc, 2023-10-09):

> «Allowing solutions that are good enough for blocks to be used in votes creates an **incentive issue** where it is beneficial to create votes instead of blocks since they will likely result in vote being **included on both branches in case chain forks** as well as allows votes to be **included in the next block rather than immediately**.»

**PARA ZEROX:** esto es exactamente la razón por la que «votos» no son «bloques de un DAG». Un voto es *deliberadamente* incluible en varias ramas, y por eso no puede valer para bloque. **CONFIANZA: alta.**

**Rango:** `voting_solution_range = solution_range × (EXPECTED_VOTES_PER_BLOCK + 1) = ×10` (`pallet-subspace/src/lib.rs:796-797`; `EXPECTED_VOTES_PER_BLOCK = 9` en `subspace-runtime/src/lib.rs:180`).

**Atadura y forks:** el voto muere con su `parent_hash`. `longevity(2)` en el pool (`:1291`). Puede entrar en el hijo de su padre o en el nieto (altura `n` o `n−1`), nunca más allá.

**Duplicados y equivocación:** clave `(public_key, sector_index, piece_offset, chunk, slot)` (`:1586-1592`) contrastada contra `ParentBlockAuthorInfo`, `CurrentBlockAuthorInfo`, `ParentBlockVoters`, `CurrentBlockVoters`. Misma clave + **misma firma** → `DuplicateVote` (rechazo). Misma clave + **firma distinta** → equivocación: se revoca la recompensa de *todos* los votos y del bloque de ese `public_key` en el bloque actual (`:1633-1657`). Nótese que la clave **no incluye `reward_address`** — consistente con §0.1-5 de D9.

**Recompensa:** 10 % de impuesto al proponente (`ProposerTaxOnVotes = (1, 10)`, `subspace-runtime/src/lib.rs:1000`; aplicación en `pallet-rewards/src/lib.rs:283-293`).

---

## 5 · Historia archivada

**AFIRMACIÓN 5.1 — el archivador exige un orden total lineal, un bloque por altura, sin huecos, y aborta ante forks más profundas que K.**

```
ARCHIVO: crates/sc-consensus-subspace/src/archiver.rs:1210-1218, 1224-1233
  client.block_hash(block_number_to_archive)   // cadena CANÓNICA, por número
  if parent_block_hash != best_archived_block_hash { return Err("Attempt to switch to a
    different fork beyond archiving depth, can't do it") }
ARCHIVO: crates/sc-consensus-subspace/src/archiver.rs:934
  "Archiver is only able to move forward and doesn't support reorgs."
```

**CLASE: detalle de implementación con consecuencia de consenso** — el resultado (`SegmentCommitment` en estado, vía inherente `store_segment_header`) sí es regla de consenso. En una cadena lineal «canónica hasta K» ≡ «`past(B)` truncado a K», así que la dependencia de la best chain es un atajo del cliente, no del protocolo. En un DAG habría que redefinirla.

**Un voto se archiva solo si el bloque canónico que lo incluyó se archiva**, como extrínseco dentro del cuerpo (`encode_block` del `SignedBlock` completo, `archiver.rs:1254`). Un voto nunca incluido no se archiva. **Un bloque paralelo nunca se archiva.**

`history_size` va en la solución y entra en `SectorId::new(public_key.hash(), sector_index, history_size)` (`pallet-subspace/src/lib.rs:1494-1498`); `verify_solution` rechaza `history_size > current_history_size + 1` y sectores expirados (`subspace-verification/src/lib.rs:286-322`). `current_history_size` sale del estado → **`past(B)`**.

---

## 6 · Tabla: de qué depende cada punto del protocolo

| Punto del protocolo | ¿best chain o `past(B)`? | Cita (`subspace @ f8842d0`) |
|---|---|---|
| Validez del PoT de un bloque | **`past(B)`** — semilla, iteraciones y nº de checkpoints derivan del padre | `sc-consensus-subspace/src/block_import.rs:407-421, 460-477` |
| `pot_parameters` (entropía + `target_slot`) | **`past(B)`** — estado del runtime en `parent_hash` | `subspace-service/src/lib.rs:328-347`; `pallet-subspace/src/lib.rs:1157-1205` |
| Muestreo de entropía (bloque `50j`) | **`past(B)`** — `block_number % 50 == 0` en la cadena del bloque | `pallet-subspace/src/lib.rs:948-966` |
| Fuente de entropía (`50j − 100`) | **`past(B)`** — clave en `PotEntropy` del estado del fork | `pallet-subspace/src/lib.rs:942-947` |
| `target_slot = slot(50j) + 15` | **`past(B)`**, pero fijado por el bloque `50j` **de ese fork** | `pallet-subspace/src/lib.rs:963-966` |
| `solution_range` de un bloque | **`past(B)`** — `next_solution_range` del padre | `sc-consensus-subspace/src/block_import.rs:380-395` |
| Validez de un voto (altura, padre, slot) | **`past(B)`** del bloque que lo incluye | `pallet-subspace/src/lib.rs:1421-1470` |
| Equivocación / duplicado de voto | **`past(B)`**, ventana de 2 bloques | `pallet-subspace/src/lib.rs:1586-1620` |
| Recompensas de votos | **`past(B)`** | `pallet-subspace/src/lib.rs:1766-1778` |
| `history_size` / expiración de sector | **`past(B)`** (`current_history_size` del estado) | `subspace-verification/src/lib.rs:286-322` |
| Elección de rama (peso) | **best chain** por definición | `sc-consensus-subspace/src/block_import.rs:728-743` |
| Flujo de PoT que el timekeeper evalúa | **best chain** (política de nodo) | `sc-proof-of-time/src/source.rs:221, 355-396` |
| Descarte de soluciones tras reorg de PoT | **best chain** (política de nodo) | `sc-consensus-subspace/src/slot_worker.rs:11-12, 233-238` |
| Qué bloque se archiva a profundidad K | **best chain** (atajo del cliente; ≡ `past(B)|K` en cadena) | `archiver.rs:1210-1233` |
| Verificación completa vs muestreada del PoT | **best chain** (política, solo en sync profundo) | `sc-consensus-subspace/src/verifier.rs:178-197` |
| Validación de votos en el pool (`validate_unsigned`) | **best chain** (estado del mejor bloque) | `pallet-subspace/src/lib.rs:1318-1345` |

---

```
ADOPTABLE: nada nuevo de código en esta ronda. Lo adoptable es la INVARIANTE
           "interval × lookback_depth == K (profundidad de archivado)" (PR #1986),
           que P-039 no tenía, y "entropía = blake3(chunk ‖ pot_output)", no el hash
           del bloque (no moldeable por transacciones).

ARRASTRA:  la mecánica de inyección vive en pallet-subspace (Substrate, mapa
           PotEntropy en estado + DigestItem). Reimplementarla en ZEROX sin
           Substrate es directo: es un mapa altura→(entropía, target_slot) y un
           campo de cabecera. No arrastra nightly.

CHOCA CON: (1) DECISIONES §21 hereda 50/2/15 como "calibradas". PR #1986 dice que
           lo calibrado es "lookback en bloques = K" y "delay/intervalo pequeño EN
           TIEMPO". ZEROX debe fijar lookback = su K, no "2 intervalos".
           (2) A T = 120 s, slot(50j)+15 cae ANTES del bloque siguiente: una reorg
           de profundidad 1 sobre el bloque inyector bifurca el flujo de PoT. En
           Autonomys hacen falta ~3. Empeora C-REORG-* y el §0.1-3 de D9.
           (3) El coste de verificar PoT no es simétrico: con justificación es
           paralelo y barato; sin ella (is_output_valid, do_proving=true) es AES
           SECUENCIAL por slot. C-NET-03/C-NET-04 debe distinguir los dos caminos.

LAGUNAS:   · Por qué DELAY = 15 exactamente: sin derivación escrita en ningún sitio.
           · La objeción de dariolina (forum 1615 #7, 2023-08-22): la cota φ_c del
             Lema 13 se aplica a la frecuencia de INYECCIÓN, y el diseño solo
             garantiza la de MUESTREO. Sin respuesta ni PR que lo cierre.
           · Cero tests de inyección de entropía y cero tests de reorg de PoT en
             todo el monorepo (verificado por búsqueda exhaustiva).
           · El paper Dilithium (github.com/subspace/consensus-v2-research-paper,
             main.tex, 1037 líneas) NO trata la inyección de entropía: es sobre
             PoAS. La justificación solo existe en foro, issues, PRs y academy.
           · No encontré ninguna spec del protocolo publicada; el PR #1841 la cita
             ("as described in the spec") pero es interna (Slack/Notion).
```

---

### D · Implementaciones desacopladas (zx-implementaciones, Opus)

He leído el contexto (`/home/katana/zeo/ZEROX/research/dag-poas-auditoria.md` §0-§0.4) y los clones ya presentes en el scratchpad. Informe.

---

# Protocolos desacoplados: qué es lineal, qué es paralelo, cómo se ordena

## 1 · Prism (prism-rust)

```
AFIRMACIÓN: Un solo puzzle PoW; el tipo de bloque (proposer / transaction / uno de m voter)
            sale del rango en que cae el hash de la cabecera, no de una elección del minero.
REPO:       yangl1996/prism-rust @ cdd913aa4a6292a5677d654492edb7487816177e (2021-04-17)
ARCHIVO:    src/config.rs:118-136
CÓDIGO:     pub fn sortition_hash(&self, hash: &H256, difficulty: &H256) -> Option<u16> {
                let multiplier = difficulty / self.total_sortition_width;
                let proposer_width = multiplier * self.proposer_sortition_width;
                let transaction_width =
                    multiplier * (self.proposer_sortition_width + self.tx_sortition_width);
                if hash < proposer_width { Some(PROPOSER_INDEX) }
                else if hash < (transaction_width + proposer_width) { Some(TRANSACTION_INDEX) }
                else if hash < difficulty {
                    let voter_idx = (hash - proposer_width - transaction_width)
                                    % self.voter_chains.into();
                    Some(voter_idx.as_u32() as u16 + FIRST_VOTER_INDEX)
                } else { None }
            }
TESTS:      Ninguno. `src/config.rs` no tiene módulo de test.
CONFIANZA:  alta
```

**Desviación medida en ese fragmento**: `transaction_width` ya incluye `proposer_sortition_width`, y la comparación le vuelve a sumar `proposer_width`. Los tres rangos reales son `[0,P)`, `[P, 2P+T)`, `[2P+T, D)`. La franja de transaction blocks se lleva `P` de probabilidad de más y las voter chains la pierden. El paper (`prism.txt:42-47`, Algoritmo 1) define voter primero y sin solapamiento. Minero y validador llaman a la misma función (`src/validation/mod.rs:62` y `:80`), así que no rompe consenso: solo desvía las tasas. Con los valores por defecto (`src/main.rs:53-58`: `m=1000`, proposer 0.1 b/s, voter 0.1 b/s, tx 80 000 tx/s) `P/D ≈ 3,2·10⁻⁴`, así que el sesgo es pequeño pero real.

```
AFIRMACIÓN: El líder de cada nivel del árbol proposer se elige por cota inferior de confianza
            (LCB) sobre los votos, con aproximación gaussiana, y solo si >3/5 de las cadenas
            votantes ya votaron y ningún rival puede alcanzarlo con los votos que faltan.
REPO:       yangl1996/prism-rust @ cdd913aa
ARCHIVO:    src/blockchain/mod.rs:659-802
CÓDIGO:     if total_vote_count > self.config.voter_chains * 3 / 5 {
                let avg_vote_blocks = total_vote_blocks as f32 / f32::from(total_vote_count);
                let adversary_expected_vote_depth =
                    avg_vote_blocks / (1.0 - self.config.adversary_ratio) * self.config.adversary_ratio;
                let poisson = Poisson::new(f64::from(adversary_expected_vote_depth)).unwrap();
                ...
                    let mut p: f32 = 1.0 - poisson.cdf((*depth as f32 + 1.0).into()) as f32;
                    for k in 0..(*depth as u64) {
                        let p1 = poisson.pmf(k) as f32;
                        let p2 = (self.config.adversary_ratio / (1.0 - self.config.adversary_ratio))
                                 .powi((depth - k + 1) as i32);
                        p += p1 * p2;
                    }
                ...
                let remaining_votes = f32::from(self.config.voter_chains) - total_votes_lcb;
                if max_vote_lcb <= remaining_votes || new_leader.is_none() { new_leader = None; }
TESTS:      NINGUNO ACTIVO. Todo `mod tests` de blockchain/mod.rs (líneas 1658-2052) está
            comentado con /* ... */ (ver src/blockchain/mod.rs:1658 y la última línea del fichero).
            Lo mismo en src/blockdb/mod.rs:253. Sólo hay tests vivos en crypto/hash.rs,
            crypto/merkle.rs, block/{proposer,voter,transaction}.rs, miner/memory_pool.rs.
            src/utxodb/mod.rs:195 y src/wallet/mod.rs:239 declaran `mod test {}` VACÍO.
CONFIANZA:  alta
```

Hay dos umbrales: `quantile_epsilon_confirm` (con `DECONFIRM_HEADROOM = 1.05`) para confirmar y `quantile_epsilon_deconfirm` para desconfirmar (`src/config.rs:7, 89-95`; uso en `blockchain/mod.rs:528-539`). Es histéresis explícita contra el flapping del líder.

```
AFIRMACIÓN: El orden final de transacciones es DFS inverso sobre las referencias del líder de
            cada nivel, deduplicado por "primera aparición", y luego expansión a los tx blocks.
REPO:       yangl1996/prism-rust @ cdd913aa
ARCHIVO:    src/blockchain/mod.rs:601-652
CÓDIGO:     let mut stack: Vec<H256> = vec![leader];
            while let Some(top) = stack.pop() {
                if !unconfirmed_proposers.contains(&top) { continue; }
                let refs: Vec<H256> = get_value!(proposer_ref_neighbor_cf, top).unwrap();
                order.push(top);
                for ref_hash in &refs { stack.push(*ref_hash); }
            }
            order.reverse();
            order = order.into_iter().filter(|h| unconfirmed_proposers.remove(h)).collect();
            put_value!(proposer_ledger_order_cf, level as u64, order);
            ...
            for block in &added {
                let t: Vec<H256> = get_value!(transaction_ref_neighbor_cf, block).unwrap();
                added_transaction_blocks.extend(&t);
            }
TESTS:      Comentados (ver arriba).
CONFIANZA:  alta
```

El padre proposer es la **primera** referencia (`insert_block`, `mod.rs:278-280`: `let mut refed_proposer: Vec<H256> = vec![parent_hash]; refed_proposer.extend(&content.proposer_refs);`), lo que fija el orden dentro de un nivel.

**Nota**: la deduplicación es de bloques *proposer* (`unconfirmed_proposers`), no de bloques *transaction*. Dos proposer distintos que referencien el mismo tx block lo meten dos veces en `added_transaction_blocks`. El paper dice explícitamente "remove all the duplicate and double-spent transactions" (`prism.txt:715-717`). Confianza media en que sea un fallo y no un caso imposible: `unreferred_transactions.remove()` (`mod.rs:336-340`) sólo disciplina al minero honesto.

```
AFIRMACIÓN: El conflicto entre transacciones se resuelve por el orden total: la segunda copia
            es un no-op silencioso porque su input ya no está en el UTXO.
REPO:       yangl1996/prism-rust @ cdd913aa
ARCHIVO:    src/utxodb/mod.rs:91-105
CÓDIGO:     for input in &t.input {
                let id_ser = serialize(&input.coin).unwrap();
                match self.db.get_pinned(&id_ser)? {
                    Some(d) => { ... if coin_data.value != input.value { return Ok((vec![], vec![])); } }
                    None => return Ok((vec![], vec![])),
                }
TESTS:      src/utxodb/mod.rs:195 → `mod test {}` vacío.
CONFIANZA:  alta
```

El `LedgerManager` aplica ese orden con un *scoreboard* de hashes calientes para paralelizar sin hazards RAW/WAR/WAW (`src/ledger_manager/mod.rs:50-141`).

**Qué necesita del estado global un bloque paralelo al crearse.** Un *transaction block* necesita solo el mempool y un padre proposer (`miner/mod.rs:264-275`). Un *voter block* necesita mucho más: `unvoted_proposer(voter_parent, proposer_parent)` recorre todos los niveles proposer desde el último votado y elige, por nivel, el bloque con más votos, desempatando por hash menor (`blockchain/mod.rs:953-984`). La validez exige **exactamente un voto por nivel**, contiguo:

```
ARCHIVO:  src/validation/voter_block.rs:40-58
CÓDIGO:   let mut start = blockchain.deepest_voted_level(&content.voter_parent).unwrap();
          let end = blockchain.proposer_level(parent).unwrap();
          if start > end { return false; }
          if content.votes.len() != (end - start) as usize { return false; }
          for vote in content.votes.iter() {
              start += 1;
              if start != blockchain.proposer_level(vote).unwrap() { return false; }
          }
```

Divergencia con el paper: el paper dice votar "the first one it received" (`prism.txt:645-646`), la implementación vota el más votado con desempate por hash. La regla del paper no es determinista entre nodos; la del código sí.

**Todos los bloques cuestan lo mismo.** La cabecera es única (`src/block/header.rs`) y sólo tiene **un** `parent` (el proposer); el `voter_parent` va en el contenido (`src/block/voter.rs`). El paper describe un Merkle de `m+2` padres (`prism.txt:648-651`); la implementación no lo hace.

## 2 · OHIE

```
AFIRMACIÓN: La cadena a la que va un bloque sale de los últimos bits del hash mod k; el bloque
            se compromete a las k puntas mediante un Merkle root y publica una prueba para la suya.
REPO:       ivicanikolicsg/OHIE @ e8c45556e19bbd82f159194990fb01ff03c07dfa (2019-05-06)
ARCHIVO:    code/verify.cpp:62-65 y code/miner.cpp:64-131
CÓDIGO:     uint32_t get_chain_id_from_hash( string h) {
                return stoi ( h.substr(58) ,nullptr,16) % CHAINS;
            }
            ---
            for( int i=0; i<CHAINS; i++){
                block *b = bc->get_deepest_child_by_chain_id( i );
                if ( b->nb->next_rank > trailing_block->nb->next_rank ){
                    trailing_block = b; trailing_id = i;
                }
                leaves.push_back( blockhash_to_string( b->hash ) );
            }
            string merkle_root_chains = compute_merkle_tree_root( leaves );
            uint32_t chain_id = get_chain_id_from_hash(h);
            vector <string> proof_new_chain = compute_merkle_proof( leaves, chain_id );
TESTS:      code/quick_test.sh (arranca 3 nodos locales; no verifica invariantes).
            No hay suite de tests unitarios ni vectores.
CONFIANZA:  alta
```

**Consecuencia dura para un diseño tipo ZEROX**: para minar UN bloque hay que conocer las **k puntas** y el *trailing block* global. El estado que un bloque paralelo necesita es el estado completo, no local.

```
AFIRMACIÓN: El orden global es (rank, chain_id); rank = next_rank del padre; next_rank hereda
            del bloque con MAYOR next_rank de todo el sistema, forzado a crecer al menos 1.
REPO:       OHIE @ e8c45556
ARCHIVO:    code/miner.cpp:133-135
CÓDIGO:     nb.rank      = parent->nb->next_rank ;
            nb.next_rank = trailing_block->nb->next_rank;
            if (nb.next_rank <= nb.rank ) nb.next_rank = nb.rank + 1;
TESTS:      ninguno
CONFIANZA:  alta
```

Coincide con el pseudocódigo del paper (`ohie.txt:611-614`, líneas 48-51) y con la definición de *trailing* como "the block with the largest next rank value, among all blocks in ∪Vⱼ" (`ohie.txt:676`).

```
AFIRMACIÓN: La confirmación total es una barrera: confirm_bar = min sobre las k cadenas del
            next_rank del último bloque parcialmente confirmado (punta menos T bloques).
REPO:       OHIE @ e8c45556
ARCHIVO:    code/Blockchain.cpp:927-987
CÓDIGO:     uint32_t confirm_bar = -1;
            for( int i=0; i<CHAINS; i++){
                block *t = deepest[i]; int count = 0;
                while( NULL != t && count++ < T_DISCARD[j] ) t = t->parent;
                ...
                if ( t->nb->next_rank < confirm_bar ) confirm_bar = t->nb->next_rank;
            }
            ...
            if ( t->is_full_block && ... && t->nb->next_rank < confirm_bar && ...)
TESTS:      ninguno
CONFIANZA:  alta
```

**Dos divergencias del prototipo respecto del paper**, ambas verificadas:

1. El paper confirma con `B̂.rank < confirm_bar` (`ohie.txt:638`, línea 73). El código usa `t->nb->next_rank < confirm_bar` (`Blockchain.cpp:971`). Es una condición estrictamente más conservadora, pero no es la del paper.
2. El paper obliga al receptor a **recomputar** rank y next_rank (líneas 49-51). El prototipo los **deserializa del mensaje del emisor** sin recomputar: `requests.cpp:94-95` (`nb.rank = safe_stoi(sp[8], pr); nb.next_rank = safe_stoi(sp[9], pr);`), y `grep -n rank code/process_buffer.cpp` no devuelve nada. Un nodo malicioso puede declarar cualquier rank.

Además **no hay PoW**: el minado es `sha256(merkle_root_chains + merkle_root_txs)` con `merkle_root_txs = to_string(rng())` y un `exponential_distribution` para el tiempo (`miner.cpp:96-103`, `:183`). Y no hay UTXO ni detección de doble gasto: `transactions.cpp:83-99` sólo verifica una firma ECDSA sobre bytes arbitrarios. **El prototipo de OHIE es un banco de pruebas de red, no una implementación de consenso.** Los números del paper (2 420 tx/s a 20 Mbps, factor de descentralización 61,8, `T = 20..30`, 1-5 min a confirmación parcial y 2-4 min más a total: `ohie.txt:1239-1279`) son de ese banco de pruebas.

## 3 · Parallel Chains (Fitzi et al., ePrint 2018/1119)

```
AFIRMACIÓN: LAGUNA — no hay implementación pública. Sí hay pseudocódigo detallado, y el diseño
            PoW es literalmente "una lineal + m-1 paralelas": C1 es la cadena de sincronización.
REPO:       —  (paper ePrint 2018/1119, v. 30-nov-2018)
ARCHIVO:    parallel-chains.txt:1051-1069 (extensión y actualización de cadenas), :1085-1112
            (estabilización y orden), Figs. 6-9
CÓDIGO:     [orden] rk(B) = |{ B̄ ∈ C_ch(B) | σ(B̄) = σ(B) ∧ B̄ ≺_G B }|
            B ≺_β B̄  ⇔  (σ(B) ≺_G σ(B̄)) ∨
                        (σ(B) = σ(B̄) ∧ rk(B) < rk(B̄)) ∨
                        (σ(B) = σ(B̄) ∧ rk(B) = rk(B̄) ∧ ch(B) < ch(B̄))
            [estabilidad] ψ1(B1) ≜ B1 ∈ C1^⌈k ∧ ∀j∈{2..m} ∃Bj ∈ Cj^⌈k : B1 ≺_G Bj
                          ψ2(Bc) ≜ Bc ∈ C^⌈k \ C1 ∧ ∃B1 ∈ C1 : σ(Bc) ≺_G B1 ∧ ψ1(B1)
            [anclaje]  aux_c incluye ⟨r_c, x_c, c, s⟩ con s = π(head(C1)); validez exige s ≤ len(C1)
                       y ∀B,B̄ ∈ Cc : B ≺_G B̄ ⇒ σ(B) ≼_G σ(B̄)
TESTS:      no existen
CONFIANZA:  alta sobre el contenido del paper; alta sobre la inexistencia de código (búsqueda
            web sin resultado; el paper es de IOHK Research y no publica repositorio)
```

Puntos que importan aquí: (a) el conflicto se evita **a priori** por *sharding* determinista de transacciones — `x_c` sólo puede contener `tx` con `chain(tx) = c` (`:1069`, `:1064-1066`); (b) el PoW es `m-for-1` con un PRG o una cadena de hashes de longitud `m`, y el minero debe **probar que computó la cadena entera** (`H^m(B)` en el `aux`) porque si no *"the adversary could bias mining towards chains with small index"* (`:1036-1038`). Ese requisito es exactamente "el bloque tuvo que costar algo, y costar en todas las cadenas a la vez".

## 4 · Chia (chia-blockchain 2.7.4-rc2+16 / chia_rs 0.48.0)

Chia **no tiene paralelismo estructural**. Tiene una sola cadena de bloques y desacopla *en el tiempo*: sólo algunos bloques llevan transacciones.

```
AFIRMACIÓN: is_transaction_block no lo elige el granjero: es "el primer bloque cuyo signage point
            supera el total_iters del último bloque de transacciones de su ancestría".
REPO:       Chia-Network/chia-blockchain @ f87270c0275904981366651a59a0618aea5144ce (tag 2.7.4-rc2-16)
ARCHIVO:    chia/consensus/prev_transaction_block.py:9-17
CÓDIGO:     while not curr.is_transaction_block:
                curr = blocks.block_record(curr.prev_hash)
            is_transaction_block = total_iters_sp > curr.total_iters
            return is_transaction_block, curr
TESTS:      chia/_tests/blockchain/test_blockchain.py:1568-1590 (test_foliage_data_presence)
CONFIANZA:  alta
```

La regla de consenso equivalente, en el validador de cabeceras, corrige el caso *overflow*:

```
ARCHIVO: chia/consensus/block_header_validation.py:723-734
CÓDIGO:  # 15. Check is_transaction_block
         curr = prev_b
         while not curr.is_transaction_block: curr = blocks.block_record(curr.prev_hash)
         if overflow:
             our_sp_total_iters = uint128(total_iters - ip_iters + sp_iters - expected_vs.ssi)
         else:
             our_sp_total_iters = uint128(total_iters - ip_iters + sp_iters)
         if (our_sp_total_iters > curr.total_iters) != (
                 header_block.foliage.foliage_transaction_block_hash is not None):
             return None, ValidationError(Err.INVALID_IS_TRANSACTION_BLOCK)
```

**Qué valida un bloque no-transaccional**: nada de cuerpo. `block_body_validation.py:232-259` — si `foliage_transaction_block_hash is None`, exige `foliage_transaction_block`, `transactions_info`, el generador y `transactions_generator_ref_list` vacíos (`Err.NOT_BLOCK_BUT_HAS_DATA`), `conds is None`, y retorna. Tests: `test_blockchain.py:2409-2438` (`test_not_tx_block_but_has_data`).

**Qué valida uno transaccional**: los 22 chequeos de `block_body_validation.py:263-583`, todos anclados a `prev_transaction_block_height`, que se obtiene de `block.foliage_transaction_block.prev_transaction_block_hash` (`:284-286`).

```
AFIRMACIÓN: El orden entre bloques de transacción lo fija prev_transaction_block_hash, y se
            valida que apunte al ancestro transaccional más reciente, con timestamp estrictamente creciente.
ARCHIVO:    chia/consensus/block_header_validation.py:834-859
CÓDIGO:     curr_b: BlockRecord = prev_b
            while not curr_b.is_transaction_block:
                curr_b = blocks.block_record(curr_b.prev_hash)
            if not header_block.foliage_transaction_block.prev_transaction_block_hash == curr_b.header_hash:
                return None, ValidationError(Err.INVALID_PREV_BLOCK_HASH)
            ...
            if header_block.foliage_transaction_block.timestamp <= prev_transaction_b.timestamp:
                return None, ValidationError(Err.TIMESTAMP_TOO_FAR_IN_PAST)
TESTS:      test_blockchain.py:190, 548, 1630, 1651, 1775
CONFIANZA:  alta
```

Los dos hechos de diseño más relevantes para ZEROX:

```
AFIRMACIÓN: El desafío de PoS nunca depende del contenido transaccional: sale de los hashes de
            sub-slot de la challenge chain. El foliage lleva el prev_block_hash y es reemplazable.
ARCHIVO:    chia/consensus/get_block_challenge.py:54-102 (ninguna rama toca el foliage);
            chia_rs @ 665176aca5fb0ca480ea6445cbda4e82af2c4e5c, crates/chia-protocol/src/foliage.rs:40-43
CÓDIGO:     // The hash of this is the "header hash". Note that for unfinished blocks, the
            // prev_block_hash Is the prev from the signage point, and can be replaced with a
            // more recent block
            prev_block_hash: Bytes32,
CONFIANZA:  alta
```

```
AFIRMACIÓN: Si un bloque resulta NO ser transaccional al infusionarse, su carga de transacciones
            se descarta; y sus recompensas las reclama el siguiente bloque transaccional.
ARCHIVO:    chia/consensus/block_creation.py:465-487 y :153-190
CÓDIGO:     # Replace things that need to be replaced, since foliage blocks did not necessarily
            # have the latest information
            is_transaction_block, _ = get_prev_transaction_block(prev_block, blocks, total_iters_sp)
            new_weight = uint128(prev_block.weight + difficulty)
            ...
            else:
                new_foliage_transaction_block = None
                new_tx_info = None
                new_generator = None
                new_generator_ref_list = []
            ---
            while not curr.is_transaction_block:
                pool_coin = create_pool_coin(curr.height, curr.pool_puzzle_hash, ...)
                farmer_coin = create_farmer_coin(curr.height, curr.farmer_puzzle_hash, ...)
                reward_claims_incorporated += [pool_coin, farmer_coin]
                curr = blocks.block_record(curr.prev_hash)
CONFIANZA:  alta
```

`new_weight = prev_block.weight + difficulty` se aplica a **todos** los bloques: los no-transaccionales suman peso y cobran. Y el comentario de `get_block_challenge.py:104-106` dice la razón del desacoplamiento en voz alta: *"when the block is farmed we do not know the latest transaction block since a new one might be infused by the time the block is infused"*.

---

## Tabla final

| Protocolo | Parte lineal | Parte paralela | Orden de tx | Conflicto | ¿Los paralelos dan seguridad? | Latencia a confirmación | ¿Usa que el bloque costó? |
|---|---|---|---|---|---|---|---|
| **Prism** (prism-rust @ cdd913aa) | Árbol *proposer* (1 nivel = 1 líder) + m árboles *voter*, cada uno Nakamoto | *Transaction blocks* (capacidad) y los m *voter trees* (seguridad) | DFS inverso desde el líder de cada nivel sobre `proposer_refs`, dedup por primera aparición, luego expansión a tx blocks | Orden total → la 2ª copia es no-op en el UTXO (`utxodb/mod.rs:101`) | **Sí, los voter**: la seguridad ES el agregado de m votos. Los tx blocks solo capacidad | LCB gaussiana sobre votos; exige >3/5 de cadenas votando y que ningún rival alcance con los votos restantes. Cota del paper `c1(β)·D`, ∝ retardo de red | **Sí, críticamente**: el tipo sale del rango del hash. Sin coste por intento el tipo sería moliblе |
| **OHIE** (@ e8c45556) | Ninguna: k cadenas simétricas | Las k cadenas (capacidad **y** seguridad; cada una es Nakamoto) | `(rank, chain_id)`; `rank = parent.next_rank`, `next_rank = max global`, forzado a crecer 1 | El paper lo delega al orden total; **el prototipo no implementa UTXO ni doble gasto** | Sí: cada cadena aporta `1/k` de la tasa; resiliencia `f < 1/2` (Teorema 1) | `T` bloques por cadena (20-30) + esperar `confirm_bar = min_i next_rank_i`. Medido: 1-5 min parcial, +2-4 min total | **Sí** para el `chain_id` (últimos bits del hash). **Pero el prototipo no tiene PoW**: hash directo + tiempo exponencial |
| **Parallel Chains PoW** (2018/1119, sin código) | **C1, cadena de sincronización** | C2..Cm, cada una con su *shard* de transacciones | `σ(B)` (bloque de sincronización) → `rk(B)` dentro del grupo → `ch(B)` | **Se evita a priori**: `chain(tx) = c` obliga a que cada tx viva en una sola cadena | Sí, cada Cc es Nakamoto; pero la **estabilización** de todas pasa por C1 | `k` de profundidad en la propia cadena (confirmación) **+** que C1 esté referenciada por bloque confirmado de **todas** las demás (estabilización) | **Sí, explícitamente**: `m-for-1 PoW` con prueba de haber computado la cadena de hashes completa, para que el adversario no sesgue hacia cadenas concretas |
| **Chia** (2.7.4-rc2+16 / chia_rs 0.48.0) | **Todo**: una sola cadena de bloques; y tres cadenas de VDF (challenge / reward / infused challenge) que son relojes, no capacidad | Ninguna. Desacople **temporal**: bloques tx y no-tx alternan en la misma cadena | `prev_transaction_block_hash` encadena los tx blocks; dentro del bloque, el generador CLVM | No hay bloques paralelos. Un bloque que no acaba siendo tx block **pierde su carga** (`block_creation.py:483-487`) | Los no-tx **sí** suman peso (`prev_block.weight + difficulty`) y cobran vía el siguiente tx block | Nakamoto sobre peso; el desacople no la cambia | **No para el tipo de bloque**: `is_transaction_block` sale de `total_iters` (posición en el VDF), no del hash. Es una propiedad **temporal**, no de coste |

## DIVERGENCIAS

1. **Prism paper vs. prism-rust**: (a) rangos de sortición solapados (el paper: voter→tx→proposer sin solape; el código: proposer→tx con `P` de más→voter); (b) el paper mete `m+2` padres en un Merkle, el código lleva un solo `parent` en la cabecera y el `voter_parent` en el contenido; (c) el paper vota "el primero que vi", el código vota "el más votado, desempate por hash menor" (`blockchain/mod.rs:961-983`) — la regla del paper no converge entre nodos; (d) el paper dedupica transacciones, el código sólo dedupica bloques proposer.
2. **OHIE paper vs. prototipo**: el prototipo no recomputa `rank`/`next_rank` (los lee del mensaje), confirma por `next_rank < confirm_bar` en vez de `rank < confirm_bar`, no tiene PoW y no tiene UTXO.
3. **Dónde se ancla el paralelismo**: OHIE ancla al conjunto **completo** de puntas (Merkle de las k). Parallel Chains ancla a **una** cadena distinguida C1. Prism ancla a un **árbol** proposer con líder por nivel. Chia no ancla nada porque no hay paralelismo.
4. **Origen del "tipo" del bloque**: Prism, OHIE y Parallel Chains lo derivan del **hash del intento de PoW** (necesitan que cada intento cueste). Chia lo deriva del **tiempo del VDF** (`total_iters_sp > curr.total_iters`) y no necesita que el bloque cueste nada para decidirlo.
5. **Modelo de conflicto**: Prism y OHIE = post-hoc por orden total. Parallel Chains = a priori por *sharding* determinista. Chia = imposible por construcción (una sola cadena de tx).

## VECTORES

- **Chia (los únicos vectores ejecutables reales que encontré)**: `/home/katana/zeo/ZEROX/PDF/chia-blockchain/chia/_tests/blockchain/test_blockchain.py` — `test_foliage_data_presence` (:1568), `test_not_tx_block_but_has_data` (:2409), `test_prev_block_hash` (:1630, :1651, :1775), `Err.IS_TRANSACTION_BLOCK_BUT_NO_DATA` (:2482, :2492, :2737). Bloques reales serializados: `/home/katana/zeo/ZEROX/PDF/chia-blockchain/chia/_tests/tools/{300000,442734,466212,1315537,1315544,1315630}.json`. Round-trip de serialización: `chia/_tests/util/test_full_block_utils.py`.
- **Prism**: `/tmp/.../scratchpad/prism-rust/src/crypto/merkle.rs:247-388` (Merkle, activos) y `src/block/{proposer,voter,transaction}.rs` (constructores de prueba). **No hay ningún test del ledger, del líder ni de la sortición.**
- **OHIE**: `/tmp/.../scratchpad/OHIE/code/quick_test.sh` — arranca tres nodos y no comprueba ninguna invariante. No hay vectores.
- **Parallel Chains**: ninguno.

## LAGUNAS

1. **No existe implementación de Parallel Chains (Fitzi et al.)**. Búsqueda web sin resultado; el paper es de IOHK Research y no publica repositorio. Todo lo que reporto de ese protocolo es pseudocódigo del PDF, no código ejecutado.
2. **No compilé ni ejecuté prism-rust ni OHIE.** No verifiqué que el árbol de prism-rust @ cdd913aa compile (el módulo de tests comentado llama a `BlockChain::new` con un argumento cuando la firma actual toma dos, `blockchain/mod.rs:114` — indicio de que quedó atrás).
3. **Prism CCS 2019 no trae evaluación de implementación.** Los números de rendimiento de Prism (los 10 000×) están en el paper de OSDI 2021, que no está en el scratchpad y no leí.
4. **No verifiqué el análisis de seguridad de Prism §5** (sólo §3 y §4.1/§4.5). No puedo afirmar bajo qué supuestos exactos vale la regla LCB implementada.
5. **chia_rs 0.48.0 no contiene la validación de cabeceras.** `grep is_transaction_block` sobre `crates/` sólo devuelve accesores de tipos (`block_record.rs:62`, `fullblock.rs:188`, `header_block.rs:69`). Toda la lógica de consenso de PoSpace/VDF sigue en Python. Si el interés era una referencia en Rust de esa parte, **no existe en chia_rs**.
6. **No medí el sesgo real de la sortición de prism-rust** ejecutándolo; el cálculo `P/D ≈ 3,2·10⁻⁴` es aritmética sobre los valores por defecto de `main.rs`, no una medición.

Sources: [Parallel Chains (ePrint 2018/1119)](https://eprint.iacr.org/2018/1119), [IOHK Research](https://iohk.io/en/research/library/papers/parallel-chainsimproving-throughput-and-latency-of-blockchain-protocols-via-parallel-composition/)

---

### E · Candidatos (zx-d2-consenso, Opus)

He leído todo el material. Respuesta directa a la pregunta de Katana antes de los candidatos.

---

## Tesis: se modifica el DAG, no el PoST

R1+R2+R3 son, juntas, un **teorema de estructura**, no tres requisitos sueltos:

- R1 exige un flujo único de PoT. En Autonomys ese flujo se define por `PotNextSlotInput::derive`, que mezcla entropía **solo si `parameters_change.slot == next_slot`** (`crates/sp-consensus-subspace/src/lib.rs:118-122`, cita literal: *"Only if entropy injection happens exactly on next slot we need to mix it in"*). El flujo depende del **slot de aplicación**, y ese slot lo fija `pre_digest.slot() + delay` del bloque en posición `≡ 0 mod 50` (`pallet-subspace/src/lib.rs:963-969`), es decir, **un bloque en la punta**.
- R2 exige entonces que exista una **posición ordinal estable a 15 slots**. Eso es una propiedad de cadena, no de DAG: es lo que D9 y D8 refutaron (Ataque 1: split honesto sin atacante).
- R3 prohíbe la única mitigación conocida (inyectar desde profundidad de finalidad).

Conclusión de D2: **cualquier estructura no lineal admisible tiene que dejar intacta una espina lineal que sea la única fuente de (a) entropía y slot de inyección del PoT, (b) reajuste, (c) `hash_bloque[altura_ploteo]` de C-EXP-04, (d) archivado.** El paralelismo solo puede vivir en capas que sean *función* de esa espina. Eso no es adaptar el PoST al DAG: es **recortar el DAG** hasta que el PoST no se entere. Los tres precedentes que leí hacen exactamente eso: Chia mantiene cadena lineal y solo marca qué bloques llevan transacciones (`block_header_validation.py:735-744`: `INVALID_IS_TRANSACTION_BLOCK` si `our_sp_total_iters > curr.total_iters` no coincide con llevar `foliage_transaction_block`); Autonomys convierte el billete sobrante en voto anclado a `height−1` (`pallet-subspace/src/lib.rs:1415-1433`); Prism llama a su estructura *"a DAG, but a **structured** DAG"* y su espina (proposer tree) sigue siendo longest-chain.

Los tres candidatos difieren en **qué capa se paraleliza**: payload (A), confirmación (B) o el sorteo mismo (C).

---

## Candidato A · Espina + fardos (payload paralelo, peso cero)

**(1) Lineal / paralelo.** Lineal: la espina, idéntica a hoy (556 B, `prev_hash` único, LWMA-1 sobre slots, q=120). Paralelo: **fardos**, objetos con cabecera propia (misma solución, mismo sello) que llevan transacciones y **no tienen `prev_hash` elegible**: se anclan a un bloque de espina concreto. R1-R3 se satisfacen porque la espina no cambia: el inyector sigue siendo el bloque `50j`, con la misma estabilidad de hoy. **Rezago añadido por el candidato: cero slots.** El rezago total sigue siendo el que decida P-039 (hoy 100 bloques de contenido = 3,3 h a T=120 s, más 15 slots de aplicación), y ese es el rezago máximo que acepto: subirlo hasta finalidad es lo que mata a GHOSTDAG (Baig-Pietrzak; greenpaper §1.1 ec. 2), bajarlo empeora φ (D9: φ₅₀ = 1,2815, umbral 43,8 %).

**(2) Qué es un billete extra.** Los que hoy se tiran: (i) el segundo ganador del mismo slot (0,42 % a σ=1 s, §21), y (ii) **todo el anillo `SR/2 < d ≤ R_F/2`**, hoy descartado. Se copia el mecanismo de Autonomys, verificado: `voting_solution_range = solution_range × (EXPECTED_VOTES_PER_BLOCK + 1)` (`pallet-subspace/src/lib.rs:1089`) y **rechazo explícito del billete de calidad de bloque** — `CheckVoteError::QualityTooHigh` si `solution_distance <= solution_range / 2` (`:1548-1552`). Anillos **disjuntos** ⟹ R4 por construcción: un billete es bloque **o** fardo, nunca los dos.

⚠️ Honestidad: ensanchar el rango **no añade espacio ni seguridad**. Es más muestreo de la misma lotería.

**(3) Orden y conflictos.** Orden total = orden de la espina; dentro de un bloque: coinbase, txs propias, luego los fardos referenciados en el orden literal de la lista, y dentro de cada fardo su orden. Conflicto: **gana la primera aparición en ese orden**; el resto se descarta sin invalidar el bloque (construcción de Prism §5.2.3, *"keeping only the first time a given transaction output is spent"*, que ellos toman de Conflux). Esto sí cambia C-BLK-09, que hoy invalida el bloque entero.

**(4) Peso.** **Solo la espina pesa.** `peso = Σ ⌊2^128/(SR+1)⌋` sobre bloques de espina; los fardos suman **cero**. Un atacante que retiene fardos no gana peso, solo pierde sus propias tarifas. Es la diferencia exacta con Filecoin (arXiv:2308.06955 §3.3: `w(T) = Σ|T_i|` — allí los objetos paralelos **sí** suman, y por eso el umbral cae al ~20 %).

**(5) Qué compra** (σ=1 s, Δ=4 s, 556 B, 1,32 ms/cabecera, 350 B/tx, zona libre 100 KB):

| | hoy | A con F=9 fardos/bloque |
|---|---:|---:|
| Latencia a **inclusión** (objeto respaldado por espacio) | 120 s | **13,3 s** |
| Latencia a **confirmación** (orden final) | sin cambio | **sin cambio** |
| Throughput | 285,7 tx/bloque = 2,38 tx/s | ×(1+F) si se elige ampliar la zona libre; **×1 si no** |
| Cabeceras extra | — | 41,7 B/s = **1,31 GB/año** |
| CPU extra por bloque | — | 9 × 1,32 ms = **11,9 ms** |

Lo que A compra de verdad no es velocidad: es que **10 granjeros distintos cobren por bloque en vez de uno**, dividiendo por 10 la varianza de ingreso del granjero pequeño. Con P-036 (descentralización > velocidad > escalabilidad) eso vale más que el throughput.

**(6) Qué cuesta.** Cambian: C-BLK-01/09 (raíz de Merkle sobre txids **y** ids de fardo; conflicto por primera aparición), C-EMIT (reparto del subsidio), C-WGT (peso del bloque incluye el de sus fardos), C-NET (topic y dedup), §26 (prueba de pago con dos saltos de Merkle). Constantes nuevas **a derivar, no a inventar**: `FACTOR_RANGO_FARDO`, `MAX_FARDOS`, ventana de anclaje `W`, y el reparto del subsidio. Precedente citado, **no adoptado**: Autonomys usa 9 votos esperados y `ProposerTaxOnVotes = (1, 10)` (`subspace-runtime/src/lib.rs:180, 1000`).

Un hallazgo que hace esto barato: **C-EMIT-01 lee `emitido`, no la altura**. Emitir menos en un bloque no rompe nada —el soft cap se conserva y la curva se estira— y C-EMIT-06 ya explota esa propiedad. Luego el subsidio se puede partir entre espina y fardos con el sobrante **no emitido**, sin tocar el cap ni la cola de 32 ZZK.

**(7) Qué se modifica.** El DAG (colapsado a un DAG de profundidad 1 y peso cero en la capa paralela). Del PoST solo se toca **una línea**: la comprobación de rango pasa de `d ≤ SR/2` a la clasificación en dos anillos.

**(8) El ataque que me preocupa: robo de tarifas por el productor de espina.** Si el fardo cobra tarifas de sus txs, el bloque de espina puede **no referenciarlo y copiar sus transacciones**, quedándose con el 100 %. Es el problema de los microbloques de Bitcoin-NG. La única salida que veo es la de Autonomys —pagar al fardo **desde el subsidio**, no desde las tarifas, y dar al productor un impuesto por incluirlo— pero eso hace del reparto un parámetro de incentivos que **no está derivado** y que decide si la capa vive o muere. **No lo tengo cerrado.**

---

## Candidato B · Espina + m ramas de voto (Prism)

**(1)** Lineal: la espina y **cada una de las m ramas de voto** (cada una longest-chain). Paralelo: las ramas entre sí. R1-R3 igual que en A: la espina no cambia.

**(2)** El billete extra se sortea a una rama `i` por una función del propio billete. Bajo PoW Prism exige que el minero no sepa su rol de antemano (*"a block is mined before knowing whether it will become a proposer block or a voter block"*, §5.2.1). Bajo PoST el granjero lo sabe Δ=4 s antes — pero **no puede elegirlo**: `solution_distance` no es molible (D8 lo descartó explícitamente: es función de `global_challenge`, `sector_slot_challenge` y el chunk, sin grado de libertad). Saberlo sin poder moverlo no es lo mismo que elegirlo, pero **la reducción de Prism no cubre este caso** y no la puedo dar por buena.

**(3)** Orden: el de la espina. Los votos no ordenan nada; confirman.

**(4)** Los votos **no suman peso**; producen una cuenta de votos por altura. Retener votos retrasa la confirmación de un bloque honesto: ese es el poder que gana el atacante, y es real.

**(5)** Lo que compra es **latencia a confirmación**, no a inclusión ni throughput. Y aquí está el número que lo hunde: Prism ec. (18), `m = 2CD/(1−2β) − 1`, *"the number of voting trees is proportional to the bandwidth-delay product... This number is expected to be very large, which is a key advantage of our protocol"*. Con D=4 s, β=0,3 y cabeceras de 556 B:

| m | objetos/s | cabeceras |
|---:|---:|---:|
| 4 | 0,25 | 4,4 GB/año |
| 10 | 0,55 | 9,6 GB/año |
| 100 | 5,05 | **88,5 GB/año** |

La ventaja de Prism es exponencial **en m**. Al presupuesto de una moneda de pago (hoy: 0,15 GB/año de cabeceras, 4,04 GB/año de justificación PoT) m cae en el rango 4-10, donde el argumento no vale nada.

**(6)** Coste: m genesis de rama, m reajustes, m reglas de fork choice, la regla de voto (*"A voter block voting for multiple blocks at the same proposer level is invalid"*) y una definición de confirmación nueva que convive con C-REORG-07.

**(7)** Se modifican los dos: el DAG (estructura de Prism) y el PoST (sorteo a m+1 clases).

**(8)** El ataque: **con m pequeño, capturar ramas**. Con m=4, un atacante con α=0,25 controla en esperanza una rama entera durante rachas largas; Prism supone m grande precisamente para que eso no ocurra. No lo tengo cerrado y creo que no se puede cerrar a este presupuesto.

---

## Candidato C · m canales de desafío con un solo PoT (Fitzi et al.)

**(1)** `desafío_i(slot) = blake3(salida_PoT ‖ slot ‖ i)`, i ∈ [0,m). **Un solo flujo de PoT** (R1 gratis: los m desafíos derivan de la misma salida; el coste de PoT sigue siendo 100,2 ms/slot, invariante). m cadenas lineales independientes, cada una con su LWMA y su SR. El canal 0 es la espina y **el único** que inyecta entropía, retargetea el PoT y ancla el archivado (R2, R3 intactos).

**(2)** No hay billete extra: se multiplica el sorteo. Cada canal es una lotería independiente sobre el mismo espacio.

**(3)** Orden total: intercalado determinista por `(slot, índice de canal)`, con un bloque de la espina que compromete las puntas de los m canales cada N bloques. Conflicto: primera aparición en el intercalado.

**(4)** Peso por canal. Un atacante que retiene un canal retrasa el **prefijo común** del orden total: el ledger no avanza más allá del slot confirmado en el canal más lento.

**(5)** Compra latencia a inclusión (`120/m` s: 30 s con m=4) y throughput ×m, con cabeceras baratas (m=4: 0,58 GB/año). Confirmación: sin cambio.

**(6)** Cambia casi todo: C-EMIT (m× bloques comprimen el calendario ×m salvo reparto), C-EXP-04, C-REORG-07 por canal, archivado, §26.

**(7)** Se modifica **el PoST**: la derivación del desafío global (`subspace-core-primitives/src/lib.rs:110-112`). Es literalmente la línea que pide Katana como alternativa.

**(8)** El ataque que lo mata no es un ataque: es el **coste de auditoría ×m**. §21, medido: un granjero de 4 TiB hace 4 161 lecturas aleatorias/slot a σ=1 s; con m=4 son 16 644, y uno de 20 TiB pasa de 20 807 a 83 228 — al borde de los ~100k IOPS de un SSD. C paga descentralización (P-036, prioridad 1) por latencia. Y el ataque abierto: **congelar un canal** para congelar el orden total; cualquier timeout que lo evite es un parámetro nuevo entre liveness y seguridad que no sé derivar.

---

## RECOMENDACIÓN D2

**Candidato A, con los fardos a peso cero, y solo si el reparto del subsidio se deriva antes de escribir una línea.** Marcada como recomendación.

Por qué: es el único de los tres que **no toca el PoST, no toca el fork choice, no toca la emisión total y no toca el rezago de inyección**. Deja las siete restricciones duras donde están porque no mueve nada de lo que ellas protegen. Y compra lo que este proyecto dice priorizar —reparto de recompensa entre más granjeros— en vez de lo que dice no priorizar.

Contra A juega, y hay que decirlo: **no compra latencia de confirmación**. Si lo que Katana quiere es confirmar antes, A no lo da y B tampoco a este presupuesto. La respuesta honesta a «confirmar antes» hoy es §13 y C-REORG-07, no una estructura nueva.

### Reglas candidatas para el SPEC (numeración provisional, no escribir aún)

1. **C-FRD-01** · Un fardo es válido si `SR/2 < solution_distance ≤ RANGO_FARDO/2`, con `RANGO_FARDO = rango_esperado(ancla) × FACTOR_RANGO_FARDO`. Un fardo con `d ≤ SR/2` es **inválido** (no «degradable»).
2. **C-FRD-02** · La identidad de un fardo es `(public_key, sector_index, history_size, chunk, slot)`. Una cadena que contenga dos objetos con la misma identidad es **inválida**.
3. **C-FRD-03** · El ancla de un fardo **MUST** ser un bloque de espina con `slot(ancla) < slot(fardo) ≤ slot(ancla) + W`.
4. **C-FRD-04** · Un bloque de espina **MUST** referenciar solo fardos anclados a él o a su padre, `≤ MAX_FARDOS`, en orden lexicográfico de identidad (determinismo).
5. **C-FRD-05** · Peso de fork choice: `Σ ⌊2^128/(SR+1)⌋` **solo sobre bloques de espina**. Un fardo suma cero.
6. **C-FRD-06** · Orden del ledger: espina → dentro del bloque, coinbase, txs propias, fardos en el orden de C-FRD-04, txs de cada fardo en su orden. Conflicto: gana la primera aparición; las posteriores se descartan sin invalidar el bloque (deroga C-BLK-09 para fardos).
7. **C-FRD-07** · La emisión total por bloque de espina sigue siendo `recompensa_base(H)` de C-EMIT-01. Lo no reclamado por fardos **MUST NOT** emitirse.

**NO-DETERMINISMO identificado:** el orden de referencia de fardos (cerrado por C-FRD-04); la ventana de dedup por identidad (acotada por `W`, como `ParentBlockVoters`/`CurrentBlockVoters` de Autonomys, ventana de 2 bloques); el rango del fardo debe leerse de la **cadena candidata**, nunca de la activa (C-REORG-06/C-EXP-04).

**RIESGO si esto está mal:** inflación si el reparto del subsidio se calcula con `emitido` desincronizado; split si `RANGO_FARDO` se deriva del ancla en una rama y de la punta en otra; nada de esto puede producir reorg, porque el peso no lo tocan los fardos.

### Para D9 (matemáticas)

1. Que el anillo disjunto conserve la invariancia `tasa de peso ∝ espacio` (§A6 verificado solo para el anillo inferior).
2. Que ensanchar el rango a `FACTOR·SR` **no** cambie φ₅₀ = 1,2815 ni el umbral del 43,8 % (más muestreo del mismo espacio, mismo double dipping — lo creo, no lo he demostrado).
3. Derivar `MAX_FARDOS` desde la cola de Poisson del anillo, no desde el 9 de Autonomys.
4. Convergencia de LWMA-1 con el peso del bloque incluyendo el de sus fardos (C-WGT).
5. Confirmar que el rezago de inyección de P-039 es el mismo con o sin fardos.

### Para D8 (adversarial)

1. **Robo de tarifas / no-referencia** del productor de espina, con el reparto propuesto. Es el ataque abierto.
2. **Spam de fardos**: coste por fardo falso = 1,32 ms de KZG al receptor; `MAX_FARDOS` como límite de consenso no limita lo que llega por red.
3. Equivocación: dos fardos con la misma identidad y payload distinto a dos mitades de la red (D9 ya mostró que la variante «pasado con dos identidades → inválido» particiona; C-FRD-02 la reintroduce y hay que atacarla).
4. Censura selectiva de fardos como vector de censura de transacciones más barato que censurar bloques.
5. §26: coste de la prueba de pago con dos saltos de Merkle y si un servidor puede ocultar un fardo entero.

### Lagunas

- No leí la construcción de Fitzi et al. (ePrint 2018/1119), solo título, autores y abstract: el candidato C se inspira en la idea publicada, **no** en su demostración.
- No verifiqué si un mismo `s_bucket` admite varios chunks ganadores (`proving.rs`): si los admite, la identidad de C-FRD-02 puede necesitar `s_bucket` en lugar de `chunk` (laguna que D9 ya declaró).
- El reparto del subsidio y `FACTOR_RANGO_FARDO` **no tienen número** y no lo invento.
- No medí `Dmax` (§0.1 punto 4 de la auditoría sigue abierto); las cifras de latencia usan Δ=4 s como proxy, que es incorrecto y lo sé.

Ficheros relevantes: `/home/katana/zeo/ZEROX/research/dag-poas-auditoria.md`, `/home/katana/zeo/ZEROX/SPEC.md` §6.1/§7.5/§11/§12.1, `/home/katana/zeo/NODOS/ZEROX/DECISIONES.md` §7/§14/§19/§21/§22/§26.
