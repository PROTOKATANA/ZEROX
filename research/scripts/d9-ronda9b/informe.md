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
- [x] D · rentabilidad medida (control positivo + modo «rojos pagados»)
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

---

## D · Rentabilidad, MEDIDA — P1 cierra el incentivo; **Kaspa literal lo duplica**

**Script:** `research/scripts/d9-ronda9b/r9b_d_coste.py` → `salida_d.txt`.
Reutiliza **sin reescribirla** la maniobra parásita de `d8_lib.MundoL9.corre_l9(modo='parasito')`
(adversario del paper, `phantom-ghostdag.txt` L1024-1027: sin retardo), con las **12 semillas
literales** `[1..12]`, horizonte 1 800 s, ventana `[60, 1 740] s`, `k = 30`, `mp = 15`,
`J` exactamente el de `d8-ronda8/salida_a1e.txt`.

Tres semánticas de pago, en unidades de recompensa **por bloque producido**:

- **S0 · R-FIN-8 vigente** — `paga(x) = #{bloques de x AZULES en la vista honesta final}`.
- **S1 · P1 tal como está escrita** («los rojos … cobran» ⇒ cobra el **productor** del rojo)
  — `paga(x) = #{bloques de x VÁLIDOS y FUSIONADOS}` (azules + rojos del orden de consenso).
- **S2 · Kaspa literal** (`coinbase.rs:121-131`: el rojo **no** cobra, cobra el **fusionador**)
  — `paga(x) = #{azules de x} + #{rojos en el mergeset de bloques de CADENA creados por x}`.
  Contabilidad fiel: la recompensa fluye **solo** por la coinbase de los bloques de la cadena
  seleccionada (`utxo_validation.rs:106-123` y `.skip(1)` en `:308`/`:335`).

| `α` | `J` | S0 h | S0 a | **ratio S0** | S1 h | S1 a | **ratio S1** | S2 h | S2 a | **ratio S2** | `n_h` | `n_a` | rojos | cad_a | cad_h | perd |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| **0,00** | 16 | 1,0000 | *(n_a=0)* | — | 1,0000 | *(n_a=0)* | — | 1,0000 | *(n_a=0)* | — | 19 978 | **0** | **0** | 0 | 4 050 | 0 |
| 0,10 | 16 | 0,9777 | 0,3116 | 0,319 | 1,0000 | 0,9757 | **0,976** | 1,0007 | 0,9966 | **0,996** | 17 924 | 2 054 | 1 818 | 274 | 3 792 | 50 |
| 0,25 | 16 | 0,8458 | 0,8422 | 0,996 | 1,0000 | 0,9990 | **0,999** | 0,8894 | 1,3324 | **1,498** | 14 921 | 5 057 | 3 130 | 2 996 | 2 110 | 5 |
| 0,30 | 31 | 0,7918 | 0,6969 | 0,880 | 1,0000 | 0,9977 | **0,998** | 0,8350 | 1,3777 | **1,650** | 13 907 | 6 071 | 4 733 | 2 650 | 2 423 | 14 |
| **0,33** | 31 | 0,7136 | 0,8277 | **1,160** | 1,0000 | 0,9963 | **0,996** | 0,7445 | 1,5103 | **2,029** | 13 297 | 6 681 | 4 970 | 4 337 | 1 645 | 25 |
| **0,35** | 31 | 0,6934 | 0,8813 | **1,271** | 1,0000 | 0,9970 | **0,997** | 0,7255 | 1,5008 | **2,069** | 12 882 | 7 096 | 4 810 | 5 390 | 1 197 | 21 |
| **0,37** | 48 | 0,6558 | 0,7593 | **1,158** | 1,0000 | 0,9922 | **0,992** | 0,6846 | 1,5335 | **2,240** | 12 499 | 7 479 | 6 150 | 4 470 | 1 669 | 58 |
| **0,40** | 48 | 0,5643 | 0,8733 | **1,548** | 1,0000 | 0,9882 | **0,988** | 0,5817 | 1,6242 | **2,792** | 11 937 | 8 041 | 6 246 | 6 380 | 937 | 95 |

**Control positivo (regla 4), ANTES de medir S1/S2** — S0 reproduce `salida_a1e.txt`:

| `α` | medido | esperado | \|dif\| |
|---:|---:|---:|---:|
| 0,25 | 0,996 | 0,995 | 0,0008 |
| 0,33 | 1,160 | 1,159 | 0,0009 |
| 0,35 | 1,271 | 1,270 | 0,0011 |
| 0,40 | 1,548 | 1,549 | 0,0015 |

**SUPERADO.** (La diferencia < 0,002 es que aquí agrego sumando sobre las 12 semillas y `a1e`
promediaba fracciones por semilla; misma maniobra, mismos bloques.)

- **Criterio `α` ✓** — `α = 0`: `n_a = 0`, columnas del atacante vacías; `rojos = 0`.
- **Cobertura de rama ✓** — `rojos` de 1 818 a 6 246 y `cad_a` de 274 a 6 380 en toda fila con
  `α > 0`: las ramas de S1 y S2 se ejercitan de verdad.

### D.1 · Lectura

1. **S1 (P1 tal como está escrita) cierra el incentivo por completo: ratio 0,988–0,999 para todo
   `α`.** La rentabilidad de 1,16–1,55 que D8 A1.5 midió **desaparece**. `S1_h = 1,0000` exacto:
   **ningún** bloque honesto pierde su recompensa, luego la reversión de transacciones de 64-142 s
   también se cierra. Y `S1_a < 1` sólo por los `perd` = 5–95 bloques retenidos que nunca se
   publicaron. **P1 hace lo que promete… con su propia redacción, que no es la de Kaspa.**
2. **S2 (Kaspa literal) es estrictamente PEOR que el statu quo en toda fila.** Ratio 1,50–2,79
   frente a 0,996–1,548 de S0. Adoptar la semántica de Kaspa *fielmente* **duplica** la
   rentabilidad de la parásita: el atacante fusiona a los honestos que enrojece y **se queda con
   su subsidio** (`S2_a > 1`: cobra más de una unidad por bloque propio). A `α = 0,25` la maniobra
   pasa de neutra (0,996) a **claramente rentable (1,498)**.
3. **Lo que P1 no cierra:** a `α = 0,10` el ratio sube de 0,319 (S0) a 0,976 (S1). Bajo R-FIN-8
   parasitar **cuesta** al granjero pequeño; bajo P1 es **gratis** (neutro) a todo `α`. El
   *griefing* deja de tener coste de oportunidad, aunque deja de tener premio. El daño residual
   —`δ` sigue existiendo y sigue restando `blue_work` al crecimiento honesto— es el que entra en
   la frontera de flujo único. **P1 quita el premio, no el ataque.**

### D.2 · Alcance de la medida (honesto)

En `MundoL9` cada evento lleva `ident = (quien, i)` **única** (`r8c_sim.py:46-48`): **la
simulación de D no contiene copias de billete.** D y A son experimentos **ortogonales**: A mide el
×15 por copias, D mide la rentabilidad de la parásita. Por eso, numéricamente, S1 aquí coincide con
la variante corregida R-FIN-8′ de §E (que sólo se diferencia en cómo trata a los rojos por U3″, de
los que aquí hay cero). **LAGUNA declarada:** no he medido la parásita **y** las copias a la vez.

**Veredicto D: DEMOSTRADO** que P1 en su redacción (S1) anula la rentabilidad (1,16–1,55 → 0,99);
**REFUTADO** que la vía sea «la semántica de Kaspa» (S2: 1,50–2,79, peor que no hacer nada).
