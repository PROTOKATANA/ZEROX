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
- [x] C · vectores nuevos con rojos pagados
- [x] D · rentabilidad medida (control positivo + modo «rojos pagados»)
- [x] E · texto de R-FIN-8′ y enmienda a R-FIN-13
- [x] F · veredicto y errores propios



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

---

## C · Vectores nuevos con los rojos pagados

**Script:** `research/scripts/d9-ronda9b/r9b_c_retarget.py` → `salida_c.txt`.

### C.1 · El invariante que P1 rompe

> **La regla que el retarget CUENTA y la regla que la emisión PAGA tienen que definir el mismo
> conjunto.** Si el conjunto pagado es mayor que el contado, la emisión corre por delante del
> calendario y el atacante se lleva la diferencia. Si es menor, el retarget infla `λ_real`.

| Diseño | conjunto CONTADO (R-FIN-13) | conjunto PAGADO (R-FIN-8) | ¿coinciden? |
|---|---|---|---|
| Vigente | azules | azules | **sí** |
| **P1 literal** | todos los válidos | todos los rojos+azules fusionados | **no** — difieren en las **copias** |
| **R-FIN-8′ + R-FIN-13′** (§E) | un bloque por **identidad**, fusionado | un bloque por **identidad**, fusionado | **sí** |

### C.2 · ¿Hay inflación? — **sí, ×15, y por las copias; no por los rojos-`k`**

Medido, **sin** copias (`r9b_d_coste.py`, maniobra parásita, 12 semillas): la fracción de bloques
producidos que acaban **fusionados** es 0,9952–1,0000 para todo `α`. **Pagar a los rojos-`k` no
emite ni un bloque de más por segundo.**

Medido, **con** copias (`r9b_c_retarget.py` C2, construcción determinista):

| `m` | `n` | `N_billetes` | `N_azules` | `N_fusionados` | `N_1×identidad` | infl. azul | **infl. fusionados** | infl. 1×id |
|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| 1 | **0** | 3 | 2 | 2 | 2 | 0,667 | **0,667** | 0,667 |
| 1 | 14 | 3 | 3 | 16 | 3 | 1,000 | **5,333** | 1,000 |
| 5 | 14 | 7 | 7 | 76 | 7 | 1,000 | **10,857** | 1,000 |
| 10 | 14 | 12 | 12 | 151 | 12 | 1,000 | **12,583** | 1,000 |
| 50 | 14 | 52 | 52 | 751 | 52 | 1,000 | **14,442** | 1,000 |

**Precisión sobre «inflación».** `C-EMIT-01` (`SPEC.md:1458-1464`) usa `emitido(H)` **acumulado**,
así que el suministro **no** se desborda: lo que pasa es que la curva se recorre ×15 más rápido y
**el atacante captura la diferencia**. Es exactamente lo que decía la ronda 1: *«inflación ×10
**sobre la cuota del atacante**»* (`dag-poas-auditoria.md:370`). **Redistribución, no ruptura del
`SOFT_CAP`.** Y la elección de conteo del retarget **no salva**, sólo elige el daño:

- R-FIN-13 vigente (azules) + P1 (paga rojos) ⇒ dificultad estable, **emisión ×15** → captura.
- R-FIN-13 enmendada (todos los válidos) + P1 ⇒ emisión al ritmo, **dificultad ×15** →
  *«congelación progresiva del ritmo de bloques»* (`dag-poas-auditoria.md:370`), censura económica.

### C.3 · ¿Hay «espacio de bloque gratis»? — **sí, el mismo ×15**

Es el motivo 2 (ronda 3) sin cambios: `N−1 = 14` copias por bloque del atacante, cada una con un
**cuerpo distinto**, todas aplicadas al UTXO en el orden del mergeset. `mergeset_size_limit = 180`
no muerde (el mergeset de cada `B_j` es 15). Con comisión cero (el consenso no exige mínimo) es
**crecimiento de estado gratis**. La mitigación alternativa que la ronda 3 dejó escrita —*«contar
la masa de los rojos contra el límite del fusionador»*— **sigue sin estar escrita** y **no la
resuelve para las copias** (sólo la encarece). Etiqueta: **CONFIRMADO**.

