# D9 — Ronda 9c: la palanca P4 (steering acotado por el PoT secuencial)

**Fecha de inicio:** 2026-09-08
**Encargo:** auditar si el steering del atacante está acotado por la ventana de decisión
del ancla `W_dec` y no por la época `I`, dado que los retos salen del PoT secuencial.

**Estado:** EN CURSO — volcado incremental.

## Índice
- A. Qué dice el diseño (reto por slot: ¿definido?)
- B. Qué hace Autonomys (cadena de derivación entropía → reto)
- C. La ventana de decisión W_dec (formal y medida)
- D. El steering con evaluación acotada
- E. Contraataques
- F. Texto de R-FIN-14
- G. Veredicto y errores propios

---

## A · Qué dice el diseño sobre el reto por slot — **LAGUNA CONFIRMADA**

Leídas las reglas en `research/dag-poas-ancla-de-orden.md` (L162-282) y en
`research/dag-poas-ancla-de-finalidad.md` (L105-135, L310-325).

| Regla | Línea | Qué fija | ¿Fija el reto del slot? |
|---|---|---|---|
| R-FIN-1 | `ancla-de-orden.md:162-166` | `I_j` = bloque de cadena seleccionada con **menor `blue_work`** entre los de `slot ≥ T_j`; `T_j = j·I` índice de PoT | no |
| R-FIN-1a | `:184-190` | `slot(sp(B)) ≤ slot(B)` y `slot(B) − slot(sp(B)) ≤ S_max ∈ [20,150] s` | no |
| R-FIN-2 | `:191-194` | `entropía_j = blake3(chunk(I_j) ‖ pot_output(I_j))`; `t_j = slot(I_j) + L` | no |
| R-FIN-3 | `:195-197` | `flujo(B,s) = H(flujo(B,t_{j−1}) ‖ entropía_j ‖ t_j)` para la última inyección con `t_j ≤ s` | **no** |
| R-FIN-4 | `:199-202` | «`B` es válido si su solución verifica **bajo `flujo(B, slot(B))`**, su justificación de PoT cubre **desde el slot futuro de `sp(B)` hasta `slot(B)` bajo ese flujo**» | no — dice *bajo qué flujo*, no *cómo* |
| R-FIN-9 | `:279-281` | los cambios de `slot_iterations` se leen del índice `c·j` y se aplican en `t_j` | no |
| R-FIN-13 | `:219-226` | `W_RETARGET ≥ 3 083 slots`; **`slot` es el índice de PoT, no el sello de la cabecera** | no |

**Hallazgo A1 (LAGUNA).** Ninguna regla escribe la función `reto(flujo, s)`. Y no puede ser
`flujo(B,s)` a secas: R-FIN-3 hace `flujo` **constante dentro de la época** (solo cambia en `t_j`),
así que un reto = `flujo` daría el **mismo reto a los 4 200 slots de la época** — el mismo ganador
siempre. Hace falta una derivación por slot, y no está.

**Hallazgo A2 (las dos lecturas posibles, con consecuencias opuestas).**

- **(i) `reto(s) = H(flujo ‖ s)`** — no secuencial. Conocida `entropía_j`, el atacante calcula los
  4 200 retos de la época **de golpe**, en microsegundos. `n_eval = I`. El steering de las rondas
  3-8 (`c_m·√(αλI)`) es **exacto**.
- **(ii) «como Autonomys»** — el reto sale de `pot_output(s)`, y `pot_output(s)` exige recorrer la
  cadena AES desde la re-siembra. `n_eval = ρ·W_dec`. El steering baja por `√(n_eval/I)`.

**Qué apunta a (ii), aunque nadie lo escribió.** R-FIN-4 exige que «la justificación de PoT cubra
desde el slot futuro de `sp(B)` hasta `slot(B)` **bajo ese flujo**». Eso es literalmente el
`SubspaceJustification::PotCheckpoints` de Autonomys (`crates/sc-consensus-subspace/src/verifier.rs:255-290`)
y solo tiene sentido si **existe una cadena de PoT por flujo**, re-sembrada en `t_j`. Si el reto
fuese `H(flujo ‖ s)`, la cadena de PoT por flujo no haría falta para la lotería (seguiría haciendo
falta como reloj, para el `slot`). Además R-FIN-9 mueve `slot_iterations` con la entropía —eso es
`PotParametersChange` de Autonomys, que lleva **`slot`, `slot_iterations` y `entropy` juntos**
(`crates/sp-consensus-subspace/src/lib.rs:139-149`): copiar esa estructura y no copiar la
re-siembra sería incoherente.

**Y la nota de la ronda 7 (`ancla-de-finalidad.md:319-322`)** —«Revelación retardada por VDF
(`entropía_j = VDF(chunk ‖ pot_output, L·iter)`), reduce el lookahead de `L + I(1−1/v)` a
`(L+I)(1−1/v)` … se deja fuera del núcleo»— **muestra que la ronda 7 modelaba el lookahead como si
conocer `entropía_j` bastase para conocer toda la época.** Es decir: la ronda 7 razonaba en la
lectura **(i)**. Ninguna ronda posterior lo corrigió.

