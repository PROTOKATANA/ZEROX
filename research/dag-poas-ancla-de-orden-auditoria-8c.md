# Auditoría 9c — Palanca P4: el reto por slot y la ventana de decisión del steering

**Pregunta:** ¿cuánto steering puede ejercer de verdad el atacante si el reto de cada slot sale del PoT
secuencial, como en Autonomys? ¿Está eso definido en el diseño? · **Fecha:** 2026-09-08, tarde-noche · **Agente:**
9c en **Opus 5**, en paralelo con 9a y 9b · **Informe (546 líneas), 9 scripts, 8 salidas, 9 commits solo en su
directorio:** `research/scripts/d9-ronda9c/`.

> **VEREDICTO (mío, tras verificar citas y reproducir sus scripts):** P4 es **correcta en el mecanismo,
> conservadora en el número y mal enunciada en la conclusión.** (1) **LAGUNA confirmada:** ninguna regla escribe
> cómo se deriva el reto de un slot; R-FIN-3 hace el `flujo` constante dentro de la época, así que «reto = flujo»
> daría el mismo ganador 4 200 slots seguidos; R-FIN-4 y R-FIN-9 apuntan a «como Autonomys» pero la ronda 7
> razonaba en la lectura contraria. (2) **Autonomys es estrictamente secuencial** (verificado por mí en el clon:
> `seed_with_entropy` → AES^N → `blake3(pot_output)` → `blake3(rand ‖ slot)`); no hay forma de saltar slots.
> (3) **La ventana de decisión medida es `W_dec ≤ 45 s`** (≤ 20 s para `α ≤ 0,33`), y **no la fija `S_max`**
> (idéntica con 20 y con 150 s): la fija la carrera. (4) **Con `ρ ≤ 1` el steering es exactamente 0**, porque
> evaluar un candidato exige conocer la cadena común `L` slots por delante y sin AES más rápido que el
> timekeeper nadie va por delante; con `ρ > 1` hace falta un *bootstrap* de días. (5) **Lo que P4 compra no es
> bajar `α_ef` (a `g` fijo es una identidad): es bajar el precio de `g`:** `I + F` de 8,26 h a **0,76-1,31 h** y el
> margen económico de **0,50× a 3,1-5,4×**. Y con la pinza del steering desactivada **`F` pasa a fijarla la
> carrera**, `F = max(F_carrera, I/(W/κ − 1))`. (6) R-FIN-14 entregada con texto de spec.

---

## 0 · Verificación independiente del agente principal

| Comprobación | Resultado |
|---|---|
| Commits `26d0183`…`54899bd` | **Solo su directorio** |
| `AUDITA_SCRIPTS.py` (9 scripts) | 2 marcas T3b (`r9c_c4:65` `pref/base`, `r9c_lib:138` `p/padres`), leídas por 9c y por mí: divergen inmediatamente / ramas excluyentes. Falsos positivos |
| Citas de Autonomys @ `f8842d0`, leídas por mí | `pallet-subspace/src/lib.rs:940-972` (cosecha cada 50 bloques, `target_slot = slot + 15` fijado 100 bloques después) ✓ · `sp-consensus-subspace/src/lib.rs:116-150` (`seed_with_entropy` solo si `parameters_change.slot == next_slot`; `PotParametersChange {slot, slot_iterations, entropy}`) ✓ · `subspace-verification/src/lib.rs:230-262, 440-447` (`derive_global_randomness` del `proof_of_time` del propio slot → `derive_global_challenge(slot)` → `sector_slot_challenge` → `solution_distance ≤ solution_range/2`; `derive_pot_entropy = blake3(chunk ‖ pot)`) ✓ · `sc-proof-of-time/src/lib.rs:106` (`slot_to_claim = slot − block_authoring_delay`) ✓ · `slot_worker.rs:400` ✓ · `subspace-core-primitives/src/lib.rs:110` (`blake3(randomness ‖ slot.to_le_bytes())`) ✓ |
| Argumento E1 (`ρ ≤ 1 ⇒ n_eval = 0`), rehecho por mí | La semilla del candidato en `t_j` es `blake3(entropía_X ‖ pot_out(t_j − 1))`, y `pot_out(t_j − 1)` está `L − W_dec ≈ 5,3 h` de PoT por delante en el instante de decidir. Sin `ρ > 1` no hay forma de tenerlo. Y mantener la elección abierta más allá de `W_dec` exigiría una reorganización de profundidad `F`, que es lo que `F` impide. Se sostiene |
| Scripts commiteados antes del cierre (`c0`, `d1`, `e1`), re-ejecutados por mí | **IDÉNTICOS** (139 s, 73 s, 0,01 s) |
<<REPRO9C>>

---

## 1 · A · La laguna, y por qué es la que más pesa

| Regla | ¿Fija el reto del slot? |
|---|---|
| R-FIN-2 (`entropía_j`), R-FIN-3 (`flujo`), R-FIN-4 (validez «bajo ese flujo»), R-FIN-9, R-FIN-13 | **No.** Fijan bajo qué flujo se verifica, no cómo se obtiene el reto |

Dos lecturas con un factor 2,4-5,3× de diferencia en el steering: (i) `reto = H(flujo ‖ s)`, no secuencial, la
época entera evaluable en microsegundos (la que las rondas 3-8 modelaron sin decirlo); (ii) «como Autonomys».
**Corrección colateral a siete rondas:** el lookahead de Autonomys no es 11 s sino **≈ 615 s** (100 bloques de
retraso más 15 slots); ZEROX con `L + I ≈ 6,5 h` estaba 38× por encima, no 2 100×.

## 2 · C · La ventana de decisión, medida (tras dos instrumentos inválidos, declarados)

