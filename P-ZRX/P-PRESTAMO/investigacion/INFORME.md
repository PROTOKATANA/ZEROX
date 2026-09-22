# INFORME — espacio-prestado-v1 · El espacio honesto prestado a una rama privada

**La respuesta, en una frase:** con la contabilidad de espacio del encargo, el umbral de deriva baja
**exactamente** en proporción al espacio prestado — `α* = (η_h − η_a·β_d − (η_h+η_a)·β_x)/(η_h+η_a)`,
que con `η = 1` es `(1 − β_d − 2β_x)/2`, y por tanto **cada unidad de espacio alquilado en
exclusiva baja el umbral el doble que cada unidad que farmea doble**; pero el atacante llega a la
ventana **con un déficit**, no con el empate de medias, y por eso dentro de `F` un atacante del
33 % **no gana con probabilidad no despreciable en ningún reparto** de los barridos: con
`F = 1.019`, `α = 0,33` y `β_d = 0` la probabilidad es `9,75·10^-108`, y **la ventana larga es
peor para él** (el mínimo medido es `8,5·10^-277` con `F = 3.600`). La frontera de deriva **no es
la frontera de la ventana**: la transición está en el cruce de `g = 0`.
Y el requisito de `CANDIDATA.md` —«el consenso base debe seguir siendo seguro suponiendo que el
doble farming es barato»— **se cumple dentro de `F`** con espacio prestado (la ventana no se
rompe) pero **no aguanta la deriva**: sin castigo, `β_d` es gratis para el granjero y el umbral
baja a `(1−β_d)/2`, así que **el castigo es imprescindible para sostener el umbral en horizonte
largo**, no para sostener la ventana. La retención necesaria tiene una región concreta:
`(ρ_ret = 0,10, T_v ≳ 3.000)` en las unidades declaradas, y **`T_v` debe superar `F`**.

**Categoría:** `seguridad` (dominante); `consenso` y `economía` (secundarias). El tema dominante es
si el consenso base aguanta el espacio prestado y cuánto castigo hace falta: por eso
`veritas/seguridad/espacio-prestado-v1/`.

**Instrumento:** `investigacion/veritas/seguridad/espacio-prestado-v1/` (Julia 1.13.0, CPU,
`veritas/julia.sh`, sin Python). Su ficha técnica —pregunta, método, verificación, rendimiento,
reproducción y límites del aparato— está en `INFORME-instrumento.md`, en el mismo directorio.
**Semilla:** `0x5052455354414d4f`. **Fecha:** 2026-09-21.

**Presupuesto declarado antes de ejecutar:** 8 hilos, 8 GiB de RAM, 256 MiB de disco, minutos por
tarea. **No se agotó.** `uptime` en los benchmarks: carga `1,15` con 4 hilos declarados ⇒ los
tiempos son **«medidos con carga ajena»** cuando la carga superó los hilos declarados (§7).

**Advertencia que gobierna todo el informe.** `α`, `β_d` y `β_x` se tratan como **fracciones de
ESPACIO**. El puente espacio → tasa **no existe** en ningún instrumento del repositorio
(`P-ZRX/P-CRP/auditoria/DEFECTOS.md` C1; `ADENDA-1.md` §A). Todo resultado de **F2 (ventana)**
está **condicionado a H-PUENTE** (`HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md` H1). **F1 (deriva) no
depende de ese puente**: es aritmética exacta sobre las medias.

---

## 0 · Respuestas cortas a las seis preguntas

| # | Pregunta | Respuesta | Etiqueta |
|---|---|---|---|
| **F1** | La superficie `α*(β_d, β_x, η_h, η_a)` y sus casos particulares | `α* = (η_h − η_a β_d − (η_h+η_a) β_x)/(η_h+η_a)`. Con `η=1`: `(1−β_d−2β_x)/2`. Contiene `β_d > 1−2α` y `α+β_x > 1/2` como casos exactos. `β_x` baja el umbral **el doble** que `β_d` | `demostrado` |
| **F2** | `P_win` de los tres eventos en la ventana `F`; a partir de qué `β_d` un atacante del 33 % gana dentro de `F` | Con paso ±1 de peso uniforme y anclaje en empate, el adversario arranca con déficit `d = (μ_p−μ_a)·F > 0` y **la ventana no le da nada**: `P = 9,75·10^-108` con `F=1.019, α=0,33, β_d=0`, y **peor con ventana más larga** (`8,5·10^-277` con `F=3.600, α=0,20, β_d=0,34`). La probabilidad salta a orden 1 **sólo al cruzar `g = 0`** (`β_d > (1−2α)/(1−α)`), que es una condición de **deriva**, no de ventana: con `α=0,33` el cruce está en `β_d = 0,5075` | `demostrado` (DP exacta) + `derivado` (la rejilla) + `condicionado` a H-PUENTE |
| **Notación** | Convención de `p` y `q`, y una acusación propia retirada | `BASELINE.md` escenario 0 **es correcto y no se toca**: allí `p` es la tasa del **honesto** y `q` la del **adversario**, luego `q < p` es adversario en minoría y `(q/p)^(d+1) < 1`. Una versión anterior de este informe lo acusó de tener la razón invertida y propuso `(p/q)^(d+1)`, que **da valores > 1** (`17,09` en el ejemplo con `p=3/5, q=2/5, d=6`). **El error era de lectura y se retira.** El kernel reproduce la fórmula de `BASELINE.md` con exactitud (§2.4) y **ninguna tabla cambia** | `verificado en fuente` + `demostrado` |
| **F3** | Equilibrio de `β_d` sin castigo y con él; ¿es el castigo imprescindible? | **Sin castigo, farmear doble es dominante y gratis**: el soborno necesario es 0 y `β_d` sube hasta agotar el espacio reclutable, con lo que `α*` cae a `(1−β_d)/2` y el umbral se pierde. **Con castigo**, `β_d` de equilibrio es la solución de `b(β_d)·N(β_d) = V`; **el castigo es imprescindible para el umbral en horizonte largo**, no para la ventana | `derivado` |
| **F4** | Coste del ataque, relativo y absoluto | Relativo: `b* = κ·q·(ρ_ret·ingreso·T_v + c_r + ingreso·M)` por reclutado, en unidades de emisión. Absoluto: el soborno **más** `α` propio (que hay que plotear y no se compra) **más** `0,092–0,190` núcleos de PoT por granjero y slot. Con `F = 3.600` y `κ·q = 1`, el PoT de la rama privada cuesta `0,092·3.600 ≈ 331` núcleos·slot por reclutado, y **lo que el atacante no puede comprar es el espacio propio ni el tiempo de maduración** | `derivado` + `estimado` |
| **F5** | Región mínima `(ρ_ret, T_v)`; sensibilidad a `κ`, `q_gana`, fragmentación; `T_v` frente a `F` | Con `V = 400` u.e. por reclutado y `n = 100`, la región que cumple `pérdida > soborno` es `ρ_ret·T_v ≳ 4.000` en las unidades declaradas: `ρ_ret = 0,10` exige `T_v ≳ 3.000`; `ρ_ret = 0,25` exige `T_v ≳ 1.200`. **`T_v` MUST superar `F`** (la evidencia aparece dentro de `F` más el margen de inclusión): con `F = 7.200`, `T_v ≥ 7.200` **no basta** si `ρ_ret` es pequeño. Frente a **`κ = 0`** (publicar solo la rama ganadora), **censura total (`q = 0`)** y **`V` sin cota**, **no hay `(ρ_ret, T_v)` que valga** | `derivado` |
| **F6** | Coste para el honesto que firma doble por accidente con tasa `ε_h` | Pérdida esperada anual `= ε_h·(ρ_ret·ingreso·T_v + c_r + ingreso·M)`. Con `ε_h = 10^-3`/año y la región de F5, el honesto accidental paga **la misma** `ρ_ret·T_v` que el atacante: no hay forma de castigar al atacante sin castigar al honesto accidental, y el compromiso es lineal en `ε_h` | `derivado` |

