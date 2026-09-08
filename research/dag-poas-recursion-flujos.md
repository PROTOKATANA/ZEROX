# La recursión R-FIN-5 / R-FIN-7 contra la Propiedad 1 — escrita, y con número

**Fecha:** 2026-09-08 (madrugada, modo autónomo) · **Origen:** D9-b, A4 (`dag-poas-ancla-de-orden-auditoria-2.md` §5):
*«la circularidad de fondo es real pero no viciosa — es una recursión por épocas que nadie ha
escrito»*, con dos LAGUNAS: (a) nadie ha escrito la inducción; (b) **la constante `c` de Prop. 7 no
está calculada en ninguna parte**. Aquí se escribe la inducción y se cierra (b) con lo que el paper
sí da. **Script:** `research/scripts/verif_recursion.py`.

---

## 1 · El problema, sin la cláusula que prueba demasiado

D9-a lo formuló con la cláusula de Def. 2 *«If `B ∉ G^u_t` we define `Risk_u(B,t,r) = 1`»*
(`phantom-ghostdag.txt` L534-535) y el máximo sobre honestos (L539). D9-b refutó ese vehículo: el
mismo argumento hace fallar la Propiedad 1 en GHOSTDAG puro por simple retardo, y **el paper declara
ese hueco él mismo** (L571: *«We leave the task of bridging this gap to a later version»*).

Lo que sí es específico de R-FIN-5 + R-FIN-7 es la **permanencia**: con retardo, un bloque entra en
todas las vistas tras `Δ`; con R-FIN-5 los bloques de otro flujo **no entran nunca**, y con R-FIN-7
nadie vuelve atrás pasadas `F = 3,2 h`. **Una partición de flujo no se cura.** La pregunta correcta es
por tanto: **¿con qué probabilidad nace una partición de flujo, a lo largo de la vida del sistema?**

## 2 · La dependencia, y por qué es una inducción y no un círculo

```
Prop. 7 sobre un DAG sin partición   ⇒  posición c·j de la cadena estable a profundidad F
                                      ⇒  P[dos honestos leen I_j distinto en t_j] pequeña
                                      ⇒  no nace partición en la época j
                                      ⇒  sigue habiendo un solo DAG   ⇒  aplica Prop. 7 en j+1
```

**Enunciado inductivo.** Sea `E_j` = «al final de la época `j` todos los honestos comparten flujo».
`E_0` vale por construcción (génesis, un solo flujo). Si vale `E_{j−1}`, el DAG de la época `j` es
uno solo y **la hipótesis de Prop. 7 se cumple**; `I_j` está a profundidad `F` en `t_j`, y
`P[¬E_j | E_{j−1}] ≤ P[reorg de la cadena seleccionada más profundo que F]`. Luego, por la cota de la
unión sobre `N` épocas: `P[∃j ≤ N : ¬E_j] ≤ N · p_F`. **No es un círculo lógico**: es un argumento
sobre el tiempo de parada «primera época con desacuerdo», y cada paso usa Prop. 7 solo bajo la
hipótesis inductiva.

**Lo que hace falta y sigue siendo LAGUNA, declarada:** Prop. 7 tal como está enunciada no es
*condicional*; el paper mismo dice que analizar el sistema «desde la perspectiva de cada nodo» es un
hueco abierto (L571). La inducción de arriba es la forma correcta de cerrarlo, y **no está demostrada
en el paper para GHOSTDAG puro**, mucho menos con U3′/R-FIN-5/R-FIN-8. Lo que sigue **no** es una
demostración: es la cota que el propio paper usa para Prop. 7, aplicada al paso inductivo.

## 3 · La constante `c`: el paper no la da, pero sí da de dónde sale

Prop. 7 (L1058-1061): *«O(e^{−cr}), where **c depends only on the system parameters**»* — sin
fórmula. Pero la demostración del **Lema 10** (L1226-1236, literal) sí dice cómo se calcula:

> *«the stationary distribution is governed by an exponent with base **α/((1−α)(1−δ))** rather than
> α/(1−α)… by assuming the attacker always manages to saturate this constant, so that their advantage
> never goes below **3k**, we can shift the process adv′(t) by 3k and **analyze it as a block race**,
> utilizing the result from [18].»*

