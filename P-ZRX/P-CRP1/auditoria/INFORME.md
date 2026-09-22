# INFORME P-CRP1 — De los diez defectos, nueve son reales y uno a medias; caen ocho cifras publicadas, cambian tres, las estructurales se sostienen, y el «sobrevive sin recortes» de PROCEDENCIA.md NO se mantiene

De los diez cargos, **nueve son reales** (D1, D2, D3, D4, D5, D7, D8,
D9, D10) y **uno es real a medias** (D6); de las cifras publicadas, **caen ocho** (la tabla
`P(alcance)` por granularidad de `D2`, la tabla «work/slot ≈ s» con GDR de `D1`, la etiqueta
`1/2⁺` y la tabla de `α_mínimo(d,ε)` de `D3`, «ataque gratis» de `D10`, «`S ≈ 24` medido» de
`D9`, «la Δ medida 0,26–0,60 s» de `D6` y «ambas azules en su rama» de `D8`), **cambian tres**
(la compra de varianza `0,022→0,0213 / 0,097→0,0950 / 0,244→0,2275 / 0,308→0,3150`; la curva
`α_mínimo(d,ε=0,10)`; y el error de la invariancia `sr↔peso`, que no incluye la paridad) y **se
sostienen las estructurales** (`α_mínimo = 1/2` de media, `α_min = 1/(S+1)` condicional, la
fórmula de rojos asimétricos y la frase «la contribución del DAG es de varianza, no de umbral»,
que la tabla corregida **refuerza**). **El veredicto de `PROCEDENCIA.md` («sobrevive sin
recortes») NO se mantiene**: sobrevive la frontera de deriva `1/2` del modelo contable, no el
paquete de cifras ni las etiquetas.

**Presupuesto y etiqueta de tiempo.** ≤ 4 hilos, ≤ 8 GiB de RAM, ≤ 1 GiB de disco temporal. En
todas las corridas `uptime` dio carga media ≤ 1,4 sobre 32 hilos lógicos: **por debajo de los 4
hilos asignados**, así que ningún tiempo publicado lleva la etiqueta «medido con carga ajena».

---

## 0 · Cómo se trabajó

- Entradas de solo lectura verificadas con `LC_ALL=C sha256sum -c P-ZRX/P-CRP1/ENTRADA.sha256`:
  **37/37 OK** al empezar y al terminar (`PROGRESO.md`).
- CRP-v0.1 copiado con `cp -a` a `auditoria/copia/`. **No hizo falta ninguna corrección de
  rutas**: `ruta_gdr()` (`copia/src/rapido.jl:158-171`) sube hasta la raíz del repositorio y
  encuentra `veritas/consenso/ghostdag-rank-v1/src/GhostdagRank.jl`. El `diff` de la copia contra
  el original es **vacío**: la única modificación permitida por el encargo no fue necesaria.
- Recálculos en `auditoria/veritas/seguridad/crp1-defectos-v1/` (estructura de LINEO §1, Julia
  CPU, `Project.toml` + `Manifest.toml`, suite de **60/60** con `--check-bounds=yes`).
- Contraste independiente con PCO-v0.1 (`veritas/consenso/puerta-cobertura-v1/`) para D4 y con
  GDR-v0.2 para D1/D8. **No se editó nada** fuera de `P-ZRX/P-CRP1/auditoria/`.

**Presupuesto de cómputo efectivo**: la corrida más larga es la tabla exacta de varianza (82 ms) y
la DP de alcance (14 ms); el total del resumen es < 1 min. Muy por debajo del tope de 24 h.

---

## 1 · Fichas D1–D10

### D1 · «El supuesto DAG era una cadena» — **REAL**

**Cargo literal** (`ENCARGO-07v2-coste-rama-privada.md:158-161`):

> `construir_rama_gdr` actualiza las puntas después de cada bloque, incluso dentro del mismo slot, y
> deja una sola punta. La salida tiene `n_azules = n_total + 1`: no ejercita anticonos ni `rojo_k`.

**Dónde está.** `copia/src/rapido.jl:195-260`. La punta elegida es `puntas[1]` (línea 216, la de
mayor `blue_work`); los demás padres son **todas** las otras puntas (línea 224,
`extras = [x for x in puntas if x != sp]`); con eso

```julia
puntas = [x for x in puntas if !(x in padres)]   # rapido.jl:246
push!(puntas, nuevo)                             # rapido.jl:247
```

deja **exactamente una** punta tras cada bloque, incluso dentro del mismo slot.

**Reproducción mínima.** `auditoria/gdr-d1-d8.jl`, apartado (a), con GDR-v0.2 real:

| s | sr/sr0 | n_total | n_azules | n_puntas | rojo_k | rojo_U3 | ms_max |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 0,10 | 1,00 | 27 | 28 | **1** | 0 | 0 | **1** |
| 0,30 | 1,00 | 53 | 54 | **1** | 0 | 0 | **1** |
| 0,30 | 4,00 | 241 | 242 | **1** | 0 | 0 | **1** |
| 0,50 | 1,00 | 94 | 95 | **1** | 0 | 0 | **1** |

`n_azules = n_total + 1` en todas las filas (el `+1` es el génesis, que `blueset` incluye:
`GDR src/modelo.jl:249`). `ms_max = 1`: **ningún** mergeset tiene más de un elemento. Lo mismo en
lo publicado: `copia/resultados/run-gdr.txt:22-30` da 14/15, 81/82, 67/68, 214/215, 96/97, 388/389.

**Control.** La misma construcción con **vista local** (los `k` bloques de un slot se autorían
contra la vista del inicio del slot, antes de propagar los del propio slot) produce estructura DAG
real:

| s | n_total | max_puntas | ms_max |
|---:|---:|---:|---:|
| 0,3 | 55 | **3** | 3 |
| 1,0 | 193 | **4** | 4 |
| 3,0 | 612 | **8** | 8 |

**¿Algún test ejercita anticonos o `rojo_k`?** No. `rojo_k` (0x01) **no existe como
identificador** en GDR-v0.2: es la etiqueta documental del valor 0x01 de `tipos`
(`GDR src/rapido.jl:11`); no hay accesor `es_rojo_k`. CRP-v0.1 nunca cuenta 0x01: su fixture sólo
mide `rojo_U3` (`copia/src/rapido.jl:348,350`; `copia/test/runtests.jl:87`). Y su suite
(`copia/test/runtests.jl:78-91`) sólo comprueba invariancia de trabajo y el fixture U2/U3″.

