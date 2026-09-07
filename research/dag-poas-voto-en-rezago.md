# Voto en el rezago — cuarta propuesta para un DAG sobre PoAS

**Fecha:** 2026-09-07 · **PROPUESTA SIN AUDITAR.** Idea aportada por Katana desde una fuente externa;
transcrita con tres correcciones y dos condiciones numéricas del agente principal (marcadas ★).
Rondas anteriores y sus refutaciones: `dag-poas-auditoria.md`, `dag-poas-inyeccion-auditoria.md`,
`dag-poas-candidatos-auditoria.md`. Debe pasar por D9 y D8.

## 0 · La observación que la distingue de las tres anteriores

En Autonomys la entropía del inyector no cambia los desafíos en el momento: se aplica al flujo del
PoT con un rezago (`POT_ENTROPY_INJECTION_DELAY = 15` slots). **Durante el rezago, dos candidatos a
inyector producen exactamente los mismos desafíos.** Ahí hay una sola lotería, cada victoria es un
solo bloque y ese bloque tiene un solo conjunto de padres. La conservación del recurso que PoW tiene
en cada intento, y que PoST no tiene entre relojes (tercera ronda, D9 §2: dos flujos = dos loterías
independientes, cubrir ambas es dominante, deriva cero), **existe en PoST mientras dura el rezago**.
Las tres rondas anteriores dejaban coexistir candidatos toda una época con loterías ya divergentes.
Esta propuesta usa el rezago como ventana de voto y no deja que los candidatos le sobrevivan.

## 1 · Algoritmo

Parámetros en slots: intervalo de inyección `I` (fijado por el reloj: `t_k = k·I`), ventana de
candidatos `w`, ventana de voto `V`, banda de corte `k_c`. Rezago total `= w + V + k_c`.

1. **Candidatos de la inyección k** (★ corregido): los bloques azules con `slot ∈ [t_k, t_k + w)` en
   `past(b)`. No «el primer slot no vacío»: con esa definición un bloque retenido en el slot exacto
   `t_k` y publicado dentro de la banda se convertía en el único candidato de ese cono (los honestos
   no tenían ninguno en `t_k` el 37 % de las veces a λ = 1) y todos los votos honestos pasaban a ser
   votos a un no candidato. Un candidato sin votos pierde aunque sea el más temprano. El atacante
   solo añade candidatos ganando billetes en `w`: `α·λ·w` de media.
2. **Rezago compartido.** Durante `[t_k, t_k + w + V + k_c)` los desafíos son comunes a todos los
   candidatos por construcción: la entropía de ninguno se ha aplicado.
3. **Voto mecánico.** Un bloque con `slot ∈ [t_k + w, t_k + w + V)` endosa al candidato que lidera el
   recuento en `past(padre seleccionado)`; empate, menor `solution_distance` del candidato (no hash:
   D8, ronda 2). El granjero no elige nada salvo sus padres; el protocolo honesto es referenciar
   todas las puntas. Cobra lo mismo vote lo que vote.
4. **Ganador** (★ corregido): para un bloque `b` cuyo padre seleccionado tiene `slot < t_k + w + V`,
   `ganador(b)` = candidato con más endosos entre los bloques azules de la ventana de voto en
   `past(b)`. Para un bloque cuyo padre seleccionado ya tiene `slot ≥ t_k + w + V`,
   **`ganador(b) = ganador(padre seleccionado)`**, heredado. Sin esto, dos bloques de la misma
   cadena seleccionada pueden recontar distinto por sus padres extra y el padre seleccionado queda
   rojo, que es la contradicción que D9 encontró en la tercera ronda (rompe «cadena ⊆ azules»).
5. **Desde `t_k + w + V + k_c` solo continúa el PoT del ganador.** Un bloque cuya solución no es
   válida bajo el ganador que su propio pasado determina es **inválido** (autoinconsistente;
   validez absoluta, sin relatividad al fusionador). Un bloque válido bajo su propio pasado pero
   con ganador distinto al de otro cono es **rojo** allí: referenciable, sin peso, sin recompensa.
   Curación por fusión conservada.
