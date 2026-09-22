# INFORME — PCO-v0.1 · ¿Se sostiene sola una partición de flujo de PoT?

**No entre los nodos que ya estaban: la letra de R-FIN-7 los congela a todos a la vez en `t_j + F` y
la partición se resuelve a la fuerza. Se sostiene por dos rendijas, y las dos son permanentes** — el
**desfase de vista** en ese único instante, `arcsin(√(τ/F))/π`, que vale **2,6 %** con `F = 600 s` y
`τ = 4 s`; y **todo el que sincronice después**, que toma el líder del momento y ya no puede
cambiar, con probabilidad `L(F)`, que **con deriva nula vale 1**. Sin adopción sigue siendo
permanente por construcción. **Y la variable que decide sigue siendo `(1−c)·(s₁−s₂)`, no `c`**: con
`s₁ = s₂` la deriva es exactamente cero para cualquier `c`, incluido `c = 0`, y los dos canales se
quedan en su peor valor.

> ⚠️ **Corregido el 2026-09-19 tras una objeción del validador, que era correcta.** La primera
> versión de este informe definía la absorción como «`F` desde que el nodo adoptó» y publicaba
> `P(bloqueo divergente) = 0,6828`. R-FIN-7 no dice eso: acota la **profundidad** de la
> reorganización, y con R-FIN-3 + R-FIN-5 la bifurcación entre flujos se queda clavada en `t_j`, así
> que **todos los nodos cruzan el umbral a la vez**. El detalle está en `PROGRESO.md` y en
> `MODELO.md` §2.3; qué medía realmente el `0,6828`, en §2.3 de aquí.

**Categoría:** `consenso` (LINEO §1). Es una regla de selección (`blue_work`, R-FIN-4/5/7/13′) y la
dinámica del líder entre flujos. Secundarios: `economía` (§3) y `almacenamiento` (§3, IOPS/TiB).

---

## 0 · Veredicto por entregable

| # | Pregunta del encargo | Respuesta | Etiqueta |
|---|---|---|---|
| 1 | ¿La tasa de peso de un flujo es `∝ W_i`? | **Sí, y el `SR` se cancela en todo instante, no solo en régimen** — con dos residuos exactos: el suelo (`< 2⁻⁶⁴`) y **la paridad de `SR`** (`1/(SR+1)`, hasta `4,88·10⁻⁴`). Lo que **no** se cancela es la fracción azul. | **DEMOSTRADO** en enteros exactos (paridad, suelo); **no demostrado** para `β` (modelo H-BETA) |
| 2a | Sin adopción | **Partición permanente por construcción.** | **DEMOSTRADO** por la letra de R-FIN-5 + R-FIN-7 |
| 2b | Con adopción | Deriva `∝ (1−c)(s₁−s₂)`. `L(t)` y `t(ε)` como funciones, certificadas con Arb. | **DEMOSTRADO** (fórmulas), **MEDIDO** (Monte Carlo) |
| 2c | ¿Dos nodos en flujos distintos? | **Todos se congelan a la vez en `t_j+F`.** Con vista común, **cero**. Con desfase `τ`: `P(sign D(F−τ) ≠ sign D(F))`, exacta, `→ arcsin(√(τ/F))/π`. Para quien llega después: `L(F)`. | **DEMOSTRADO** (fórmula, contra oráculo `BigFloat` y MC); la lectura de R-FIN-7 es **demostrada por su letra**, no por su intención |
| 3 | ¿Cuánta cobertura hay en equilibrio? | `c → 1` exige **dos** cosas: `p_j > ρ_var` y que **toda** granja supere `x* = ρ_fij/(p_j−ρ_var)`. La segunda no se cumple genéricamente: el coste fijo por flujo abierto no es cero. | **DEMOSTRADO** (condición); **estimado** (`c` numérico, depende de H-TAMANOS) |
| 4 | El contraste histórico | Con `c = 1` este modelo **reproduce** la ronda 3: `P(cambio tras 600 s) = 0,792` frente a `0,82`. La cifra histórica es la ley del arcoseno, y su horizonte —no declarado— es lo único que la fija. | **MEDIDO**; la reconstrucción del modelo de la ronda 3 es **no demostrada** |

---

## 1 · El modelo de peso — demostrado, y corregido en un punto

### 1.1 · La cancelación es exacta, y no depende del retarget

`SR` entra como `A(SR)` en la tasa de bloques y como `1/(SR+1)` en el peso. **Se cancela en todo
instante**: con el retarget convergido o sin converger, con clamp o sin él, con cualquier ventana y
cualquier redondeo. **No existe transitorio de retarget en la media de la tasa de peso.** El encargo
pedía comprobar la cancelación «en régimen, en el transitorio y con los suelos enteros»: la respuesta
es que los tres son el mismo caso, porque `SR` es la misma variable en los dos factores.

