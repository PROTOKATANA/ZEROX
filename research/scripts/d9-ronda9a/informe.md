# D9 · Ronda 9a — ¿es correcto el «doble conteo»? Auditoría de `dag-poas-tras-d8-palancas.md` §1

**Fecha:** 2026-09-08, noche · **Auditor:** D9, adversarial, Opus 5 · **Directorio:** `research/scripts/d9-ronda9a/`
**Instrumento:** `r9a_lib.py` (extiende `d8-ronda8/d8_lib.py` y `d9-ronda8c/{r8c_gd,r8c_sim}.py`; **no toca ninguno**).

## Pregunta única

El agente principal afirma que TODAS las rondas 3-8 y la auditoría D8 contaron **dos veces** el espacio del
atacante: metieron el mismo `α` en el `δ` (rojos honestos, que sólo se consiguen con bloques **publicados**) y
en la carrera privada de doble gasto (que exige bloques **privados**). Con `α = α_p + α_f` y la parásita en su
óptimo, dice, el `blue_work` público crece a `1−α` y `r = α_f/(1−α) ≤ α/(1−α)`; con `δ = 0` la frontera de
flujo único pasaría de 36,5 % a **46,9 %**.

> ## VEREDICTO ADELANTADO
>
> **La tesis es CORRECTA, y por una razón más fuerte que la que el agente escribe.** No es que «el atacante no
> pueda estar en dos sitios a la vez»: es que **la tasa de `blue_work` de la cadena pública NUNCA baja de
> `(1−α)λ`, haga el atacante lo que haga** — y de hecho **SUBE** (medida: `1,18·(1−α)λ` a `α = 0,35`), porque
> los bloques con los que enrojece son azules en la cadena que gana. El `δ` del Lema 9 **no se resta del
> denominador de la carrera**; se resta sólo de la **parte honesta** de ese denominador, que no es la magnitud
> que decide una reorganización.
>
> **Pero el argumento del agente tiene un hueco que hay que cerrar, y yo lo cierro con un número:** la
> conservación **se rompe** en cuanto `2Δλ` se acerca a `k`. Medido: con `Δ = 20 s` y `α = 0`, sin que el
> atacante gaste **un solo bloque**, `δ₀ = 0,443` y `Wpub/H = 0,557`. **El `δ` real del diseño no es una
> palanca del adversario: es `Δ`.** Y `Δ` sigue sin medir.
>
> **Frontera de flujo único, recalculada:** ver §4. Con `δ = 0`, **46,88 %**.

---

## L0 · Lo leído (con fichero y línea)

| Fuente | Lo que aporta a esta ronda |
|---|---|
| `research/dag-poas-tras-d8-palancas.md` §1 | La afirmación a auditar |
| `research/dag-poas-ancla-de-orden-auditoria-7.md` §1.1 | Modelo cerrado de la parásita: `J* = kα/(1−2α)`, `δ_ráfaga(J) = 1 − kα/(J(1−α))` |
| `d8-ronda8/informe.md` A1.1-A1.5, A6b | La parásita, su `δ`, su legalidad, su rentabilidad, y `3k` medido = 0,56·3k |
| `d8-ronda8/d8_a1c_riesgo.py:29-40` | `prev()` — la carrera de Skellam del Lema 10, reutilizada **sin reescribir** |
| `research/fuentes/phantom-ghostdag.txt` L1100-1160 (Lema 9), L1200-1236 (Lemas 12 y 10), L1024-1037 (adversario, `wH`) | Ver §1.2: **`wH` es el score del bloque virtual honesto — incluye los azules del atacante** |
| `d9-ronda8c/r8c_gd.py:110, 259-263` | `find_selected_parent` = `max` por `blue_work`; `blue_work = blue_work(sp) + |mergeset_blues|`, **1 por bloque** |

---

## L1 · Formal — la cota de intercambio · **DEMOSTRADA (con holgura O(Δλ) por evento)**

**Modelo.** `λ = 1` bloque/s, `Δ = Dmax = 4 s`, `k = 30`, `blue_work = |BlueSet|`. Adversario del paper
(L1024-1027): ve todo al instante, entrega al instante, no puede retrasar honesto↔honesto por encima de `Dmax`.
`α = α_p + α_f`, honesto `1−α`.

