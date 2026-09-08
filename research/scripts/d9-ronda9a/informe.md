# D9 · Ronda 9a — ¿es correcto el «doble conteo»? Auditoría de `dag-poas-tras-d8-palancas.md` §1

**Fecha:** 2026-09-08, noche · **Auditor:** D9, adversarial, Opus 5 · **Directorio:** `research/scripts/d9-ronda9a/`
**Instrumento:** `r9a_lib.py` (extiende `d8-ronda8/d8_lib.py` y `d9-ronda8c/{r8c_gd,r8c_sim}.py`; **no toca ninguno**).

---

## Relanzamiento: estado heredado y qué verifiqué de él

**Este informe lo empezó un D9 que murió por cuota de sesión.** Lo de abajo es lo que heredé, lo que
comprobé de ello y lo que hice con el trabajo que dejó a medias. (Secciones L0, L1, L2, L2b: suyas,
verificadas por mí una a una. Secciones L1-bis, L3, L4, L5 y el veredicto: mías.)

| Heredado | Estado en disco | Qué hice |
|---|---|---|
| `informe.md` L0, L1, L2, L2b (commits `3fa103f`, `c604f97`) | Commiteado | **Verificado** — ver abajo. L1 **corregido**: la holgura no es «O(Δλ) por evento», y hay un contraejemplo en el propio paper |
| `r9a_a1_intercambio.py`, `salida_a1.txt` | Commiteado, corrida completa | Leído; la validación contra `d8_a1b` (5 `α`, `δ` a 3-4 decimales) es correcta |
| `r9a_a1b_control.py`, `salida_a1b.txt` | Commiteado, corrida completa | Leído; **L2b es el hallazgo más importante del D9 anterior** y lo suscribo con una salvedad (abajo) |
| `r9a_lib.py`, `r9a_a2_split.py`, `salida_a2.txt` | **Sin commitear**, corrida A2 **completa** (249 s, 7 200 corridas, controles incluidos) | **Utilizables. Commiteados** en `239a9dc` como WIP heredado. Es el punto B del encargo, entero → §L3 |
| `r9a_a4_parcial.py` | **Sin commitear, NUNCA EJECUTADO** (`salida_a4.txt` no existía) | Leído, correcto. **Ejecutado por mí** → §L4 |
| `r9a_a3_frontera.py`, `salida_a3.txt` | Commiteado con la salida **VACÍA (0 bytes)** | El script es correcto pero tarda ~15 min (barrido fino × 9 modelos de Skellam): el D9 anterior murió antes de que terminara. **Ejecutado por mí** → §L5 |
| `__pycache__/r9a_lib.cpython-313.pyc` | **Commiteado por error** | Sacado del índice (`git rm --cached`) en `239a9dc` |

**Nada de lo heredado se descartó.** Todo era utilizable; lo único que corrijo es una afirmación de L1
(§L1-bis) y una lectura de L2b.

### Qué verifiqué de L1 — la parte que se sostiene

El álgebra de la Proposición A la rehíce entera y **es correcta**:

- `BlueSet(B′) = BlueSet(D) ⊔ X` y `BlueSet(C) = BlueSet(D) ⊔ Y` con **el mismo** `BlueSet(D)`, porque
  `D` está en las dos cadenas seleccionadas y `BlueSet(D)` depende solo de `D` (GHOSTDAG es determinista
  por bloque: `protocol.rs:135-160`, `blue_score(sp) + |mergeset_blues|`). Luego `score(C) ≥ score(B′)`
  ⟺ `|Y| ≥ |X|`. ✓
- `R = |X_h| − |X_h ∩ Y_h|` ✓ · `|Y_a| − |X_a| ≤ |Y_a| − |Y_a ∩ X_a| = A` ✓ ·
  `|Y_h| − |X_h ∩ Y_h| = |Y_h \ X_h|` ✓ · luego **`R ≤ A + |Y_h \ X_h|`**. ✓
- La cita del paper que sostiene 1.1 es literal y **decisiva**: `phantom-ghostdag.txt` L1034-1036,
  *«The honest score wH(t) is defined as the score of the virtual block of the honest node at time t»*.
  El score del bloque virtual honesto **incluye los azules del atacante**. La corrección de fondo del
  agente principal —que `(1−α)(1−δ)λ` no es el denominador de la carrera— **es correcta y está bien
  fundada en la fuente**.

### Qué corrijo de L1

