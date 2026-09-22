`A` bajo las reglas vigentes vale **`A = L_slots + I_slots − W_dec − D`** en el régimen estacionario y **no depende de `ρ`**; `+D` **resta** ahí —**nunca suma**: sumaría solo si el reto se derivara de `pot_output`, que `C-POT-03` prohíbe— y **se cancela en el transitorio**; `(h)` **sigue comprando lo que decía comprar** (baja la ventana de `L+I` a `≈I`, esto es, por el factor `ρ*`), pero bajo `C-FLU-01` su protección y su coste quedan **atados desde abajo a `F_slots`**, y esa es exactamente la realimentación que el encargo §4.4 sospechaba: **con el suelo a cero, bajar `F` a `F_carrera` deja `ρ*` en 2,15, al borde del techo físico del reloj**. El histórico `A_core` **subestima `A` para todo `ρ` realista** y **sobreestima el acantilado de `ρ = 1`**. `TAREAS.md` §2.9(c) punto 11 **se puede cerrar**, pero no con la cifra que ese punto suponía.

> **⚠️ INCIDENCIA DE HUELLAS (leer antes que nada, encargo §6).** La comprobación
> `sha256sum -c P-ZRX/P-ADELANTO/ENTRADA.sha256` **pasa** al terminar igual que al empezar
> (`P-ZRX/P-ADELANTO/PROMPT.md: OK`), y `PROMPT.md` no se tocó. **Pero `git status --short` tiene al
> terminar dos entradas que no tenía al empezar y que NO son mías:** ` D ZEROX-EN-NUMEROS.md` y
> `?? .trash/`. El fichero está **intacto** en `.trash/ZEROX-EN-NUMEROS.md` (mismo blob que `HEAD`,
> `f623319a…`, mismo tamaño y fecha): es un **movimiento**, reversible con
> `git checkout -- ZEROX-EN-NUMEROS.md`. No lo he restaurado porque la raíz del repositorio queda fuera
> de mi zona de escritura y el movimiento puede ser deliberado. Detalle y evidencias en
> `PROGRESO.md` §6.1.

# INFORME — P-ADELANTO · ADL-v1.0

**Pregunta** (encargo §0): cuántos slots conoce por adelantado un atacante con reloj `ρ` veces más
rápido, `A`, bajo las reglas vigentes —`pot_output = salida(f, slot + D)`, `D-2 = A`, y `L` derivada
por `C-FLU-01`— y qué cuesta cegarlo.

**Instrumento:** `investigacion/veritas/seguridad/adelanto-v1/` (ADL-v1.0, Julia 1.13.0, CPU `znver5`).
**Categoría:** `seguridad` (dominante); `consenso` y `rendimiento` secundarias. Motivo: la pregunta es
cuánta ventana de retos futuros conoce el atacante (seguridad); las reglas que la restringen son de
consenso y el precio de (h) se mide en núcleos por nodo (rendimiento).

**Presupuesto declarado antes de ejecutar:** 8 hilos de CPU, 4 GiB de RAM, 1 GiB de disco, corridas de
minutos. **No se agotó**: el barrido completo `--modo todo` tarda segundos y el directorio ocupa
menos de 1 MiB. Sin GPU (no la justifica: es un barrido analítico, no un Monte Carlo) y sin RNG.

---

## 1 · El resultado, en una tabla

Rejilla representativa: `F_slots = 7200` (2 h), `S_max = 150`, `I_slots = 851`, `W_dec = 20`,
`D = 4`, `t_obs = 10^6` slots. `L_slots = 7200` por `C-FLU-01` (`manda_F = true`).

| `ρ` | `A_core` (histórico) | `A_frontera` (este trabajo) | `A_con_h` | régimen |
|---:|---:|---:|---:|---|
| 1 | 0 | **0** | 0 | frontera |
| 1,001 | 7 179,85 | **1 000** | 0 | transitorio |
| 1,005 | 7 183,23 | **5 000** | 0 | transitorio |
| 1,008 | 7 186,29 | **8 000** | 0 | transitorio (justo por debajo del umbral) |
| 1,01 | 7 187,43 | **8 027** | 0 | flujo (`ρ_trans = 1,008027`) |
| 2 | 7 604,50 | **8 027** | 0 | flujo |
| 9 | 7 935,44 | **8 027** | 0 | flujo |
| 100 | 7 986,94 | **8 027** | 0 | flujo |
| ρ → ∞ | 8 030 | **8 027** | 0 | flujo |

`A_frontera = mín(ρ·t_obs, Γ − D) − mín(t_obs, Γ − D)` con `Γ = t_obs + I + L − W_dec`; su valor
saturado es `L + I − W_dec − D = 8027`. **`A_core` y `A_frontera` coinciden solo en `ρ → ∞`, y hasta
la convención discreta de un slot.**

**Tres consecuencias que cambian la lectura histórica:**

