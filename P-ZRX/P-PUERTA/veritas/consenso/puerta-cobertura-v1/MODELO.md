# MODELO — PCO-v0.1

Notación: `c` es la fracción del espacio total que audita **los dos** flujos; `1−c` se reparte en
exclusiva `s₁ / s₂` con `s₂ = 1−s₁`. El espacio que cubre el flujo `i` es

```
W_i = c + (1−c)·s_i ,        W₁+W₂ = 1+c ≥ 1
```

`W₁+W₂ > 1` no es un error: en prueba de espacio **el mismo sector se audita contra los dos
retos**; no hay que repartir el espacio (`research/dag-poas-ancla-de-finalidad-metaauditoria.md:130-145`).

---

## 1 · La tasa de peso de un flujo — el punto 1 del encargo

### 1.1 · Lo que se cancela, y por qué

Sea `P` el número de ensayos por slot de un flujo (pares sector–pieza auditados) y `SR` su rango.
El predicado de aceptación es, **leído del código**
(`PDF/autonomys-subspace/crates/subspace-verification/src/lib.rs:150-158` y
`.../subspace-core-primitives/src/solutions.rs:332-337`):

```
bidirectional_distance(audit_chunk, global_challenge) ≤ SR ÷ 2
```

una distancia sobre un **círculo** de `2^64` puntos. El número de valores aceptados es

```
A(SR) = 2·(SR ÷ 2) + 1  =  SR+1  si SR es par
                           SR    si SR es impar
```

El peso de un bloque es `w(SR) = ⌊2^128/(SR+1)⌋` (`SPEC.md:1669`, `C-GD-01`). Por tanto

```
tasa_peso(P,SR)  =  P · A(SR)/2^64 · ⌊2^128/(SR+1)⌋
```

y, escribiendo `⌊2^128/(SR+1)⌋ = (2^128 − ρ(SR))/(SR+1)` con `ρ(SR) = 2^128 mod (SR+1)`, en forma
cerrada exacta:

```
razón(SR) := tasa_peso(P,SR) / (P·2^64)
           = 1 − ρ(SR)/2^128                       si SR es par
           = SR/(SR+1) − SR·ρ(SR)/((SR+1)·2^128)   si SR es impar
```

**Conclusión del punto 1, demostrada y verificada en enteros exactos:**

- **El `SR` se cancela**, y se cancela **en todo instante**: `SR` entra como `(SR+1)` en la tasa de
  bloques y como `1/(SR+1)` en el peso. La cancelación **no depende del retarget**: vale con el
  retarget convergido, sin converger, con clamp, con cualquier ventana y con cualquier regla de
  redondeo, porque `SR` es la misma variable en los dos factores. **No existe transitorio de
  retarget en la media de la tasa de peso.**
- **Salvo por dos residuos, los dos exactos:**
  1. **El suelo**: `ρ(SR)/2^128 ≤ SR/2^128 < 2^{-64}`. Irrelevante en todo el dominio.
  2. **La paridad**: si `SR` es **impar**, queda un déficit de exactamente `1/(SR+1)` (menos el
     suelo). Y es materialmente relevante en redes grandes: `SR` decrece con el espacio, así que el
     déficit **crece** con el tamaño de la red. Con el `SR_MIN = 2^11` que el repositorio ha
     barajado, el déficit llega a `1/2049 = 4,88·10⁻⁴`.
- Y el efecto es **elegible**: para la misma tasa de bloques hay **dos** `SR` (uno par y uno impar,
  porque `A(2m) = A(2m+1)`), y dan **pesos distintos**. Qué `SR` devuelve el retarget es hoy un
  detalle de redondeo sin justificación de consenso.

### 1.2 · Lo que NO se cancela: la fracción azul

`blue_work` suma **solo los azules** (`SPEC.md:1710`). Sea `ν_i` la tasa total de bloques del flujo
`i` y `β_i` su fracción azul. Entonces, usando `ν_i = W_i·A(SR_i)/2^64`:

```
tasa_blue_work(i) = β_i · ν_i · w(SR_i) = β_i · W_i · 2^64 · razón(SR_i)
```

