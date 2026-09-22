# PROGRESO — P-REVELACION (REV-v1.0)

Bitácora del encargo `P-ZRX/P-REVELACION/PROMPT.md`. **Las §1-§4 se escribieron ANTES de abrir
`research/scripts/d8-ronda10a/r10a_lib.py`** (requisito del encargo §4). Lo posterior va fechado y
marcado.

---

## 1 · Comprobaciones de entrada (encargo §6)

Ejecutadas desde la raíz `/home/katana/zeo/ZEROX`, antes de escribir nada:

```text
$ LC_ALL=C sha256sum -c P-ZRX/P-REVELACION/ENTRADA.sha256
P-ZRX/P-REVELACION/PROMPT.md: OK

$ git -C /home/katana/zeo/ZEROX status --short
 D ZEROX-EN-NUMEROS.md
?? .trash/
?? P-ZRX/
?? veritas/consenso/poda-post-v1/
?? veritas/consenso/prueba-recursiva-v1/
?? veritas/seguridad/

$ date
lun 21 sep 2026 11:57:00 CEST
```

Entorno: Julia 1.13.0 (`./veritas/julia.sh`), AMD Ryzen 9 9950X3D (`znver5`), 16 núcleos físicos /
32 hilos lógicos, 123 GiB de RAM visibles. `~/.julia` es de **solo lectura** en esta máquina, así que
la caché de compilación se redirige con `JULIA_DEPOT_PATH="/tmp/dsh-julia-depot:$HOME/.julia"`,
igual que documentó ADL-v1.0 (`P-ZRX/P-ADELANTO/investigacion/INFORME.md:433-441`).

**Aviso de huellas, primera línea del informe:** las cinco entradas de `git status` de arriba
**no son mías** y ya estaban al empezar (son las mismas que ADL-v1.0 declaró en su propia incidencia,
`P-ZRX/P-ADELANTO/investigacion/INFORME.md:3-11`). `P-ZRX/P-REVELACION/PROMPT.md` verifica. Si algo
cambia entre la comprobación de entrada y la de salida que no sea mío, se dice en `INFORME.md`.

## 2 · Presupuesto declarado (encargo, adaptación LINEO §11)

| Recurso | Presupuesto |
|---|---|
| Tiempo de cómputo total | **3 h** de pared; ninguna corrida individual > 20 min salvo las colas de tasa baja, con techo de **1 h** |
| Hilos | **máximo 16** (tope del encargo); escalado medido en `1, 2, 4, 8, 16` |
| RAM | **8 GiB** |
| Disco | **256 MiB** en `P-ZRX/P-REVELACION/investigacion/` |
| GPU | no se usa: el problema es una recursión escalar por eventos, con dependencia secuencial; §5.7 de LINEO no se justifica |

Si se agota: checkpoint en `resultados/`, estado **inconcluso** y nada de convertir un timeout en
falsedad.

---

## 3 · La recursión, escrita desde las reglas (antes de leer `r10a_lib.py`)

### 3.1 Unidades y objetos

Todo en **índices de slot de PoT** (`C-FLU-01`, `SPEC.md:1507-1526`: una comparación de consenso
**MUST NOT** depender de `τ_nom`). `t` es el tiempo de pared en slots, con el honesto a 1 slot/s
nominal. Las entradas `L, I, W_dec, D, S_max, Lrev, ρ, α` son **símbolos**, no constantes fijadas
(encargo §9).

Se separan dos objetos que no se mezclan:

- **`V` — ventana de adelanto.** `V(t) = Φ_a(t) − Φ_h(t)`, diferencia en slots entre la frontera de
  PoT del atacante y la del honesto. Es lo que explota el sembrador y lo que gobierna `M` y
  `T_seal`. **Oscila dentro de cada época.**
- **`steering`.** Por época `j`: si el atacante tiene su cadena común en `t_j − 1` **antes** del plazo
  de decisión `D_j = T_j + W_dec`, i.e. `Φ_a(D_j) ≥ t_j − 1`. Su umbral es `ρ*`. Nada que ver con `V`.