1. **`A` no depende de `ρ` en el régimen estacionario.** La cota la pone el **flujo** (las anclas son
   bloques honestos y su decisión tarda `W_dec`), no el reloj del atacante. Lo que `ρ` gobierna es
   **cuántos candidatos evalúa dentro de la ventana**, `n_eval = ρ·W_dec` — de ahí `I ≥ ρ_max·W_dec`
   (`R-FIN-14(f)`) —, que es **otra magnitud**. `A_core` mezcla las dos y por eso le sale una
   dependencia en `ρ` que la contabilidad de eventos no reproduce.
2. **`A_core` subestima `A`** para todo `ρ` realista: `7 604,5` frente a `8 027` con `ρ = 2`, y
   `7 986,9` frente a `8 027` con `ρ = 100`. Solo alcanza y supera el tope —por 3 slots, que son la
   convención discreta— a partir de `ρ ≈ 283`. Una cota de edad `M > sup A` tomada de `A_core` **no es
   suficiente**.
3. **El acantilado de `ρ = 1` es del modelo histórico, no del fenómeno.** `A_core` salta de `0` a
   `7 179,85` entre `ρ = 1` y `ρ = 1,001`; `A_frontera` es **continuo** (`A_frontera(1) = 0`,
   `A_frontera(1,001) = 1000`). El salto de `A_core` es el término de *presupuesto* `L − W_dec`
   concedido entero en cuanto `ρ > 1`.

---

## 2 · El modelo, y de dónde sale `D`

### 2.1 Fronteras de slots firmables

Firmar un bloque en el slot `s` exige dos cosas, y solo dos:

- **(i) PoT propio hasta `s + D`.** El campo de cabecera es `pot_output(B) = salida(f, slot(B)+D)` y la
  justificación encadena hasta ahí (`C-POT-05`, `SPEC.md:1403-1417`). Si la posición del timekeeper es
  `Φ`, hace falta `Φ ≥ s + D`.
- **(ii) flujo determinado hasta `s + D`.** Todas las inyecciones con `t_i ≤ s+D` deben tener su ancla
  cerrada; eso define el horizonte `Γ(t)`.

Con `Γ(t) = t + I + L − W_dec` (premisa 2 de `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`, con dos
respaldos históricos independientes), el honesto a `Φ_h(t) = t + D` y el atacante a `Φ_a(t) = D + ρt`:

```text
h(t) = mín( t , Γ − D )          a(t) = mín( ρ·t , Γ − D )
A(t) = a(t) − h(t) = mín(ρ·t, Γ−D) − mín(t, Γ−D)
```

Tres regímenes, y los tres importan:

| Régimen | Condición | `A` | ¿`D`? |
|---|---|---|---|
| flujo manda al honesto | `Γ − D < t` | `0` | los dos mueren igual |
| **flujo manda al atacante** | `t ≤ Γ − D < ρ·t` | **`Γ − D − t = L + I − W_dec − D`** | **resta** |
| reloj manda a los dos | `Γ − D ≥ ρ·t` | `(ρ−1)·t` | **se cancela** |

El umbral entre los dos últimos es `ρ_trans = (Γ−D)/t = 1 + (I+L−W_dec−D)/t`, que con `t = 10^6` vale
**1,008**. En el régimen que el modelo histórico describe —estacionario, `t` grande— **manda la fila
central: `D` resta**, y `A` es `ρ`-independiente.

### 2.2 Por qué `D` no suma, y en qué régimen resta o se cancela

- **No suma.** Sumaría si `reto(f,s)` se derivara de `pot_output = salida(f, s+D)`: entonces el
  atacante que va `D` por delante conocería el reto `D` slots antes. `C-POT-03`
  (`SPEC.md:1383-1386`) y `R-FIN-14(e)` lo prohíben expresamente. Se mide la región que produciría:
  `A_add = A_core + D` (columna de `resultados/BARRIDO-D.tsv`). **La prohibición vale exactamente `D`
  slots de adelanto.**
- **No se cancela.** `D` aparece **idéntico** en `h` y en `a` —es un hándicap común—, pero
  `mín(t+D, Γ) − D = mín(t, Γ−D)`: el honesto está limitado por **su reloj** (`h = t`, porque
  `Γ − D ≥ t` en el dominio viable) y el atacante por **el flujo** (`a = Γ − D`). El término `−D` solo
  muerde al que ya está limitado por el flujo. Y ese es el atacante.
- **La variante que cancelaría `D`** es suponer que el timekeeper honesto **no** va `D` por delante y
  que simplemente firma `D` slots tarde (`h = t − D`). Entonces `A = (ρ−1)t + D − D`. **Esa suposición
  contradice `C-POT-05`** —si el honesto no tuviera `salida(f, s+D)` no podría ni rellenar el campo—,
  pero se implementa como contrafactual (`A_sub`) para dejar la región a la vista.
- **La premisa que decide el signo** está aislada y etiquetada como tal en
  `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md` §6: *el timekeeper honesto avanza `D` por delante de su
  frontera de bloques*. **No está escrita en el SPEC ni medida en ZEROX.** Lo que cerraría la
  discusión es una línea de disciplina en `C-POT-05`/`C-TIMELORD-*`, o medir en
  `prototipos/pot-estable` que `slot(B) + D ≤ posición del timekeeper`. Si esa premisa fuera al revés,
  `D` se cancelaría y el resto de este informe no cambiaría **nada más**: la dependencia en `ρ`, el
  acantilado y la realimentación `F`↔`L` son independientes de ella.

