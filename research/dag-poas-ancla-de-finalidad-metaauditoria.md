# Meta-auditoría de la auditoría D9+D8 de la ronda 7

**Objeto:** `dag-poas-ancla-de-finalidad-auditoria.md` (commit `d6020a1`) y la propuesta que audita,
`dag-poas-ancla-de-finalidad.md` (commit `57bbde7`, corregida con R-FIN-1a).
**Fecha:** 2026-09-07 · **Encargo de Katana:** «analiza si lo que se dice es correcto».
**Método:** ejecución de los 15 scripts citados, lectura de la fuente primaria BDK+19 en local,
y 5 scripts de verificación nuevos (`/tmp/d9-ronda7/verif_*.py`).

**Veredicto:** el veredicto global de la auditoría —**«LA PROPUESTA SOBREVIVE»**— **no está
respaldado por su propia evidencia.** No es que la propuesta quede refutada: es que **las dos
preguntas que Katana designó como decisivas (Q1 y Q2 de §8) no han sido auditadas de hecho**. Sus
demostraciones son, respectivamente, una tautología y una constante escrita a mano. Además aparecen
dos problemas nuevos que salen de la **propia fuente primaria que la propuesta cita** para su umbral.

---

## 0 · Resumen en una tabla

| # | Hallazgo | Gravedad | Cómo se comprobó |
|---|---|---|---|
| A | Q1 «DEMOSTRADO, 20 000 trials, 0 éxitos» es una **tautología**: `alpha` no se usa, la condición de éxito es insatisfacible por construcción | **Bloqueante** | `verif_q1_tautologia.py` |
| B | B2, B3, B4 («SIN VECTORES», `P=0.000000`) tienen **el mismo defecto**. B3 compara una variable consigo misma | **Bloqueante** | lectura + ejecución |
| C | Q2 «DEMOSTRADO» descansa en **pagos cableados** `{1.0, 0.0, 0.5}`; el `0.5` es falso en prueba de espacio por 6 órdenes | **Bloqueante** | `verif_cobertura.py` |
| D | El umbral **47,6 % es el valor con Δ = 0**. BDK Tabla 3 lo dice literalmente. Con el Δ = 4 s de la propuesta: 35,0 % / 17,4 % / 1,8 % | **Bloqueante** | `verif_umbral_delta.py` + paper |
| E | La fuente primaria impone **W > κ ⇒ soborno encubierto**. La propuesta está **3,5× dentro** de ese régimen; Autonomys, 2 órdenes fuera | **Bloqueante** | `verif_ventana_prediccion.py` + paper |
| F | La rama «ec. (2) completa» **no se propaga** al margen económico: da 1,06× y **0,65×** (la premisa 1 se invierte) | **Bloqueante** | `verif_margen_eq2.py` |
| G | El «4,6·10⁻³⁷» es **la columna equivocada** del propio `reversal.py`; la columna GHOSTDAG da 2,65·10⁻²¹ con la `k` de la propuesta, y **1,000** con `k=793` | **Alta** | ejecución de `reversal.py` |
| H | Cita **fabricada** en §11: «Dembo et al., *DAGger: A DAG-based Blockchain Protocol*» | **Alta** | lectura del PDF en local |
| I | El modelo económico usa 42,9 µs cuando su fuente ordena usar 2,82 µs | Media (dirección conservadora) | `coste-ploteo-medido.md:96` |
| J | La columna «Líneas» de §9 son **bytes** | Baja (señal) | `wc -l` |
| K | «Superficie de ataque agotada» no está respaldado | Media | inventario de scripts |
| L | Política del vault exige **Opus** para D9/D8; la ronda 7 declara «(general)» en las 4 pasadas | Media (proceso) | `NODOS/ZEROX/CLAUDE.md:217` |

**Lo que sí está bien** (§7): φ_c, el modelo A*, los tiempos de ploteo medidos, la aritmética de
costes, el ataque A1 original y el script B1. No es poco, y conviene no tirarlo.

---

## 1 · Hallazgo A — la demostración de Q1 es una tautología

Q1 es la primera de las dos preguntas que, en palabras de la propia sesión, «deciden todo lo demás».
Su veredicto pasó de PLAUSIBLE a **DEMOSTRADO** apoyado en «20 000 trials Monte Carlo, 0 éxitos».

El núcleo de `r7b_q1.py` es:

```python
def simulate_attack_a1(lambda_chain, alpha, F, c, j, n_trials=10000):
    for trial in range(n_trials):
        slots = build_chain_strictly_monotone(lambda_chain, p + 200, seed=trial)
        threshold      = slots[p]        # = slot(I_j)
        max_slot_before = slots[p - 1]
        if max_slot_before >= threshold:  # <- condición de éxito del atacante
            successes += 1
```

y `build_chain_strictly_monotone` construye `slots[i] = slots[i-1] + expovariate(λ)`, con
`expovariate > 0` siempre. Por tanto `slots[p-1] < slots[p]` **por construcción**, y la condición de
éxito es **lógicamente insatisfacible**, no improbable.

**Dos pruebas, ejecutadas** (`verif_q1_tautologia.py`):

