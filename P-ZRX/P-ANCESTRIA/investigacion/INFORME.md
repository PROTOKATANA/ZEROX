# INFORME — P-ANCESTRIA / ANR-v0.1

**No existe un `d` útil distinto del que ya está implementado.** El reto de ZEROX no está anclado a
`d = ∞`: `C-FLU-03` corta la vista de época en `T_j + L_slots`, así que el flujo **sí** separa toda
divergencia anterior a ese corte y el diseño de hoy es un anclaje a profundidad **finita**, medida en
*slots* y acotada por `I_slots + L_slots` (§F5, *derivado de las reglas vigentes*). Cualquier `d`
menor cambia umbral por ventana de reutilización según un tipo de cambio exacto (§F4), y `d = 0`
devuelve el **26,8941 %** ya descartado. El continuo existe; ZEROX ya está dentro de él.

**Categoría** (`LINEO.md` §1): `consenso` (dominante) — el objeto es una regla de anclaje del reto de
consenso; `seguridad` (secundaria), por el umbral bajo grinding.

**Instrumento**: `P-ZRX/P-ANCESTRIA/investigacion/veritas/consenso/ancestria-reto-v1/`.
Suite **53/53** con `--check-bounds=yes`; `run.jl --todo` **TODO OK** (12 artefactos en `resultados/`).

---

## F1 · P4 formalizada, y el contraejemplo la viola

### F1.0 · Notación

`H` es una **historia** (un prefijo de DAG válido). `π` es un **certificado**: la evidencia de
recurso que acompaña al bloque (solución PoAS + justificación PoT, `C-HDR-07`). `V(π, H) ∈ {0,1}` es
el predicado de validez. `cost(π) ∈ [0,∞]` es el recurso esperado (espacio × tiempo) para producir
`π`. `R* := inf{ cost(π) : ∃H, V(π, H) = 1 }`.

Las tres propiedades del teorema D5 (`veritas/consenso/poda-post-v1/INFORME.md:19`), *verificadas en
fuente*:
**P1** comprobable sin el DAG; **P2** ligado a recurso; **P3** ligado a la ancestría.

### F1.1 · Enunciado de P4

> **P4 (el recurso se paga de nuevo por cada ancestría).** Para todo algoritmo `A`, todo `k ≥ 1` y
> toda `k`-tupla de historias admisibles `H₁,…,H_k` dos a dos distintas, si `A` emite
> `(π₁,…,π_k)` con `V(π_i, H_i) = 1` para todo `i`, entonces el recurso esperado consumido por `A`
> es `≥ k · R* · (1 − o(1))`, con el `o(1)` sobre `k`.

Dicho sin fórmulas: **ningún preprocesamiento ni transferencia amortiza el recurso entre ancestrías
distintas.** El coste del `i`-ésimo certificado no puede pagarse con el del `j`-ésimo.

### F1.2 · PoW la cumple (*demostrado*, modelo de oráculo aleatorio)

En PoW `π = n` (nonce) y `V(n, H) ⟺ H_d(H ‖ n) < T`. La ancestría `H` **entra en la entrada del
hash**. Si `V(n, H₁)` y `V(n, H₂)` con `H₁ ≠ H₂`, dos entradas distintas dan la misma imagen por
debajo de `T`: una colisión. Luego un nonce sirve para una sola ancestría, y `k` ancestrías exigen
`k` búsquedas independientes de `2^L` evaluaciones esperadas cada una. `k·R*` con `R* = 2^L`. ∎

### F1.3 · El contraejemplo «cara transferible + barata ligada» la viola (*demostrado*)

Sea `V((σ,τ), H) := V_σ(σ) ∧ V_τ(H, τ)`, con `V_σ` **independiente de `H`** (transferible) y
`cost(σ) = c_σ > 0`, `cost(τ) = c_τ > 0`. Entonces `R* = c_σ + c_τ`.

El adversario `A`: produce `σ` **una vez** (coste `c_σ`) y, para cada `H_i`, produce `τ_i`
(coste `c_τ`). Recurso total `c_σ + k·c_τ`, frente a `k·R* = k(c_σ + c_τ)`. La diferencia es
`(k−1)·c_σ > 0` para todo `k ≥ 2`. **P4 se viola para todo `k ≥ 2`.** ∎