### 2.3 Viabilidad: `D < L_slots`

El bloque del slot `s` necesita la inyección activa en `s + D`, cuyo ancla está en el slot
`≤ s + D − L`. Para que esté en el pasado validado de `B` hace falta `D ≤ L_slots`; con convergencia
del ancla, `D ≤ L_slots − W_dec`. **Si `D ≥ L_slots` ningún bloque puede avanzar**: no es un régimen
de seguridad distinto, es un diseño que no produce bloques. El instrumento lo marca con `vivo` en cada
fila y no calcula adelantos fuera del dominio.

**Respuesta a las tres preguntas del encargo §3:**

| Pregunta | Respuesta | Etiqueta |
|---|---|---|
| ¿`D` suma, resta, o depende? | **Resta** en el estacionario (`A = Γ−D−t`); **se cancela** en el transitorio (`A = (ρ−1)t`); **sumaría** solo si se levantara `C-POT-03`, que está prohibido | derivado, **condicionado** a las premisas 2 y 6; la aritmética verificada por instrumento (Sim-v1) |
| ¿Qué pasa con `I ≥ ρ_max·W_dec`? | **Sobrevive tal cual.** Sus entradas (`W_dec`, `ρ`) no contienen `D`; mide `n_eval`, no la ventana | derivado |
| ¿Cambia el punto de bifurcación? | El **compromiso** se corre con el conocimiento, pero la **grieta** entre ambos es `s(1−1/ρ)`, **sin `D`**. Lo único que cambia es *qué* se compromete | derivado |

### 2.4 Regresión contra SEM-v1 (`D = 0`), bit a bit

`adelanto_D(ρ,L,I,W_dec,D=0)` coincide con una **transcripción literal** del núcleo de SEM-v1 en las
88 filas de la rejilla, con `maxdiff = 0.0` exacto. Los siete valores publicados se reproducen:

| `ρ` | `L` | `A_core` reproducido | publicado por SEM-v1 | `w` = `floor(A)` |
|---:|---:|---:|---:|---:|
| 1 | 3 600 | 0 | 0 | 0 |
| 1,001 | 3 600 | 3 579,85 | 3 579,85 | 3 579 |
| 1,001 | 7 200 | 7 179,85 | 7 179,85 | 7 179 |
| 1,5 | 3 600 | 3 862,67 | 3 862,67 | 3 862 |
| 1,5 | 7 200 | 7 462,67 | 7 462,67 | 7 462 |
| 3 | 3 600 | 4 146,33 | 4 146,33 | 4 146 |
| 3 | 7 200 | 7 746,33 | 7 746,33 | 7 746 |

**`verificado por instrumento`, `alcance: la aritmética del núcleo de SEM-v1`.** El encargo §2(a) se
cumple: mi generalización contiene al histórico como el caso `D = 0`. **Y por eso mismo el encargo §9
obliga a decir cuál está mal si no reproduce SEM-v1: lo reproduce. Lo que se declara no es una
discrepancia de copia, es que `A_core` es un modelo de un objeto distinto del que dice medir** (§1).

---

## 3 · Fase 2 — la revelación retardada `(h)`, rehecha

### 3.1 Protección `ρ*` con `L` derivada por `C-FLU-01`

```text
A_con_h(ρ) = máx(0, (I + W_dec − 1) − (L + I)/ρ)      ρ > 1
ρ*         = (L + I)/(I + W_dec − 1)                  [convención −1 de A_core]
ρ*_cont    = (L + I)/(I + W_dec)                      [invierte (h.6) exactamente]
```

`ρ*` reproducido contra los valores publicados de la ronda 10a (`I = 851`, `W_dec = 20`):
`ρ* = 9,254` frente a **9,24** publicado; con `W_dec = 45`: `8,995` frente a **8,99**. Error < 0,15 %.
**Etiqueta: reproducido, no medido** (el VDF no se implementa).

**Lo que cambia de escala respecto del histórico.** Con `C-FLU-01`, `L_slots ≥ F_slots`. El histórico
trataba `L` como palanca libre y podía bajarlo para abaratar; ahora **no puede bajar de `F_slots`**:

| `F_slots` | origen | `L_slots` | `manda_F` | `I` | `ρ*_cont` | `coste_rel` | `q+1` líneas | **núcleos/nodo** |
|---:|---|---:|---|---:|---:|---:|---:|---:|
| 1 019 | `F_carrera` 33 %, δ=0 | 1 019 | sí | 851 | **2,147** | 2,197 | 3 | **0,211** |
| 1 249 | `F_carrera` 35 %, δ=0 | 1 249 | sí | 851 | **2,411** | 2,468 | 3 | **0,237** |
| 3 547 | `F_carrera` 33 %, δ D8 | 3 547 | sí | 851 | **5,049** | 5,168 | 6 | **0,497** |
| 7 200 | `F = 2 h` provisional | 7 200 | sí | 851 | **9,243** | 9,461 | 10 | **0,909** |
| 19 180 | `F = 5,3 h` medido | 19 180 | sí | 851 | **22,998** | 23,538 | 24 | **2,262** |