---

## 1 · El modelo, las unidades y quién es espacio y quién es tasa

**Reparto.** Espacio total normalizado a 1. `α` = espacio propio del atacante, **retirado** de la
pública. `β_d` = espacio honesto que trabaja en **las dos** ramas. `β_x` = espacio alquilado que
**abandona** la pública. Leales = `1 − α − β_d − β_x`. Es el modelo del PROMPT §2, sin cambios.

**Deriva (en unidades de peso por unidad de tiempo).**

```text
g = η_a·(α + β_d + β_x) − η_h·(1 − α − β_x)
```

**Por qué `β_d` no aparece en el término de la pública:** el doble granjero **sigue publicando**
(no abandona), así que la pública conserva `1−α−β_x` bloques por unidad de tiempo sea cual sea
`β_d`. Lo que `β_d` hace es **añadir** peso a la privada. Ésa es toda la asimetría económica del
doble farmeo y es la razón de que `β_x` valga el doble: cada unidad de `β_x` quita 1 a la pública
**y** suma 1 a la privada; cada unidad de `β_d` sólo suma 1 a la privada.

**Frontera exacta.** Despejando `g = 0` en `α`:

```text
α*(β_d, β_x, η_h, η_a) = (η_h − η_a·β_d − (η_h + η_a)·β_x) / (η_h + η_a)
```

**Casos particulares exactos** (los que el PROMPT §2 pide comprobar):

| caso | condición | `α*` con `η_h = η_a = 1` |
|---|---|---|
| sin espacio prestado | `β_d = β_x = 0` | `1/2` |
| sólo doble farmeo | `β_x = 0` | `(1−β_d)/2`; `β_d > 1−2α` ⟺ `g > 0` |
| sólo alquiler exclusivo | `β_d = 0` | `1/2 − β_x`; `α + β_x > 1/2` |
| los dos | — | `(1 − β_d − 2β_x)/2` |

La tabla completa, en `Rational{BigInt}` y con `g(α*) = 0` exacto en las 12 filas, está en
`veritas/seguridad/espacio-prestado-v1/resultados/F1-superficie.tsv`. La identidad `g(α*) = 0` se
comprueba además con `α* ± 10^-9` (signo estricto a los dos lados) en los tests.

**Lo que `α*` NO es.** Es una **identidad aritmética del modelo contable de medias**, no el umbral
del protocolo (`BASELINE.md` §A: prohibido escribir «el umbral de ZEROX es 1/2»; `CIFRAS.md` A1:
«se sostiene» sólo como frontera de deriva). Y `α*` presupone que `η_h` y `η_a` **no dependen de
`α` ni de `β`**: si esos productos cambian con el reparto, hay que resolver y publicar **todas** las
raíces y regiones de signo (`BASELINE.md` §B.2).

---

## 2 · F2 · La ventana `F`: por qué la deriva no decide dentro de `F`

### 2.1 El montaje exacto

La carrera empieza **en la bifurcación**, no en el génesis: hasta ahí las dos ramas comparten
historia y trabajo. A partir de la bifurcación, la rama pública produce peso a tasa
`μ_p = η_h(1−α−β_x)` y la privada a tasa `μ_a = η_a(α+β_d+β_x)`. Si el atacante **espera a que la
pública se adelante** (retención con anclaje en empate), el déficit inicial en unidades de peso es

```text
d = (μ_p − μ_a)·F = −g·F
```

que es **positivo** en todo el barrido con `g < 0`. El atacante gana cuando el déficit visita `−1`
por primera vez («superar» **estricto**, como manda el PROMPT §2 y `BASELINE.md` escenario 0).