**Cifras publicadas que toca.** La tabla de `--gdr` (`resultados/run-gdr.txt:22-30`, reproducida en
`INFORME.md:27`) dice «Work/slot con GDR ≈ s». Mide una cadena, no un DAG: **cae como medición de
la contribución del DAG**. Lo que sí mide (la identidad `sr↔peso`) está en D4/D11.

**Veredicto: REAL.**

---

### D2 · «La DP de granularidad perdía casi toda la masa» — **REAL**

**Cargo literal** (`ENCARGO-07v2:175-176`):

> El corte fijo 0…60 descartó casi toda la distribución para `g=256` y no renormalizó. Además `d`
> se declaró en unidades de trabajo pero se mantuvo como entero de bloques al cambiar `g`.

**Dónde está.** `copia/src/referencia.jl:129-141` (`pmf_cambio_neto`, línea 129:
`corte::Int=40`; línea 150 de `prob_alcance_dp`: `corte=min(nmax,60)`), y el punto de llamada
`copia/run.jl:138`: `prob_alcance_dp(0.4, float(g), 600; d=6)` — `d = 6` **bloques** para todo `g`,
cuando `d` está en unidades de trabajo y cada bloque pesa `1/g`.

**Reproducción mínima.** Masa retenida por el corte (calculada con la propia pmf del instrumento,
`auditoria/veritas/seguridad/crp1-defectos-v1/run.jl --d2`):

| g | masa retenida con corte 0…60 | `z = d` (lo publicado) | `z = d·g` (lo correcto) |
|---:|---:|---:|---:|
| 1 | 1,000000 | 8,009e-2 | 8,009e-2 |
| 4 | 1,000000 | 6,553e-2 | **4,434e-5** |
| 16 | 1,000000 | 4,214e-2 | **5,967e-18** |
| 64 | 0,999537 | 1,259e-2 | **4,920e-69** |
| 256 | **2,312e-23** | 3,193e-26 | **0** (masa agotada) |

El corte sólo colapsa en `g=256` (como dice el cargo), pero el **defecto de unidades arruina toda
la fila con `g>1`**, y la masa cruda nunca se publicó.

**Recálculo independiente y exacto** (`run.jl --d2`). Tres métodos:

| g | z = d·g | ruina exacta ±1 `(q/p)^z` (`Rational{BigInt}`) | DP Poisson, masa conservada | cota de martingala | publicado |
|---:|---:|---:|---:|---:|---:|
| 1 | 6 | 8,779150e-2 | 8,008882e-2 | 8,779150e-2 | 8,0e-2 |
| 4 | 24 | 5,940319e-5 | 4,434045e-5 | 5,940319e-5 | 6,6e-2 |
| 16 | 96 | 1,245200e-17 | 5,966730e-18 | 1,245200e-17 | 4,2e-2 |
| 64 | 384 | 2,404122e-68 | 4,986261e-69 | 2,404122e-68 | 1,3e-2 |
| 256 | 1536 | 3,340612e-271 | 1,954830e-272 | 3,340612e-271 | 3,2e-26 |

- La columna «ruina exacta ±1» es la prescripción del propio D2/D3 («representar el déficit como
  `d·g`»), exacta en `Rational{BigInt}`; validada contra un sistema lineal racional y contra
  enumeración de caminos (`test/runtests.jl` T2).
- La columna «DP Poisson» resuelve la **misma** recurrencia con la pmf compuesta **sin truncar**:
  matriz de transición completa, masa conservada, y **estable a 15 dígitos** al multiplicar por 6
  el margen de ventana (`m+200`, `m+600`, `m+1200` dan el mismo valor). Para `g = 1, 4, 16`
  coincide con la DP del propio CRP-v0.1 cuando se le da el déficit correcto (`8.008882e-2`,
  `4.434045e-5`, `5.966723e-18`): **implementación independiente, mismo resultado**.
- La columna «martingala» es una **cota superior exacta**: con `X = H−A`,
  `H~Poisson(g(1−α))`, `A~Poisson(gα)` y `z = α/(1−α)` se tiene `E[z^X] = exp(g[(1−α)(z−1)+α(z⁻¹−1)]) = 1`
  (residuo medido < 1e-76), de donde `P(alcance) ≤ z^{d·g}`, exacto en `Rational{BigInt}`.
- Intervalo riguroso completo (cota inferior de horizonte finito `max_n P(S_n ≤ −d·g)` y cota
  superior de martingala), `run.jl --d2`: `g=256` → `[2,03e-1010, 3,34e-271]`. El valor publicado
  `3,2e-26` **viola la cota superior en 244 órdenes de magnitud**: queda refutado sin ambigüedad.
  La cota inferior es muy floja porque acota la posición final y no el mínimo del paseo; se publica
  tal cual en lugar de estrecharla con un argumento no certificado.

**¿Sobrevive «la contribución del DAG es de varianza, no de umbral»?** **Sí, y se refuerza.** La
frase es sobre la *media* (`α* = 1/2` no se mueve) y sobre la *cola*, y la cola corregida decrece
mucho más deprisa con `g` que la publicada. Lo que cae es la tabla numérica, no la tesis.

**Cifras que toca:** la tabla `P(alcance)` de `INFORME.md:50-52` y su repetición en
`run.jl:250-254` (`--referencias`): **g=4, 16, 64 y 256 caen**; `g=1` se sostiene.

**Veredicto: REAL.**

---

### D3 · «Empatar no es superar estrictamente» — **REAL**

**Cargo literal** (`ENCARGO-07v2:198-210`):

> El contrato exige superar la ventaja pública inicial. […] `P(alcanzar empate D=0) = (q/p)^d`,
> `P(superar estrictamente D<0) = (q/p)^(d+1)`.

**Dónde está.**
- `copia/src/referencia.jl:153`: `p[1] = 1.0  # déficit ≤ 0: ya alcanzó` — el DP absorbe en
  `D ≤ 0`, es decir el evento de **empate**, no el estricto.