**El enunciado correcto del punto 1 es por tanto**

```
R_i ∝ β_i · W_i        (con razón(SR_i) = 1 − O(2^{-64}) ó 1 − 1/(SR_i+1))
```

y `R_i ∝ W_i` **si y solo si `β₁ = β₂`**.

- **En régimen**, R-FIN-13′ (`SPEC.md:1289-1291`) hace que cada flujo reajuste sobre su propio
  conjunto pagable, lo que fija la **misma** tasa en los dos flujos ⟹ `β₁ = β₂` ⟹ `R_i ∝ W_i`
  **exacto** (salvo los dos residuos de §1.1). El `ν` se cancela también: la expresión de arriba no
  contiene `ν`.
- **En el transitorio**, los dos flujos heredan el `SR` del último bloque común, `ν_i = W_i·ν₀`
  difiere, y `β` es decreciente en `ν`: el flujo **minoritario** produce más despacio, tiene menos
  anticono y una `β` mayor. El transitorio **favorece al minoritario**, es decir **estabiliza la
  partición**. Su tamaño es `β₁/β₂ − 1` y está tabulado en `resultados/peso-beta.csv`.

`β` se modela como `P(Poisson(2νΔ) ≤ k)` (**H-BETA**, declarada). No es un teorema de GHOSTDAG.

---

## 2 · La dinámica de la diferencia de peso — el punto 2

`D(t) := blue_work₁(t) − blue_work₂(t)`. Es un Poisson compuesto con dos tamaños de salto. Medido
en unidades de `w₂`, sube `r = w₁/w₂` a tasa `λ₁` y **baja exactamente 1** a tasa `λ₂`.

| | tasas `λ_i` | salto `r` | proceso |
|---|---|---|---|
| **Régimen** (retarget convergido) | `λ₁ = λ₂ = λ` | `r = W₁/W₂` | Poisson compuesto de dos saltos |
| **Transitorio** (`SR` común) | `λ_i = β_i·W_i·ν₀` | `r = 1` | **Skellam** verdadero |

Los dos tienen la misma deriva `∝ (1−c)(s₁−s₂)`, **pero distinta varianza y distinto retículo**:
las probabilidades de cambio de signo y la magnitud de arcoseno **no coinciden**, y por eso se
entregan los dos. Lo que sí coincide es el signo de la conclusión.

### 2.1 · Régimen «sin adopción»

R-FIN-5 (`research/dag-poas-ancla-de-orden.md:223-225`) prohíbe que un bloque referencie un bloque
de otro flujo, y la comprobación es **estructural, antes de tocar el PoT**: «un nodo honesto jamás
verifica el PoT de un flujo ajeno». R-FIN-7 (`:301-303`) prohíbe reorganizar por debajo de `F`.
Si ningún nodo verifica ni adopta la rama rival, **la partición es permanente por construcción**,
con cobertura o sin ella, con deriva o sin ella. No hay nada que simular: es la letra de las dos
reglas. `L(t) ≡ 1` no aplica aquí porque ni siquiera hay un «líder» común que pueda cambiar.

### 2.2 · Régimen «con adopción»

El nodo sigue al flujo de mayor `blue_work` mientras `F` se lo permita. Entonces el líder es
`sign(D)` y la pregunta del encargo es la probabilidad de que ese signo vuelva a cambiar.

**Raíz de Lundberg.** `R > 0` es la única raíz de

```
g(R) = λ₁·(e^{−R·r} − 1) + λ₂·(e^{R} − 1) = 0
```

que existe si y solo si la deriva `λ₁r − λ₂ > 0`. Con deriva nula, `R = 0`.

**Ruina.** `M_u = e^{−R·D(u)}` es martingala. El proceso baja en saltos de tamaño 1, así que al
cruzar el cero acaba en `D(τ) ∈ (−1,0]` y el teorema de parada opcional da

```
e^{−R(d+1)} ≤ P(D baja a ≤0 desde d) ≤ e^{−R·d}
```

