# Ancla de finalidad + presupuesto económico de lookahead — séptima propuesta para un DAG sobre PoAS

**Fecha:** 2026-09-07 · **PROPUESTA SIN AUDITAR** del agente principal, por decisión de Katana
(opción c: reabrir P-038 y buscar un séptimo diseño de DAG puro). Rondas anteriores y sus
refutaciones: `dag-poas-auditoria.md` (1), `dag-poas-inyeccion-auditoria.md` (2),
`dag-poas-candidatos-auditoria.md` (3), `dag-poas-voto-auditoria.md` (4),
`dag-poas-balizas-auditoria.md` (5), `dag-poas-relojes-auditoria.md` (6). Las dos últimas
auditorías fijaron la condición para una séptima ronda: **atacar una premisa, no variar el
mecanismo.** Esta propuesta ataca dos premisas que las seis rondas y sus seis auditorías
compartieron sin escribirlas. Debe pasar por D9 y D8. Scripts de esta ronda en el scratchpad de la
sesión (`d7/{phi_c,lookahead_economico}.py`), reproducibles.

## 0 · Las dos premisas que ataca

**Premisa 1 · «El lookahead de referencia es el de Autonomys: 11 s.»** Las seis auditorías midieron
el lookahead en «×Autonomys» y trataron ×36 (ronda 4) y ×95 (ronda 2) como refutaciones. Ninguna
derivó qué lookahead es *peligroso*. D9 lo dejó escrito en la ronda 2: *«el diseño es viable solo
si se acepta explícitamente pagar 75× el lookahead de Autonomys. Esa es una decisión de Katana, no
un resultado matemático»*. Nadie tomó esa decisión porque nadie puso el precio en la unidad
correcta. La unidad correcta es el **punto de equilibrio del ploteo dirigido**: el lookahead a
partir del cual fabricar espacio con GPU cuesta menos que comprarlo en SSD. Con los tiempos de
ploteo **medidos** por el proyecto sale en **horas, no en segundos** (§1). Autonomys eligió 11 s
por comodidad de su mecanismo lineal, no porque 12 s fueran inseguros.

**Premisa 2 · «Un DAG sobre PoAS necesita un evento acordado a profundidad cero e impredecible.»**
Es la frase que cierra las rondas 2, 3, 4 y 5. Es cierta **solo bajo la premisa 1**: si la
inyección tiene que surtir efecto segundos después del evento, el evento tiene que estar acordado
segundos después de ocurrir, y eso un DAG rápido no lo da. Si la inyección puede surtir efecto a
**profundidad de finalidad**, el evento solo necesita estar acordado a profundidad de finalidad,
que es lo que cualquier estructura Nakamoto da **por definición** de finalidad. El evento sigue
siendo impredecible (un granjero real gana un bloque real en tiempo real) y no moldeable
(`blake3(chunk ‖ pot_output)`, Autonomys, `subspace-verification/src/lib.rs:444-446`). Lo único que
cambia es *cuándo* se aplica.

**Consecuencia.** El rezago `L` entre el inyector y la aplicación deja de ser «≈ 0» y pasa a ser
«= profundidad de finalidad». Eso es exactamente lo que la ronda 2 quería. La ronda 2 murió por dos
cosas: el lookahead ×95 (premisa 1, que aquí se refuta con número) y la regla de no fusión
R-INJ-2, que hacía la validez relativa al fusionador y eliminaba la curación. **La ronda 3 reparó
lo segundo** (validez absoluta bien fundada por inducción sobre `past(B)`, D9: DEMOSTRADO) pero
volvió a profundidad cero para no pagar el lookahead, y ahí la mató la cobertura racional. Nadie
juntó «ancla a profundidad de finalidad» con «validez absoluta» porque la premisa 1 lo prohibía.
Esta propuesta es esa unión, más una regla nueva (R-FIN-5) que cierra el DoS de flujos ajenos que
la ronda 3 dejó abierto.

## 1 · El presupuesto de lookahead, derivado

Modelo (D9, ronda 2, §3.3, sin cambios): con lookahead `A` el atacante prueba cada sector recién
ploteado contra `A` desafíos futuros en vez de uno; auditar cuesta 42,9 µs por sector y desafío
(`coste-ploteo-medido.md`), plotear cuesta `t_plot`; el ploteo domina y el espacio efectivo es
`A / t_plot` sectores de 1 GiB por GPU. El atacante paga `G` GPUs de forma continua; el honesto paga
`A/t_plot` sectores de SSD. Punto de equilibrio:

```
A* = coste_horario_GPU × t_plot / coste_horario_SSD_por_sector
```

`t_plot` está **medido**: 69,363 s en GTX 1070; 4,28 s (ALU-bound) y 9,92 s (ancho de banda)
extrapolados a GPU tope 2026 (`coste-ploteo-medido.md`). Los **precios son supuestos** y van
marcados como tales; se dan tres escenarios para ver la sensibilidad, no para elegir uno
(`d7/lookahead_economico.py`):

| Escenario de precios (SUPUESTO) | GTX 1070 (medido) | GPU tope, ancho de banda | GPU tope, ALU | 10× sobre ALU (margen tecnológico) |
|---|---:|---:|---:|---:|
| A · GPU 2 000 $/2 a/300 W · SSD 100 $/TiB/5 a · 0,10 $/kWh | 1 022 h | 146 h | **63 h** | 6,3 h |
| B · GPU 1 000 $/3 a/250 W · SSD 60 $/TiB/5 a (favorece al atacante) | 665 h | 95 h | **41 h** | 4,1 h |
| C · GPU 3 000 $/2 a/400 W · SSD 120 $/TiB/4 a · 0,20 $/kWh | 1 120 h | 160 h | **69 h** | 6,9 h |

**Lectura.** Con la GPU tope extrapolada y el escenario que más favorece al atacante, el ploteo
dirigido solo compensa a partir de **41 horas** de lookahead. Un lookahead de **1 h** deja un margen
de 41-69× hoy, y de 4-7× frente a un plotter hipotético 10× más rápido que el extrapolado. Un
lookahead de **20 min** deja 120-200× hoy y 12-20× frente al 10×. Autonomys, con 11 s, tiene
13 000×: **está tres órdenes de magnitud por encima de lo que la economía exige**, y la cadena
lineal de ZEROX hereda ese margen sin haberlo pedido.

Lo que este presupuesto **no** cubre, dicho ahora: (i) la clase de ataque de las parcelas
comprimidas (almacenar parte y recomputar el resto), que es ortogonal al lookahead y golpea igual
a la cadena lineal; (ii) la deriva de precios y de tecnología, que obliga a que `L` e `I` sean
constantes **actualizables por C-UPG**, no eternas; (iii) que el atacante también necesita guardar
los sectores ganadores hasta su slot, coste que se ha ignorado a su favor. Y una nota de forma: es
un umbral **económico**, de la misma clase que el de 3,2 PiB del checkpoint (§25: «ES UNA ELECCIÓN,
NO UNA DERIVACIÓN»), y hay que escribirlo con esa etiqueta.

## 2 · El algoritmo

Constantes, todas **en tiempo** salvo `c`:

```
F   finalidad: profundidad máxima de reorg de la cadena seleccionada, en segundos de slot
L   rezago de aplicación de la inyección; candidatos: L = F (incondicional) o L ≈ F/4 (probabilístico, §6)
c   época de inyección, EN BLOQUES de la cadena seleccionada (D9 rondas 2-3: en tiempo cambia la seguridad)
q   slots por bloque esperado; candidatos q = 1 y q = 10
k   GHOSTDAG, en el punto fijo del retarget (D9 ronda 3: 24 a q = 1, 5 a q = 10)
```

Estructura: GHOSTDAG (`rusty-kaspa @ c338d495` como referencia) con `blue_work = Σ ⌊2^128/(SR+1)⌋`
sobre azules, desempate por menor `solution_distance` y nunca por hash, unicidad de billete U3′
(identidad `(public_key, sector_index, history_size, chunk, slot)`), retarget por controlador
multiplicativo sobre azules en ventana de slots (D9, ronda 3, DEMOSTRADO en modelo honesto), un
solo flujo de PoT verificado por gossip en su topic (§24.6c).

**R-FIN-1 · Posición e inyector.** `pos(B) = pos(sp(B)) + 1`, con `sp` el padre seleccionado. El
inyector de la época `j` visto desde `B` es `I_j(B) :=` el ancestro de la cadena seleccionada de
`B` en la posición `c·j`. Único por cadena, siempre existe, sin campo de cabecera, y `sp(B)` nunca
discrepa de `B` (es la corrección que D9 dio en la ronda 3, con demostración).