Dirección y tamaño del cambio: `ρ*` **sube** porque `L` ya no se puede bajar, y lo hace **linealmente
con `F`**. El coste sube con él **exactamente igual**: `ρ*_cont = coste_rel · I/(I+W_dec)`, esto es,
**el factor que las separa es `I/(I+W_dec)`, que vale 0,977 con `W_dec = 20` y `I = 851`**. El
histórico decía «protección y coste son el mismo número»; bajo `C-FLU-01` **siguen siéndolo, y además
ese número tiene suelo `1 + F_slots/I`**. Un nodo no puede pagar menos de
`0,0961 · (1 + F_slots/I)` núcleos por (h) sin bajar `F`.

### 3.2 Coste por nodo, como función

```text
líneas de AES del timekeeper  q + 1 = ⌈L/I⌉ + 1
núcleos continuos por nodo    c_v · (1 + L/I),   c_v = 0,0961 s/slot  [medido]
```

`c_v` es el `verify` medido en `research/dag-poas-ancla-de-orden.md:342`; la forma `1 + L/I` es la de
la ronda 10a (`research/scripts/d8-ronda10a/informe.md:745-755`). **`D` NO separa protección y coste**:
la justificación sigue llevando `d = slot(B) − slot(sp(B)) ≤ S_max` portadores
(`C-POT-05`, `SPEC.md:1412-1414`), y el desplazamiento `+D` no añade ni un portador. **Quien las
separa es `C-FLU-01`**, por dos vías: el factor `I/(I+W_dec)` (pequeño) y, sobre todo, **el suelo
`L ≥ F_slots`** (grande cuando `F` es de horas e `I` de cientos de segundos).

### 3.3 El vector C4 con `C-FLU-22` en la mano — **subsumido en especie, agravado en magnitud**

Enunciado a reevaluar: *«un lado de partición sin `q + 1` líneas de AES no produce bloques válidos
aunque conserve su espacio»*.

- **No es un fallo de consenso nuevo.** `C-FLU-22` **ya aceptó** que una partición más larga que `L`
  no tiene cura (la ventana es vacía desde el propio `t_j`, `SPEC.md:1825-1831`) y que el lado
  perdedor queda sin valor económico (`C-FLU-15`, `SPEC.md:1778-1794`). (h) no cambia la validez ni la
  adopción: la comprobación de flujo sigue siendo **estructural y previa a cualquier AES**
  (`C-FLU-14`, `SPEC.md:1724-1726`; `C-POT-08` paso 1b). **En especie, (h) queda subsumido.**
- **En magnitud, lo agrava, y de dos formas medibles.** (1) El suelo de hardware de un lado de
  partición pasa de «espacio» a «espacio **más `q + 1` líneas de AES**»; con `L = 7200`, `I = 851`,
  son **10 líneas** y **0,909 núcleos** por nodo que el lado perdedor necesita **incluso para
  verificar** al ganador durante la ventana de adopción de `C-FLU-22`. (2) **`C-FLU-22` exige verificar
  el PoT del flujo rival para adoptarlo** (`SPEC.md:1813-1815`) y **`PRESUP_NODO` no contempla ese
  término**: `TAREAS.md` §2.9(c) 12 lo dimensiona como `F_slots × 92 ms ≈ 11 min` de CPU, sin la
  revelación. (h) **añade una tercera mordaza a un presupuesto cuya cota superior el propio `TAREAS.md`
  declara no derivada.**
- **Conclusión.** (h) no reabre `C-FLU-22`; lo encarece y añade una partida sin derivar. **No es
  motivo para rechazar (h), es motivo para que `PRESUP_NODO` se derive con (h) dentro si (h) se
  adopta.** Etiqueta: **razonamiento sobre reglas escritas**, no simulación.

### 3.4 El suelo de `F`: la realimentación `F ↔ L ↔ ρ*` — **condicionada, no universal**

El 2026-09-08 se registró que (h) **no baja `F` por debajo de `F_carrera`** (`0,28 h` con δ=0;
`0,99 h` con el δ de D8; `research/scripts/d9-ronda10b/informe.md:47-48`). Bajo `1a` hay algo que el
modelo histórico no tenía: **`L ≥ F_slots`, y `ρ*` crece con `L`**. Se mide:

| `F_slots` | `L_suelo` | `L_slots` | `manda_F` | `ρ*_cont` | coste_rel | núcleos | líneas |
|---:|---:|---:|---|---:|---:|---:|---:|
| 1 019 | 0 | 1 019 | **sí** | 2,147 | 2,197 | 0,211 | 3 |
| 1 019 | 3 600 | 3 600 | no | 5,110 | 5,230 | 0,503 | 6 |
| 1 249 | 0 | 1 249 | **sí** | 2,411 | 2,468 | 0,237 | 3 |
| 1 800 | 0 | 1 800 | **sí** | 3,044 | 3,115 | 0,299 | 4 |
| 1 800 | 3 600 | 3 600 | no | 5,110 | 5,230 | 0,503 | 6 |
| 3 547 | 0 | 3 547 | **sí** | 5,049 | 5,168 | 0,497 | 6 |
| 7 200 | 0 | 7 200 | **sí** | 9,243 | 9,461 | 0,909 | 10 |
| 19 180 | 0 | 19 180 | **sí** | 22,998 | 23,538 | 2,262 | 24 |