**Veredicto A: LAGUNA.** El reto por slot no está definido; el diseño es ambiguo entre dos lecturas
con un factor `√(I/(ρ·W_dec)) ≈ 2,4-5,3` de diferencia en el steering. Texto propuesto: §F (R-FIN-14).

---

## B · Qué hace Autonomys — la cadena de derivación completa, con fuente

Clon `/home/katana/zeo/fuentes/subspace` @ `f8842d0` (verificado con `git log --oneline -1`).

### B.1 · De la entropía a la semilla del PoT

1. **Se cosecha** en cada bloque múltiplo de `POT_ENTROPY_INJECTION_INTERVAL = 50`
   (`crates/pallet-subspace/src/lib.rs:949-956`):
   `derive_pot_entropy(chunk, proof_of_time) = blake3_hash_list([chunk, pot_output])`
   (`crates/subspace-verification/src/lib.rs:442-446`). **Es exactamente la `entropía_j` de R-FIN-2.**
2. **Se le fija el slot objetivo** `lookback_in_blocks = INTERVAL · LOOKBACK_DEPTH = 50·2 = 100`
   bloques después (`:942-944`, `:964-971`):
   `target_slot = pre_digest.slot() + POT_ENTROPY_INJECTION_DELAY (15)`.
3. **Se publica** como `PotParametersChange { slot: target_slot, slot_iterations, entropy }`
   (`crates/sp-consensus-subspace/src/lib.rs:139-149`) — entropía **y** `slot_iterations` en la
   misma estructura, en el mismo slot. Es la unión de R-FIN-2 y R-FIN-9.
4. **Se mezcla en la cadena de PoT, en un solo slot exacto**
   (`crates/sp-consensus-subspace/src/lib.rs:118-129`):
   ```rust
   if parameters_change.slot == next_slot {
       seed = parent_output.seed_with_entropy(&parameters_change.entropy);
   } else { seed = parent_output.seed(); }
   ```
   `seed_with_entropy(e) = blake3_hash_list([e, pot_output])[..16]`
   (`crates/subspace-core-primitives/src/pot.rs:288-294`).
   **Verificado: «antes de `t_j` la entropía no se mezcla» (R-FIN-2) es literalmente cierto en el código.**

### B.2 · De la semilla al reto del slot `s` — **cadena estrictamente secuencial**

```
seed(t_j)            = blake3(entropía_j ‖ pot_output(t_j−1))[..16]        pot.rs:288-294
pot_output(s)        = AES^{slot_iterations}( pot_output(s−1) )            (prove, subspace-proof-of-time)
                       — 206 557 520 iteraciones/slot en mainnet, chain_spec.rs:128-130
global_randomness(s) = blake3( pot_output(s) )                             pot.rs:277-280
global_challenge(s)  = blake3( global_randomness(s) ‖ s.to_le_bytes() )    lib.rs:108-112
sector_slot_challenge= sector_id.derive_sector_slot_challenge(global_challenge)   verification/lib.rs:235-237
s_bucket_audit_index = sector_slot_challenge.s_bucket_audit_index()        verification/lib.rs:238
solution_distance    = calculate_solution_distance(global_challenge, masked_chunk, sector_slot_challenge)
                                                                            verification/lib.rs:250-252
gana si solution_distance ≤ solution_range/2                                verification/lib.rs:254-260
```

**El punto decisivo: `s` entra dos veces —como contador en `derive_global_challenge` y como
profundidad de la cadena AES en `pot_output(s)`— y la segunda no se puede saltar.** Para conocer el
reto del slot `t_j + n` hay que ejecutar `n` slots de AES secuencial desde la re-siembra.
`derive_global_challenge` **por sí sola no es una PRF sobre la época**: su entrada `Randomness`
cambia en cada slot.

### B.3 · Con qué slot — respuesta: con **el suyo**, no `s − DELAY`

- El bloque de slot `s` lleva `proof_of_time = pot_checkpoints[s].output()`
  (`crates/sc-consensus-subspace/src/slot_worker.rs:400`) y se verifica con ese mismo `slot`
  (`crates/subspace-verification/src/lib.rs:234-235`).
- `BLOCK_AUTHORING_DELAY = 4` **no retrasa el reto**: retrasa *qué slot se reclama*. El granjero
  reclama `slot_to_claim = slot_probado − 4` (`crates/sc-proof-of-time/src/lib.rs:106-107`) y debe
  además incluir `future_proof_of_time = pot_output(s+4)`
  (`slot_worker.rs:405`, `verifier.rs:262-267`). Efecto neto: el reto del slot `s` se conoce en el
  instante `s`, el granjero tiene 4 s para auditar, y el bloque no se puede **publicar** hasta `s+4`.
- Restricción de consenso: `const_assert!(POT_ENTROPY_INJECTION_DELAY > BLOCK_AUTHORING_DELAY + 1)`
  y `INTERVAL > DELAY` (`crates/subspace-runtime/src/lib.rs:159-165`).

