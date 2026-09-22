# INFORME — P-CLAVE · Retención por clave: a quién no disuade, y cuánto cuesta reclutarlo

**La respuesta, en una frase:** ligar la retención a la **clave** desbloquea el paquete (no hace
falta probar que la parcela existía entera) pero **no disuade al atacante que importa**: en el
régimen que decide (`ρ_ret > 0`), el reparto de saldos tiene una cola enorme de claves con saldo
**cero o casi cero** —con la distribución de tamaños declarada en H3, el **48,6 % del espacio** está
en claves con saldo < 0,001 u.e. y el **67,5 %** con saldo < 0,01 u.e., para `T_v = 3.600`—, y el
atacante que necesita cruzar la deriva sólo tiene que reunir `β_d > 1 − 2α` (**0,34** con un
atacante del 33 %, **0,20** con uno del 40 %). Como `0,675 > 0,34`, **el atacante consigue el `β_d`
que cruza la deriva comprando sólo claves de saldo casi cero, a coste de soborno CERO**, y por
tanto **la retención por clave no defiende ese caso**. La región `(ρ_ret, T_v)` que sobrevive **a la
vez** a la condición de `P-PRESTAMO` y al coste del honesto existe, pero es una **banda estrecha**
—`T_v ≥ (V/N − c_r − I·M)/(ρ_ret·I)` y `T_v < 1/(ν·ρ_ret)`, es decir `ρ_ret > ν·(3700)` en las
unidades del ejemplo—, y **fuera de ella no hay nada**: con `κ = 0`, `q = 0` o `V` sin cota no
existe ningún `(ρ_ret, T_v)`, y **frente a un atacante con claves nuevas la retención no cobra
nada**, porque su saldo confiscable es cero por construcción. El coste absoluto que sí queda es
**espacio, no saldo**: reunir el 10 % de una red de 1 PiB cuesta **102 GiB** de ploteo, **2,38 h**
en el ploteo medido de 32 hilos (o **3,17 días** de un hilo, o **0,0059 días** con la GPU a 5 s/GiB
**documentada, no medida**), y **el tiempo de maduración no se compra**.

**Categoría:** `economía` (dominante); `seguridad` y `consenso` (secundarias). El tema dominante es
el coste y el reparto del castigo económico (a quién disuade y cuánto cuesta reclutarlo), y por eso
`veritas/economia/retencion-clave-v1/`.

**Instrumento:** `P-ZRX/P-CLAVE/investigacion/veritas/economia/retencion-clave-v1/` — Julia 1.13.0,
CPU, `veritas/julia.sh`, **sin Python**. Referencia exacta (`Rational{BigInt}` y enumeración
multinomial) para las colas antes de cualquier aproximación normal. **Semilla:**
`0x434c415645` («CLAVE»). **Fecha:** 2026-09-22.

**Presupuesto declarado antes de ejecutar:** 8 hilos, 8 GiB de RAM, 512 MiB de disco, minutos por
tarea. **No se agotó** (el único consumo de disco grande es `resultados/BENCH.txt`, y el escalado
dejó `resultados/ESCALADO.tsv`; el kernel MC con 10⁶ réplicas asigna 552 MB **en memoria**, no en
disco). `uptime` anotado antes de cada bloque de benchmark en `resultados/BENCH.txt`.

**Configuración de hilos conservada: 4.** El escalado medido (`resultados/ESCALADO.tsv`) da
×1,96 a 4 hilos y ×1,55 a 8; **se conserva 4**, que es lo que manda LINEO §7 («se conserva la
configuración que gane, aunque use menos de 24»). El presupuesto de 8 hilos es el techo.

**Advertencia que gobierna el informe.** El **saldo confiscable es una variable aleatoria**; todas
las cifras de su distribución se calculan en **unidades de emisión** (`ingreso` por bloque, símbolo
`= 1`), **no** en tasa de bloques por unidad de tiempo derivada del espacio. **No se usa H-PUENTE
en ninguna cifra de este informe** (a diferencia de F2 de `P-PRESTAMO`, que sí está condicionada a
ella). Lo que sí es una **hipótesis declarada** es la **distribución de tamaños de clave** (H3) y el
modelo de llegada de recompensas (H1, Poisson) — ver
`HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md` y §7.

**Advertencia de fuente, y una corrección al trabajo heredado.** Al abrir
`P-ZRX/P-PRESTAMO/investigacion/INFORME.md` entero aparece una **inconsistencia interna**: su texto
define `g = η_a(α+β_d+β_x) − η_h(1−α−β_x)` (la rama pública sólo pierde `β_x`) pero su fórmula de
`α*` y su tabla de umbrales corresponden al reparto en que `β_d` **también** abandona la pública. Con
`η = 1`, el primero da `β_d > 1 − 2α` (lo que dice `PROMPT.md` §2.2, y lo que anula `g`); la tabla
publica `β_d > (1−2α)/(1−α)`, donde `g` **no** se anula (con `α = 0,33`, `g = 0,167`). Este informe
usa el reparto del texto —el del encargo—, publica `1 − 2α` como frontera y conserva la heredada
como columna aparte (`resultados/F3-grieta.tsv`). Detalle en `PROGRESO.md` O7. **No se modificó
ningún fichero de `P-ZRX/P-PRESTAMO/`.**

---

## 0 · Respuestas cortas a las seis preguntas