- `copia/run.jl:147`: `αmin = 1.0 / (1.0 + (0.10)^(-1.0 / d))` — la curva del empate.
- `copia/run.jl:129-130` etiqueta la columna «Probabilidad de que el adversario alcance (lleve el
  déficit a ≤0)»: correcto como descripción, incorrecto como criterio del contrato.
- Contraste: `efecto_varianza_sr` sí usa la comparación estricta (`copia/src/rapido.jl:88`,
  `gana[r] = (ba > bh)`), pero `curva_corta_mc` usa `a >= h` (`copia/src/rapido.jl:143`): **dos
  convenciones distintas en el mismo fichero**.

**Reproducción mínima** (`run.jl --d3`):

| d | `α_min` empatar (publicado) | `α_min` superar estricto | diferencia |
|---:|---:|---:|---:|
| 3 | 0,317014 | **0,359935** | +0,042921 |
| 6 | 0,405219 | **0,418498** | +0,013279 |
| 12 | 0,452176 | **0,455835** | +0,003659 |
| 24 | 0,476033 | **0,476990** | +0,000957 |
| 50 | 0,488489 | **0,488715** | +0,000226 |

En la retícula (`α=0,4`, `z=6`): empate `(q/p)^6 = 0,0877915`; estricto `(q/p)^7 = 0,0585277`. Con
el paseo compuesto de Poisson, la razón entre ambos eventos se mantiene en **≈ q/p = 0,666667**
para todo `g` (verificado en `g ∈ {1,4,16,64,256}`), coherente con que la cota de martingala del
evento estricto sea exactamente `(q/p)` veces la del empate.

**La etiqueta `1/2⁺`.** `INFORME.md:43` escribe `α_mínimo(d,ε) = 1/(1+ε^{−1/d}) → 1/2⁺` y
`run-corto.txt:49` dice «→ α_min → 0.5 **por arriba** al crecer d». Los valores son
`0,3170 < 0,4052 < 0,4522 < 0,4760 < 0,4885 < … < 0,5`: la sucesión **crece hacia 1/2 desde
abajo**. La notación `1/2⁺` y el «por arriba» son una etiqueta equivocada, y D3 pide exactamente
esa regresión textual.

**Cifras que toca:** la tabla de `INFORME.md:39-41` (**cambia**), la fila
`α_min(d=6, ε=0,1) = 0,405` de la tabla comparativa de `INFORME.md:69-73` y de
`run-referencias.txt:16-18` (**cambia a 0,418**), y la leyenda `1/2⁺` (**cae**). La frontera de
deriva `α_mínimo = 1/2` es un enunciado distinto (`umbral_medio`, `referencia.jl:94-108`) y **no**
se ve afectada.

**Veredicto: REAL.**

---

### D4 · «`λ ∝ SR` era un supuesto, no una derivación» — **REAL (conclusión correcta, demostración circular)**

**Cargo literal** (`ENCARGO-07v2:226-228`):

> El v1 definió `λ(s,SR)=s·λ₀·SR/SR₀` y después “demostró” la cancelación contra el peso. Deriva la
> probabilidad discreta desde las reglas PoAS que realmente correspondan: distancia circular,
> condición `solution_distance ≤ solution_range/2`, todos los chunks ganadores y extremos de
> dominio.

**Dónde está.** `copia/src/modelo.jl:61`:
`tasa_esperada(s, sr, p) = s * p.lambda0 * Float64(sr) / Float64(p.sr0)`. El «origen» de esa
linealidad está en el comentario de `copia/MODELO.md:14-15`: «cada chunk gana si
`solution_distance ≤ sr/2`; con distancia uniforme en `{0,…,M−1}`, la probabilidad es **≈**
`sr/(2M)`». Es una aproximación escrita a mano, y `copia/src/referencia.jl:7-8` la llama
explícitamente «la identidad **asintótica** […] se acota el error de los suelos». Sin embargo
`copia/INFORME.md:15` etiqueta el resultado global como **«demostrado»** y
`copia/PROCEDENCIA.md:38-39` dice «es una **identidad, no una estadística**». Las tres frases no
pueden ser ciertas a la vez.

**Recálculo independiente y exacto** (`run.jl --d4`). El predicado PoAS real acepta, en el círculo
de `2^64` puntos, `|aceptados| = 2·⌊sr/2⌋ + 1` residuos (distancia 0: un punto; distancia `j ≥ 1`:
dos puntos). Luego

```text
T(sr) = (2⌊sr/2⌋+1)/2^64 · ⌊2^128/(sr+1)⌋
      = 1 − ρ/2^128                              si sr es par
      = (sr/(sr+1))·(1 − ρ/2^128)                si sr es impar,   ρ = 2^128 mod (sr+1)
```

Comprobado contra cálculo directo en `Rational{BigInt}` y contra enumeración exhaustiva del dominio
circular (`test/runtests.jl` T1, T5). Consecuencia: hay un **déficit de paridad** de exactamente
`1/(sr+1)` cuando `sr` es impar. Valores: `sr=1` → 1/2; `sr=2049` → 4,878e-4; `sr=2^50−1` → 8,88e-16.
El modelo de CRP-v0.1 **no contiene la paridad**: su `cota_invariancia`
(`copia/src/referencia.jl:17-28`) sólo mide el residuo del suelo, y su «error_rel máx = 1,33e-14»
(`resultados/run-teoria.txt:20`) es exactamente eso.

**Contraste con PCO-v0.1** (`veritas/consenso/puerta-cobertura-v1/`, método distinto y ejecutor
distinto). PCO deriva la tasa **del predicado leído del código** (`src/peso.jl:39-61`), cuenta
`A(SR) = 2⌊SR/2⌋+1` y demuestra la cancelación en enteros exactos **bajo la condición** de que el
predicado sea el de Autonomys (`INFORME.md:78-79`), con el residuo de paridad incluido
(`MODELO.md:41-62`). Es decir: **PCO sí deriva (condicionado a una fuente); CRP-v0.1 supone la
linealidad y luego la «comprueba» contra su propio supuesto.** El resultado final coincide en el
orden dominante; la demostración de CRP-v0.1 no es una demostración.