### B.4 · Corrección a siete rondas: el «lookahead de 11 s» de Autonomys está mal contado

`ancla-de-orden.md:257` dice *«El "11 s" que citaban siete rondas es `DELAY − AUTHORING_DELAY = 15 − 4`»*.
Eso es la holgura de autoría, no el lookahead. El lookahead real de Autonomys —tiempo entre que
`entropía_j` es **pública** (bloque `n`, múltiplo de 50) y el slot en que **surte efecto**— es
`lookback_in_blocks = 100` bloques ≈ **600 s** (a 6 slots/bloque), más 15 slots: **≈ 615 s ≈ 10,2 min**,
no 11 s (`pallet-subspace/src/lib.rs:942-944` y `:964-971`). No cambia P4, pero sí el denominador de
la premisa 1 de la ronda 7 (`ancla-de-finalidad.md:15-22`): ZEROX con `L+I ≈ 6,5 h` está **38×** el
lookahead de Autonomys, no 2 100×.

**Veredicto B: VERIFICADO** (cadena de derivación completa, con fichero y línea; secuencialidad
demostrada por construcción de la cadena AES).

---

## Controles (regla de método 4) — `r9c_c0_control.py`, `salida_c0.txt`

| Control | Resultado |
|---|---|
| C1 · `c_m` contra lo publicado (`dag-poas-voto-auditoria.md` L199) | `c_2 = 0,5642` (pub. 0,564), `c_4 = 1,0294` (pub. 1,029) — **OK** |
| C2 · negativo, `α = 0` | menú del ancla = **1** en las 12 semillas y en los dos `S_max`. El instrumento no inventa cambios |
| C3 · positivo, `α > 0`, decisión libre | el ancla **sí** cambia: 6/12 mundos a `α=0,10`; **12/12** a 0,25 / 0,33 / 0,40; hasta **4 anclas distintas**. El instrumento no es ciego |
| C4 · R-FIN-1a | **0 violaciones** en 751 053 aristas de cadena comprobadas |
| C5 · lectura del ancla | «menor `blue_work` con `slot ≥ T`» ≡ «primero de la cadena con `slot ≥ T`»: 540 comprobaciones, **0 discrepancias** |

**Cobertura de rama** (`COB`, tras C0): `sp_filtrado_h = 124`, `sin_sp_h = 12`,
`sp_filtrado_a = 2`, **`sin_sp_a = 0` — rama NO EJERCITADA**, se declara: nunca ocurrió que el
atacante se quedase sin ningún padre válido bajo R-FIN-1a. `bloques_h = 1 201 200`,
`bloques_a = 385 886`, `retenidos = 17 438`, `liberados = 15 518`.

---

## D · El steering con evaluación acotada — `r9c_d1_steering.py`, `salida_d1.txt`

### D.1 · ¿Es exacta la fórmula `c_m·√(αλ·n_eval)`? — sí, y ligeramente **conservadora**

Simulación de la lotería: `m` corrientes Poisson independientes, se observan los `n_eval`
primeros slots de cada una, se elige la de más victorias, y se suman las victorias del resto
de la época. 12 semillas literales × 40 000 épocas, `I = 4 200`, Poisson exacto (numpy).

| `α` | `m` | `n_eval` | ganancia medida | `c_m·√(αλn)` | razón | `E[resto]` medido | teórico |
|---:|---:|---:|---:|---:|---:|---:|---:|
| **0,00** | 3 | 150 | **0,000** | 0,000 | — | 0,00 | 0,00 |
| 0,10 | 3 | 150 | 3,285 | 3,278 | **1,002** | 404,99 | 405,00 |
| 0,10 | 3 | 4 200 | 17,345 | 17,344 | **1,000** | 0,00 | 0,00 |
| 0,25 | 3 | 150 | 5,184 | 5,182 | **1,000** | 1 012,48 | 1 012,50 |
| 0,33 | 3 | 150 | 5,951 | 5,954 | **0,999** | 1 336,47 | 1 336,50 |
| 0,40 | 3 | 150 | 6,540 | 6,555 | 0,998 | 1 619,96 | 1 620,00 |
| 0,33 | 23 | 150 | 14,023 | 13,573 | 1,033 | 1 336,48 | 1 336,50 |
| 0,33 | 151 | 150 | 19,646 | 18,655 | **1,053** | 1 336,51 | 1 336,50 |

- **Exacta para `m` pequeña** (razón 0,998-1,002), la que decide el diseño.
- **Subestima 3-10 % para `m` grande** (23, 151): `c_m` es la esperanza del máximo de `m`
  **normales**, y el máximo de `m` Poisson con media 15-60 es algo mayor por la asimetría.
  Es un error **a favor del atacante** en las tablas publicadas — pequeño, y se declara.
- `E[resto]` coincide con `(I − n_eval)·αλ` en las 4 cifras: **la selección no contamina el
  resto de la época**.