### C.4 · La parásita con rojos pagados — el premio se va, el castigo también

- **Los bloques fallidos NO cobran.** Un bloque retenido y nunca publicado no está en `past` de la
  punta ⇒ no se fusiona ⇒ no cobra bajo ninguna semántica. Medido: `perd` = 5–95 bloques,
  `S1_a = 0,988–0,999`. **Intentarlo cuesta 0,1–1,2 %.**
- **Pero deja de castigar.** A `α = 0,10` el ratio pasa de **0,319** (R-FIN-8) a **0,976** (P1).
  Bajo R-FIN-8 un granjero pequeño que parasita **pierde dos tercios de su ingreso**; bajo P1 no
  pierde nada. **P1 quita el premio y también el disuasorio.** El `δ` que la parásita impone
  —y que entra en `(1−α)(1−δ)` de la frontera de flujo único— sigue siendo el mismo: **P1 no
  cierra el ataque, cierra su rentabilidad.** Etiqueta: **DEMOSTRADO** (medido en D).
- **Efecto colateral (PLAUSIBLE, no medido):** si un bloque cobra igual siendo rojo, desaparece la
  presión económica hacia la **puntualidad**. Hoy un granjero tardío pierde la coinbase; con P1 no.
  Un `δ` «natural» mayor por pereza rebaja `(1−α)(1−δ)` sin ningún atacante. **No lo he medido.**

### C.5 · Interacción con R-FIN-1a: P1 concentra TODO el *griefing* en la invalidación

R-FIN-1a **no enrojece: invalida** (`slot(B) − slot(sp(B)) > S_max` ⇒ bloque inválido). Por R-FIN-4
un bloque inválido no está en el `past` de ningún bloque válido, luego **nunca se fusiona y nunca
cobra**, bajo cualquier semántica. No hay interacción directa. **Pero sí una indirecta y mala:**
con P1, enrojecer a un honesto deja de quitarle dinero, así que **la única forma de negarle el pago
pasa a ser invalidarlo** — es decir, R-FIN-1a. D8 A3 M1 midió esa superficie:
**11,7 bloques honestos/h** invalidados a `α = 0,25` y **24,2/h** a `α = 0,40` con `S_max = 20 s`,
y **0/h** con `S_max ≥ 30 s`. **P1 sube la apuesta de elegir `S_max ≥ 30 s`.** Etiqueta:
**PLAUSIBLE** (la superficie está medida por D8; que el atacante se desplace a ella es inferencia).

### C.6 · Interacción con `merge_depth` — la cláusula de P1 es vacua **y además errónea**

En Kaspa un rojo fuera de `merge_depth_root` **no es que no cobre: es que invalida al fusionador**
(`post_pow_validation.rs:79-101`, `RuleError::ViolatingBoundedMergeDepth` en `:96`). No existe la
categoría «rojo fusionado fuera de `merge_depth`». **Excepción:** los *kosherizing blues*
(`block_depth.rs:109-119`) — un rojo que sea ancestro de un azul del mergeset descendiente de
`merge_depth_root` **sí se fusiona legalmente**, y en Kaspa **sí cobra**. La cláusula de P1
«dentro de `merge_depth`» le negaría el pago sin ninguna razón. Etiqueta: **VERIFICADO** (código).

### C.7 · Interacción con U3″ dinámica — es el agujero, ya cubierto en A

Un rojo cuya identidad **ya fue coloreada de azul** en `past(sp)` o **en el mismo mergeset** es una
**copia**. Bajo P1 cobra y aplica su cuerpo ⇒ ×15 (A, C.2, C.3). **R-FIN-8′ tiene que distinguir
las dos causas de rojez.** Nombro la distinción para poder escribirla:

- **`rojo_k`** — rojo por el `k`-cluster de GHOSTDAG (`check_blue_candidate`, `protocol.rs:246-283`).
  Su billete es **único** en la vista del fusionador. **Cobra y aplica.**
- **`rojo_U3`** — rojo porque su identidad ya está azul en `past(sp)` o antes en el mismo mergeset
  (R-FIN-11 U3″). Es una **copia**. **Ni cobra, ni aplica, ni cuenta en el retarget.**

La distinción es **determinista y función de `past(B)`** (R-FIN-4): U3″ ya la calcula al colorear,
`r8c_gd.py:222-231`. No cuesta nada implementarla.

### C.8 · El retarget y la nota de `dag-poas-delta-real.md` — **deja de aplicar, y está MEDIDO**

`dag-poas-delta-real.md:17-20` deriva `λ_real = k·λ_obj/(k − 2D·λ_obj)` de la premisa
`λ_obs = λ·k/(k + 2Dλ)`, es decir **«el retarget sólo ve azules»**. Medido sobre la maniobra
parásita de D8 (12 semillas, `k = 30`, `Δ = 4 s`, `λ = 1/s`):

| `α` | azul/producido | **infl. contando azules** | fusionado/producido | **infl. contando fusionados** | `N_prod` | rojos |
|---:|---:|---:|---:|---:|---:|---:|
| **0,00** | 1,0000 | **1,0000** | 1,0000 | **1,0000** | 19 978 | **0** |
| 0,10 | 0,9093 | 1,0998 | 0,9975 | 1,0025 | 19 978 | 1 838 |
| 0,25 | 0,8449 | 1,1836 | 0,9997 | 1,0003 | 19 978 | 3 268 |
| 0,30 | 0,7630 | 1,3106 | 0,9993 | 1,0007 | 19 978 | 4 937 |
| 0,33 | 0,7518 | 1,3302 | 0,9987 | 1,0013 | 19 978 | 5 168 |
| 0,35 | 0,7601 | 1,3156 | 0,9989 | 1,0011 | 19 978 | 4 982 |
| 0,37 | 0,6946 | 1,4398 | 0,9971 | 1,0029 | 19 978 | 6 313 |
| **0,40** | 0,6887 | **1,4521** | 0,9952 | **1,0048** | 19 978 | 6 365 |

- **Criterio `α` ✓** — `α = 0`: inflación 1,0000 por las dos reglas, 0 rojos.
- **Control positivo ✓** — contando azules, la inflación medida a `α = 0,40` es **×1,452**, del
  mismo orden que el **×1,36** que el modelo de `delta-real.md` deriva para `k = 30` (la medida es
  algo mayor porque el `δ` parásito de D8 supera la cota del Lema 9 — es el hallazgo A1 de D8).

**Conclusión, MEDIDA:** si el retarget cuenta a los rojos-`k`, la inflación cae de **×1,45 a
×1,005**, y `λ_real ≈ λ_obj`, `δ_real ≈ δ_nominal`. **La nota `dag-poas-delta-real.md` deja de
aplicar.** Lo que compra, con los números de ese mismo fichero (`k = 30`): `δ_real` 0,267 → `δ`
nominal 0,211; umbral de **orden** 40,0 % → **41,7 %**; `r = 1` en 42,3 % → **43,1 %**.
**Etiqueta: DEMOSTRADO** (medido a 12 semillas, con `α = 0` y control positivo). **Es el beneficio
más grande de P1, y P1 lo menciona de pasada.**

### C.9 · Coste arquitectónico que P1 **no** declara