1. **La holgura NO es «O(Δλ) por evento» en el sentido que L1 escribe.** L1 dice que `|Y_h \ X_h|` son
   «honestos creados en `(t−Δ, t]`». Falso: son los honestos **fuera de `past(B′)`**, y `B′` es la punta
   honesta *seleccionada*, creada en `t_{B′} ≤ t`; el intervalo correcto es `(t_{B′}−Δ, t]`, no `(t−Δ, t]`.
   El D9 anterior escribió el intervalo equivocado. El **efecto** es el mismo orden de magnitud
   (`t − t_{B′} ~ Exp(1/((1−α)λ))`), pero la afirmación tal como está escrita es falsa.
2. **La otra rama de la holgura no es `0`.** L1 dice que los honestos ya rojos en la vista de `B′` «son
   0 si el `δ` natural es 0». Eso es circular: `δ` natural `= 0` es lo que L2b **mide**, no algo que se
   pueda suponer dentro de la demostración. La rama correcta es: son `≤ δ₀·(honestos vivos)`, con
   `δ₀ = P(Poisson(2Δλ) > k)`, **medido** en L2b.
3. **Y el paper contiene un contraejemplo declarado a la versión literal «uno a uno como máximo»**, que
   L1 no menciona. Es §L1-bis, y es el aporte principal del relanzamiento.

### Qué verifiqué de L2b — y la salvedad

L2b es correcto y su lectura 1 (el instrumento no está ciego) la suscribo entera: **el sitio donde el
D9 anterior encontró `R/A_azul > 1` es `Δ ≥ 20 s`**, y ahí lo encuentra sin que el atacante gaste un
solo bloque (`δ₀ = 0,443` a `α = 0`, `W_pub/H = 0,557`). Eso **no es** un contraejemplo a la tesis del
agente principal: es un contraejemplo a la idea de que `δ` sea una palanca *del adversario*. A `Δ = 4 s`
(el valor del diseño) `δ₀ = 5,4·10⁻¹⁰`, es decir cero.

**La salvedad, que L2b no dice y hay que decir:** la frase «en el modelo del paper el adversario **no
puede** tocar `Δ`» es cierta *dentro del modelo* y **falsa en la red real**. `Δ` es el retardo honesto↔honesto
efectivo, y un atacante de red (eclipse parcial, inundación) lo sube — es exactamente lo que la línea A3
de D8 estudió. Así que la lectura correcta es: **`δ = 0` vale bajo el adversario del paper; un atacante
que consiga `Δ_ef ≥ 12 s` compra `δ ≈ 0,083` sin gastar espacio.** Eso es una **LAGUNA**, no un
refutación, y la frontera se da abajo en los dos regímenes.


---

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

---

## L1-bis · El contraejemplo está en el paper — y no sobrevive a la condición de victoria · **REFUTADO**

**Script:** `r9a_a5_cota.py` → `salida_a5.txt`. Formal + comprobación numérica exhaustiva.

### 1-bis.1 · Lo que el Lema 9 dice, literalmente

`research/fuentes/phantom-ghostdag.txt` L1138-1147, cita exacta:

> *«It follows that the adversary gains the most by publishing k + 1 blocks in the anticone of the
> selected parent … all the blocks in the anticone of the old selected parent, except the k + 1 blocks
> published by the adversary, will be considered red … On average, there are at most 2Dλ such blocks,
> so that **the adversary has managed to replace k + 2Dλ blue blocks with k + 1 blue blocks**.»*
> …
> *«the highest factor by which the adversary can reduce the growth of the honest blue set is
> `k/(k+2Dλ) = 1 − 2Dλ/(k+2Dλ)`»*

Con las constantes del diseño (`k = 30`, `2Dλ = 8`): **`R = 38` rojos por `A = 31` azules del atacante,
`R/A = 1,226`**. Y `1 − 30/38 = 0,2105`: **ahí está, exactamente, el `δ = 0,2105` de las rondas 3-8.**

**Esto es un contraejemplo declarado, y de la fuente primaria, a la afirmación literal que se me pide
auditar** («uno a uno como máximo»). El D9 anterior no lo cita. Lo trato como el encargo manda.

### 1-bis.2 · Por qué no se realiza: el paper no comprueba su propia condición de victoria