> **Corrección de mi propio método (regla 10).** Que `E[resto]` salga exacto **no lo demuestra**:
> en mi simulación el resto se sortea independiente **por construcción**. Lo que sí es
> argumento: por R-FIN-2/R-FIN-3 la entropía es **una sola por época** y el reto de cada slot
> sale del PoT, que no depende de qué bloques se hayan minado; modelando `blake3∘AES` como
> oráculo aleatorio, los slots `> n_eval` son independientes de los `≤ n_eval`.
> **PLAUSIBLE, no DEMOSTRADO.** Residuo declarado: el **retarget** sí acopla (una racha
> temprana estrecha `solution_range`), y el acoplamiento va **en contra** del atacante.

### D.2 · Control de reproducción, y la tabla recalculada

Control (lectura LIBRE, `m_dis = 2,822`, `α_cal = 0,10`, `A* = 4,1 h` esc. B con plotter 10×):

| `g` | `I` | `F` | `I+F` | `α_ef(m=2,8)` | `α_ef(m=151)` | margen |
|---:|---:|---:|---:|---:|---:|---:|
| 3,6 % | 4 890 s | 6,17 h | 7,53 h | 33,4 % | 34,5 % | 0,54× |
| 7,0 % | 1 293 s | 1,63 h | 1,99 h | 33,9 % | 35,8 % | 2,06× |

**Idénticos a los publicados** en `dag-poas-tras-d8-palancas.md` §2 P3. El instrumento reproduce.

**Hallazgo D2 (el que importa, y que P4 no dice).** `α_ef` a un `g` objetivo dado **no cambia**
con la evaluación acotada: es una identidad, `g(33 %) = g_obj·(c_{m_compra}/c_{m_dis})·√(α_cal/0,33)`
en las dos lecturas. **Lo que cambia es el PRECIO de ese `g`:** `I` deja de escalar como `1/g²`
y pasa a escalar como `1/g`, y sobre todo deja de escalar con `I` mismo:

```
LIBRE   :  I = (c_m/g)² / (αλ)                    (n_eval = I, autoreferente)
ACOTADA :  I = c_m·√(n_eval/(αλ)) / g             (n_eval constante, exógena)
```

Tabla P3 **recalculada** (`m_dis = 2,955`; `α_ef` a `α = 0,33`; `A* = 4,1 h`):

| lectura | `g` | `I` | `F` | `I+F` | `α_ef(m=2,955)` | `α_ef(m=23)` | `α_ef(m=151)` | margen |
|---|---:|---:|---:|---:|---:|---:|---:|---:|
| LIBRE (hoy) | 3,6 % | 5 362 s | 6,77 h | 8,26 h | 33,44 % | 34,01 % | 34,39 % | **0,50×** |
| LIBRE | 7,0 % | 1 418 s | 1,79 h | 2,18 h | 33,85 % | 34,97 % | 35,71 % | 1,88× |
| **`n_eval`=150** | **3,6 %** | **897 s** | **1,13 h** | **1,38 h** | 33,44 % | 34,01 % | 34,39 % | **2,97×** |
| `n_eval`=150 | 7,0 % | 461 s | 0,58 h | 0,71 h | 33,85 % | 34,97 % | 35,71 % | 5,77× |
| `n_eval`=225 (ρ=1,5) | 3,6 % | 1 099 s | 1,39 h | 1,69 h | 33,44 % | 34,01 % | 34,39 % | 2,42× |
| `n_eval`=450 (ρ=3) | 3,6 % | 1 554 s | 1,96 h | 2,39 h | 33,44 % | 34,01 % | 34,39 % | 1,71× |
| `n_eval`=45 (carrera `k`) | 3,6 % | 491 s | 0,62 h | 0,76 h | 33,44 % | 34,01 % | 34,39 % | 5,42× |

**Lo que compra P4, en una línea:** con el **mismo** steering (3,6 %) y el **mismo** `α_ef`,
`I+F` baja de **8,26 h a 1,38 h** (×6,0) y el margen económico frente a un plotter 10× pasa de
**0,50× (INSUFICIENTE) a 2,97× (suficiente)**. `F = 5,3 h` se convierte en `F ≈ 1,1 h`.

`c_m` usados (integración numérica, `r8c_steering.c_m`): `c_2,822 = 0,7961`,
`c_2,955 = 0,8336`, `c_23 = 1,9292`, `c_151 = 2,6515`.

**Veredicto D: VERIFICADO** que la fórmula `c_m·√(αλ·n_eval)` es correcta (conservadora ≤ 5,3 %
para `m ≤ 151`); **REFUTADO el enunciado de P4 en su parte de `α_ef`** («el steering baja por
`√(n_eval/I)`» es cierto **a `I` fija**, pero la propuesta *deriva* `I` del steering: a `g`
objetivo fijo, `α_ef` no se mueve). **DEMOSTRADO** el beneficio real: es en `I`, `F` y el
margen económico.

---

## E · Contraataques — `r9c_e1_contraataques.py`, `salida_e1.txt`

### E.1 · ¿Puede precomputar los candidatos ANTES de `T_j`? — **No los candidatos; SÍ la cadena común. Y eso es lo que decide todo.**