Lo que queda es exacto y está en `resultados/peso.csv`, calculado en `Rational{BigInt}`:

| `SR` | paridad | desviación exacta de `tasa/(P·2^64)` | `1/(SR+1)` |
|---:|---|---:|---:|
| 6 148 914 690 | par | `−6,96·10⁻³⁰` | 1,63·10⁻¹⁰ |
| 6 148 914 691 | **impar** | **`−1,6263·10⁻¹⁰`** | 1,6263·10⁻¹⁰ |
| 6 148 914 | par | `−1,48·10⁻³²` | 1,63·10⁻⁷ |
| 6 148 915 | **impar** | **`−1,6263·10⁻⁷`** | 1,6263·10⁻⁷ |
| 2 048 (`SR_MIN` barajado) | par | `−5,65·10⁻³⁶` | 4,88·10⁻⁴ |
| 2 049 | **impar** | **`−4,878·10⁻⁴`** | 4,878·10⁻⁴ |

**Hallazgo.** El predicado de aceptación es `bidirectional_distance ≤ SR ÷ 2` sobre un círculo de
`2^64` (`subspace-verification/src/lib.rs:150-158`, `subspace-core-primitives/src/solutions.rs:332-337`),
luego acepta `2⌊SR/2⌋+1` valores: **`SR+1` si `SR` es par y `SR` si es impar**. `C-GD-01`
(`SPEC.md:1669`) divide siempre por `SR+1`. Con `SR` impar queda un déficit de exactamente
`1/(SR+1)`, y **crece al crecer la red**, porque `SR` decrece con el espacio.

Y es **elegible**, que es lo peor: `A(2m) = A(2m+1)`, así que para la misma tasa de bloques hay dos
`SR` —uno par y uno impar— con **pesos distintos**. Cuál devuelve el retarget depende hoy de un
redondeo sin justificación de consenso. Palanca P1 de `PROPUESTA.md`; corrección de una línea.

**Entre dos flujos** el déficit se cancela si los dos `SR` tienen la misma paridad y **no** si
difieren (`resultados/peso-sesgo.csv`, `10^12` piezas, `c = 0,9`, `s₁ = 0,6`):

| paridad (`SR₁`, `SR₂`) | sesgo de `R₁/R₂` frente a `W₁/W₂` |
|---|---:|
| par, par | `1,06·10⁻³²` |
| impar, impar | `−1,08·10⁻⁹` |
| **par, impar** | **`+5,10·10⁻⁸`** |
| **impar, par** | **`−5,20·10⁻⁸`** |

**Etiqueta:** DEMOSTRADO, en enteros exactos, **bajo la condición** de que el predicado de
aceptación sea el de Autonomys leído arriba. Si ZEROX cambia el predicado, cambia el resultado.

### 1.2 · Lo que no se cancela: la fracción azul

`blue_work` suma solo azules, así que `R_i = β_i·W_i·2^64·razón(SR_i)`, y `R_i ∝ W_i` **si y solo
si `β₁ = β₂`**.

- **En régimen**, R-FIN-13′ (`SPEC.md:1289-1291`) fija la misma tasa en los dos flujos ⟹ `β₁ = β₂`
  ⟹ **`∝ W_i` exacto**.
- **En el transitorio**, `ν_i = W_i·ν₀` difiere, y `β` decrece con la tasa: **el flujo minoritario
  tiene más fracción azul**. El transitorio **estabiliza la partición**.

Magnitud del sesgo por `β` (`resultados/peso-beta.csv`, `ν₀ = 1`):

| `Δ`, `k` | `c = 0`, `s₁ = 0,6` | `c = 0,5`, `s₁ = 0,6` | `c = 0,9`, `s₁ = 0,6` |
|---|---:|---:|---:|
| 4 s, k = 30 (rejilla del SPEC) | `−1,7·10⁻¹⁵` | `−2,4·10⁻¹²` | `−8,1·10⁻¹¹` |
| 16 s, k = 18 | **`−51,9 %`** | **`−64,1 %`** | **`−24,8 %`** |

**Etiqueta:** con `k` holgado frente a `2νΔ`, `∝ W_i` vale con error `< 10⁻¹⁰` — pero eso es
**casi tautológico** bajo H-BETA y está declarado como tal. Con `Δ = 16 s` y `k = 18`, `∝ W_i` es
sencillamente **falso**, y el error favorece al minoritario. **No demostrado** fuera de H-BETA.

---

## 2 · Los dos regímenes

### 2.1 · Sin adopción — permanente por construcción