**R-FIN-1a · Monotonicidad de slot en la cadena seleccionada.** Para todo bloque `B` en la cadena
seleccionada: `slot(sp(B)) < slot(B)`. Un bloque cuyo padre seleccionado tenga slot mayor o igual
es inválido. Esto garantiza que la cadena seleccionada es estrictamente creciente en tiempo,
cerrando el ataque de desplazamiento de inyector (D8, ronda 7, A1).

**R-FIN-2 · Entropía e instante.** `entropía_j = blake3(chunk(I_j) ‖ pot_output(I_j))`;
`t_j = slot(I_j) + L`. Antes de `t_j` la entropía no se mezcla (verificado en código, ronda 4:
`sp-consensus-subspace/src/lib.rs:118-126`, solo en el slot exacto), así que **durante `[slot(I_j),
t_j)` todos los candidatos a `I_j` producen el mismo flujo**: una sola lotería.

**R-FIN-3 · Identificador de flujo.** `flujo(B, s) = H(flujo(B, t_{j−1}) ‖ entropía_j ‖ t_j)` para
la última inyección con `t_j ≤ s`, calculado sobre la cadena seleccionada de `B`. Entre inyecciones
el flujo es determinista. Dos linajes con las mismas parejas `(entropía, t)` son el mismo flujo,
aunque sus inyectores sean cabeceras distintas del mismo billete (cierra N1 de la ronda 3).

**R-FIN-4 · Validez absoluta.** `B` es válido si: su solución verifica bajo `flujo(B, slot(B))`;
su justificación de PoT cubre desde el slot futuro de `sp(B)` hasta `slot(B)` bajo ese flujo;
todos los bloques de `past(B)` son válidos; y cumple R-FIN-5. Función de `past(B)` y de nada más.
Bien fundada por inducción sobre el orden topológico: D9 lo DEMOSTRÓ en la ronda 3 para la forma
con inyector declarado, y su propia corrección (inyector = posición `c·j`) elimina el único paso
que allí dependía de la cabecera. Hay que rehacer la inducción con esta forma, no darla por hecha.

**R-FIN-5 · Pasado consistente de flujo.** Para todo `X ∈ past(B)`:
`flujo(X, slot(X)) = flujo(B, slot(X))`. Un bloque **MUST NOT** referenciar un bloque de un flujo
distinto. Es una comprobación **estructural** —`flujo(X, ·)` ya está calculado al validar `X`— que
se hace antes de tocar ningún PoT. Consecuencia: **un nodo honesto jamás verifica el PoT de un
flujo ajeno**, porque un bloque de flujo ajeno no entra en su DAG. El protocolo honesto es
«referenciar todas las puntas *del propio flujo*», que en operación normal —un solo flujo— es
exactamente el de GHOSTDAG.

**R-FIN-6 · Color.** El k-cluster de GHOSTDAG, sin ninguna condición de color por flujo: R-FIN-5
la hace innecesaria. «Cadena seleccionada ⊆ azules» se conserva tal cual.

**R-FIN-7 · Finalidad en tiempo, sin `exit`.** Un nodo **MUST NOT** reorganizar su cadena
seleccionada por debajo de `F` segundos de slot; una punta que lo exigiera se **ignora**
(`rusty-kaspa virtual_processor/processor.rs:298-306`), nunca apaga el proceso. Sustituye a
C-REORG-07 en el DAG. **No es deuda de ingeniería: es la pieza que sostiene §3.3.**

**R-FIN-8 · Rojos.** Ni la coinbase ni las transacciones de un bloque rojo se aplican al estado.
Rojo = peso cero, estado cero, recompensa cero. Se aparta de Kaspa a propósito (`utxo_validation.rs:122`
aplica las tx de los rojos): cierra la inflación ×10 (ronda 1, ataque 3) y el espacio de bloque
gratis (ronda 3, N6). La coinbase sigue dentro del cuerpo (C-HDR-08): un bloque se aplica entero o
no se aplica.

**R-FIN-9 · Recalibración del PoT.** Los cambios de `slot_iterations` (§19, por timestamps) se
leen también de la cadena seleccionada en la posición `c·j` y se aplican en `t_j`, para que el
flujo sea función del mismo inyector y del mismo instante.