El candidato `X` no cambia nada de la cadena de PoT **hasta `t_j = slot(X) + L`**. Su semilla ahí
es `blake3(entropía_X ‖ pot_out(t_j − 1))` (Autonomys `PotOutput::seed_with_entropy`,
`crates/subspace-core-primitives/src/pot.rs:288-294`, aplicada solo en el slot exacto,
`crates/sp-consensus-subspace/src/lib.rs:118-129`). Luego **evaluar un solo slot de un candidato
exige estar YA en el slot `t_j − 1` de la cadena común.** Eso es una carrera de VDF.

**La cota de conocimiento (nueva, y P4 no la vio).** En el instante `u` el atacante conoce
`entropía_i` para toda época `i` con ancla cerrada, es decir `T_i + W_dec ≤ u`; la última inyección
que puede calcular es la siguiente a esa, en el slot `≈ u − W_dec + L + I`. Luego su
**ventaja máxima sobre el timekeeper es `L + I − W_dec` slots = 23 130 slots** con `L = 5,3 h`,
`I = 4 200 s`, `W_dec = 150 s`. Necesita ventaja `L = 19 080` para estar en `t_j − 1` en el
instante `T_j`. **La cota lo permite** (porque `L + I − W_dec > L` ⟺ `I > W_dec`).

**La cota de velocidad la cierra.** La cota de conocimiento avanza a **1 slot/s de media** (salta
`I` slots cada `I` s). Luego:

| `ρ` | ¿crece la ventaja? | bootstrap hasta el tope (`W_dec = 150`) | `n_eval` por candidato |
|---:|---|---:|---:|
| **≤ 1,0** | **no** — se queda en la que tenga; si empieza en 0, sigue en 0 | ∞ | **0** |
| 1,01 | sí, a 0,01 slot/s | 642,5 h (26,8 días) | 152 |
| 1,05 | sí | 128,5 h (5,4 días) | 158 |
| 1,15 | sí | 42,8 h | 172 |
| 1,5 | sí | 12,8 h | 225 |
| 3,0 | sí | 3,2 h | 450 |

**Hallazgo E1 (corrige P4).** `n_eval = ρ·W_dec` **solo si `ρ > 1`** y tras un *bootstrap* de días.
Con `ρ ≤ 1` el steering por elección de ancla es **exactamente 0**, no `W_dec`. P4 escribe
«ρ ∈ {1; 1,5; 3}» y la fila `ρ = 1` es **0, no 150**.
Y las cadenas post-inyección de candidatos distintos son **independientes** ⇒ paralelizables:
con `m` unidades AES el atacante consigue `ρ·W_dec` slots **por candidato**, no repartidos.

### E.2 · ¿Mantener varios candidatos abiertos más allá de `W_dec`?

`W_dec` es, por definición, el último instante en que **una acción suya** cambia el ancla. Dos
puntas propias en el anticono de `T_j`, si las publica y deja que los honestos elijan, **no son
steering**: no elige él. Para elegir tiene que actuar (publicar una y retener la otra), y esa
acción cae dentro de `W_dec`. La cota estructural es R-FIN-1a: un bloque retenido más de `S_max`
segundos **no puede ser extendido por ningún bloque válido posterior** (`slot(B) − slot(sp(B)) ≤ S_max`
con `slot` en tiempo real), luego deja de ser candidato a estar en la cadena seleccionada.
Medido en C.

### E.3 · ¿Cuánto `ρ` para evaluar la ÉPOCA ENTERA dentro de `W_dec`? — `ρ ≥ I/W_dec`

| `I` | `W_dec=45` | `W_dec=150` | `W_dec=225` | `W_dec=300` |
|---:|---:|---:|---:|---:|
| 461 s | 10,2 | 3,1 | 2,0 | **1,5** |
| 897 s | 19,9 | 6,0 | 4,0 | 3,0 |
| 4 200 s | 93,3 | 28,0 | 18,7 | 14,0 |

**Cota física de `ρ`:** la cadena de PoT es AES-128 **secuencial**; `ρ = reloj_atacante /
reloj_referencia`. Autonomys calibra `pot_slot_iterations = 206 557 520` para ≈ 1 s en un
**14900KS a 6,2 GHz** (`crates/subspace-node/src/chain_spec.rs:128-130`), que es el tope del
mercado ⇒ `ρ ∈ [1; ~1,2]`. **`ρ ≥ 3` no es alcanzable con silicio de consumo.** Aviso: si `I` se
recalibra a ~460 s (la fila `g = 7 %` acotada), un `ρ = 1,5` con `W_dec = 300` **sí** evaluaría la
época entera y P4 se anularía a sí misma. **`I` no debe bajar de `≈ ρ_max·W_dec`.**

### E.4 · ¿Acortar `S_max` solo por esto? — se responde con la medida de C (§C)

Coste conocido (D8 A3, `dag-poas-ancla-de-orden-auditoria-7.md`): `S_max = 20 s` invalida el
**71-75 %** de los bloques de un granjero con 20 s de retraso; el agente principal lo re-instrumentó
y en régimen sale **77 %**. Es un precio de censura de granjeros lentos, no de seguridad.

