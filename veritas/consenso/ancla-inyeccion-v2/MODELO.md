# MODELO — ANCLA-v0.2 · P-2.1 v3

## 1 · Bloque, DAG y parámetros (perfil A″)

- `λ = 1 bloque/s` total, `τ_nom = 1 s/slot`: **slot = índice entero de PoT = instante de
  creación** (`s ∈ ℕ`). R-FIN-1a no estricta: `slot(sp(B)) ≤ slot(B)`.
- `k = 30`, `max_block_parents = 15`, `mergeset ≤ 180`, `S_max_slots = 150`.
- Bloque: `(id::ID32, padres, slot, sd, sr, ident)`. `id` aleatorio de 32 bytes; `sd` uniforme en
  `[0, 2^64)`; `sr` **fijo por réplica** (sin retarget en 4.A: la tasa es λ y el reparto por α;
  con sr fijo, `blue_work ∝ Σ azules` y el desempate `(bw, sd, id)` coincide con la semántica de
  los instrumentos históricos D8/D9). Declarado en el contrato.
- Creación: por slot, honesto con prob `1−e^{−λ(1−α)}`, atacante con `1−e^{−λα}`, independientes;
  orden en el slot: honesto primero, atacante después (el atacante ve el bloque honesto del slot).
- GHOSTDAG: **GDR-v0.2 sin modificar** (`EstadoRapido`, `anadir!`, `cadena_seleccionada`,
  `virtual_sp`), `Params()` por defecto = SP_ZEROX + MERGE_SPEC + U3 dinámica.
- Selección de padres del honesto (portada de R-FIN-12 / `pick_virtual_parents`):
  candidatos = puntas de su vista ordenadas por `blue_work` descendente; el padre seleccionado es
  el primero que cumple `0 ≤ slot(nuevo) − slot(c) ≤ S_max`; el resto de padres (≤ 14) se eligen
  sobre la **cola de candidatos barajada** (mitad por `blue_work`, mitad al azar — el `shuffle`
  obligatorio de `processor.rs:1069-1089`), sin superar `blue_work(sp)` (si lo superasen serían
  sp y violarían R-FIN-1a) y con presupuesto de mergeset ≤ 180. Un honesto sin candidato válido
  **no crea bloque** (contador de cobertura de rama, informado).

## 2 · Épocas y ancla R-FIN-1

`T_j = j·I_slots` (índice de PoT). Una réplica mide UNA época: warm-up de `W0 = 300` slots,
`T_j = 300`, ventana de cortes `d ∈ [0, L_med)` con `L_med = 1000`, horizonte
`H = T_j + L_med + S_max + 100 = 1550` slots. Unidades: slots. La dependencia de `G(d)` respecto
de `I` es nula en este modelo (tasas fijas, traducción temporal por slots): declarado y
comprobado en una celda de sensibilidad (I ∈ {300, 851}).

### 2.1 · Orden de evaluación (ENCARGO §3.1), y unicidad del punto fijo

`I_j :=` primer bloque con `slot ≥ T_j` de la cadena seleccionada del bloque virtual **sobre
`past(B) ∩ {slot < t_j}`**, `t_j = slot(I_j) + L_slots`. Con R-FIN-1a todo bloque de la cadena
con `slot ≥ T_j` y con `slot < t_j` tiene slot ∈ `[T_j, T_j+S_max)` cuando `S_max < L`; y ningún
bloque con slot `≥ T_j+S_max` puede ser ancestro de un candidato (monotonía de slot). Por tanto,
para cualquier corte `x > T_j+S_max`, la restricción `{slot < x}` deja TODOS los ancestros de
cualquier candidato dentro del conjunto; el punto fijo se calcula por iteración finita:

```
t ← T_j + L
repetir:  X ← cruce de T_j en la cadena del virtual sobre {slot < t}
          si slot(X)+L == t: parar (punto fijo)
          si no: t ← slot(X)+L
```