| # | Pregunta | Respuesta | Etiqueta |
|---|---|---|---|
| **F1** | La distribución del saldo confiscable, y qué fracción del espacio tiene saldo por debajo de `b` | Por clave: `B = ρI·Σ (1−a/T_v)`, con `E[B] = ρIθ/2`, `Var[B] = ρ²I²θ/3`, `P(B=0) = e^{−θ}`, `θ = λfT_v` (exactas). La desviación típica **relativa** es `√(4/(3θ))`: con `θ = 0,36` vale `1,92`, y la **normal sobreestima `P(B=0)` en un factor 0,43** (`0,302` frente a `0,698`). En **espacio**: con `T_v = 3.600`, `λ = 1` y Pareto(1e-8, 2,2) [H3], el **48,6 %** del espacio está en claves con saldo < 0,001 u.e., el **67,5 %** con saldo < 0,01, el **79,5 %** con < 0,1 y el **87,1 %** con < 1. **El reparto, no la media, decide** | `demostrado` (momentos y `e^{−θ}`) + `hipótesis H3` (tamaños) |
| **F2** | El coste de reclutar `β` eligiendo por saldo, en emisión, frente a reclutar al azar | **Por debajo del umbral `B(ε)` el coste es CERO**, y por encima es `C(β) = (β − B(ε))·coef` con `coef = ρλT_v/2` (900 u.e./unidad de espacio con `ρ=0,5`, `T_v=3.600`). Con `ε = 0,01`: `B = 0,675`, luego **`C(0,2) = C(0,34) = C(0,5) = C(0,67) = 0`**. El tope por clave (`b`) **nunca se alcanza** (`coef·f_min = 9·10⁻⁶ ≪ b`), así que el coste no depende de `b` ni del exponente. **Elegir abarata frente al azar**: 0 frente a `28,8` (az=A) para `β=0,02` y `0` frente a `128,4` para `β=0,2` en las mismas celdas | `derivado` + `medido` (muestra) |
| **F3** | ¿Existe un `β` que cruce la deriva alcanzable sólo con claves de saldo cero o casi cero? | **SÍ, en el régimen que decide.** Con `α = 0,33` la frontera es `β_d > 1 − 2α = 0,34` y el espacio en claves con saldo < 0,01 es `0,675 (T_v=3.600)`, `0,749 (1.000)`, `0,842 (100)`, `0,602 (10.000)`: **`0,602…0,842 > 0,34` en todo el barrido**. Con el criterio heredado (`0,5075`) la grieta sólo se cierra a `T_v ≳ 10⁵`. Con `ε = 0,001` (`B = 0,486`) la grieta también existe con `1 − 2α`. **La retención por clave no defiende ese caso** | `derivado` + `hipótesis H3` |
| **F4** | ¿Se puede encarecer la creación de claves nuevas sin registro ni moneda previa? | **NO, y ése es el resultado.** El ploteo es lineal en bytes e independiente del número de identidades y las identidades son gratis por diseño (`research/dag-poas-balizas-auditoria.md` §2, D9, `verificado en fuente`): repartir `S` bytes en `N` claves cuesta el **mismo** trabajo que una sola, y no hay moneda previa que consumir. El **coste extra de identidad es 0**. Lo único que la clave nueva sí paga es **tiempo**: el primer bloque tarda `T_v/θ` slots de media (`10⁸` slots con `f = 10⁻⁸`, `T_v = 100`) y su saldo confiscable es cero durante `T_v` | `verificado en fuente` + `derivado` |
| **F5** | El coste para el honesto, y la región `(ρ_ret, T_v)` que sobrevive a la vez a `P-PRESTAMO` y a la grieta | `L_h/(ingreso del honesto) = ν·ρ_ret·T_v` — **independiente de `f`**. La región es `T_v ≥ (V/N − c_r − I·M)/(ρ_ret·I)` **y** `T_v < 1/(ν·ρ_ret)` (y `T_v > F`). Con `V/N = 400`, `c_r = 10`, `M = 20`, `I = 1`: `ρ_ret·T_v > 3.700` y `ρ_ret·T_v < 1/ν`, luego **la región existe sólo si `ν < 2,7·10⁻⁴` reorgs/slot** (`ρ_ret·T_v = 370` sería el mínimo si `c_r+M` se contara una sola vez). `ρ_ret = 0,10` exige `T_v ≥ 37.000`; `ρ_ret = 0,50` exige `T_v ≥ 7.400`. **El mismo producto `ρ_ret·T_v` que disuade es el que cobra al honesto** | `derivado` |
| **F6** | Frente a qué atacante no hay `(ρ_ret, T_v)`, con coste absoluto en hardware y emisión | **No hay región** frente a: (a) `κ = 0` (publicar sólo la rama ganadora), (b) `q = 0` (censura total de la prueba), (c) `V` sin cota, (d) **un atacante con claves nuevas**, (e) `beneficio > pérdida`. La banda de F5 excluye el caso (d) por construcción. **Coste absoluto que sí queda** (no comprable con soborno): reunir `β = 0,10` de una red de 1 PiB = 102 GiB = 2,38 h de ploteo a 32 hilos (3,17 días de 1 hilo; 0,0059 días con la GPU a 5 s/GiB, **documentada no medida**), **más `T_v` de maduración, que es tiempo y no se compra**. Frente a la censura y a `κ=0`, **el mecanismo no vuelve nada imposible: nada** | `derivado` + `medido` (ploteo heredado) |

---

## 1 · El modelo, las unidades y qué es cada símbolo

**Reparto de espacio** (el del encargo, espacio total normalizado a 1): `α` = espacio propio del
atacante **retirado** de la pública; `β_d` = espacio honesto que farmea **doble** (sigue publicando y
además alimenta la privada); `β_x` = espacio alquilado en exclusiva que **abandona** la pública;
leales `= (1−α) − β_x`. Tasas de peso: `μ_p = η_h((1−α) − β_x)`, `μ_a = η_a(α + β_d + β_x)`.