**Los tres eventos** (separados, como exige `BASELINE.md` escenario 5):

```text
P_terminal(d,T)      = P(Z_T = −1)            (estar en −1 justo en T)
P_first_passage(d,T) = P(∃ t ≤ T : Z_t = −1)  (primera pasada; monótona en T)
P_eventual(d)        = P(∃ t : Z_t = −1)      (límite de la anterior)
```

### 2.2 La ventana no se descarta con una cota: se calcula

**Todas** las celdas publicadas de F2 se calculan con la **DP exacta** sobre el estado
`(mínimo, posición)`, con la absorción en la primera visita a `−1`. No hay ninguna columna de
cota: una versión anterior de este trabajo publicaba `(1 − p_adv)^F` como si fuera la probabilidad
de la celda y **no lo era** (no acotaba: con `F=1.019, α=0,33, β_d=0` daba `10^-177` frente al
valor real `9,75·10^-108`). El detalle del defecto y su corrección están en `PROGRESO.md` O6.

La única etiqueta que **no** es un cálculo es `imposible`, y es una **imposibilidad estructural**:
si `d > F`, el adversario necesitaría más pasos favorables que slots tiene la ventana, y
`P_first_passage = 0` exactamente (la DP también lo devuelve 0).

**Consecuencia sobre el coste:** al no poder descartar celdas por una cota, la rejilla se acota por
**presupuesto de cómputo** (la DP es `O(T·(d+1)·(d+T))`), y eso es lo que declara §4 del
`PROGRESO.md`: la rejilla de `F = 7.200` queda **inconclusa por coste**, con `correr-f2.sh` como
entrada mínima reproducible.

### 2.3 El resultado

La rejilla de `F = 1.019` (valores exactos, DP; `q_adv` es la tasa del adversario por paso y
`d` el déficit inicial en unidades de peso). **`limite_ruina`** marca las celdas donde la DP
subdesborda `Float64` (el valor real es `< 10^-308`): allí se publica el **límite exacto**
`(q_adv/(1−q_adv))^(d+1)`, que es cota superior de `P_first_passage`, en vez de un cero falso.

`α = 0,20` (cruce de deriva en `β_d = 0,750`):

| `β_d` rel. | `q_adv` | `d` | `P_primera` | `log10 P` | etiqueta |
|---:|---:|---:|---:|---:|---|
| 0,00 | 0,2000 | 611 | < 10⁻³⁰⁸ | −368,46 | `limite_ruina` |
| 0,20 | 0,3103 | 448 | 3,648·10⁻¹⁵⁸ | −157,44 | `exacto` |
| 0,40 | 0,3939 | 285 | 4,424·10⁻⁵⁶ | −55,35 | `exacto` |
| 0,60 | 0,4595 | 122 | 2,701·10⁻¹⁰ | −9,57 | `exacto` |
| 0,70 | 0,4872 | 41 | 5,230·10⁻² | −1,28 | `exacto` |
| 0,80 | 0,5122 | 0 | 0,9920 | −0,003 | `exacto` |
| 1,00 | 0,5556 | 0 | 0,999997 | −1,4·10⁻⁶ | `exacto` |

`α = 0,33` (cruce en `β_d = 0,5075`):

| `β_d` rel. | `q_adv` | `d` | `P_primera` | `log10 P` | etiqueta |
|---:|---:|---:|---:|---:|---|
| 0,00 | 0,3300 | 346 | 9,752·10⁻¹⁰⁸ | −107,01 | `exacto` |
| 0,20 | 0,4092 | 210 | 4,939·10⁻³⁵ | −34,31 | `exacto` |
| 0,34 | 0,4543 | 114 | 2,064·10⁻¹⁰ | −9,69 | `exacto` |
| 0,40 | 0,4716 | 73 | 8,591·10⁻⁵ | −4,07 | `exacto` |
| 0,50 | 0,4981 | 5 | 0,8312 | −0,080 | `exacto` |
| 0,55 | 0,5104 | 0 | 0,9903 | −0,004 | `exacto` |
| 1,00 | 0,5988 | 0 | 1,000 | 0 | `exacto` |

`α = 0,40` (cruce en `β_d = 0,333`):

| `β_d` rel. | `q_adv` | `d` | `P_primera` | `log10 P` | etiqueta |
|---:|---:|---:|---:|---:|---|
| 0,00 | 0,4000 | 204 | 4,130·10⁻³⁷ | −36,38 | `exacto` |
| 0,20 | 0,4643 | 82 | 3,125·10⁻⁶ | −5,51 | `exacto` |
| 0,34 | 0,5017 | 0 | 0,9781 | −0,0096 | `exacto` |
| 0,50 | 0,5385 | 0 | 0,99985 | −6,7·10⁻⁵ | `exacto` |
| 1,00 | 0,6250 | 0 | 1,000 | 0 | `exacto` |

**Con `F = 3.600` la ventana larga es PEOR para el adversario**, porque el déficit inicial crece
con el horizonte (`d = (1−2α)(1−β_d)·F`):

| `α` | `β_d` rel. | `q_adv` | `d` | `P_primera` | `log10 P` |
|---:|---:|---:|---:|---:|---:|
| 0,20 | 0,34 | 0,3711 | 1.181 | 8,530·10⁻²⁷⁷ | −276,07 |
| 0,20 | 0,55 | 0,4444 | 576 | 2,132·10⁻⁵⁹ | −58,67 |
| 0,20 | 0,70 | 0,4872 | 144 | 1,499·10⁻⁴ | −3,82 |
| 0,33 | 0,34 | 0,4543 | 404 | 6,724·10⁻³⁴ | −33,17 |
| 0,33 | 0,50 | 0,4981 | 18 | 0,6960 | −0,157 |
| 0,40 | 0,34 | 0,5017 | 0 | 0,9897 | −0,0045 |