1. **No hay adversario dentro.** `alpha` aparece solo en la firma de la función; nunca en el cuerpo.
   Comprobado barriendo α de 0 a 1:

   | α | 0,00 | 0,10 | 0,33 | 0,49 | 0,90 | 0,99 | 1,00 |
   |---|---|---|---|---|---|---|---|
   | éxitos / 2 000 | 0 | 0 | 0 | 0 | 0 | 0 | 0 |

   Un atacante con el **100 %** del espacio obtiene el mismo resultado que uno con el 0 %. La
   simulación no mide nada sobre el atacante.

2. **La cota estadística no da para lo que se afirma.** Aun si la simulación fuese válida, 0 éxitos
   en *n* pruebas solo acota `p ≤ 3/n` al 95 % (regla de tres):

   | | valor |
   |---|---|
   | 0 / 20 000 → cota al 95 % | `p ≤ 1,5·10⁻⁴` |
   | trials necesarios para `p ≤ 10⁻⁹` | 3,0·10⁹ |
   | trials necesarios para `p ≤ 4,6·10⁻³⁷` | 6,5·10³⁶ |

   La propuesta invoca 10⁻⁹ y 4,6·10⁻³⁷. Ninguna simulación de 20 000 trials puede respaldar eso.

**Lo que la Parte A llama «inducción»** tampoco lo es. El paso inductivo, textualmente:

```python
# Paso inductivo: asumimos que para todo i < p, slot(i) < slot(p)
for i in range(p):
    assert chain_slots[i] < chain_slots[p]
```

Asume lo que quiere probar y lo verifica sobre un dato que ya lo cumple.

---

## 2 · Hallazgo B — tres «SIN VECTORES» de D8 tienen el mismo defecto

| Script | Condición evaluada | Por qué es tautológica |
|---|---|---|
| `d8b_b2.py:200` | `ignored_by_finality = (slot_A < t_j - F)` con `slot_A = chain_slots[p]`, `p < POS_INJECT`, y `t_j - F = chain_slots[POS_INJECT]` | La cadena es monótona por construcción ⇒ siempre `True` ⇒ ambos contadores siempre 0 |
| `d8b_b3.py:131-132` | `Ij_A = owners_common[POS_INJECT]` … `Ij_B = owners_common[POS_INJECT]` | **Las dos mitades de la partición leen la misma variable.** `Ij_A != Ij_B` es `x != x` |
| `d8b_b4.py:87-88` | `p = randint(1, POS_INJECT-1)`; `ignored = (slot_D < umbral)` | Mismo patrón ⇒ `ignored` siempre `True` ⇒ `adopted_count` siempre 0 |

B3 es el más grave porque es **el único test que debía medir el acuerdo entre dos nodos honestos**,
que es exactamente lo que Q1 afirma. Su propio comentario lo delata:

```python
# En la cadena comun, ambos tienen el mismo I_j
```

Eso no es un resultado: es la hipótesis. Y además hay una nota en el código, `d8b_b3.py:112`:
`# Nota: en B no hay atacante porque estamos midiendo desacuerdo honesto`.

---

## 3 · Hallazgo C — Q2 se apoya en constantes escritas a mano, con un modelo de coste falso para PoAS

`r7_q2.py` ejecuta un bucle Monte Carlo completo (calcula `n_blocks_c`, `n_blocks_d`) y a
continuación **descarta el resultado**, sobrescribiendo los pagos en cada iteración:

```python
payoffs[0] = 1.0
payoffs[1] = 0.0
payoffs[2] = 0.5  # asumiendo division equitativa del espacio entre flujos
```

De ahí sale «dominancia estricta de Solo C», y de ahí el veredicto **DEMOSTRADO** de Q2. El propio
docstring escribe la conclusión como premisa: *«En este modelo, la estrategia "solo C" domina
estrictamente»*.

### El `0,5` es falso en prueba de espacio, y por seis órdenes de magnitud

La justificación del `0,5` es «división equitativa del espacio entre flujos». En prueba de espacio
**no hay que dividir el espacio**: el mismo sector se audita contra los desafíos de los dos flujos.
Cubrir un segundo flujo cuesta **un pase de auditoría extra**, no la mitad de la tasa de bloques.

Con los costes **medidos por el propio proyecto** (`coste-ploteo-medido.md`, 1 slot/s):

| Granja | Núcleos extra, granjero honesto (42,92 µs) | Núcleos extra, atacante SIMD (2,82 µs) |
|---:|---:|---:|
| 1 TiB | 0,044 | 0,003 |
| 10 TiB | 0,440 | 0,029 |
| 100 TiB | 4,40 | **0,29** |
| 1 PiB | 43,95 | 2,89 |

Razón plotear/auditar, medida: **1 517 730×**.

**Consecuencia lógica.** El pago correcto de «cubrir ambos» es `1 − ε` con `ε ≈ 0`, no `0,5`. Con ese
pago:

- «Solo C» deja de dominar **estrictamente**: empata con «ambos» salvo ε.
- En cuanto `P(el flujo divergente gane) > ε`, **«cubrir ambos» pasa a dominar**.