**Deriva** `g = μ_a − μ_p = η_a(α+β_d+β_x) − η_h((1−α) − β_x)`, y su raíz en `α`:

```text
α*(β_d, β_x, η_h, η_a) = (η_h − η_a·β_d − (η_h+η_a)·β_x)/(η_h+η_a)
```

que es la fórmula que publica `P-PRESTAMO` §1 y que **ahora sí anula `deriva`** (la versión anterior
de su instrumento no estaba parametrizada así: `PROGRESO.md` O7). Casos particulares exactos:

| caso | condición | `α*` con `η = 1` |
|---|---|---|
| sin espacio prestado | `β_d = β_x = 0` | `1/2` |
| sólo doble farmeo | `β_x = 0` | `(1−β_d)/2`; `g > 0 ⟺ β_d > 1 − 2α` |
| sólo alquiler exclusivo | `β_d = 0` | `1/2 − β_x`; `g > 0 ⟺ β_x > 1/2 − α` |
| los dos a la vez e iguales | `β_d = β_x` | `1/2 − 3β/2` |

**Aviso sobre el umbral.** El cruce del doble farmeo es `β_d > 1 − 2α` (el del `PROMPT.md` §2.2). El
valor `(1−2α)/(1−α)` que publica la tabla de `P-PRESTAMO` §2.3 es mayor y **no** anula `g` en el
reparto de su propio texto; se publica aparte y **no se usa** para decidir. Con `β_d = β_x = 0`,
`α* = 1/2`, que es el `α*` de CRP-v0.1.

**El saldo confiscable.** Una clave con fracción `f` gana bloques a tasa `λf` (Poisson). De cada
recompensa de valor `I` se retiene `ρ_ret`, liberada **linealmente** durante `T_v` slots. Con
`θ := λfT_v`:

```text
E[B]     = ρ_ret·I·θ/2                       (M3)
Var[B]   = ρ_ret²·I²·θ/3                     (M4)
P(B = 0) = e^{−θ}                            (M5)
sd_rel   = √(4/(3θ))                         (M6)
```

`P(B = 0)` es **exacta** en el modelo (basta que no llegue ningún bloque). (M3)–(M4) son integrales
de la función de retención sobre un proceso de Poisson y se comprueban por integración numérica
independiente en los tests (`momentos exactos y frontera de deriva`, 68 controles).

**Unidades.** Todo adimensional respecto del espacio total (`= 1`) y de `I` (con `I = 1` salvo donde
se diga). `λ` [bloques/slot], `T_v`, `F`, `M` [slots], `ν` [reorgs/slot], `ε`, `b`, `V/N`, `c_r`
[u.e.]. **Ningún parámetro de consenso se fija**: todos entran por CLI y aparecen como columna.

---

## 2 · F1 · La distribución del saldo confiscable

### 2.1 La cola de los pequeños, en la clave y en el espacio

`resultados/F1-distribucion.tsv`. Dos medidas que **no** son la misma y se publican separadas:
`P(B = 0)` **por clave** (exacta), y la fracción del **espacio** en claves con saldo bajo un umbral
`ε` (que depende de la distribución de tamaños, H3).

Clave de referencia `f = 10⁻⁴`, `ρ_ret = 0,5`, `I = 1`, `λ = 1`:

| `T_v` | `θ` | `E[B]` | `Var[B]` | `sd_rel` | `P(B=0)` exacta | normal | normal/exacta |
|---:|---:|---:|---:|---:|---:|---:|---:|
| 100 | 0,01 | 0,0025 | 8,33·10⁻⁴ | 11,55 | **0,99005** | 0,4655 | **0,470** |
| 1.000 | 0,10 | 0,025 | 8,33·10⁻³ | 3,65 | **0,90484** | 0,3921 | **0,433** |
| 3.600 | 0,36 | 0,09 | 0,03 | 1,92 | **0,69768** | 0,3017 | **0,432** |
| 10.000 | 1,00 | 0,25 | 0,0833 | 1,15 | **0,36788** | 0,1932 | **0,525** |
| 100.000 | 10,0 | 2,50 | 0,8333 | 0,365 | **4,54·10⁻⁵** | 0,00308 | **67,95** |

**Lectura.** La normal **no aproxima `P(B = 0)` en ningún régimen útil**: la sobreestima por un
factor ≈ 2,3 cuando `θ ∈ [0,1…1]` y la **subestima por un factor 68** cuando `θ = 10`. Con `θ`
pequeño —granjero pequeño— acierta «de milagro» (ambas van a 1) pero falla en el valor absoluto
(0,47 frente a 0,99). Es exactamente la advertencia del PROMPT §4: **la normal falla justo donde
importa**, y por eso toda cifra de este informe sale de la fórmula exacta o de la DP exacta.

Fracción del **espacio** en claves con saldo por debajo de `ε` (Pareto truncada en `[10⁻⁸, 1]`, H3),
`T_v = 3.600`, `λ = 1`:

| `ε` (u.e.) | `α=2,05` | `α=2,2` | `α=2,5` | `α=3,0` |
|---:|---:|---:|---:|---:|
| 0,001 | 0,2938 | **0,4856** | 0,7795 | 0,9737 |
| 0,01 | 0,3763 | **0,6755** | 0,9000 | 0,9990 |
| 0,1 | 0,4414 | **0,7952** | 0,9684 | 0,9999 |
| 1 | 0,5000 | **0,8708** | 0,9990 | 0,99999 |

