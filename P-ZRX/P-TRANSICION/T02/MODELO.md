# MODELO — T02: modelo adversarial de la selección a través del corte

**ID:** T02. **Ejecutor:** DeepSeek (harness, `deepseek-flash`). **Director:** Claude.
**Autoridad:** `ORDEN-T02.md` y `CORRECCION-T02-A.md`. Aquí se describe **qué** se modela, con sus
supuestos; los resultados están en `INFORME.md` y el procedimiento en `METODO.md`.

## 0. Unidades y símbolos

| Símbolo | Significado |
|---|---|
| `T_pow` | unidad de tiempo = intervalo medio de bloque PoW |
| `h` | fracción de hash del adversario (honesto `1−h`) |
| `a` | fracción de espacio PoST del adversario |
| `p` | probabilidad de que un slot PoST tenga algún ganador |
| `r` | duración del slot en unidades de `T_pow` (`τ/T_pow`) |
| `k` | profundidad de la bifurcación (bloques PoW privados) |
| `z` | confirmaciones que espera el comerciante (E1) |
| `δ` | exceso de trabajo por bloque del adversario (E3) |
| `F_slots` | profundidad máxima de sustitución de `C-FIN-01` (`∞` = sin cota) |
| `M` | horizonte en slots: `M = 10·F_slots`, y `M = 10⁵` si `F_slots = ∞` |
| `M_dep` | madurez de un depósito en bloques PoW (E4) |
| `H*` | altura del terminal (igual para ambas ramas en E2/E3) |
| `t_H`, `t_A` | instante en que existe el terminal honesto / del adversario |
| `W_H(t)`, `W_A(t)` | peso PoST acumulado de la rama honesta / adversaria en `t` |
| `d` | índice de slot del último bloque PoST de la punta honesta (0 si no hay) |

Tiempo continuo en unidades de `T_pow`; probabilidades en `Float64`; conteos y decisiones en
enteros (LINEO §5.3).

## 1. Convenciones comunes (CORRECCION-T02-A)

1. **PoW.** Bloques PoW como procesos de Poisson independientes: honesto a tasa `1−h`, adversario a
   tasa `h`. Sin retarget dentro de la ventana. Cada bloque PoW vale 1 de trabajo.
2. **Fase PoST por rama.** Cada rama con terminal arranca **su propia** fase PoST cuando su terminal
   existe (`t_H` la honesta, `t_A` la del adversario). El slot `j ≥ 1` de una rama ocurre en
   `t_rama + j·r`. En cada slot la rama honesta gana un bloque de peso 1 con probabilidad
   `(1−a)·p` y la adversaria con `a·p` (independientes). Peso por bloque = 1 (`k = 0`).
3. **Empates.** La métrica principal usa `≥`: el adversario gana el empate (cota superior de su
   éxito). Se reporta además la métrica estricta `>`.
4. **Horizonte.** `M` slots contados desde `t_H`; si el adversario no ha ganado, abandona (fracaso).
   En E2 no basta con alcanzar `H*`: hay que ganar antes de `M`.
5. **`C-FIN-01` (nodo en línea).** El nodo no sustituye si `d ≥ F_slots`. `d` se mide con la
   convención de AMBIGÜEDAD-1 ratificada: el slot del bloque PoW ancestro es 0, luego
   `d = slot del último bloque PoST de su punta honesta` (0 si aún no hay ninguno). Un nodo que
   sincroniza desde cero aplica la regla **sin** `C-FIN-01`.
6. **Supuestos favorables al adversario (declarados).** El adversario no aporta peso a la rama
   honesta (retiene) y no se modela doble farmeo a favor del honesto; la velocidad PoT del
   adversario es la nominal (sin `ρ`). Red sin latencia (límite optimista para el honesto).

## 2. E1 · control de Nakamoto (sin corte, sin `k`)

Es exactamente el modelo de Nakamoto §11. El adversario empieza a minar en privado en el bloque que
contiene el pago; el comerciante espera `z` confirmaciones; el adversario gana si su rama llega a
tener más bloques que la honesta en algún momento. Fórmula de control (con `q = h`, `p = 1−h`):

    λ = z·q/p
    P(z) = 1 − Σ_{k=0}^{z} (λ^k e^{−λ}/k!)·(1 − (q/p)^{z−k})

para `q < p`; si `q ≥ p`, `P = 1`. Se elimina `k` de E1: no interviene.

**Simulador.** Réplica: `X ~ Poisson(λ)` (bloques del adversario durante el tiempo medio `z/p` que
el honesto tarda en minar `z` bloques — el artículo fija ese tiempo en su valor medio); si `X ≥ z`,
éxito; si no, ruina del jugador desde el déficit `z−X` con absorción en 0 y truncación en `CAP_E1`.

## 3. E2 · terminal alternativo privado + espacio

- Cuando la cadena honesta tiene altura `H* − k`, el adversario empieza a minar en privado desde ese
  bloque. Ambas ramas tienen su terminal **exactamente** a la altura `H*`; `Φ` es verdadera en las
  dos y `W_min` no liga (todos los bloques valen 1).
- El honesto alcanza `H*` en `t_H` (su bloque `k`-ésimo); el adversario en `t_A` (su bloque
  `k`-ésimo privado). Si `t_A > t_H + M·r`, fracasa.
- **Selección.** `FC-3` (y `FC-2`): el adversario gana en el primer `t ≥ t_A` con
  `W_A(t) ≥ W_H(t)`. `FC-1` no cambia nada aquí porque la comparación de trabajo PoW ya decidió
  `t_A` (ambas ramas con trabajo `H*`, gana la que llega antes), y E2 se reporta con la regla de
  pesos PoST.