R-FIN-5 exige `flujo(X,slot(X)) = flujo(B,slot(X))` para todo `X ∈ past(B)`, con comprobación
**estructural antes de tocar el PoT**: *«un nodo honesto jamás verifica el PoT de un flujo ajeno»*
(`research/dag-poas-ancla-de-orden.md:223-225`). R-FIN-7 prohíbe reorganizar por debajo de `F`
(`:301-303`). Si nadie verifica ni adopta la rama rival, **no hay ningún mecanismo que pueda unir
los dos flujos**, haya cobertura o no, haya deriva o no.

**Etiqueta: DEMOSTRADO** por la letra de las dos reglas. No se simula porque no hay nada estocástico
que medir. **Condición:** que R-FIN-5 y R-FIN-7 se apliquen literalmente y no haya ningún otro
mecanismo de adopción en el diseño.

### 2.2 · Con adopción — `L(t)` y `t(ε)`

Deriva `= λ·(W₁−W₂)/W₂ ∝ (1−c)(s₁−s₂)`. Extracto de `resultados/dinamica.csv` (régimen, `λ = 1`,
tiempos en slots):

| `c` | `s₁` | deriva | `I` | `t(10⁻³)` | `t(10⁻⁹)` | `L(600)` | `L(11 520)` |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 0 | 0,50 | 0 | 0 | **∞** | **∞** | **1** | **1** |
| 0 | 0,60 | 0,500 | 3,99·10⁻² | 136 | 468 | 4,63·10⁻¹² | 9,06·10⁻²⁰² |
| 0,5 | 0,55 | 6,90·10⁻² | 1,11·10⁻³ | 4 873 | 16 798 | 0,248 | 4,21·10⁻⁷ |
| 0,5 | 0,60 | 0,143 | 4,44·10⁻³ | 1 219 | 4 201 | 2,10·10⁻² | 4,63·10⁻²⁴ |
| 0,75 | 0,55 | 2,90·10⁻² | 2,04·10⁻⁴ | 26 528 | 91 448 | 0,621 | 3,01·10⁻² |
| 0,9 | 0,55 | 1,06·10⁻² | 2,77·10⁻⁵ | 195 438 | 673 716 | 0,855 | 0,424 |
| 0,9 | 0,60 | 2,13·10⁻² | 1,11·10⁻⁴ | 48 860 | 168 430 | 0,715 | 0,110 |
| **cualquiera** | **0,50** | **0** | **0** | **∞** | **∞** | **1** | **1** |

Todas las cifras salen de `prob_cambio_posterior` y `tiempo_hasta`, con encierre de dos lados; las
48 filas de `resultados/certificado.csv` comprueban que la bola de `Arblib` (160 bits) **solapa** el
encierre en el 100 % de los casos, con anchura máxima `4,8·10⁻²`. No hay ningún `min(1.0, ·)` en el
instrumento: la descomposición `L = P(D≤0) + P(D̃>0)` da un valor en `[0,1]` por construcción.

**La escala.** `L` depende de `λ` y `t` solo a través de `λt`, luego `t(ε) ∝ 1/λ`. Es un resultado,
no un supuesto, y `test/runtests.jl` lo comprueba barriendo `λ`.

**Qué es `L(F)` tras la corrección.** En la primera versión era una **cota** de que dos nodos
quedaran en flujos distintos. Bajo la regla leída por su letra es algo más preciso y más grande: es
**exactamente** la probabilidad de que quien sincronice después de `t_j+F` acabe en el flujo
contrario al que quedaron los veteranos (§2.3). La tercera función que pedía el encargo
—`P(dos nodos en flujos distintos)`— está en §2.3, no aquí.

### 2.3 · Congelamiento simultáneo — la regla leída por su letra

`research/dag-poas-ancla-de-orden.md:301-303` dice *«Un nodo **MUST NOT** reorganizar su cadena
seleccionada **por debajo de `F` segundos de slot**»*: acota la **profundidad**. Con R-FIN-3
(linaje acumulativo) los dos linajes no vuelven a coincidir, y con R-FIN-5 todo bloque del flujo
rival tiene su pasado entero en él, así que la bifurcación se queda clavada en `t_j` y la
profundidad para cruzar vale `t − t_j`. **Todos los nodos se congelan a la vez en `T* = t_j + F`.**

- **Con vista común: `P(bloqueo divergente) = 0`.** Todos ven el mismo `D`, se congelan en el mismo
  flujo, y **la partición se resuelve en tiempo exactamente `F`**. No hay nada que simular.
- **La grieta es el desfase de vista.** Dos nodos separados por `τ` segundos se congelan en flujos
  distintos si y solo si el líder cambió en esos últimos `τ`.