`C-EMIT-03` (`SPEC.md:1532-1533`) dice `Σ salidas(coinbase) ≤ subsidio(H) + Σ fees(bloque)` **del
propio bloque**, y `C-HDR-08` (`:858-861`) mantiene la dirección fuera de la cabecera porque *«la
recompensa es la salida de la coinbase»*. Las dos sobreviven **sólo** con la variante
«**se aplica la coinbase propia de todo bloque fusionado**» (§E). Con la variante **Kaspa literal**
(`coinbase.rs:121-131`, el fusionador cobra) hay que reescribir `C-EMIT-03` a
`Σ salidas ≤ Σ_{X ∈ mergeset(B)} (subsidio(X) + fees_aceptadas(X))` — que es lo que la ronda 1
llamaba *«rediseño de §22 y C-EMIT»* (`dag-poas-auditoria.md:372`). **P1 la vende como «la palanca
más barata: una regla». Con la variante recomendada lo es; con la de Kaspa, no.**
**Residuo PLAUSIBLE, no medido:** con la coinbase propia, **nadie cobra por fusionar a un rojo**.
Kaspa paga al fusionador precisamente para incentivar la inclusión. En ZEROX el algoritmo de padres
está adoptado como consenso (R-FIN-12, `pick_virtual_parents`), así que la conducta no depende del
incentivo, pero **no he medido si un granjero racional se desviaría**.

---

## E · Texto propuesto — R-FIN-8′ y R-FIN-13′

*(No he tocado `research/dag-poas-ancla-de-orden.md`. Este es el texto para que lo aplique el
agente principal.)*

### E.1 · Las dos causas de rojez, nombradas

Sea `B` un bloque de la **cadena seleccionada** y `mergeset(B) = past(B) \ (past(sp(B)) ∪ {sp(B)})`.
El coloreado de R-FIN-6 + R-FIN-11 asigna a cada `X ∈ mergeset(B)` exactamente una etiqueta,
**función de `past(B)` y de nada más** (R-FIN-4):

- **azul** — `X ∈ mergeset_blues(B)`.
- **`rojo_k`** — `X ∈ mergeset_reds(B)` **y** su identidad de billete (R-FIN-11) no era azul en
  `past(sp(B))` ni fue coloreada de azul antes que `X` en el orden `sort_blocks` del mergeset.
  Es rojo **por el `k`-cluster** (`protocol.rs:246-283`): su billete es único.
- **`rojo_U3`** — `X ∈ mergeset_reds(B)` **y** su identidad sí lo era. Es una **copia** (R-FIN-11 U3″).

La distinción ya la calcula U3″ al colorear (`r8c_gd.py:222-231`); no cuesta nada implementarla.

> **Por qué la penalización sólo puede caer sobre quien se equivoca a sí mismo.** Producir dos
> bloques con la misma identidad exige dos firmas Ed25519 válidas sobre dos `pre_hash` distintos
> bajo la **misma** `sol.public_key` (`C-HDR-03`/`C-HDR-04`, `SPEC.md:865-870`), y `merkle_root`
> está dentro de la prefirma: **cambiar el cuerpo obliga a refirmar**. Nadie puede convertir el
> bloque de un tercero en `rojo_U3`; sólo el dueño del billete, equivocándose. **DEMOSTRADO.**

### E.2 · R-FIN-8′ · Rojos