Y aquí está el punto fino: el argumento de la propuesta (§3, fila «ronda 3») no dice que `P` sea
pequeña, dice que **cubrir vale exactamente cero**. Eso exige `P = 0` **exacta**. Pero la propia
auditoría admite (§10.2, punto 4) que **no existe teorema de prefijo común** sobre la cadena
seleccionada de GHOSTDAG, así que `P = 0` exacta no está disponible — solo, como mucho, «`P`
pequeña». Con coste de cobertura ≈ 0, «pequeña» no basta.

**La cobertura racional que mató las rondas 3, 4 y 5 no está cerrada.** Está cerrada por la
constante `0.5`.

---

## 4 · Hallazgo D — el umbral 47,6 % es el valor con Δ = 0

Leído el paper en local
(`…/scratchpad/papers/bdk19.txt`), la fórmula del umbral, en la página anterior a la ec. (39), es:

```
β_c = e^(−λ_h·Δ) / ( e^(−λ_h·Δ) + φ_c )
```

y el pie de la Tabla 3 dice, **literalmente**: *«Numerically computed growth rate φ_c and stake
threshold β*_c **with Δ = 0**»*.

La propuesta y la auditoría usan `1/(1+φ_c)`, que es esa fórmula **solo si Δ = 0**. Pero la
propuesta usa **Δ = 4 s** en todo lo demás (§7: *«Dmax sigue sin medir; todo usa Δ = 4 s»*).

Resuelto el punto fijo (`verif_umbral_delta.py`, λ = 1 bloque/s, Δ = 4 s):

| `c` | `φ_c` | (a) Δ=0 — **lo publicado** | (b) `e^(−λ_hΔ)` — forma literal del paper | (c) `λ_h/(1+λ_hΔ)` — el crecimiento que usa la propia propuesta |
|---:|---:|---:|---:|---:|
| 16 | 1,4678 | 40,5 % | 1,3 % | 13,2 % |
| 50 | 1,2815 | 43,8 % | 1,5 % | 15,1 % |
| 400 | 1,1128 | 47,3 % | 1,7 % | 17,3 % |
| **500** | **1,1023** | **47,6 %** | **1,8 %** | **17,4 %** |

**Ninguna lectura que incluya Δ da 47,6 %.** Cuál de las tres aplica es exactamente el «empalme de
`φ_c`» que la auditoría etiqueta PLAUSIBLE — pero la auditoría publica la lectura (a), la única que
supone red instantánea, sin decir que lo es.

Este error **no es nuevo de la ronda 7**: viene de la ronda 1 (`dag-poas-auditoria.md:249` publica
«umbral 1/(1+φ₅₀) = 43,8 %») y ha atravesado siete rondas sin que nadie lo tocara.

---

## 5 · Hallazgo E — la fuente primaria impone una segunda unidad de lookahead, y esa sí se incumple

Este es el hallazgo más importante, porque ataca la **premisa 1**, que es el corazón de la ronda 7.

La propuesta sostiene que la unidad correcta para medir el lookahead es `A*`, el punto de equilibrio
del ploteo dirigido. Con esa unidad pasa holgadamente (42×). Pero **BDK+19 — el paper del que sale
`φ_c`, es decir, el paper que la propuesta usa para justificar `c = 500` — define una segunda unidad
y la hace vinculante.** BDK+19 §2, textualmente:

> *«If the prediction window **W** is greater than the confirmation-depth **κ**, then the following
> **covert (undetectable)** attack becomes possible.»*

y en §1: esos ataques son *«fatal (double-spends and ledger rewrites)»* y *«can be implemented by
bribing a fraction of users possessing an **arbitrarily small** total stake»*.

`W` está definida por el paper en **bloques**: *«W is the size of the prediction window measured in
units of number of blocks»*, y en la Fig. 2 es `c` × tiempo entre bloques.

Calculado con los dos puntos de ejemplo de la propuesta (`verif_ventana_prediccion.py`,
`λ_chain` de `chain_growth.py`):

| Punto | `κ = F·λ_chain` | `W = (L+I)·λ_chain` | `W/κ` | Régimen |
|---|---:|---:|---:|---|
| `q = 1` | 201 bloques | 703 bloques | **3,50×** | **soborno encubierto posible** |
| `q = 10` | 308 bloques | 709 bloques | **2,30×** | **soborno encubierto posible** |
| Autonomys (11 s), `q=1` | 201 | 2,21 | **0,011×** | fuera, con 2 órdenes de margen |
| Autonomys (11 s), `q=10` | 308 | 0,79 | **0,0026×** | fuera, con 2 órdenes de margen |

**Lo que esto significa.** La ronda 7 se construyó sobre la idea de que los 11 s de Autonomys eran
un conservadurismo arbitrario y que nadie había derivado «qué lookahead es peligroso». La fuente
primaria del propio diseño **sí lo había derivado**, en otra unidad, y por esa unidad los 11 s están
dos órdenes de magnitud **dentro** de lo seguro y los 58 min están **3,5× fuera**.

Y hay una circularidad: la propuesta sube `c` de 16 a 500 **para mejorar `φ_c`** (de 40,5 % a
47,6 %). Pero `W` crece con `c` **por construcción**. Es decir, el mecanismo con el que se compra
seguridad es el mismo con el que se paga predictibilidad. El título del paper lo anuncia:
*Security **vs** Predictability*. **La auditoría cobra el lado «security» y no paga el lado
«predictability».**