Y este esquema satisface P1, P2 y P3 **literalmente** — es exactamente lo que dice la revisión
externa (`veritas/consenso/poda-post-v1/PROCEDENCIA.md:110-116`, *verificado en fuente*): `V_σ` es
local (P1), `σ` está ligado a recurso (P2) y `V_τ` liga a la ancestría (P3). **P4 es la propiedad que
falta, y no se sigue de las otras tres.**

### F1.4 · El diseño de hoy la viola para ancestrías del mismo flujo (*demostrado de las reglas*)

De `SPEC.md`: `reto(f, s) = blake3(aleatoriedad(f, s) ‖ LE64(s))` con
`aleatoriedad(f, s) = blake3(salida(f, s))` (**C-POT-03**, líneas 1388-1398); `flujo(B, s)` se deriva
de `past(B)` (**C-FLU-10**, líneas 1653-1673); el paso 5 de **C-POT-08** (línea 1507) verifica la
solución PoAS **contra `reto` del slot** con el flujo del contexto; **C-POT-07** (línea 1478) indexa
la caché por `(f, s, semilla(f,s), N(s))`.

Luego el predicado que debe satisfacer la solución PoAS depende **sólo** del par `(f, s)`. Si
`slot(B₁) = slot(B₂) = s` y `flujo(B₁, s) = flujo(B₂, s)`, entonces `reto` coincide y **una misma
solución verifica en los dos bloques**: un solo gasto sirve a dos ancestrías. `π` es transferible
dentro de la clase `{(B, s) : flujo(B, s) = f}`. ∎

Ésta es precisamente la separación que el encargo describe (`PROMPT.md:69-71`): en PoW el hash
compromete a los padres **y** es el recurso; aquí la solución no depende de los padres y el sello
Ed25519 no es único (`C-HDR-04`, línea 992-1000, y su regresión
`crates/zx-core/tests/ed25519_no_unicidad.rs`). La revisión dejó escrito que el instrumento de
`poda-post-v1` **no modelaba** esto (`PROCEDENCIA.md:117-119`). Aquí se modela.

### F1.5 · Cuánto dura esa transferibilidad

**No es ilimitada.** La clase de transferencia está acotada por la regla de flujo: dos ancestrías
comparten `f` mientras compartan las inyecciones activadas, y eso se acaba en el primer corte de
vista que las separe (§F5). **P4 se cumple a partir de esa profundidad y se viola por debajo.** Ése
es el puente exacto entre F1 y F5, y es lo que convierte el encargo en una pregunta cuantitativa.

---

## F2 · `umbral(d)`, con el control `d = 0` → 27 %

### F2.1 · El modelo, y por qué es éste

Fuente primaria: **BDK+19**, *Proof-of-Stake Longest Chain Protocols: Security vs Predictability*,
arXiv 1910.02218v3, §5.4 y Anexo F (`research/fuentes/bdk19.txt`, leído íntegro en lo pertinente).
Allí `c` es *el número de niveles del árbol privado del atacante entre actualizaciones de la
aleatoriedad*: `RandSource(b)` sólo cambia si `depth(b) % c == 0` (Anexo F), y el **Lemma 13** dice que
la estrategia óptima es bifurcar en los padres de los bloques *godfather*. La ecuación (39) es

```text
Λ_c(t) = −log(−t) − (c−1)·log(1−t)          (λ = 1)
Λ_c(t) = t · Λ'_c(t)                         (39)   →  raíz negativa única t*
φ_c    = −c·t* / ( log(−t*) + (c−1)·log(1−t*) )  =  c·t* / Λ_c(t*)
umbral = 1/(1 + φ_c)                         (Δ = 0)
```

`φ_c·λ_a` es la tasa de crecimiento del árbol privado y el umbral es el máximo de fracción
adversarial tolerada. **BDK+19 tabula `φ₁ = e` y `φ_∞ = 1`.**

### F2.2 · La reducción `d ⟷ c = d + 1`

Con el reto anclado a `σ(B)`, el ancestro a `c = d + 1` niveles:

- `d = 0` ⟹ `σ(B) = sp(B)` ⟹ la aleatoriedad cambia en **cada** bloque ⟹ `c = 1`.
- `d → ∞` ⟹ la aleatoriedad es la del flujo, constante dentro de la época ⟹ `c → ∞`.