### 1.1 · La magnitud que decide la carrera no es la que el diseño mide

La tabla de riesgo usa `r = α/((1−α)(1−δ))`. El denominador `(1−α)(1−δ)λ` es la tasa de **bloques honestos que
acaban azules**. Pero la carrera del Lema 10 es `adv(t) = wA(t) − wH(t)`, y el paper define (L1035-1037):

> *«The honest score `wH(t)` is defined as the score of the **virtual block of the honest node** at time t»*

El score del bloque virtual honesto **cuenta también los bloques del atacante que son azules en esa vista**.
La magnitud correcta es por tanto `tasa_Wpub = [(1−α)(1−δ) + α_p·(azules/publicados)]·λ`, no `(1−α)(1−δ)λ`.
**Ese es el error, y es anterior a las rondas 3-8: está en cómo el diseño leyó el Lema 9.**

### 1.2 · Proposición A (cota de intercambio, por evento)

Sea `t` un instante en que la publicación de un bloque `C` del atacante hace que la red honesta cambie de
cadena seleccionada; sea `B′` la punta seleccionada honesta justo antes y `D` el último ancestro común de
`SelectedChain(B′)` y `SelectedChain(C)`. Sean `X = BlueSet(B′)\past(D)`, `Y = BlueSet(C)\past(D)`, con
sus partes honesta y del atacante `X_h, X_a, Y_h, Y_a`.

Que la red cambie de cadena exige `score(C) ≥ score(B′)` (paper L1121-1124; en el código,
`find_selected_parent` es un `max` sobre `blue_work`, `protocol.rs:99-106` / `r8c_gd.py:110`), luego
**`|Y| ≥ |X|`**. Con `R := |X_h \ Y|` (rojos honestos del evento) y `A := |Y_a \ X|` (azules **nuevos** del
atacante):

```
R = |X_h| − |X_h ∩ Y_h|                                    (un honesto sólo puede seguir azul dentro de Y_h)
|Y_h| + |Y_a| ≥ |X_h| + |X_a|                              (de |Y| ≥ |X|)
⇒ R ≤ (|Y_a| − |X_a|) + (|Y_h| − |X_h ∩ Y_h|) = A + |Y_h \ X_h|
```

`|Y_h \ X_h|` son honestos azules para `C` que **no** lo eran para `B′`: sólo pueden ser (i) honestos creados en
`(t−Δ, t]` —el atacante los ve al instante y `B′` todavía no— o (ii) honestos que estaban **rojos** en la vista
de `B′`, que son `0` si el `δ` natural es `0`. Los primeros son `O(Δλ(1−α))` por evento. Por tanto

> **`R ≤ A + O(Δλ)` por evento de cambio de cadena.** ∎

**Corolario (la forma cerrada de la ráfaga).** Para la familia de ráfagas (la parásita de D8), la cuenta es
exacta y no necesita la holgura: publicar `J` bloques tras `T = J/(α_pλ)` exige `J + k > (1−α)λT` para ganar
(`auditoría 7` §1.1), y los rojos son `(1−α)λT − k`. Restando: **`rojos < J`, siempre, con margen `k`.** En el
óptimo `J = J*` la razón vale exactamente 1 y la tasa pública queda en `(1−α)λ`; para `J < J*` la parásita
**sube** la tasa pública por encima de `(1−α)λ`; para `J > J*` la ráfaga fracasa y no hay rojos. **El mejor
caso del parásito es "no aportar nada", que se consigue gratis apagando la máquina.**

**Lo que la Proposición A NO demuestra:** la versión **integrada** (sumada sobre todos los eventos de un
horizonte) con holgura cero. El término de borde es `≤ 2Δλ·ν` con `ν ≤ α_pλ/(k+1)` eventos/s, es decir
`≤ 0,26·α_p` rojos/s: **no es despreciable a nivel de cota**. La versión integrada se decide **midiendo**
(§2), no demostrando. Etiqueta: **DEMOSTRADO por evento, VERIFICADO integrado.**