> **R-FIN-8′ · Rojos: cobran y aplican, salvo las copias. (Sustituye a R-FIN-8, ronda 9b.)**
>
> 1. **Quién cobra.** Un bloque **azul** o **`rojo_k`** cobra. Un **`rojo_U3`** **no cobra nada**:
>    ni subsidio ni comisiones.
> 2. **Cuánto y a quién.** Se aplica **la coinbase del propio bloque cobrador**, tal como está
>    escrita en él, sujeta a `C-EMIT-03` con su propio `H`. **NO se adopta el `red_reward` de
>    Kaspa** —donde el rojo no cobra y cobra el fusionador (`coinbase.rs:121-131`)—: medido en §D,
>    esa variante **multiplica por 1,50–2,79** la rentabilidad de la cadena parásita, porque el
>    atacante fusiona a los honestos que enrojece y se queda con su subsidio. Con esta redacción
>    **`C-HDR-08` y `C-EMIT-03` no se tocan**.
> 3. **Qué se aplica al estado.** Las transacciones de los bloques **azules** y **`rojo_k`** se
>    aplican. Las de un **`rojo_U3`** **no**: su cuerpo es inerte —ni UTXO, ni comisiones, ni peso
>    contra ningún límite— salvo que sigue ocupando una plaza de `mergeset_size_limit`.
> 4. **En qué orden.** Por cada bloque `C` de la cadena seleccionada, en el orden
>    `[sp(C)] ++ mergeset(C)` con el mergeset en **`blue_work` ascendente**, desempate por
>    `solution_distance` menor y luego por hash — **azules y `rojo_k` entrelazados en esa única
>    clave**, no primero unos y luego otros (`ghostdag.rs:115-136`, `ordering.rs:38-42`,
>    `utxo_validation.rs:120-123`). Los `rojo_U3` se **saltan**.
> 5. **Conflictos.** Una transacción que no valide contra `UTXO(sp(C)) ⊕ diff(mergeset hasta ella)`
>    **se descarta en silencio**: no invalida ni al bloque que la contiene ni al fusionador
>    (`utxo_validation.rs:311-313`, `.filter_map(...ok()...)`). Gana el gasto que aparece **primero**
>    en el orden de (4). `fees(X)` en (2) suma **sólo** las transacciones aceptadas de `X`.
> 6. **Una sola vez.** La coinbase de `X` y cada transacción de `X` se intentan **exactamente una
>    vez**: en el primer —y único— bloque de la cadena seleccionada que tiene a `X` en su mergeset.
> 7. **`merge_depth`.** **No hay cláusula de pago por profundidad.** Un rojo que no descienda de
>    `merge_depth_root` y no sea ancestro de un *kosherizing blue* **invalida al bloque fusionador**
>    (R-FIN-12; `post_pow_validation.rs:79-101`, `RuleError::ViolatingBoundedMergeDepth`), luego
>    nunca llega a cobrar. Un rojo **kosherizado** (`block_depth.rs:109-119`) **sí se fusiona y sí
>    cobra** por (1).
> 8. **Inválidos.** Un bloque inválido (R-FIN-1a, R-FIN-4, R-FIN-5, U2) **no es rojo: no existe**.
>    Por R-FIN-4 no está en el `past` de ningún bloque válido: no se fusiona, no cobra, no cuenta.
> 9. **Madurez.** `COINBASE_MATURITY` (`C-EMIT-05`) se cuenta desde el bloque de **cadena** que
>    fusionó a `X`, no desde `X`: antes de fusionarse, el color de `X` —y por tanto si cobra— no
>    está decidido.
>
> **Lo que cierra, medido (§D, 12 semillas, adversario del paper):** la rentabilidad de la cadena
> parásita de D8 A1.5 pasa de **1,16 / 1,27 / 1,16 / 1,55** (`α = 0,33 / 0,35 / 0,37 / 0,40`) a
> **0,996 / 0,997 / 0,992 / 0,988**, y ningún bloque honesto pierde su recompensa (`S1_h = 1,0000`
> exacto): **se acaban también las reversiones de transacciones de 64-142 s**.
> **Lo que NO cierra:** el ataque sigue existiendo y ahora es **gratis** también a `α` pequeño
> (ratio 0,319 → 0,976 a `α = 0,10`): quita el premio y también el castigo.
> **Lo que sustituye a los dos motivos de R-FIN-8:** la cláusula `rojo_U3` de (1) y (3) — sin ella
> la inflación ×15 de la ronda 1 y el espacio de bloque gratis de la ronda 3 **vuelven** (§A, ×14,7
> medido).