**Cifras que toca.** `INFORME.md:15` («demostrado»), `INFORME.md:18-21` y `PROCEDENCIA.md:34-46`
(«el producto se cancela», «identidad, no estadística»): **cambia la etiqueta**. El valor
`error_rel máx = 1,33e-14` **se sostiene** como error del suelo, pero **cambia** de significado: no
acota el error total del producto. La frontera `α* = 1/2` **se sostiene**: el residuo de paridad es
`≤ 4,9e-4` con `SR ≥ 2^11` y decrece como `1/SR`.

**Veredicto: REAL.** Formulación exacta: *conclusión correcta, demostración circular, y con un
residuo (el de paridad) que el v1 no ve.*

---

### D5 · «El controlador real no se modeló» — **REAL (el cargo); las cifras se sostienen**

**Cargo literal** (`ENCARGO-07v2:244-247`):

> No fijes directamente `sr_adversario = sr0/K`. Hoy no existe un algoritmo normativo completo del
> controlador destino: C-HDR-06 fija causalidad/interfaz, mientras arranque, ventana, redondeos,
> fusiones tardías y validación multivista siguen pendientes.

**Dónde está.** La familia `CTRL_FIJO / CTRL_REACTIVO / CTRL_INVERSO` vive en
`copia/src/modelo.jl:71-108` y se declara juguete en `copia/MODELO.md:44-52` («Ninguna es “el”
controlador: son una familia»). La tabla de compra de varianza se produce en
`copia/src/rapido.jl:77-94` (`efecto_varianza_sr`) fijando **directamente** `sra = sr0 ÷ K`
(línea 82) y `sr_h = p.sr0`. El propio `INFORME.md:200-203` declara la curva corta con
controlador real **inconclusa**.

**La cifra que más importa, recalculada sin Monte Carlo** (`run.jl --d5`). Con
`A_h ~ Poisson((1−α)T)` y `A_a ~ Poisson(αT·sr_a/sr0)`, el evento es `A_a·w(sr_a) > A_h·w(sr0)`;
la suma doble se evalúa en `BigFloat` a 256 bits con los pesos **enteros exactos** (así los empates
se cuentan sin error de redondeo):

| K | `P(>)` exacta | `P(≥)` exacta | `P(=)` exacta | publicado | diferencia |
|---:|---:|---:|---:|---:|---:|
| 1 | 0,021301871417 | 0,023995492373 | 2,694e-3 | 0,0220 | −0,00070 |
| 4 | 0,095029330297 | 0,095029330297 | 8,165e-116 | 0,0968 | −0,00177 |
| 16 | 0,227470210323 | 0,227470210323 | 3,710e-101 | 0,2435 | **−0,01603** |
| 64 | 0,314997908312 | 0,314997908312 | 1,713e-97 | 0,3078 | +0,00720 |

Masa de Poisson omitida al truncar las colas: ≤ 2,8e-74.

**Reproducción y ruido del MC.** Ejecutando `efecto_varianza_sr` del instrumento original
(`auditoria/copia`, semilla por defecto) se obtiene **exactamente** lo publicado:
`0,022 / 0,09675 / 0,2435 / 0,30775`. Barriendo **60 semillas maestras × 4000 réplicas**:

| K | media de 60 corridas | sd de una corrida | exacto | min / max observados |
|---:|---:|---:|---:|---|
| 1 | 0,02114 | 0,00221 | 0,02130 | 0,0168 / 0,0268 |
| 4 | 0,09558 | 0,00374 | 0,09503 | 0,0878 / 0,1050 |
| 16 | 0,22771 | 0,00674 | 0,22747 | 0,2140 / 0,2448 |
| 64 | 0,31470 | 0,00686 | 0,31500 | 0,2985 / 0,3310 |

La media de 60 corridas coincide con el valor exacto dentro de 6e-4 en los cuatro casos, y el
`0,2435` publicado es el **máximo** de la muestra de 60: un valor de cola de la semilla concreta,
no un sesgo del método.

**Sobre el sesgo de semillas consecutivas de `P-ZRX/P-PUERTA/`.** Reproducido: la autocorrelación
lag-1 de la primera salida de `StableRNG(semilla + i)` es **−0,4275** (P-PUERTA reporta ≈ −0,43).
Medido en **este** estimador, en cambio, el efecto es **menor que el ruido**: el sesgo de la media
de 60 corridas frente al exacto es ≤ 6e-4 y la desviación típica observada coincide con la
binomial (por ejemplo K=16: observada 0,00674 frente a la binomial 0,00663), porque cada réplica
consume 800 draws de Poisson y la correlación entre semillas se diluye. **Se reporta como
medición, no como defecto confirmado del resultado.**

**¿Depende del defecto D1?** **No.** `efecto_varianza_sr` → `simular_raza`
(`copia/src/rapido.jl:87`) → `simular_rama_rapido` (líneas 67-68): ese camino **no toca GDR ni el
DAG**. La tabla de varianza es puramente un enunciado sobre dos procesos de Poisson compuestos.

**Cifras que toca.** `INFORME.md:93-101` y `PROPUESTA.md:20-23` («de 2,2 % a 30,8 %»): **cambian**
a **2,13 % → 31,50 %**, sin Monte Carlo y con 6 cifras significativas. `E[trabajo_adv]`
(179,9 / 179,7 / 180,9 / 178,0): **se sostiene** (el valor exacto es 180,0 en los cuatro casos; las
cifras publicadas son medias MC de 4000 réplicas). La afirmación cualitativa «el adversario compra
cola con varianza, sin mover la media» **se sostiene y ahora está demostrada, no muestreada.**

**Veredicto: REAL.** El modelo es el juguete que el cargo describe; las cifras resisten.

---

### D6 · «Los rojos asimétricos no estaban medidos» — **REAL A MEDIAS**

**Cargo literal** (`ENCARGO-07v2:258-260` y guía del encargo P-CRP1 §2):

> Define eficiencia de trabajo, no una fracción global de bloques […]
> `PROCEDENCIA.md` §3.2 acota los rojos asimétricos con `α > (1−f)/(2−f)` y afirma que «la Δ medida
> es 0,26–0,60 s».

**Dónde está.** `copia/PROCEDENCIA.md:50-68`. La fórmula: si la honesta pierde fracción `f` de su
trabajo por rojos y el adversario no pierde nada, el adversario gana si
`α > (1−α)(1−f)` ⟺ `α(2−f) > (1−f)` ⟺ **`α > (1−f)/(2−f)`**.