- **Nodo en línea:** cambia si además `d < F_slots` en el instante de la victoria; **nodo nuevo:**
  cambia siempre (sin `C-FIN-01`).
- Caso `t_A ≤ t_H`: en `t_A` el honesto aún no ha arrancado su fase PoST, luego `W_H = W_A = 0` y el
  empate favorece al adversario; `d = 0`, de modo que el nodo en línea también cambia.

**Simulador.** `t_H ~ Gamma(k, 1−h)` y `t_A ~ Gamma(k, h)` (sumas de `k` exponenciales). El conteo
del adversario se simula bloque a bloque hasta `k` o el horizonte. La carrera PoST se simula a nivel
de bloque: estado `D = W_H − W_A`, con salto geométrico entre bloques (las rondas sin bloque no
cambian `D`). El estado honesto inicial (tras `m = ⌊(t_A−t_H)/r⌋` slots) se muestrea en `O(1)`:
nº de bloques `~ Binomial(m, α)` y slot del último bloque por geométrica. Para `a < 1/2` se poda
cuando `D > 300` (la probabilidad de remontar es `< ρ^{300} < 10⁻²⁴`).

## 4. E3 · rama PoW con más trabajo por bloque (abstracción de dificultad)

- El adversario bifurca a profundidad `k` del terminal honesto **después** de que exista `T`
  (reescribe los últimos `k` bloques) y mina `k` bloques privados con trabajo individual `1+δ`,
  `δ ∈ {0.01; 0.1}`, a tasa `h/(1+δ)`. Su terminal está a la misma altura `H*`, con prefijo de
  trabajo `H* + k·δ > H*`. **No** produce peso PoST: `a` solo interviene vía la probabilidad
  honesta `α = (1−a)·p`.
- **`FC-1`:** gana en cuanto publica su terminal (más trabajo), sin peso PoST. El nodo nuevo cambia
  siempre; el nodo en línea cambia solo si `d < F_slots`, con `d = slot del último bloque PoST
  honesto` (0 si no hay). Se reporta la **partición**: `P(en línea NO cambia y nuevo SÍ) =
  P(d ≥ F_slots)`.
- **`FC-3`:** gana solo si `W_A ≥ W_H`; como `W_A = 0`, gana únicamente mientras `W_H = 0` (ningún
  bloque PoST honesto todavía). Se reporta `P(W_H(t_A) = 0)`.
- Coste: `k·(1+δ)` unidades de trabajo.

**Método.** Fórmulas exactas. Con `n = ⌊t_A/r⌋` y `t_A ~ Gamma(k, (1+δ)/h)`,
`P(d ≥ F_slots) = 1 − E[(1−α)^{max(0, n−F_slots+1)}]` y `P(W_H = 0) = E[(1−α)^n]`, sumando sobre
las bandas `n` con la CDF de la Gamma.

## 5. E4 · censura de depósitos

- `Φ` es verdadera en cuanto existe **un** depósito maduro en la cadena seleccionada
  (`S_min = q`, `K_min = 1`, `SEC-0`); `H_corte_min` y `W_min` no ligan.
- Hay siempre un depósito pendiente en el mempool desde `t = 0`. Todo bloque honesto incluye los
  depósitos pendientes; los del adversario, nunca. Un depósito incluido en el bloque de altura `b`
  madura cuando la cadena seleccionada alcanza la altura `b + M_dep` **con ese bloque dentro**.
- **Estrategia.** Cada vez que aparece en la cadena seleccionada un bloque honesto con depósito, el
  adversario empieza a minar en privado desde su padre (altura `b−1`) y publica cuando su rama
  privada es **estrictamente** más larga que la seleccionada. Si lo consigue antes de que el
  depósito madure, el depósito sale de la cadena y vuelve al mempool; si madura, el corte ocurre.
  Solo persigue un depósito a la vez.
- **Horizonte:** `10⁴·T_pow`; si no hay corte, la réplica se cuenta como **censurada**.
- Se mide: retraso del corte (media y p99, en `T_pow`) y fracción de bloques de la cadena
  seleccionada minados por el adversario hasta el corte (emisión capturada).

**Simulador.** Eventos exponenciales: honesto a tasa `1−h`, adversario a tasa `h`. El retraso se
reporta como instante del corte desde `t = 0`; el corte sin adversario tendría media `1 + M_dep`
(`Gamma(1+M_dep, 1)`). La “fracción capturada” es `bloques_adversarios_en_la_seleccionada / altura`
en el instante del corte.

## 6. E5 · cadena de baja dificultad (solo cualitativo)

`W_min` importa porque un adversario que fabrica una rama con dificultad rebajada puede alcanzar la
altura `H_corte_min` **sin** el trabajo acumulado mínimo, y el corte por altura sola aceptaría un
terminal barato; `W_min` lo impide. Este modelo **no** mide ese ataque porque prohíbe el retarget
(§3.1 de la orden) y fija `W_min` como no ligante (`todos los bloques valen 1`); no se inventa un
modelo de retarget.

## 7. Qué NO es este modelo

Sin latencia, sin retarget, sin GHOSTDAG real (`k = 0`, cada bloque PoST tiene un padre implícito en
la cadena), sin sesgo de semilla (A-07), sin precios de hash (A-10), sin doble farmeo. Ver la
sección «Lo que este modelo NO demuestra» en `INFORME.md`.