**`P_div(F, τ) = P(sign D(F−τ) ≠ sign D(F))`** (`resultados/congelamiento.csv`, régimen, `λ = 1`,
`τ = 4 s`). Validada contra un oráculo de enumeración completa en `BigFloat` (coincide al octavo
dígito) y contra Monte Carlo con Philox:

| `c` | `s₁` | deriva | `F` | **`P_div`** | `arcsin(√(τ/F))/π` | cota de banda | **`L(F)`** (los que llegan después) |
|---:|---:|---:|---:|---:|---:|---:|---:|
| **cualquiera** | **0,50** | **0** | 600 | **0,02560** | 0,02602 | 0,183 | **1** |
| **cualquiera** | **0,50** | **0** | 7 200 | **0,00738** | 0,00750 | 0,0532 | **1** |
| **cualquiera** | **0,50** | **0** | 11 520 | **0,00584** | 0,00593 | 0,0420 | **1** |
| 0,9 | 0,60 | 0,0213 | 600 | 0,02407 | — | 0,171 | 0,715 |
| 0,9 | 0,60 | 0,0213 | 7 200 | 0,00334 | — | 0,0240 | 0,207 |
| 0,9 | 0,60 | 0,0213 | 11 520 | 0,00164 | — | 0,0117 | 0,110 |
| 0,75 | 0,60 | 0,0588 | 600 | 0,01591 | — | 0,113 | 0,322 |
| 0,5 | 0,60 | 0,143 | 600 | 0,00184 | — | 0,0134 | 0,0210 |
| 0 | 0,60 | 0,500 | 600 | 1,2·10⁻¹² | — | 1,2·10⁻¹¹ | 4,6·10⁻¹² |

Monte Carlo (6 000 réplicas, Philox, Clopper–Pearson) en las celdas con `F = 600`: `0,02517`
[0,0214, 0,0295] frente a `0,02560`; `0,00217` [0,00115, 0,00370] frente a `0,00184`; `0,01683`
[0,01373, 0,02042] frente a `0,01591`; `0,02133` [0,01783, 0,02531] frente a `0,02407`. **Las cuatro
contienen la fórmula.**

**Lo que hay que leer de esa tabla:**

1. **Sin deriva, `c` no entra en absoluto.** Las tres primeras filas valen lo mismo para `c = 0`,
   `0,25`, `0,5`, `0,75`, `0,9` y `1`. La cobertura no toca ninguno de los dos canales.
2. **`P_div` decae como `√(τ/F)`**: para dividirla por dos hay que **cuadruplicar `F`**. De `F = 600 s`
   a `F = 11 520 s` (3,2 h) sólo baja de `2,6 %` a `0,58 %`. Y es una división **permanente**:
   ocurre justo en el instante en que la regla cierra la puerta.
3. **El canal de los recién llegados es uno o dos órdenes de magnitud mayor**, y con deriva nula
   vale **1**: cualquiera que sincronice después de `T*` acabará, antes o después, pegado al flujo
   contrario. Es el canal que manda, y **sale de un hueco en la redacción de R-FIN-7**: la regla no
   dice nada sobre la **primera** selección de un nodo sin cadena previa (H-RECIEN-LLEGADO).
   Depende además de que el flujo perdedor **siga recibiendo bloques** después del congelamiento, es
   decir de que un granjero pueda firmar en un flujo que su nodo no ha seleccionado
   (H-PRODUCIR-SIN-SELECCIONAR): R-FIN-7 constriñe la cadena seleccionada, no la firma. **Si una
   regla atara producir a seleccionar, este canal se cerraría solo** — y sería la corrección más
   barata de todo el informe.
4. **La cota de banda `P(|D(F)| ≤ δ)`** —la forma en que la pregunta suele plantearse— es válida y
   **holgada por un factor 5–7**. Se publica, pero el número bueno es el de retardo.

**Realimentación, bajo la regla corregida** (`resultados/congelamiento-realimentado.csv`, `τ = 4 s`,
6 000 réplicas). Ya no acelera una absorción —que ahora ocurre a la fuerza en `t_j+F`—: lo único que
puede hacer es **alejar `D` de cero antes de que llegue ese instante**.

| `c` | `s₁` | `F` | `ρ = 0` | `ρ = 10⁻⁴` | `ρ = 10⁻³` |
|---:|---:|---:|---:|---:|---:|
| 0,5 | 0,50 | 600 | 0,02517 | 0,02033 | **0,00100** (25× menos) |
| 0,5 | 0,50 | 7 200 | 0,00767 | **0** [0, 6·10⁻⁴] | **0** |
| 0,75 | 0,50 | 600 | 0,02517 | 0,02183 | 0,00850 |
| 0,9 | 0,50 | 600 | 0,02667 | 0,02267 | 0,02017 (sólo 24 % menos) |
| 0,9 | 0,50 | 7 200 | 0,00833 | 0,00200 | **0** |

