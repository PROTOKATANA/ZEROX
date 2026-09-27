# HIPÓTESIS QUE CODIFICAN LA CONCLUSIÓN

**Obligatorio por `PROMPT.md` §6.** Su motivo, textual del encargo: *«qué supuestos, de haberse
elegido de otro modo, cambiarían el veredicto. En esta serie ya hubo un control que **codificaba su
propia conclusión** y solo lo cazó la verificación independiente.»*

Este documento es, por tanto, un **autoexamen adversarial**: para cada supuesto, qué pasa si se
elige al revés. Se ordenan por **cuánto mueven el veredicto**, no por cuándo aparecen.

Leyenda de la columna «¿mueve el veredicto?»:
`NO` = cambia cifras, no la conclusión · `SÍ` = la conclusión cambia · `SÍ (crítico)` = **la
conclusión principal depende de este supuesto**.

---

## H-1 · `SÍ (crítico)` — Que la captura de la víctima sea **TOTAL**: que no le quede ninguna vía al pasado honesto

**El supuesto.** La derivación de F1 (`src/flujo.jl`) concluye partición permanente **si** la vista
de época de la víctima diverge, y eso exige que **no reciba** el bloque que cruza `T_j` — ni ningún
descendiente suyo— hasta después de su propia activación `t_j`.

**Si se elige al revés.** Si a la víctima le queda **una sola** conexión honesta, recibe el bloque
que cruza `T_j` (o un descendiente que lo contiene) antes de `t_j`; su `V_j` converge a la de la red
y **no hay divergencia de ancla ni de flujo**. La partición **no se fabrica**.

**Por qué es crítico y hay que decirlo en la primera línea del informe.** El veredicto de F1 es
**condicional a la captura completa**, y la captura completa es exactamente el objeto de la
**sección D**. Y la sección D concluye que **el gestor de direcciones de ZEROX no existe**: hoy no
hay tabla, ni selección, ni diversidad por selección. Es decir:

> **F1 está derivado y se sostiene, pero su premisa —que el adversario pueda sostener la captura
> total durante `> F_slots`— NO está determinada para ZEROX, porque no hay red P2P que capturar.**

Esto **no invalida** F1: lo convierte en un resultado **condicional**, con la condición nombrada, y
convierte la construcción del gestor de direcciones (y de sus contramedidas) en el eslabón que
decide si el agujero es alcanzable. Se ha escrito así en `INFORME.md` §F1 y §F3.

**Control aplicado:** el matiz del **mecanismo** —que el eje es la **retención** y no el retardo—
se derivó precisamente al atacar este supuesto: un retraso uniforme de `E < L_slots` **no** produce
la divergencia, y por eso el informe no dice «el eclipse retrasa y por tanto parte», sino «retener
el bloque que cruza `T_j` parte, y eso equivale a cortar el flujo».

---

## H-2 · `NO` — El régimen de peso: `SR = 0` (conteo) frente a `SR = sd` (`C-GD-01`)

**El supuesto.** El instrumento histórico pesa por conteo (`blue_work = nº de azules`). Se reutiliza
el motor de `GDR-v0.2` explotando que **`SR = 0` en todo bloque da `blue_work = 2^128·|blues|`, que
ordena igual**. La equivalencia está **comprobada**, no supuesta (test dedicado).

**Si se elige al revés** (peso por `SR`, que es la regla vigente): las cifras se mueven. Lo más
visible, `rojo_V` de la variante (iii) con `E = 60 s` cae de `1,0000` a **`0,9543`** — un 4,6 % de
los bloques de la víctima deja de perderse. La invalidez se mueve hasta ~3 puntos.

**¿Mueve el veredicto? NO** para F1 (la partición no depende del peso: depende de qué bloques
recibe la víctima) y **NO** para el hallazgo central (100 % de recompensa perdida). **SÍ** para
cualquier cifra citada sin recalcular — y por eso `INFORME.md` §F2 dice explícitamente que **ninguna
magnitud de 11b es transferible**.

---

## H-3 · `NO` — El valor de `Δ` (4 s histórico frente a 0,26–0,60 s de hoy)

**El supuesto.** `Δ = 4 s` para el control (es el del oráculo); `Δ ∈ {0,26, 0,45, 0,60}` para el
régimen vigente. **La `Δ` de hoy es SIMULADA** (`DMS-v0.1`), no medida en red desplegada.

**Si se elige otro valor:** la propia **fila de control se mueve hasta +7,3 puntos** (`S = 150`),
y de forma **no monótona**: `iii E=20, S=20` da `0,7022` (Δ=4), `0,6011` (Δ=0,26) y `0,7640`
(Δ=0,60). Interpolar entre regímenes **no es legítimo**.

**¿Mueve el veredicto? NO** para F1 ni para el 100 % de pérdida (`rojo_V = 1,0000` en las ocho
combinaciones). **SÍ** para toda magnitud, y la no monotonía es la prueba de que no se extrapola.