**Lo que la tabla dice.** (1) Donde el adversario **no** gana la deriva, la probabilidad dentro de
la ventana es minúscula y **decrece con `F`**: el valor menor medido es `8,530·10⁻²⁷⁷`
(`F=3.600, α=0,20, β_d=0,34`). (2) La probabilidad **salta a orden 1 justo al cruzar `g = 0`**:
con `α=0,33` pasa de `0,831` en `β_d=0,50` a `0,990` en `β_d=0,55`, con el cruce en `0,5075`; con
`α=0,40`, de `3,1·10⁻⁶` en `β_d=0,20` a `0,978` en `β_d=0,34`, con el cruce en `0,333`. **La
transición la manda la deriva, no la ventana.** (3) **Un atacante del 33 % no gana dentro de `F`
con probabilidad no despreciable en ningún reparto que no cruce antes la deriva**, y para cruzarla
necesita `β_d > 0,5075`, es decir *más de la mitad del espacio honesto* farmeando doble.

**A partir de qué `β_d` gana un atacante del 33 % dentro de `F`.** Fijando el criterio declarado
`P_first_passage ≥ 10^-6` y bisecando en `β_d` con la DP exacta
(`resultados/F2b-betad-minimo.tsv`; el fichero se conserva del barrido anterior, que ya usaba la
DP para estas celdas —la bisección **nunca** usó la cota retirada—):

| `F` | `α` | `β_d` mínimo (relativo a `1−α`) | `β_d` absoluto | `α*` de deriva con ese `β_d` | margen `α* − α` |
|---:|---:|---:|---:|---:|---:|
| 1.019 | 0,20 | 0,6320 | 0,5056 | 0,2472 | **+0,0472** |
| 1.019 | 0,33 | 0,3764 | 0,2522 | 0,3739 | **+0,0439** |
| 1.019 | 0,40 | 0,1935 | 0,1161 | 0,4420 | **+0,0420** |
| 3.600 | 0,20 | 0,6864 | 0,5491 | 0,2254 | **+0,0254** |
| 3.600 | 0,33 | 0,4365 | 0,2924 | 0,3538 | **+0,0238** |
| 3.600 | 0,40 | 0,2576 | 0,1546 | 0,4227 | **+0,0227** |

(La columna `α*` es `(1 − β_d_absoluto)/2`, la frontera de deriva con `β_x = 0`.)

**Lectura.** Para que un atacante del 33 % tenga `P = 10^-6` **dentro de `F`** hace falta prestar
`≈ 25 %` del espacio honesto (absoluto, `F = 1.019`) y **sigue sin ganar la deriva**: la frontera
`α*(β_d) = (1−β_d)/2` queda **por encima** de `α` por un margen de `+0,022…+0,047`. Es decir: la
ventana es **más exigente** que la deriva, y el atacante que sólo puede mirar `F` slots necesita
`β_d` **del orden del umbral de deriva** para alcanzar una probabilidad aún minúscula. Nótese que
estos `β_d` **crecen con `F`** (a igual `α`): cuanto más larga es la ventana admitida, más espacio
prestado hace falta, porque el déficit inicial `d = (1−2α)(1−β_d)·F` crece con `F`.

**Etiqueta.** Los valores son **DP exacta** (`demostrado` dentro del modelo ±1, verificado contra
la enumeración exhaustiva en 714 celdas exactas), `condicionado` a H-PUENTE. **Todo F2 está `condicionado` a H-PUENTE** (`DEFECTOS.md` C1) y a
H3 (paso ±1 con peso uniforme): con pesos heterogéneos —el poder de compra de varianza de
`CIFRAS.md` A12/B2, `P` de `2,130 %` a `31,500 %` con `sr0/64`— la cola se compra y estos números
**no se trasladan**. Ése es el escenario 7 del PROMPT §2, tratado aparte en §5.3.

### 2.4 Convención de notación: `BASELINE.md` **no** se toca (corrección de un error propio)

**`BASELINE.md` escenario 0 es correcto y no se modifica.** Una versión anterior de este informe
lo acusó de tener la razón invertida. **La acusación era falsa y se retira.** El error fue de
lectura: en el encargo original y en `BASELINE.md`, **`p` es la tasa del HONESTO y `q` la del
ADVERSARIO**, de modo que `q < p` significa **adversario en minoría** y `(q/p)^(d+1) < 1`, que es
lo correcto. Este trabajo venía usando `p` para la tasa del **adversario** sin advertirlo, e
interpretó `q < p` como «adversario por delante».

**Lo que este instrumento calcula, en la convención de `BASELINE.md`.** Con `p` = tasa del honesto
y `q` = tasa del adversario, la fórmula de `BASELINE.md` se reproduce con exactitud:

| `p` (honesto) | `q` (adversario) | `d` | DP `P_first_passage(T = 400)` | `(q/p)^(d+1)` |
|---:|---:|---:|---:|---:|
| 2/3 | 1/3 | 5 | 0,015625 | 0,015625 |
| 3/5 | 2/5 | 2 | 0,29629533 | 0,29629630 |
| 2/3 | 1/3 | 0 | 0,5 | 0,5 |
| 4/5 | 1/5 | 6 | 6,104·10⁻⁵ | 6,104·10⁻⁵ |

**El error quedó en el texto, no en las transiciones.** El kernel implementa el déficit
`Z = (trabajo público) − (trabajo privado)`; baja con la probabilidad del **adversario** (primer
argumento de `primera_dp`, llamado allí `p`) y sube con `1 −` eso, en la primera visita a `−1`.
Reescrito en la notación de `BASELINE.md`, **el adversario es `q`** y el kernel es
`primera_dp(q, d, T)`; así reproduce la tabla de arriba. **Ninguna tabla de este informe cambia**
(F2 se calcula con la probabilidad del adversario como primer argumento, que es lo que el paseo
necesita). Lo que cambia es el nombre de la variable en la prosa y en las firmas.