Lo que manda es el producto **`ρ·F·(1−c)`**: la realimentación sólo puede mover el espacio
**exclusivo**, que es `1−c`, y necesita tiempo para moverlo. Con `c = 0,9` y `F = 600 s` apenas hay
qué mover y apenas baja; con `c = 0,5` y `F = 7 200 s` la rendija se cierra del todo dentro de la
resolución del Monte Carlo. **Es la primera palanca de este informe que actúa sobre el caso
simétrico sin depender de `s₁−s₂`** — pero es conducta de granjero, no regla de protocolo.

**Qué medía el `0,6828` de la versión anterior** (`0,6793` una vez corregido el generador, defecto
D4). Medía `P(∃ dos rachas disjuntas de longitud ≥ F con signos opuestos)` dentro de un horizonte de
24 000 slots (`resultados/absorcion.csv`, conservado y
etiquetado como **regla superada**). Bajo la regla corregida **no es «dos nodos bloqueados en flujos
distintos»**: es una **cota inferior estricta** de la divergencia veterano/recién-llegado, porque
exige una racha completa de longitud `F` del signo contrario cuando al recién llegado le basta un
instante. El valor correcto de esa magnitud es `L(F)`, que con deriva nula vale **1**, no `0,6828`.
La corrección, por tanto, **baja** el número de los veteranos (de `0,68` a `0,026`) y **sube** el de
los recién llegados (de `0,68` a `1`). No es un ajuste: es que la cifra anterior mezclaba dos
poblaciones que la regla trata de forma completamente distinta.

## 3 · Cuánta cobertura hay en equilibrio — la pregunta que decide

**La condición, como función de los costes y sin ningún precio inventado:**

```
cubrir el flujo j es racional  ⟺  p_j  >  ρ_var + ρ_fij / x
```

con `x` en TiB, `ρ_var` el coste marginal **variable** por TiB dividido por la recompensa por TiB, y
`ρ_fij` (en TiB) el coste **fijo por flujo abierto** dividido por la recompensa por TiB. De ahí:

```
x*           = ρ_fij / (p_j − ρ_var)                       [tamaño mínimo para cubrir]
x*_productor = (ρ_fij + ρ_prod) / (p_j − ρ_var)            [para producir además el PoT]
c            = fracción del espacio en granjas con x > x*
```

**Para qué rangos `c → 1`.** Hacen falta **dos** condiciones, y se suele contar solo la primera:

1. **`p_j > ρ_var`.** Si no, no cubre **ninguna** granja, por grande que sea.
2. **`x* < x_mín` de la red.** Con `ρ_fij > 0` siempre hay granjas por debajo. `c → 1` exige
   `ρ_fij → 0`, es decir **coste fijo por flujo nulo**, y no lo es: verificar el PoT de un flujo
   cuesta `0,092–0,190` núcleos según ISA (`SPEC.md:2988`) y **producirlo** cuesta
   `1,561 s/slot ≈ 1,56 núcleos` (`research/dag-poas-ancla-de-orden.md:342`), ~16× más.

**Esto es lo que refuta el argumento histórico.** `research/dag-poas-candidatos-auditoria.md:20-22`
dice que cubrir todos los flujos vivos es «estrategia estrictamente dominante» porque publicar es
gratis y auditar cuesta `1/1 517 730` de plotear. La razón plotear/auditar es correcta y no es el
argumento: mide un coste **variable** (pases de auditoría) y **calla el fijo** (verificar y producir
el PoT), que es el único que decide si una granja pequeña entra. **Con coste fijo positivo, «cubrir
todos» no es dominante para todas las granjas, y `c < 1` genéricamente.** Etiqueta: **DEMOSTRADO**
como condición; los `c` numéricos de `resultados/cobertura.csv` son **estimados** y dependen de
H-TAMANOS.

**Y ojo con la dirección.** `c < 1` **ayuda** a resolver la partición, no la sostiene. El argumento
histórico usaba `c = 1` para concluir «no converge»; corregirlo a `c < 1` **debilita** esa
conclusión… y no la elimina, porque con `s₁ = s₂` da igual.

**`S_máx`, como función de los IOPS por TiB y no de la capacidad** (`resultados/smax.csv`,
slot = 1 s, verificación 101 ms):

| límite | fórmula | valor |
|---|---|---|
| IOPS | `ι·dur_slot / 1 040,25` | `ι = 25 000` IOPS/TiB (SSD de 4 TiB y 100 k IOPS) ⟹ **`S = 24,03`, a cualquier capacidad** |
| núcleos | `N/(0,04465·x + 0,101)` | `N = 16` núcleos ⟹ 110 (1 TiB), 57,2 (4 TiB), 16,1 (20 TiB), **3,50 (100 TiB)**, **0,358 (1 PiB)** |