El paper exige *«such that the most recent published block has score at least as large as that of the
selected parent»* y luego **no lo verifica**. Con el modelo cerrado de la auditoría 7 §1.1 (privada
`= fork + k + J`, honesta `= fork + J(1−α)/α`), una ráfaga de `J = k+1` bloques gana solo si
`k+1 < J* = kα/(1−2α)`, o sea `α > (k+1)/(3k+2) = 0,3370`. Medido (`salida_a5.txt` §5.2):

| `α` | `J*` | ¿`k+1 < J*`? | ¿gana? | `R(k+1)` | **`R/A`** |
|---:|---:|:--|:--|---:|---:|
| **0,00** | 0,0 | no | **no** | 0,0 | **0,000** |
| 0,10 | 3,8 | no | **no** | 249,0 | 8,032 |
| 0,25 | 15,0 | no | **no** | 63,0 | 2,032 |
| 0,30 | 22,5 | no | **no** | 42,3 | 1,366 |
| 0,33 | 29,1 | no | **no** | 32,9 | 1,063 |
| 0,35 | 35,0 | **sí** | **sí** | 27,6 | **0,889** |
| 0,40 | 60,0 | sí | sí | 16,5 | 0,532 |
| 0,45 | 135,0 | sí | sí | 7,9 | 0,255 |

**Donde `R/A > 1`, la ráfaga no cambia la cadena (no hay rojos). Donde cambia la cadena, `R/A < 1`.**
El `k + 2Dλ` del paper es una cota que su propia condición de victoria no admite con estas constantes.

### 1-bis.3 · La equivalencia cerrada · **DEMOSTRADO**

Con `R(J) = max(0, J(1−α)/α − k)` y `A = J`:

```
gana ⟺ k + J > J(1−α)/α ⟺ J(1−α)/α − k < J ⟺ R < A          (para α > 0)
```

> **Teorema (ráfaga).** Para todo `α ∈ (0, 1/2)` y todo `J ≥ 1`: **una ráfaga produce más rojos que
> bloques azules del atacante si y solo si la ráfaga PIERDE** — y una ráfaga que pierde no deja ningún
> rojo permanente, porque la cadena honesta la revierte y los honestos vuelven a ser azules. ∎

Comprobado por barrido exhaustivo `J = 1..1000 × 10 valores de α` = **10 000 comprobaciones,
0 discrepancias** (cobertura: 1 080 casos «gana», 9 920 «pierde»; las dos ramas). `max R/A` entre las
que ganan: 0,9958 (`α=0,33`), 0,9748 (0,35), 0,9915 (0,40), 0,9999 (0,49) — **nunca ≥ 1**.
Es la explicación exacta del «máximo absoluto 0,995» medido en L2.

### 1-bis.4 · Y aun CONCEDIENDO la holgura del paper, parasitar no ayuda

Escenario pesimista: se concede que cada evento gasta `k+1` bloques publicados y produce `2Dλ` rojos de
exceso. Frecuencia máxima `ν ≤ α_p λ/(k+1)`, luego el exceso de rojos es
`c·α_p λ` con **`c = 2Dλ/(k+1) = 0,2581`**, y `tasa_Wpub ≥ (1 − α − c·α_p)λ`. Con `α = α_p + α_f`:

```
r(β) = (1−β)α / (1 − α − c·β·α),      β = α_p/α ∈ [0,1]
dr/dβ|₀ < 0  ⟺  −(1−α) + c·α < 0  ⟺  α < 1/(1+c) = 0,7949
```

| `α` | `β=0` | `β=0,25` | `β=0,5` | `β=0,75` | `β=1` | argmax |
|---:|---:|---:|---:|---:|---:|---:|
| **0,00** | 0,0000 | 0,0000 | 0,0000 | 0,0000 | 0,0000 | 0,00 |
| 0,25 | **0,3333** | 0,2555 | 0,1742 | 0,0891 | 0,0000 | **0,00** |
| 0,33 | **0,4925** | 0,3815 | 0,2630 | 0,1361 | 0,0000 | **0,00** |
| 0,35 | **0,5385** | 0,4184 | 0,2893 | 0,1503 | 0,0000 | **0,00** |
| 0,40 | **0,6667** | 0,5225 | 0,3647 | 0,1914 | 0,0000 | **0,00** |
| 0,45 | **0,8182** | 0,6478 | 0,4574 | 0,2430 | 0,0000 | **0,00** |