**La fórmula es correcta.** Verificada exactamente (`run.jl --d6`):

| f | Δ de origen | `α_min = (1−f)/(2−f)` | publicado |
|---:|---:|---:|---:|
| 0,0000 | 4 s | 0,500000 | 0,5000 |
| 0,0020 | 8 s | 0,499498 | 0,4995 |
| 0,0828 | 12 s | 0,478384 | 0,4784 |
| 0,2858 | 16 s | 0,416590 | 0,4166 |

**La etiqueta de la Δ, no.** `PROCEDENCIA.md:64` escribe «La Δ **medida** en
`veritas/finalidad/delta-medido-v1/` es 0,26–0,60 s». Fuentes abiertas:

- `veritas/finalidad/delta-medido-v1/INFORME.md:1-9`: título «**Δ medido en red sintética P2P**»,
  y «Estado: **esto mide, no decide**». Su `MODELO.md` §2 etiqueta `MR` = «medida en red ZEROX
  (**ninguna disponible**)» y las latencias como `H` (hipótesis de escenario) y `MS` (medida en
  simulación concreta).
- `veritas/finalidad/delta-medido-v1/INFORME.md:413`: «Δ_99 p99 queda en **0,26–0,60 s**».
- `P-ZRX/P-2.1/SINTESIS.md:28`: «**La Δ es simulada (DMS-v0.1), no medida en red.**»
- `P-ZRX/P-2.1/ENCARGO.md:497`: «DMS-v0.1 es **simulada con latencias supuestas**».

Llamarla «la Δ medida», sin el calificador de red sintética, es un sobre-enunciado. La etiqueta
correcta es **medida en simulación**, no medida de red.

**Las fracciones rojas no salen de `delta-medido-v1`.** Están en
`research/scripts/d9-ronda9a/r9a_a6_frontera_delta.py:31`
(`DELTA0_MEDIDO = {4.0: 0.0000, 8.0: 0.0020, 12.0: 0.0828, 16.0: 0.2858, …}`) y las reproduce
`d9-ronda11a`. Son simulaciones históricas con Δ **fijada a mano**, exactamente el uso que el
propio D6 prohíbe («no dibujes Δ marginales iid y los llames vistas de red coherentes»). La
constante se llama `DELTA0_MEDIDO`, y de ese nombre viene la confusión.

**El factor «25 veces».** `PROCEDENCIA.md:64-65` dice «unas **25 veces** por debajo del primer
escalón de la tabla». Con los números que él mismo cita: `4 / 0,60 = 6,7` y `4 / 0,26 = 15,4`.
Para llegar a 25 hay que comparar `16 s` — el **último** escalón — con `0,60 s`. **No se
reproduce.**

**Qué se sostiene.** Que la fórmula `(1−f)/(2−f)` es correcta; que con `f = 0` (el caso de la Δ
sub-segundo, por debajo del primer escalón tabulado) el umbral no se mueve; y que el efecto es un
hueco **acotado**, no cerrado por medición directa — esto último lo dice el propio
`PROCEDENCIA.md:67-68`. Lo que cae es la etiqueta «medida» y el factor «25×». Además, la
definición de `η_x(T)` que exige D6 (ventana, punta/contexto de color, prefijo común, raíz
implícita) **no está implementada en ninguna parte**: `f` entra como fracción global de bloques.

**Veredicto: REAL A MEDIAS.**

---

### D7 · «Multistream era una identidad tautológica» — **REAL**

**Cargo literal** (`ENCARGO-07v2:300-301`):

> El v1 implementó `S·α/(1−α+S·α)` y testeó la misma fórmula. Eso no demuestra que `S` flujos
> puedan sumarse.

**Dónde está.** `copia/src/modelo.jl:159`:
`cuota_multistream(α, S) = S * α / (1 - α + S * α)`; y el test
`copia/test/runtests.jl:72-76`:

```julia
@test cuota_multistream(0.5, 1) ≈ 0.5
@test 1 / (1 + 3) == 0.25
@test cuota_multistream(0.2, 5) > 0.5
```

Las tres líneas comparan la **definición** con la **definición**. `run.jl:115-119` sólo evalúa
`cuota_multistream(0.45, S)` y `1/(S+1)` para `S` de una lista literal.

**Qué queda demostrado.** Exactamente dos cosas: (a) que la fórmula aplicada a `α = 1/2` da `1/2`
(porque `S·α = 1−α` con `α = 1/(S+1)`), y (b) que `α_min = 1/(S+1)` despeja esa igualdad. **Nada
sobre si `S` flujos pueden sumarse.** La cuota `Sα/(1−α+Sα)` es una **definición aditiva**, no una
derivación: no aparece compatibilidad de `past(B)` por slot, ni prefijos comparados en `slot(X)`,
ni `P(max_i{W_i−d_i} > W_pub)`, ni los controles de D7 (flujos idénticos ⇒ `S=1`; iid con déficit
cero ⇒ `1−E[F_{W|W_pub}(W_pub)^S]`), ni cotas de unión.

**Etiqueta interna incoherente.** `INFORME.md:135` llama al multistream «el único vector
**medido** que baja el umbral» y en la misma frase lo etiqueta «**no demostrado / condicional**».
No se midió ningún flujo: se evaluó una fórmula.

**Cifras que toca.** La tabla `α_min` de `INFORME.md:131-133` (`0,333/0,200/0,111/0,059/0,040`) y
la de `PROCEDENCIA.md:75-77`: **la aritmética se sostiene**; **cae** la palabra «medido» y
**cae** «el único vector medido». La conclusión de D7 (el toy aditivo exige `α > 0,04` para deriva
positiva con `S = 24`, no superación estricta) está bien formulada en `ENCARGO-07v2:336-338` y el
v1 no la contradice.

**Veredicto: REAL.**

---

### D8 · «El fixture U2/U3″ entre ramas era insuficiente» — **REAL**

**Cargo literal** (`ENCARGO-07v2:342-343`):

> No acredites “azul en su propia rama” mediante `es_ancestro(x,x)`. El color no es propiedad
> global del bloque: registra `(punta/contexto, bloque) → color` e inspecciona conjunto azul y
> `blue_work` reales en cada punta.

**Dónde está.** `copia/src/rapido.jl:368-369`:

```julia
azulX = GDR.es_ancestro_rapido(est3, 2, 2) && okX
azulY = GDR.es_ancestro_rapido(est3, 3, 3) && okY
```

y en GDR-v0.2 (`veritas/consenso/ghostdag-rank-v1/src/rapido.jl:43`):

```julia
es_ancestro_rapido(est::EstadoRapido, a::Int, b::Int) = a == b || a in est.anc[b]
```

Con `a == b` el primer operando del `||` es verdadero y Julia cortocircuita. **Reproducción
mínima** (`gdr-d1-d8.jl`, apartado D8(a)): `es_ancestro_rapido(est3, 2, 2) = true` y
`es_ancestro_rapido(est3, 3, 3) = true`, sin consultar jamás `est.anc`. Luego
`azulX && azulY` se reduce a `okX && okY`, es decir a «los bloques se añadieron». El resultado
publicado `run-gdr.txt:39` («ambas azules en su rama=**true**») **no aporta evidencia de color**.

**Cobertura de los cuatro casos que D8 exige:**

| caso | cobertura en CRP-v0.1 |
|---|---|
| dos copias del mismo billete en una rama compatible | SÍ (`est`, bloques `A1`/`A2` + fusionador `C`) |
| dos ramas disjuntas con el mismo billete y flujo compatible | SÍ (`est3`, `X` e `Y`) |
| dos ramas con prefijos PoT **realmente divergentes** | **NO** |
| intento de fusión de cada caso | PARCIAL |
| orden explícito: flujo → validez → U2 → color U3″ | **NO** (no hay ninguna etapa de flujo PoT) |

**Qué se sostiene.** Las filas que sí se miden: «mismo billete dos veces dentro de una rama ⇒ 1
azul y 1 `rojo_U3`», «U2 rechaza el mismo billete en el pasado (`:u2`)» y «un fusionador ve una
azul y la otra `rojo_U3`» **se sostienen** (medidas con GDR-v0.2). La conclusión cualitativa de
`INFORME.md:150-151` («U3″ bloquea dentro y no entre ramas disjuntas») **se sostiene** para los
casos probados.

**Cifras que toca.** La fila «Mismo billete en dos ramas disjuntas | ambas válidas y **azules en su
propia rama**» de `INFORME.md:147`: la validez se mide, **el color no**: **cae como medición**.

**Veredicto: REAL.**

---

### D9 · «`S = 24` no fue una medición del v1» — **REAL**

**Cargo literal** (`ENCARGO-07v2:352-372`, extracto):

> Separa tres magnitudes: `S_escenario`, `S_microbenchmark`, `S_adversario`. […] No conviertas
> `floor(100000/4161)=24` en capacidad acreditada.

**Dónde está.** `copia/run.jl:117`: `for S in (1, 2, 4, 8, 16, 24, 64)`. `S` es un literal del
bucle; el instrumento sólo evalúa `cuota_multistream(0.45, S)` y `1/(S+1)`. **No hay ninguna
medición de IOPS, ni de lecturas aleatorias, ni de núcleos, ni de PoT** en todo CRP-v0.1. La cifra
se justifica en prosa en `copia/PROCEDENCIA.md:79`: «`S ≈ 24` es el límite de IOPS de un SSD de
100 k».

**Origen rastreado.** `fld(100000, 4161) = 24` (verificado en `test/runtests.jl` T11). La constante
`4161.0` aparece como «lecturas_4TiB» en
`P-ZRX/P-2.1/veritas/consenso/ancla-inyeccion-v2/src/puerta.jl:62` y en
`P-ZRX/P-PUERTA/veritas/consenso/puerta-cobertura-v1/src/cobertura.jl:40`. El propio encargo 07v2
prohíbe expresamente ese paso (`ENCARGO-07v2:372`).

**Estado de las tres magnitudes:**

| magnitud | estado en CRP-v0.1 |
|---|---|
| `S_escenario` = 24 | existe, pero **sin etiquetar como elección de barrido** |
| `S_microbenchmark` | **NO EXISTE**: ningún microbenchmark de I/O en el instrumento |
| `S_adversario` | **NO EXISTE**: sin perfil de hardware, sin p50/p95/p99, sin profundidad de cola, sin distinguir caché de página de almacenamiento |

**Cifras que toca.** `PROCEDENCIA.md:79` («límite de IOPS de un SSD de 100 k»), `INFORME.md:131-137`
y `SPEC.md:3782` / `TAREAS.md:187-194` («0,040 con S = 24, que es el límite de IOPS…»): **caen como
medición**. La parte paramétrica `P(α,S)` **se sostiene** condicionada a `S`.

**Veredicto: REAL.**

---

### D10 · «“Ataque gratis” estaba sobre-enunciado» — **REAL**

**Cargo literal** (`ENCARGO-07v2:382-396`, extracto):

> Contabiliza por separado: espacio adicional; CPU/PoT/IOPS; energía; recompensa y tarifas a las
> que se renuncia durante la retención; duración real desde la bifurcación hasta la decisión;
> capital/hardware ya hundido frente a coste marginal. […] La conclusión máxima permitida sin un
> modelo económico completo es “cero espacio plotteado adicional bajo los supuestos declarados”, no
> “ataque gratis”.

**Dónde está.** `copia/INFORME.md:117-120` («el **coste marginal de recurso del ataque es 0**»,
«el ataque es “gratis” en recursos»), alimentado por `copia/run.jl:259-269`, que sólo calcula

```text
coste_op(PoST)/coste_op(PoW) = T_retención/T_a,   con  T_retención ≈ Δ·conf
```

Una afirmación sin derivación, sin unidades y sin ninguna cifra de recursos.

**Contabilidad por término** (`run.jl --d10`):

| término | estado en el instrumento |
|---|---|
| espacio adicional plotteado | 0 — el único término realmente modelado |
| CPU / PoT / IOPS | **no contado** (el PoT se ejecuta igual en la rama privada) |
| energía | **no contado** (no aparece en ninguna cifra) |
| recompensa y tarifas renunciadas | **parcial**: «≈ Δ·conf», sin derivación ni unidades |
| duración bifurcación→decisión | **no medido** |
| capital hundido vs coste marginal | **no separado** (el modelo sólo tiene la fracción `α`) |