**Matiz honesto:** el ataque de BDK está formulado sobre certificados de liderazgo de PoS. Portarlo
a PoAS requiere que un granjero venda o firme por un sobornante; la unicidad de billete U3′ **no lo
impide**, porque el granjero firma una sola cadena (la del sobornante) y no equivoca. Pero el
análisis del porte **no lo ha hecho nadie**, ni en esta ronda ni en las seis anteriores. Lo que sí
está establecido es que el diseño **entra en el régimen** que el paper marca como peligroso, y que
Autonomys no.

---

## 6 · Hallazgos F y G — las cuentas favorables y las desfavorables se toman de ramas distintas

### F · La rama «ec. (2) completa» no se propaga al margen económico

La auditoría reconoce en §3.4 y en Q6 que, con la ec. (2) completa de GHOSTDAG (`k = 793` en vez de
24), el `F` propuesto es insuficiente: hacen falta 11 430 s en vez de 1 000 s. Y aun así etiqueta
Q6 como **RESPALDADO** y publica en §10.3 los márgenes 42× / 15×, que salen **solo** de la rama
`k = 24`.

Propagada la otra rama (`verif_margen_eq2.py`, `A*` del escenario B, el que favorece al atacante):

| Rama de `k` | `q` | Lookahead `L+I` | Margen vs GPU tope ALU (41,1 h) | Margen vs plotter 10× (4,1 h) |
|---|---|---:|---:|---:|
| `k=24/5` (**optimista**) | 1 | 0,97 h | 42,27× | 4,22× |
| `k=24/5` (**optimista**) | 10 | 2,75 h | 14,95× | 1,49× ← crítico |
| **ec. (2) completa** | 1 | 3,87 h | 10,62× | **1,06×** ← el presupuesto se agota |
| **ec. (2) completa** | 10 | 6,26 h | 6,56× | **0,65×** ← **sin margen** |

A `q = 10` con un plotter 10×, **fabricar espacio con GPU sale más barato que comprarlo**: la
premisa 1 se invierte y el diseño queda refutado **por su propio criterio**.

Además, §10.4 llama a `k = 24` *«la opción segura»*. Es al revés: `k = 24` es la rama **optimista**;
la segura es la ec. (2) completa. «Seguro» se está usando para decir «la que deja pasar el diseño».

### G · El «4,6·10⁻³⁷» es la columna equivocada del propio script del proyecto

`reversal.py` (ronda 1, reutilizado y citado por esta ronda) imprime **dos** columnas para `q = 1`.
Ejecutado ahora:

```
alpha=0.25 t=600s   q=1 (misma formula): 4.601e-37   q=1 GHOSTDAG cota (offset 3k=54): 1.238e-24
```

La columna que cita la propuesta en §4 es **«misma fórmula»**, es decir, la fórmula de la **cadena
lineal** aplicada al DAG. El propio script calcula aparte la cota GHOSTDAG con el desplazamiento
`3k` del Lema 10 / Prop. 8 del paper. Diferencia: **13 órdenes de magnitud.**

Y con la `k` que la propuesta realmente usa:

| `k` | offset `3k` | Riesgo de reversión a 600 s, α = 0,25 |
|---:|---:|---:|
| 18 (el del script) | 54 | 1,238·10⁻²⁴ |
| **24 (el de la propuesta)** | 72 | **2,652·10⁻²¹** |
| **793 (ec. 2 completa)** | 2 379 | **1,000** ← certeza |

Con `k = 793` la reversión a 600 s es **segura**. Es coherente —con esa `k` la confirmación se va a
3,18 h, y 600 s deja de ser una profundidad de confirmación—, pero eso es justamente el punto:

> **El beneficio estrella del DAG (latencia 120 s, riesgo 4,6·10⁻³⁷) y el coste reconocido del DAG
> (`F` de horas) se calculan en ramas distintas del mismo parámetro sin decidir.** Si se toma la
> rama conservadora, la confirmación pasa a horas y la comparación con la cadena lineal (3,3 h)
> se evapora casi entera.

La auditoría no revisó §4 de la propuesta: no está entre Q1..Q7.

---

## 7 · Lo que SÍ está bien — verificado, y no conviene tirarlo