**La realimentación es real y es exactamente esta: `ρ*(F) = (F + I)/(I + W_dec)` cuando
`L = F_slots`, y es CERO cuando manda `L_suelo_slots` o `S_max_slots+1`.** La condición, en palabras:
**manda el primer término de `C-FLU-01` si y solo si `F_slots > L_suelo_slots` y
`F_slots ≥ S_max_slots + 1`.** Con `L_suelo = 3600`, bajar `F` de 1 800 a 1 019 **no cambia `ρ*` en
absoluto** (5,110 en las dos filas).

**Consecuencia, y es la respuesta a §4.4.** (h) sigue comprando la bajada de `F` **solo si el suelo
`L_suelo_slots` se fija antes y por encima del `L` que la protección deseada exige** — que es
precisamente lo que `C-FLU-01` dice que es el suelo: responde a otra magnitud (la cola de desacuerdo
frente a `Δ`), no a `F`. Si `L_suelo_slots` se deja a `0` y `L` queda atada a `F`, entonces **bajar
`F` a `F_carrera` baja `ρ*` a ~2,15 y la protección de (h) se queda en la mitad de lo que el histórico
suponía gratis**. **`L_suelo_slots` deja de ser un detalle de redacción y pasa a ser la palanca que
decide si (h) sirve para acortar `F`.**

**Y (h.6) pone un techo a lo que `F` puede bajar.** `I* = (L − ρ_max·W_dec)/(ρ_max − 1)` con las
restricciones `I ≥ ρ_max·W_dec` (`R-FIN-14(f)`) y `I > S_max` (`C-FLU-09`):

| `ρ_max` | `F = 1 019` (`L = 1019`) | `F = 3 547` | `F = 7 200` |
|---:|---|---|---|
| 1,5 | `I* = 1 978` → admisible, 0,146 núcleos, 2 líneas | `I* = 7 068` → admisible | `I* = 14 340` → admisible |
| 2,5 | `I* = 646` → admisible, 0,248 núcleos, 3 líneas | `I* = 2 343` → admisible | `I* = 4 767` → admisible |
| 5 | `I* = 229,75` → admisible, 0,522 núcleos, 6 líneas | `I* = 866` → admisible | `I* = 1 775` → admisible |
| **9** | `I* = 104,875` → **NO admisible** (`I* < I_min_f = 180` y `< S_max+1 = 151`) | `I* = 423` → admisible | `I* = 877,5` → admisible |

**A `F = F_carrera` (0,28 h) el techo de `ρ_max` es `≈ 6,84`, y no lo pone `(h.6)` sino `I > S_max`.**
Con `L = 1 019`, `W_dec = 20`, `S_max = 150`, la condición `I* = (1 019 − 20·ρ_max)/(ρ_max − 1) > 151`
da `ρ_max < 6,842`; por encima, `I` tendría que ser menor que `S_max` y `C-FLU-09` lo prohíbe. `ρ_max = 9`
es **inadmisible** por esa razón.

**Pero el techo de `ρ_max` no es el techo de `A = 0`, y esa distinción es la que decide.** Con
`L = F_slots = 1 019` el umbral de cegado es `ρ* = (1 019 + 851)/(851 + 20) = 2,147`. Por encima de
`ρ = 2,147` **y hasta 6,84**, `(h)` se puede calibrar pero **ya no cega**: con `ρ_max = 2,5` deja
`A = 118` slots, y con `ρ_max = 5` deja `A = 492`. Es decir:

```text
F = F_carrera y L_suelo = 0   ⇒   o ρ_max ≤ 2,147 con A = 0, o ρ_max > 2,147 con A > 0. No las dos.
```

`2,147` está **dentro del techo físico estimado del reloj (1,5–2,5×)**. **Bajar `F` a `F_carrera` sin
fijar antes `L_suelo_slots` deja la protección de (h) en el borde del techo que existía para combatir.**
Con `L_suelo = 3 600`, `ρ* = 5,11` y la contradicción desaparece. **Es la respuesta completa a §4.4: la
realimentación no solo existe, decide si (h) sirve.**

---

## 4 · Fase 3 — las tres cotas, como funciones

### 4.1 `ρ_max` admisible, con y sin (h)

```text
sin (h):  A(ρ) = L + I − W_dec − D         para todo ρ > ρ_trans ≈ 1 + (L+I−W_dec−D)/t
          ⇒ NO existe ρ_max > 1 que anule A. Lo que se puede acotar es n_eval = ρ_max·W_dec ≤ I.
con (h):  A(ρ) = máx(0, (I + W_dec − 1) − (L + I)/ρ − D)
          ⇒ A = 0 exactamente para todo ρ ≤ ρ* = (L+I)/(I+W_dec−1)
```