**exacto** (las dos cotas coinciden) cuando `r` es entero, porque entonces el salto aterriza justo
en 0. Ese es el transitorio: se recupera `P = (λ₂/λ₁)^d`, el clásico de Skellam.

**`L(t)`, la función que pide el encargo.** Con deriva positiva, desde `D ≤ 0` el signo vuelve a
cambiar con probabilidad 1, luego

```
L(t) = P(D(t) ≤ 0) + E[ h(D(t))·1(D(t)>0) ]
```

y, usando que `E[e^{−R·D(t)}] = e^{t·ψ(−R)} = 1` por definición de `R`, la inclinación exponencial
convierte el segundo sumando en **otra probabilidad**:

```
E[e^{−R·D(t)}·1(D(t)>0)] = P(D̃(t) > 0),   λ̃₁ = λ₁e^{−R r},  λ̃₂ = λ₂e^{R}
```

```
L(t) = P(D(t) ≤ 0) + P(D̃(t) > 0)          [con h exacta: r entero]
L(t) ∈ [ P(D≤0) + e^{−R}·P(D̃>0) , P(D≤0) + P(D̃>0) ]    [en general]
```

**Los dos sumandos son probabilidades del lado equivocado y los dos decaen.** No hay ninguna resta
de números grandes y por eso **no hace falta ningún `min(1.0, ·)`**: el resultado sale en `[0,1]`
por construcción. Con deriva nula, `R = 0`, los dos sumandos son `P(D≤0)` y `P(D>0)` y la función
**calcula** 1.

**Decaimiento.** `ψ` es convexa, `ψ(0) = ψ(−R) = 0`, y `θ* = log(λ₁r/λ₂)/(1+r)` da el mínimo. Con
`I = −g(θ*)`, la cota de Chernoff acota **los dos** sumandos —el del proceso inclinado porque
`ψ̃(θ) = ψ(θ−R)` y el mínimo cae dentro de `(−R,0)`—, así que

```
L(t) ≤ 2·e^{−I·t}        y        t(ε) ≤ log(2/ε)/I
```

**Escala.** `L` depende de `(λ, t)` solo a través de `λt`. Luego `t(ε) ∝ 1/λ`: no hay que barrer
`λ`, y el test lo comprueba en vez de suponerlo.

### 2.3 · Congelamiento simultáneo — la regla, leída por su letra

**Corrección tras objeción del validador (2026-09-19).** La primera versión de este modelo definía
la absorción como *«`sign(D)` constante durante `F` desde que el nodo adoptó»*. **Eso no es lo que
dice R-FIN-7.** Su letra (`research/dag-poas-ancla-de-orden.md:301-303`) es:

> *Un nodo **MUST NOT** reorganizar su cadena seleccionada **por debajo de `F` segundos de slot***

Es una cota a la **profundidad** de la reorganización, no al tiempo que el nodo lleva en su flujo. Y
la profundidad que exige cambiar de flujo está fijada por dónde se bifurcaron: con **R-FIN-3**
(linaje acumulativo, `flujo(B,s) = H(flujo anterior ‖ entropía_j ‖ t_j)`) los dos linajes nunca
vuelven a coincidir, y con **R-FIN-5** todo bloque del flujo rival tiene su pasado entero en el
flujo rival. Luego el punto de bifurcación se queda clavado en `t_j` y su profundidad crece **a un
segundo por segundo**:

```
profundidad para cambiar de flujo en el instante t  =  t − t_j
```

De donde la regla correcta, que es **más fuerte y más simple** que la que yo había escrito:

> **Todos los nodos se congelan a la vez en `T* = t_j + F`**, cada uno en el flujo que su propia
> vista diga que lidera en ese instante. Antes de `T*` cualquiera puede cambiarse; después, nadie.

**Consecuencia 1 — con vista común no hay divergencia.** Sin atacante y sin asimetría de red todos
ven el mismo `D`, luego todos se congelan en el mismo flujo y **la partición se resuelve, siempre,
en tiempo exactamente `F`**. No hay nada estocástico que medir.