### 1.3 · Maniobra (ii): ¿puede el flujo privado heredar los bloques parásitos publicados?

Sí puede fusionarlos — y **no le sirve**, por dos razones independientes:

1. **Los bloques parásitos publicados están en el pasado de las DOS cadenas**, luego aportan lo mismo a `wA` y
   a `wH` y se cancelan en `adv = wA − wH`.
2. **Lo que el flujo se traiga de fuera de su propia cadena está acotado por una constante, no por una tasa.**
   El bloque `A_1` del flujo (el más viejo por encima de la bifurcación) tiene en su anticono **todo** lo creado
   después de él que no esté en su cadena: honestos, parásitos propios y ajenos. La regla k-cluster
   (`protocol.rs:250`, `r8c_gd.py:_check_with_chain_block`) le permite como mucho `k` azules ahí. El paper lo
   acota globalmente en `3k` (Lema 12, L1200-1206: *«score(C) ≤ score(B) + 3k»*) y D8 lo midió: **máximo real
   50 = 1,67·k** (`d8-ronda8/informe.md` línea 5). Una constante `≤ 3k` **ya está dentro** del `prev()`: es
   exactamente la «ventaja inicial `3k`» con la que se desplaza la Skellam. **Heredar no cambia la deriva.**

### 1.4 · Maniobra (iii): parásito racional AJENO

Con honesto `h = 1−α_f−α_p`, parásito `α_p` y corredor privado `α_f`, la conservación da
`tasa_Wpub ≥ h·λ`, con igualdad en el óptimo del parásito. Luego `r = α_f/(1−α_f−α_p)`. **Un parásito ajeno de
cuota `α_p` hace exactamente el mismo daño que un granjero de cuota `α_p` apagado** — ni más ni menos. Números
en §4.

---

## L2 · Simulación · A1 — la cota de intercambio, medida · **VERIFICADO**

**Script:** `r9a_a1_intercambio.py` → `salida_a1.txt`. 37 maniobras × 9 `α` × 12 semillas = **3 996 corridas**,
horizonte 1 800 s, ventana [60, 1740] s, `k=30`, `Δ=4`, `mp=15`, `msl=180`, `u3=dynamic`. 150 s de cómputo.

Familia barrida: `modo ∈ {parásito, cadena, abanico} × J ∈ {16,31,48,64,96} × d_fork ∈ {1,2}`, **dos cadenas
parásitas alternas** (`MundoDosParasitas`, la sub-pregunta «ráfagas encadenadas / dos parásitas»), y **parásita
con 3 copias del mismo billete** bajo U3″-dynamic (`MundoParasitaCopias`).

**Validación del instrumento contra D8** (regla: reproducir antes de refutar) — `δ` de la parásita `d_fork=1`:

| `α` | `δ` de D8 (`salida_a1b.txt`) | `δ` mío | |
|---:|---:|---:|---|
| 0,25 | 0,1544 | **0,1542** | ✓ |
| 0,33 | 0,2867 | **0,2864** | ✓ |
| 0,35 | 0,3065 | **0,3066** | ✓ |
| 0,40 | 0,4366 | **0,4357** | ✓ |
| 0,45 | 0,5834 | **0,5825** | ✓ |

**El resultado (máximo sobre las 37 maniobras, el atacante elige la mejor):**

| `α` | máx `R/A_pub` | **máx `R/A_azul`** | **mín `W_pub/H`** | ráfagas totales |
|---:|---:|---:|---:|---:|
| **0,00** | 0,000 | **0,000** | **1,0000** | **0** |
| 0,10 | 0,199 | 0,667 | 1,0004 | 74 |
| 0,25 | 0,455 | 0,722 | 1,0074 | 206 |
| 0,33 | 0,572 | 0,709 | 1,0000 | 275 |
| 0,35 | 0,558 | 0,747 | 1,0000 | 292 |
| 0,40 | 0,655 | 0,783 | 1,0000 | 334 |
| 0,45 | 0,712 | 0,964 | 0,9999 | 380 |
| 0,55 *(control)* | 0,787 | 0,981 | 1,0062 | 734 |
| 0,70 *(control)* | 0,423 | 0,995 | 1,0034 | 1 149 |

