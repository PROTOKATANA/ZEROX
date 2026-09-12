# Enmienda Z0 — registro permanente de la enmienda de RCE-v0.1

Fecha de la enmienda: 2026-09-12. Decisión: Katana. Ejecutado por DeepSeek en la zona
aislada `deepseek/z0-no-op-v1/`; validado por Claude reejecutando; migrado a `veritas/` el
2026-09-12. Este documento conserva la procedencia del cambio antes de que la zona temporal
desapareciera.

## 1 · Qué se enmendó y por qué

El CONTRATO de RCE-v0.1 decía, para `N_j=0`, «mantener `R_j`», y dos implementaciones propias
del proyecto discrepaban sobre qué significa «mantener»: Julia (RCE, ARM, comprobación
decisiva) agendaba una propuesta `HeldZero` con el rango del sello; el helper Rust
`FeedbackState::close` no agendaba nada. El vector `W=10, R₀=100, Q=10, ganancia 1/1,
delay_windows=2` con `N₀=5` sellado en el slot 10 y `N₁=0` en el slot 20 lo exhibía: Julia
subía a 200 en el slot 30 y volvía a 100 en el slot 40 por una ventana vacía que nunca vio ese
200; Rust se quedaba en 200. Agendar un valor con activación diferida no es *mantener*: es
*revertir*. Katana decidió el 2026-09-12, sobre el hallazgo H1 de
`comprobacion-decisiva-v1/AUDITORIA-EXTERNA.md`: **Z0 es un no-op explícito** — `causal_step`
devuelve `(StepHeldZero, current, 0, false)`; la activación 0 impide que ningún llamante
agende la propuesta. La ventana sin progreso sí se sella y sí se registra. RCE-v0.1 pasa a
revisión 2; ARM-v0.1 pasa a revisión 2 (consume RCE revisión 2).

## 2 · Derivaciones a mano (2026-09-12 21:40, escritas ANTES de ejecutar)

Regla del encargo: cada valor esperado se deriva primero; la medición sólo lo confirma.
Notación: `W` ancho, `G` gracia, `D` `activation_delay_windows`, `R_j` rango activo,
`c_j=(j+1)W+G` corte, `b_j=(⌊c_j/W⌋+1)W`, `A_j=b_j+(D−1)W`.

### D1 — Vector nuevo del fixture `CONTROLADOR.txt`

`current=100`, `observed=0`, `cutoff=20`, `seal=20`, `W=10`, `Q=10`, `a/d=1/1`, clamps
`[1/2,2/1]`, rango `[1,1000]`, `D=2`, `Floor`.

- `b = (⌊20/10⌋+1)·10 = 3·10 = 30`; `delay_extra = (2−1)·10 = 10`; `A = 30+10 = 40`.
- `seal (20) < A (40)` → **no** es `MissedUpdate`.
- `observed == 0` → `HeldZero`. Con la enmienda devuelve `activation = 0` y
  `next = current = 100`, `clamped = false`.
- **Esperado: `HeldZero 100:0:0`.** Línea nueva:

  ```text
  STEP 100 0 20 20 10 10 1 1 1 2 2 1 1 1000 2 Floor HeldZero 100:0:0
  ```

- `execute_fixtures` pasa de `(cases=9, assertions=18)` a **`(cases=10, assertions=20)`**.

### D2 — RCE `test/runtests.jl`, testset «activación y Pending»

`cfg = controller()`: inicial 300, `W=20`, `D=1`, `cutoff=23`, `seal=23`.

- `b = (⌊23/20⌋+1)·20 = 2·20 = 40`; `A = 40`. `seal (23) < A (40)` → no Missed;
  `observed=0` → HeldZero.
- **Esperado nuevo: `(StepHeldZero, U(300), U(0), false)`** (antes la activación era 40).
- Vector de regresión nuevo:

  ```julia
  cfg_delay2 = ControllerConfig(100, 10, 1, 1, 1, 2, 2, 1, 1, 1000, 2, RoundFloor)
  causal_step(100, U(0), 20, 20, 10, cfg_delay2) == (StepHeldZero, U(100), U(0), false)
  ```