Las dos fronteras son **posiciones de PoT**, y `V` es la diferencia, que es exactamente el objeto
`A = a(t) − h(t)` de ADL (`HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md:9-16`): `a(t) = mín(Φ_a, Γ) − D`,
`h(t) = mín(Φ_h, Γ) − D`, luego `a − h = Φ_a − Φ_h` cuando las dos están por debajo de `Γ`. **La
diferencia entre mi recursión y ADL no es la definición de `A`: es qué es `Φ_a`.**

### 3.2 El modelo por eventos (M1)

Épocas `j = 1, 2, …`:

```text
T_j = j·I                                  umbral de época (C-FLU-01)
s_j = T_j + off_j                          slot del ancla (C-FLU-04); off_j ∈ [0, S_max)
t_j = s_j + L                              instante de activación (C-FLU-07)
propia_j ~ Bernoulli(α)                    si el ancla es un bloque del atacante
```

El atacante avanza a razón de **ρ slots de PoT por slot de pared** y **solo mientras tiene la
entropía que necesita**. Para completar el slot `t_j` hacen falta las dos cosas: (1) haber llegado
con su cadena común a `t_j − 1`; (2) tener `entropía_j`. De ahí la recursión, con `τ_j` = instante en
que completa el slot `t_j`:

```text
τ_j = máx( τ_{j-1} + (t_j − t_{j-1})/ρ ,  e_j + 1/ρ )
```

donde `e_j` es **cuándo obtiene `entropía_j`**, y es lo único que cambia entre variantes:

| variante | `e_j` |
|---|---|
| ancla **ajena**, sin (h), especula | `s_j` |
| ancla **ajena**, sin (h), espera la decisión | `s_j + W_dec` |
| ancla **propia**, sin (h) | `máx(s_j, t(Φ_a ≥ s_j + D))` — sus dos entradas son suyas |
| con (h) | `+ Lrev/ρ` (el VDF de revelación corre **en paralelo**, en su propia línea de AES) |

El `+D` de la variante propia es `C-POT-05` (`SPEC.md:1403-1417`): `pot_output(I_j) = salida(f, s_j + D)`.
Para un ancla ajena el atacante **recibe** `pot_output` en la cabecera del bloque, luego no necesita
frontera propia.

La frontera honesta se **simula con las mismas barreras** (encargo §4), con `e_j^h = s_j + W_dec + Lrev`
a velocidad 1: así la puntualidad `Lrev ≤ L − W_dec` es una **invariante observada**, no un supuesto.
Con el timekeeper honesto `D` por delante de su frontera de bloques (`premisa 6` de ADL,
`HIPOTESIS…:43-51`), la condición real es **`Lrev ≤ L − W_dec − D`**, porque la frontera honesta cruza
`t_j` en `t_j − D` y no en `t_j`. Se implementa el interruptor `premisa6 ∈ {sí, no}` y se publican las
dos.

### 3.3 Predicciones cerradas (escritas antes de leer el instrumento histórico)

**P1 — sin (h), régimen estacionario, adversario que espera a la decisión.** Con `Δ_j = s_{j+1} − s_j = I`:

```text
V_min  = L − 1/ρ − W_dec − D
V_max  = (L − 1 − W_dec − D) + I(1 − 1/ρ) − 1/ρ
amplitud = V_max − V_min = I(1 − 1/ρ)
```

- Es **exactamente** `A_core = (L − 1 − W_dec) + I(1 − 1/ρ)`
  (`P-ZRX/P-SEMBRADOR/investigacion/INFORME.md:86`, con `D = 0`), más el residuo discreto `−1/ρ`.
- Con `D = 0`, `W_dec = 0` (adversario que **especula**) es `L + I(1 − 1/ρ) − 1 − 1/ρ`: la forma de
  la **ronda 7** (`research/dag-poas-ancla-de-finalidad.md:319-322`).