---

## H-4 · `NO` — Que el atacante **vea todo al instante** (`atacante_sin_retardo = true`)

**El supuesto.** El modelo del artículo (11b, `r8c_sim.py:33-37`): el atacante no sufre retardo ni
hacia ni desde los honestos. Es el caso **más favorable al atacante** que sigue siendo coherente.

**Si se elige al revés** (el atacante sufre el mismo `Δ`): su ventaja de vista desaparece y sus
bloques llegan tarde, lo que **debilita** sus variantes. El instrumento conserva el interruptor
(`con_todos_atacante`) para poder medirlo; **no se ha medido aquí**.

**¿Mueve el veredicto? NO** en la dirección de la seguridad: el sesgo va **a favor del atacante**,
luego los resultados son una **cota conservadora** para la defensa.

---

## H-5 · `NO` — `f_v = 0,05` y la forma cerrada de la variante (ii)

**El supuesto.** La víctima produce una fracción `f_v` del espacio; `0,05` es el valor del oráculo.
La variante (ii) con `paso = 0` tiene forma cerrada `P(inválido) = e^{−f_v·S_max}`.

**Si se elige otro `f_v`:** todo escala, pero **la forma cerrada es consecuencia, no hipótesis**, y
es **invariante al régimen** (`Δ` y peso): sale idéntica en las ocho combinaciones
(`0,7927 / 0,3109 / 0,1762 / 0,0000`, `n = 193`). Eso es precisamente lo que la convierte en control.

**¿Mueve el veredicto? NO.** Es el resultado más robusto del instrumento.

---

## H-6 · `SÍ` — Que la víctima **no corra su propio timelord** (variante (i))

**El supuesto.** Declarado en 11b §A.1: la víctima no corre timelord propio (granjero = PC con SSD;
el timelord lo opera el proyecto). Sin PoT no hay slot que justificar ⇒ **0 bloques**.

**Si se elige al revés** (la víctima corre su timelord): la variante (i) **degenera en (ii)** con la
salvedad de que su cadena de PoT divergiría de la de la red. Ese caso **no está simulado**: haría
falta modelar dos cadenas de PoT y su reconciliación — **LAGUNA declarada**, heredada de 11b y no
cerrada aquí.

**¿Mueve el veredicto? SÍ, para la variante (i)**: su «coste cero espacio, 100 % de daño» es
exactamente lo que deja de ser cierto si la víctima produce su propio PoT. Se etiqueta en
`INFORME.md` §0 como hipótesis declarada del instrumento heredado, no como propiedad del protocolo.

---

## H-7 · `SÍ` — La definición de `rojo_V`: comparar contra el blueset **final** de la vista pública

**El supuesto.** `rojo_V` = fracción de bloques de la víctima que **no están en el blueset de la
vista pública final**, en la ventana de régimen. Es la definición del oráculo heredado.

**Si se elige otra** (p. ej. comparar contra el blueset en el instante de cada bloque, o usar
`blue_score` en vez de pertenencia al blueset): el número cambia — es lo que ya pasó en 11b entre el
`0,77` de la auditoría 7 y el `0,7500` de la ventana temporal bien definida (11b §A.0). Los tres
números son el **mismo fenómeno** con definiciones distintas.

**¿Mueve el veredicto? SÍ, para la magnitud** (que es `1,0000` o `0,7500`, no algo intermedio);
**NO** para la conclusión «la víctima pierde toda su recompensa mientras dura el eclipse».

---

## H-8 · `SÍ` — Que la selección de pares sea **uniforme sin reemplazo**

**El supuesto.** En `src/captura.jl`, la víctima elige sus `ω` salientes **al azar y sin reemplazo**
de una tabla repartida en grupos; de ahí `p^(1/ω)`.

**Si se elige al revés** (selección **sesgada**, como el `tried` de Bitcoin con su sesgo por
frescura): el requisito cambia **en órdenes de magnitud**. Con el mismo `ω = 8`, el artículo publica
`f = 72 %` de `tried` para el 90 % en el ataque original, pero `f = 98,7 %` con selección aleatoria,
y la diferencia entre 595 IP y 163 000 IP (peor caso) es la misma familia de supuesto.

**¿Mueve el veredicto? SÍ, para la sección D.** Por eso la sección D **declara el modelo** en cada
fila y **no** presenta la cota uniforme como el coste del adversario: es una **cota superior**.

---

## H-9 · `SÍ` — El **modelo de recursos** de la cuenta de captura

**El supuesto.** Se cuenta en **IP y prefijos**, como Heilman.

**Si se elige al revés:** hay dos reevaluaciones publicadas que cambian el recurso escaso.
Apostolaki et al. (IEEE S&P 2017) muestran que **<100 prefijos BGP** aíslan ~50 % del poder de
minado: el atacante **no necesita poseer** los prefijos, le basta con **secuestrarlos**. Y Marcus,
Heilman y Goldberg (ePrint 2018/236) eclipsan Ethereum **con dos hosts y una IP cada uno**, porque
su agrupamiento es `/24` y su modelo de conexiones es otro.