**Riesgo de notación que se declara y que la revisión debe vigilar.** El primer argumento de
`primera_dp`, `p_de_alpha` y `p_superar_exacto` es la **tasa del adversario** (el `q` de
`BASELINE.md`), no el `p` de `BASELINE.md`. Es un nombre desafortunado, conservado para no
introducir un renombrado masivo a última hora; queda escrito en las firmas de
`src/modelo.jl` y `src/rapido.jl` y es el primer sitio donde mirar si alguna cifra no cuadra.
**No se detectó ningún uso del nombre que haya cambiado un resultado.**

**Con el adversario en mayoría (`q > p`) la probabilidad de superar es 1, no `(p/q)^(d+1)`.** Es
la comprobación que delata el error de la versión anterior: con `p = 2/5`, `q = 3/5` la DP da
`P → 1`, y la fórmula que yo proponía habría dado `0,667` (`d = 0`), `0,296` (`d = 2`) y `0,059`
(`d = 6`).

---

## 3 · F3 · El juego: ¿es farmear doble dominante? ¿Es el castigo imprescindible?

### 3.1 Sin castigo

El granjero racional compara:

```text
ganancia de farmear doble  =  (probabilidad de que su bloque privado cuente) · recompensa privada
coste de farmear doble     =  verificación PoT de la segunda rama = 0,092–0,190 núcleos
pérdida si lo castigan     =  0    (no hay castigo)
```

Con `κ = 0` (o sin castigo), `b* = 0`: **el soborno necesario es cero y farmear doble es
estrictamente dominante** (el coste de verificación lo paga el granjero, pero es ~16× menor que
producir el PoT, `veritas/consenso/puerta-cobertura-v1/INFORME.md:252-253`). La tabla
`resultados/F3-juego.tsv` lo cuantifica: para `κ = 0`, el soborno necesario es `0` en las 80
filas y el número de reclutados pagables es **sin cota**.

**Consecuencia sobre el umbral.** `β_d` sube hasta agotar el espacio reclutable. Si todo el
espacio honesto disponible farmea doble (`β_d = 1−α`), la frontera es

```text
α* = (1 − (1−α))/2 = α/2  <  α    para todo α > 0
```

es decir: **la privada gana la deriva para cualquier `α > 0`**. **Sin castigo, el umbral se pierde
por completo.** Ésta es la respuesta sin rodeos a la pregunta central de F3: **el consenso base NO
es seguro suponiendo que el doble farmeo es barato**, si «barato» significa «sin castigo».

### 3.2 Con castigo

Con el castigo estrecho de `CANDIDATA.md` §5, la pérdida del granjero castigado es

```text
pérdida = ρ_ret·ingreso·T_v + c_r + ingreso·M
b* = κ·q·pérdida − ganancia_extra
```

y el atacante debe pagar `b*·N_recl`. Con `κ = 1`, `q = 1`, `ρ_ret = 0,5`, `T_v = 10.000` e
`ingreso = 1`, la pérdida por reclutado es `5.030` u.e. y el soborno necesario es el mismo:
frente a un valor de ataque `V = 400` u.e. por reclutado (`V = 4` semanas de emisión, `N = 100`),
el ataque **no compensa** (`5.030 > 400`). Con `ρ_ret = 0` no compensa tampoco
(`pérdida = 30 > 400` falso: **30 < 400** ⇒ sí compensa) — es decir, **`ρ_ret = 0` NO basta**:
el atacante paga `30·100 = 3.000` u.e. y compra un ataque de `40.000` u.e.

**Región de indiferencia.** El `β_d` de equilibrio es la solución de

```text
b*(ρ_ret, T_v, κ, q) · N_recl(β_d)  =  V(β_d)
```

donde `N_recl(β_d)` es el número de granjeros que hay que reclutar para conseguir una fracción
`β_d` de espacio. **El `β_d` de equilibrio crece con `V` y decrece con `(ρ_ret·T_v)`**: es la
curva de indiferencia del atacante.

### 3.3 La restricción que el encargo no menciona: conservación de la oportunidad

El PROMPT §2 trata `β_d` como variable independiente. **No lo es, en función de la identidad de
billete elegida** (`ADENDA-1.md` §B; `PROPOSICIONES.md` P7/P8):

| identidad | ¿dos soluciones del mismo slot en la misma pieza son el mismo `TicketId`? | ¿`β_d` aporta peso neto? | umbral |
|---|---|---|---|
| `C-GD-07` vigente (con `chunk`) | **no** (dos `chunk` distintos ⇒ dos billetes) | **sí** | baja a `(1−β_d−2β_x)/2` |
| `IDV-01` y `CANDIDATA.md` §3 (sin `chunk`, con `piece_offset`) | **sí** | **no**: usar la misma oportunidad en dos ramas **es** la infracción estrecha, y la única salida es repartir el espacio | vuelve a `1/2` |

**Consecuencia, y es la bifurcación de diseño más importante de este informe.** Si se adopta
`IDV-01`/`CANDIDATA`, el doble farmeo **sin equivocación** deja de existir como estrategia: el
granjero que use su oportunidad en las dos ramas **deja evidencia** (el par de bloques) y el
castigo lo alcanza. Entonces `β_d` **no baja el umbral** y el requisito de `CANDIDATA.md` se
cumple **por construcción**, sin depender de que el castigo sea creíble. Si se mantiene
`C-GD-07`, `β_d` sí baja el umbral y **el castigo es la única defensa**.