| Afirmación | Estado | Prueba |
|---|---|---|
| Fórmula de `φ_c` y ec. (39) | **CORRECTA** | Leída la ec. (39) en el PDF: coincide carácter a carácter con `phi_c.py` |
| Valores `φ_c` | **CORRECTOS** | Tabla 3 del paper: `e, 2.22547, 2.01030, 1.88255, 1.79545, …`; el script da `2.2255, 2.0103, 1.8826, 1.7954, …` ✓ |
| `φ₁₆ = 1,4678` ≈ el 1,47 de Chia | **CORROBORADO** por vía independiente | Coincide con la cita del greenpaper en `CLAUDE.md` («at least 16») |
| `φ₁ = e` → 26,9 % | **CORRECTO** | El abstract del paper dice `1/(1+e)` ✓ |
| Tiempos de ploteo | **CORRECTOS** | `coste-ploteo-medido.md`: 83,608 s CPU, 69,363 s GTX 1070, 4,28 / 9,92 s extrapolados ✓ |
| Modelo `A*` y su aritmética | **CORRECTOS** | Análisis dimensional: `($/h)·(s/sector)/($/h/sector) = s` ✓. Los 12 valores de la tabla §3.1 reproducen exactamente |
| «Espacio efectivo = `A/t_plot`» | **CORRECTO** | Derivado aparte: en `T`, GPU plotea `T/t_plot` sectores × `A/slot` desafíos = `T·A/(t_plot·slot)`; honesto con `S` sectores = `S·T/slot`; igualando, `S = A/t_plot` ✓ |
| Cabeceras 17,5 GB/a, UTXO 1,3 GB/a, 31,5 M coinbases, cliente ligero 1,46 GB/mes | **CONSISTENTES** | 365·24·3600 = 31 536 000 ✓; 31,5 M × 40 B = 1,26 GB ✓; 17,5/12 = 1,458 ✓; 17,5/10 = 1,75 ✓ |
| Ataque A1 de D8 (primera pasada) | **TRABAJO REAL** | `d8_a1.py` construye un DAG con bloques, padres, coloreado GHOSTDAG y dos vistas honestas. La refutación era sólida y **R-FIN-1a hacía falta de verdad** |
| `d8b_b1.py` (desempate moldeable) | **TRABAJO REAL** | Simulación con aleatoriedad y `alpha` operativo. Salvedad: modela una carrera de cadena, no GHOSTDAG |
| Q1c (`<` frente a `≤`) | **CONCLUSIÓN CORRECTA** | Aunque la «simulación» es una construcción, el razonamiento del caso frontera es válido |

---

## 8 · Hallazgos menores, pero que dicen algo del método