Con `S_max < L` la sucesión de `t` es monótona y toma ≤ S_max+1 valores; detecto ciclos y
reporto en INFORME si aparece no-unicidad (encargo §3.1 lo exige). **Vector de regresión
obligatorio:** existe al menos un DAG donde la ancla sobre la vista completa ≠ ancla restringida
(el artefacto prohibido por el encargo); se incluye en los tests.

- **Ancla definitiva** de la época (referencia para W_obs): el punto fijo sobre el sub-DAG
  **completo** `{slot < t_j*}` (todos los bloques creados, publicados o no), NO sobre la vista
  completa del simulador.
- **Ancla de un observador en el corte d:** cruce de `T_j` en la cadena del virtual de su vista
  (bloques recibidos con llegada ≤ `T_j + d`). Para `d < L` toda llegada tiene slot `< t_j` (pues
  `slot ≤ T_j+d−Δ < T_j+L ≤ t_j`), luego la restricción es vacua en los cortes: no hay artefacto.
- **Cascada** (inyeccion-auditoria:112): si la cadena cambia por debajo de `T_j`, cambia `I_j` y
  todos los posteriores; en 4.A solo se mide la época j (una por réplica); la cascada se modela en
  4.B (coste de reconstrucción).

## 3 · W_obs y W_steer (ENCARGO §3.2), descompuestas

**W_obs** (por réplica, en slots tras `T_j`):
`W_obs = max( W_obs^def, W_obs^par )` con

- `W_obs^def = max sobre observadores o de max{ d : ancla_o(corte d) ≠ ancla definitiva }`;
- `W_obs^par = max sobre pares (o1,o2) de max{ d : ancla_o1(corte d) ≠ ancla_o2(corte d) }`.

`G(d) = P(W_obs > d)`; `G^def`, `G^par` y `G_vacío(d) = P(algún observador sin ancla en d)` se
entregan **por separado** y la conjunta `G = P(max > d)`. Con Δ constante uniforme,
`G^par ≡ 0` por construcción (declarado; cota inferior anticipada en el encargo).
Observador sin ancla = su cadena aún no cruza `T_j`: estado contado, nunca descartado.

**W_steer** (capacidad del atacante, magnitud del repositorio): leída sobre una sola vista
canónica al final del horizonte. Para cada `d` de la rejilla `{0,10,20,45,80,120,150,200,300}`,
`menu(d) =` conjunto de anclas alcanzables con decisión en `T_j+d` (liberar un candidato retenido,
o ninguno — V1; soltar/no soltar cadena privada — V2). `W_steer = max{ d : |menu(d)| ≥ 2 }`;
a α=0 es −1 por construcción. Portado de r9c (`r9c_c4_wdec.py`, rejilla y tope de 10 candidatos
literales) para el control positivo 1: máx −1/10/20/20/45 s a α=0/0,10/0,25/0,33/0,40.

## 4 · Red, vistas y retardos

Vistas **cerradas bajo ancestros** (ronda 14): `recv(b) = max(llega(b), max recv(padres))`;
un bloque se inserta en la vista de un observador solo cuando toda su ascendencia está recibida.
La **vista completa del simulador** (que incluye bloques del atacante aún no publicados) NUNCA se
usa para leer anclas de observadores.

- **Escalones de estrés (Δ ∈ {4,10,16} s):** retardo constante: bloque honesto creado por el
  observador `c` en el slot `s` → `recv(c) = s`, `recv(o≠c) = s+Δ`. Creadores honestos por
  turno rotativo entre los N_obs = 12 observadores (portado de MundoDosVistas).
- **Δ nominal (sub-segundo):** modelo DMS-v0.1 portado: grafo regular d=8 de N=100 nodos,
  latencia lognormal por arista (mediana 80 ms, p99 500 ms; μ=ln 0,08, σ=ln(6,25)/2,3263),
  inundación hop-by-hop con cola serial, `t_tx` según DMS; N_obs = 12 observadores muestreados
  de los 100; llegadas = tiempos de recepción de la inundación. Calibrado contra Δ_99 p99 ∈
  [0,26; 0,60] s de DMS-v0.1.