### D3 — ARM «cierre objetivamente tardío y cero real distinto de Pending»

`empty_model`: catálogo vacío, `CloseFrame(700,0,10)`, `W=10`, `G=0`, `test_controller()`
(inicial 100, `Q=10`, `D=1`, Floor).

- `c_0 = 10`, sello 10. `b = (⌊10/10⌋+1)·10 = 20`; `A = 20`.
- `observed = 0` → HeldZero. **Esperado: `proposals` queda vacía** (desaparece `(700,0,20,100)`)
  y `seals[1].activation_slot == 0`.

### D4 — ARM testset de ventana vacía con desfase 2

`W=10`, `G=0`, `D=2`, `R₀=100`, `Q=10`, ganancia 1/1, clamps `[1/2,2/1]`, rango `[1,1000]`,
Floor. Frames `(100,0,10)`, `(200,1,20)`, `(300,2,40)`; historias 200 y 300 sin bloques:
cohortes 1 y 2 ambas vacías.

**Cohorte 0** (sello 10): `N=5`.
`num = 100·((1−1)·5 + 1·10) = 1000`; `den = 1·5 = 5`; `raw = ⌊1000/5⌋ = 200`.
`lower = ⌊100·1/2⌋ = 50`; `upper = ⌈100·2/1⌉ = 200`; `stepped = clamp(200,50,200) = 200`;
`bounded = clamp(200,1,1000) = 200`. `b = (⌊10/10⌋+1)·10 = 20`; `A = 20+10 = 30`.
`seal 10 < 30` → **Scheduled: propuesta `(100,0,30,200)`**.

**Cohorte 1** (sello 20): `N=0` → HeldZero, `A` nominal 40, devuelta 0, **sin propuesta**.
El rango activo al sellar era 100 (la 200@30 no ha activado), pero ya no se agenda 100@40.

- Tras `replay!(view, 200)`: `active_range == 100`; `proposals == [(100,0,30,200)]`;
  `seals[2].code === HeldZero`; `range_at(30) == 200`; `range_at(39) == 200`;
  **`range_at(40) == 200`** (antes 100).

**Cohorte 2** (sello 40): activan las propuestas con `activation ≤ 40` — sólo `200@30` →
`active_range = 200`, `activations = [propuesta]`. `N=0` → HeldZero, sin propuesta.

- Tras `replay!(view, 300)`: `active_range == 200` (antes 100); `activations == proposals`;
  **`agenda` vacía** (antes `[(300,2,50,100)]`); `range_at(35) == 200`.

Nota: la cohorte 2 es **otro** HeldZero — su propuesta `(300,2,50,100)` desaparece igualmente.

### D5 — DCS `verificar_heldzero` (mismo fixture que D4)

- **Esperado: `proposals == [(100,0,30,200)]`** (pierde `(200,1,40,100)` y `(300,2,50,100)`);
  `activations == proposals`; `range_at_39 == 200`; **`range_at_40 == 200`** (antes 100);
  `range_at_35 == 200`. El sello y el registro no cambian (`seals[2].code === HeldZero`).
- El campo de `ejecutar_convergencia` pasa a `heldzero_convergencia` con `range_at_40 == 200`.

### D6 — Rust: `causal_step` y la frontera ARM

- `causal_step(100, Some(0), 20, 20, 10, controller)` con `delay_windows=2` →
  `Ok(Step { code: HeldZero, next: 100, activation: 0, clamped: false })`.
- En `reconstruct` del vector `[frame(900,0,10,5), frame(2,1,20,0)]`:
  `schedule.get(&30).next_range == 200` (sigue), **`schedule.get(&40)` es `None`** (nuevo),
  y tras `activate_through(40)` el rango activo **es 200** (antes 100).
- El «control legado» deja de divergir: `close` y `reconstruct` producen el mismo estado; el
  test afirma esa igualdad explícitamente.

**Cero discrepancias** entre lo derivado y lo medido: las seis derivaciones se confirmaron
íntegras en la ejecución.

## 3 · Cifras de la validación

Medidas por **Claude reejecutando las suites** (no leyendo los `RESULTADOS/` del ejecutor),
sobre `deepseek/z0-no-op-v1/arbol/`, el 2026-09-12:

| Comprobación | Resultado |
|---|---|
| `cargo test --workspace --no-fail-fast` | 485 aprobados · 1 fallido · 4 ignorados |
| El único fallo | `el_spec_dice_el_tamano_real_de_la_cabecera` — preexistente, debe seguir rojo |
| `cargo test -p zx-consensus --test retarget_causal_endogeno_modelo` | 13 aprobados, 0 fallidos |
| `cargo fmt --check` | exit 0 |
| `cargo clippy --workspace --all-targets -- -D warnings` | exit 0 |
| Julia RCE | 12 856 asserts, exit 0 |
| Julia ARM (`--seed 20260911`) | 687 asserts, exit 0 |
| Julia comprobación decisiva (`--seed 20260912`) | 451 asserts, exit 0 |
| Convergencia Julia | `runtests.jl` ARM: `range_at(…, U(40)) == 200` |
| Convergencia Rust | `frontera.rs`: `arm.feedback.active_range == 200` tras `activate_through(40)` |

## 4 · Límites que siguen en pie

La enmienda arregla la semántica del **modelo**, no el nodo: `crates/zx-node/` sigue sin
implementar el controlador RCE. La convergencia Julia–Rust está demostrada en el modelo y en
la frontera de test Rust, no en un nodo ejecutando el protocolo completo (ni red, ni PoAS, ni
DAG real). `MissedUpdate` conserva su activación calculada (asimetría deliberada, fuera de
alcance). El desajuste preexistente de `SPEC.md` en `HUELLAS.sha256` (huella del fichero
commiteado `70481a8e…` frente al árbol de trabajo sin commitear `1683af53…`) **no se toca**:
es decisión de Katana.

## 5 · Decisiones del encargo original que el prompt no cubría

1. **`TAREAS.md` §1.1**: nota de estado fechada (ejecutado, pendiente de validación) sin
   reescribir el diagnóstico, para cumplir el grep de §5.5 del encargo.
2. **`.gitignore` excluido del parche**: ZEROX ganó la entrada `deepseek/` después de copiarse
   el árbol de trabajo; incluir el hunk habría borrado una entrada ajena al trabajo.
3. **Artefactos Rust de ARM regenerados** (`RUST.txt`, `RUST-ARM.txt`, `CONTROLES-RUST.txt`,
   `FORMATO-RUST.txt`): el encargo sólo nombraba TESTS/RUN/ENTORNO, pero los viejos conservaban
   evidencia del adaptador retirado y del `println` de mismatch.
4. **`git_diff_check=NA`** en el TESTS.txt de RCE: la copia de trabajo no tenía `.git` por
   diseño; el diff se entregó como parche verificado con `git apply --check`.

## Nota sobre la huella de `SPEC.md` (2026-09-12, añadida en la migración)

Al validar la migración se comprobó que la huella de `SPEC.md` registrada en `HUELLAS.sha256`
cuando se firmó RCE-v0.1 —`70481a8ecc1bf9b834b80d30bfa3c2bf5dd54ba779b3cda2218eabe1673aefb1`—
**no corresponde a ningún estado recuperable del documento**: ni al árbol de trabajo
(`1683af53e6c118213ea5ddfa85872a9e3470e72e20eea51ca308296aa4deb92f`), ni al `SPEC.md` de `HEAD`
(`f2dce753ea6665b6ce239b00f42599672881dec5211fc417596678f191f165b2`), ni a ninguno de los
últimos 40 commits de la rama. Acreditaba una versión que vivió en el árbol de trabajo el
2026-09-11 y que nunca se comprometió con ese contenido.

Corregido por decisión de Katana: la línea pasa a la huella del `SPEC.md` **contra el que se
ejecutó y validó esta enmienda**, que es la afirmación que la huella puede sostener. El puntero
al SPEC original de la firma se da por perdido y se consigna aquí para que quede rastro.

Un informe previo describió `70481a8e…` como «el hash de `git show HEAD:SPEC.md`». Esa
afirmación era incorrecta y no se verificó antes de repetirla; los tres valores de arriba sí
están medidos.
