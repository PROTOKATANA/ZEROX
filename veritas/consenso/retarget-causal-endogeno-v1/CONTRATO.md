# RCE-v0.1 — contrato de retarget causal endógeno

Fecha: 2026-09-11. Revisión del instrumento: **2** (enmendado 2026-09-12). Estado: **modelo de evaluación; no activado en consenso**. Parte de
VRC-v0.1 y conserva `EventId=(context_id,block_id)`, P0/P1, L0/LG, DA0, snapshots sellados y
undo contextual. Ninguna cifra de fixtures o escenarios es parámetro de producción.

## Controlador entero mínimo

Cada cohorte `J_j=[jW,(j+1)W)` tiene corte `c_j=(j+1)W+G`. Al cerrarse aporta el snapshot
inmutable `N_j=|counted_ids_j|`. Sea `Q` el conteo objetivo, `R_j` el rango activo, y `a/d`
una ganancia racional con `0<a<=d`. Para `N_j>0` se calcula exactamente:

```text
num = R_j * ((d-a)*N_j + a*Q)
den = d*N_j
R_raw = round(num/den)
R_step = clamp(R_raw, floor(R_j*p_lo/q_lo), ceil(R_j*p_hi/q_hi))
R_next = clamp(R_step, R_min, R_max)
```

Todos los productos usan enteros comprobados o `BigInt` en el oráculo. El kernel UInt128 exige
como precondición comprobada `R_max*d*typemax(UInt64)<=typemax(UInt128)`; configuraciones fuera
de ese dominio se rechazan antes de simular, no saturan ni divergen del oráculo. Se comparan dos modos
explícitos: `Floor` y `NearestEven`; el segundo resuelve empates hacia el cociente par. Los
clamps multiplicativos son racionales positivos, `p_lo<=q_lo`, `p_hi>=q_hi`, y el clamp global
satisface `0<R_min<=R_initial<=R_max`. Para `N_j=0`, política Z0: **no se agenda propuesta
alguna**; la activación devuelta es `0`, igual que en `Pending`. La ventana sin progreso
**sí se sella y sí se registra** en las métricas (racha sin evento, sellos, `observed=0`).
Cero no se sustituye por epsilon. *Mantener* es no intervenir: agendar `R_j` con activación
diferida es *revertir* — reimpone el rango del sello aunque entre medias haya activado
evidencia real posterior. Un snapshot `Pending` no produce actualización.

Bootstrap B0 mantiene `R_initial` hasta cerrar la primera ventana completa. Sea
`b_j=(floor(c_j/W)+1)*W`, la primera frontera estrictamente posterior al corte. La activación
nominal es `A_j=b_j+(activation_delay_windows-1)*W`, con `activation_delay_windows>=1`. La propuesta sólo se
agenda si la ventana queda Ready en `seal_slot<A_j`. Si queda Ready en o después, se registra
`MissedUpdate` y el rango se mantiene: nunca se activa retroactivamente. Pending bloquea el
cierre de ventanas posteriores. La propuesta usa el rango activo al sellarse. Colisiones de
activación son configuración inválida, no se desempatan por llegada.

## Enmienda Z0 — revisión 2 (2026-09-12)

La revisión 1 decía «mantener `R_j`» para `N_j=0` sin precisar cómo, y dos implementaciones
propias del proyecto discrepaban: Julia (RCE, ARM, comprobación decisiva) agendaba una
propuesta `HeldZero` con el rango del sello; el helper Rust `FeedbackState::close`
(`crates/zx-consensus/tests/`) no agendaba nada. El vector `W=10, R₀=100, Q=10, ganancia 1/1,
delay_windows=2` con `N₀=5` sellado en el slot 10 y `N₁=0` en el slot 20 lo demostró: Julia
subía a 200 en el slot 30 y **volvía a 100** en el slot 40 por una ventana vacía que nunca
vio ese 200; Rust se quedaba en 200. Agendar un valor obsoleto no mantiene: revierte. Katana
decidió el 2026-09-12, sobre el hallazgo H1 de
`veritas/consenso/comprobacion-decisiva-v1/AUDITORIA-EXTERNA.md`, adoptar **Z0 como no-op
explícito**: `causal_step` devuelve `(StepHeldZero, current, 0, false)` para que ningún
llamante pueda agendarla. Consecuencia secundaria: como `HeldZero` ya no puede producir una
propuesta, **ya no puede provocar una colisión de activación**; el conjunto de
configuraciones que producen colisiones (configuración inválida) se reduce.