## 3 · Por qué cada refutación de las seis rondas no aplica aquí

| Ronda | Qué la mató | Aquí |
|---|---|---|
| 1 | Inyector por posición ordinal a profundidad 0 → split honesto | El inyector se lee a profundidad `L ≥` finalidad. Que dos honestos discrepen es una violación de finalidad, probabilidad `ε` por construcción de `F` |
| 1 | `m` flujos fusionados → `m·α·λ`, umbral → 0 | R-FIN-5: los flujos no se fusionan, nunca. Un bloque de otro flujo no está en el DAG |
| 2 | Lookahead ×95 | Premisa 1: el lookahead se compara con `A*` (§1), no con 11 s. `L + I` cabe con margen ≥ 40× (§6) |
| 2 | R-INJ-2: validez relativa al fusionador; sin curación | Validez absoluta (R-FIN-4/5). Curación: cualquier partición `< F` reconecta con **un** flujo, porque antes de `t_j` no hay divergencia (R-FIN-2); una partición `> F` es violación de finalidad, el mismo fallo que Kaspa acepta más allá de sus 12 h |
| 2 | Épocas colapsadas | Época en posiciones de cadena: siempre existe el bloque `c·j` (D9, ronda 3, DEMOSTRADO) |
| 2 | Desempate por hash gratis | `solution_distance` |
| 2 | El atacante elige el inyector entre ~4 candidatos | El valor de elegir entre `m` entropías es `≈ c_m·√(αλI)/(αλI)` del ingreso de la época (D9, ronda 4, §5): con `I` de decenas de minutos es del orden del 3 % en ≤ 22 % de las épocas. Palanca de un bit por época, como en la lineal. **A cuantificar por D9** |
| 2 | R-INJ-5 obliga a `X ≪ L`; griefing por retraso | No hay R-INJ-5. Un bloque retenido no entra en la cadena seleccionada (su `blue_work` es el de su pasado, menor que el de cualquier punta honesta posterior); solo pierde su recompensa por k-cluster, como en Kaspa |
| 2 | DoS: sub-DAG de flujo falso, 77 kB → 60 core-s | Un sub-DAG de otro flujo no se verifica: R-FIN-5 lo rechaza estructuralmente antes del PoT |
| 3 | Cobertura racional de flujos → deriva cero, sin atacante | Solo existe si dos flujos pueden ganar. Un flujo divergente diverge en un bloque que en `t_j` está a `L` de profundidad. Con `L = F` ese bloque es **final** cuando el flujo nace: ningún nodo honesto puede adoptar el flujo por R-FIN-7, cubrirlo tiene valor esperado cero, nadie lo cubre. Con `L < F`, `P(alcance)` acotada por `ε` (§6, D9) |
| 3 | Spam de candidatos, 1,25-4,1 núcleos impodables | No hay candidatos declarados ni verificación de flujos ajenos. El coste de un flujo ajeno para un honesto es **cero** |
| 3 | Prefiltro de relé o evadible o particiona | No hay prefiltro: R-FIN-5 es consenso, no política |
| 4 | Semilla divergente anclada, `h = (1−2α)λV` | La semilla anclada **es** un flujo divergente: mismo tratamiento que la fila de la ronda 3. `V` de la ronda 4 es aquí `L`, y ya no compite con el lookahead de Autonomys |
| 5 | Exclusividad derrotable por Sybil (teorema) | No hay exclusividad de ninguna clase. El teorema no tiene objeto |
| 5 | Baliza retenida liberada en el corte; 31 % de intervalos sin baliza | No hay balizas ni corte: el inyector es una posición de cadena. El lema `Λ = D` de la ronda 5 se reutiliza para otra cosa: acuerdo honesto sobre `past(I_j)` en `t_j` |
| 6 | Grinding gratuito por elección de padres (`chunk_min` sobre `past(b)`) | La entropía sale de **un** bloque (`chunk ‖ pot_output`), no de un conjunto: elegir padres no la cambia |
| 6 | Reparto de coinbase por slot; verificación de relojes ajenos sin cota; filtro `τ` | Un flujo, coinbase por bloque, sin filtro |
| 6 | Cliente ligero peor | Sigue siendo un coste real: §5.4 |

## 4 · Lo que compra frente a la cadena lineal

