# HIPÓTESIS QUE CODIFICAN LA CONCLUSIÓN — PCO-v0.1

Supuestos que, **fijados por definición**, vuelven tautológico o casi tautológico algún resultado
de este instrumento. Cada uno lleva: qué fija, qué resultado se vuelve trivial si se acepta, y en
qué dirección se movería la conclusión si fuera falso.

Los tres que el encargo exige están aquí: **H-UNO** (cada honesto sigue un solo flujo), **H-S**
(el reparto `s₁/s₂`) y **H-RETARGET** (el modelo de retarget).

---

## H-UNO · «Cada honesto sigue un solo flujo» — **SE RECHAZA COMO SUPUESTO, ES UN EJE**

`P-2.1/ENCARGO.md` §4.0 advierte: *«Si `MODELO.md` supone que cada honesto elige un flujo y se
queda, ese supuesto codifica la conclusión»*. Correcto, y por eso aquí **no se supone**: es el eje
`c`.

- `c = 0` es exactamente «cada honesto sigue un solo flujo». Si se fijara `c = 0`, la deriva sería
  máxima y la partición se resolvería en tiempo finito **por definición**: sería la conclusión
  escrita como premisa.
- `c = 1` es exactamente «todos cubren todos los flujos», la premisa histórica de la fila 1 de
  `research/dag-poas-candidatos-auditoria.md:33`. Si se fijara `c = 1`, la deriva sería **cero por
  construcción** y «no converge» sería igual de tautológico, en la otra dirección.

**Lo que sí queda codificado, y hay que decirlo:** la producción es una lotería de espacio con
tasa proporcional a `W_i`, es decir, **cubrir un flujo se traduce linealmente en billetes en ese
flujo**. Eso es lo que hace que «cubrir ambos» no cueste espacio, y es el mecanismo medido en
`research/dag-poas-ancla-de-finalidad-metaauditoria.md:130-161`. Si un diseño obligara a **dividir**
el espacio entre flujos, `W₁+W₂ = 1` en vez de `1+c`, la deriva cambiaría y todas las cifras de §2
dejarían de aplicar.

---

## H-S · El reparto `s₁/s₂` de los no cubridores — **PARÁMETRO LIBRE, NO ESTIMADO**

`W_i = c + (1−c)s_i`. La deriva es `∝ (1−c)(s₁−s₂)`, un producto de **dos** factores.

- **`s₁ = s₂ = 1/2` hace la deriva exactamente cero para cualquier `c`**, incluido `c = 0`. Es
  decir: fijar un reparto simétrico codifica «la partición no se resuelve» con la misma fuerza con
  la que `c = 1` lo codifica. Es el defecto que `P-2.1/ADENDA-2.md` §3 señala («`s₁ = 0,5` daría
  deriva nula»), y por eso `s₁` se barre en `{1/2, 11/20, 3/5, 3/4, 9/10, 1}` y **el caso simétrico
  se publica aparte**, no se promedia con los demás.
- **Este instrumento no estima `s₁`.** El reparto lo produce el suceso que crea la partición —qué
  fracción de los nodos exclusivos leyó cada ancla—, y eso es la pregunta A de `P-2.1`
  (`G(d)` y `L_mín`), no ésta. Cualquier afirmación sobre «cuánto tarda en resolverse una
  partición real» exige una distribución de `s₁` que **no existe medida en el repositorio**.
- El caso `s₁ = 1` («todos los exclusivos en un flujo») es el más favorable a la resolución y el
  menos verosímil para una partición nacida de un desacuerdo de ancla entre dos grupos.

---

## H-RETARGET · El modelo de retarget — **DOS RAMAS, LAS DOS ENTREGADAS**

Lo que se supone: que el retarget de cada flujo actúa **sobre su propio conjunto pagable** y
**converge a una tasa objetivo común** (R-FIN-13′, `SPEC.md:1289-1291`).

- **Si se acepta y ha convergido** (régimen): `λ₁ = λ₂` y `w_i ∝ W_i`. La deriva `∝ (1−c)(s₁−s₂)`
  sale de ahí.
- **Si no ha convergido** (transitorio): `w₁ = w₂` y `λ_i ∝ β_i·W_i`. Misma deriva, **distinta
  varianza**, y además `β` entra con signo (favorece al minoritario).
- **Lo que NO se supone:** que la cancelación del `SR` dependa del retarget. No depende: §1 del
  `MODELO.md` la demuestra en enteros exactos para **cualquier** `SR`. Suponer lo contrario —en
  cualquiera de los dos sentidos— es precisamente el defecto 2 de `P-2.1/ADENDA-2.md`.
- **Lo que queda codificado:** que los dos flujos apuntan a la **misma** tasa objetivo. Si el
  objetivo de retarget dependiera del flujo (por ejemplo, si el conjunto pagable se midiera con
  ventanas de distinta longitud), `β₁ ≠ β₂` en régimen y `R_i ∝ W_i` dejaría de valer. No hay en el
  repositorio ninguna medición que fije la longitud de esa ventana.