**Sensibilidad a `T_v`** (`α = 2,2`, `ε = 0,01`): `0,842 (T_v=100)`, `0,749 (1.000)`,
`0,675 (3.600)`, `0,602 (10.000)`, `0,369 (100.000)`. **`T_v` más largo reduce la grieta pero no la
cierra** en el rango de interés, y alarga la banda de F5 en la dirección equivocada.

**El exponente es una hipótesis, no un dato.** `α` **mayor** ⇒ cola más pesada hacia los pequeños ⇒
**más** espacio bajo el umbral (comprobado en los dos sentidos en los tests). No hay medición de la
distribución real de tamaños de clave en ZEROX ni en Autonomys; el informe publica `α ∈ {2,05; 2,2;
2,5; 3}` y la conclusión cualitativa no depende de cuál se elija (siempre hay una cola grande),
mientras la **cifra** sí.

### 2.2 El arranque y el churn

`resultados/F1b-arranque.tsv`. Con entradas y salidas de claves a tasa `c` [fracción del espacio por
slot] y espacio por clave independiente de la edad, la fracción de espacio con edad `< T_v` es
`1 − e^{−cT_v} ≈ c·T_v`. Con `T_v = 3.600`: `3,6·10⁻³ (c=10⁻⁶)`, `3,6·10⁻² (10⁻⁵)`, `0,30 (10⁻⁴)`.
**La fracción «siempre en arranque» es pequeña salvo churn muy alto**, pero eso **no** es la grieta:
la grieta de F1 no es «claves nuevas» sino «claves pequeñas que nunca han ganado un bloque»
(`P(B=0) = e^{−θ} → 1`), que son **permanentes**, no transitorias.

### 2.3 La varianza de los pequeños: cuantificación

Con `f = 10⁻⁶`, `T_v = 3.600`, `λ = 1`: `θ = 3,6·10⁻³`, `P(B = 0) = 0,99641`, `E[B] = 9·10⁻⁴`,
`sd_rel = 19,2`. **El 99,64 % del tiempo esa clave tiene saldo exactamente cero**, y el tiempo
esperado hasta su primer bloque es `T_v/θ = 10⁶` slots. Un modelo de flujo medio le asignaría
`ρIθ/2 = 9·10⁻⁴` u.e. confiscables de forma permanente; la realidad del proceso es que **casi
siempre no tiene nada**. Es la diferencia entre un modelo de flujo medio y la varianza real, y es
**medible sin ambigüedad** en el instrumento (`V3-cola-pequena.tsv`).

---

## 3 · F2 · Reclutar `β`: cuánto abarata elegir

### 3.1 El resultado analítico

`resultados/F2b-coste-analitico.tsv` y `F2c-curva-coste.tsv`. El atacante ordena por **soborno por
unidad de espacio** y toma las más baratas. Con soborno `min(coef·f_i, b)` y
`coef = ρ_ret·λ·T_v/2`:

- **El tope `b` nunca se alcanza** en el rango relevante: `coef·f_min = 900·10⁻⁸ = 9·10⁻⁶ ≪ b`
  (incluso con `b = 1`). Por tanto `soborno_i = coef·f_i`, **el ratio es constante `coef`**, y el
  coste de juntar `β` es `coef·β` **con independencia de la distribución** — el resultado más
  importante de F2.
- **Pero** las claves con `θ_i < ε` tienen soborno **0**. Sea `B(ε) = M(ε/(λT_v))` la fracción de
  espacio en esas claves. Entonces

```text
C(β) = 0                     si β ≤ B(ε)
     = (β − B(ε)) · coef      si β > B(ε)
```

Con `ρ_ret = 0,5`, `λ = 1`, `T_v = 3.600` (`coef = 900`) y `α = 2,2`:

| `ε` | `B(ε)` | `C(0,20)` | `C(0,34)` | `C(0,50)` | `C(0,70)` |
|---:|---:|---:|---:|---:|---:|
| 0,001 | 0,4856 | **0** | **0** | 12,9 | 193 |
| 0,01 | 0,6755 | **0** | **0** | **0** | 22,0 |
| 0,1 | 0,7952 | **0** | **0** | **0** | **0** |

**La forma de la curva es el hallazgo:** una meseta de coste **exactamente cero** hasta `B(ε)`, y
después lineal con pendiente `coef`. No hay codo suave: hay un **escalón en `B(ε)`**.

### 3.2 Cuánto abarata elegir, medido

`resultados/F2-reclutamiento.tsv` (muestra de 3·10⁵ claves de la Pareto truncada; DP exacto sobre
las 1.000 mayores; test de que el greedy **no** es óptimo en general, `PROGRESO.md` O8):

| `β` | azar (coste) | greedy (coste) | DP exacto | analítico `C(β)` |
|---:|---:|---:|---:|---:|
| 0,02 | 28,77 | **0** (191.426 claves) | 16,43 | 0 |
| 0,05 | 35,83 | **0** | 38,40 | 0 |
| 0,10 | 65,19 | **0** | 71,14 | 0 |
| 0,20 | 128,42 | **0** | 141,87 | 0 |
| 0,30 | 193,28 | 26,94 | 208,43 | 0 (β<0,675) |
| 0,50 | 315,37 | 206,98 | 323,78 | 0 |