`argmax β = 0` en **todas** las filas, y `1/(1+c) = 0,795 > 1/2` lo garantiza analíticamente para todo
`α < 1/2`. **Etiqueta: DEMOSTRADO. La tesis del agente principal sobrevive incluso concediendo el
exceso de `2Dλ` rojos por evento que el paper reclama.** `r = α/(1−α)` es la base correcta.

### 1-bis.5 · «Rojos de rojos»: no existe — cerrado con el código, no con simulación

Sub-pregunta (i) del encargo. En `rusty-kaspa` @ `c338d495`, `check_blue_candidate_with_chain_block`
(`consensus/src/processes/ghostdag/protocol.rs:194`) recorre **`chain_block.data.mergeset_blues`** —
solo los AZULES— para contar el anticono azul del candidato, y solo incrementa
`candidate_blue_anticone_size` con ellos (L205-212). **Un bloque rojo nunca cuenta en el anticono azul
de otro.** Consecuencia: enrojecer un bloque **libera** presupuesto `k` para los demás; la redness no
se propaga, y no puede existir una cascada «un bloque publicado enrojece 1, que enrojece 2, que
enrojece 4». **Etiqueta: DEMOSTRADO (por código de referencia).**

---

## L3 · Simulación del reparto `α = α_p + α_f` — punto B del encargo · **VERIFICADO**

**Script:** `r9a_a2_split.py` → `salida_a2.txt` (heredado, corrida completa: 6 `α` × 5 repartos × 5
flujos × 4 `J` × 12 semillas = **7 200 corridas**, 249 s, horizonte 1 800 s, `t₀ = 60 s`).

**Los cuatro controles del encargo, los cuatro pasan:**

| Control | Exigido | Medido |
|---|---|---|
| `α_p = 0` reproduce la carrera simple | deriva `= 2α−1` | `−0,4039 / −0,2974 / −0,2003 / −0,0980` vs `−0,400 / −0,300 / −0,200 / −0,100` (`α = 0,30/0,35/0,40/0,45`) |
| `α = 0` da ventaja 0 | todo a cero | `adv_fin=0, n_f=0, n_pub=0, ráfagas=0` |
| `α_f > 0,5` gana | deriva `> 0` | `α = 0,55`: **`+0,1155`** (predicho `+0,100`) |
| Contadores de rama | `> 0` en las dos | `her`, `frl`, `sprob`, `raf` todos con cobertura |

**El hallazgo del D9 anterior que hay que subrayar, porque es un artefacto de instrumento que casi se
lee como resultado:** en las variantes `hereda` / `parasito` (el flujo privado fusiona puntas públicas),
`find_selected_parent` es un **`max` sobre `blue_work`** (`protocol.rs:99-106`), así que si un padre
fusionado tiene más `blue_work` que la punta privada, **el padre seleccionado deja de ser el flujo**: la
«cadena privada» se funde con la pública y deja de ser una cadena competidora. El contador `sprob` lo
cuenta y `div_seg` (profundidad de divergencia en segundos) cae de 1 737 s a **8-208 s**. Su deriva `≈ 0`
**no es una carrera ganada: es que ya no hay carrera.** De ahí las variantes `_est` (estrictas).

**La pregunta directa, con el filtro de divergencia (solo cadenas que siguen compitiendo):**

| `α` | `α_p/α = 0 %` | 25 % | 50 % | 75 % | 100 % |
|---:|---:|---:|---:|---:|---:|
| 0,30 | **−0,3908** | −0,4737 | −0,5619 | −0,6430 | — |
| 0,35 | **−0,2832** | −0,3766 | −0,4841 | −0,5828 | — |
| 0,40 | **−0,1847** | −0,2993 | −0,4149 | −0,5198 | — |
| 0,45 | **−0,0824** | −0,2086 | −0,3462 | −0,4799 | — |
| 0,55 | **+0,1312** | −0,0270 | −0,2023 | −0,4484 | — |

**La deriva es máxima en `α_p = 0` en TODAS las filas, y monótona decreciente en `α_p`.** Dedicar
espacio a la parásita no solo no ayuda al que corre: **le quita exactamente el espacio que gasta.**

**Y la conservación, celda a celda** (`W_pub/H`, debe ser `≥ 1`):

| `α` | 0 % | 25 % | 50 % | 75 % | 100 % |
|---:|---:|---:|---:|---:|---:|
| **0,00** | 1,0000 | 1,0000 | 1,0000 | 1,0000 | 1,0000 |
| 0,35 | 1,0000 | 1,0050 | 1,0177 | 1,0481 | **1,4582** |
| 0,45 | 1,0000 | 1,0144 | 1,0464 | 1,0933 | **1,8132** |