El límite correcto es **el mínimo de los dos**, y **cambia de dueño con el tamaño**: las granjas
pequeñas están limitadas por IOPS (`S ≈ 24`) y las grandes por CPU. A 1 PiB con 16 núcleos,
`S_núcleos = 0,36`: **ni siquiera alcanza para auditar un solo flujo** —auditar 1 000 TiB contra un
flujo cuesta `44,65 + 0,10 = 44,75` núcleos continuos—. La metaauditoría da **43,95** núcleos a
1 PiB (`research/dag-poas-ancla-de-finalidad-metaauditoria.md:138-145`), es decir 42,92 a 1 000 TiB;
la diferencia del **4 %** no es un desacuerdo: ellos usan 1 000 sectores/TiB y aquí se usan
**1 040,25**, derivados de la medición de 4 161 lecturas/slot a 4 TiB
(`research/dag-nativo-poas-propuesta.md:1360`). Fijar un único SSD para cualquier
capacidad, que es lo que producía el absurdo «0 flujos con 100 TiB», queda corregido:
`s_max_iops` no depende de la capacidad y `test/runtests.jl` lo comprueba barriéndola.

---

## 4 · El contraste histórico — la misma magnitud, y el horizonte que faltaba

La magnitud es **el instante del último cambio de líder dentro de un horizonte** (ley del arcoseno),
no «al menos un cambio».

**Lo exacto** (`resultados/arcoseno-exacto.csv`, `Rational{BigInt}`): para un paseo simétrico, la
media del instante del último cruce es **`T/2` exactamente** para todo `n`, y
`P(último cruce > 0,99·T) = 0,0638`.

**Lo de este modelo** (`resultados/arcoseno-mc.csv`, 6 000 réplicas, `λ = 1`, **horizonte declarado
`T = 6 000` slots**), con deriva nula (`s₁ = 1/2`, cualquier `c`):

| magnitud | este modelo | ley del arcoseno (límite de difusión) | ronda 3 |
|---|---:|---:|---:|
| `E[último cambio]/T` | **0,4945** [±0,0046] | **0,5** | — |
| `P(cambio tras 600 s)` | **0,7825** [0,7718, 0,7929] | **0,7952** | **0,82** |

La diferencia del **1,6 %** entre lo medido y la ley del arcoseno **no es error**: es la corrección
de retícula del proceso discreto frente a su límite de difusión, y sale del mismo tamaño —1,6 %— que
en las cuatro celdas independientes de §2.3 (`0,02560` medido frente a `0,02602` del límite).

**Conclusión del punto 4.** Con `c = 1` —la premisa de la ronda 3— este modelo **reproduce el
resultado histórico**: `0,7825` frente a `0,82`, y la ley del arcoseno predice `0,7952` para ese
horizonte.

**La dirección en que R-FIN-4/5 cambia la dinámica, que el encargo pedía determinar y no suponer:**
si el proceso de la ronda 3 era también un paseo **libre** sin deriva —que es lo que su propio
razonamiento describe, «Skellam de deriva nula, recurrente»
(`research/dag-poas-candidatos-auditoria.md:20-22`)—, entonces **la fusión no cambia esta magnitud**:
con cobertura total la deriva es cero en los dos diseños y el último cruce sigue la ley del
arcoseno en los dos. Si, en cambio, la fusión hacía el proceso **reversivo a la media** —los
cruces pasarían a ser estacionarios y el último cruce se pegaría al final de cualquier horizonte—,
entonces sí difiere, y ahí la partición no fusionable sería **más estable**, no menos.
**No se puede decidir sin reejecutar su instrumento, y no se ha hecho.** Lo que sí se puede decir es
que sus dos cifras apuntan a procesos distintos: `0,82` es lo que da un paseo libre con horizonte
`≈ 7 708 s`, y `203,6` de `205,7` es lo que da un proceso de cruces estacionarios, no un paseo
libre, que habría dado `102,9`.

**En qué no es comparable, y es lo importante:**

1. **La ronda 3 no declaró su horizonte, y el horizonte es lo único que fija la cifra.** Bajo la ley
   del arcoseno, `P(cambio tras 600 s) = 0,82` implica `T = 7 708 s`
   (`resultados/arcoseno-contraste.csv`); con `T = 1 000 s` habría salido `0,44` y con `T = 20 000 s`,
   `0,89`. **La cifra no mide una propiedad del diseño: mide la longitud de la corrida.**
2. **Las dos cifras históricas no son consistentes entre sí bajo la ley del arcoseno.** `0,82` implica
   `T = 7 708 s`; un instante medio del último cambio de `203,6 s` implica `T = 407 s`. Si el
   horizonte hubiera sido la época de `205,7 s`, la media habría sido `102,9 s`, no `203,6 s`. Al
   menos una de las dos mide algo distinto de lo que su redacción dice.