**Lectura.** Elegir por saldo **no abarata: elimina el coste**. El «contrafactual azar» paga
`28,8…315` u.e. porque incluye claves con saldo; elegir sólo las de saldo casi cero paga **0**. La
comparación pertinente **no es un cociente** (el cociente es infinito), sino el **salto a cero**.
El «DP exacto» da más que el greedy en estas celdas porque se restringe a las 1.000 claves mayores
(las baratas están fuera); es la comprobación de que el greedy es cota y no óptimo, no una cifra
física.

---

## 4 · F3 · ¿Hay un `β` que cruce la deriva sólo con saldo cero?

`resultados/F3-grieta.tsv`. Se compara la **frontera de deriva** con la **fracción de espacio**
comprable a coste ~0. Con `α = 0,33`:

| `T_v` | `1 − 2α` (PROMPT) | `(1−2α)/(1−α)` (heredado) | `B(ε=0,01)` | grieta con PROMPT | grieta con heredado |
|---:|---:|---:|---:|---|---|
| 10 | 0,34 | 0,5075 | 0,900 | **SÍ** | SÍ |
| 100 | 0,34 | 0,5075 | 0,842 | **SÍ** | SÍ |
| 1.000 | 0,34 | 0,5075 | 0,749 | **SÍ** | SÍ |
| 3.600 | 0,34 | 0,5075 | 0,675 | **SÍ** | SÍ |
| 10.000 | 0,34 | 0,5075 | 0,602 | **SÍ** | SÍ |
| 100.000 | 0,34 | 0,5075 | 0,369 | **SÍ** | **NO** (por poco) |

Con `α = 0,40` (`1−2α = 0,20`) la grieta es aún más ancha; con `α = 0,25` (`0,50`) es **SÍ** con
`ε ≥ 0,01` y **NO** con `ε = 0,001` (`B = 0,486`). Con `α = 0,10` hay que llegar a `ε = 1` para
superar `1 − 2α = 0,80` (`B = 0,871`), y con `ε = 0,1` (`B = 0,795`) no se llega.

**Respuesta a F3: SÍ en el régimen que decide.** Para cualquier atacante con `α ≳ 0,25` —el caso que
`CANDIDATA.md` §A.1 discute— el espacio comprable a coste cero **supera** el `β_d` que cruza la
deriva, siempre que `T_v ≲ 10⁵` slots y el umbral de «casi cero» sea `ε ≥ 0,01` u.e. (≈ 6 bloques
retenidos en el caso de `T_v = 3.600` con `ρ_ret = 0,5`, porque `E[B] = 0,01` ⟺ `θ = 0,04`).
**La retención por clave no defiende ese caso**, y hay que decirlo así.

**Matiz que no se esconde.** Con el criterio heredado (`0,5075`) y `T_v = 10⁵`, la grieta **no** se
abre; con `ε = 0,001` y `α = 0,33`, `B = 0,486 < 0,5075`. Es decir: **el atacante queda fuera de la
grieta sólo si el umbral de «casi cero» es tan pequeño que los atacantes con `α ≥ 0,4` siguen
entrando por `1−2α`.** No hay una elección de `ε` que cierre la grieta para todos los `α`.

---

## 5 · F4 · Claves nuevas: qué se puede encarecer y qué no

`resultados/F4-claves-nuevas.tsv`.

**Lo que no se puede encarecer.** Por el teorema de identidad
(`research/dag-poas-balizas-auditoria.md` §2, D9, `verificado en fuente`): el ploteo es **lineal en
bytes** e **independiente del número de identidades**, y las identidades son **gratis por diseño**
(no hay registro, no hay moneda previa). Repartir `S` bytes en `N` claves cuesta exactamente el mismo
trabajo total que una sola. **El coste extra de identidad es 0**, y ninguna de las dos cosas que el
PROMPT §2.3 permite (registro de parcelas, moneda previa) está disponible. **Ése es el resultado.**

| dimensión | antes (1 clave) | después (`N` claves) | coste extra |
|---|---|---|---|
| ploteo | `S` bytes | `S` bytes repartidos | **0** |
| identidad | 1 clave | `N` claves | **0** |
| recompensa esperada por clave | `∝ S` | `∝ S/N` | 0 (suma igual) |
| saldo confiscable por clave | `∝ S` | `∝ S/N` | **−** (¡baja! el atacante gana) |

**Lo que sí paga la clave nueva: tiempo.** `E[B] = 0` hasta que llega el primer bloque, `T_v/θ`
slots de media (`10⁸` slots con `f = 10⁻⁸`, `T_v = 100`; `10⁴` con `f = 10⁻⁴`). Y **el tiempo no se
compra**. Pero la espera **no** es una defensa contra el atacante: es exactamente la misma espera que
sufre un granjero honesto nuevo. La asimetría real es otra y hay que nombrarla:

- El **honesto nuevo** espera `T_v` con saldo cero y **quiere** tener saldo (lo dejará crecer).
- El **atacante con clave nueva** espera `T_v` con saldo cero y **no quiere** tener saldo: si dura
  más de `T_v` empieza a acumular, así que **rota de clave** antes. Con rotación a `T_rot < T_v`,
  su saldo confiscable es siempre 0 y su coste en retención es siempre 0.

**Coste de la rotación.** Mantener `β` de espacio con rotaciones cada `T_rot` exige tener en vuelo
`β·(1 + T_v/T_rot)` de espacio (la clave vieja y la nueva conviven durante `T_v`), es decir
`1 + T_v/T_rot` veces el ploteo. Con `T_v = 3.600` y `T_rot = 360`: **×11 en ploteo**. Es el único
precio que el mecanismo le pone a la rotación, y **es precio de bytes, no de saldo** — exactamente lo
que F4 dice que no se puede evitar sin registro ni moneda.

---