Latencia a inclusión `120/q` s. Riesgo de reversión por orden a 600 s con `α = 0,25`: `4,6·10⁻³⁷` a
`q = 1` frente a `0,140` a `q = 120` (D9, ronda 1, `reversal.py`; sobrevive en la ronda 2 «para el
riesgo de orden»). El segundo término de riesgo que D9 añadió en la ronda 2, `P(discrepancia de
I_j)`, es aquí `≤ ε` por construcción. Todos los bloques cobran: la varianza del granjero pequeño
se divide por `q`. Sin huérfanos por colisión de slot. Y **no toca el PoT ni la prueba de espacio**:
cambia de dónde se lee el inyector y cuándo se aplica.

## 5 · Lo que cuesta, sin rodeos

1. **Lookahead `L + I(1−1/v)`**, ≤ `L + I` con `v → ∞`, frente a 11 s. Número en §6.
2. **Tolerancia a particiones `= F`.** Más allá, split permanente entre flujos (modelo de Kaspa).
   La lineal hoy: 3,3 h, con `exit`. Fijar `F = 3,3 h` empuja el lookahead a ~4 h y el margen
   económico a ~10× (§6). Es una bifurcación real para Katana.
3. **Cabeceras:** ≥ 17,5 GB/año a `q = 1`, cota inferior con un solo padre (D9, ronda 1); ~1,75 a
   `q = 10`. La lineal: 0,15.
4. **Cliente ligero (§26) no sobrevive.** GHOSTDAG no tiene SPV (D8, ronda 1, ataque 8): `blue_work`
   en cabecera es una afirmación. Con finalidad en tiempo y el ancla de release, la wallet tendría
   que bajar **todas** las cabeceras desde el ancla para colorear: 1,46 GB/mes a `q = 1`, ~0,15 a
   `q = 10`. Sin prueba de peso conocida. Es el coste estructural más grande del DAG y no lo
   arregla ningún parámetro.
5. **Coinbases:** 31,5 M salidas/año a `q = 1` (3,15 M a `q = 10`); crecimiento de UTXO ~1,3 GB/año
   si no se consolidan (estimación propia a ~40 B por salida).
6. **Previsión propia:** todo granjero conoce sus victorias `L` por adelantado (Chia: ~30 s). Sin
   efecto en consenso conocido; sí en mempool y en incentivos de ordenación. D8.
7. **Rojos sin aplicar:** una transacción que solo esté en un bloque rojo no entra; hay que
   reincluirla. Se pierde la inclusividad de Kaspa.
8. **Huecos de GHOSTDAG heredados sin cerrar:** no existe teorema de prefijo común sobre la cadena
   seleccionada (D9, ronda 2; `F` se calibra con medición, no con demostración); la ec. (2) de la
   calibración de `k` tiene un término que «no decae exponencialmente» y el propio paper y Kaspa lo
   ignoran (`k = 793` en vez de 18 si no se ignora, y `F` sube a 2,1-3,2 h); `φ_c` está probado
   sobre conteo, no sobre peso azul (todas las rondas).
9. **C-EXP-04:** altura `:= pos` en la cadena seleccionada; `altura_ploteo ≤ pos(punta) − F·λ_cadena`
   para que el mapeo sea inmutable. `VIDA_MINIMA` y `DISPERSION` se rederivan en tiempo.
10. **Poda:** sin niveles de PoW. Candidato: nivel `ℓ(B) = ⌊log₂(rango_solucion(B) / solution_distance(B))⌋`
    con el `rango_solucion` **de la propia cabecera** (fijo por bloque; D8 lo descartó en la ronda 2
    por usar el SR vigente, que cambia). Sin verificar.
11. **Retarget:** el sesgo del Lema 9 (31 % a `q = 1`) obliga a `k` en punto fijo (D9, ronda 3);
    que el sesgo sea sostenible es PLAUSIBLE, NO DEMOSTRADO.

## 6 · Constantes — forma de derivación, ningún número inventado

- **`F`** debe cumplir a la vez `F ≥ L_acuerdo(q, α_max, k, ε)` y `F ≥` tolerancia a particiones
  que Katana quiera. `L_acuerdo` está medido por D9 en la ronda 2 (`L_para_1e-9.py`, carrera con
  handicap `4k`): **682 s** a `q = 1`, `α = 0,33`, `k = 18`; **4 296 s** a `q = 10`, `k = 5`;
  **3,2 h** a `q = 1` con la `k` de la ec. (2) completa. Con `k = 24` (punto fijo) sube algo; a
  rehacer.