3. **`c = 1` no es un equilibrio** (§3), así que la celda que compara no es la que describe una red
   real.
4. La unidad de peso difiere: allí los flujos se fusionaban y el peso era acumulable entre ramas;
   aquí `D` es la diferencia entre dos `blue_work` que **no** pueden sumarse.

**Etiqueta:** MEDIDO para las cifras de este modelo (con su IC); **no demostrado** para la
reconstrucción del modelo de la ronda 3 —no se ha reejecutado su instrumento— y para la lectura de
sus dos cifras.

---

## 5 · Rendimiento y validación (LINEO §6)

⚠️ **Toda esta sección se midió con la máquina ocupada.** Durante la ejecución, otro agente corría
`P-2.1/run.jl 4a` con 24 hilos y la carga media era **22**. Los tiempos son por tanto **cotas
superiores** del coste real, y no son comparables con una medición en máquina libre. Las
**asignaciones**, en cambio, no dependen de la carga y sí son comparables.

`resultados/bench.txt`. `L(t)` en `t = 60`, transitorio `c = 1/2`, `s₁ = 3/5`:

| Variante | Tiempo mediano | Asignaciones | Bytes | Hilos/backend | Resultado frente a la referencia |
|---|---:|---:|---:|---|---|
| Oráculo `BigFloat` (doble suma directa) | 4,025 ms | 140 645 | 7 879 696 | 1 CPU | fuente de verdad, `5,27435649745760·10⁻¹` |
| Kernel `Float64` (ventana + gamma incompleta) | **21,14 µs** | **0** | **0** | 1 CPU | igual, `rtol = 10⁻⁹` |
| Certificado `Arblib` 160 bits | 0,296 ms | 11 330 | 543 936 | 1 CPU | **contiene** el valor: `[0,527435649745760167… ± 2,29·10⁻³⁷]` |

Aceleración kernel/oráculo: **190×**, con **cero asignaciones** en el camino caliente. El coste va
como `O(√(λt))`. La simulación hace **12,2 ns por evento** y asigna **96 bytes por réplica**,
independientemente del horizonte (eran 9,3 ns y 32 bytes con el generador anterior: el estado de
Philox es mayor, y **ese es el precio de que las réplicas sean de verdad independientes**).

**Escalado de hilos.** 2 000 réplicas de `T = 5 000`: **0,263 s con 1 hilo, 0,134 s con 2** (1,96×).
**El escalado `1…24` de LINEO §7 no se hizo, y se declara:** el encargo fija un tope de 2 hilos
porque otro agente usa 24 en `P-2.1/`; medir 4…24 habría roto el tope de la máquina y contaminado su
banco. Es una **laguna declarada**, no un olvido.

**Validación cruzada.** `test/runtests.jl`: **239 comprobaciones, todas pasan**, en los dos perfiles
(`--threads=1 --check-bounds=yes` y `--threads=2`). Incluye:

- kernel `Float64` contra el oráculo `BigFloat` (`r = 1` y `r ≠ 1`);
- `L(t)` contra el oráculo de Skellam por la vía directa, **sin** inclinación exponencial;
- Monte Carlo dentro del intervalo exacto de Clopper–Pearson alrededor de la fórmula;
- `prob_ruina` exacta `= (λ₂/λ₁)^d` para `r = 1`, y encierre que contiene el MC para `r ≠ 1`;
- `prob_congelamiento_divergente` contra la **enumeración completa** de la ley conjunta en
  `BigFloat` (coincide al octavo dígito) y contra Monte Carlo;
- la forma cerrada `arcsin(√(τ/F))/π` contra el cálculo exacto en el límite sin deriva, con la
  comprobación explícita de que **no** es `(2/π)arcsin`;
- **la independencia entre réplicas del generador**: la autocorrelación lag-1 sobre 20 000 réplicas
  debe quedar por debajo de `0,02`. Ese test **falla** con el esquema de semillas consecutivas que
  usaba la versión anterior;
- 48 puntos certificados con `Arblib`: **100 % de solapamiento**, anchura máxima `4,8·10⁻²`;
- el port de `pieces_to_solution_range` contra los tres `const_assert!` de Autonomys;
- y los bloques **NO-CONSTANTE**, que barren parámetros y exigen que el resultado **cambie** en la
  dirección correcta. Si alguien sustituye una función por su valor esperado escrito a mano, fallan.

**Cinco defectos propios, encontrados y corregidos** (detallados en `PROGRESO.md`):