## Variables y estado

| Variable | Unidad | Estado |
|---|---|---|
| `W`, `G` | slots enteros | escenarios pendientes |
| `activation_delay_windows` | cohortes enteras | escenario pendiente |
| `Q`, `N_j` | adjudicaciones/EventId | escenario / derivado |
| `R*` | unidades enteras abstractas de rango | escenario; no PoAS calibrado |
| `a/d`, clamps | racionales enteros | familia de estudio |
| `Delta`, congestión, retención | slots o segundos según etiqueta | escenarios, no medidos aquí |
| tasa | eventos pagables por slot | derivada |

`W/G` son distintos de `W_adm`. L0 puro puede divergir tras un cierre; `G>=W_adm` es condición
suficiente entera para cohortes completas. LG exige incorporación estrictamente anterior al corte.

## Adversario y trazas comunes

Una traza exógena, derivada únicamente de `(seed,slot,actor,intento,tipo_de_draw)`, fija palabras de 64 bits;
el escenario exige `draw_scale` potencia de dos y usa una máscara, evitando sesgo de módulo. Fija además
draws sintéticos de retardo y copia; estos últimos no se presentan como distribuciones uniformes exactas.
`adversary_header_delay` retrasa la cabecera y `adversary_body_hold` retiene el cuerpo con la cabecera
ya visible, ejercitando DA0. Cada variante recibe exactamente esa traza,
pero admite oportunidades contra su propio rango activo y realimenta su propia historia.
Los `TicketId`, `BlockId` y `PaymentId` se reservan para toda oportunidad a partir de
`(slot,actor,intento,copy)`, incluso si una variante no produce; por ello una oportunidad común
no cambia de identidad cuando divergen los rangos.
El escenario adversarial puede fijar retención, copias y retraso de cuerpos;
no rompe PoT, firmas, KZG ni hashes. La Bernoulli sintética sólo prueba dinámica del controlador:
no certifica distribución PoAS, multiplicidad física ni `Delta` de ZEROX.

## Métricas y estados desconocidos

Se registran tasa, EventId contados/pagables y su igualdad, exclusión honesta, reinclusiones y
latencia, slots `Pending`, no progreso por Pending y por ausencia de evento por separado, su
máximo combinado y si la racha final queda censurada por el horizonte,
máximo conjunto de cabeceras pendientes y pagos originados nunca
aceptados y clamps. Reversión después de aceptación queda `MetricPending(:no_branch_model)`:
este modelo no tiene ramas/reorg y no puede convertir esa ausencia en cero.
Cola real de red/servicio, capacidad por bytes y desacuerdo entre observadores quedan también
`MetricPending`: una agenda de entregas no se etiqueta como cola de red.

Si L0 paga tras un sello, el controlador usa el snapshot `counted` inmutable aunque difiera de
`payable`; la divergencia se registra, no se retroactualiza.

Falla estructuralmente: overflow, configuración inválida, cambio retroactivo, Pending contado
como cero, activación sin desfase, desigualdad no declarada counted/payable, dependencia de orden
de llegada/RNG propio por variante o divergencia referencia/kernel.

Orden de fases en un slot: (1) activar propuestas ya agendadas; (2) cerrar cohortes cuyo corte
es ese slot; (3) incorporar cabeceras/cuerpos. Por ello `body_available_slot==slot` sigue
`Pending` para el cierre de ese slot y queda disponible para incorporar en la fase 3. Toda suma y producto de fronteras es checked;
overflow falla sin mutación.