- **`L`**: incondicional `L = F`. Probabilístico: bajo cobertura total (peor caso, ambos flujos
  crecen a `λ`) la diferencia es Skellam de deriva nula desde `h = (1−2α)λL`, y el flujo divergente
  solo puede adoptarse antes de que su punto de divergencia sea final, ventana `F − L`; exigir
  `(1−2α)λL ≥ z_ε·√(2λ(F−L))` da `L ≈ F/3` a `F/5` (con `λ = 1`, `α = 1/3`: `L ≥ 1 237 s` para
  `F = 3 600`; `L ≥ 2 483 s` para `F = 12 000`). **D9 decide si el modelo de cobertura total es el
  peor caso** (el atacante añade sus bloques a ambos lados; la cascada «nerviosa» de la ronda 5
  entra aquí).
- **`c`** en bloques de cadena seleccionada, con `φ_c` de BDK+19 ec. 39 (`d7/phi_c.py`, reproduce
  `φ₁₆ = 1,4678` y `φ₅₀ = 1,2815`):

  | `c` | 50 | 100 | 250 | 500 | 1 000 | 2 000 |
  |---|---:|---:|---:|---:|---:|---:|
  | `φ_c` | 1,2815 | 1,2074 | 1,1387 | 1,1023 | 1,0754 | 1,0556 |
  | umbral `1/(1+φ_c)` | 0,438 | 0,453 | 0,468 | **0,476** | **0,482** | 0,487 |

  La duración de la época es `I = c / λ_cadena`, con `λ_cadena = λ/(1+λD)` (D9, ronda 1,
  `chain_growth.py`: 0,200/s a `q = 1`, 0,0712/s a `q = 10`). Condición de una sola inyección
  pendiente: `L < I` (el `INTERVAL > DELAY` de Autonomys); si `L ≥ I`, D9 debe mirar qué gana el
  atacante conociendo `entropía_j` antes de que se elija `I_{j+1}`.
- **Cota de lookahead:** `L + I ≤ A* / margen`, con `A*` de §1 y el margen decidido por Katana.
- **`k`**: punto fijo del retarget (D9, ronda 3).

Dos puntos de ejemplo, **para ver órdenes de magnitud, no como decisión**:

| | `q = 1`, `k = 24` | `q = 10`, `k = 5` |
|---|---:|---:|
| `F = L` (acuerdo a `10⁻⁹`, `α = 0,33`) | ~1 000 s | ~4 300 s |
| `c` · `I` | 500 · 2 500 s | 400 · 5 600 s |
| umbral `φ_c` | 0,476 | 0,473 |
| lookahead máximo `L + I` | **58 min** | **2,75 h** |
| margen frente a `A*` (esc. B, GPU tope ALU) | 42× | 15× |
| margen frente a `A*` con plotter 10× | 4,2× | 1,5× |
| tolerancia a particiones | 17 min | 72 min |
| cabeceras/año | ≥ 17,5 GB | ≥ 1,75 GB |

`q = 10` paga menos cabeceras y tolera particiones más largas, pero su `F` es 4× mayor porque la
cadena crece más despacio en bloques, y eso come el margen económico. `q = 1` tiene el margen y la
convergencia, y paga cabeceras y un cliente ligero inviable. **Ninguno de los dos está elegido.**

## 7 · Lo que NO está demostrado

- Que `F` derivado de la carrera de la ronda 2 sea la profundidad de acuerdo real de la cadena
  seleccionada de GHOSTDAG: es medición y extrapolación de 8 órdenes (D9, ronda 2), no teorema.
- Que la cobertura total sea el peor caso para `L < F`, y que la cascada «nerviosa» no lo empeore.
- Que `φ_c` con `c` en posiciones de cadena valga con peso azul en vez de conteo (empalme sin
  demostrar desde la ronda 3), y que el *steering* público del inyector esté acotado por
  `c_m/√(αλI)`.
- Que ignorar el segundo término de la ec. (2) de GHOSTDAG sea admisible (Kaspa lo hace; nadie lo
  demuestra).
- El presupuesto económico: sus precios son supuestos y su modelo ignora el almacenamiento de los
  sectores ganadores. Es una cota a favor del atacante, pero no está auditada.