- **Atacante (adversario del paper, L1024-1027):** latencia cero; ve todo lo publicado;
  elige padres libremente dentro de la validez.

## 5 · Adversario 4.A (V1, V2, V3, A3)

- **V1** (portada de r9c_c4 con la clausura de publicación corregida): candidatos = bloques del
  atacante con slot ≥ T_j, **retenidos desde su creación**; el resto de bloques del atacante usa
  la política `tips_pub` (cuelgan solo de bloques ya publicados, para no delatar candidatos).
  Decisión en `T_j+d`: liberar UN candidato (publicar un bloque publica todo su pasado) o ninguno.
  El atacante maximiza W_obs sobre (candidato, d).
  **DECLARACIONES DE ADENDA-2 (ambas también en INFORME §1.4):**
  (i) **tope de 8 candidatos por muestreo uniforme** (`candidatos_v1`, `tope=8`): es **cota
  inferior del poder del atacante** — la misma laguna que el tope de 10 de la ronda 9c
  (`auditoria-8c.md:60`, LAGUNA declarada). Ningún veredicto sobre V1 vale sin esa etiqueta.
  (ii) **la ventana de la familia base es `[T_j, T_j+45]`**: hereda el «45 s» histórico que el
  encargo pedía no heredar. No la justifica `S_max` (una ancla puede estar hasta 150 slots tras
  `T_j`). Queda pendiente de justificar o barrer: en la segunda pasada se barre la ventana a
  `[T_j, T_j+S_max]` (y el tope) como celda de sensibilidad; hasta entonces, V1 se etiqueta
  «familia con tope 8 y ventana 45 s».
- **V2**: bloques del atacante en `[T_j−P, T_j+d]` con política `sp` (cadena privada: cada uno
  cuelga solo de su padre seleccionado propio); liberada (punto) o no en `T_j+d`, con clausura.
  Barrido P ∈ {0, 30, 60, 90, 120}.
- **V3**: V2 + entrega selectiva (A3) combinadas; búsqueda sobre (P, d, observador objetivo).
  **Declarada «la más fuerte que encontré, no demostrada óptima».**
- **A3** (portada de `MundoDosVistas`): el atacante entrega cada bloque suyo a UN solo observador
  (instantáneo); los demás lo reciben solo por cierre de ancestros (cuando reciben un honesto que
  lo referencia). Con N_obs=12 se sesga hacia el observador objetivo elegido por réplica
  (alternancia honesta 50/50 en el instrumento histórico).

## 6 · Desempate declarado

C-ORD-01 / SP_ZEROX de GDR-v0.2: mergeset y `rank` por `(blue_work, solution_distance, id)`
ascendente; padre seleccionado por máximo `blue_work`, en empate menor `sd`, luego menor `id`.
Es el desempate del diseño candidato; **no** el desempate por hash (fuera de la cobertura de
Prop. 7, trampa 11). El ancla es el **primer cruce** (equivalente DEMOSTRADO en ronda 11c Prop. 1
a «menor blue_work entre slot ≥ T_j»); leo la identidad estructural, nunca etiquetas.

## 7 · Proceso de ramificación de 4.C

Carrera de score discreta por slots (sin red): honesto gana cada slot con prob `λ_h`, atacante
con `λ_a` (presupuestos disjuntos; el mismo α NUNCA está en δ y en la carrera — prohibición del
encargo). El atacante mantiene S ramas privadas; cada victoria suya extiende UNA rama (asignación
como variante: fija uniforme vs adaptativa-al-mejor; la resolución de las hipótesis en disputa
sale de comparar ambas). `P_terminal ≤ P_primer_paso ≤ P_eventual` por definición de los tiempos
de parada. φ_c portado de BDK ec. 39 (verificado contra φ₁₆=1,4678, φ₅₀=1,2815 en
`relojes-auditoria.md:128-131`); umbral con retardo `α* = (1−δ)/(φ_c + 1−δ)`, δ de GHOSTDAG.
Barridos: S ∈ {1,2,4,8,16,24}, I_slots ∈ [300, 5000], α ∈ [0,25; 0,49], m hasta `1+λ·S_max=151`.

