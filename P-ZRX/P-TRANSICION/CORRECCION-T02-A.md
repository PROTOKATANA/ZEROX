# CORRECCIÓN-T02-A — definiciones cerradas de E1–E4

**ID:** T02-A. **Fecha:** 2026-09-26. **Director:** Claude. Complementa `ORDEN-T02.md`, que sigue
vigente en todo lo que aquí no se cambia. **Las cuatro ambigüedades que señalaste son defectos de
la orden**, y parar fue correcto. Tus resoluciones de AMBIGÜEDAD-1 (`slot(PoW) = 0`, luego
`d = slot de la punta honesta`) y AMBIGÜEDAD-6 quedan **ratificadas**.

## Convenciones comunes (todas las carreras)

- Tiempo continuo en unidades de `T_pow`. Bloques PoW: Poisson, honesto tasa `1−h`, adversario `h`.
- Cada rama con terminal empieza **su propia** fase PoST en el instante en que su terminal existe
  (`t_H` para la honesta, `t_A` para la del adversario). Slot `j ≥ 1` de una rama ocurre en
  `t_rama + j·r`. En cada slot, la rama honesta gana un bloque de peso 1 con probabilidad `(1−a)·p`;
  la del adversario, con probabilidad `a·p` (independientes). **Supuesto favorable al adversario,
  declárelo:** el adversario no aporta peso a la rama honesta (retiene) y no se modela doble farmeo
  a favor del honesto; la velocidad PoT del adversario es la nominal (sin `ρ`).
- El adversario publica en el primer instante en que su historia gana según la regla; un nodo en
  línea cambia si además `d < F_slots`, con `d` = índice de slot del último bloque PoST de su punta
  honesta (0 si aún no hay ninguno). Un nodo que sincroniza desde cero cambia sin `C-FIN-01`.
- **Empates:** métrica principal con `≥` (el adversario gana el empate; cota superior de su éxito);
  reporta además la métrica con `>`. Ambas en todos los puntos.
- Horizonte: `M` slots contados desde `t_H`; si el adversario no ha ganado, abandona (fracaso).

## E1 · control de Nakamoto (sin corte)

Se elimina `k` de E1. Es exactamente el modelo de Nakamoto §11: el adversario empieza a minar en
privado en el bloque que contiene el pago; el comerciante espera `z` confirmaciones; éxito si la
rama privada llega a tener **más** bloques que la honesta en algún momento. Fórmula de control:

    λ = z·q/p;  P(z) = 1 − Σ_{k=0}^{z} (λ^k e^{−λ}/k!)·(1 − (q/p)^{z−k}),  con q = h, p = 1 − h

Debe coincidir con la tabla del artículo (`q = 0,1` y `0,3`, `z = 0…10`) con error `< 10⁻⁶`, y el
simulador con la fórmula dentro de su IC al 99,9 %.

## E2 · terminal alternativo privado + espacio

- En el instante en que la cadena honesta tiene altura `H* − k`, el adversario empieza a minar en
  privado desde ese bloque. Ambas ramas tienen su terminal **exactamente** a la altura `H*`
  (`Φ` verdadera en ambas, `W_min` no liga: todos los bloques valen 1).
- Honesto alcanza `H*` en `t_H`; adversario en `t_A` (su bloque `k`-ésimo privado). Si el adversario
  todavía no ha llegado a `H*` cuando han pasado `M` slots desde `t_H`, fracasa.
- **FC-3 / FC-2:** el adversario gana en el primer `t ≥ t_A` con `W_A(t) ≥ W_H(t)` (pesos PoST
  acumulados de cada rama); nodo en línea: además `d < F_slots`.
- **FC-1:** los dos prefijos tienen el mismo trabajo (`H*`) ⇒ empate en trabajo ⇒ decide el peso PoST
  **exactamente igual que FC-3**. Repórtalo como resultado (en este modelo FC-1 ≡ FC-3 en E2), no
  como fallo.
- Métricas: éxito (con IC) para nodo en línea y nodo nuevo; bloques PoW privados minados; slots
  hasta el éxito.

## E3 · rama PoW con más trabajo por bloque (abstracción de dificultad mayor)