1. La ventana de Poisson centrada en la media dejaba fuera la región que domina el resultado:
   `L(t)` salía con una cota de truncación `10¹⁴` veces mayor que el valor.
2. La evaluación por intervalos de `hypgeom_gamma_lower` devolvía bolas de radio `10¹³⁰` en la cola,
   que se propagaban enteras al resultado.
3. La variante realimentada no comprobaba la divergencia en la última racha, y daba `0,5505` donde
   la versión base daba `0,6828` para la misma celda.
4. **El Monte Carlo estaba sesgado por el generador.** `StableRNG(semilla + i)` con `i` consecutivo
   no da flujos independientes: autocorrelación lag-1 de **−0,43** entre réplicas. LINEO §5.1 ya
   pedía `Random123`/Philox para esto y yo usé `StableRNGs`, que es para fixtures. Migrado: la
   autocorrelación baja a **−0,0006**.
5. **La forma cerrada del congelamiento estaba mal por un factor 2 exacto**: escribí
   `(2/π)arcsin(√(τ/F))`, que es `P(hay un cero)`, cuando la magnitud es `P(el signo cambia)`.

Los dos primeros daban resultados **válidos e inservibles**, no falsos; el tercero, el cuarto y el
quinto sí eran sesgos. El 4 y el 5 se descubrieron **porque la fórmula nueva y su Monte Carlo
discreparon fuera del intervalo de Clopper–Pearson**, y el árbitro fue un oráculo de fuerza bruta en
`BigFloat`. La corrección del segundo, además, bajó el tiempo de la certificación de **302 s a
0,1 s**.

**Y un defecto de alcance, señalado por el validador y aceptado**: la regla de absorción de la
primera versión no era la de R-FIN-7. Ese no lo encontré yo.

---

## 6 · Lo que este informe NO cierra

1. **`s₁`.** Todo cuelga del reparto del espacio exclusivo en el instante en que nace la partición, y
   **no hay ninguna medición ni modelo de esa distribución en el repositorio**. Si se concentra cerca
   de `1/2` —lo esperable si la partición nace de que dos mitades leyeron anclas distintas—, la
   deriva es cero para cualquier `c` y ninguna palanca de cobertura sirve. Es lo más barato que queda
   por medir (`PROPUESTA.md` §P5).
2. **Con atacante, nada de esto vale.** Basta con que un adversario añada espacio al flujo perdedor
   hasta igualar `(1−c)(s₁−s₂)` para anular la deriva. Todas las conclusiones de §2 sobre resolución
   son **optimistas**.
3. **`β`** es un modelo (H-BETA), no un teorema de GHOSTDAG. Con `Δ` grande y `k` ajustado, `∝ W_i`
   es falso por decenas de puntos porcentuales.
4. **La probabilidad de que nazca** una partición no se calcula aquí: es `P-2.1` §4.A.
5. **El encierre del régimen `r ≠ 1`** no es exacto: la ruina tiene un exceso al cruzar el cero
   acotado por `e^{−R}`, que da una anchura relativa `≤ 1−e^{−R}` (máximo medido `4,8·10⁻²`). Para el
   transitorio (`r = 1`) sí es exacto.
7. **`τ` no está medido.** `MIGRACION.md` dice de `Δ`: *«Sin medir en una red ZEROX con DAG; 4/16/20 s
   son escenarios»*. Todo el §2.3 es función de `τ` y no puede dejar de serlo hasta que alguien mida
   la dispersión de vistas en una red real.
8. **El desacuerdo de vista se modela como retraso puro** (H-DESFASE). Dos vistas reales pueden
   diferir en bloques cruzados, y entonces el desacuerdo es mayor: `P_div(F,τ)` es una **cota
   inferior** del real a igual dispersión, y la cota de banda —5 a 7 veces mayor— es la superior.
9. **R-FIN-7 no dice qué hace un nodo sin cadena previa** (H-RECIEN-LLEGADO). De ese hueco sale el
   canal que domina el resultado. Cerrarlo es redacción, no cálculo.
6. **`H-PoT-COMUN`**: se supone que los dos flujos avanzan al mismo ritmo de PoT. El repositorio mide
   que la máquina de referencia **no llega a 1 s/slot**; la dispersión de hardware entre productores
   de PoT introduciría una deriva que este modelo no tiene, con signo arbitrario.

---

## 7 · Reproducir

`METODO.md` tiene los comandos exactos desde la raíz. Resumen: `julia 1.13.0`, semilla `0x5A5A`,
`λ = 1`, 6 000 réplicas, 2 hilos, `Manifest.toml` versionado, `HUELLAS.sha256` con las rutas desde la raíz. El
barrido completo (`run.jl --todo`) tarda **86 s** y no se acerca a ninguno de los tres topes del
presupuesto declarado en `CONTRATO.md` §3.