**Etiqueta.** F3 con `C-GD-07`: `derivado`. F3 con `IDV-01`: `derivado` + `condicionado` a que
`IDV-01` se adopte (hoy está marcada «condicionada»,
`veritas/consenso/identidad-disponibilidad-v1/CONTRATO-VALIDACION.md` §1). **Este trabajo no
decide la identidad**: cuantifica las dos ramas.

---

## 4 · F4 · Coste del ataque, relativo y absoluto

### 4.1 Relativo, en unidades de emisión de la red

`resultados/F4-coste-absoluto.tsv`. Con `V = 4` semanas de emisión (`emisión semanal = 10.000`
u.e.) y `N = 100` reclutados:

| `κ·q` | soborno por reclutado (u.e.) | soborno total | PoT de la rama privada (`F=3.600`) | total | ¿rentable para `V = 40.000`? |
|---:|---:|---:|---:|---:|---|
| 0,00 | 0 | 0 | 331.200 | 331.200 | **no** (y además el soborno es gratis… pero no hay disuasión) |
| 0,25 | 1.257,5 | 125.750 | 331.200 | 456.950 | **no** |
| 0,50 | 2.515,0 | 251.500 | 331.200 | 582.700 | **no** |
| 1,00 | 5.030,0 | 503.000 | 331.200 | 834.200 | **no** |

**Soborno condicionado al éxito.** Si el atacante **sólo paga si gana** (`q = q_gana`,
`q_pierde = 0`), el coste esperado del soborno es `q_gana·b*·N`, no `b*·N`. Con `q_gana = 0,1` el
coste esperado cae a la décima parte; **con `q_gana → 0` el ataque le sale gratis al atacante**
(y por eso la censura de la prueba es, para el atacante, una forma de **no pagar**, no una forma
de perder).

### 4.2 Absoluto: qué necesita además del soborno, y qué no puede comprar

| término | valor | ¿se compra? |
|---|---|---|
| soborno a los reclutados | `b*·N_recl` | **sí** (es la parte «caro») |
| `α` propio | fracción del espacio total | **no a corto plazo**: hay que plotearlo (83,6 s/GiB en 32 hilos, medición **histórica** de `research/coste-ploteo-medido.md`, no heredable como cifra) y **madurarlo** durante `M` |
| PoT de la rama privada | `0,092–0,190` núcleos por granjero y slot (`veritas/consenso/puerta-cobertura-v1/INFORME.md:252`); `1,561 s/slot ≈ 1,56 núcleos` por bloque **producido**, que pone el atacante | **sí** (se alquila cómputo) |
| maduración `M` | símbolo | **no**: es tiempo, y el tiempo no se compra |
| ventana `F` | símbolo | **no**: la ventana la fija el protocolo |

**Lo que el mecanismo vuelve imposible y lo que sólo vuelve caro** (modelo de amenaza de Katana,
obligatorio):

- **Imposible**: nada, en el estado actual. `P-PERMANENCIA` §5 lo dice para las pruebas de
  permanencia («ninguna pieza vuelve la trampa *imposible*; todas la vuelven *cara*, y la única
  familia que podría volverla imposible —un compromiso criptográfico del cálculo caro, E1/E4— **no
  existe** para el formato fijado»). La infracción estrecha **sí** vuelve **detectable** el doble
  uso de una misma oportunidad, que es distinto de imposible.
- **Caro**: el soborno (proporcional a `ρ_ret·T_v·N`), el PoT de la rama privada y el tiempo de
  maduración.
- **Gratis para el atacante si fracasa**: con soborno condicionado al éxito y censura, el coste
  esperado del soborno tiende a 0 con `q_gana`.

---

## 5 · F5 · La región `(ρ_ret, T_v)`, y frente a qué atacante no hay región

### 5.1 La región

`resultados/F5-region.tsv`. Criterio (`CANDIDATA.md` §A.2 C1): pérdida esperada del reclutado
**>** soborno necesario, con `V = 400` u.e. por reclutado.

| `κ·q` | `ρ_ret` | `T_v` mínimo de la rejilla que cumple | forma cerrada | ¿`T_v > F` (con `F = 7.200`)? |
|---:|---:|---:|---:|---|
| 1,00 | 0,10 | 10.000 | `T_v > 3.700` | **sí** (10.000 > 7.200) |
| 1,00 | 0,25 | 1.000 | `T_v > 1.480` | **no** (1.000 < 7.200) |
| 1,00 | 0,50 | 1.000 | `T_v > 740` | **no** |
| 0,50 | 0,10 | 10.000 | `T_v > 7.700` | **sí** (por poco) |
| 0,25 | 0,10 | 100.000 | `T_v > 15.700` | **sí** |
| 0,10 | 0,10 | — (ninguna celda) | `T_v > 39.700` | **sí** |

(La forma cerrada sale de `κ·q·(ρ_ret·T_v + c_r + ingreso·M) > V/N` con `V/N = 400`,
`c_r + ingreso·M = 30`.)

**La restricción que manda es `T_v ≳ F`, no el soborno.** La retención debe durar **más que la
ventana en que la evidencia puede aparecer**, que es del orden de `F` **más el margen de inclusión**
(la evidencia tiene que entrar en la historia seleccionada, y si el atacante censura, la inclusión
tiene su propio retraso). Con `F = 7.200` slots, **`ρ_ret = 0,10` con `T_v = 3.000` no cumple el
requisito temporal** aunque sí el económico; para `T_v > 7.200` con `ρ_ret = 0,10` y `V = 400`,
`pérdida = 0,10·1·7.200 + 30 = 750 > 400` ⇒ **sí cumple**. La región mínima publicada es
`ρ_ret·T_v ≳ 4.000` **y** `T_v > F + margen`.