Además, el escenario que el propio D10 señala —«si el adversario publica la misma producción en la
historia honesta, ésta crece con su aportación»— está contemplado en el modelo
(`umbral_medio(; publica=true)`, `copia/src/referencia.jl:94-100`) pero el §4 del informe no lo
conecta con el coste: mezcla el régimen de publicación con el de retención.

**Cifras que toca.** `INFORME.md:117-120` («gratis», «coste marginal 0»): **caen**. La conclusión
admisible es «**cero espacio plotteado adicional** bajo los supuestos declarados», como dice el
propio encargo.

**Veredicto: REAL.**

---

## 2 · Defectos que no estaban en la lista (D11–D14)

### D11 · La tabla «work/slot ≈ s» con GDR no tiene incertidumbre y su error llega al 30 % — **REAL**

**Dónde.** `copia/src/rapido.jl:287-303` (`experimento_gdr_invariancia`) usa **una sola
realización** con `n_slots = 200` y publica `trabajo/slot` a 4 decimales. Lo publicado
(`resultados/run-gdr.txt:22-30`, y `INFORME.md:27` que lo resume como «≈ `s` (tabla)»):

| s | trabajo/slot | error relativo frente a `s` |
|---:|---:|---:|
| 0,10 | **0,0700** | **−30,0 %** |
| 0,10 | 0,1013 | +1,3 % |
| 0,30 | 0,3350 | +11,7 % |
| 0,30 | 0,2675 | −10,8 % |
| 0,50 | 0,4800 | −4,0 % |
| 0,50 | 0,4850 | −3,0 % |

La fila de `s=0,10` con `sr=sr0` tiene **14 bloques** en 200 slots: su error estándar relativo es
`1/√14 ≈ 27 %`. Publicar ese 0,0700 como confirmación de «≈ s» sin ningún intervalo es
indefendible, con independencia de D1.

### D12 · Las dos «mediciones» de trabajo de una rama difieren exactamente en `w(v)` — **REAL**

**Dónde.** `copia/src/rapido.jl:266`: `medir_rama` devuelve `blue_work = est.gd[v].bw`, y
`GDR src/rapido.jl:183-188` calcula `gd[B].bw = Σ_{x ∈ blueset(B)\{B}} w(x)` — el bloque `B` **no**
aporta su propio peso. `copia/src/rapido.jl:275-284`: `medir_rama_normalizada` suma
`peso_relativo(est.srs[x], sr0)` sobre `blueset(v)`, que **sí incluye** `v`
(`GDR src/modelo.jl:249`, `Set{Int}([tip])`). Las dos funciones dicen medir «el trabajo de la
rama» y difieren en exactamente `w(v)`. Ninguna de las dos es incorrecta por separado; usarlas
como si fueran la misma magnitud no está justificado en el informe, y `experimento_gdr_invariancia`
además reconstruye el trabajo aritméticamente (`copia/src/rapido.jl:296-297`) en vez de medirlo.

### D13 · Tope silencioso de 200 bloques por slot — **REAL**

**Dónde.** `copia/src/rapido.jl:211`: `k = min(poisson_knuth(rng, mu), 200)`. El comentario dice
«tope de simulación: evita explotar si un controlador patológico dispara `sr`», pero el tope se
aplica **siempre**, no se reporta y no existe en `MODELO.md`. Con `CTRL_INVERSO` el `sr` se va al
mínimo y `mu → 0`, así que en la práctica no se alcanza; en cualquier caso un truncamiento no
declarado en el kernel es un defecto de contrato.

### D14 · La validación de la curva corta acepta un factor 20 — **REAL**

**Dónde.** `copia/test/runtests.jl:43`: `@test 0.05 < dp / ex < 50`. Una tolerancia de un factor
20 entre la DP y la ruina exacta no es una validación de nada. En mi recálculo, la comprobación
equivalente se hace con tolerancias de 1e-8 (sistema racional) y 1e-9 (enumeración).

### D15 · `modo_fuentes` cita una ruta que ya no existe — **REAL (menor)**

`copia/run.jl:65` lista `deepseek/veritas/consenso/prueba-recursiva-v1/INFORME.md`. Comprobado hoy
desde la raíz: **FALTA** (la auditoría se migró a `veritas/consenso/prueba-recursiva-v1/`). El
modo `--fuentes` lo reportaría como faltante; no hay `run-fuentes.txt` publicado, así que la
comprobación de fuentes nunca se archivó.

---

## 3 · Cifras: qué se sostiene, qué cambia y qué cae

El detalle fila a fila está en `CIFRAS.md`. Resumen:

**Caen (8).**
1. La tabla `P(alcance)` por granularidad, `g ∈ {4, 16, 64, 256}` (`INFORME.md:50-52`) — D2.
2. La tabla «work/slot ≈ s» con GDR (`INFORME.md:27`, `run-gdr.txt:22-30`) — D1 y D11.
3. La etiqueta `α_mínimo → 1/2⁺` / «por arriba» (`INFORME.md:43`, `run-corto.txt:49`) — D3.
4. «Coste marginal de recurso del ataque = 0» y «el ataque es gratis» (`INFORME.md:117-120`) — D10.
5. «`S ≈ 24`, el límite de IOPS de un SSD de 100 k» como base de una cifra (`PROCEDENCIA.md:79`) — D9.
6. «La Δ **medida** es 0,26–0,60 s» y «unas 25 veces por debajo» (`PROCEDENCIA.md:64-65`) — D6.
7. «Mismo billete en dos ramas disjuntas ⇒ **azules en su propia rama**» (`INFORME.md:147`) — D8.
8. «El único vector **medido** que baja el umbral» (`INFORME.md:135`) — D7.

**Cambian (3).**
1. `P(adv > hon)`: `0,022 / 0,097 / 0,244 / 0,308` → **`0,021302 / 0,095029 / 0,227470 / 0,314998`**
   (exacto, sin MC) — D5.
2. `α_mínimo(d, ε=0,10)`: `0,317 / 0,405 / 0,452 / 0,476 / 0,489` →
   **`0,360 / 0,418 / 0,456 / 0,477 / 0,489`** (evento estricto) — D3.
3. La invariancia `sr↔peso`: «error_rel máx = 1,33e-14» → **se sostiene como residuo del suelo, pero
   el déficit de paridad `1/(sr+1)` (hasta 4,878e-4 con `SR = 2049`) no estaba contado** — D4.