**Ninguna maniobra de la familia pasa de 1 rojo honesto por bloque azul del atacante.** Ni siquiera con
`α = 0,70`. El máximo absoluto es **0,995**.

**Y la tasa que decide la carrera** (parásita `d_fork=1`, el mejor `J` por fila):

| `α` | `δ` | `tasa W_pub` | `(1−α)λ` | **`W_pub/H`** |
|---:|---:|---:|---:|---:|
| 0,00 | 0,0000 | 0,9910 | 1,0000 | 1,0000 |
| 0,25 | 0,1542 | 0,8373 | 0,7500 | **1,131** |
| 0,33 | 0,2864 | 0,7450 | 0,6700 | **1,130** |
| 0,35 | 0,3066 | **0,7533** | 0,6500 | **1,179** |
| 0,40 | 0,4357 | 0,6824 | 0,6000 | **1,153** |
| 0,45 | 0,5825 | 0,6500 | 0,5500 | **1,198** |

A `α = 0,35` el diseño supone que el denominador de la carrera es `(1−α)(1−δ) = 0,451`. **Medido: 0,753.**
Un factor **1,67**. Etiqueta: **VERIFICADO — la tesis del agente principal es correcta, y conservadora.**

---

## L2b · Control positivo · **el instrumento SÍ ve `R/A_azul > 1`** — y encuentra dónde

**Script:** `r9a_a1b_control.py` → `salida_a1b.txt`. Un resultado que nunca cruza el umbral es sospechoso
(regla 4). Se construye el caso en que la conservación **debe** romperse: subir `Δ`, porque el anticono honesto
es `~Poisson(2Δλ)` y en cuanto se acerca a `k = 30` los honestos se vuelven rojos **entre ellos**, sin que el
atacante gaste un bloque. `Δ` se parchea en `d8_lib.DELTA` en tiempo de ejecución (declarado; el fichero no se
toca).

| `Δ` | `2Δλ` | `P(Poi>k)` | `δ₀` medido (`α = 0`) | `R/A_azul` (`α=0`) | `W_pub/H` (`α=0`) | `R/A_azul` (`α=0,35`) | `W_pub/H` (`α=0,35`) |
|---:|---:|---:|---:|---:|---:|---:|---:|
| **4** *(diseño)* | 8 | 5,4e−10 | **0,0000** | — (`A=0`) | **1,0000** | 0,632 | **1,179** |
| 8 | 16 | 5,7e−04 | **0,0020** | ∞ | 0,9980 | 0,709 | 1,145 |
| 12 | 24 | 9,6e−02 | **0,0828** | ∞ | 0,9172 | 0,800 | 1,101 |
| 16 | 32 | 5,9e−01 | **0,2858** | ∞ | 0,7142 | 0,958 | 1,022 |
| **20** | 40 | 9,4e−01 | **0,4428** | ∞ | 0,5572 | **1,121** | **0,9360** |
| 24 | 48 | 1,0 | 0,5401 | ∞ | 0,4599 | 1,249 | 0,8643 |
| 32 | 64 | 1,0 | 0,6526 | ∞ | 0,3474 | 1,382 | 0,7899 |

**Dos lecturas, las dos importantes:**

1. **El instrumento no está ciego:** mide `R/A_azul = 1,12-1,38` y `W_pub/H = 0,79-0,94` en cuanto el caso
   existe. El «≤ 1» de A1 es un **hallazgo**, no una limitación.
2. **El `δ` que de verdad existe no lo impone el atacante: lo impone `Δ`.** Y en el modelo del paper el
   adversario **no puede** tocarlo (L1024-1027: no retrasa honesto↔honesto por encima de `Dmax`). A `Δ = 4` el
   `δ` gratis es `0,0000`; a `Δ = 8` —el valor de la LAGUNA que D8 dejó abierta— es **0,0020**, todavía
   irrelevante; a `Δ = 12` es **0,083** y ya mueve la frontera. **`k = 30` protege hasta `Δ ≈ 10 s`.**

---

*(en curso: L3 · simulación del presupuesto repartido; L4 · frontera; L5 · veredicto)*