Lema de ventana (*demostrado*, `referencia.jl:ventana_exhaustiva`): dos ramas con ancestro común a
profundidad `m` comparten `σ` en un bloque de profundidad `n` **si y sólo si** `n − c ≤ m`. Por tanto
la aleatoriedad se refresca cada `c = d + 1` niveles del árbol privado — que es exactamente la
definición de `c` en BDK+19. **H1 del `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`: la equivalencia es
*derivada*, y la regla literal (reto dependiente de ancla **y** slot) da aleatoriedad fresca
adicional, de modo que `umbral(d)` es una **cota superior de la seguridad**, no un valor exacto.**

### F2.3 · CONTROL OBLIGATORIO: `d = 0` devuelve el 27 %

```
$ ./veritas/julia.sh --project=$D $D/run.jl --control
d = 0  ->  c = 1  ->  phi_1 = 2.718281828459045   (e = 2.718281828459045)
umbral(0) en [0.268941421369995104, 0.268941421369995104]
1/(1+e)      = 0.268941421369995104   -> 26.8941 %
theta*(1) = -e y phi_1 = e exactos (sustitucion simbolica): true
CONTROL: umbral(0) == 1/(1+e)  ->  OK (27 %)
```

`θ* = −e` se comprueba **simbólicamente**, sin solver: con `c = 1`, (39) es `−log(−t) = −1`, i.e.
`−t = e`; sustituyendo, `−1 = −1`, y `φ₁ = −1·(−e)/log(e) = e`. *Demostrado*.
El control **pasa**: el instrumento no está mal y se puede seguir.

### F2.4 · `umbral(d)` (aritmética certificada)

`recinto_theta` encierra `t*` con redondeo dirigido y **signo certificado** contra la cota de error
de MPFR; anchura `2^-(prec−40)`. Artefacto: `resultados/run-tabla-umbral-d.txt`.

| `d` | `c = d+1` | `φ_c` | **`umbral(d)`** | ventana de reutilización |
|---:|---:|---:|---:|---:|
| **0** | 1 | 2,718282 | **0,268941 (26,89 %)** | 1 bloque |
| 1 | 2 | 2,225473 | 0,310032 | 2 |
| 2 | 3 | 2,010300 | 0,332193 | 3 |
| 4 | 5 | 1,795447 | 0,357725 | 5 |
| 9 | 10 | 1,578609 | 0,387806 | 10 |
| 24 | 25 | 1,383017 | 0,419636 | 25 |
| 49 | 50 | 1,281528 | 0,438303 | 50 |
| 99 | 100 | 1,207390 | 0,453024 | 100 |
| 249 | 250 | 1,138689 | 0,467576 | 250 |
| 499 | 500 | 1,102316 | 0,475666 | 500 |
| 999 | 1 000 | 1,075447 | 0,481824 | 1 000 |
| 1 999 | 2 000 | 1,055584 | 0,486480 | 2 000 |
| 4 999 | 5 000 | 1,037045 | 0,490907 | 5 000 |
| 19 999 | 20 000 | 1,019954 | 0,495061 | 20 000 |
| ∞ | ∞ | 1 | **0,500000** | **no acotada** |

`φ_c` es estrictamente decreciente y `umbral(d)` estrictamente creciente; `φ_{10⁷} = 1,0011606621 > 1`
(*demostrado numéricamente con certificación*: `resultados/run-monotonia.txt`). **Ningún `c` finito
alcanza `1/2`.**

### F2.5 · Validación (ninguna es la fórmula contra sí misma)

| Comprobación | Ruta | Resultado |
|---|---|---|
| Tabla 3 de BDK+19, `c = 1..10` | fuente externa | discrepancia máx. **8,5·10⁻⁶** |
| `φ₁₆, φ₅₀, φ₁₀₀, φ₂₅₀, φ₅₀₀, φ₁₀₀₀, φ₂₀₀₀` citados en el repositorio | fuente externa | discrepancia máx. **4,7·10⁻⁵** (redondeo a 4 cifras) |
| O1: `sup_t Λ_c(t)/t` por sección áurea | ruta numérica **distinta** | coincidencia **0,00·10⁰** en 8 valores de `c` |
| O2: `Σ_{j≥c} q^j + cola = q^c/(1−q)` | `Rational{BigInt}` **exacto** | OK |
| O2: `Λ_c(t) = log(Σ_{j≥c} (1/(1−t))^j)` | `BigFloat` | OK, `c` hasta 1 000 |
| O3: `θ*(1) = −e`, `φ₁ = e` | sustitución **simbólica** | OK |
| O4: lema de ventana | enumeración **exhaustiva** | OK, `c ∈ {1,2,3,5}`, 50 niveles |
| kernel `Float64` ↔ referencia `BigFloat` | equivalencia | peor relativa **5,0·10⁻¹⁵** |