Con `F = 7 200`, `I = 851`, `W_dec = 20`, `D = 4`: sin (h) `A = 8 027` slots para todo `ρ` realista;
con (h) `A = 0` hasta `ρ* = 9,25` y `A = 851 + 20 − 1 − 4 − 8 051/ρ` por encima. **Coste de cada
opción:** sin (h), 0,0961 núcleos/nodo (solo la cadena principal); con (h), `0,0961·(1+L/I)` núcleos
más `q+1` líneas — **0,909 núcleos y 10 líneas** con la calibración de 2 h.

**Sobre `ρ_max = 3` frente a (h).** El techo físico estimado del reloj AES es **1,5–2,5×**
(`research/pot-aes-asic-chacha.md:40-42`, **estimación**, con el estudio de Supranational sin
localizar). Con (h) y `ρ_max = 2,5`, `F = 7 200`, `W_dec = 45`: `I* = 4 725 s`, `q + 1 = 3` líneas,
**0,2425 núcleos continuos por nodo** (0,1464 de la ruta de revelación + 0,0961 de la cadena
principal). **Ese es el punto de operación que (h) hace posible y que `3×` sin (h) no alcanza**,
porque sin (h) `A` no baja de `L + I − W_dec − D` para ningún `ρ`.

### 4.2 Cota inferior de la edad `M` de un compromiso previo de parcela

`P-SEMBRADOR` (`investigacion/INFORME.md:130,144`) condiciona A1+C1 a `M > sup A` sobre la región de
`ρ` admitida. Con `sup` sobre `ρ ∈ [1, ρ_max]` y el margen de red/finalidad como símbolo aparte:

```text
sin (h):  M > L + I − W_dec − D + margen
con (h):  M > máx(0, (I + W_dec − 1) − (L + I)/ρ_max − D) + margen
```

| `F_slots` | `L` | `I` | `D` | `ρ_max` | `sup A` sin (h) | `sup A` con (h) |
|---:|---:|---:|---:|---:|---:|---:|
| 1 019 | 1 019 | 851 | 4 | 2,5 | **1 846** | 118 |
| 1 019 | 1 019 | 851 | 4 | 5 | **1 846** | 492 |
| 1 019 | 1 019 | 851 | 4 | 9 | **1 846** | (658) — **calibración inadmisible**: `I* = 104,9 < S_max+1` |
| 1 249 | 1 249 | 851 | 4 | 2,5 | **2 076** | 26 |
| 3 547 | 3 547 | 851 | 4 | 2,5 | **4 374** | 0 |
| 7 200 | 7 200 | 851 | 4 | 2,5 | **8 027** | 0 |
| 19 180 | 19 180 | 851 | 4 | 2,5 | **20 007** | 0 |

**Dos resultados que importan para `P-SEMBRADOR`:**

1. **Sin (h), `M` está dominada por `L`, y `L ≥ F_slots` por `C-FLU-01`: `M > ~F_slots`.** Con `F`
   provisional de 2 h, `M > 8 027` slots ≈ **2,23 h** más margen; con `F = 5,3 h`, **≈ 5,6 h**. La
   salida histórica «desatar `L` de `F`» **está cerrada** (`TAREAS.md` §2.9(b) 7 ya lo decía).
2. **Con (h) y `ρ_max ≤ ρ*`, `sup A = 0` y la edad exigida colapsa al margen.** Con `F = 2 h` y
   `ρ_max = 2,5`, `ρ* = 9,25 > 2,5`, luego `A = 0` en toda la región admitida y
   **`M > margen`**. Ese es el valor de (h) para A1+C1: **convierte una edad de horas en una edad de
   margen.** Es el mismo resultado que compra para `F` (§3.4), y se paga en núcleos.

**Qué habría que medir para fiarse.** (a) `ρ_max` real por plataforma (el techo 1,5–2,5× es
estimación); (b) la premisa 6 de `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md` —disciplina del timekeeper
honesto— que decide si `D` resta o se cancela; (c) el coste medido por intento dirigido del sembrador,
que `P-SEMBRADOR` sigue declarando no determinado; (d) `W_dec` en red real (`≤ 45 s` es máximo
observado, no cota universal).

### 4.3 Cota inferior del tiempo de sellado secuencial adversarial

Candidata B de `P-SEMBRADOR` (`investigacion/INFORME.md:154-164`). El candidato elegido tras conocer
el reto no llega a tiempo si `T_seal,adv > sup A`. Con las mismas fórmulas:

```text
T_seal,adv > L + I − W_dec − D + margen        (sin h)
T_seal,adv > máx(0, (I + W_dec − 1) − (L + I)/ρ_max − D) + margen   (con h)
```

| `F_slots` | `T_seal,adv` mínimo sin (h) | en horas (τ = 1 s) | ¿compatible con granja doméstica? |
|---:|---:|---:|---|
| 1 019 | 1 846 slots | **0,51 h** | **sí**, con holgura |
| 1 249 | 2 076 slots | 0,58 h | sí |
| 3 547 | 4 374 slots | 1,22 h | discutible |
| 7 200 | 8 027 slots | **2,23 h** | **no**: el honesto paga lo mismo por sector |
| 19 180 | 20 007 slots | 5,56 h | no |