Es decir: **una carrera de Nakamoto** con crecimiento honesto `(1−α)(1−δ)λ`, atacante `αλ`, y
ventaja inicial `3k`. Es exactamente el modelo de `verif_constantes.py` §3 (que D9-b ya contrastó con
el paper). Con `k = 25`, `δ = 8/33 = 0,2424`, `F = 11 520 s`, `I = 2 490 s` ⇒ **12 665 épocas/año**:

| `α` | base `r = α/((1−α)(1−δ))` | `p_F` = P(reorg > `F`) por época | unión 1 año | **unión 10 años** |
|---:|---:|---:|---:|---:|
| 0,10 | 0,147 | 0 (subdesbordamiento) | 0 | 0 |
| 0,25 | 0,440 | 2,6·10⁻²⁵⁰ | 3,3·10⁻²⁴⁶ | 3,3·10⁻²⁴⁵ |
| 0,33 | 0,650 | 1,3·10⁻⁹⁰ | 1,7·10⁻⁸⁶ | 1,7·10⁻⁸⁵ |
| **0,40** | **0,880** | **2,0·10⁻⁸** | **2,6·10⁻⁴** | **2,6·10⁻³** |
| 0,45 | 1,080 | 0,57 | 1 | 1 |

**La base `r` cruza 1 en `α = (1−δ)/(2−δ) = 43,1 %`.** Ahí la deriva deja de favorecer al honesto y
la cota se vuelve vacua. D9-a, con el `δ_ef` que midió bajo U3′-posproceso, la situó en 37,5 %; con
el `δ` del paper (que es el que aplica bajo U3′-filtro, si D9-c lo confirma) es 43,1 %.

## 4 · Lo que esto establece y lo que no

**Establece:**
- La recursión **se cierra numéricamente** para `α ≤ 0,33`: la probabilidad de que nazca una
  partición de flujo en 10 años es `< 10⁻⁸⁴`. A ese nivel, «la partición no se cura» es irrelevante
  porque no ocurre.
- **A `α = 0,40` la cota a 10 años es 2,6·10⁻³.** No es despreciable. El umbral publicado de
  ~40,7 % (`dag-poas-ancla-de-orden.md`) **está en el borde** donde la garantía de flujo único deja
  de ser fuerte. **Región de operación honesta: `α ≲ 0,35`** para una vida de 10 años con
  `P(partición) < 10⁻¹⁰`.
- La constante `c` **no es una laguna abierta**: es la tasa de la carrera de bloques del Lema 10, y
  está calculada arriba.

**No establece (LAGUNA, con etiqueta):**
1. Prop. 7 **condicionada** a la hipótesis inductiva: el paper deja ese hueco (L571) y aquí no se
   cierra; se usa su cota como si fuera condicional. **PLAUSIBLE**, no DEMOSTRADO.
2. Que el `δ` aplicable sea el del paper (0,2424) y no algo mayor: depende de que U3′-filtro
   restituya «1 billete = 1 bloque» —D9-b lo midió (`δ_ef ≈ 0`, cinco estrategias hasta `α=0,45`,
   peor caso 0,0759) pero no lo demostró—, y de lo que D9-c encuentre en A1/A3.
3. Que `3k` sea la ventaja real y no solo cota (Lema 12): D9-b midió máximo real 26 ≈ `k`, así que
   la cota es **holgada** y los números de arriba son **pesimistas**.
4. La tabla usa `p_F` **por época**; si el atacante concentra su esfuerzo en una época elegida, la
   cota de la unión es la correcta y ya está incluida. Si ataca **varias a la vez**, el modelo no
   cambia (cada época es una carrera independiente desde `3k`).

## 5 · Consecuencia para el diseño

El umbral de seguridad del DAG sobre PoAS **no es un número, son dos**:

| | valor | de dónde |
|---|---:|---|
| Umbral de **orden** (reversión de transacciones) | ~40,7 % | `Lema 9 ⊗ φ₅₀₀`, `dag-poas-ancla-de-orden.md` §1 |
| Umbral de **flujo único** (que no nazca partición en 10 años) | **~35 %** | esta nota, §3-4 |

El segundo es más restrictivo, y es el que hay que publicar como umbral del sistema mientras
R-FIN-5/R-FIN-7 hagan las particiones permanentes. Chia desplegado está en 40,5 %; Bitcoin en 50 %.