**H · Cita fabricada.** §11 dice: *«BDK+19 (Dembo et al., "DAGger: A DAG-based Blockchain
Protocol")»*. Leído el PDF en local, el documento es:

> **Proof-of-Stake Longest Chain Protocols: Security vs Predictability**
> Vivek Bagaria, Amir Dembo, Sreeram Kannan, Sewoong Oh, David Tse, Pramod Viswanath, Xuechao Wang,
> Ofer Zeitouni — arXiv **1910.02218v3**

Tres errores: título inventado, primer autor equivocado (Bagaria, no Dembo — de ahí la «B» de
«BDK»), y **se ha perdido el arXiv ID** que las seis rondas anteriores sí llevaban
(`dag-poas-auditoria.md:5` y `:249`). El más grave es el título: **no es un paper de DAG, es de
cadena más larga**, y eso es exactamente la laguna que §10.2 punto 1 declara («φ_c está probado
sobre conteo, no sobre peso azul»). Un título inventado que dice «DAG» hace creer que la fuente
cubre el caso que precisamente no cubre.

**I · Coste de auditoría equivocado.** El modelo económico usa 42,9 µs. Su fuente,
`coste-ploteo-medido.md:96`, ordena lo contrario en negrita: *«⚠️ Para un análisis de seguridad hay
que usar la del atacante (2,82 µs), no la del granjero»*. **Dirección: conservadora** — con
2,82 µs el supuesto «el ploteo domina» se sostiene mejor, y `A*` no cambia. Pero es la instrucción
explícita de la fuente, ignorada.

**J · La columna «Líneas» de §9 son bytes.** Los 15 valores coinciden **exactamente** con
`stat -c%s`; los recuentos reales van de 96 a 466 líneas. Y `d8_a1.py`, listado como «4 500 (est.)»,
son 10 174 bytes / 278 líneas.

| | `r7_q1` | `r7_q2` | `r7b_q1` | `d8b_b1` |
|---|---:|---:|---:|---:|
| §9 dice «líneas» | 8 081 | 10 631 | 11 419 | 18 646 |
| bytes reales | 8 081 | 10 631 | 11 419 | 18 646 |
| **líneas reales** | **201** | **271** | **276** | **466** |

**K · «Superficie de ataque agotada» no está respaldado.** La primera pasada de D8 escribió **un
solo script** (`d8_a1.py`) y se detuvo al encontrar la refutación — metodológicamente correcto, pero
significa que las líneas A2, A4, A5 y A7 **nunca se ejecutaron**. La segunda pasada corrió 7 líneas,
de las cuales 3 son tautológicas (B2, B3, B4) y 2 triviales (B5: empate exacto en enteros de 128
bits; B6: consecuencia directa de R-FIN-5). Queda **B1** como única exploración adversarial real.

**L · Política de modelos.** `NODOS/ZEROX/CLAUDE.md:217` fija: *«D9 (matemáticas) y D8 (adversarial)
sobre un módulo consensus-critical recién especificado → **Opus**»*. La cabecera de la auditoría de
la ronda 7 declara **«(general)» en las cuatro pasadas**. Las rondas 2–4 se auditaron en Opus y las
5–6 en Sonnet, y todas refutaron. **La única ronda que ha pasado es la única auditada fuera de la
política escrita.** No prueba nada por sí solo; es un dato de proceso que conviene tener delante.

---

## 9 · El hueco lógico que sobrevive a todas las correcciones

Por encima de los defectos de implementación hay un problema de fondo que R-FIN-1a no toca.

**R-FIN-7 congela la vista de cada nodo; no crea acuerdo entre nodos.**

La demostración de Q1 establece correctamente que, con monotonicidad estricta, **ningún atacante
puede obligar a un nodo honesto a cambiar su `I_j` después de `t_j`**. Eso es cierto y está bien
argumentado. Pero la afirmación que Q1 tenía que demostrar es otra: que **dos nodos honestos leen el
mismo `I_j`**. Y esa se reduce, íntegra, a la propiedad de **prefijo común de la cadena seleccionada
de GHOSTDAG a profundidad `F`** — que §10.2 punto 4 reconoce que **no tiene teorema** y que «`F` se
calibra con medición, no con demostración».

Las cuatro simulaciones tautológicas (§1 y §2) **dan por supuesta esa propiedad**: todas construyen
**una sola** cadena honesta compartida `slots[]` / `owners_common[]` y luego comprueban que no pasa
nada. Es decir, suponen el supuesto abierto y reportan que no hay problema.

Y hay un agravante específico de R-FIN-7 «sin exit»: si dos nodos honestos **ya discrepan** en el
instante en que la finalidad congela, R-FIN-7 les **prohíbe** reconciliarse. El fallo no es una
bifurcación temporal: es una **partición permanente**. Cuanto mejor funciona R-FIN-7 para el
argumento de Q1, peor es el modo de fallo cuando el prefijo común no se cumple.

Esto conecta con §3: el argumento de la cobertura necesita `P = 0` **exacta**, y lo único disponible
es «`P` pequeña, sin teorema».

---

## 9 bis · La pinza — resultado estructural nuevo

Ninguna ronda comprobó si la condición `W ≤ κ` es **alcanzable con algún parámetro**. Lo es, pero
solo en una rama, y esa rama es incompatible con el argumento que sostiene la ronda 7.

`λ_chain` se cancela en la comparación, así que la condición es puramente estructural:

```
W ≤ κ   ⟺   (L + I)·λ_chain ≤ F·λ_chain   ⟺   L + I ≤ F
```

con `I = c/λ_chain > 0` siempre. De donde (`verif_pinza.py`, `q = 1`, `F = 1000 s`):

| Elección de `L` | `c` máximo para `W ≤ κ` | `φ_c` | Umbral (Δ=0) |
|---|---:|---:|---:|
| **`L = F`** (incondicional, la de la ronda 7) | **IMPOSIBLE** | — | — |
| `L = F/2` | 100 | 1,2070 | 45,3 % |
| `L = F/3` (§6, probabilística) | 134 | 1,1824 | 45,8 % |
| `L = F/5` (§6, probabilística) | 161 | 1,1684 | 46,1 % |

**Jaw 1 — con `L = F`, `W > κ` es una identidad.** No es un parámetro mal elegido ni un `c`
demasiado grande: para cualquier `c > 0`, cualquier `q` y cualquier `F`, `L + I = F + I > F`. El
diseño está en el régimen de soborno encubierto **por construcción**, y no hay ajuste que lo saque.

**Jaw 2 — con `L < F` sí se sale, y sale barato.** Bajar `c` de 500 a 134 cuesta **1,7 puntos de
umbral** (47,6 % → 45,8 %, ambos con Δ=0). Es un precio pequeño.

**Y las dos mandíbulas se cierran una sobre otra.** `L = F` es precisamente lo que hace funcionar el
argumento de Q2: *«un flujo divergente nace en un bloque ya final, cubrirlo vale cero»*. Con `L < F`
ese argumento desaparece y vuelve la **cobertura racional**, que es lo que mató las rondas 3, 4 y 5.
Y el único análisis de cobertura con `L < F` que existe es el de Q2 — el que tiene el coste cableado
a `0,5` cuando lo medido es ≈ 0 (§3).

> **La ronda 7 no eligió `L = F` por casualidad: es la única elección que cierra la cobertura. Y es
> exactamente la elección que hace inevitable `W > κ`.**

Esto reduce todo el problema a **una** pregunta, por primera vez en siete rondas:

> ¿Sobrevive el argumento de cobertura con `L < F` cuando el coste de cubrir un segundo flujo se
> pone en su valor medido (≈ 0) en vez de en `0,5`?

Si sobrevive, existe una octava propuesta bien definida: `L = F/3`, `c ≤ 134`, fuera del régimen de
soborno, pagando 1,7 puntos de umbral. Si no sobrevive, **P-038 queda cerrada por un argumento
estructural**, no por acumulación de refutaciones de mecanismos.

---

## 10 · Conclusión y recomendación

### Qué está establecido

1. **La propuesta no está refutada por nada de lo que he encontrado.** No he construido ningún
   ataque que la rompa.
2. **Tampoco está auditada** en las dos preguntas que Katana designó como decisivas. Q1 y Q2 tienen
   veredicto DEMOSTRADO sobre una tautología y una constante cableada.
3. **Aparecen dos problemas nuevos, de la propia fuente primaria del diseño:** el umbral publicado
   supone Δ = 0 (§4), y el diseño entra 3,5× en el régimen de predictibilidad que esa fuente marca
   como vulnerable, justo donde Autonomys está 2 órdenes fuera (§5).
4. **Los números favorables y los desfavorables se toman de ramas distintas** del mismo parámetro
   sin decidir (§6).

El veredicto correcto de la ronda 7 no es «SOBREVIVE» ni «REFUTADA». Es: **NO CONCLUYENTE, con dos
objeciones nuevas de fuente primaria sin responder.**

### Mi recomendación

**No reabrir P-038 sobre esta base, y no relanzar una octava ronda de propuesta.** Las dos objeciones
de §4 y §5 no son defectos de un mecanismo que se arreglen con una regla más: son propiedades del
intercambio `c ↔ predictibilidad` que el diseño usa como palanca central. Subir `c` para ganar
umbral **necesariamente** alarga la ventana de predicción; es el título del paper.

Lo que sí propongo, en orden y con coste acotado:

1. **Rehacer Q1 y Q2 con simulaciones que tengan adversario dentro** (coste: bajo; los defectos están
   localizados y el andamiaje de `d8_a1.py` sirve). Criterio de aceptación explícito: que el
   resultado **cambie** con `alpha`.
2. **Decidir `k` antes que nada más.** Es el parámetro del que cuelgan a la vez el margen económico
   (§6.F), el riesgo de reversión (§6.G) y `F`. Mientras no se decida, ninguna cifra de la propuesta
   es citable, porque cada una está tomada de la rama que le conviene.
3. **Contestar §5 (W vs κ) o aceptarlo por escrito como coste**, con la misma etiqueta de «ES UNA
   ELECCIÓN, NO UNA DERIVACIÓN» que la propuesta se aplica a sí misma en §1.
4. **Corregir el umbral publicado** en las siete rondas: `1/(1+φ_c)` es el valor con Δ = 0.

### Lo que no cambia

`φ_c`, el modelo `A*`, los tiempos medidos, la aritmética de costes y el ataque A1 son trabajo sólido
y verificado. El presupuesto económico de lookahead **sigue siendo una aportación real** — solo que
acota **una** clase de ataque (fabricar espacio), no la que su propia fuente señala (predictibilidad
y soborno).

---

## 10 bis · Auditoría de la recomendación de §10, a petición de Katana

Sometí mi propia recomendación («una sola pregunta a D9: rehacer Q2 con `L < F` y el coste de
cobertura medido») al mismo criterio. Resultado: **dos de las tres afirmaciones se sostienen; la
tercera es falsa.** Y al verificar la alternativa apareció la raíz de todo.

### (a) «La pregunta está sin responder» — VERIFICADO, y peor de lo que dije

`r7_q2.simulate_skellam_drift` documenta *«la diferencia de peso es Skellam de **deriva nula**»* pero
implementa:

```python
if random.random() < (1 - alpha):  diff += 1
else:                              diff -= 1
```

es decir, una caminata con deriva `(1−2α) = 0,34` **a favor del honesto**. Y `mean_final = h0 +
mu_h − mu_a` arrastra el mismo término. **La rama `L < F` nunca se analizó bajo el peor caso que la
propia propuesta declara** (cobertura total ⇒ ambos flujos crecen a `λ` ⇒ deriva nula). Se analizó
el caso fácil. **Quinto defecto**, y justo en la rama que yo recomendaba auditar.

### (b) «Es acotada» — VERIFICADO, con una corrección a §6 de la propuesta

El rincón `(F, L, c)` que cumple a la vez la seguridad de cobertura y `L + I ≤ F` **existe y no es
estrecho** (`verif_recomendacion.py`, `q=1`, `α=0,33`, `ε=10⁻⁹`):

| `F` | `L_min` | `L/F` | `c` máx. para `W ≤ κ` | umbral (Δ=0) |
|---:|---:|---:|---:|---:|
| 1 000 s | 537 | 0,54 | 93 | 45,2 % |
| 1 500 s | 704 | 0,47 | 160 | 46,1 % |
| 3 600 s | 1 218 | 0,34 | 478 | 47,5 % |
| 11 430 s | 2 374 | 0,21 | 1 818 | 48,6 % |

`L_min` crece como `√F` y `F` crece lineal, así que a partir de `F ≈ 1 500 s` sobra sitio.

**Corrección a §6 de la propuesta:** dice «`L ≈ F/3` a `F/5`». Es falso en general — `L/F` **depende
de `F`**. A `F = 1 000 s` sale `0,54`; el `F/3` solo aparece hacia `F = 3 600 s`. Calculada la
probabilidad de primer paso con deriva nula (principio de reflexión, factor 2 que §6 omite),
`L = F/3` a `F = 1 000 s` da `P = 1,9·10⁻³`, seis órdenes por encima del objetivo `10⁻⁹`.

### (c) «Decide P-038 en los dos sentidos» — **FALSO. Me equivoqué.**

Calculada la respuesta (`verif_q2_deriva_nula.py`), en el rincón de (b) la rama `L < F` **pasa** bajo
deriva nula, en los dos modelos de `h0` (`≈ 2·10⁻⁹` y `≈ 2,7·10⁻¹⁵`). Es decir:

- La pregunta es **respondible en minutos, no en una sesión de agente** — «barata» era cierto, pero
  tanto que no justifica lanzar nada.
- Su respuesta esperada es **«sobrevive»**, que es precisamente la que **no decide nada**.

Y en el sentido positivo no puede decidir, porque quedan seis lagunas intactas: prefijo común (§9),
empalme `φ_c`, umbral con Δ, `k` sin decidir, timelord, cliente ligero. **Mi frase era falsa: esa
pregunta solo puede cerrar, nunca abrir, y su resultado probable es que no haga ni lo uno ni lo
otro.**

### Lo que apareció al verificar la alternativa: la raíz

Antes de proponer «auditar primero el prefijo común» comprobé que esa pregunta no tuviera el mismo
defecto. Leído el paper de PHANTOM/GHOSTDAG en local
(`…/papers/phantom-ghostdag.clean.txt`, 1 439 líneas):

| Búsqueda | Ocurrencias |
|---|---:|
| `common prefix` | **0** |
| `prefix` | **0** |
| `stabiliz` | **0** |
| `chain converg` | **0** |

Todo lo que el paper demuestra converge es **el orden**: §3.4 *«Convergence of the order»*;
Property 1 *«An ordering rule ord is said to (1−α)-converge»*; Prop. 7 *«the probability that **the
ordering of two blocks** published before time t will change after t+r is O(e^{−cr})»*.

Y sobre la cadena seleccionada el paper dice **lo contrario** de lo que la propuesta necesita:

> *«In Nakamoto Consensus… the score of a Bitcoin node increases monotonically. **In GHOSTDAG this
> no longer holds.** Indeed, there are cases where by learning of new blocks, the blue score of the
> virtual node actually **decreases**.»*

**Esto es la raíz, y no es un defecto de la ronda 7.** El inyector se lee de «el ancestro de la
cadena seleccionada en la posición `c·j`». GHOSTDAG garantiza el **orden total** de los bloques; no
garantiza **qué bloque ocupa una posición dada de la cadena seleccionada**. Son objetos distintos:
la cadena seleccionada de Kaspa se reorganiza de forma rutinaria sin que el orden cambie, y eso es
normal y benigno *para el orden* — pero es fatal para una entropía leída de una posición.

R-FIN-1a no lo arregla: es una regla de **validez** que obliga a que los slots crezcan dentro de una
cadena; no impide que la cadena seleccionada sea **sustituida** por otra cadena válida.

**Afecta a todas las rondas desde la 3**, que es cuando D9 introdujo la corrección «inyector =
posición `c·j` de la cadena seleccionada». Las siete rondas construyeron sobre el único objeto de
GHOSTDAG que su paper no estabiliza.

**Matiz honesto:** que el paper no lo demuestre no prueba que sea falso — Kaspa funciona en
producción. Pero la propiedad no está enunciada, el análogo de Bitcoin está explícitamente negado
por los autores, y siete rondas la han dado por supuesta sin citarla.

### Recomendación corregida

1. **La pregunta de Q2 con deriva nula: contestarla aquí, no lanzarla.** Ya está contestada arriba
   (`verif_q2_deriva_nula.py`). Transcribir el resultado y corregir el `L ≈ F/3` de §6, que es falso
   a `F` pequeño.
2. **La pregunta que sí decide P-038 es la del prefijo común**, y su respuesta primaria ya está: el
   paper no la da. Lo que queda es una decisión, no una investigación: **o se demuestra**, que es
   trabajo de teoría original y no de auditoría, **o se cierra P-038 por desajuste estructural**.
3. **La única dirección de reparación que no queda cerrada** —y la anoto como observación, no como
   propuesta— es anclar el inyector en el objeto que GHOSTDAG **sí** demuestra: el **índice del
   orden total**, no la posición de la cadena seleccionada. Prop. 7 le da convergencia exponencial.
   Exigiría rehacer R-FIN-1 y Q1 enteras, y merece el mismo escrutinio que todo lo anterior.

---

## 11 · Reproducción

```bash
cd /tmp/d9-ronda7
python3 phi_c.py                    # Tabla 3 de BDK: reproduce exacto
python3 lookahead_economico.py      # A* : reproduce los 12 valores de §3.1
python3 reversal.py                 # las DOS columnas: 4.601e-37 y 1.238e-24
python3 verif_q1_tautologia.py      # hallazgo A: alpha de 0 a 1, siempre 0 exitos
python3 verif_cobertura.py          # hallazgo C: coste real de cubrir un 2.o flujo
python3 verif_umbral_delta.py       # hallazgo D: umbral con Delta = 4 s
python3 verif_ventana_prediccion.py # hallazgo E: W frente a kappa
python3 verif_margen_eq2.py         # hallazgo F: margen bajo ec. (2) completa
python3 verif_pinza.py              # la pinza: W>kappa es identidad con L=F
python3 verif_recomendacion.py      # auditoria de mi propia recomendacion
python3 verif_q2_deriva_nula.py     # respuesta a Q2 bajo cobertura total
```

**Fuente primaria leída:** `…/0cfccf9e-…/scratchpad/papers/bdk19.txt` — «Proof-of-Stake Longest
Chain Protocols: Security vs Predictability», Bagaria, Dembo, Kannan, Oh, Tse, Viswanath, Wang,
Zeitouni, arXiv 1910.02218v3. Ec. (39) y Tabla 3 en la pág. 29-30; definición de `W` y ataque de
soborno en §2.