**Consecuencia 2 — la única grieta es el desfase de vista.** Si un nodo va `τ` segundos por detrás
de otro, sus vistas en `T*` son `D(F−τ)` y `D(F)`, y se congelan en flujos distintos si y solo si
**el líder cambió durante esos últimos `τ` segundos**:

```
P_div(F, τ) = P( sign D(F−τ) ≠ sign D(F) )
            = Σ_{e ≠ 0} P(ΔD = e)·P( D(F−τ) ∈ I_e ),   I_e = (0,−e] si e<0;  (−e,0] si e>0
```

exacto, condicionando por el incremento `ΔD` sobre la ventana `τ` —que tiene pocos eventos,
`Poisson(λτ)`— y usando probabilidades de **banda** `P(a < D ≤ b) = prob_le(b) − prob_le(a)`.

En el límite de difusión **sin deriva** tiene forma cerrada. `(D(F−τ), D(F))` es normal bivariante
de correlación `ρ = √((F−τ)/F)`, y la probabilidad de caer en cuadrantes opuestos es
`1/2 − arcsin(ρ)/π`, que con `arcsin(√(1−x)) = π/2 − arcsin(√x)` queda

```
P_div → arcsin(√(τ/F)) / π            [decae como √(τ/F)]
```

**Y esta división sí es permanente**: ocurre justo en el instante en que la regla cierra la puerta,
así que ninguno de los dos lados puede ya volver.

**Consecuencia 3 — los que llegan después.** Un nodo que se sincroniza en `u > T*` reconstruye toda
la historia, así que su bifurcación también está a profundidad `u − t_j > F`: **toma el líder que
vea al llegar y se queda con él**. Discrepa de los veteranos si y solo si el líder cambió alguna vez
después de `T*`, es decir con probabilidad **`L(F)`** — la misma función del §2.2, que con deriva
nula vale exactamente **1**.

Y el líder sí puede seguir cambiando después de `T*` **si** los granjeros que cubren los dos flujos
siguen firmando en los dos: R-FIN-7 constriñe la **cadena seleccionada** de un nodo, no qué bloques
puede firmar (**H-PRODUCIR-SIN-SELECCIONAR**, que es una lectura de la letra y no una regla
escrita). Si una regla atara producir a seleccionar, después de `T*` el flujo perdedor dejaría de
recibir bloques, `D` se alejaría de cero monótonamente y **el canal de los recién llegados se
cerraría solo**.

**Cota de banda.** Si en vez del retardo se parametriza el desacuerdo como un desfase `δ` en el
valor de `D`, dos nodos solo pueden discrepar si `D` está dentro de esa banda:
`P_div ≤ P(|D(F)| ≤ δ)`, con `δ = (λ₁r + λ₂)·τ` el peso en vuelo. Es una cota válida y **holgada
por un factor 5–7** frente al cálculo exacto por retardo; se publica porque es la forma en que la
pregunta suele plantearse, no porque sea la mejor.

**Lo que medía la regla anterior.** `resultados/absorcion.csv` conserva
`P(∃ dos rachas disjuntas de longitud ≥ F con signos opuestos)` dentro de un horizonte. Bajo la
regla corregida **eso no es «dos nodos bloqueados en flujos distintos»**: es una **cota inferior
estricta** de la divergencia veterano/recién-llegado, porque exige una racha completa de longitud
`F` del signo contrario cuando al recién llegado le basta un instante. El valor correcto de esa
magnitud es `L(F)`.

### 2.4 · Realimentación

Los granjeros en exclusiva del flujo perdedor se cambian: `s₁` relaja hacia el líder a tasa `ρ`,

```
ds₁/dt = +ρ(1−s₁)  si lidera el flujo 1 ;   −ρ·s₁  si lidera el 2
```

Entre dos bloques la solución es exponencial y se aplica exacta. En régimen las **tasas** no
cambian (`λ₁=λ₂=λ`): lo que cambia es el **peso** por bloque, `w_i ∝ W_i(t)`.

---

## 3 · Cobertura racional — el punto 3

Un granjero de `x` TiB que ya cubre el flujo canónico decide si cubre además el flujo `j`.

```
ingreso marginal por slot  =  p_j · Rec_j · x / W_j
coste marginal por slot    =  π_io·ℓ·x  +  π_cpu·(a·x + v)
```