**Veredicto.** Un sellado secuencial **solo sirve si `F` es corta**. Con `F = F_carrera` (0,28 h) basta
un sellado adversarial de **> 0,51 h por sector**, que una granja doméstica puede permitirse como
coste de alta única. Con `F = 2 h` haría falta **> 2,23 h por sector**, y como el honesto paga el mismo
tiempo por sector, **la candidata se cae sola**, tal y como el encargo §0.3 anticipaba. Con (h)
adoptada, `sup A = 0` y **el sellado secuencial deja de ser necesario** para este vector.

---

## 5 · Representación, rendimiento y veracidad numérica

**Estructura de datos.** Una fila es un `struct` inmutable e `isbits` (`ParametrosAdelanto{Float64}`)
con 10 campos; el kernel consume **todos** los campos a la vez, así que `AoS` es lo correcto —no hay
un campo que se recorra sobre millones de filas—. La salida del barrido es un `Vector{ResultadoAdelanto{T}}`
más una vista `SoA` plana (`Matrix{Float64}` preasignada). No se usan `Dict`, `Set`, `Any`, `Union`,
ni arrays de tamaño fijo pequeño: la operación dominante es evaluar ~12 funciones escalares por fila, y
por eso `StaticArrays`, `StructArrays` o CSR **no** se justifican (LINEO §4).

**Sin cancelación catastrófica.** `A_frontera` se evalúa por ramas
(`(ρ−1)t` / `Γ−D−t` / `0`) en lugar de como diferencia de dos números casi iguales: con `t = 10^6` y
`A ≈ 8·10^3`, la forma ingenua perdía 3 dígitos. El test §8 lo comprueba contra `BigFloat` de 256 bits.

**Tabla de rendimiento** (Julia 1.13.0, CPU `znver5`, `OPENBLAS_NUM_THREADS=1`; `resultados/BENCH-h*.txt`):

| Variante | Tiempo mediano | Asignaciones | Hilos | Resultado frente a referencia |
|---|---:|---:|---|---|
| `evaluar_fila` (una fila) | 4,65 ns | 0 | 1 | referencia del kernel |
| `barrer!` serial, 100 000 filas | **0,9127 ms** (9,13 ns/fila) | **0** (`@allocated` = 0 bytes) | 1 | `==` con BigFloat (tol 64 eps) |
| `barrer_hilos!`, 100 000 filas | véase tabla de escalado | 7–42 allocs (una vez) | 1–8 | **idéntico** al serial |
| `referencia_bigfloat` (256 bits) | 2,358 µs | 91 allocs | 1 | oráculo |
| `simular_fronteras` (400 épocas) | 0,307 µs | 3 allocs | 1 | oráculo independiente |

**Escalado** (el barrido es aritmética escalar pura, sin memoria compartida; se conserva la
configuración que gana, aunque sea menos de 8 hilos):

| Hilos | `barrer_hilos!` mediana | serial de la misma corrida | speedup | eficiencia |
|---:|---:|---:|---:|---:|
| 1 | 0,9020 ms | 0,9127 ms | 1,00× | 100,0 % |
| 2 | 0,4877 ms | 0,9156 ms | 1,88× | 93,9 % |
| 4 | 0,2669 ms | 0,9145 ms | 3,43× | 85,7 % |
| **8** | **0,1593 ms** | 0,9169 ms | **5,76×** | **71,9 %** |

**Gana 8 hilos en tiempo absoluto** (5,76× sobre el serial), y es la configuración que se conserva. La
eficiencia cae al 71,9 % porque el trabajo por fila es de nanosegundos y el barrido completo dura menos
de un milisegundo: el coste de arranque de las tareas pesa. Para el tamaño real de este encargo —una
rejilla de decenas de filas— **la configuración correcta es 1 hilo**: paralelizar un barrido de
segundos solo añade sobrecarga. Se publican las dos cosas.

**Validación** (`resultados/VALIDACION.txt`, 100 asserts en `test/runtests.jl`, todos en verde):

| Comprobación | Resultado |
|---|---|
| Regresión contra SEM-v1, `D = 0` | `maxdiff = 0,0` exacto; tabla publicada con error ≤ 0,0034; `w` idéntico |
| Kernel contra `BigFloat` 256 bits (1 134 filas) | peor error relativo `1,27·10⁻¹⁴` ≤ `64 eps`; 0 violaciones |
| `A_frontera` contra **Sim-v1** | diferencia máxima **1,0 slot** = la convención discreta, constante |
| Invariantes (continuidad en `ρ=1`, monotonías, `A_con_h(ρ*) = 0`, `C-FLU-01` en los tres regímenes) | 0 fallos |
| Umbrales discretos `Float64` vs `Rational{BigInt}` (576 filas) | 0 discrepancias; error en `ρ*` = 0 |
| `@code_warntype` / JET sobre `evaluar_fila` y `barrer!` | sin `Any`; `report_call`/`report_opt` con 0 errores |
| Barrido con hilos vs serial | idéntico |