| `α` | `W_dec` máx (unión de vías) | menú `m(d)` en `d = 10 / 20 / 45 s` |
|---:|---:|---|
| **0,00** | **−1** | 1,00 / 1,00 / 1,00 |
| 0,10 | 10 s | 1,17 / 1,00 / 1,00 |
| 0,25 | 20 s | 1,42 / 1,08 / 1,00 |
| 0,33 | 20 s | 1,58 / 1,17 / 1,00 |
| 0,40 | **45 s** | 1,83 / 1,25 / 1,00 |

Vías: retener candidatos propios y liberar uno en `T_j + d`; cadena privada desde `T_j − P` soltada o no en
`T_j + d`. Idéntica con `S_max = 20` y `150 s`. **El menú vive en los primeros 10-20 s y está cerrado a los 45 s.**
Resolución: rejilla `{0, 10, 20, 45, …}` y tope de 10 candidatos (LAGUNA declarada).

**Hallazgo de instrumento que afecta a rondas anteriores (LAGUNA):** los simuladores de D9-c…f y D8 (`r8c_sim.py`,
`d8_lib.py`) permiten «retener» un bloque y publicar un hijo suyo, cosa imposible en la red real (nadie valida sin
el padre). 9c lo corrigió con la clausura de publicación. **Las `m` medidas «con retención» en D8 A4.2
(`m = 2,822-2,955`) y D9-f pueden estar infladas.** No cuantificado.

## 3 · D · Qué compra P4 exactamente

La fórmula `c_m·√(αλ·n_eval)` es exacta a `m` pequeña (razón 0,998-1,002) y conservadora ≤ 5,3 % a `m = 151`.
**Pero `α_ef` a un `g` objetivo fijo no cambia** — es una identidad. Lo que cambia es el precio de `g`: `I` deja de
escalar como `1/g²` y como `I` mismo, y pasa a `I = c_m·√(n_eval/(αλ))/g`:

| lectura | `g` | `I` | `F` (por steering) | `I+F` | margen B, plotter 10× |
|---|---:|---:|---:|---:|---:|
| LIBRE (constantes actuales, `m = 2,955`) | 3,6 % | 5 362 s | 6,77 h | 8,26 h | **0,50×** |
| `n_eval = 45` (`W_dec`, `ρ = 1`; con `ρ ≤ 1` el valor real es 0) | 3,6 % | 491 s | 0,62 h | 0,76 h | **5,42×** |
| `n_eval = 68` (`ρ = 1,5`) | 3,6 % | 602 s | 0,76 h | 0,93 h | 4,42× |
| `n_eval = 135` (`ρ = 3`) | 3,6 % | 851 s | 1,07 h | 1,31 h | 3,13× |

**Aviso de 9c que hay que respetar:** con la pinza del steering desactivada, `F` la fija la carrera:
`F = max(F_carrera, I/(W/κ − 1))`. Con el modelo de 9a (`δ = 0`), `F_carrera(α = 0,35) = 0,34 h`; con el `δ`
pesimista de D8, 1,85 h. Y la restricción nueva **`I ≥ ρ_max·W_dec`** (si `I` baja de ahí, el atacante evalúa la
época entera dentro de la ventana).

## 4 · E · Contraataques y la opción que cierra del todo

- **Precomputar candidatos antes de `T_j`:** imposible (necesitan `pot_out(t_j − 1)`). **Adelantar la cadena
  común:** posible solo con `ρ > 1`, hasta `L + I − W_dec` slots, tras un *bootstrap* de 5,4 días (`ρ = 1,05`) a
  12,8 h (`ρ = 1,5`). `ρ ≥ 6` no existe en silicio de consumo (Autonomys calibra al 14900KS).
- **Mantener candidatos abiertos más allá de `W_dec`:** no es steering (no elige él); actuar cae dentro de `W_dec`.
- **Acortar `S_max` por esto:** inútil (`W_dec` no depende de `S_max`) y caro (D8 A3).
- **Revelación retardada** (`entropía_j = VDF(chunk ‖ pot_out, L·iter)`, revelada en `t_j`; la ronda 7 la
  descartó): lleva `n_eval` a **0 para cualquier `ρ`**, porque la cota de conocimiento pasa a `I < L`. Coste: un
  VDF más que producir y verificar. PLAUSIBLE, no medido. Queda como opción.

## 5 · F · R-FIN-14 (texto de 9c; va a la propuesta)

Cadena de PoT **secuencial por flujo**; `semilla(f, t_j) = blake3(entropía_j ‖ salida(f, t_j − 1))`;
`salida(f, s) = AES^{N(s)}(semilla)`; `reto(f, s) = blake3(blake3(salida(f, s)) ‖ LE64(s))`; validez por
`sector_slot_challenge` y `solution_distance ≤ solution_range/2`; justificación por `PotCheckpoints` acotada a
`S_max`, comprobación de flujo antes que la de PoT; **prohibido** `reto = H(flujo ‖ s)` o cualquier PRF que
permita saltar slots (es el contenido de seguridad de la regla); calibración `I ≥ ρ_max·W_dec`; `t_j` distintos
dos a dos (dado `S_max < I`); revelación retardada como opción.

## 6 · Errores declarados por 9c (cinco) y efecto sobre las decisiones

`r9c_c1` inválido entero (6,5 h tiradas); primera pasada de `c2` inválida (retener y publicar un hijo); segunda
sobre-corregida; independencia del resto de la época asumida, no medida; dos ramas sin ejercitar.

**Decisiones:** R-FIN-14 va a la propuesta. Las constantes `I`, `F` **hay que recalibrarlas** con la ventana medida,
y la elección de `ρ_max` (1 / 1,5 / 3) y de `F` (carrera o steering) es de Katana: tabla en §3 y en la propuesta.