## 6 · F5 · El coste para el honesto y la región `(ρ_ret, T_v)`

### 6.1 El coste honesto, derivado

De `P-EQUIVOCACION/investigacion/FALSOS-POSITIVOS.md` §3 (FP7) y `SPEC.md` §7.2: tras un reorg, el
billete de la historia abandonada **vuelve a estar disponible** y el firmante seguro debe negarse a
reusarlo. El honesto **pierde ese slot**. Con `ν` = tasa de reorg [reorgs/slot] e
`ingreso_por_slot = λI`:

```text
L_h                    = ν · ρ_ret · T_v · λ · I          [u.e. por slot]
L_h / (ingreso del honesto = f·λ·I)  = ν · ρ_ret · T_v     ← independiente de f
```

`resultados/F5-honesto-region.tsv`:

| `ρ_ret` | `T_v` | `ν = 10⁻⁴` | `ν = 3·10⁻⁴` | `ν = 10⁻³` |
|---:|---:|---:|---:|---:|
| 0,10 | 3.600 | 0,036 | 0,108 | 0,360 |
| 0,50 | 3.600 | 0,180 | 0,540 | **1,80 (NO)** |
| 1,00 | 7.200 | 0,720 | **2,16 (NO)** | **7,20 (NO)** |

**Un `(ρ_ret, T_v)` con `ρ_ret·T_v·ν ≥ 1` le cobra al honesto más que todo su ingreso:** no es una
regla, es una confiscación.

### 6.2 La región, y su anchura

Disuasión: `κ·q·(ρ_ret·I·T_v + c_r + I·M) > V/N`. Honestidad: `ν·ρ_ret·T_v < 1`. Con `V/N = 400`,
`c_r = 10`, `M = 20`, `I = 1` (`c_r + M = 30`, los números de `P-PRESTAMO` §5.1):

| `κq` | `ρ_ret` | `T_v` mínimo que disuade | `T_v` máximo que el honesto tolera con `ν = 10⁻⁴` | región |
|---:|---:|---:|---:|---|
| 1,00 | 0,10 | 3.700 | 100.000 | **existe** |
| 1,00 | 0,25 | 1.480 | 40.000 | **existe** |
| 1,00 | 0,50 | 740 | 20.000 | **existe** |
| 0,25 | 0,10 | 15.700 | 100.000 | **existe** |
| 0,25 | 0,10 | 15.700 | 10.000 (ν=10⁻³) | **VACÍA** |
| 0,10 | 0,10 | 39.700 | 100.000 | existe (por poco) |

**La región es una banda, no un recinto.** Su anchura en `T_v` es `1/(νρ_ret) − T_min(ρ_ret)`, y el
**mismo producto `ρ_ret·T_v`** que hay que subir para disuadir es el que hay que mantener bajo para
no confiscar al honesto. **Condición necesaria para que exista**: `ν < 1/(V/N − c_r − I·M)` en las
unidades del ejemplo, es decir **`ν < 2,7·10⁻⁴` reorgs/slot**. Si los reorgs son más frecuentes que
eso, **no hay `(ρ_ret, T_v)` que valga** (banda vacía). Ésa es una restricción nueva y **no está en
`P-PRESTAMO`**, que sólo impone `T_v ≳ F`.

**Y la restricción temporal sigue vigente**: `T_v > F` (`P-PRESTAMO` §5.1). Con `F = 7.200`, la
banda útil es `7.200 < T_v < 1/(νρ_ret)`, más estrecha todavía.

---

## 7 · F6 · Frente a quién no hay región, y el coste absoluto

### 7.1 Los adversarios que rompen la región

`resultados/F6-coste-absoluto.tsv`:

| adversario | condición | consecuencia |
|---|---|---|
| publica sólo la rama ganadora | `κ = 0` | soborno necesario = 0: **no hay disuasión** |
| censura total de la prueba | `q = 0` | soborno necesario = 0: **no hay disuasión** |
| `V` sin cota | `V → ∞` | no hay `(ρ_ret, T_v)` finito que cumpla `b > V/N` |
| atacante con espacio propio | `α > 0` | su parte `α` no se recluta: la región sólo cubre `β` |
| **claves nuevas** | saldo = 0 durante `T_v`; rota antes | **la retención no le cobra nada** |
| beneficio > lo confiscable | `V > pérdida` | el cálculo racional sigue favoreciendo la trampa |
| **y la grieta de F3** | `B(ε) ≥ 1 − 2α` | **el `β_d` que cruza la deriva se compra a coste 0** |

**Ésta es la respuesta a F6:** frente a `κ=0`, `q=0`, `V` sin cota y **claves nuevas**, ningún
`(ρ_ret, T_v)` disuade, y **el mecanismo no vuelve nada imposible en esos casos: nada.** La única
familia que podría volverlo imposible —un compromiso criptográfico del cálculo— **no existe** para
el formato fijado (`P-PERMANENCIA` §5, ya citado por `P-PRESTAMO`).

### 7.2 Coste absoluto: hardware y emisión