Un control de cordura adicional que **no** vale como prueba y se declara como tal
(`resultados/run-oraculo-brw.txt`): la simulación por haz del árbol `T'` da `S*_k/k > c/φ_c` en la
dirección que predice el truncamiento (el haz corta un árbol infinito y `k` es finito), con sesgo
que decrece al crecer `c` (+0,564 / +0,326 / +0,243). **Etiqueta: estimado; no certifica la tasa.**

---

## F3 · `cobertura(d)`

### F3.1 · Definición exacta

`ventana_reuso(d) := c = d + 1` bloques (lema de ventana, *demostrado*). Para una rama privada de
longitud `L` bloques contada desde el ancestro común (`L` es **entrada**, no constante):

```text
bloques_compartidos(d, L) = min(L, d+1)          reto compartido con la rama pública
bloques_separados(d, L)   = L − min(L, d+1)      reto propio
cobertura(d, L)           = bloques_separados / L
```

### F3.2 · Qué conducta separa cada profundidad

| Conducta | ¿La separa `d`? | Fórmula |
|---|---|---|
| **B1 doble farmeo en rama privada** | sí, fuera de la ventana | `1 − min(L, d+1)/L` |
| **B2 transferencia del certificado a otra historia** | sí, fuera de la ventana | `1 − min(L, d+1)/L` (misma clase `{B : σ(B) = X}`) |
| **B3 niveles de poda** | sí para todo `d` finito | 1 si `d < ∞`; **0 si `d = ∞`** (sin ancla, el nivel no depende de la ancestría: el fallo P3 de D5) |

`resultados/run-cobertura.txt`, con `L = 1 000`:

| `d` | `c = d+1` | compartidos | separados | `cobertura` |
|---:|---:|---:|---:|---:|
| 0 | 1 | 1 | 999 | 0,999 |
| 9 | 10 | 10 | 990 | 0,990 |
| 49 | 50 | 50 | 950 | 0,950 |
| 249 | 250 | 250 | 750 | 0,750 |
| 499 | 500 | 500 | 500 | 0,500 |
| 999 | 1 000 | 1 000 | 0 | **0,000** |
| ∞ | ∞ | 1 000 | 0 | **0,000** |

### F3.3 · Advertencia de lectura

`cobertura(d, L)` **no** es una probabilidad de seguridad: es una cuenta de bloques. Un atacante
elige `L` y por tanto la fracción; lo que **no** elige es la ventana absoluta `c = d + 1`, que es la
magnitud que decide (§F4). Presentar `cobertura(d, L → ∞) = 1` como «P4 restaurada» sería el error
que el encargo prohíbe (`PROMPT.md:263`). **La cobertura no es un cierre.**

---

## F4 · ¿Existe un `d` útil? — **No, y la demostración es el tipo de cambio**

### F4.1 · La dualidad

**`c = d + 1` es simultáneamente la ventana de reutilización de F3 y el parámetro de correlación de
F2.** No son dos palancas: son la misma. Todo lo que compra umbral compra transferabilidad.

### F4.2 · Demostración

1. `umbral(d) = 1/(1 + φ_{d+1})` y `φ_c > 1` **estrictamente** para todo `c` finito, con `φ_c ↓ 1`
   (*demostrado*: monotonía verificada en `c = 1..400`; `φ_{10⁷} − 1 = 1,16·10⁻³ > 0`).
   Por tanto **`umbral(d) < 1/2` estrictamente para todo `d` finito.** Ningún `d` finito iguala el
   umbral del diseño de hoy.
2. La ventana de reutilización es exactamente `d + 1` bloques. Por tanto la frontera de Pareto es
   `{ (1/(1+φ_{d+1}), d+1) : d ≥ 0 }`: una curva uniparamétrica, sin grados de libertad sobrantes.
