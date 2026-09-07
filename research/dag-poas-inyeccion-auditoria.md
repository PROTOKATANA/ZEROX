# Inyección anclada en DAG — auditoría D9 + D8 (segunda ronda) y cierre

**Fecha:** 2026-09-07 · Audita `dag-poas-inyeccion-anclada.md` · Cierra la segunda parte de **P-038**
con veredicto negativo · Corrige la formulación de **P-039** · D9 y D8 en Opus, scripts en el
scratchpad de la sesión (`d9/{inyector_phi,lookahead,chain_agree,L_para_1e-9}.py`,
`d8b/{ghostdag_sim,drive,ties}.py`).

## 0 · Veredicto

La propuesta **cierra los dos fallos de la primera ronda** (D8 lo midió: el inyector honesto deja
de cambiar a los 57 s en p99 a q=1; la fusión entre flujos queda prohibida) **y abre otros que son
de diseño, no de parámetro**. No pasa la condición de Katana.

| Afirmación / regla | D9 | D8 |
|---|---|---|
| R-INJ-1 (inyector = primer bloque de cadena seleccionada de past(B) con slot ≥ E_j) | **REFUTADA: circular.** La cadena seleccionada depende de la validez de bloques posteriores a t_j, que depende del inyector. Reparable: calcularla sobre past(B) ∩ {slot < t_j}, por inducción sobre épocas | — |
| §3.1 split honesto | Justificación refutada: el Teorema 4 de GHOSTDAG acota el **orden de pares**, no la cadena seleccionada; nadie prueba prefijo común sobre ella. Medido sin atacante: la cadena seleccionada difiere de la final el 41 % del tiempo a q=1, máximo 101,5 s. Con atacante, L necesario: 377 s (q=1, α=0,25, k=18), **2 133 s a q=10**, **2,1 h con la k de la ec. (2) completa** | **Cerrado en el caso honesto** (p99 57 s a q=1, 21 s a q=10) |
| §3.2 multi-flujo | Sobrevive con supuestos: R-INJ-2 lo cierra | Cerrado, al precio de los hallazgos 3-5 |
| **§3.3 lookahead «igual que Autonomys»** | **REFUTADA por dos órdenes.** El lookahead de Autonomys es `DELAY − D = 11 s`, no 15 min: la entropía se conoce con 10 min de antelación pero el **instante** `slot(50j)+15` no existe hasta que el bloque 50j se produce. En la propuesta el instante `t_j = slot(I_j)+L` es público con L de antelación. Fórmula correcta: `lead = L + g − D + I(1−1/v)` = **17,4 min** con L=900, I=300, v=2; y ≈15 min incluso con v→1⁺. Ratio **95×**. Ploteo dirigido: 15,1 GiB por GTX 1070 (medido), 261 GiB por GPU tope (extrapolado) | Cuantificó el ploteo dirigido como no rentable (6,5 GiB/GPU) usando la fórmula de la propuesta; con la de D9 el número es el de la izquierda |
| §3.4 φ menor con épocas en tiempo | **REFUTADA.** El `c` de BDK+19 son niveles del árbol **del atacante**: `c_a = α·λ·I`, no `λ·I`. Umbral: 0,459 a q=1 (por casualidad mejor), **0,394 a q=10** (peor que 0,438), **sin objeto a q=120**. Corolario: `c = 50` se queda **en bloques** | **Palanca 4× mayor**, no igual: en el borde de época hay ~4 candidatos honestos incomparables (medido: media 4,09 a q=1) y el atacante elige cuál es el inyector con un billete, ganando el empate por hash |
| R-INJ-2 (no fusión) | Sobrevive; determinista con E1 reparado; **no** reintroduce n-split (dos flujos exigen dos billetes distintos) | **Hace la validez relativa al fusionador**: el mismo bloque válido para B e inválido para B′. Incompatible con `BlockStatus` global de rusty-kaspa; dos implementaciones que cacheen distinto divergen. **Elimina la curación por fusión**: un eclipse de 15 min deja al nodo con ~600 bloques que no puede reconciliar; con C-REORG-07 actual, `exit`. Kaspa fusiona y no pierde nada |
| R-INJ-3 (U3′) | Sobrevive | Sobrevive |
| R-INJ-4 (peso/DAA/emisión solo azules) | Retarget: **no existe en la literatura** para DAG bajo PoAS. Contador multiplicativo sobre azules converge en modelo honesto; bajo atacante el Lema 9 permite sesgar el conteo de azules un **31 %** a q=1 → SR se ensancha → más bloques → k se queda corto. Realimentación no analizada | Falta decir que la **coinbase de un rojo no se aplica**: rusty-kaspa aplica las tx de los rojos; con coinbase dentro del bloque, 1 billete → hasta 10 coinbases |
| R-INJ-5 (anticono anclado a slot) | **Obligatoria, no opcional**: X < L es condición de buena definición del inyector | Con X ≪ L, toda partición > X destruye el lado minoritario; griefing por retraso selectivo |
| Desempate por hash de GHOSTDAG | — | **Gratis bajo PoAS** (re-firmar cambia el hash) y decide inyector, retarget y altura: 35 % de empates a q=1, 96 % a q=120 |
| Épocas colapsadas (hueco de cadena > I) | — | Laguna de especificación con final en split; a q=120 e I=300 s ocurre en el 8 % de las épocas |
| C-EXP-04 en el DAG | — | «Altura» sin definir; por posición en el orden, las copias rojas gratis la mueven; por cadena seleccionada, VIDA_MINIMA pasa a 3,8 días a q=1 |
| Confirmación «mismo riesgo en menos tiempo» | Sobrevive para el riesgo de orden; aparece un segundo término `P(discrepancia de I_j)` que **invalida** en vez de reordenar y que domina si L es corto | — |

## 1 · Lo que la segunda ronda enseña, y que la primera no había dicho