6. **Unicidad de billete.** La misma victoria con dos conjuntos de padres = dos cabeceras con el
   mismo sector y slot: castigo al sector (quema de recompensa de la época, inhabilitación P
   épocas), prueba = dos firmas, sin verificar ningún reloj. Madurez de coinbase ≥ P épocas.
7. **Peso, DAA, emisión**: solo sobre azules; peso `Σ ⌊2^128/(SR+1)⌋`; coinbase de rojos no se
   aplica; k en el punto fijo de la realimentación del retarget (D9, tercera ronda: 24 a q = 1).

## 2 · Por qué responde a cada objeción anterior

| Objeción | Respuesta |
|---|---|
| Dos loterías, cobertura dominante, deriva cero (D9, ronda 3) | Solo hay dos loterías **después** del rezago, y para entonces cada cono tiene ganador. Coexisten solo en la banda de ruido de propagación |
| Granularidad de la exclusividad por sector (agente principal) | Un granjero pequeño con una victoria en la ventana emite exactamente un voto, sin declarar nada. La exclusividad opera en cada victoria porque en el rezago los dos relojes son el mismo |
| Cota de candidatos (D8, ronda 3) | `α·λ·w` candidatos del atacante por inyección |
| Validez relativa y curación (D8, ronda 2) | Validez absoluta por autoconsistencia; rojo, no inválido, en otros conos |
| Balance attack | El supuesto «los honestos convergen» que D8 usó en su simulación (17-24 s con α = 1/3) deja de ser racional y pasa a ser mecánico; realimentación tipo GHOST |
| Revelación tardía | Votos retenidos en la banda `k_c` cambian el ganador solo si superan el margen honesto `≈ (1−2α)·λ·V`; con votos del atacante `≤ α·λ·V` hace falta `α > 1/3` |
| Lookahead | Rezago `w + V + k_c ≈ 40-60` slots ⟹ lookahead `≈ rezago − D`, **3-5× Autonomys**. Con 69,363 s/sector medidos, décimas de GiB por GPU |

## 3 · Condiciones numéricas nuevas (★)

- **Ceguera del voto.** Un atacante con candidato propio quiere votar al candidato cuyo flujo
  posterior le favorezca. Para saberlo debe computar el flujo de cada candidato durante la época
  siguiente (`≈ I` slots) dentro de `V`. Condición: **`v_max < I / V`**. Con `I = 200`, `V = 40`:
  `v_max < 5`. Hay que fijar qué `v` es defendible para AES (Autonomys: AES-NI cerca del límite de
  hardware; sin fuente que dé un número).
- **Double dipping con época en tiempo.** `t_k = k·I` es la época en tiempo que D9 refutó en la
  ronda 2: niveles del árbol privado del atacante `c_a = α·λ·I`, no `λ·I`; umbral punto fijo
  `α* = 1/(1+φ(α*·λ·I))` (D9: 0,459 a q = 1 con I = 300; 0,394 a q = 10). Asumible a λ = 1; no a
  λ = 0,1. **q e I se deciden juntos.**

## 4 · Lo que no está demostrado

- Que el recuento converja antes de la divergencia de desafíos bajo balance con `α = 1/3`, y qué
  `V` hace falta: ¿la banda de ruido es de segundos (dos candidatos nombrados, recuento) o reaparece
  la cola de 101 s de la identidad de la cadena seleccionada (D9, ronda 2)?
- Que el atacante con candidato propio no pueda sesgar cuando los honestos están divididos, más allá
  de la condición de ceguera.
- Que la regla 3 (elección de padres con consecuencias de consenso) no interactúe mal con la poda.
- `V` frente al lookahead, con número.
- Toda la deuda de ingeniería de D8 sigue abierta: cliente ligero, poda sin niveles de PoW,
  C-REORG-07 en tiempo, C-EXP-04 con altura por cadena seleccionada, `Dmax`, k.