---

## H-BETA · La fracción azul se modela como `P(Poisson(2νΔ) ≤ k)`

**No es un teorema de GHOSTDAG.** Es la aproximación habitual del anticono en un DAG de Poisson.

- Si se acepta con `k` holgado frente a `2νΔ` —el caso de la rejilla del SPEC, `k = 30`, `Δ = 4 s`,
  `ν ≈ 1`— entonces `β₁ ≈ β₂ ≈ 1` y el resultado `R_i ∝ W_i` del punto 1 se vuelve **casi
  tautológico**: se ha supuesto lo que se quería concluir, con un error de `10⁻⁵`.
- Por eso el resultado se entrega como dependencia de `β₁/β₂` y `resultados/peso-beta.csv` barre
  `Δ ∈ {1,4,16} s` y `k ∈ {18,30}`: con `Δ = 16 s` y `k = 18` el sesgo llega al **50–90 %**, y
  entonces `∝ W_i` es sencillamente falso.
- Dirección del error: el modelo de anticono Poisson **sobrestima** `β` para un DAG real con
  retardos correlacionados, y el sesgo siempre favorece al flujo **minoritario**, es decir
  **estabiliza la partición**. Si `β` fuera peor de lo modelado, la partición se sostendría más,
  no menos.

---

## H-EMPATE · El empate `D = 0` va al flujo 2

La fórmula y la simulación usan la misma convención: **el flujo 1 lidera si y solo si `D > 0`**.

- El empate es un **artefacto de la normalización**: al medir `D` en unidades de `w₂` el proceso
  cae en una retícula y `D = 0` tiene probabilidad positiva. En ZEROX los pesos son enteros de 128
  bits derivados de dos `SR` distintos y `C-ORD-01` aún rompe empates por `solution_distance` y por
  id (`SPEC.md:1367-1370`), así que un empate exacto de `blue_work` entre flujos tiene probabilidad
  del orden de `2^{-128}`.
- La sensibilidad está **acotada y publicada**: `prob_empate(f,t)` da `P(D(t)=0)`, que es la masa
  máxima que la convención puede mover. Decae como `O(1/√t)` y en el régimen con `r` de denominador
  grande cae a `10⁻²⁶`. Ninguna conclusión del informe depende de ella.

---

## H-TAMANOS · La distribución de tamaños de granja es Pareto

`cobertura_equilibrio` necesita saber qué fracción del espacio está en granjas por encima de `x*`.
Se usa una Pareto de exponente `α ∈ {1, 2}` sobre una rejilla logarítmica.

- **El repositorio no tiene ninguna medición de esto.** Es el supuesto más débil del punto 3, y el
  que más mueve el resultado: con `α = 1` (cola gruesa, mucho espacio en granjas grandes) `c` se
  acerca a 1; con `α = 2` se desploma.
- Por eso el resultado que se publica del punto 3 **no es un valor de `c`**, sino `x*` —el tamaño
  mínimo de granja para el que cubrir es racional— que **no depende de H-TAMANOS**. `c` se da como
  ilustración de qué hace falta para que `c → 1`, con la Pareto etiquetada.

---

## H-SIN-ATACANTE · Todo el análisis es sin adversario

No hay atacante en ninguna parte del instrumento. Los únicos desvíos son los del muestreo honesto.

- Eso es lo que pide el encargo («¿se sostiene **sola**?»), y es también su límite: un adversario
  con fracción `α` del espacio puede sostener la partición añadiendo espacio al flujo que va
  perdiendo, y basta con que iguale `(1−c)(s₁−s₂)` para anular la deriva. El coste de hacerlo es la
  pregunta B de `P-2.1`, no ésta.
- Dirección: **todas** las conclusiones de este instrumento sobre resolución de la partición son
  cotas **optimistas**. Con atacante, la partición se sostiene más.

---

## H-VISTA-COMUN · Todos los honestos ven el mismo DAG — **ES LA QUE DECIDE EL §2.3**

Sin atacante y sin asimetría de red, los honestos comparten vista, luego comparten líder.

Bajo la lectura literal de R-FIN-7 (profundidad de la reorganización, no tiempo desde la adopción),
**este supuesto no matiza el resultado: lo determina por completo**. Todos los nodos se congelan a
la vez en `t_j + F`; si su vista es idéntica, se congelan en el mismo flujo y
`P(bloqueo divergente) = 0` **por construcción**. Aceptar H-VISTA-COMUN al pie de la letra es
escribir la conclusión «la partición se resuelve» como premisa.