- El tope de ADL, `L + I − W_dec − D` (`adelanto_frontera_inf`), es `V_max + 1 + (I+1)/ρ`: **la
  envolvente `ρ → ∞`, no el valor**.
- **Predicción:** `A_core` **no subestima**; es el máximo exacto para `ρ` finito bajo su adversario
  (espera), y ADL **sobreestima** en `≈ 1 + I/ρ`. `A_frontera` y `A_core` solo coinciden en `ρ → ∞`.
- **Bootstrap:** `V` crece a razón `(ρ−1)` mientras no está estancado; el tiempo hasta una ventaja
  `0,9·L` es `0,9L/(ρ−1)`. Es el control C1 de 9c §E.1.

**P2 — sin (h), rachas de anclas propias.** Un ancla propia **no bloquea** la barrera. Tras `r`
anclas propias seguidas la ventaja crece sin tope y la forma cerrada de la ronda 10a es

```text
V tras r anclas propias = (L + (r+1)·I)(1 − 1/ρ)      [− convención discreta]
steering  ⟺  (L + (r+1)·I)(1 − 1/ρ) ≥ L − W_dec + off
n* = ⌈ ((L − W_dec)·ρ/(ρ−1) − L) / I ⌉      tasa = α^(n*−1)
```

**P3 — con (h), la ventana `V` NO se anula.** Con `Lrev < L`:

```text
V_max = (L + I − 1 − W_dec − D) − (Lrev + I + 1)/ρ      [espera]
      = (L + I − 1 − D) − (Lrev + I + 1)/ρ              [especula]
```

que para `Lrev = L` es `(L+I)(1−1/ρ) − 1 − 1/ρ − D`: la forma de la ronda 7 con (h). Es **estrictamente
positiva para todo `ρ > 1`**, y con `Lrev = L − S_max` es **mayor** que con `Lrev = L` en `S_max/ρ`.

**Predicción:** `«sup A = 0 con (h) y ρ_max ≤ ρ*»` es **FALSO**. `ρ*` gobierna el *steering*, que es
otro objeto: es la holgura de la carrera `ρ(I + W_dec) − (Lrev + I) ≥ 0`, y su umbral es
`ρ* = (Lrev + I)/(I + W_dec)`. La forma `A_con_h = máx(0, (I + W_dec − 1) − (L + I)/ρ)` de ADL
(`adelanto_con_h`) es **esa holgura de steering**, no la ventana.

**P4 — lectura del validador (§0 del encargo).** Coincido en lo esencial y preciso dos cosas:
1. **De acuerdo:** el horizonte en escalera da un máximo finito en `ρ` que es `A_core` (no el tope
   continuo); ADL da la envolvente; con (h) la ventana es `(L+I)(1−1/ρ) > 0` y `sup A = 0` es falso;
   `ρ*` es *steering* y no ventana.
2. **Precisión 1:** la fórmula del validador `(L − 1 − W_dec) + I(1 − 1/ρ)` **no lleva `−D`**. Con
   `D-2 = A` y `C-POT-05`, `D` **resta** también en el escalonado (P1), porque la frontera honesta va
   `D` por delante. El `A_core` histórico no lleva `D` porque es anterior a `D-2 = A` y el propio
   `P-SEMBRADOR` lo declara pendiente (`INFORME.md:90`).
3. **Precisión 2:** con la premisa 6 activa, la condición de puntualidad del honesto es
   `Lrev ≤ L − W_dec − D`, **no** `Lrev ≤ L − W_dec`: la frontera honesta cruza la barrera `D` slots
   antes. Si el honesto no la respeta, **se estanca** y `V` crece por un motivo que no es del
   atacante; el simulador lo marca como violación de invariante y no lo cuenta como resultado.

### 3.4 Controles de regresión (encargo §4) — parámetros fijados en la fuente

Leídos en `research/scripts/d8-ronda10a/informe.md` y `r10a_b1_reloj.py:89,110,128` antes de
ejecutar:

| Control | Parámetros exactos | Cifra publicada a reproducir |
|---|---|---|
| C1 | `L = 19 080`, `I = 4 200`, `W_dec = 150`, `D = 0`, `offset = 0` | tope `L + I − W_dec = 23 130`; bootstrap `0,9L/(ρ−1)` = 477,00 h a `ρ=1,01`; tope simulado `L + I(1−1/ρ)` |
| C2 | `(L,I) ∈ {(7 200, 851), (3 600, 851), (19 080, 4 200)}`, `W_dec = 0` | sin (h) `L + I(1−1/ρ)`; con (h) `(L+I)(1−1/ρ)`; razón 1,000 en 15 filas |
| C3 | `(L,I) ∈ {(7 200, 851), (19 080, 4 200)}`, `W_dec(α) = 10/20/45`, `α ∈ {0,10;0,33;0,40}` | `ρ ≤ 1 ⇒ 0` exacto; `ρ = 1,001 ⇒ 0` con horizonte finito |
| `ρ*` | `(L,I,W_dec) = (7 200,851,20) → 9,24`; `(7 200,851,45) → 8,99`; `(3 600,851,20) → 5,13` | titular y §B.1.2 |
| `Lrev` | `Lrev/L = 0,979 → 9,07`; `0,50 → 5,11` | §A.1 |
| rachas | `α = 0,33`, `ρ=2,5 → n*=6, 3,914·10⁻³`; `ρ=3 → n*=5, 1,186·10⁻²` | §B.1.3 |

Los controles comparan **la simulación** con formas cerradas **externas** (9c §E.1, ronda 7, ronda
10a) y con `A_frontera` de `P-ZRX/P-ADELANTO/investigacion/veritas/seguridad/adelanto-v1/src/modelo.jl`,
que se **incluye como dependencia de lectura** (no se copia a mano y no se modifica). Ningún test
compara una fórmula con su propia transcripción (encargo §9).

---

## 4 · Registro de lo ejecutado

_(se completa a medida que avanza el encargo)_

---

## 5 · Registro de lo ejecutado (posterior a la lectura de `r10a_lib.py`)

### 5.1 Lectura del instrumento histórico

`research/scripts/d8-ronda10a/r10a_lib.py` se abrió **después** de escribir §3, como exige el
encargo, y **nunca se ejecutó**. Lo que cambió respecto de lo previsto:

- Su métrica de ventaja es `v = t_j − llegada_j` con `llegada_j = paso[j−1] + (t_j − t_{j−1})/ρ`:
  mide la llegada a la barrera **antes** de la espera y **sin** la frontera honesta `D` por delante.
  Coincide con mi `v_barrera`, que expongo aparte precisamente para reproducir C2.
- Su recursión **no** tiene el «−1» del tope (`t_j − 1`): corre hasta `t_j` a razón `ρ`. Eso basta
  para reproducir el tope con razón 1,000000 y **no** para reproducir el *bootstrap* (razón 0,977);
  la diferencia está cuantificada en `INFORME.md` §3.
- Su `arr_pro = f_sj` (frontera al pasar `s_j`) confirmó que el ancla propia **no espera** y que la
  semilla se conoce antes del slot; mi kernel lo implementa con `pot_output = salida(f, s_j + D)`
  (`C-POT-05`), que es la lectura con `D-2 = A`.

### 5.2 Contraste de las predicciones de §3.3 con lo medido

