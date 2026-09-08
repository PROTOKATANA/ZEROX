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