### E.3 · R-FIN-13′ · Enmienda a la ventana del retarget

> **R-FIN-13′ (enmienda, ronda 9b).** Donde R-FIN-13 dice «`N_obs` cuenta **azules** del flujo
> canónico en la ventana de `W` índices de PoT», debe decir:
>
> «`N_obs` cuenta, en la ventana de `W` índices de PoT del flujo canónico, **exactamente los
> bloques que cobran por R-FIN-8′** — azules y `rojo_k` —, es decir **un bloque por identidad de
> billete**. Los `rojo_U3` (copias) **no cuentan**, igual que no cobran.»
>
> **Invariante de diseño que la enmienda instituye:** *el conjunto que el retarget CUENTA y el
> conjunto que la emisión PAGA son el mismo conjunto.* Si el pagado excede al contado, la emisión
> corre por delante del calendario y el exceso se lo lleva quien lo provoca; si el contado excede
> al pagado, `λ_real` se infla. Las dos direcciones están medidas en §C.2 y §C.8.
>
> **Consecuencia, MEDIDA (§C.8, 12 semillas, `k = 30`, `α = 0`…0,40):** la inflación del retarget
> bajo ataque parásito cae de **×1,452** (contando azules) a **×1,005** (contando también los
> `rojo_k`). **La nota `research/dag-poas-delta-real.md` deja de aplicar**: `λ_real ≈ λ_obj` y
> `δ_real ≈ δ_nominal`. Con los propios números de ese fichero (`k = 30`): `δ` 0,267 → **0,211**,
> umbral de **orden** 40,0 % → **41,7 %**, `r = 1` en 42,3 % → **43,1 %**.
>
> **LAGUNA declarada:** Kaspa además excluye del conteo (y del subsidio del rojo) los bloques del
> mergeset con `blue_score < lowest_daa_blue_score` (`mergeset_non_daa`, `difficulty.rs:155-163`;
> `coinbase.rs:123`). R-FIN-13 define su ventana sobre **índices de PoT**, no sobre `blue_score`, y
> **no está escrito** qué pasa con un bloque fusionado cuyo `slot` cae fuera de la ventana vigente.
> Hay que redactarlo; no lo he medido.

---

## F · Veredicto y errores propios

### F.1 · Veredicto por punto