3. El tipo de cambio, calculado con el instrumento (`resultados/run-tipo-cambio.txt`):

| umbral objetivo | `c = d+1` mínimo | `d` mínimo | ventana de reutilización | `φ_c` |
|---:|---:|---:|---:|---:|
| 0,30 | 2 | 1 | 2 bloques | 2,225473 |
| 0,35 | 5 | 4 | 5 | 1,795447 |
| 0,40 | 14 | 13 | 14 | 1,496813 |
| 0,45 | 86 | 85 | 86 | 1,221622 |
| 0,48 | 798 | 797 | 798 | 1,083320 |
| 0,49 | 4 019 | 4 018 | 4 019 | 1,040815 |
| 0,495 | 19 457 | 19 456 | 19 457 | 1,020202 |
| 0,5 | — | — | **no alcanzable con `c` finito** | — |

Recuperar **medio punto** de umbral (0,495 frente a 1/2) cuesta una ventana de **19 457 bloques**.
El extremo `d = 0`, el único sin ventana, da el **26,8941 %** ya descartado por `PROMPT.md:102-110`.

4. **Y el diseño de hoy ya es un punto interior**, no el extremo `d = ∞` (§F5): su ventana de
   reutilización es finita (§F5.2). Por tanto cualquier `d` menor **cambia** umbral por ventana sobre
   lo que ya hay, y cualquier `d` mayor no compra umbral medible.

**Conclusión.** No hay un `d` que dé a la vez un umbral aceptable y una separación no trivial **que
mejore lo existente**: los dos requisitos piden extremos opuestos del mismo parámetro, y el punto que
el protocolo ya ocupa es el que maximiza el umbral. Se cierra la puerta **por escrito**, con el tipo
de cambio publicado.

### F4.3 · Contraste con el teorema de §1.1 del encargo

`research/dag-poas-balizas-auditoria.md:30-38,66-78` (*verificado en fuente*): cualquier regla «una
identidad-X publica bajo un solo reloj» es derrotable partiendo el espacio, porque el ploteo es
lineal en bytes e independiente del número de identidades y las identidades son gratis. **El anclaje
a profundidad `d` no es una regla de exclusividad por identidad**, así que el teorema no lo alcanza:
aquí no se pide a nadie que renuncie a cubrir dos ramas, se hace que **cubrirlas cueste recurso
nuevo** fuera de la ventana. Lo que el teorema sí impide es la vía que el encargo descarta de
antemano: cobrar el anclaje con un recurso ajeno al espacio (depósito o tasa por identidad) — eso es
PoS, rechazado al elegir PoST. **La propuesta no es de exclusividad y no reintroduce identidades.**

---

## F5 · La vía del flujo

### F5.1 · Qué separa hoy el identificador de flujo, y a qué granularidad

*Verificado en fuente* (`SPEC.md` §7.1.3-§7.1.5):
`V_j(B) := (past(B) ∪ {B}) ∩ {X : slot(X) < T_j + L_slots}` (**C-FLU-03**, línea 1568);
`I_j(B)` = primer bloque de `Chn(V_j(B))` con `slot ≥ T_j` (**C-FLU-04**, línea 1576);
`entropía_j(B) = blake3(chunk(I_j) ‖ pot_output(I_j))` (**C-FLU-12**, línea 1688);
`flujo(B,s) = H_flujo(flujo(B, t_j−1) ‖ entropía_j(B) ‖ LE64(t_j))` (**C-FLU-10**, línea 1657);
la inyección ya activada **se hereda, no se recalcula** (**C-FLU-21**, línea 1775).

Granularidad: el flujo es un identificador de **32 bytes acumulativo** que cambia en cada inyección;
los ingredientes son **dos campos de cabecera por ancla** más sus slots (así lo dice el comentario de
`C-FLU-14`, líneas 1751-1754).

### F5.2 · ¿Puede una rama privada permanecer en el mismo flujo que la pública? — **Sí, y de forma acotada**

Sean dos ramas con ancestro común último a `s_x`. Su diferencia simétrica son bloques con
`slot > s_x`, luego:

```text
T_j + L_slots ≤ s_x  ⟹  V_j idéntico  ⟹  I_j, entropía_j y t_j idénticos
```