**¿Mueve el veredicto? SÍ, para la sección D y para F4.** Es literalmente el caso que el encargo
anticipa con «si existe un `α` que lo abarate, cuál»: el abaratamiento no viene de `α` (que lo
**encarece**), viene de cambiar el recurso. **Y para ZEROX hay un tercer abaratamiento posible que
no se ha medido: el `PeerId` de `libp2p` es gratis (clave pública), así que una cuenta en «IPs» no
acota un Sybil.** No se ha encontrado medición de esto.

---

## H-10 · `NO` — El modelo secuencial de la frontera de PoT (E1)

**El supuesto.** `P(L ≤ x) = ∏_{j≥0} F_D(x + jσ)`: un solo slot retrasado **atasca** la frontera
verificada, porque el encadenado es `semilla(f,s) = salida(f,s−1)` (`C-POT-01`).

**Si se elige al revés** (frontera no secuencial, p. ej. poder verificar slots salteados): la cola
de E1 colapsaría a la **marginal** de `D`, y `B` bajaría. Pero **`C-POT-01` es regla vigente**, y el
control lo confirma: `P(D>8) = 0,0100` frente a `P(L>8) = 0,014760`, es decir la secuencial es
**estrictamente más pesada**. El supuesto no es una elección del instrumento: es una regla.

**¿Mueve el veredicto? NO.** Cambiaría `B`, no la conclusión de que E1 ve (i) y (iii).

---

## H-11 · `NO` — La familia de cola del retardo honesto en E1

**El supuesto.** Lognormal (la que pide el encargo) y Pareto, ambas ajustadas a la **misma mediana y
p99**.

**Si se elige otra familia:** `B` pasa de ~21 s a ~1 422 s. Es el resultado «incómodo» de 11b y aquí
se **confirma**: dos ajustes de la misma frase difieren en un factor >2.

**¿Mueve el veredicto? NO, y hay que decir por qué:** porque **`B` no se fija en este encargo**.
E1 como conducta (no autorizar, alertar, rotar) es útil con cualquier `B` razonable; lo que cambia
es el coste en falsas alarmas.

---

## H-12 · `NO` — La contabilidad de falsas alarmas de E2

**El supuesto.** Una prueba por slot (cota conservadora) y `n_min` como el primer umbral cuya cola
de Poisson queda por debajo de `1/año`. Reproduce **exactamente** 11b §C.1 (6/23/66/211) y §C.5
(`α = 0,9249`).

**Si se elige al revés** (sólo ventanas disjuntas): `n_min` sube (11b publica 8/28/74/229) y el
sensor se vuelve más conservador.

**¿Mueve el veredicto? NO.** Y **no** se reproduce la columna `s_λ > 0` de 11b porque su texto no
define esa cuenta: se anota como defecto del instrumento histórico (`INFORME.md` §6.4) en vez de
resolverlo a favor de la hipótesis.

---

## H-13 · `NO` — La dirección de la cota de `E_min = F_slots`

**El supuesto, y aquí hubo un error propio que se corrige.** En la primera redacción de
`src/flujo.jl` el comentario decía que tomar `slot(I_j) = T_j` era «el caso más favorable al
defensor». **Es falso y se corrigió en el código.** Tomar el ancla más temprana **minimiza** la
duración necesaria, luego el `E_min = F_slots` que sale es una **cota INFERIOR exacta** del eclipse
necesario — es decir, del lado de la defensa — y además se **alcanza** (con `s₀ = T_j + L − F`).
Para cualquier ancla posterior la duración necesaria es `≥` esa.

**¿Mueve el veredicto? NO por la dirección (la cota es la correcta), pero habría sido un error de
etiqueta si se hubiera dejado escrito.** Se deja constancia porque es exactamente el tipo de frase
—«conservador para la defensa»— que se escribe por inercia y no se comprueba.

---

## Lo que este autoexamen NO cubre

- **No hay un control que codifique la conclusión principal**: F1 se apoya en H-1, que está
  **nombrada como crítica** y cuya premisa **no está determinada** para ZEROX. Lo que sí se ha
  evitado es presentar F1 como incondicional.
- **La partición de flujo no está simulada de extremo a extremo.** H-1 se comprueba por aritmética
  de las reglas, no construyendo dos vistas con dos flujos y dos anclas. Ese paso queda **propuesto
  y no ejecutado**, y por eso F1 lleva la etiqueta `derivado` y no `medido`.
- **Ninguna hipótesis sobre el mundo físico** (hardware, ancho de banda real, latencias reales) se
  ha medido aquí: se citan de `veritas/rendimiento/coste-salto-v1` y de `DMS-v0.1`.