| Punto | Afirmación | **Etiqueta** | Número que la sostiene |
|---|---|---|---|
| **A** | «Los dos motivos de R-FIN-8 son obsoletos con U2 + U3″ porque cada billete paga una vez» | **REFUTADO** | U3″ da **1 azul** por identidad pero **13–699 rojos válidos y fusionados**; **×14,706** por billete a `m = 50`; asíntota **×15** = `max_block_parents` |
| **A** | El ×N está acotado por `max_block_parents − 1 = 14` copias por bloque del atacante | **DEMOSTRADO** (construcción determinista + control positivo `U2` / `TooManyParents`) | `salida_a.txt` |
| **B(i)** | «Los rojos cobran» = semántica de Kaspa | **REFUTADO** | `coinbase.rs:121-131`: el rojo **no** cobra; su subsidio+comisiones van agregados a la `script_public_key` del **fusionador** |
| **B(ii)** | «Sus transacciones se aplican en el orden del mergeset si no entran en conflicto» = Kaspa | **VERIFICADO** | `utxo_validation.rs:106-176` + `ghostdag.rs:115-136` + `:311-313` (conflicto ⇒ descarte silencioso); `.skip(1)` en `:308`/`:335` (la coinbase del fusionado no se aplica) |
| **B** | «dentro de `merge_depth`» | **REFUTADO** como cláusula: es **vacua** (fuera de profundidad el fusionador es inválido, `post_pow_validation.rs:96`) **y errónea** para los *kosherizing blues* (`block_depth.rs:109-119`), que sí se fusionan y sí cobran | — |
| **C.2/C.3** | Con P1 literal hay inflación de cuota y espacio de bloque gratis | **CONFIRMADO** | retarget ×**14,442** contando todos los válidos; ×**1,000** contando 1 por identidad |
| **C.4** | Con P1 la parásita deja de ser rentable pero también deja de costar | **DEMOSTRADO** | 1,16-1,55 → 0,99; y 0,319 → 0,976 a `α = 0,10` |
| **C.4** | P1 quita la presión económica hacia la puntualidad (δ «natural» mayor) | **PLAUSIBLE** — no medido | — |
| **C.5** | P1 desplaza todo el *griefing* a R-FIN-1a (invalidar en vez de enrojecer) | **PLAUSIBLE** (la superficie está medida por D8 A3: 11,7-24,2 bloques/h a `S_max = 20 s`, **0/h** a `S_max ≥ 30 s`) | — |
| **C.8** | Si R-FIN-13 cuenta los rojos-`k`, `dag-poas-delta-real.md` deja de aplicar | **DEMOSTRADO** | inflación **×1,452 → ×1,005**; `α = 0` da 1,0000 por las dos reglas |
| **C.9** | P1 es «la palanca más barata: una regla» | **PLAUSIBLE sólo con la variante recomendada.** Con la variante Kaspa hay que reescribir `C-EMIT-03` y revisar `C-HDR-08` (`SPEC.md:858-861`, `:1532-1533`) | — |
| **D** | Control positivo | **SUPERADO** | 0,996 / 1,160 / 1,271 / 1,548 vs 0,995 / 1,159 / 1,270 / 1,549; \|dif\| ≤ 0,0015 |
| **D** | P1 (tal como está escrita) anula la rentabilidad de la parásita | **DEMOSTRADO** | ratio **0,988–0,999** en todo `α`; `S1_h = 1,0000` |
| **D** | «Llevar R-FIN-8 a la semántica de **Kaspa**» | **REFUTADO** | ratio **1,498 / 1,650 / 2,029 / 2,069 / 2,240 / 2,792** — peor que el statu quo en **toda** fila |
| **E** | Texto de R-FIN-8′ y R-FIN-13′ | entregado arriba | — |

### F.2 · Respuesta a la pregunta del encargo

- **¿Es P1 segura?** **No como está escrita.** Le falta la cláusula `rojo_U3`; sin ella reabre los
  dos motivos originales de R-FIN-8 con un factor **×15**, mayor que el ×10 de la ronda 1 porque
  `max_block_parents` subió de 10 a 15.
- **¿Es exacta en su texto?** **No.** «Semántica de Kaspa» y «los rojos cobran» son reglas
  **distintas**, y la que P1 quiere es la que **no** es de Kaspa. La cláusula «dentro de
  `merge_depth`» es vacua y errónea. Y no declara su efecto sobre `C-EMIT-03` / `C-HDR-08`.
- **¿Cuánto cierra?** Con la cláusula `rojo_U3` añadida (R-FIN-8′), **cierra las tres**: (i) la
  ganancia (1,16-1,55 → 0,99), (ii) la reversión de transacciones (`S1_h = 1,0000`), (iii) la
  inflación del retarget (×1,452 → ×1,005, y con ella la nota `delta-real`, que vale +1,7 puntos
  de umbral de orden y +0,8 de `r = 1`). **No cierra** el ataque en sí: `δ` sigue igual, y ahora
  parasitar es gratis también a `α` pequeño.

### F.3 · Mis errores y las lagunas que dejo (regla 10)

1. **Acepté sin comprobar el encuadre del encargo durante media hora.** El encargo dice «llevar
   R-FIN-8 a la semántica de Kaspa», y el texto de P1 **no es** la semántica de Kaspa. Debí verlo
   al leer `coinbase.rs:131` y no al medir S2. La medida existe porque desconfié tarde.