Sea `j* = min{ j : T_j + L_slots > s_x }`. Las inyecciones `j < j*` son idénticas en las dos ramas;
la `j*` puede diferir. Su activación es
`t_{j*} = slot(I_{j*}) + L_slots ∈ [T_{j*} + L_slots, T_{j*} + 2·L_slots)`, y como `j*` es el primer
cruce, `T_{j*} ≤ s_x − L_slots + I_slots`. Por tanto

```text
t_{j*} − s_x  ∈  (0,  I_slots + L_slots]        ventana de reto compartido, EN SLOTS
```

**Demostrado de las reglas vigentes.** Consecuencia: el flujo **sí** separa, y separa toda divergencia
anterior al corte de vista; lo que ocurre es que la separación llega **tarde**, una vez cruzado el
umbral de época. Por eso el encargo acierta al decir que «la rama privada y el doble farmeo ocurren
dentro de un flujo», y se equivoca al concluir de ahí que el flujo no da P4: **lo da, a esa
profundidad.**

### F5.3 · ¿Da o no da P4 el identificador de flujo?

**Lo da a una profundidad de `≤ I_slots + L_slots` slots, y no por debajo.** Dos ancestrías que
difieren sólo en bloques posteriores a esa profundidad comparten `f` y por tanto comparten `reto`
(§F1.4): la transferibilidad **está acotada**. Por tanto:

- **El diseño de hoy no es `d = ∞`**: es un anclaje a profundidad finita **medida en slots**, que en
  bloques vale `d* ≈ (I_slots + L_slots)·λ_cadena`. Con `L_slots ≥ F_slots` y `F` en horas, `d*` es
  del orden de **miles de bloques** a `q = 1`: ahí `φ_{d*} ≈ 1` y `umbral ≈ 1/2`, que es lo que el
  repositorio observa como «cero grinding».
- **No hace falta un eje nuevo de anclaje por profundidad**: el eje ya existe y es `I_slots` y
  `L_slots`. Es la misma pieza, medida en tiempo y no en bloques.
- **`I_slots` y `L_slots` son símbolos** (`C-FLU-01`, líneas 1530-1533): no se fija ninguno. Lo que
  queda es la **relación**: ventana de reto compartido `≤ I_slots + L_slots` slots.

### F5.4 · ¿Sirve el ancla de inyección (`C-FLU-12`) como objeto de anclaje?

Es **el objeto que ya se usa**: `entropía_j` es el ingrediente del flujo (**C-FLU-10**) y su ancla
`I_j` es canónica por flujo (misma para todas las ramas que comparten `V_j`). Pero usar la inyección
de una época **más antigua** `I_{j−k}` como fuente del reto **no aumenta la separación**: lo que
separa ramas es el corte de vista `T_j + L_slots`, no cuál de las entropías se use. Anclar a
`I_{j−k}` hace que **más** ramas compartan el ancla (todas las que coinciden `k` épocas atrás), es
decir **menos** separación, con la misma ventana en slots. **No es una palanca nueva; es un
desplazamiento dentro de la ventana ya existente.** Y no toca `C-POT-03` (el reto sigue
dependiendo de la salida PoT del slot), pero **sí** tocaría `C-FLU-10`/`C-FLU-12`, que es donde el
ancla vive.

---

## F6 · Coste, si algo sobreviviera

La respuesta a F4 es que **no sobrevive una regla nueva**. Se reporta igualmente el coste de la
alternativa, porque es el argumento que cierra la puerta.

### F6.1 · Reglas del SPEC que habría que tocar (por ID)

| Regla | Qué cambiaría |
|---|---|
| **C-FLU-10** (línea 1653) | la definición del flujo: el ancla dejaría de ser `I_j` de la época y pasaría a ser `σ(B) = anc_d(B)` |
| **C-FLU-12** (1685) | la fuente de la entropía (`I_j(B)` → `σ(B)`) |
| **C-HDR-06** (909) | el rango esperado contextual depende del flujo: cambian las **entradas** del controlador y por tanto el retarget |
| **C-FLU-13 / C-FLU-14** (1721/1741) | la validez absoluta y el pasado consistente de flujo se enuncian sobre `flujo(·)`; la comparación sigue siendo de 32 bytes |
| **C-GD-10** (2370) | la cola de candidatos del productor: hoy descarta puntas que cambiarían inyecciones **ya activadas**; con ancla a `d`, **casi todo** conjunto de padres distinto cambiaría el reto |
| **C-FLU-20 / C-FLU-21** (1756/1775) | la herencia de la inyección activada no tiene análogo directo: el reto cambia con los padres, no con la época |
| **C-POT-03** (1388) | **no** cambia: el reto sigue dependiendo de la salida PoT del slot y del ancla |
| **§6.1** (825) | **no** se reabre: `σ(B)` es derivado de `past(B)` (**C-GD-09**, línea 2363). **Discrepo de `veritas/consenso/poda-post-v1/INFORME.md:144-147`**, que anticipa reabrir §6.1; el ejemplo que ese informe da («que el desafío dependa del hash de los padres») sí podría exigir campo, `σ(B)` no. |