## 8 · Modelo de cobertura de 4.0 — RETIRADA (ADENDA-2)

> **RETIRADA (2026-09-19):** la 4.0 de este instrumento queda sustituida por **PCO-v0.1
> (`P-PUERTA/`)**. Defectos: constantes literales (`deriva_retarget = 0`, `t_abs = Inf` sin
> cálculo) y la hipótesis equivocada para ZEROX — el peso `w = ⌊2^128/(SR+1)⌋` cancela el SR:
> el peso crece ∝ al espacio que cubre el flujo, y la deriva con adopción es `∝ (1−c)(s₁−s₂)`.
> El texto de abajo queda como registro histórico del modelo retirado, NO como resultado.

- Coste marginal físico (medido en el repo, no heredado como cifra propia sino citado):
  auditar = 42,9 µs/sector/desafío; 4 TiB = 4 161 lecturas/slot por flujo; SSD 100 k IOPS.
  `S_max_racional(cap) = min( cores_AES disponibles, ⌊IOPS_ssd / (cap/4TiB · 4161)⌋ )`
  como función del coste marginal (IOPS + núcleos AES) y de `P(gana)`: cubrir el flujo i es
  racional ssi `P(gana i)·(recompensa por billete en i) ≥ coste marginal`. Se entrega la
  condición exacta y la curva.
- Deriva/absorción: `D(t)` = diferencia de peso entre los dos flujos; incrementos por slot con
  tasas ∝ al espacio que cubre cada flujo (`c` cubre ambos; `1−c` reparto simétrico o
  pro-minoritario como variantes); Skellam generalizado; tiempo de absorción hasta `D=0` (muerte
  de un flujo) por cadena de Markov exacta (enteros) y Monte Carlo para validar; barrido
  `c ∈ [0,1]`.
- Contraste histórico recalculado bajo R-FIN-4/5: dos flujos a tasa λ cada uno, sin fusión:
  la diferencia de peso es Skellam de deriva nula (recurrente): el líder cambia indefinidamente;
  `P(cambia tras τ)` exacta por convolución. Contrasta con 203,6 s / 0,82 de la ronda 3.

## 9 · Criterio de aceptación y controles positivos

- **Criterio de aceptación** (ENCARGO §4.A, reimplementado en Julia): `G(d)` debe cambiar con α;
  test automático: `G(α=0)`, `G(α=0,45)` y el degenerado `α=1` (atacante dueño de todo ⇒
  `W_obs ≈ L_med+Δ`) son tres distribuciones distintas; declarado el resultado.
- **Control positivo 1**: W_steer contra ronda 9c (tabla de máx −1/10/20/20/45 s, Δ=4 s,
  12 semillas, misma rejilla).
- **Control positivo 2**: P(dos honestos leen I_j distinto en T_j+d) con A3, Δ=4 s, k=30,
  12 semillas, rejilla diádica {4,…,512} — contra `salida_c14.txt` (α=0: 0,886/0,644/0,348/0,0833/
  0,0076/0; α=0,25: 0,608/0,220/0,0379/0/0/0; α=0,40: 0,504/0,106/0,0152/0/0/0); explico la
  anomalía (cola más larga a α=0) o la reporto como discrepancia.
- **Cota de calibración de la cola**: ajuste exponencial contrastado contra
  `r = (√((1−α)λ) − √(αλ))²` = 0,0572 por slot a α=1/3.

## 10 · Estadística

Unidad independiente = época/réplica (una época por réplica, DAG independiente, RNG derivado por
réplica con Random123/StableRNG). Reducción determinista por orden de réplica. IC 95 %
Clopper–Pearson simultáneo (por d) vía `beta_inc`; `0/n` se publica como cota `3/n` al 95 %, no
como frontera. Extrapolación por debajo de lo medible: etiqueta `estimado`, hipótesis exponencial.
Régimen numérico: conteos en enteros; G en Float64 con IC exactos; 4.0 en aritmética exacta
(Rational/BigInt) para los umbrales.