**Cuantificación del margen.** `F` es un símbolo y la evidencia puede aparecer **dentro** de `F`
(el par de bloques se produce en la ventana). El margen es el tiempo de inclusión más el de
finalización: como mínimo, `T_v > F`; razonable, `T_v ≥ F + Δ_inclusión + F` (una finalidad más
para que la evidencia sea irreversible). `Δ` **no está medida en red** (`CIFRAS.md` A28: la Δ es
de simulación), así que el margen queda **`derivado` pero no cuantificado**.

### 5.2 Sensibilidad

| parámetro | efecto sobre la región |
|---|---|
| `κ → 0` | el soborno necesario → 0 y **la región se vacía**: no hay `(ρ_ret, T_v)` que disuada |
| `q_gana → 0` | ídem: la censura de la prueba anula el castigo |
| fragmentación | el reclutado reparte su espacio en lotes y **arriesga sólo los lotes que usa** (`CANDIDATA.md` §A.1): la pérdida esperada se divide por el número de lotes, luego la región se multiplica por ese número |
| parcelas de reserva | los lotes maduros de reserva **no se pierden**: la pérdida efectiva es la del lote señalado, no la de toda la parcela |
| `V` sin cota | **no hay región** |
| espacio propio (`α > 0`) | el atacante no necesita reclutar para su parte `α`: la región sólo cubre el `β` reclutado |

### 5.3 El escenario que el PROMPT §2 pide aparte: compra de varianza

Etiquetado «condicionado a R-FIN-13′ sin especificar». Con `sr` bajo, `CIFRAS.md` A12/B2
(recalculado por convolución exacta, **no** los valores publicados) da
`P(adv > hon)` de `0,021302 / 0,095029 / 0,227470 / 0,314998` para `K = 1, 4, 16, 64` con
`α = 0,45`, `T = 400`. Es decir: **la varianza compra cola con el mismo trabajo medio**, y ese
vector **no está en el modelo ±1 de F2**. Si R-FIN-13′ se especifica de forma que permita al
atacante elegir `sr`, la ventana deja de estar gobernada por `p` y pasa a estarlo por la
distribución de pesos: **entonces F2 no aplica**. No se cuantifica aquí porque R-FIN-13′ no está
especificada (`CIFRAS.md` C18: «correcto y conservado»).

---

## 6 · F6 · El coste para el granjero honesto

`resultados/F6-honesto.tsv`. Un honesto que firma el mismo `TicketId` y slot con dos `pre_hash`
distintos **sin mala fe** (dos nodos redundantes sobre la misma parcela, o un reinicio con estado
perdido) incurre en la misma pérdida que el atacante:

```text
pérdida por evento   = ρ_ret·ingreso·T_v + c_r + ingreso·M
pérdida esperada/año = ε_h · (ρ_ret·ingreso·T_v + c_r + ingreso·M)
```

Con `ε_h = 10^-3`/año y `ingreso = 1`, `c_r = 10`, `M = 20`:

| `ρ_ret` | `T_v` | pérdida por evento | pérdida esperada anual |
|---:|---:|---:|---:|
| 0,00 | 0 | 30 | 0,030 |
| 0,10 | 1.000 | 130 | 0,130 |
| 0,25 | 1.000 | 280 | 0,280 |
| 1,00 | 10.000 | 10.030 | 10,03 |

**El compromiso es lineal y no tiene codo.** La misma `ρ_ret·T_v` que hace falta para disuadir al
atacante (región de §5.1) es la que paga el honesto accidental, escalada por `ε_h`. Con la región
necesaria (`ρ_ret·T_v ≈ 4.000`), un honesto con `ε_h = 10^-3`/año pierde `≈ 4` u.e./año, es decir
`≈ 4·10^-4` de su ingreso si su ingreso anual es `10.000`. **No hay separación posible por el lado
económico**: lo único que separa al honesto del atacante es la **protección en el productor**
(un registro persistente de lo firmado por lote y slot que se niegue a firmar dos veces,
`CANDIDATA.md` §A.2 C3), que es un requisito de **producción**, no de consenso. **Sin esa
protección, el primer castigo máximo es una trampa** (`P-EQUIVOCACION` D11: ¿leve o gradual?).

---

## 7 · Verificación y rendimiento

### 7.1 Controles de corrección

`test/runtests.jl` con `--check-bounds=yes`: **125 controles, todos en verde**. Las vías son
independientes entre sí:

| vía | qué es | contra qué se contrasta |
|---|---|---|
| DP sobre `(mínimo, posición)` | transición directa del paseo, `O(T·(d+1)·(d+T))` | enumeración exhaustiva y forma cerrada |
| enumeración exhaustiva recursiva | las `2^T` trayectorias con bandera de primera visita | DP |
| `(q/p)^(d+1)` | forma cerrada del horizonte largo | DP a `T = 4.000` |
| Monte Carlo `Philox4x` contracorriente | 20.000 réplicas, IC de Wilson | DP exacta |

Cobertura: **714 celdas exactas** (`Rational{BigInt}`) en `p ∈ {1/10, 1/3, 2/5, 1/2, 2/3, 9/10}`,
`d ∈ 0…7`, `T ∈ 0…16`, con `DP == enumeración` y `interior + paso = 1` exacto. El kernel `Float64`
coincide con el exacto a `< 10^-12` relativo y el `BigFloat` a 256 bits también.

### 7.2 Defectos propios detectados y corregidos

Siete, cada uno con su vector de regresión: DP con `−1` absorbente (calcula otra cosa), escritura
en `v` mientras se lee `v` (doble conteo), truncación de la cuadrícula (pérdida de masa), el
enumerador que cortaba la recursión, el mínimo inicial mal puesto (daba `>1`), una fórmula de
reflexión con el tope mal puesto (retirada) y `Philox4x64` inexistente en `Random123`. Detalle en
`PROGRESO.md` §3 y en la cabecera de `src/referencia.jl`.

### 7.3 Tabla de rendimiento (LINEO §6)