### F6.2 · Disco del granjero honesto

- **Hoy**: el granjero audita su espacio **una vez por slot** contra el flujo vigente y, si gana,
  arma el bloque eligiendo padres después (`C-HDR-04` permite variar el sello; la solución no depende
  de los padres).
- **Con ancla a `d`**: el orden se invierte — **padres → `σ(B)` → reto → auditoría**. La auditoría
  pasa a estar **serializada detrás** de la elección de padres, y como `C-GD-10` deja esa elección al
  azar de una cola barajada, el productor que quiera reintentar con otro conjunto de padres paga
  **una auditoría por intento**.
- **Etiqueta: `derivado`, no medido.** No hay granja en esta máquina: no se mide la tasa real de
  sorteos/TiB ni el coste de I/O por auditoría. Lo que se afirma es el cambio de orden y su
  consecuencia cualitativa, no un número de lecturas por slot.

### F6.3 · Relé compacto

Verificado en `SPEC.md` §16.2: **C-NET-25** (línea 3181) pone en `/zerox/blocks/2` «cabecera DAG,
nonce de transporte e IDs cortos», y **C-NET-26** (3210) hace el anuncio compacto obligatorio;
**R-NET-01** (3648) anuncia «cabecera e identificadores cortos». La cabecera **incluye los padres**
(`C-HDR-01`/`C-HDR-03`), así que **el anuncio ya se emite con los padres fijados** y ninguna de esas
reglas anuncia el billete antes de conocerlos. **Corrijo la premisa del encargo
(`PROMPT.md:193-194`)**: lo que el ancla a `d` rompe no es el anuncio del relé, es la **capacidad de
calcular el billete antes de fijar los padres** — y eso es pipeline del productor (§F6.2), no el
relé. Si existiera una optimización que anunciara el billete por separado, sí se rompería; no la
encontré en §16.2.

### F6.4 · ¿De qué lado de la validez absoluta cae? — **Del lado absoluto**

`σ(B)` es función exclusiva de `past(B)` (**C-GD-09**), igual que lo es `flujo(B,·)` (**C-FLU-10**) y
como exige `C-FLU-13` (líneas 1721-1727): la validez **MUST NOT** depender de la cadena seleccionada
del observador, de su punta, de su reloj ni del orden de llegada. Anclar el reto a `σ(B)` **no**
introduce validez relativa y **no** reabre el multistream. Que el productor pueda elegir padres para
moler el reto **no** es circularidad prohibida por `C-POT-06`: la circularidad prohibida es aceptar
del candidato el valor que el verificador debe derivar, y aquí el verificador deriva `σ(B)` de
`past(B)`. **Etiqueta: derivado de reglas; es la restricción dura del encargo y se respeta.**

---

## Contraste con la cota de §1.2 (los 27 %)

`research/dag-poas-ancla-de-finalidad.md:313-319` (*verificado en fuente*) descarta los «trunks por
bloque» con `c = 1` y `φ₁ = e`, umbral 27 %, y fija ahí la cota a batir. **Este informe no la bate
por ningún `d` finito**: reproduce el 26,8941 % como control y demuestra que el umbral sube
**monótonamente** hacia `1/2` al crecer `d`, pagando ventana de reutilización. Ninguna propuesta de
este informe supera el 50 % — que es el valor del diseño vigente — ni se presenta como superación.
`research/dag-poas-ancla-de-finalidad-metaauditoria.md:309` (*verificado en fuente*) confirma que el
abstract de BDK+19 dice `1/(1+e)` y que `φ₁ = e` es correcto: coincide con el control de §F2.3.

