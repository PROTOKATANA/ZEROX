# D9 · Ronda 9b — auditoría de la palanca P1 (R-FIN-8 → semántica de Kaspa)

**Fecha:** 2026-09-08 · **Auditor:** D9 (adversarial) · **Estado:** EN CURSO

## Pregunta única
¿Es **segura**, **exacta en su texto** y **cuánto cierra** la palanca P1 de
`research/dag-poas-tras-d8-palancas.md` §2: «los rojos con billete válido dentro de `merge_depth`
cobran, sus transacciones se aplican en el orden del mergeset si no entran en conflicto, y el
retarget (R-FIN-13) cuenta todos los bloques válidos»?

Regla vigente (`research/dag-poas-ancla-de-orden.md:274`):
> **R-FIN-8 · Rojos.** Ni la coinbase ni las transacciones de un bloque rojo se aplican al estado.
> Cierra la inflación ×10 (ronda 1) y el espacio de bloque gratis (ronda 3).

## Estado del volcado
- [x] A · los motivos originales (ronda 1 «×10», ronda 3 «espacio gratis») y si siguen vivos
- [x] B · qué hace Kaspa de verdad (rusty-kaspa @ c338d495), fichero y línea
- [ ] C · vectores nuevos con rojos pagados
- [ ] D · rentabilidad medida (control positivo + modo «rojos pagados»)
- [ ] E · texto de R-FIN-8′ y enmienda a R-FIN-13
- [ ] F · veredicto y errores propios



---

## A · Los dos motivos originales de R-FIN-8 — **SIGUEN VIVOS bajo P1 literal**

### A.1 · Motivo 1: la «inflación ×10» (ronda 1, ATAQUE 3)

Fuente literal: `research/dag-poas-auditoria.md:365-372`.

> **ATAQUE 3 · Copias rojas gratis alimentan el retarget y la emisión si se porta Kaspa**
> **Pasos:** un billete → hasta `max_block_parents` copias (Kaspa a 1 bps: 10, `bps.rs:57-73`)
> referenciadas como padres por el siguiente bloque real del atacante. Las copias son rojas por U3
> pero **(a)** entran en el `mergeset_size` → el DAA ve **×11** bloques por billete → el rango se
> estrecha; **(b)** con la coinbase **dentro del bloque** (C-HDR-08, `merkle_root`) y las txs de
> rojos aplicadas, **cada copia acuña su coinbase**.
> **Efecto:** **inflación ×10** sobre la cuota del atacante, más congelación progresiva del ritmo.

Tiene **dos mitades independientes**: (a) es el **retarget**, (b) es la **emisión**. La mitigación
que se adoptó fue triple: (i) DAA solo sobre azules, (ii) coinbase del rojo no se aplica, (iii) nota
de que el modelo «recompensa = salida de la coinbase del propio bloque» (**C-HDR-08**, `SPEC.md:858`)
es **incompatible** con decidir el color después.

### A.2 · Motivo 2: el «espacio de bloque gratis» (ronda 3)

Fuente literal: `research/dag-poas-candidatos-auditoria.md:459-472`.

> **HALLAZGO:** Un billete → N copias rojas con conjuntos de transacciones distintos, todas
> aplicadas: espacio de bloque gratis y crecimiento de estado gratis. **SEVERIDAD:** DoS
> (crecimiento de estado) — **NO inflación**. […] Las tx pueden ser de comisión cero […]
> sí hay N× de inserción de UTXO por billete.
> **MITIGACIÓN:** no aplicar las transacciones de los bloques rojos […] **o contar la masa de los
> rojos contra el límite del fusionador. No está escrito.**

### A.3 · La afirmación de P1 y por qué es **FALSA**

P1 (`research/dag-poas-tras-d8-palancas.md:31-33`) afirma que los dos motivos son obsoletos
«con U2 + U3″ (cada billete paga una vez)». **Confunde *azul una vez* con *pagado una vez*.**

- **U2** (`R-FIN-11`) invalida un bloque cuya identidad ya esté en **su propio pasado**. Dos copias
  hermanas —en anticono mutuo— **son ambas válidas**.
- **U3″ dinámica** garantiza que **una sola copia por identidad sea AZUL**. Las demás quedan
  **ROJAS y VÁLIDAS**, dentro del `mergeset`, dentro de `merge_depth`.
- **P1 paga a los rojos.** Luego paga a las `N−1` copias. El ×N vuelve, sin tocar U2 ni U3″.

### A.4 · Verificación **constructiva** (no estadística)

`research/scripts/d9-ronda9b/r9b_a_copias.py` → `salida_a.txt`. Construcción explícita sobre
`r8c_gd.DAG(k=25, u2=True, u3_mode="dynamic", max_parents=15)` (fiel a rusty-kaspa @ c338d495):
`H0` honesto; `n` copias del **mismo** billete `X` colgadas todas de `H0` (legal: `H0` no tiene `X`
en su pasado); `B_1..B_m` bloques del atacante con billete propio, cada uno con padres
`(B_{j−1}, n copias frescas)`.