| Predicción | Medido | Veredicto |
|---|---|---|
| P1 `V_max = (L−1−W_dec−D)+I(1−1/ρ)−1/ρ` | `A_core − D` **exacto** (sin los dos residuos discretos) | **confirmada en estructura, corregida en la convención discreta**: los residuos `−1` y `−1/ρ` no aparecen porque el `−1` del tope y el `+1/ρ` del cruce se cancelan |
| P1 `V_min` régimen | `L − W_dec − D − 1` | **confirmada** |
| P1 `A_core` no subestima; ADL es la envolvente | diferencia `0,00` con `A_core`; ADL nunca se alcanza | **confirmada** |
| P2 rachas `α^(n*−1)` | razones 1,004-1,113 con IC | **confirmada** dentro del conteo |
| P3 con (h) `V_max = (L+I)(1−1/ρ)` | idéntico en las diez filas | **confirmada** |
| P3 `«sup A = 0»` falso | `A_con_h = 0` con `V_max = 4 830,6` | **confirmada** |
| P4 precisiones 1 y 2 al validador | `−D` resta `D` exacto; la puntualidad es `L−W_dec−D` | **confirmadas las dos** |

### 5.3 Incidencias propias, declaradas

1. **Carrera de datos detectada por el test de determinismo** (§11 de `runtests.jl`): los buffers
   `off`/`propia` se compartían entre hilos. Corregida asignándolos **por réplica**; los *checksums*
   de `vmax`, `vmin`, `hist` y `n_pro` son ahora idénticos con 1, 2, 4, 8 y 16 hilos. **Los barridos
   anteriores a la corrección se descartaron y se reejecutaron enteros.**
2. **`Revise` y `LoweredCodeUtils`**: el registro de Julia está por delante de los paquetes del
   depósito (solo lectura). `Manifest.toml` se fijó a las versiones presentes (`Revise 3.17.0`,
   `LoweredCodeUtils 3.8.0`), documentado aquí.
3. **`JULIA_DEPOT_PATH`**: `~/.julia` es de solo lectura; la caché de compilación va a
   `/tmp/dsh-julia-depot`, igual que en ADL-v1.0.

### 5.4 Presupuesto consumido

| Recurso | Declarado | Consumido |
|---|---|---|
| Tiempo | 3 h | **~81 s** de barridos + ~40 min de compilación/depuración; **no agotado** |
| Hilos | ≤ 16 | 16 en los barridos, escalado medido 1…16 |
| RAM | 8 GiB | < 0,5 GiB (el mayor `ResultadoBarrido`: 96 × 8 192 × 8 B ≈ 6 MiB de histogramas) |
| Disco | 256 MiB | **336 KiB** (`investigacion/` completo) |

---

## 6 · Comprobaciones de salida (encargo §6)

```text
$ LC_ALL=C sha256sum -c P-ZRX/P-REVELACION/ENTRADA.sha256
P-ZRX/P-REVELACION/PROMPT.md: OK

$ git -C /home/katana/zeo/ZEROX status --short
 D ZEROX-EN-NUMEROS.md
?? .trash/
?? P-ZRX/
?? veritas/consenso/poda-post-v1/
?? veritas/consenso/prueba-recursiva-v1/
?? veritas/seguridad/

$ date
lun 21 sep 2026 13:27:36 CEST
```

**Idénticas a las de entrada.** Las cinco entradas de `git status` **no son mías** y ya estaban
antes de empezar (son las mismas que ADL-v1.0 declaró). `PROMPT.md` verifica. Nada ajeno cambió, así
que el informe **no** necesita abrir con una incidencia de huellas.

---

## 7 · Entregables

| Fichero | Contenido |
|---|---|
| `investigacion/INFORME.md` | respuesta, F1-F5, controles, rendimiento, límites |
| `investigacion/CORRECCIONES-A-P-ADELANTO.md` | 15 filas de ADL con veredicto y evidencia |
| `investigacion/DECISIONES-PENDIENTES.md` | D1-D6 |
| `investigacion/PROGRESO.md` | esta bitácora |
| `investigacion/veritas/seguridad/revelacion-v1/` | instrumento (LINEO §1) + `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md` |
| `…/revelacion-v1/resultados/` | CONTROLES, ADL, F1-F5, TIEMPOS, TESTS, BENCH-h1…16, OPTIMIZACION, PERFIL, WARNTYPE, JET, ENTORNO |