- `Dmax` sigue sin medir; todo usa `Δ = 4 s`.

## 8 · Lo que D9 tiene que intentar refutar

1. **La premisa 2, formalmente:** que con `L ≥ F` la probabilidad de que dos nodos honestos lean
   inyectores distintos es la de violación de finalidad y no algo peor por la ventana de
   posiciones (`pos = c·j` es un conteo de cadena, no de slots; ¿mueve el atacante la posición
   `c·j` insertando bloques en su rama antes de que sea final?).
2. **Deriva bajo cobertura con `L < F`:** el modelo Skellam de §6 con atacante adaptativo y la
   cascada de la ronda 5; `L` mínimo para `ε = 10⁻⁹`; y si con `L = F` queda algún equilibrio en
   el que cubrir un flujo muerto sea racional.
3. **`φ_c` con `c` en posiciones** y el steering público, con peso azul.
4. **Lookahead exacto** con `L`, `I`, `D`, `v`, y con `L ≥ I` si se admite.
5. **El presupuesto económico:** el modelo de §1, sus supuestos y una cota que incluya el
   almacenamiento de ganadores; dar `A*` como intervalo con procedencia de cada entrada.
6. **`F` mínimo** con `k = 24` y con la ec. (2) completa, a `q = 1` y `q = 10`.
7. Retarget con R-FIN-5 (los bloques de flujo ajeno no cuentan): que el controlador de la ronda 3
   siga convergiendo.

## 9 · Lo que D8 tiene que intentar romper

1. **Forzar una divergencia de flujo con `α < 1/2`:** partición inducida `> F` por eclipse o
   retraso selectivo; coste real en C-NET-20.
2. **R-FIN-5 como palanca:** un bloque válido que un honesto no puede referenciar; ¿hay forma de
   hacer que dos honestos lean flujos distintos para el mismo `X` sin violar finalidad?
3. **Nodo que sincroniza:** debe elegir flujo antes de tener `F` de historia; el checkpoint firmado
   (§25) y el ancla de release cubren esto o no.
4. **Previsión de `L`:** qué hace un granjero que conoce sus victorias 15-60 min antes; retención
   con información perfecta propia dentro de GHOSTDAG; mempool.
5. **R-FIN-7 sin `exit`:** partición honesta `> F`, comportamiento de cada lado, y cómo se
   reconcilia sin humano.
6. **R-FIN-8:** censura por enrojecimiento; coste de excluir a un granjero concreto.
7. **Cliente ligero:** qué puede y qué no puede verificar una wallet desde el ancla de release, con
   número de bytes y de CPU a `q = 1` y `q = 10`.
8. Poda por nivel con el `rango_solucion` de la cabecera: ¿es moldeable el nivel vía el retarget?
9. Todo lo de §5.

## 10 · Considerado y descartado en esta ronda

- **Trunks por bloque (ronda 6, §5):** un VDF por bloque desde el padre seleccionado. Cada punta es
  una lotería: si el desafío se actualiza en cada bloque, `c = 1` y `φ₁ = e` (umbral 27 %); si se
  actualiza cada `c` bloques, vuelve la pregunta «cuál de los bloques del slot actualiza», que es
  el problema de acuerdo de las seis rondas. Y `k` timelords. No aporta nada que esta no tenga.
- **Revelación retardada por VDF** (`entropía_j = VDF(chunk ‖ pot_output, L·iter)`, al estilo del
  ICC de Chia): reduce el lookahead de `L + I(1−1/v)` a `(L + I)(1−1/v)` para `v` finito, sin
  cambiar la cota con `v → ∞`. Es una mejora opcional que añade un VDF más; se deja fuera del
  núcleo.

## 11 · Efecto colateral para la cadena lineal (P-039)

La premisa 1 también aprieta a la lineal: hoy a `T = 120 s` la inyección surte efecto **antes del
bloque siguiente** y una reorg de profundidad 1 bifurca el flujo (agravamiento de P-039). Con el
presupuesto de §1, la lineal puede aplicar la entropía del bloque `c·j` a `slot(c·j) + L` con `L`
de minutos —el inyector con confirmaciones de sobra— pagando un lookahead que sigue dos órdenes
por debajo de `A*`. No se decide aquí; se anota para P-039.