| `u3_mode` | `m` | `n` | azules de `X` | **rojos de `X`** | billetes reales | **bloques pagados bajo P1** | **×/billete** | rechazos |
|---|---:|---:|---:|---:|---:|---:|---:|---|
| `dynamic` | 1 | 14 | 1 | **13** | 2 | 15 | **7,500** | — |
| `dynamic` | 2 | 14 | 1 | **27** | 3 | 30 | **10,000** | — |
| `dynamic` | 5 | 14 | 1 | **69** | 6 | 75 | **12,500** | — |
| `dynamic` | 10 | 14 | 1 | **139** | 11 | 150 | **13,636** | — |
| `dynamic` | 50 | 14 | 1 | **699** | 51 | 750 | **14,706** | — |
| `dynamic` | 1 | 15 | 0 | 0 | 1 | 0 | — | `TooManyParents` |
| `off` (GHOSTDAG puro) | 5 | 14 | **25** | 45 | 6 | 75 | 12,500 | — |
| **`α = 0` (m=3, n=0)** | 3 | 0 | **0** | **0** | — | — | — | — |

- **Criterio `α` ✓** — sin copias (`n = 0`): 0 azules de `X`, 0 rojos de `X`.
- **Control positivo ✓** — copia colgada de otra copia ⇒ rechazo `U2`; 21 padres ⇒ `TooManyParents`.
  El instrumento **sí** rechaza cuando debe.
- **Cobertura de rama ✓** — `u3_mode='off'` da 14→25 azules (el ×N *de peso* que U3″ cerró);
  `u3_mode='dynamic'` da **exactamente 1 azul** por identidad — la afirmación de P1 **es cierta sobre
  el color** — y **13-699 rojos válidos y fusionados** — la afirmación **es falsa sobre el pago**.

**El límite es `max_block_parents − 1 = 14` copias por bloque del atacante, y la cota asintótica es
`×15` por billete** (`(1+14m)/(m+1) → 15`). `mergeset_size_limit = 180` no muerde (el mergeset de
cada `B_j` es exactamente 15). `merge_depth = 3 600 · bps` (`constants.rs:81`, `bps.rs:88-90`) acota
`m`, no el factor.

**Veredicto A: la afirmación de P1 está REFUTADA.** Ambos motivos originales de R-FIN-8 vuelven a
estar abiertos si P1 se aplica tal como está escrita: **inflación ×15** (motivo 1b), **retarget ×15**
(motivo 1a, si además se enmienda R-FIN-13 a «todos los bloques válidos») y **espacio de bloque y
crecimiento de estado ×15** (motivo 2). El fallo **no** está en el fondo de P1 —pagar a los rojos del
*k-cluster*— sino en que P1 no distingue **por qué** un bloque es rojo.

---

## B · Qué hace Kaspa de verdad — `rusty-kaspa` @ `c338d495` (23 ago 2026, verificado)

### B.1 · Coinbase: los rojos **SÍ** se emiten, pero **NO cobra el rojo: cobra el FUSIONADOR**

`consensus/src/processes/coinbase.rs:97-137` — `expected_coinbase_transaction`
(⚠️ la ruta del encargo, `consensus/src/processes/coinbase/mod.rs`, **no existe**; es `coinbase.rs`):

```
:109  for blue in ghostdag_data.mergeset_blues.iter().filter(|h| !mergeset_non_daa.contains(h)) {
:110      let reward_data = mergeset_rewards.get(blue).unwrap();
:113      outputs.push(TransactionOutput::new(subsidy + total_fees, reward_data.script_public_key.clone()));

:119  let mut red_reward = 0u64;
:121  for red in ghostdag_data.mergeset_reds.iter() {
:123      if mergeset_non_daa.contains(red) { red_reward += reward_data.total_fees; }
:126      else                              { red_reward += reward_data.subsidy + reward_data.total_fees; }
:130  if red_reward > 0 {
:131      outputs.push(TransactionOutput::new(red_reward, miner_data.script_public_key.clone()));
```

Tres hechos, con línea:

1. **A cada AZUL del mergeset se le paga a SU propia `script_public_key`** (`:113`).
2. **Todos los ROJOS se agregan en UNA salida pagada a `miner_data.script_public_key`** — el minero
   del bloque **fusionador** (`:131`). *El rojo no cobra nada; cobra quien lo fusiona.*
3. Un rojo **fuera de la ventana DAA** (`mergeset_non_daa`) aporta **solo comisiones**, sin subsidio
   (`:123`). `mergeset_non_daa` = mergeset con `blue_score < lowest_daa_blue_score`
   (`difficulty.rs:155-163`).

Y el subsidio **de un bloque nunca sale de su propia coinbase**: la coinbase de `B` paga al mergeset
de `B`, y a `B` le paga un descendiente. Confirmado en `utxo_validation.rs:308` y `:335`:
`.skip(1) // Skip the coinbase tx.` — **la coinbase de un bloque fusionado (azul o rojo) NO se aplica**.