Por eso el instrumento **no la acepta**: la relaja con un parámetro explícito, el desfase `τ`, y
todo el §2.3 es la medida de cuánto se paga por esa relajación. `τ = 0` devuelve `P_div = 0`, que es
exactamente la tautología, y el resultado se publica como **función de `τ`**, nunca con `τ` fijado.

## H-DESFASE · El desacuerdo de vista se modela como un retraso puro `τ`

Se supone que la vista de un nodo retrasado `τ` es `D(t−τ)`: ve **todo** lo producido hasta `t−τ` y
**nada** de después.

- **Qué codifica.** Que los dos nodos ven prefijos encajados del mismo flujo de bloques. Es el caso
  más favorable: dos vistas reales pueden diferir en bloques **cruzados** (A ve uno que B no y
  viceversa), y entonces el desacuerdo es mayor que el de un retraso puro de la misma magnitud.
  `P_div(F,τ)` es por tanto una **cota inferior** del desacuerdo real a igual dispersión.
- **La alternativa, también entregada.** `prob_banda` acota por `P(|D(F)| ≤ δ)` sin suponer nada
  sobre la forma del desacuerdo, sólo su tamaño `δ`. Sale **5–7 veces mayor**: esa horquilla es la
  medida de cuánto está haciendo H-DESFASE.
- **`τ` no se fija.** Se barre en `{1, 4, 16, 60}` s. El repositorio no tiene `Δ` medido en una red
  ZEROX con DAG (`MIGRACION.md`: *«Sin medir en una red ZEROX con DAG; 4/16/20 s son escenarios»*).

## H-RECIEN-LLEGADO · Un nodo que sincroniza toma el líder del momento y ya no puede cambiar

Se supone que un nodo que hace IBD después de `t_j + F` elige la punta de mayor `blue_work` al
llegar, y que a partir de ahí R-FIN-7 le impide cruzar (su bifurcación ya está a profundidad `> F`).

- **Qué codifica.** Que la primera selección de un nodo sin cadena previa **no** es una
  «reorganización» —si lo fuera, un nodo nuevo no podría elegir nada— pero la segunda sí. R-FIN-7 no
  dice nada sobre el arranque: es un hueco de la regla, y de ese hueco sale todo el canal de §2.3
  consecuencia 3, cuya probabilidad `L(F)` vale **1** con deriva nula.
- **Si la regla se completara** —por ejemplo, con un ancla de arranque, o exigiendo que un nodo
  nuevo espere `F` antes de fijar— ese canal se cierra y el §2.3 se queda sólo con el desfase de
  vista. **Es la laguna más barata de cerrar de todo el informe**, y está en la redacción de la
  regla, no en el cálculo.

## H-PRODUCIR-SIN-SELECCIONAR · Un granjero puede firmar bloques en un flujo que no ha seleccionado

Se supone que, después de `T* = t_j + F`, los granjeros que cubren los dos flujos **siguen
produciendo en los dos**, aunque su nodo tenga ya congelada su cadena seleccionada en uno.

- **Base.** R-FIN-7 dice *«no reorganizar su **cadena seleccionada**»*: constriñe qué historia sigue
  el nodo, no qué bloques puede firmar. Y §3 dice que cubrir todos los flujos vivos es lo racional
  mientras el pago marginal supere el coste. **Es una lectura de la letra, no una regla escrita.**
- **Qué codifica, y cuánto.** Es lo que mantiene vivo el flujo perdedor después del congelamiento y,
  con él, **todo el canal de los recién llegados**. Si la implementación atara producir a
  seleccionar —o si una regla lo exigiera—, después de `T*` el flujo perdedor dejaría de recibir
  bloques, `D` se alejaría de cero monótonamente y `L(F)` dejaría de ser la magnitud: el canal
  dominante del §2.3 **se cerraría solo**.
- **Dirección.** Aceptarla es el caso **pesimista**. Negarla exige una regla nueva (y entonces hay
  que preguntarse qué impide a un atacante firmar en los dos flujos de todos modos, que es la
  pregunta B de `P-2.1`).

## H-PoT-COMUN · Los dos flujos avanzan al mismo ritmo de PoT

Los slots son índices de PoT (R-FIN-13) y el PoT es una cadena secuencial de AES: su ritmo lo fija
el hardware, no el consenso. Se supone que los dos flujos avanzan a la misma velocidad de slots.

- Si un flujo tuviera un productor de PoT más rápido, su reloj correría más y su tasa de bloques
  por segundo de pared sería mayor: aparecería una deriva **que no está en este modelo**, con signo
  arbitrario. `research/dag-poas-ancla-de-orden.md:342` mide `prove = 1,561 s/slot` en un 9950X3D y
  dice explícitamente que **esa máquina no llega a 1 s/slot**: la dispersión de hardware entre
  productores de PoT no es despreciable y no está acotada en ninguna parte.
- Es, junto con H-S, el supuesto cuya violación más fácilmente cambia el signo de la conclusión.