`resultados/BENCH.txt`. **Carga ajena `1,15` con 4 hilos ⇒ «medido con carga ajena».**

| Variante | Tiempo mediano | Asignaciones | Hilos | Resultado frente a la referencia |
|---|---:|---:|---|---|
| DP `Rational{BigInt}` (oráculo exacto) `d=2,T=12` | 0,161 ms | 11.555 | 1 | fuente de verdad exacta |
| Enumeración exhaustiva `T=18` | 118,2 ms | — | 1 | coincide con la DP en 714 celdas |
| DP `Float64` `d=10, T=1.000` | 13,36 ms | 6 | 1 | error relativo `< 10^-12` |
| DP `Float64` `d=100, T=3.600` | 1.543 ms | 6 | 1 | idem |
| DP `Float64` `d=350, T=1.019` | 521,9 ms | 6 | 1 | idem |
| Barrido serial (205 celdas) | 863,4 ms | — | 1 | — |
| Barrido paralelo (205 celdas) | 253,9 ms | — | 4 | idéntico al serial, **×3,40** |

`@code_warntype` de `primera_dp(Float64, Int, Int)` devuelve
`@NamedTuple{paso::Float64, interior::Float64}` **sin `Any`**. Asignaciones del kernel: 6 por
llamada (los dos buffers). Sin `@fastmath`, sin `@simd`, sin `Float32`.

---

## 8 · Lo que esta investigación NO resuelve

- **El puente espacio → tasa.** No existe en ningún instrumento (`DEFECTOS.md` C1, D4 abierto). F2
  y F3 están condicionados a H-PUENTE; F1 no.
- **El valor de `F`, `M`, `ρ_ret`, `T_v`, `κ`, `q`, `η`, `V`, `c_r`.** Son símbolos: este informe
  **no fija ninguno**. Lo que hace es dar la región de `(ρ_ret, T_v)` en función de los demás.
- **La distribución real de `δ`, `d`, `α`, `I`, `L_suelo`, `S_max`.** Son símbolos del SPEC
  (`PROPOSICIONES.md` P11.2). Sin ellos no hay cifra de `κ`, sólo la región de P8.
- **`C-GD-11` (*bounded merge depth*).** Cinco `<<PENDIENTE>>`; sin él no se sabe si el
  contraejemplo de `P4` es alcanzable. Es el pendiente que más puede mover el resultado
  (`DECISIONES-PENDIENTES.md` D1 de `P-EQUIVOCACION`).
- **La asimetría de la carrera del ancla (`P5`).** Está `derivado`, **no medido**: `κ` no es
  independiente de `α`, y este informe lo trata como símbolo (barrido) en vez de con `κ(α,δ,L)`
  porque la distribución de `δ` no existe. **Si `κ` decrece con la ventaja del atacante, la región
  de F5 se estrecha proporcionalmente**, pero la conclusión cualitativa (régimen `C-GD-07`:
  el castigo es imprescindible) no cambia.
- **La compra de varianza.** El escenario 7 del PROMPT §2 está etiquetado y no cuantificado: R-FIN-13′
  no está especificada. **Si se especifica y permite elegir `sr`, F2 no aplica.**
- **El coste mínimo real del ataque.** `r = 25,03` tablas/s es cota **superior** del atacante
  (`P-PERMANENCIA` §6); un kernel SIMD/GPU/ASIC no está medido en ningún encargo. El escenario GPU
  `17×` es **documentación ajena, nunca medida**.
- **La detección de un granjero que borra la parcela.** `P-PERMANENCIA`: quien delata es que **deja
  de ganar bloques** (E5), no la auditoría; y un granjero con `σ = 10^-5` es invisible durante
  **8,0 días** (E5, `w=7.175`). El modelo de F3 supone que el castigo es efectivo.
- **Los precedentes externos** (SpaceMint, protección contra doble firma en PoS). No se abrió
  ninguno: quedan **no verificados** y no se citan (`P-EQUIVOCACION` D13).
- **La integración real en el nodo.** Nada de esto está implementado en `crates/`: es un modelo
  cuantitativo, no una migración.

---

## 9 · Reproducción

```bash
cd /home/katana/zeo/ZEROX
LC_ALL=C sha256sum -c P-ZRX/P-PRESTAMO/ENTRADA.sha256
cd P-ZRX/P-PRESTAMO/investigacion/veritas/seguridad/espacio-prestado-v1
export JULIA_DEPOT_PATH="$PWD/../../../.julia-depot:/home/katana/.julia"

# Perfil de referencia (1 hilo, límites activos): 125 controles
JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 \
  /home/katana/zeo/ZEROX/veritas/julia.sh --check-bounds=yes --project=. test/runtests.jl

# Benchmarks (tabla de §7.3)
JULIA_NUM_THREADS=4 OPENBLAS_NUM_THREADS=1 \
  /home/katana/zeo/ZEROX/veritas/julia.sh --project=. bench/benchmarks.jl

# Resultados publicados
./correr-f2.sh                                  # F2-ventana.tsv y F2-ventana-F3600.tsv (DP exacta en todas las celdas)
JULIA_NUM_THREADS=4 /home/katana/zeo/ZEROX/veritas/julia.sh --project=. \
  run.jl --tarea f1 --tarea f3 --tarea f4 --tarea f5 --tarea f6 --seed 0x5052455354414d4f
```

**Artefactos.** `resultados/F1-superficie.tsv`, `F2-ventana.tsv`, `F2b-betad-minimo.tsv`,
`F3-juego.tsv`, `F4-coste-absoluto.tsv`, `F5-region.tsv`, `F6-honesto.tsv`, `F2-corrida.log`,
`BENCH.txt`. **Hipótesis falsables:** `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`. **Bitácora y
huellas:** `PROGRESO.md`. **Bifurcaciones para Katana:** `DECISIONES-PENDIENTES.md`.