1. **El «slot de la punta + 15» de Autonomys no es una comodidad: es el mecanismo de seguridad.**
   Yo lo llamé comodidad (basado en el foro 1615 #3). D9 lo corrige: el lookahead de Autonomys es
   11 s **porque el instante de inyección no existe hasta que aparece el bloque 50j**. Cualquier
   diseño que haga el instante predecible con L de antelación paga L de lookahead. Y hacerlo
   impredecible exige un **evento acordado a profundidad cero**, que una cadena lineal a q=120
   tiene (el bloque 50j es único el 94 % de las veces, D8) y un DAG a q pequeño **no tiene** (~4
   candidatos incomparables en el borde). Ese es el núcleo estructural, y no es un parámetro.
2. **La regla de no fusión resuelve el multi-flujo quitando al DAG la propiedad por la que existe**:
   fusionar en vez de descartar es lo que hace que un DAG sobreviva a particiones y a la latencia.
   Con R-INJ-2, una discrepancia de inyector no se reordena: invalida. Y la validez pasa a depender
   del fusionador.
3. **L no es derivable hoy**: depende de un teorema de prefijo común sobre la cadena seleccionada
   de GHOSTDAG que nadie ha probado, de `Dmax` (sin medir) y de `k` (sin calibrar; con la ec. (2)
   completa L salta de 6 min a 2,1 h).
4. **Autonomys tiene el mismo dilema y lo resuelve con la cadena lineal**: su propia investigadora
   dejó escrito (2023-08-22) que φ_c aplica a la frecuencia de inyección y el diseño solo garantiza
   la de muestreo. Sin cerrar.

## 2 · Corrección de P-039

La formulación anterior decía «3,3 h de lookahead» a T = 120 s. D9: eso es **rezago de
contenido** (cuánto antes se conoce la entropía), no lookahead (cuántos slots de PoT se pueden
precomputar). El lookahead de ZEROX lineal con las constantes heredadas es `DELAY − D = 11 s`,
igual que Autonomys, porque el instante depende del bloque 50j. Lo que sigue en pie de P-039:

- `interval × lookback == K` es el invariante (PR #1986), no «2 intervalos».
- A T = 120 s, `slot(50j)+15` cae **antes** del bloque siguiente: una reorg de profundidad 1 sobre
  el inyector bifurca el flujo (en Autonomys, ~3 confirmaciones). Esto sí es grave.
- `DELAY = 15` sin derivación; `c = 50` **en bloques**, no en tiempo (D9 §3.4).
- El rezago de contenido de 3,3 h: D9 no lo evalúa como ataque; BDK no analiza si el rezago
  cambia φ_c. Queda como laguna, no como el «13× peor» que D8 calculó con la fórmula equivocada.

## 3 · Qué quedaría para una tercera ronda, y por qué no la recomiendo

Para que un DAG con inyección funcione hace falta un evento **acordado a profundidad cero e
impredecible**. Las tres formas de tenerlo: (a) una cadena lineal a tasa baja (lo que ya hay);
(b) un beacon externo con comité (Filecoin + drand: confianza en el comité); (c) un acuerdo
bizantino por época (Spacemesh: sincronía de relojes, red muerta). Ninguna es «el DAG con PoAS».
La única vía no lineal que no toca ese núcleo sigue siendo **espina + fardos**
(`dag-nativo-poas-propuesta.md` §3), porque los fardos no inyectan, no pesan y no se fusionan.

---

## Anexo A · Informe D9 (Opus), íntegro

He leído la propuesta, mi propia auditoría anterior, `dag-nativo-poas-propuesta.md §2`, el código de Autonomys citado y las fuentes. Scripts nuevos en `/tmp/claude-1000/-home-katana-zeo/0cfccf9e-55ae-4058-bcf4-31f0987f1dbd/scratchpad/d9/`: `inyector_phi.py`, `lookahead.py`, `chain_agree.py`, `L_para_1e-9.py`.

# D9 — refutación de `dag-poas-inyeccion-anclada.md`

## 0 · Dos errores estructurales que atraviesan toda la propuesta

**(E1) La definición de I_j es circular.** R-INJ-1 dice: *I_j es el bloque de la cadena seleccionada **de past(B)** con el menor slot ≥ E_j*. La cadena seleccionada de `past(B)` se calcula desde la punta hacia abajo (`sp(B)=argmax blue_work` entre padres, recursivo), así que depende del `blue_work` de bloques con slot hasta `slot(B)`. Bajo R-INJ-2, la validez —y por tanto la existencia en el DAG y el color— de esos bloques con slot > t_j depende del flujo, que depende de I_j. **I_j = f(cadena(past(B)))**, **cadena = g(bloques válidos)**, **validez = h(I_j)**. No hay orden de evaluación bien fundado y no se demuestra que el punto fijo exista ni sea único. CLASIFICACIÓN: **REFUTADA** (R-INJ-1 tal como está escrita).
*Corrección propuesta:* `I_j := primer bloque con slot ≥ E_j de la cadena seleccionada del bloque virtual sobre past(B) ∩ {slot < t_j}`. Eso sí es bien fundado por inducción sobre j (para decidir la época j solo se usan flujos de épocas < j). Todo lo que sigue lo evalúo sobre esta versión reparada; sobre la versión literal no hay nada que evaluar.

**(E2) La propuesta compara su lookahead con la magnitud equivocada de Autonomys.** «K + intervalo = 15 min» es el **rezago de contenido** (qué antigüedad tiene la entropía). El *lookahead* es otra cosa: cuántos slots de PoT se pueden precomputar. En Autonomys la entropía del bloque `50j` viene del `50j−100` y es **conocida desde hace 10 minutos**; lo único que impide precomputar es que el **instante** de aplicación, `target_slot = slot(50j) + 15` (`pallet-subspace/src/lib.rs:964-971`), no existe hasta que el bloque `50j` se produce en tiempo real. Lookahead de Autonomys = `DELAY − D = 15 − 4 = 11 s`. En la propuesta `E_j = j·I` está fijado por el reloj y `t_j = slot(I_j)+L`, luego el instante de cada inyección futura es **público con ~L+I de antelación**. Son magnitudes que difieren en dos órdenes.

---

## 1 · Afirmaciones de §3

### §3.1 «Split honesto sin atacante: dos honestos discrepan en I_j solo si discrepan en la cadena seleccionada a profundidad L, que es la cota de reorg del Teorema 4»

**VEREDICTO: REFUTADA en su justificación; la conclusión sobrevive como conjetura con supuestos, y las constantes citadas están mal.**

1. **El Teorema 4 no dice eso.** Prop. 7 (ePrint 2018/104, p. 11) acota `Risk(B,t,r)` = probabilidad de que **el orden de dos bloques** cambie. La cadena seleccionada es otro objeto y el paper **no** prueba common prefix sobre ella; al contrario, en la prueba del Lema 9 (p. 11-12) escribe explícitamente que el adversario publicando `k+1` bloques en el anticono del padre seleccionado *«will cause the honest network to switch a chain»*. Un bloque puede salir de la cadena seleccionada **sin que cambie el orden de ningún par** (dos hermanos azules A,B en anticono mutuo: la cadena pasa por A o por B, el orden de linealización del mergeset no cambia). Citar Teorema 4 para acotar P(cambio de cadena) es un cambio de objeto. **RESPALDADO POR FUENTE en contra.**

2. **Medido, sin atacante** (`chain_agree.py`, modelo «todo azul», λ=1/s, D=4 s, 24 semillas × 1200 s, 5 448 muestras): la cadena seleccionada del bloque virtual difiere de la final **el 41 % del tiempo**; `P(profundidad de cambio > 64 s) = 3,7·10⁻³`; máximo observado **101,5 s**. A q=10 (λ=0,1): 1,5 % y máximo 16,4 s. Es decir: la premisa «los honestos solo discrepan si hay reorg profunda» es correcta en dirección, pero a q=1 la cadena seleccionada **reorganiza constantemente** y hace falta L grande. Ajuste exponencial de la cola (tasa 0,0736 s⁻¹) → L ≈ **270 s** para 10⁻⁹ **sin atacante**. Esa extrapolación cubre 8 órdenes de magnitud: **PLAUSIBLE, NO DEMOSTRADA**.

3. **Con atacante** (`L_para_1e-9.py`; carrera de score con handicap de freeloading `4k` del Lema 12 y crecimiento honesto `(1−α)(1−δ)` del Lema 9):

| | α=0,10 | α=0,20 | α=0,25 | α=0,33 |
|---|---:|---:|---:|---:|
| q=1, k=18 | 189 s | 287 s | **377 s** | **682 s** |
| q=10, k=5 | 915 s | 1 537 s | **2 133 s** | **4 296 s** |
| q=1, k=793 (ec. 2 completa) | — | — | **2,1 h** | **3,2 h** |

**El «L = 600–900 s» de la propuesta solo vale a q=1 y con la k del término de Poisson.** A q=10 con α=0,25, L=600 s da P = **0,108 por época** — una partición permanente cada 9 épocas. Es una **cota corregida**, y el número que la propuesta cita (10⁻²⁴ de mi `reversal.py`) era de la carrera Nakamoto lineal, no de esta.

4. **La sensibilidad de borde que se me pidió examinar existe, pero no por donde se pensaba.** Con la definición reparada (E1), «primer slot ≥ E_j» es estable frente a bloques publicados tarde **solo si R-INJ-5 se aplica con X < L** (un bloque con slot antiguo llega rojo y GHOSTDAG nunca elige un rojo como padre seleccionado). Sin esa condición, un bloque retenido con slot ∈ [E_j, E_j+ε] publicado después de t_j cambia I_j para los bloques posteriores → invalidez mutua. **La propuesta no liga X con L; hay que hacerlo: X < L es condición de corrección, no una opción.**

5. **La consecuencia de discrepar no es «una reorg».** Bajo R-INJ-2 los bloques del lado perdedor no se pueden referenciar **nunca**: la reorg no reordena, **invalida**. Y hay realimentación: si la cadena cambia por debajo de E_j, cambia I_j y en cascada todos los I_{j'}, j'>j, porque cada uno se lee sobre la cadena resultante. El coste de recuperación es *todo lo posterior a t_j* en el lado minoritario, más la reconstrucción del PoT desde t_j (pregunta 5). **VERIFICADO por construcción del propio texto de R-INJ-2.**

### §3.2 «Multi-flujo del atacante: R-INJ-2 lo cierra»

**VEREDICTO: SOBREVIVE CON SUPUESTOS.** Mi construcción de A3 («m flujos → m·α·λ») exigía merge irrestricto; R-INJ-2 lo prohíbe de forma determinista (con E1 reparado). Es la respuesta correcta a A3 y a D8-Ataque 2. Los supuestos que quedan abiertos: (a) el coste de **rechazar** un sub-DAG de flujo falso es el mismo que el de aceptarlo (hay que recomputar cadena + flujo antes de decidir) → superficie de DoS, territorio de D8; (b) la regla convierte cada discrepancia en partición permanente (§3.1.5).

### §3.3 «Lookahead: no se paga más que Autonomys»

**VEREDICTO: REFUTADA. La fórmula es incorrecta y la comparación es contra otra magnitud.**

Derivación (`lookahead.py`). Sea `lead(w)` = último slot de PoT calculable menos reloj `w`. Entre inyecciones el flujo es determinista, luego `d(lead)/dw = v−1`, con barrera en `t_{j+1} = E_{j+1}+g+L` (g = `slot(I_{j+1})−E_{j+1}`), que se conoce en `w = E_{j+1}+D`. En régimen estacionario (alcanzado para cualquier v>1 tras un transitorio de `(L−D)/(v−1)` s):

**lead_max = L + g − D + I·(1 − 1/v)**

Con L=900, I=300, D=4, v=2, g=0: **1 046 s = 17,4 min**, no los 450 s que da `(L+I)(1−1/v)` de la propuesta. Y con **v = 1+ε** el lookahead sigue siendo **L−D ≈ 15 min**: no hace falta un VDF rápido, basta uno marginalmente más rápido y paciencia. Autonomys: **11 s**, independiente de v, porque el instante de la siguiente barrera no existe hasta que aparece el bloque `50j` (caveat honesto: adivinar el slot exacto acierta ~1-2 % de las veces, σ≈42 s sobre 50 bloques). Ratio: **95×**.

**Ataque habilitado (ploteo dirigido).** Con lookahead A el atacante prueba cada sector recién ploteado contra A desafíos futuros en vez de 1; auditar cuesta 42,9 µs/sector/desafío (medido) frente a 69,4 s de plotear, así que el ploteo domina y el espacio efectivo es `A/t_plot` sectores de 1 GiB:

| t_plot | A = 11 s (Autonomys) | A = 1 046 s (L=900,I=300,v=2) |
|---|---:|---:|
| GPU GTX 1070, **medido** 69,363 s | 0,16 GiB | **15,1 GiB** |
| GPU tope 2026, extrapolado 4 s | 2,8 GiB | **261,5 GiB** |

No es fatal en absoluto (261 GiB de espacio *fabricado* frente a una red de TiB), pero es el vector que la inyección existe para cerrar y la propuesta lo abre 95×. **La afirmación «no se paga más que Autonomys» es falsa por dos órdenes de magnitud.** Y confirma lo que dijo la auditoría §0: las dos exigencias siguen sin reconciliarse; la propuesta elige el cuerno del lookahead largo sin decirlo.

*(Corrección de otra cifra: «ZEROX lineal a T=120 s está peor: 3,3 h» mezcla lo mismo. El lookahead de ZEROX lineal hoy es 11 s; 3,3 h es el rezago de contenido. P-039 sigue siendo un problema, pero no este.)*

### §3.4 «Grinding del inyector: φ menor que φ₅₀ porque hay cientos de bloques por época»

**VEREDICTO: REFUTADA.** En BDK+19 §5.4, `c` es el número de **niveles del árbol privado del atacante** entre actualizaciones de desafío, no el número de bloques totales de la red. Con época definida en **tiempo**, el atacante tiene `c_a = α·λ·I` niveles por época, no `λ·I`. Como φ_c es decreciente, `c_a < c_honesto` da φ **mayor**. Además el umbral se vuelve un **punto fijo**: `α* = 1/(1+φ(α*·λ·I))` (`inyector_phi.py`):

| | I=300 s | I=600 s | I=3 600 s |
|---|---:|---:|---:|
| q=1 (λ=1) | α*=0,459 (c=138) | 0,469 | 0,486 |
| q=10 | **α*=0,394** (c=11,8) | 0,420 | 0,462 |
| q=120 | **c<1: sin cota** | 0,292 | 0,394 |

A q=1 con I=300 s la afirmación resulta cierta por casualidad (0,459 > 0,438 de c=50), pero **a q=10 es falsa** (0,394 < 0,438) y **a q=120 el objeto ni existe**. Corolario para P-039: `c = 50` debe quedarse **en bloques**, como está en Autonomys y como concluyó `dag-nativo-poas-propuesta.md §2.2`; definir el intervalo en tiempo es un cambio de seguridad, no de unidades.

Y hay una palanca **adicional** que la propuesta niega: no es solo «retener el propio bloque». En su cadena privada el atacante decide **cuál** de sus bloques con slot ≥ E_j es el primero de su cadena (omitiendo los anteriores de su propia cadena seleccionada), y conoce `entropía = blake3(chunk‖pot_output)` en el momento de crear cada uno. Factor de ramificación por época = número de sus bloques en la ventana, no 2. La ec. 39 ramifica una vez por nivel; esta elección extra **no está cubierta** por φ_c. Junto con la objeción de dariolina (φ_c está sobre la frecuencia de *inyección*, el diseño garantiza la de *muestreo*, sin cerrar desde 2023-08-22), **φ bajo inyector-por-slot es laguna, no un número**. Y el teorema sigue siendo sobre **conteo**, no sobre peso por espacio (reserva que la propia propuesta admite y que sigue abierta).

---

## 2 · Reglas R-INJ

- **R-INJ-1 — REFUTADA** por circularidad (E1). Reparable como se indica; con la reparación es determinista y bien fundada **si además** se impone monotonía de slots en la cadena seleccionada (`slot(B) > slot(sp(B))`), que hoy no existe: sin ella, «el menor slot ≥ E_j» puede caer en cualquier punto de la cadena y el atacante mete un bloque de slot antiguo para moverlo. Es la regla que en A5 quedó *PLAUSIBLE, NO DEMOSTRADA*; la propuesta la necesita como **condición de buena definición**, no como oportunidad.
- **R-INJ-2 — SOBREVIVE CON SUPUESTOS.** Determinista sobre `past(B)` una vez reparado E1. No reintroduce el n-split de Filecoin (arXiv 2308.06955 §6.1): allí hacen falta las dos condiciones —honestos que no pueden fusionar **y** copias del atacante que **suman peso a cada lado**—; aquí la primera se cumple pero la segunda no (dos flujos exigen **dos billetes distintos**, cada uno pesa en su lado). **DEMOSTRADO además que la equivocación NO parte el flujo**: `entropía = blake3(chunk ‖ pot_output)` (`derive_pot_entropy`, `pallet-subspace/src/lib.rs:948-951`) y `t_j = slot(I_j)+L`, así que dos bloques con la **misma** solución y cuerpos distintos dan la misma entropía y el mismo instante → mismo flujo. El ataque de D8 («dos candidatos a I_j a dos mitades dentro de D») **necesita dos billetes distintos y mantenerlos en dos cadenas seleccionadas durante L slots**, es decir, cuesta la carrera de profundidad L de §3.1. Es la diferencia con «pasado con dos identidades → inválido», que partía con **un** billete.
- **R-INJ-3 — SOBREVIVE** (U3′ es la forma que D8 y yo cerramos; nada nuevo que refutar).
- **R-INJ-4 — NO DEMOSTRADA.** Ver §3 (retarget) abajo.
- **R-INJ-5 — SOBREVIVE, y es obligatoria, no opcional.** Con `X < L` cierra la publicación tardía que rompería la definición reparada de I_j. Falta derivar X: `X ≥ 2Dλ` para no enrojecer bloques honestos y `X < L` por lo anterior; a q=1 eso es `8 ≤ X < 600`, ventana amplia, sin criterio para elegir dentro de ella.

---

## 3 · Retarget (pregunta 6)

**No existe en la literatura una regla de reajuste para DAG bajo PoAS con convergencia demostrada.** Lo que sí puedo demostrar y lo que no:

- **DEMOSTRADO (modelo honesto):** con estimador «número de azules en una ventana de W slots» y controlador multiplicativo amortiguado `ln SR_{n+1} = ln SR_n − γ(ln N_obs − ln N_obj)`, el error en logaritmo cumple `x_{n+1} = (1−γ)x_n + ruido`, contractivo para `0<γ<2`, con varianza estacionaria `γ/(2−γ)·Var(ln N)` y `Var(ln N) ≈ 1/N_obj`. El punto fijo es único porque `E[N] = P·SR·W/2^65` es estrictamente creciente en SR (invariancia ya verificada en A6, ε ≤ 4,88·10⁻⁴). Los slots **no son moldeables** (a diferencia de los timestamps de PoW), lo que elimina el vector clásico del retarget.
- **REFUTADA la neutralidad del estimador bajo atacante:** por el Lema 9 del propio paper, el adversario puede reducir el crecimiento del conjunto azul honesto en un factor `2Dλ/(k+2Dλ)`, que a q=1 con k=18 y 2Dλ=8 es **31 %**. Un retarget que cuente azules es sesgable un 31 % a la baja publicando `k+1` bloques en el anticono del padre seleccionado → SR se ensancha → más bloques por slot → `c = Dλ` sube → la calibración de k se queda corta. **Realimentación positiva no analizada en ninguna fuente.**
- Sigue en pie de A6: medir la **cadena seleccionada** no sirve (crece a `λ/(1+λD)`; no existe λ para q ≤ 4).

## 4 · Confirmación (pregunta 7)

Los números de `reversal.py` (α=0,25, t=600 s: q=120 → 0,140; q=1 → 4,6·10⁻³⁷) **no cambian** con inyección anclada mientras no haya discrepancia de flujo: dentro de una época todo el DAG comparte desafío y R-INJ-2 no se activa. La propiedad «el mismo riesgo en menos tiempo de reloj» **sobrevive para el riesgo de orden**. Lo que cambia es que aparece un **segundo término de riesgo, no decreciente con la antigüedad de la transacción dentro de su época**: `Riesgo_total(B,t,r) = max(Riesgo_orden, P(discrepancia de I_j))`, y este último no reordena sino que **invalida** todo lo posterior a t_j. Con L calibrado a 10⁻⁹ por época domina el primero; con L=600 s a q=10 y α=0,25 domina el segundo con 0,108 y la ventaja del DAG desaparece por completo. **La ganancia de confirmación del DAG está condicionada a L, y L a q y a k.**

---

## Cierre

**REFUTADAS:** R-INJ-1 (circular; corrección dada) · §3.3 lookahead (fórmula errónea `(L+I)(1−1/v)`; correcta `L+g−D+I(1−1/v)`; comparación contra la magnitud equivocada de Autonomys; 95× peor, no igual) · §3.4 φ (c del atacante es `αλI`, no `λI`; falso a q=10 y sin objeto a q=120; palanca de elección de inyector no cubierta) · §3.1 en su justificación (Teorema 4 es sobre el orden, no sobre la cadena seleccionada) · neutralidad del retarget por conteo de azules (sesgable 31 %).

**NO DEMOSTRADAS:** que P(cambio de cadena seleccionada a profundidad L) decaiga exponencialmente (nadie lo prueba; mi extrapolación cubre 8 órdenes) · φ bajo elección de inyector por slot y con peso por espacio · convergencia del retarget bajo adversario · unicidad del punto fijo si se insiste en la definición circular · que el rezago de contenido no altere φ_c (heredada).

**COTAS CORREGIDAS:** lookahead de Autonomys 15 min → **11 s** · lookahead de la propuesta 7,5 min → **17,4 min** (v=2) y ≈15 min incluso con v→1⁺ · L=600–900 s → **377 s (q=1, α=0,25, k=18)**, **682 s (α=0,33)**, **2 133 s (q=10, α=0,25)**, **2,1 h (q=1 con k de la ec. 2)** · φ: umbral 0,438 (c=50 en bloques) → **0,394 a q=10 con I=300 s** · ZEROX lineal «3,3 h de lookahead» → 3,3 h de **rezago de contenido**, lookahead 11 s.

**LO QUE NO PUDE VERIFICAR:** la cola de P(cambio de cadena) más allá de 10⁻³ (simulación, no teorema; y con el modelo «todo azul», optimista) · el efecto de peso por espacio dentro de la ec. 39 · el coste de rechazo bajo R-INJ-2 (D8) · la extrapolación de GPU a 4 s/sector (no medida; la medida es 69,363 s en GTX 1070) · Dmax real (sigue usando Δ=4 s como proxy, y **L es lineal en Dmax vía k**).

**Lo que habría que demostrar antes del SPEC:** (1) un teorema de prefijo común **sobre la cadena seleccionada** de GHOSTDAG, con constantes, o una fuente que lo tenga — sin eso L no es derivable, es una apuesta; (2) buena fundamentación de I_j (definición reparada) y unicidad; (3) φ con elección de inyector entre `αλI` candidatos y con peso; (4) retarget de DAG con el sesgo del Lema 9 dentro; (5) Dmax medido y k recalibrado, con justificación de ignorar el segundo término de la ec. (2); (6) los 4 puntos que quedaron de la auditoría anterior (§0.4-3,4,5).

**Valores de L e I:** **no se pueden fijar todavía**, y no por falta de aritmética sino porque L depende de tres cosas que no están: el teorema de prefijo de la cadena seleccionada (inexistente), `Dmax` (sin medir) y `k` (sin calibrar; con la ec. (2) completa L salta de 6 min a 2,1 h). Lo que sí puedo fijar es la **forma** de la respuesta: `I` debe definirse **en bloques** (`I_bloques ≥ 50`, φ) y no en slots; `L` debe cumplir simultáneamente `L ≥ L(q,α,k)` de la tabla, `X < L` en R-INJ-5, y `L + I(1−1/v) ≤ presupuesto de lookahead`, presupuesto que **hoy es de 11 s en Autonomys y que la propuesta no acota en ningún sitio**. Con q=1, α=0,33 y k=18, esas tres condiciones dan `L ≈ 700 s` y un lookahead de ~14 min, es decir: **el diseño es viable solo si se acepta explícitamente pagar 75× el lookahead de Autonomys**. Esa es una decisión de Katana, no un resultado matemático — pero ahora tiene su precio medido.

---

## Anexo B · Informe D8 (Opus), íntegro

He leído las dos propuestas, mi informe previo, el código de Kaspa y de Autonomys, y he simulado GHOSTDAG. Empiezo por lo que la propuesta **sí** cierra, con número, y después por lo que abre.

---

# D8 · Auditoría adversarial de `dag-poas-inyeccion-anclada.md`

**Fuentes:** `rusty-kaspa @ c338d495`, `subspace @ f8842d0`, SPEC §7.5/§11/§12/§12.1/§16.3, simulador propio en `/tmp/claude-1000/-home-katana-zeo/0cfccf9e-55ae-4058-bcf4-31f0987f1dbd/scratchpad/d8b/{ghostdag_sim.py,drive.py,ties.py}` (GHOSTDAG real: k-cluster, `find_selected_parent` por `(blue_work, hash)`, retardo D=4 s, todos los mineros referencian todas las puntas).

## 0 · Lo que la propuesta cierra de verdad (medido, no argumentado)

**Ataque 1 previo (split honesto sin atacante): CERRADO.** Simulé la estabilidad de `I_j = primer bloque de cadena seleccionada con slot ≥ E_j` visto desde la punta, sin atacante:

| q | k | épocas | última variación de I_j (s desde E_j) | P(cambia tras 60 s) |
|---|---|---|---|---|
| 1 | 18 | 48 | media 12,4 · p50 9 · p90 27 · **p99 57** · max 57 | **0/48** |
| 10 | 5 | 186 | media 1,7 · p50 0 · p90 7 · **p99 21** · max 23 | **0/186** |

`L = 600–900` slots es holgado por un factor ≥ 10 frente al p99 honesto. La afirmación de §3 se sostiene **en el caso honesto**.

**Ataque 2 previo (multi-flujo fusionado): CERRADO** por R-INJ-2, al precio de los hallazgos 3, 4, 5 y 7 de abajo.

**Vector 1 del encargo (equivocar el inyector): NO FUNCIONA, y por una razón que la propuesta no invoca.** `derive_pot_entropy(chunk, proof_of_time) = blake3_hash_list([chunk, pot_output])` — `subspace/crates/subspace-verification/src/lib.rs:442-446` @ f8842d0. Dos copias del mismo billete comparten `chunk` y `slot`, luego comparten `pot_output` y **entropía**; y como `t_j = slot(I_j) + L` y el slot es parte de la identidad, comparten también el slot de aplicación. Las dos mitades de la red convergen al mismo flujo aunque elijan copias distintas. El hash del bloque, que sí es moldeable re-firmando, **no entra en la entropía**. R-INJ-3 es irrelevante aquí; lo que salva la regla es el hallazgo #6 de `dag-nativo-poas-propuesta.md` §2. Conviene escribirlo como invariante explícito, porque hoy se sostiene por accidente.

---

## 1 · Hallazgos

```
HALLAZGO:     El desempate de GHOSTDAG por hash es gratis bajo PoAS y decide el inyector
SEVERIDAD:    split
ESTADO:       CONFIRMADO
ESCENARIO:    find_selected_parent ordena por (blue_work, hash) y sort_blocks igual. Con
              peso = ⌊2^128/(SR+1)⌋, TODOS los bloques de una época de reajuste tienen el
              mismo peso, luego blue_work empata constantemente. Medido en mi simulador
              sobre decisiones con más de un padre: q=1 -> 35,4 % de empates (11 229
              decisiones), q=10 -> 80,3 % (1 836), q=120 -> 96,3 % (54). Bajo PoW re-hacer
              el hash cuesta un bloque; bajo PoAS cuesta cambiar reward_address (D9 ya
              refutó U1 por esto). Un granjero con espacio no nulo fija el hash de sus
              bloques al máximo y GANA TODOS los empates en los que participa: sus bloques
              entran en la cadena seleccionada con probabilidad desproporcionada. Y la
              cadena seleccionada es ahora la fuente de I_j (R-INJ-1), del retarget
              (R-INJ-4: "mide slots de la cadena seleccionada") y de la altura de C-EXP-04.
UBICACIÓN:    rusty-kaspa/consensus/src/processes/ghostdag/ordering.rs:38-40 y
              protocol.rs:99-106 (c338d495); propuesta R-INJ-4 (no menciona el desempate)
PRECONDICIÓN: un billete cualquiera. Coste marginal: cero.
MITIGACIÓN:   desempate por solution_distance (A6 lo proponía; R-INJ-4 lo perdió). No
              elimina el hallazgo 2, solo este.
```

```
HALLAZGO:     La afirmación "su única palanca es retener su propio bloque" es falsa: el
              atacante ELIGE el inyector entre ~4 candidatos honestos con un solo billete
SEVERIDAD:    split (grinding de entropía; degrada φ_c en la dirección contraria a §3)
ESTADO:       CONFIRMADO la palanca; SOSPECHA el φ resultante (no lo he derivado)
ESCENARIO:    Medí el número de bloques mutuamente incomparables (anticono mutuo) con slot
              en [E_j, E_j+8 s]: q=1 -> media 4,09, max 11; q=10 -> media 0,70, max 4;
              q=120 -> media 0,06, max 2. En la cadena LINEAL a q=120 el bloque 50j es
              único el 94 % de las épocas: el atacante solo puede publicar o retener (1 bit).
              En el DAG a q=1 hay ~4 candidatos honestos y el atacante, con UN billete
              posterior a E_j, construye variantes de su bloque X_1..X_4 cada una con un
              candidato distinto como padre seleccionado, gana el empate por el hallazgo 1,
              y publica la que le conviene. No necesita ganar el slot E_j: le basta un
              billete cualquiera dentro de la ventana de convergencia (~10-60 s, medido).
              Factor de ramificación por época: de ~1,03 a ~4, gratis y repetible en cada
              una de las 288 épocas diarias (I=300 s).
              §3 afirma "a q pequeño una época de 5 min tiene cientos de bloques -> φ menor
              que φ50 = 1,2815". El parámetro c de BDK+19 es el número de bloques que
              dependen del MISMO desafío, sí, pero el árbol privado se ramifica por el
              número de ENTROPÍAS alcanzables por época, que aquí sube de ~1 a ~4. La
              propuesta mueve las dos magnitudes en direcciones opuestas y solo contabiliza
              la favorable.
UBICACIÓN:    propuesta §3 ("Grinding del inyector") y §2 (definición de I_j)
PRECONDICIÓN: un billete en [E_j, E_j + convergencia]. Con α = 0,05 y q = 1, ~2 billetes/época.
MITIGACIÓN:   sin mitigación conocida dentro del esquema. Anclar I_j a un bloque a
              profundidad fija en la cadena (no "primer slot ≥ E_j") reintroduce la posición
              ordinal que la propuesta quería evitar. Esto es trabajo de D9 antes de nada más.
```

```
HALLAZGO:     R-INJ-2 convierte una discrepancia transitoria en partición NO CURABLE:
              un eclipse de ~15 min apaga permanentemente al nodo eclipsado
SEVERIDAD:    DoS (apagado remoto dirigido)
ESTADO:       CONFIRMADO condicional a que C-REORG-07 siga como está (§5 lo deja abierto)
ESCENARIO:    (1) Atacante eclipsa a V desde E_j (C-NET-20 lo encarece, no lo impide).
              (2) Le alimenta un sub-DAG autoconsistente cuya cadena seleccionada da
              I_j = X != I_j honesto. (3) V produce y acepta bloques con slot ≥ t_j bajo el
              flujo de X. (4) Se levanta el eclipse a los ~L+ε = 10-15 min. (5) R-INJ-2
              prohíbe fusionar: los bloques de V y los honestos son mutuamente inválidos.
              V no puede "re-colorear", tiene que DESTRUIR todo desde t_j: a q=1 son ~600
              bloques. (6) C-REORG-07: MAX_REORG_LENGTH = 99 -> ReorgDemasiadoProfunda ->
              exit (SPEC.md:1734-1745).
              EN KASPA ESTE ESCENARIO CUESTA CERO: al levantarse el eclipse el nodo
              fusiona, re-colorea y no pierde nada. La regresión la introduce R-INJ-2.
UBICACIÓN:    propuesta R-INJ-2; SPEC.md:1734-1745; rusty-kaspa
              virtual_processor/processor.rs:298-306 (Kaspa ignora puntas, no apaga)
PRECONDICIÓN: eclipse de 10-15 min sobre el objetivo. Cero espacio.
MITIGACIÓN:   C-REORG-07 en tiempo y sin exit (§5 lo reconoce pero no lo resuelve). Aun sin
              exit, queda la destrucción de L·λ bloques y la pérdida total de recompensa
              del lado minoritario.
```

```
HALLAZGO:     R-INJ-2 hace la validez RELATIVA AL FUSIONADOR; es incompatible con el
              modelo de estado de rusty-kaspa y con cualquier caché de validación
SEVERIDAD:    split (dos implementaciones aceptan/rechazan los mismos datos distinto)
ESTADO:       CONFIRMADO
ESCENARIO:    "B es inválido si algún X ∈ past(B) tiene una solución inválida bajo el flujo
              que past(B) determina en slot(X)". El flujo lo determina la cadena seleccionada
              de past(B). Dos fusionadores B y B' con cadenas seleccionadas distintas en la
              época j dan flujos distintos -> el MISMO X es válido en B e inválido en B'.
              "Inválido" deja de ser una propiedad del bloque. rusty-kaspa guarda un único
              BlockStatus global por hash (consensus/core/src/blockstatus.rs:5-21;
              header_processor/processor.rs:258, 294, 405) y toda la canalización asume que
              StatusInvalid es definitivo. Portar R-INJ-2 exige validez indexada por
              (bloque, fusionador) -> O(|past|) por fusionador en el peor caso, y hace que
              dos implementaciones que cacheen distinto diverjan sin que ninguna sea "la
              incorrecta". La propuesta no lo menciona.
UBICACIÓN:    propuesta R-INJ-2; rusty-kaspa blockstatus.rs:5-21, processor.rs:294
PRECONDICIÓN: ninguna; ocurre en operación normal en cada reorg de cadena seleccionada.
MITIGACIÓN:   sin mitigación conocida sin rediseñar el almacén de estados. Es la razón por
              la que "R-INJ-2 = la semántica de la cadena lineal, extendida" (§2) no es cierta:
              en la lineal past(B) es una cadena, aquí es un DAG con cadena seleccionada
              variable.
```

```
HALLAZGO:     DoS por sub-DAG de flujo falso: 77 kB -> 60 core-segundos, replay ilimitado
SEVERIDAD:    DoS
ESTADO:       CONFIRMADO (cifras de coste medidas; amplificación calculada)
ESCENARIO:    El atacante calcula UNA vez un flujo de PoT alternativo de T = 600 slots
              (coste: T/v segundos secuenciales de una cadena AES; con v=2, 300 s en un
              núcleo). Adjunta las justificaciones (128 B/slot = 76,8 kB) y unas cabeceras.
              El receptor, para rechazar por R-INJ-2, tiene que verificar el flujo:
              600 × 100,20 ms = 60,1 core-segundos (paralelizable con la justificación, no
              eliminable). Por sub-DAG único no hay amplificación (300 core-s de producción
              contra 60 de verificación). Pero el atacante REPLICA el mismo sub-DAG a N
              víctimas a coste ~0: amplificación 60 core-s por cada 77 kB emitidos,
              es decir ~781 core-µs por byte.
              C-NET-03/04 NO lo cubren: C-NET-04 filtra por trabajo acumulado relativo al
              tip propio (SPEC.md:2399-2410) y bajo GHOSTDAG blue_work en la cabecera es una
              afirmación del minero, no comprobable sin colorear (mi Ataque 8 previo,
              post_pow_validation.rs:47-53). Y el presupuesto de C-NET-03 está escrito sobre
              "validar el PoW de una cabecera cuesta un SHA3-256" (SPEC.md:2394): son cinco
              órdenes de magnitud de diferencia.
UBICACIÓN:    propuesta R-INJ-2 y §5 ("Coste de auditoría de red"); SPEC.md:2381-2410
PRECONDICIÓN: un núcleo y 300 s por flujo falso; ancho de banda trivial.
MITIGACIÓN:   prefiltro de RELAY (no de validez): "si el I_j que afirma el sub-DAG no
              coincide con el de mi cadena asentada a profundidad L, descarto sin verificar".
              Es política, no consenso, así que no rompe R-INJ-1 — pero un nodo que
              sincroniza o que viene de una partición no tiene cadena asentada con la que
              comparar y come el coste íntegro. El DoS se concentra en el nodo que arranca.
```

```
HALLAZGO:     Colapso de épocas: si la cadena seleccionada tiene un hueco > I, entonces
              I_j = I_{j+1} = ... y hay dos o más inyecciones en el mismo slot t_j
SEVERIDAD:    split
ESTADO:       CONFIRMADO como laguna de especificación
ESCENARIO:    I_j = "primer bloque de cadena seleccionada con slot ≥ E_j". Si entre el
              bloque de cadena A (slot E_j−10) y el siguiente B hay un hueco de 700 slots,
              entonces B es a la vez I_j, I_{j+1} y I_{j+2}: misma entropía, mismo
              t = slot(B)+L. La propuesta no dice qué pasa: ¿se mezcla la entropía una vez o
              tres? ¿Se saltan las épocas? Dos implementaciones razonables discrepan ->
              flujos distintos -> R-INJ-2 -> partición.
              Frecuencia: la cadena seleccionada crece a λ/(1+λD) (D9, chain_growth.py:
              0,200 a q=1; 0,712 a q=10). A q=1 el hueco medio es 5 s y P(hueco>300 s) es
              despreciable. Pero durante una divergencia de SR —el régimen que §21 ya
              documenta para q pequeño y que un atacante puede provocar espaciando bloques,
              P-014— o tras una partición, el hueco supera I con facilidad. A q=120 con
              I=300 ocurre en el 8 % de las épocas en operación normal.
UBICACIÓN:    propuesta §2 (definición de I_j y de t_j)
PRECONDICIÓN: hueco de la cadena seleccionada > I. Provocable atacando el crecimiento.
MITIGACIÓN:   definir explícitamente el caso (p. ej. "si I_j == I_{j−1}, la época j no
              inyecta"), y derivar I contra el hueco p99 de la cadena seleccionada al q
              elegido. Ninguna de las dos cosas está en el documento.
```

```
HALLAZGO:     R-INJ-5 obliga a X << L, y entonces toda partición de más de X slots
              destruye el lado minoritario; griefing por retraso selectivo
SEVERIDAD:    pérdida-fondos (recompensas) / menor
ESTADO:       CONFIRMADO
ESCENARIO:    R-INJ-5 ("slot < slot(fusionador) − X -> rojo") es lo que cierra el vector 2
              del encargo: un inyector retenido y publicado en E_j+L−ε es rojo, no entra en
              la cadena seleccionada, y no puede mover I_j. Correcto. Pero para cerrarlo hace
              falta X << L (con L=600 y X=600 el inyector retenido vuelve a entrar). Con
              X ~ 20-60 slots, cualquier granjero cuyo bloque tarde más de X en propagarse
              pierde el peso y la recompensa. Kaspa usa MERGE_DEPTH_DURATION = 3600 s
              (constants.rs:70) precisamente para no hacer esto. Además el k-cluster ya
              enrojece por su cuenta a partir de ~k/λ = 18 s a q=1: X y k tienen que
              derivarse juntos y no lo están.
              Griefing: retrasar selectivamente los bloques de un granjero X+1 slots le
              anula la recompensa a coste de red, sin espacio.
UBICACIÓN:    propuesta R-INJ-5; rusty-kaspa consensus/core/src/config/constants.rs:70,
              post_pow_validation.rs:79-101
PRECONDICIÓN: control de propagación sobre la víctima durante X slots.
MITIGACIÓN:   sin mitigación conocida que no reabra la retención del inyector.
```

```
HALLAZGO:     "Emisión solo sobre azules" (R-INJ-4) no dice que las TRANSACCIONES de los
              rojos no se apliquen; con el código portado, la inflación ×10 sigue viva
SEVERIDAD:    inflación
ESTADO:       CONFIRMADO condicional (el código de referencia hace exactamente eso)
ESCENARIO:    rusty-kaspa aplica las transacciones de los bloques rojos
              (utxo_validation.rs:122 sobre consensus_ordered_mergeset, que mezcla
              mergeset_blues y mergeset_reds, ghostdag.rs:116-130). En ZEROX la coinbase va
              DENTRO del bloque (C-HDR-08, merkle_root): si las tx de un rojo se aplican, su
              coinbase acuña. R-INJ-4 dice "peso, reajuste y emisión solo sobre azules"
              — pero R-INJ-3 admite explícitamente copias rojas del mismo billete (hasta
              max_block_parents = 10, bps.rs:57-73). Un billete -> 10 coinbases si "emisión
              solo sobre azules" no se traduce además a "la coinbase de un bloque rojo NO
              se aplica al UTXO". §5 lo llama "coinbase por bloque a q pequeño: repensar".
              No es repensar: es la diferencia entre acuñar de la nada y no acuñar.
UBICACIÓN:    propuesta R-INJ-3/R-INJ-4 y §5; rusty-kaspa utxo_validation.rs:122,
              ghostdag.rs:116-130, coinbase.rs:117-131
PRECONDICIÓN: portar el código de referencia sin la regla adicional. 1 billete real.
MITIGACIÓN:   regla explícita: la coinbase de un bloque rojo no se aplica; el fusionador
              paga; reward_address vuelve a la cabecera (deshace C-HDR-08).
```

```
HALLAZGO:     Bajo R-INJ-2 el flujo de PoT no se puede podar: 4,04 GB/año de
              justificaciones que ningún nodo puede tirar si quiere validar el pasado
SEVERIDAD:    menor (coste) — agrava el Ataque 7 previo
ESTADO:       CONFIRMADO por aritmética; SOSPECHA de que exista un esquema sucinto
ESCENARIO:    R-INJ-2 hace que la validez de un bloque antiguo dependa del flujo de PoT que
              su past determinaba. Una prueba de poda de cabeceras (pruning_proof/build.rs:
              145-195) no puede establecerlo sin los checkpoints: 128 B/slot × 31,5 M
              slots/año = 4,04 GB/año, no podables. La verificación tampoco es sucinta
              (CLAUDE.md ya lo advierte del PoT de Autonomys). El nivel de poda análogo que
              §5 propone (solution_distance ≤ SR/2^ℓ) además NO es estable: SR cambia con
              el reajuste, así que el "nivel" de un bloque no es una propiedad fija del
              bloque, a diferencia de los ceros del hash (calc_level_from_pow,
              consensus/pow/src/lib.rs:72-75).
UBICACIÓN:    propuesta §5 (poda); rusty-kaspa pruning_proof/build.rs:145-195
MITIGACIÓN:   sin mitigación conocida.
```

```
HALLAZGO:     C-EXP-04 en el DAG: "altura" no está definida y la definición natural
              (posición en el orden total) la mueve el atacante con copias rojas gratis
SEVERIDAD:    split
ESTADO:       SOSPECHA (depende de una definición que la propuesta no da; sin escenario
              cerrado hasta que exista la regla)
ESCENARIO:    C-EXP-02 usa hash_bloque[altura_ploteo] y C-EXP-04 exige leerlo "de la cadena
              que se está validando" (SPEC.md:1806, 1819-1823). En el DAG hay muchos bloques
              a la misma puntuación. Si "altura" = posición en el orden total de GHOSTDAG,
              ese orden incluye los rojos, y un atacante que publique copias rojas gratis de
              sus billetes (R-INJ-3 las permite) DESPLAZA el mapeo altura -> hash: cambia
              desplazamiento = blake3(sector_id ‖ hash_bloque[altura_ploteo]) mod 2^20 y por
              tanto caducidad_altura de sectores ajenos. Un sector caduca para un nodo y no
              para otro -> el mismo bloque es válido para uno e inválido para otro.
              Si "altura" = índice en la cadena seleccionada, el problema desaparece pero
              VIDA_MINIMA_BLOQUES = 65 536 pasa a medir 3,8 días a q=1 (crecimiento de
              cadena 0,200/s) en vez de 18,2 h, y ese factor depende de λD, que el atacante
              influye espaciando bloques o aumentando D con spam.
UBICACIÓN:    SPEC.md:1804-1832; propuesta (no trata C-EXP en absoluto)
MITIGACIÓN:   fijar altura = blue_score de la cadena seleccionada y re-derivar
              VIDA_MINIMA/DISPERSION en tiempo. No está hecho.
```

---

## 2 · Los ataques 3-8 del informe previo, uno por uno

| Ataque previo | Estado en esta propuesta |
|---|---|
| 3 · coinbase de rojos + DAA con rojos (inflación ×10) | **Parcialmente cerrado y parcialmente ignorado.** R-INJ-4 cierra DAA y peso. La aplicación de las tx de los rojos (y por tanto la coinbase) no se menciona: ver hallazgo de inflación. |
| 4 · U3 no implementable | **Cerrado.** R-INJ-3 adopta U3′ literalmente. |
| 5 · C-REORG-07 a q=1 = apagado | **Aplazado y AGRAVADO.** §5 lo lista como abierto; R-INJ-2 lo convierte en apagado remoto por eclipse de 15 min (hallazgo 3). |
| 6 · q sin función de calibración | **Aplazado.** §5: "Dmax real sin medir; k sin calibrar". Además L, I y X ahora dependen de q y no hay ninguno derivado. |
| 7 · poda por PoW | **Aplazado y AGRAVADO** (hallazgo de poda: el flujo de PoT no se poda, y el nivel por `solution_distance` no es estable). |
| 8 · cliente ligero | **Aplazado.** §5 lo admite; R-INJ-2 lo empeora: un SPV necesitaría además el flujo y la cadena de inyectores. |
| Menor · A5 invierte la dirección | **Cerrado** por R-INJ-5, abriendo el hallazgo de la partición > X. |

---

## 3 · Ataques buscados y NO encontrados

- **Equivocar el inyector (vector 1).** Neutralizado: entropía y `t_j` son función del billete, no del bloque (`subspace-verification/src/lib.rs:442-446`). Ninguna de las dos mitades puede quedar con un flujo distinto por esta vía.
- **Split honesto en I_j sin atacante (Ataque 1 previo).** Medido: p99 = 57 s a q=1 y 21 s a q=10, con L = 600-900. No encontrado.
- **Retener el inyector y publicarlo en E_j+L−ε (vector 2).** No funciona: el bloque retenido es rojo por k-cluster a partir de ~18 s (q=1, k=18) y por R-INJ-5, y los rojos no están en la cadena seleccionada. Contrasta con C-REORG-07 solo en que el retenido nunca llega a provocar reorg del flujo.
- **Ploteo dirigido con el lookahead (vector 5).** Cuantificado y **no rentable**. Con `L+I = 900` slots y v=2 la ventana es W = 450 slots. Ploteo medido: 69,363 s/sector de 1007,94 MiB (GTX 1070, `coste-ploteo-medido.md:189-196`). Espacio equivalente de un fabricante-y-tira = r·W = (1/69,363)·450 = **6,5 GiB por GPU** (auditar 450 desafíos por sector cuesta 450×2,82 µs = 1,3 ms, despreciable: el cuello es el ploteo). Con la extrapolación ALU-bound a GPU tope 2026 (4,28 s/sector): **105 GiB por GPU**. Comparación: 6,5 GiB de SSD cuestan ~0,50 $ contra ~100 $ de GPU usada — 200× peor para el atacante. Autonomys hoy paga el mismo lookahead de 15 min. **ZEROX lineal a T=120 s está 13× peor** (3,3 h -> W=5940 s -> 85,6 GiB/GTX 1070, 1,35 TiB con GPU tope): P-039 sigue siendo el problema más grande de los dos.
- **Cascada de inyectores (vector 6).** No amplifica la *profundidad*: una reorg que cambia I_j bifurca en slot(I_j), luego ya revierte todo lo posterior; I_{j+1}, I_{j+2} cambian dentro de esa misma reorg. Lo que sí cambia es la *naturaleza*: los bloques no se reordenan, se **destruyen** (son inválidos bajo el flujo nuevo), y el lado perdedor paga 60 core-s de re-verificación de PoT. Es lo que alimenta el hallazgo 3, no un ataque aparte.
- **Grinding de la entropía por contenido del bloque.** Cerrado por el mismo motivo que el vector 1.
- **Fusión entre flujos (Ataque 2 previo, D9 A3).** Cerrado por R-INJ-2, al precio de los hallazgos 3, 4 y 5.

## 4 · No pude analizar

- **φ_c con ramificación 4 por época**: implementar la ec. 39 de BDK+19 con árbol de ramificación variable es trabajo de D9. Doy la palanca y su tamaño medido, no el umbral resultante.
- **Frecuencia de cambio de I_j CON atacante** a α = 0,1-0,25: mi simulador es honesto puro; añadir un adversario que retiene y elige padres es otra tarde de trabajo.
- **k-cluster exacto**: mi implementación restringe el cálculo del anticono a una ventana de 40 s. Verifiqué que el `maxspan` observado cae dentro, pero no es la implementación de `check_blue_candidate` de Kaspa línea a línea; los porcentajes de empate y el tamaño del conjunto de candidatos no dependen de ese detalle, la p99 de convergencia sí podría moverse algún segundo.
- **Coste real de la re-validación bajo R-INJ-2** con el almacén de estados rediseñado: no existe ese diseño, así que no hay nada que medir.
- **`s_bucket` vs `chunk` en la identidad de billete** (`proving.rs`): sigue sin verificar desde el informe anterior.

---

## Veredicto

**Sí, cierra los dos fallos de la auditoría anterior.** El split honesto está cerrado con medición (p99 = 57 s frente a L = 600), y la fusión entre flujos está cerrada por R-INJ-2. Ninguna de las dos vuelve por la puerta de atrás.

**Y abre cinco fallos nuevos, dos de ellos de diseño, no de parámetro:**

1. **R-INJ-2 hace la validez relativa al fusionador.** Es incompatible con el modelo de `BlockStatus` global de rusty-kaspa y es un caldo de cultivo para que dos implementaciones diverjan. La frase "es la semántica de la cadena lineal, extendida" no es cierta.
2. **R-INJ-2 elimina la curación por fusión**, que es el mecanismo por el que un DAG sobrevive a las particiones. Con C-REORG-07 tal cual, un eclipse de 15 min apaga un nodo para siempre — algo que Kaspa no permite y que la cadena lineal de ZEROX tampoco permitía a esa escala.
3. **La palanca de grinding del inyector es ~4× mayor que en la lineal, no menor**, y §3 afirma lo contrario.
4. **El desempate por hash de GHOSTDAG es gratis bajo PoAS** y ahora decide el inyector, el retarget y la altura: es un agujero sistémico que la propuesta perdió por el camino (A6 lo tenía).
5. **Épocas colapsadas y C-EXP-04 en el DAG** son lagunas de especificación con final en split.

Mi recomendación: **no tocar el SPEC.** Antes de eso hacen falta, en este orden, (a) el φ con ramificación 4 de D9, (b) una regla de validez de PoT en DAG que no sea relativa al fusionador —y no la veo—, y (c) C-REORG-07 redefinido en tiempo y sin `exit`, que además es deuda de la cadena lineal ya decidida. Y con o sin DAG, **P-039 (3,3 h de lookahead a T=120 s) es hoy 13× peor que cualquier cosa que discuta este documento**, con el número de arriba: 1,35 TiB de espacio fabricable por GPU tope frente a 105 GiB.