### E.5 · La palanca que SÍ cierra `n_eval` a 0 para cualquier `ρ` — **revelación retardada**

`dag-poas-ancla-de-finalidad.md:319-322` la describió y la **descartó**
(«`entropía_j = VDF(chunk ‖ pot_output, L·iter)`, al estilo del ICC de Chia … se deja fuera del
núcleo»). Con ella, `entropía_j` **no se conoce hasta `t_j`**, y la cota de conocimiento pasa de
`L + I − W_dec` a **`I`** (solo puede calcular hasta la siguiente inyección aún no revelada).
Como el atacante necesita ventaja `L`:

```
ventaja disponible = I = 4 200   <   ventaja necesaria = L = 19 080     ⇒   n_eval = 0
```

**La condición es exactamente `L > I`** — la misma que la ronda 7 marcó como problema
(`ancla-de-finalidad.md:243`: «si `L ≥ I`, D9 debe mirar qué gana el atacante conociendo
`entropía_j` antes de que se elija `I_{j+1}`»). Con revelación retardada, `L > I` deja de ser un
problema y pasa a ser **la garantía**. Coste: un VDF más (el `L·iter` del ICC), que hay que
producir y verificar. **PLAUSIBLE, no medido.**

**Veredicto E: PLAUSIBLE con una corrección DEMOSTRADA a P4** (la fila `ρ = 1` es `n_eval = 0`,
no `n_eval = W_dec`) y **una LAGUNA nueva**: `I ≥ ρ_max·W_dec` es una restricción de diseño que
nadie escribió, y que se viola si `I` baja a ~460 s.

---

## F · Texto propuesto de **R-FIN-14** (no aplicado; `dag-poas-ancla-de-orden.md` no se toca)

> **R-FIN-14 · Reto por slot desde el PoT re-sembrado. (NUEVA, D9 ronda 9c.)**
> Cierra la laguna de que R-FIN-2/3/4 fijan *bajo qué flujo* se verifica una solución pero no
> *cómo* se obtiene el reto de cada slot. Es la regla de la que depende toda la cota `n_eval`.
>
> **(a) Cadena de PoT por flujo — SECUENCIAL.** Cada flujo `f` tiene una única cadena de PoT
> indexada por slot. Para todo slot `s > s₀(f)`:
> ```
> semilla(f, s) = blake3( entropía_j ‖ salida(f, s−1) )[0..16)     si s = t_j para alguna
>                                                                   inyección j de f (R-FIN-2)
>               = salida(f, s−1)                                   en cualquier otro caso
> salida(f, s)  = AES128_chain^{N(s)} ( semilla(f, s) )            (subspace-proof-of-time::prove)
> ```
> con `N(s)` el `slot_iterations` vigente en `s` (R-FIN-9), aplicado en el **mismo** slot `t_j`
> que la entropía, y `salida(f, s₀)` la salida heredada del flujo padre en la bifurcación.
> A lo sumo **una** inyección por slot.
>
> **(b) Reto global del slot.**
> ```
> aleatoriedad(f, s) = blake3( salida(f, s) )
> reto(f, s)         = blake3( aleatoriedad(f, s) ‖ LE64(s) )
> ```
>
> **(c) Validez de la solución.** Un bloque `B` con `slot(B) = s` y `f = flujo(B, s)` (R-FIN-3) es
> válido solo si, con `sector_id = H(pk ‖ sector_index ‖ history_size)` y
> `ssc = derive_sector_slot_challenge(sector_id, reto(f, s))`:
> (i) la prueba de espacio verifica en el s-bucket `s_bucket_audit_index(ssc)`;
> (ii) `solution_distance( reto(f,s), chunk ⊕ hash(PoS), ssc ) ≤ solution_range(B) / 2`.
> El `solution_range` es el del retarget de R-FIN-13.
>
> **(d) Justificación de PoT.** `B` **MUST** incluir los puntos de control que encadenan
> `salida(f, slot(sp(B)) + D)` → `salida(f, s + D)`, con `D` el retardo de autoría
> (`BLOCK_AUTHORING_DELAY` de Autonomys). R-FIN-1a acota esa cadena a `S_max` slots, luego a
> `S_max · 96,1 ms` de verificación en el peor caso. Un nodo **MUST NOT** verificar PoT de un
> flujo distinto del suyo (R-FIN-5): la comprobación de flujo es **anterior** a la de PoT.
>
> **(e) Prohibición explícita — es el contenido de seguridad de la regla.** El reto **MUST NOT**
> derivarse de ninguna función que permita **saltar slots**. En particular, `reto(f, s) =
> H(flujo(f) ‖ s)` y cualquier variante que sea PRF de `s` a partir de un valor fijo de la época
> están **PROHIBIDAS**. La secuencialidad de (a) es lo único que impide que el atacante evalúe la
> época entera de un candidato a ancla **antes** de tener que elegirlo, y es la hipótesis sobre la
> que se calcula `n_eval` y, con él, `I` y `F`.
>
> **(f) Restricción de calibración.** `I ≥ ρ_max · W_dec`, con `W_dec` la ventana de decisión del
> ancla (§C) y `ρ_max` la cota superior admitida para la velocidad de AES de un atacante frente al
> timekeeper. Con `W_dec` medida y `ρ_max = 1,5`, `I ≥ 450 s`. Si `I` baja de esa cota, el
> atacante evalúa la época entera dentro de `W_dec` y (e) deja de comprar nada.
>
> **(g) Unicidad de `t_j`.** Los `t_j` de inyecciones distintas **MUST** ser distintos dos a dos.
> Se cumple por construcción: `slot(I_j) ∈ [j·I, j·I + S_max)` (Cota E de R-FIN-1) y
> `S_max < I`, luego `slot(I_j)` es estrictamente creciente en `j` y `t_j = slot(I_j) + L`
> también. **DEMOSTRADO** dado `S_max < I` (150 < 4 200).
>
> **(h) Nota de diseño, con etiqueta.** Con `L > I` hay `⌈L/I⌉ = 5` inyecciones pendientes a la
> vez y sus entropías son **públicas antes de aplicarse**. Eso permite a un atacante con `ρ > 1`
> adelantar la cadena común hasta `L + I − W_dec` slots (§E.1). La variante **revelación
> retardada** —`entropía_j = VDF(chunk(I_j) ‖ salida(I_j), L·iteraciones)`, revelada en `t_j`—
> reduce esa ventaja a `I` y hace `n_eval = 0` para cualquier `ρ`, al coste de un VDF adicional.
> Queda como **opción**, no como núcleo.