Lo que el atacante **sí** paga (no se compra con soborno): espacio. `resultados/F6-coste-absoluto.tsv`
con 1 PiB de red, ploteo **medido** de `83,608 s/GiB` en CPU de 32 hilos
(`research/coste-ploteo-medido.md`, cita **histórica, no heredable como cifra de consenso`) y GPU a
`5 s/GiB` (**documentada, NO medida**):

| `β` | espacio | CPU 32 hilos | CPU 1 hilo | GPU (5 s/GiB, doc.) |
|---:|---:|---:|---:|---:|
| 0,02 | 20,5 GiB | 0,48 h | 0,63 días | 0,0012 días |
| 0,10 | 102,4 GiB | 2,38 h | 3,17 días | 0,0059 días |
| 0,30 | 307,2 GiB | 7,13 h | 9,51 días | 0,018 días |
| 0,50 | 512 GiB | 11,9 h | 15,9 días | 0,030 días |

**Y no se compra**: el tiempo de maduración (`T_v > F`) y el ploteo inicial. **Lo que se compra**: el
soborno (aquí, cero por la grieta), el PoT de la rama privada (`0,092–0,190` núcleos por granjero y
slot, `veritas/consenso/puerta-cobertura-v1/INFORME.md`) y el hardware de ploteo.

**Corrección de una cifra heredada.** `research/dag-poas-balizas-auditoria.md` Anexo B cita
«1 PiB: GPU GTX 1070, 69,363 s/sector, 420,9 días». Con 1 GiB por sector y `5 s/GiB` **documentados**,
1 PiB (1.048.576 GiB) son **60,7 días**, no 420,9. La diferencia (×6,9) es la diferencia entre usar
`s/GiB` y `s/sector` con sectores de otro tamaño; se publica la cifra de este instrumento, **con su
fuente y su etiqueta**, y se deja constancia de la discrepancia.

---

## 8 · Verificación

`resultados/TEST.log`: **1.096 controles, 0 fallos** (1 hilo, `--check-bounds=yes`). Las vías son
independientes entre sí; **ningún test compara una fórmula consigo misma**:

| vía | qué es | contra qué se contrasta |
|---|---|---|
| momentos exactos (M3)–(M6) | integrales de la retención sobre Poisson | integración numérica independiente |
| oráculo de espacios exponenciales | representación exacta de Dirichlet de los huecos | enumeración multinomial |
| enumeración multinomial explícita | `K` bins, composiciones con peso `N!/(Πn_j!)K^{−N}` | DP por `m` |
| DP de la CDF por `m` | estado `(s,i)`, transición binomial condicional | enumeración bruta (7 pares `(K,m)` × 4 valores de `x`) |
| kernel MC por conteos de bins | `Poisson(θ)` + multinomial por bin | CDF exacta y oráculo, con IC |
| `Rational{BigInt}` | álgebra del reparto multinomial | enumeración `Float64` en la misma rejilla |
| reclutamiento | greedy vs DP exacto vs fuerza bruta (200 instancias) | contraejemplo que prueba que el greedy no es óptimo |
| reclutamiento | DP exacto vs fuerza bruta | 601 controles |
| masa bajo umbral | `E[min(f,x)]/E[f]` vs CDF truncada estándar | dos expresiones algebraicas distintas |

**Identidades de borde comprobadas.** `ρ_ret = 0` y `T_v = 0` dan la delta en 0; `T_v → 2T_v` duplica
`E[B]`; `g(α*) = 0` exacto con signo estricto a los dos lados para `η` distintos; `β_x` baja el
umbral el doble que `β_d` (con `η=1`); `1 − 2α` anula `g` con `η=1` y
`(1−2α)/(1−α)` **no** lo anula; `P(B=0)` exacta = `e^{−θ}` en cuatro vías; serial ≡ hilos.

**Defectos propios** (12 detectados y corregidos, con su vector): `PROGRESO.md` §3. Los cuatro que
más costaron: la convolución que perdía `N=0` (O1), el índice de fila de la DP (O5), la cancelación
catastrófica al normalizar la Pareto (O6) y la afirmación falsa de que el greedy de reclutamiento es
óptimo (O8).

---

## 9 · Rendimiento

`resultados/BENCH.txt` (LINEO §6). `uptime` anotado antes de cada bloque. **No se publica ninguna
aceleración sin validación**: el kernel MC se compara con la CDF exacta (test), no sólo consigo
mismo.

| Variante | Tiempo mediano | Asignaciones | Hilos | Frente a la referencia |
|---|---:|---:|---|---|
| Oráculo espacios exponenciales (vía exacta) | 0,04 µs | 42 B | 1 | fuente de verdad exacta |
| Kernel MC 1.000 réplicas, 1 hilo | 35,9 µs | 32,5 KB | 1 | coincide en distribución (IC) |
| Kernel MC 10⁶ réplicas | 27,3 ms | 552 MB | 4 | **idéntico al serial** (test) |
| CDF exacta (DP por `m`), `θ = 36` | 63,7 ms | 197 MB | 1 | exacta, validada contra el oráculo |
| CDF exacta (DP por `m`), `θ = 0,36` | 63,3 ms | 197 MB | 1 | exacta |
| `reclutamiento_eligiendo` (`n = 10⁵`) | 0,12 ms | 1,6 MB | 1 | cota superior (no óptimo: O8) |
| `reclutamiento_exacto` (`n = 10⁵`, 2.000 pasos) | 180 ms | 3,2 GB | 1 | óptimo (test vs fuerza bruta) |

El kernel MC asigna `1,004` posiciones por réplica y `42 B` por llamada al oráculo. **Escalado
`1…8` hilos** (`resultados/ESCALADO.tsv`, 2·10⁶ réplicas con `K = 32`): `1 hilo 0,223 s`;
`2 hilos 0,156 s` (×1,44); **`4 hilos 0,114 s` (×1,96)**; `8 hilos 0,144 s` (×1,55). **Se conserva
4 hilos**, que es la configuración que gana realmente —como manda LINEO §7: el tope es un techo, no
un objetivo—; con 8 hilos la contención de memoria (cada réplica tiene su propio buffer) degrada el
resultado. El presupuesto declarado (8 hilos) incluye esa configuración ganadora.

**Controles de discretización** (`resultados/V1-discretizacion.tsv`): el kernel de `K = 8` frente al
de `K = 32` y la CDF exacta con `n = 2·10⁴` réplicas; por ejemplo `θ = 0,05`, `x = 0`:
`exacta 0,16530`; `K=8 0,17265`; `K=32 0,17265` (la diferencia es el sesgo de la rejilla, no ruido
MC). **Controles de cotas** (`resultados/V4-cotas.tsv`): la cota `e^{−θ}` se cumple en las 20
celdas.

Sin `@fastmath`, sin `@simd`, sin `Float32`. Paralelización sólo por réplicas con RNG derivado por
`hash64(semilla, id)` (semillas **no** consecutivas) y reducción determinista.

---

## 10 · Lo que esta investigación NO resuelve

- **La distribución real de tamaños de clave.** No existe medida en ZEROX ni en Autonomys. Todo F1
  «en espacio», todo F2 y todo F3 dependen de H3 (Pareto, exponente declarado). **La conclusión
  cualitativa no depende del exponente; la cifra sí.**
- **El puente espacio → tasa** (H-PUENTE) sigue sin existir. Aquí **no se usa**, pero no se cierra.
- **Los valores de `F`, `M`, `ρ_ret`, `T_v`, `κ`, `q`, `ν`, `V`, `c_r`, `λ`.** Son símbolos; este
  informe da regiones y funciones de ellos, no constantes.
- **`κ` como función de `α`** (`P5`/`P6` de `P-EQUIVOCACION`): aquí se barre como símbolo. Si `κ`
  decrece con la ventaja del atacante, la región se estrecha proporcionalmente.
- **La capacidad real de censura (`q`) y el soborno condicionado al éxito.** No se miden; la
  conclusión es `q = 0 ⇒` no hay región, sin cuantificar cuánto cuesta censurar.
- **La identidad de billete (`IDV-01` vs `C-GD-07`).** Sigue siendo la bifurcación D1 de
  `P-PRESTAMO`; este informe **no la decide** y sus cifras NO dependen de ella, porque aquí el
  castigo se supone efectivo (`κ` como símbolo) y lo que se mide es a quién alcanza.
- **La implementación en el nodo.** Nada de esto está en `crates/`: es un modelo cuantitativo.
- **El precedente externo en su totalidad.** Se verificó SpaceMint §3.3/§4 (citas en §11 y en
  `evidencia/spacemint/`). **No se abrió** la protección contra doble firma en validadores PoS ni la
  «full version» a la que SpaceMint §4 remite.
- **La varianza dentro de una misma clave como palanca del atacante.** Aquí se modela el saldo por
  clave con Poisson; no se modela que el atacante **elija** claves por su historia para explotar la
  varianza (lo que `P-PRESTAMO` §5.3 llama «compra de varianza», `R-FIN-13′`). Si esa compra está
  permitida, la cola de F1 se ensancha y **la grieta de F3 empeora**, no mejora.

## Lo que esta investigación NO resuelve (resumen ejecutivo)

Distribución de tamaños (H3, hipótesis), puente espacio→tasa (H-PUENTE, sin usar), valores de los
símbolos, `κ(α)`, `q` real, identidad de billete, integración en el nodo, precedentes externos
completos y la compra de varianza.

---

## 11 · Reproducción

```bash
cd /home/katana/zeo/ZEROX
LC_ALL=C sha256sum -c P-ZRX/P-CLAVE/ENTRADA.sha256
cd P-ZRX/P-CLAVE/investigacion/veritas/economia/retencion-clave-v1
export JULIA_DEPOT_PATH="$PWD/../../../../.julia-depot:/home/katana/.julia"

# 1) Perfil de referencia (1 hilo, límites activos): 1.096 controles
JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 \
  /home/katana/zeo/ZEROX/veritas/julia.sh --project=. --check-bounds=yes test/runtests.jl

# 2) Artefactos publicados (F1..F6, V1..V4)
JULIA_NUM_THREADS=8 OPENBLAS_NUM_THREADS=1 \
  /home/katana/zeo/ZEROX/veritas/julia.sh --project=. run.jl --seed 0x434c415645 \
    --tarea f1 --tarea f1b --tarea f2 --tarea f2b --tarea f2c --tarea f3 \
    --tarea f4 --tarea f5 --tarea f6 --tarea v1 --tarea v2 --tarea v3 --tarea v4

# 3) Benchmarks
JULIA_NUM_THREADS=4 OPENBLAS_NUM_THREADS=1 \
  /home/katana/zeo/ZEROX/veritas/julia.sh --project=. bench/benchmarks.jl

# o todo de una vez:
./correr-todo.sh
```

**Artefactos.** `resultados/F1-distribucion.tsv`, `F1b-arranque.tsv`, `F2-reclutamiento.tsv`,
`F2b-coste-analitico.tsv`, `F2c-curva-coste.tsv`, `F3-grieta.tsv`, `F4-claves-nuevas.tsv`,
`F5-honesto-region.tsv`, `F6-coste-absoluto.tsv`, `V1-discretizacion.tsv`, `V2-greedy.tsv`,
`V3-cola-pequena.tsv`, `V4-cotas.tsv`, `TEST.log`, `CORRIDA.log`, `BENCH.txt`, `ESCALADO.tsv`.
**Hipótesis falsables:** `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`. **Bifurcaciones para Katana:**
`DECISIONES-PENDIENTES.md`. **Bitácora y huellas:** `PROGRESO.md`.