con `ℓ` lecturas/slot/TiB, `a = ℓ·(42,92 µs)/dur_slot` núcleos/TiB y `v` los núcleos de
**verificación del PoT del flujo**, que **no escala con la granja**. Dividiendo por la recompensa
por TiB `Rec_j/W_j` quedan dos números adimensionales y **ningún precio inventado**:

```
ρ_var = (π_io·ℓ + π_cpu·a)·W_j/Rec_j        [adimensional]
ρ_fij = π_cpu·v·W_j/Rec_j                   [TiB]

cubrir es racional  ⟺  p_j  >  ρ_var + ρ_fij/x
```

De ahí el **tamaño mínimo de granja** `x* = ρ_fij/(p_j − ρ_var)`, y `c` en equilibrio **no es una
elección del modelo**: es la fracción del espacio en manos de granjas por encima de `x*`.

Y hay un tercer término que el argumento histórico no contaba: **alguien tiene que producir el
PoT** del flujo (`prove = 1,561 s/slot`, `research/dag-poas-ancla-de-orden.md:342`), unas 16 veces
el coste de verificarlo. Si ninguna granja llega a `x*_productor`, el flujo **no tiene quien le
calcule la cadena de PoT** y muere solo.

**Techo físico.** Dos límites, y el correcto **no depende de la capacidad**:

```
S_IOPS(ι)        = ι · dur_slot / ℓ          [ι = IOPS por TiB del medio]
S_núcleos(N,x)   = N / (a·x + v)
S_max            = min(S_IOPS, S_núcleos)
```

`S_IOPS` es constante en la capacidad porque las lecturas y los discos crecen a la vez; fijar un
solo SSD para cualquier capacidad es el error que produce el absurdo «0 flujos con 100 TiB».

---

## 4 · Complejidad, representación y presupuesto

| Parte | Coste | Representación elegida y por qué |
|---|---|---|
| Punto 1 | `O(1)` por `SR`, aritmética de precisión arbitraria | `BigInt`/`Rational{BigInt}`. El resultado se decide en el bit `2^{-64}`: `Float64` no puede verlo. |
| `L(t)` | `O(√(λt))` por evaluación | Suma sobre una ventana de `n₁` con las dos colas acotadas por gammas incompletas **exactas**. La ventana se centra por media y se ensancha hasta que la masa excluida baja de `10⁻⁴·` la cota de Chernoff del propio resultado. |
| `t(ε)` | ~14 evaluaciones | Newton sobre `log L` con pendiente `I`, arrancando del tiempo suficiente certificado. Bisección costaría ~160. |
| Simulación | `O(λ·T)` eventos por réplica | Estado `isbits`; el peso se lleva en **enteros** (`Dq = p·n₁ − q·n₂`), no en `Float64`: el signo es lo que se mide y un acumulador flotante se equivoca justo en el cruce. |
| Réplicas | paralelas | RNG derivado de `(semilla, id)`, escritura en posición exclusiva, reducción en orden de id. |
| Certificación | `O(√(λt))` bolas + `O(λt)` de tabla | `Arblib` a 160 bits. Dos decisiones forzadas por medición: (a) la raíz de Lundberg se biseca **en bolas** hasta `10⁻⁴⁰`, porque con radio `10⁻¹³` la evaluación por intervalos de la gamma incompleta amplificaba el radio ~4 000× y `L(t)` salía con radio `10⁻⁸`; (b) la Poisson se **tabula por recurrencia** y se acumula sin restas, porque `hypgeom_gamma_lower` regularizada devuelve `[±8,8·10¹¹¹]` con `μ=600`, `m=844`. La segunda bajó la certificación de 302 s a 0,1 s. |

Presupuesto declarado en `CONTRATO.md` §3: 2 hilos, 4 GiB, 3 h. El instrumento no se acerca a
ninguno de los tres; la parte cara es el Monte Carlo de absorción, acotado por un tope explícito de
eventos (`--tope-eventos`), y lo que no cabe se declara **censurado**, no «no ocurre».