### B.2 · DAA: cuenta azules **y rojos**

`consensus/src/processes/difficulty.rs:27-30`:
`sp_daa_score + (ghostdag_data.mergeset_size() − mergeset_non_daa.len())`, y
`mergeset_size() = mergeset_blues.len() + mergeset_reds.len()`
(`model/stores/ghostdag.rs:111-113`). Kaspa **sí** cuenta rojos en el retarget — porque en Kaspa un
rojo cuesta un PoW y **no hay copias**.

### B.3 · Transacciones: los rojos **SÍ** se aplican, en el orden ascendente del mergeset

`consensus/src/pipeline/virtual_processor/utxo_validation.rs:106-176`, `calculate_utxo_state`:

- `:120-123` itera `once(selected_parent) ++ consensus_ordered_mergeset_without_selected_parent(...)`.
- `consensus_ordered_mergeset` = `once(sp) ++ ascending_mergeset_without_selected_parent`
  (`model/stores/ghostdag.rs:175-180`), y ese `ascending` hace `merge_join_by` de
  **`mergeset_blues.skip(1)` con `mergeset_reds`** por `SortableBlock::cmp`
  (`ghostdag.rs:115-136`) — es decir, **azules y rojos entrelazados por `blue_work` ascendente**,
  desempate por hash (`ordering.rs:38-42`).
- `:129` compone la vista `sp_utxo ⊕ mergeset_diff` **antes de cada bloque**: el orden decide.
- `:311-313` / `:335-337` `filter_map(... .ok() ...)`: una tx que **conflictúa se descarta en
  silencio**, no invalida el bloque. Las no conflictivas se aplican (`:152-156`).
- `:159-167` registra `MergesetBlockAcceptanceData` por bloque fusionado (azul **o rojo**), y
  `:172-176` guarda `mergeset_rewards[merged_block] = (subsidy, block_fee, script_public_key)`
  **también para los rojos** — de ahí sale el `red_reward` de B.1.

### B.4 · `merge_depth`: un rojo fuera de profundidad **no es que no cobre — es que no se puede fusionar**

`consensus/src/pipeline/header_processor/post_pow_validation.rs:79-101`, `check_bounded_merge_depth`:
recorre **solo `mergeset_reds`**; si un rojo no es descendiente de `merge_depth_root` **ni** es
ancestro de algún *kosherizing blue*, el **bloque fusionador es INVÁLIDO**
(`RuleError::ViolatingBoundedMergeDepth`, `:96`). `merge_depth = bps · 3 600`
(`bps.rs:88-90`, `constants.rs:81`).

### B.5 · Qué parte de P1 coincide con Kaspa y qué parte NO

| P1 dice | Kaspa | Veredicto |
|---|---|---|
| «sus transacciones se aplican en el orden del mergeset si no entran en conflicto» | `utxo_validation.rs:120-156` + `ghostdag.rs:115-136`; conflicto ⇒ descarte silencioso | **COINCIDE** (VERIFICADO) |
| «el retarget cuenta todos los bloques válidos» | `difficulty.rs:27-30`, `mergeset_size()` = azules + rojos, menos `non_daa` | **COINCIDE** en la letra; **DIVERGE en la premisa** — Kaspa no tiene copias de billete (ver A) |
| «los rojos **cobran**» | El rojo **NO cobra**: su subsidio + comisiones se agregan y se pagan a la `script_public_key` del **FUSIONADOR** (`coinbase.rs:121-131`) | **NO COINCIDE** |
| «con billete válido **dentro de `merge_depth`**» | En Kaspa un rojo fuera de `merge_depth` **no se fusiona**: invalida al fusionador (`post_pow_validation.rs:96`). No existe la categoría «rojo fusionado que no cobra por profundidad» | **NO COINCIDE** (la cláusula es vacua) |
| — (P1 no lo menciona) | Un rojo **fuera de la ventana DAA** cobra **solo comisiones**, sin subsidio (`coinbase.rs:123`) | **FALTA en P1** |
| — (P1 no lo menciona) | La coinbase de un bloque fusionado **no se aplica** (`utxo_validation.rs:308`): incompatible con **C-HDR-08** (`SPEC.md:858-861`), que ata la recompensa a la salida de la coinbase del **propio** bloque | **FALTA en P1** — es un cambio de `SPEC.md`, no «una regla» |

**Consecuencia de incentivos que P1 no ve.** Si se adopta la semántica de Kaspa *literal*, en la
cadena parásita de D8 A1.2 **es el atacante quien fusiona a los honestos enrojecidos**, luego el
subsidio de los honestos rojos **se lo lleva el atacante**. La palanca que P1 vende como «sin
ganancia» sería, en su forma fiel a Kaspa, **una transferencia directa de los honestos al atacante**.
Se mide en D.

**Veredicto B: VERIFICADO** (fichero y línea). P1 coincide con Kaspa en las transacciones,
diverge en el destinatario de la recompensa del rojo, y su cláusula de `merge_depth` es vacua.