**Ninguna celda baja de 1,0000.** Y `W_pub/H` **sube** con `α_p`: cuanto más parasita, **más rápido**
crece el `blue_work` de la cadena pública.

---

## L4 · Publicar solo PARTE de la cadena privada — maniobra (ii)-b · **REFUTADA**

**Script:** `r9a_a4_parcial.py` → `salida_a4.txt`. Escrito por el D9 anterior, **ejecutado por mí**
(49 s, 6 `α` × 4 `J` × 4 `frac_pub` × 12 semillas = **1 152 corridas**).

Es la maniobra que rompería la tesis si funcionara: comprar `δ` con los bloques publicados y **conservar**
la ventaja con los que se quedan en privado — los presupuestos dejarían de ser disjuntos.

**Validación del instrumento:** `frac_pub = 1,00` reproduce la parásita de D8 **exactamente**:
`δ = 0,1544 / 0,2867 / 0,3065 / 0,4366 / 0,5834` a `α = 0,25/0,33/0,35/0,40/0,45`. Idéntico a
`d8-ronda8/salida_a1b.txt`. ✓

| `α` | `frac_pub` | `δ` | `R/A_azul` | **`W_pub/H`** | `adv_max` | ráfagas | **cambios de cadena** |
|---:|---:|---:|---:|---:|---:|---:|---:|
| **0,00** | 1,00 | **0,0000** | — | **1,0000** | 0,0 | 0,0 | **0,0** |
| 0,25 | 1,00 | 0,1544 | 0,540 | 1,1312 | 20,8 | 27,8 | 27,8 |
| 0,25 | 0,50 | **0,0550** | 0,319 | 1,1172 | 22,3 | 54,9 | **2,2** |
| 0,25 | 0,25 | 0,0625 | 0,495 | 1,0637 | 24,9 | 109,3 | **0,2** |
| 0,35 | 1,00 | 0,3065 | 0,632 | 1,1789 | 30,5 | 19,9 | 19,9 |
| 0,35 | 0,50 | **0,1372** | 0,540 | 1,1158 | 32,5 | 38,1 | **1,9** |
| 0,35 | 0,25 | **0,1033** | 0,716 | 1,0409 | 39,3 | 75,7 | **0,8** |
| 0,45 | 1,00 | 0,5834 | 0,746 | 1,1984 | 39,9 | 12,2 | 12,2 |
| 0,45 | 0,25 | **0,2191** | 0,350 | 1,4090 | 43,4 | 97,3 | **3,0** |

**Tres lecturas, las tres contra la maniobra:**

1. **`δ` CAE al retener** — 0,3065 → 0,1033 a `α = 0,35`. Retener no compra `δ`: lo **pierde**, porque la
   publicación parcial ya no gana al padre honesto (`cambios` cae de 19,9 a **0,8**: el 99 % de las
   publicaciones parciales **no hacen cambiar de cadena a la red**).
2. **`W_pub/H ≥ 1,0409` en las 24 celdas con `α > 0`**, y `= 1,0000` exacto en la fila `α = 0`. La
   conservación aguanta en toda la familia.
3. **`adv_max ≤ 43,4 < 3k = 90` en todas.** La ventaja retenida **no supera la constante `3k` que
   `prev()` ya le regala al atacante** como desplazamiento inicial de la Skellam (Lema 12, L1200-1206:
   `score(C) ≤ score(B) + 3k`). Retener no crea ventaja fuera de lo ya contabilizado.

**Etiqueta: REFUTADA la maniobra (ii)-b.** No existe la publicación parcial que compre `δ` gratis.

---

## L5 · La frontera recalculada — punto C del encargo · **VERIFICADO**

**Scripts:** `r9a_a6_frontera_delta.py` → `salida_a6.txt` (mío) y `r9a_a3_frontera.py` → `salida_a3.txt`
(heredado, ejecutado por mí), contrastados con `r9a_a7_frontera_rapida.py` → `salida_a7.txt`.
Los tres usan el **`prev()` literal de `d8-ronda8/d8_a1c_riesgo.py:29-40`** (Skellam del Lema 10,
ventaja inicial `3k = 90`, `F = 19 080 s`, `I = 4 200 s`, 7 509 épocas/año, unión a 10 años `< 10⁻¹⁰`).