---

## C · La ventana de decisión `W_dec` — MEDIDA

### C.0 · Definición formal

`I_j` es función de la cadena seleccionada final. Se define

> `W_dec` = el mayor `d` tal que existe una **acción del atacante tomada en `T_j + d`** —con
> **prefijo común**: todo lo anterior a `T_j + d` idéntico entre las ramas— que cambia `I_j`.
> `W_dec = −1` si ninguna decisión posterior a `T_j` cambia el ancla.

Vías medidas: **(i)** retener candidatos propios y **liberar uno** en `T_j+d`;
**(ii)** construir una cadena privada desde `T_j − P` (`P ∈ {0,30,90}`) y **soltarla o no** en `T_j+d`.

### C.1 · Tres instrumentos, y dos errores míos por el camino (regla 10)

| Versión | Error | Resultado (inválido / válido) |
|---|---|---|
| `r9c_c1_wdec.py` | **`menu ∪ {base}`**: `base` no comparte prefijo (no retiene nada), así que el contraste mezclaba una decisión de `T_j` con una de `T_j+d` | `W_dec` **saturaba la rejilla** (300 s) para `α ≥ 0,25`. **INVÁLIDO** |
| `r9c_c2_wdec.py` 1ª pasada | **el atacante «retenía» un bloque y publicaba un HIJO suyo.** En la red real publicar el hijo publica al padre (nadie valida sin él). Diagnosticado en `r9c_c3_diag.py`: el bloque que volteaba el ancla a `d = 600` era siempre el **primero** del lote, y estaba en la cadena final porque un hijo suyo, no retenido, lo arrastraba | `W_dec` = 600 s (saturada). **INVÁLIDO**. Corregido en `r9c_lib.py` con la **clausura de publicación** (`llega[ancestro] ← min(...)`, 994-1 021 disparos por corrida) |
| `r9c_c2` 2ª pasada | consistente pero **sobre-corregida**: retiene la ventana entera (el atacante tira todos sus bloques) | `W_dec ≤ 20 s`. Válida como **cota inferior** |
| **`r9c_c4_wdec.py`** | prefijo común barato: candidatos retenidos, **el resto del atacante en `tips_pub`** (cuelga solo de bloques ya publicados, así no delata a ninguno) | **VÁLIDA** |

> **Aviso para las rondas anteriores.** La clausura de publicación **no está** en `r8c_sim.py`
> (D9-c…D9-f) ni en `d8_lib.py`. Toda `m` medida allí «con retención» puede estar inflada por el
> mismo artefacto — el atacante retiene un bloque y publica un descendiente. **No lo he
> cuantificado**: queda como LAGUNA para quien revise D8 A4.2 (`m = 2,822`) y D9-f (`m = 3,64`).

### C.2 · Resultado (`r9c_c4_wdec.py`, `salida_c4.txt`; 12 semillas, `TJ = 200`, horizonte 1 000 s)

| `α` | `W_dec(i)` med / p90 / max | `W_dec(ii)` med / p90 / max | **unión** med / p90 / **max** | `T*` teórico `k/(1−2α)` |
|---:|---:|---:|---:|---:|
| **0,00** | −1 / −1 / **−1** | −1 / −1 / **−1** | −1 / −1 / **−1** | 30 |
| 0,10 | −1 / −1 / 10 | 0 / 10 / 10 | 0 / 10 / **10** | 38 |
| 0,25 | −1 / 10 / 20 | −1 / 0 / 10 | 0 / 10 / **20** | 60 |
| 0,33 | −1 / 20 / 20 | −1 / 20 / 20 | 10 / 20 / **20** | 88 |
| 0,40 | 10 / 20 / 20 | 10 / 45 / 45 | 10 / 45 / **45** | 150 |