2. **La ruta del encargo `consensus/src/processes/coinbase/mod.rs` no existe**; el fichero es
   `consensus/src/processes/coinbase.rs`. Lo corregí sin decirlo hasta §B.
3. **Mi agregación en §D no es la de `a1e`:** yo sumo sobre las 12 semillas, `d8_a1e_coste.py`
   promedia fracciones por semilla. De ahí la diferencia de 0,0008-0,0015 del control. **Es una
   discrepancia real, no ruido**, y la declaro en vez de esconderla; no cambia ninguna conclusión.
4. **La fila `m = 1, n = 0` de C2 da inflación 0,667 (< 1)**: es un artefacto de contar génesis y
   `H0` como billetes en un DAG de 3 bloques. **No mide nada**; sólo la tendencia de la columna es
   interpretable. La dejo impresa en vez de recortarla.
5. **`r8c_gd.py` no implementa `check_bounded_merge_depth`.** La construcción de §A supone
   `m ≤ merge_depth` sin comprobarlo. Con `merge_depth = 3 600·bps` (`constants.rs:81`) hay margen
   de sobra, pero **es una suposición, no una medida**.
6. **LAGUNA — no he medido la parásita Y las copias a la vez.** §A y §D son experimentos
   ortogonales (en `MundoL9` cada evento lleva `ident` única, `r8c_sim.py:46-48`). Un atacante
   podría componer las dos maniobras; **no sé cuánto suman**.
7. **LAGUNA — el residuo de incentivo a fusionar.** Con la coinbase propia (E.2 punto 2) nadie
   cobra por incluir a un rojo. Kaspa paga al fusionador **precisamente por eso**. R-FIN-12 adopta
   `pick_virtual_parents` como consenso, así que la conducta no depende del incentivo, pero **no he
   medido si un granjero racional se desviaría**. Si hubiera que darle algo, la variante mínima
   sería *sólo las comisiones* del rojo al fusionador, dejándole el subsidio al productor — y **eso
   tampoco lo he medido**.
8. **LAGUNA — `mergeset_non_daa`.** R-FIN-13′ no dice qué pasa con un bloque fusionado cuyo `slot`
   cae fuera de la ventana vigente (§E.3).
9. **LAGUNA — C.4 y C.5 son PLAUSIBLE, no medidos**: el `δ` por pereza y el desplazamiento del
   *griefing* hacia R-FIN-1a.

### F.4 · `AUDITA_SCRIPTS.py` (regla 5)

```
$ python3 research/scripts/AUDITA_SCRIPTS.py research/scripts/d9-ronda9b
Scripts analizados: 3

research/scripts/d9-ronda9b/r9b_a_copias.py
   [T3b] L105: ['d', 'd2'] = MISMA expresión: DAG(k=K, u2=True, u3_mode='dynamic', max_parents=MAXP)

======================================================================
Sospechas totales: 1
```
Salida completa en `salida_audita.txt`. **Marca leída:** `d` y `d2` son dos DAG **independientes**
de la sección de control positivo — `d` para el control de `U2` (copia colgada de otra copia) y
`d2` para el de `TooManyParents` (21 padres). **No se comparan entre sí** ni se usa una para
derivar la otra: T3b busca el patrón de `d8b_b3` (dos variables «distintas» con el mismo valor,
comparadas después) y aquí ese patrón no está. **Falso positivo, declarado.**
Los otros dos scripts (`r9b_d_coste.py`, `r9b_c_retarget.py`) salen **sin marcas**; ambos llevan
`SEMS = list(range(1, 13))` (12 semillas literales, T4 no dispara) y `alpha` vivo en toda función.

---

**Ficheros de esta ronda:** `research/scripts/d9-ronda9b/` — `informe.md` (este),
`r9b_a_copias.py` / `salida_a.txt`, `r9b_c_retarget.py` / `salida_c.txt`,
`r9b_d_coste.py` / `salida_d.txt`, `salida_audita.txt`.