### 5.1 · La frontera con el `δ` que el atacante SÍ puede imponer gratis: **no hay ninguno**

L1-bis lo demuestra y L2b lo mide: con `Δ = 4 s` el `δ` que el atacante compra **sin gastar espacio**
es `δ₀ = 0,0000` (medido a `α = 0`; la cola de Poisson da `5,4·10⁻¹⁰`). Y el `δ` que compra **gastando
espacio** le sale del mismo presupuesto de la carrera y le sale a pérdida (L3). Luego el modelo correcto
para un atacante único es **`δ = 0`**:

| Modelo | Frontera `10⁻¹⁰` | `r = 1` | Colchón sobre 33 % |
|---|---:|---:|---:|
| (a) `δ` de D8 con el **mismo `α`** en los dos sitios (auditoría 7) | 36,5 % | 0,381 | +3,5 |
| (b) Lema 9 como tasa, `δ = 0,2105` (rondas 3-8) | 40,8 % | — | +7,8 |
| **(c) atacante único, `δ = 0`** | **46,8784 %** | 0,5000 | **+13,88** |

**La tesis del agente principal se confirma con su número exacto: 46,88 %.** El 36,5 % de la auditoría
7 es el resultado de meter `α` dos veces.

### 5.2 · El parásito racional AJENO (sub-pregunta (iii)) — reproducidos sus tres números

Un parásito de cuota `α_p` que corre la parásita en su óptimo hace que la tasa pública valga
`(1−α_f−α_p)λ` (L1-bis: su aportación azul se compensa exactamente con los rojos que produce). Es decir:
**un parásito ajeno de cuota `α_p` hace el mismo daño que un granjero de cuota `α_p` APAGADO.** Ni más.

| `α_p` ajeno | Frontera **del atacante** | Suma `α_f + α_p` | `r = 1` en | vs 33 % |
|---:|---:|---:|---:|---:|
| **0 %** | **46,8784 %** | 46,88 % | >0,50 | +13,88 |
| 10 % | **42,0270 %** | 52,03 % | 0,4500 | +9,03 |
| 20 % | **37,1840 %** | 57,18 % | 0,4000 | +4,18 |
| 33 % | **30,9036 %** | 63,90 % | 0,3350 | −2,10 |

El agente principal escribió «42,0 / 37,2 / 30,9 %». **Reproducidos a la cuarta cifra.** Y la lectura
que él no escribe: para bajar la frontera al 33 % hacen falta **63,9 % del espacio total** entre
atacante y parásito — y el parásito **no es del atacante**: es un tercero racional que hay que suponer
coordinado o simultáneo.

### 5.3 · La palanca que SÍ existe, y que no es el espacio: `Δ` · **LAGUNA**

Con el `δ₀` **medido** en L2b a `α = 0` (no con la cola de Poisson, que sobreestima: a `Δ = 16` da 0,59
frente a 0,286 medido):

| `Δ` (s) | `δ₀` medido a `α = 0` | Frontera `10⁻¹⁰` | `r = 1` | vs 33 % |
|---:|---:|---:|---:|---:|
| **4** *(diseño)* | **0,0000** | **46,8784 %** | >0,50 | **+13,88** |
| 8 *(LAGUNA de D8)* | 0,0020 | 46,8268 % | 0,4995 | +13,83 |
| 12 | 0,0828 | 44,6542 % | 0,4784 | +11,65 |
| 16 | 0,2858 | 38,3337 % | 0,4166 | +5,33 |
| **20** | 0,4428 | **32,3788 %** | 0,3578 | **−0,62** |
| 24 | 0,5401 | 28,0899 % | 0,3150 | −4,91 |
| 32 | 0,6526 | 22,4269 % | 0,2578 | −10,57 |

**`k = 30` con `λ = 1` aguanta hasta `Δ ≈ 16 s` con colchón, y el 33 % se pierde en `Δ ≈ 20 s`.** Esto
es el resultado operativo de esta ronda: **el número que hay que medir no es `α`, es `Δ`.** Con `Δ = 8`
(la LAGUNA que D8 dejó abierta) el diseño está holgado; con `Δ_ef ≥ 20 s` —alcanzable por un atacante
de **red**, no de espacio, y el modelo del paper no lo cubre (L1024-1027)— la frontera cae por debajo
del umbral operativo del 33 %.