**Se sostienen.**
- `α_mínimo = 1/2` como **frontera de deriva del modelo contable** (media), en los dos regímenes —
  con la etiqueta corregida: el residuo de paridad de D4 y la varianza de D5 lo rodean, no lo
  mueven.
- La frase «la contribución del DAG es de varianza, no de umbral» — **reforzada** por la tabla
  corregida de D2.
- `α_min = 1/(S+1)` como **identidad condicional** al diseño del flujo (D7); el toy aditivo exige
  `α > 1/(S+1)` para deriva positiva, no superación.
- La tabla de rojos asimétricos `0,5000 / 0,4995 / 0,4784 / 0,4166` (fórmula exacta) — D6.
- `E[trabajo_adv] ≈ α·T = 180` — D5 (el valor exacto es 180,0 en los cuatro `K`).
- U2/U3″ **intra-rama** y **de fusión**; U2 rechaza (`:u2`) — D8.
- La corrección de la cuenta del encargo (`α > 1` al publicar, no `0,5`) — `PROCEDENCIA.md:91-99`.
- Suite `45/45` con `--check-bounds=yes`, `HUELLAS.sha256` exit 0, escalado 1→24 hilos con
  resultados idénticos, `Project.toml` con sólo dependencias usadas.
- La amplificación `16×` de `sr_val/sr_peso` (aritmética exacta, `PROPUESTA.md:11-12`).

**No determinables.**
- `coste_op(PoST)/coste_op(PoW) → T_retención/T_a` (`INFORME.md:115`): `T_retención ≈ Δ·conf` no
  está derivado, y `Δ` es simulada (D6). No se puede cerrar con las fuentes disponibles.
- Los tiempos y asignaciones de `INFORME.md:159-160`: no los reejecuté con `BenchmarkTools` en el
  entorno original; mi propia medición está en `auditoria/veritas/seguridad/crp1-defectos-v1/resultados/BENCH.txt`.

---

## 4 · ¿Se mantiene el veredicto de `PROCEDENCIA.md` («sobrevive sin recortes»)?

**No.** `PROCEDENCIA.md:6-7` afirma que CRP-v0.1 es «el único cuyo veredicto principal sobrevive a
la validación sin recortes» y `PROCEDENCIA.md:34-36` titula «El umbral es `1/2`, igual que PoW».

Lo que sobrevive es **una frase**: la frontera de deriva del modelo contable de media es `1/2`, y
el `SR` endógeno no la mueve en media. Lo que no sobrevive es el **paquete**: la tabla de cola
corta que ilustra la contribución del DAG (D2), el evento del contrato en la curva `α_mínimo` (D3),
la demostración de la cancelación (D4), la base de la cifra de varianza como *medición* (D5), la
medición de `S` (D9), la contabilidad de coste (D10) y el respaldo de color del fixture U2/U3″ (D8).
La propia `PROCEDENCIA.md` acuñó la regla —«reproducir no es validar»— que aquí se aplica contra
ella: Claude **reprodujo** (yo también reproduje, exactamente, todo lo publicado) y de ahí pasó al
veredicto sin abrir la DP, la pmf ni el fixture.

Y `ENCARGO-07v2:145` prohíbe expresamente «en la liga de PoW» y «seguro al 50 %» mientras quede una
hipótesis necesaria pendiente. Queda más de una: el acoplamiento espacio↔solución (D4), el
controlador real (D5), la unicidad del flujo PoT (D7) y la asimetría de rojos (D6). **No se admite
ninguna de las dos frases**, y esta auditoría no las usa.

---

## 5 · Lo que esta auditoría NO resuelve

1. **No cierra la curva corta con el controlador real.** R-FIN-13′ sigue sin especificar; lo que
   hice es recalcular la familia de juguete con un método exacto, no modelar el controlador del
   SPEC.
2. **No cierra la cota inferior rigurosa de D2.** El intervalo certificado de `g=256` es
   `[2,03e-1010, 3,34e-271]`. El extremo superior (martingala, exacto) es el útil y basta para
   refutar lo publicado; el inferior es flojo porque acota la posición final y no el mínimo del
   paseo. El valor puntual `1,95e-272` es una DP de masa conservada **estable** frente a la ventana,
   validada contra la implementación de CRP-v0.1 donde ésta es fiable, pero no es una cota
   certificada.
3. **No mide `S_adversario`.** No he hecho ningún benchmark de I/O (el encargo P-CRP1 no lo pide y
   el hardware/dataset no está disponible en esta zona). Para D9 basta con mostrar que el v1
   tampoco lo midió.
4. **No reejecuté los benchmarks del instrumento.** El escalado 1→24 hilos sí lo verifiqué en
   `ESCALADO.txt` (resultados idénticos); las asignaciones y tiempos de `INFORME.md:159-160` no los
   reproduje.
5. **No audité CRP-v0.2 ni v0.3.** Están en `P-ZRX/rescate-deepseek/veritas/seguridad/` y los
   audita `P-ZRX/P-CRP/`. Aquí sólo se comprueba si los diez defectos son reales en v0.1.
6. **No decidí nada de consenso.** No fijo `S`, ni `Δ`, ni `k`, ni `α`, ni el umbral. Todo lo que
   publico son recálculos de las cifras del instrumento con sus propios parámetros.
7. **No certifiqué el sesgo del MC de `P-PUERTA` para otros estimadores.** Medí que la
   autocorrelación es real (`−0,4275`) y que en **este** estimador el efecto queda por debajo del
   ruido. Eso no generaliza a otros instrumentos.
8. **No validé el conteo de residuos PoAS contra la fuente de Autonomys.** Lo leí citado en
   PCO-v0.1 (`src/peso.jl:39-61`) y verifiqué la fórmula por enumeración exhaustiva en dominios
   pequeños; no abrí el Rust de `PDF/autonomys-subspace/` en esta auditoría.

---

*Recálculos: `auditoria/veritas/seguridad/crp1-defectos-v1/` (Julia CPU, suite 60/60).*
*Fichas GDR: `auditoria/gdr-d1-d8.jl` → `auditoria/salidas/gdr-d1-d8.txt`.*
*Reproducción del instrumento: `auditoria/salidas/repro-tests.txt`.*