---

## Tabla de rendimiento (formato LINEO §6)

`uptime` antes de medir: `23:06:23  up 14 days 19:35, carga 2,01 1,70 1,39`. `julia 1.13.0`, 1 hilo,
`znver5`, sin BLAS. Artefacto: `resultados/BENCH.txt`.

| Variante | Tiempo mediano | Asignaciones | Memoria | Hilos | Resultado frente a referencia |
|---|---:|---:|---:|---|---|
| Oráculo O1 (`phi_por_maximo`, ruta independiente) | 7 438 µs | 30 744 | — | 1 CPU | fuente de verdad en `c` muestreado |
| Referencia certificada (`umbral_c_medio`, `BigFloat` 384 bits) | 2 973 µs | 25 053 | 1,33 MB | 1 CPU | = O1, = Tabla 3 |
| Kernel `Float64` (`phi_c_f64`) | 4,4 µs | **0** | **0 B** | 1 CPU | igual a la referencia, peor rel. 5,0·10⁻¹⁵ |
| Simulación BRW (`brw_minimo`, c=2, k=5) | 2,68 ms | — | — | 1 CPU | cota superior monótona (estimado) |

No se publica «X veces más rápido»: hay tamaño, trabajo, semilla (`0x5a5a5a5a`), métrica y resultado
comprobado. **No se paraleliza**: con las tablas completas por debajo del minuto, el perfil no
justifica hilos y el encargo impone un tope de 4. Corridas con `Threads.nthreads() = 1`.

---

## Límites declarados

- **`umbral(d)` es una cota superior de la seguridad**, no el valor exacto, bajo la regla literal:
  ver H1 y H5 en `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`.
- **`umbral` se publica con `Δ = 0`** porque `Δ` y `λ_h` son símbolos en el SPEC (§7.3). La forma con
  retardo (`umbral_c_retardo`) está implementada y sin usar.
- **No se fija ningún parámetro**: `d`, `c`, `I_slots`, `L_slots`, `F_slots`, `k`, `P`, `λ` son
  entradas. La ventana de F5 va como **cota**, no como valor.
- **La F5 es lectura de reglas, no medición**: `Δ` está simulada en el repositorio, no medida en red
  (`P-ZRX/P-2.1/SINTESIS.md:26-28`), y `Dmax` sigue sin medir.
- **El coste de F6.2 es cualitativo**: no hay granja en esta máquina, no se mide I/O por auditoría.
- **Todo es del diseño vigente**: si `C-FLU-03`/`C-FLU-10`/`C-FLU-21` cambian, la ventana de F5
  cambia con ellos.

---

## Lo que esta investigación NO resuelve

- **No demuestra P4 para el protocolo**: demuestra que P4 es la propiedad que falta (F1), que el
  diseño de hoy la cumple **a partir de la profundidad de F5** y no por debajo, y que ninguna regla
  nueva de anclaje la mejora. La parte «y no por debajo» es una **cota de modelo**, no un teorema
  sobre la red.
- **No mide** la ventana de F5 en una red real, ni el coste de I/O del productor bajo un ancla de
  profundidad `d`, ni la tasa real de sorteos por TiB.
- **No decide** si la ventana `≤ I_slots + L_slots` es suficientemente corta: eso depende de `Δ` real
  y de la tolerancia a particiones, y `Δ` no está medida. Es una **decisión para Katana**, no un
  resultado.
- **No modela** el PoT como flujos independientes: usa el flujo como objeto único, y el propio
  repositorio advierte que eso deja fuera la ramificación del PoT en los puntos de inyección
  (`veritas/consenso/poda-post-v1/PROCEDENCIA.md:117-119`).
- **No cierra** la laguna de `poda-post-v1/PROCEDENCIA.md:82-107` sobre la población de bloques
  (D1/D2/D6): no la toca y no depende de ella.
- **No valida** el ancla a profundidad `d` contra el grinding público que BDK no modela (elegir el
  inyector de la cadena pública), que la ronda 4 de la investigación dejó abierto
  (`research/dag-poas-voto-auditoria.md:179`, citado desde `research/dag-poas-candidatos-auditoria.md:173`).
- **No propone** ninguna regla para el SPEC. No se fija `d` ni se recomienda adoptarlo.