El modelo sin retarget no permite más trabajo a igual altura, así que E3 se define con una
**abstracción explícita** (no modeles cómo se consigue):

- El adversario bifurca a profundidad `k` del terminal honesto **después** de que exista `T`
  (reescribe los últimos `k` bloques) y mina `k` bloques privados cuyo trabajo individual es
  `1 + δ`, con `δ ∈ {0,01; 0,1}`, a tasa `h/(1+δ)` (cada bloque cuesta `1+δ` veces más). Su terminal
  está a la misma altura `H*` y su prefijo tiene trabajo `H* + k·δ > H*`.
- El adversario **no** produce peso PoST (`a` no interviene): E3 aísla el efecto del hash.
- **FC-1:** gana en cuanto publica su terminal (más trabajo), sin peso PoST; nodo en línea: cambia
  solo si `d < F_slots` en ese instante; nodo nuevo: cambia siempre. Reporta la probabilidad de que
  los nodos en línea **no** cambien y los nuevos **sí** (partición entre nodos viejos y nuevos) en
  función de `(h, k, δ, F_slots, r, p)`.
- **FC-3:** gana solo si `W_A ≥ W_H`; con `W_A = 0` gana únicamente mientras `W_H = 0` (ningún
  bloque PoST honesto todavía). Reporta esa probabilidad.
- Coste: `k·(1+δ)` unidades de trabajo.

## E4 · censura de depósitos

Simplificación declarada: `Φ` es verdadera en cuanto existe **un** depósito maduro en la cadena
seleccionada (equivale a `S_min = q`, `K_min = 1`, `SEC-0`); `H_corte_min` y `W_min` no ligan.

- Hay siempre un depósito pendiente en el mempool honesto desde `t = 0`. Todo bloque honesto
  incluye los depósitos pendientes; los del adversario nunca. Un depósito incluido en el bloque de
  altura `b` madura cuando la cadena seleccionada alcanza altura `b + M_dep` con ese bloque dentro.
- Estrategia del adversario: cada vez que aparece en la cadena seleccionada un bloque honesto con
  depósito, empieza a minar en privado desde su padre e intenta adelantar a la rama honesta
  (publica cuando su rama privada es más larga) **antes** de que el depósito madure; si lo
  consigue, el depósito sale de la cadena y vuelve al mempool; si el depósito madura, el corte
  ocurre. Solo persigue un depósito a la vez.
- Mide, para `h ∈ {0,1; 0,25; 0,4; 0,5; 0,6; 0,9}` y `M_dep ∈ {1, 3, 6, 12}`: retraso del corte
  (media y percentil 99, en `T_pow`) y fracción de bloques de la cadena seleccionada minados por el
  adversario hasta el corte (emisión capturada). Horizonte `10⁴·T_pow`: si no hay corte, se cuenta
  como **censurado en el horizonte** y se reporta la fracción de réplicas censuradas (para
  `h > 1/2` se espera cerca de 1: dilo y da la cota).

## Qué no cambia

Rejilla de §3.6 salvo lo dicho; umbral de §7; 4 hilos; presupuesto de 2 h **reiniciado** para esta
corrección; entregables de §8; límites de §9. Añade a `ENTRADA` la comprobación de
`ENTRADA-T02-A.sha256`.

## Lanzamiento

    cd /home/katana/zeo/ZEROX/P-ZRX/P-TRANSICION/T02 && \
    ( set -a; . /home/katana/torio/deepseek-harness/.env >/dev/null 2>&1; set +a; \
      node /home/katana/torio/deepseek-harness/apps/cli/lib/bin.js --profile headless \
      "Orden T02, corrección A. Lee íntegros /home/katana/zeo/ZEROX/P-ZRX/P-TRANSICION/CORRECCION-T02-A.md, /home/katana/zeo/ZEROX/P-ZRX/P-TRANSICION/ORDEN-T02.md y tu propio T02/PROGRESO.md; lee íntegro /home/katana/zeo/ZEROX/V-ZRX/LINEO.md antes de escribir código. Cumple la orden con las definiciones de la corrección. Si detectas otra falta de definición que cambie un resultado, infórmala antes de editar." \
      > ../T02-A-dsh.stdout 2> ../T02-A-dsh.stderr )