**Sim-v1 es un oráculo genuinamente independiente**: no evalúa ninguna forma cerrada; construye la
lista de épocas, deriva `Γ(t)` de esa lista (`Γ = t_{i*+1} − 1`) y calcula las fronteras con las dos
restricciones. Reproduce la forma cerrada salvo **exactamente un slot**, que es la misma convención
discreta que el `−1` de `A_core`.

**Comando reproducible** (la máquina de este encargo tiene el depósito de Julia en solo lectura, así
que se redirige la caché de compilación a `/tmp`; el proyecto y el `Manifest.toml` son los que fijan
el árbol):

```bash
cd /home/katana/zeo/ZEROX/P-ZRX/P-ADELANTO/investigacion/veritas/seguridad/adelanto-v1
JULIA_DEPOT_PATH="/tmp/dsh-julia-depot:$HOME/.julia" \
JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 \
  /home/katana/torio/.juliaup/bin/julia --project=. --threads=1,0 run.jl --modo todo
# pruebas
JULIA_DEPOT_PATH="/tmp/dsh-julia-depot:$HOME/.julia" \
  /home/katana/torio/.juliaup/bin/julia --project=. --threads=1,0 test/runtests.jl
# mediciones y diagnósticos
for n in 1 2 4 8; do
  JULIA_DEPOT_PATH="/tmp/dsh-julia-depot:$HOME/.julia" JULIA_NUM_THREADS=$n \
  OPENBLAS_NUM_THREADS=1 /home/katana/torio/.juliaup/bin/julia --project=. --threads=$n,0 bench/benchmarks.jl
done
```

Argumentos completos y semilla en `resultados/ENTORNO.txt`. **No hay semilla**: el instrumento es
determinista; Sim-v1 usa una rejilla fija de offsets, no RNG.

---

## 6 · Presupuesto y entrega

- **Tiempo:** barrido completo `--modo todo` en segundos; `bench/` con 100 000 filas y cuatro
  configuraciones de hilos, minutos. **No se agotó el presupuesto.**
- **Memoria:** la rejilla mayor (`FASE3.tsv`, 2 059 líneas) es O(n) con `n ≈ 2·10³` filas; el bench usa
  100 000 filas × 2 vectores ≈ 30 MiB. Muy por debajo de 4 GiB.
- **Disco:** `resultados/` = **336 KiB**; el directorio entregado completo
  (`P-ZRX/P-ADELANTO/`) = **564 KiB**. Muy por debajo de 1 GiB.
- **Estado:** **conclusivo** dentro del alcance declarado; las premisas que no están cerradas se
  enumeran en §7 y en `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`.

---

## 7 · Lo que esta investigación NO resuelve

1. **La disciplina de avance del timekeeper honesto** (premisa 6). Decide si `D` resta o se cancela.
   Ni el SPEC la escribe ni hay medición en ZEROX. **Es la única pieza que puede cambiar el signo del
   resultado principal**, y está aislada a propósito.
2. **`ρ` real por plataforma.** El techo 1,5–2,5× sigue siendo **estimación**
   (`research/pot-aes-asic-chacha.md:40-42`); el estudio de Supranational que Autonomys cita **no está
   localizado**. Toda la Fase 3 depende de `ρ_max` como símbolo.
3. **`W_dec` en red real.** `≤ 45 s` es máximo observado, no cota universal
   (`research/dag-poas-ancla-de-orden.md:290-291`).
4. **`L_suelo_slots`, `I_slots`, `F`, `D`, `S_max` y `ρ_max` siguen sin fijar.** No los he fijado: el
   encargo lo prohíbe y ningún resultado numérico de este informe es una constante escrita a mano;
   todas salen de una función y cambian al barrer.
5. **La forma `A_con_h` no está medida.** Es la forma cerrada publicada por la ronda 10a; el VDF de la
   revelación no se implementa aquí, así que no hay verificación independiente de (h) más allá de
   reproducir sus `ρ*`.
6. **No se modela** `π_DAG`, propagación, retarget durante el ataque, competencia entre soluciones del
   mismo slot, orfandad, ni el bootstrap completo con `L ≥ I`.
7. **El bootstrap no está medido.** Para `ρ` apenas mayor que 1, alcanzar el régimen estacionario
   puede tardar días (`research/scripts/d9-ronda9c/informe.md:264-272`). El instrumento declara
   `ρ_trans` y no lo cobra.
8. **`C-FLU-22` con (h) dentro no está re-simulado.** §3.3 es razonamiento sobre reglas escritas; no
   cuantifica la tercera mordaza de `PRESUP_NODO`.
9. **El coste medido del intento dirigido del sembrador** sigue sin existir; esta investigación
   entrega la cota temporal (`sup A`) que ese modelo necesita, no la económica.
10. **No se decide ninguna de las tres herramientas.** `ρ_max`, `M` y el tiempo de sellado van como
    funciones y regiones; la elección es de Katana y está en `DECISIONES-PENDIENTES.md`.