**Idéntica con `S_max = 20 s` y con `S_max = 150 s`** (las dos mitades de `salida_c4.txt` coinciden
fila a fila). **`S_max` no es lo que cierra la ventana** — a `λ = 1` y `τ = 1 s` el salto natural de
slot en la cadena es de 1-3 s, y un bloque retenido 20 s ya es inextensible con las dos.
Lo que la cierra es **la carrera**: `W_dec ≈ 10-45 s`, por debajo de `T* = k/((1−2α)λ) = 38-150 s`
(la cota es cota, no realidad — regla 6).

**El menú por instante de decisión** (`m(d)` medio, vía i, `S_max=150`):

| `α` | d=0 | **d=10** | d=20 | d=45 | d=80 | … | d=450 |
|---:|---:|---:|---:|---:|---:|---|---:|
| **0,00** | 1,00 | **1,00** | 1,00 | 1,00 | 1,00 | | 1,00 |
| 0,10 | 1,00 | **1,17** | 1,00 | 1,00 | 1,00 | | 1,00 |
| 0,25 | 1,00 | **1,42** | 1,08 | 1,00 | 1,00 | | 1,00 |
| 0,33 | 1,00 | **1,58** | 1,17 | 1,00 | 1,00 | | 1,00 |
| 0,40 | 1,00 | **1,83** | 1,25 | 1,00 | 1,00 | | 1,00 |

El menú vive **en los primeros 10-20 s** tras `T_j` y está **cerrado a los 45 s**.

**Cobertura de rama** (`r9c_c4`): `sp_filtrado_h = 90`, `sin_sp_h = 180`,
`clausura_publicacion = 994`, `tips_pub = 3 394 962`, `menu_ge2 = 42`, `menu_ii_ge2 = 64`,
`anc_atac = 3 186`, `anc_hon = 10 774`, `recortes = 610` (el tope de 10 candidatos mordió),
`runs = 13 960`. **No ejercitadas: `sp_filtrado_a = 0`, `sin_sp_a = 0`** — se declaran.
`rfin1a_ok = 0` aquí porque la comprobación de R-FIN-1a corre en `r9c_c0` (751 053 aristas, 0
violaciones), no en este script.

**Veredicto C: VERIFICADO — y a favor de P4, con más margen del que P4 pedía.**
`W_dec ≤ 45 s` medida (≤ 20 s para `α ≤ 0,33`), no los 150 s de `S_max`.
**LAGUNA declarada:** el tope de 10 candidatos y la rejilla `{0,10,20,45,…}` acotan la resolución;
`W_dec` real está en `(20, 45]` a `α = 0,40`, no medida más fina.

### C.3 · La tabla P3 con la `W_dec` medida (`r9c_d2_final.py`, `salida_d2.txt`)

`m_dis = 2,955`, `α_cal = 0,10`, `α_ev = 0,33`, `W/κ = 1,22`, `A* = 4,1 h` (esc. B, plotter 10×):

| lectura | `g` | `I` | `F` | `I+F` | `α_ef(m=2,955)` | `α_ef(m=151)` | margen |
|---|---:|---:|---:|---:|---:|---:|---:|
| **LIBRE (publicado hoy)** | 3,6 % | 5 362 s | **6,77 h** | 8,26 h | 33,44 % | 34,39 % | **0,50×** |
| `n_eval = 20` (`W_dec=20`, `ρ=1`) | 3,6 % | 327 s | 0,41 h | 0,50 h | 33,44 % | 34,39 % | 8,13× |
| **`n_eval = 45`** (`W_dec=45`, `ρ=1`) | **3,6 %** | **491 s** | **0,62 h** | **0,76 h** | 33,44 % | 34,39 % | **5,42×** |
| `n_eval = 68` (`W_dec=45`, `ρ=1,5`) | 3,6 % | 602 s | 0,76 h | 0,93 h | 33,44 % | 34,39 % | 4,42× |
| `n_eval = 135` (`W_dec=45`, `ρ=3`) | 3,6 % | 851 s | 1,07 h | 1,31 h | 33,44 % | 34,39 % | 3,13× |

**`I+F` cae de 8,26 h a 0,76-1,31 h y el margen económico de 0,50× (insuficiente) a 3,1-5,4×.**

> **AVISO IMPORTANTE, que P4 no dice.** Con la pinza del steering desactivada, **`F` deja de estar
> fijada por el steering y pasa a estarlo por la carrera**: D8 midió `F_min(α=0,35) = 0,34 h` con
> `δ = 0` y **1,85 h** con el `δ` pesimista (`dag-poas-tras-d8-palancas.md` §2 P3). `F = 0,62 h`
> **estaría por debajo** de ese segundo valor. La constante que hay que fijar es
> `F = max(F_carrera, I/(W/κ−1))`, y con P4 el primer término manda. **No es «F = 0,62 h»: es
> «F ya no lo decide el steering».** Eso, y solo eso, es lo que P4 compra en `F`.
