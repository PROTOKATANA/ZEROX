# PROGRESO — P-PRESTAMO · el espacio honesto prestado a una rama privada

**Zona de escritura:** solo `P-ZRX/P-PRESTAMO/investigacion/`. No se editó ni movió nada de
`SPEC.md`, `TAREAS.md`, `ci/`, `crates/`, `prototipos/`, `research/`, `veritas/` ni del resto de
`P-ZRX/`. `PROMPT.md`, `CANDIDATA.md` y `ENTRADA.sha256` se leyeron, no se tocaron.

**Entorno:** Julia 1.13.0 (CPU, `veritas/julia.sh`), nativa sin Python; AMD Ryzen 9 9950X3D
(16 núcleos / 32 hilos lógicos), 123 GiB de RAM.

---

## 0 · Objeciones declaradas ANTES de empezar (PROMPT §7, ADENDA-1 §E)

El encargo pide decir antes de empezar si algo del modelo del §2 o de la pérdida del granjero
parece equivocado. Esto es lo que se detectó al leer `PROMPT.md`, `ADENDA-1.md`, `CANDIDATA.md`,
`BASELINE.md`, `DEFECTOS.md`, `CIFRAS.md`, `PROPOSICIONES.md`, `DECISIONES-PENDIENTES.md` y
`P-PERMANENCIA/investigacion/INFORME.md` enteros.

**O1 · [RETIRADA] La objeción sobre `BASELINE.md` escenario 0 era FALSA.** Este fichero declaró
que `BASELINE.md:18` tenía «la razón invertida». **No la tiene: el error era de lectura.** En el
encargo original y en `BASELINE.md`, **`p` es la tasa del HONESTO y `q` la del ADVERSARIO**, así
que `q < p` es «adversario en minoría» y `(q/p)^(d+1) < 1` es lo correcto. Este trabajo venía
usando `p` para la tasa del **adversario** sin advertirlo. La corrección que se propuso
(`(p/q)^(d+1)` con el adversario por delante) **daba valores mayores que 1** — con `p = 3/5`,
`q = 2/5`, `d = 6` daba `17,09` — y **no se aplicó a `BASELINE.md`, que no se toca**.

**Qué se comprobó al respecto (para que la revisión no tenga que repetirlo):**

1. **El error quedó en el texto, no en las transiciones.** El kernel implementa el déficit
   `Z = (trabajo público) − (trabajo privado)`: baja con la probabilidad del **adversario**
   (primer argumento de `primera_dp`, llamado `p` allí) y sube con la del honesto. Reescribiendo la
   convención de `BASELINE.md` (adversario = `q`), `primera_dp(q, d, T)` reproduce su fórmula
   `(q/p)^(d+1)` en las cinco comprobaciones:

   | `p` honesto | `q` adversario | `d` | DP `T=400` | `(q/p)^(d+1)` |
   |---:|---:|---:|---:|---:|
   | 2/3 | 1/3 | 5 | 0,015625 | 0,015625 |
   | 3/5 | 2/5 | 2 | 0,29629533 | 0,29629630 |
   | 2/3 | 1/3 | 0 | 0,5 | 0,5 |
   | 4/5 | 1/5 | 6 | 6,104·10⁻⁵ | 6,104·10⁻⁵ |

2. **Ninguna tabla publicada cambia.** F2 llama a `primera_dp` con `p_de_alpha(...)`, que ya
   devolvía la tasa del **adversario**; F1 no usa el paseo; F3–F6 son economía. Los ficheros de
   `resultados/` **no se regeneraron** porque no dependían del error.

3. **Sí apareció un defecto real de notación en el código**: `p_superar_exacto` había quedado
   tomando la tasa del **honesto** (como `BASELINE.md`) mientras el módulo declaraba que su primer
   argumento era la del adversario. Eso no afectaba a ninguna cifra publicada (la función sólo se
   usaba en asertos de test), pero era una trampa. **Corregido:** la firma toma ahora la tasa del
   adversario `q`, deriva `p = 1 − q` dentro, y la convención está escrita en la cabecera de
   `src/referencia.jl` y `src/rapido.jl`. Se añadió la reconciliación con `BASELINE.md` a los
   tests (4 celdas exactas).

**Lección de método, y es la que importa:** una convención de nombres no declarada produjo una
acusación falsa contra un documento correcto. La regla que se adopta aquí: **cada función que
reciba una tasa declara en su firma si es la del honesto o la del adversario**, y ninguna
conclusión se apoya en una cita leída sin su notación.

**O2 · El `β_d` del modelo del §2 no es un símbolo libre: tiene una restricción de conservación
que el encargo no menciona.** El §2 pide barrer `β_d` como variable independiente. Pero si la
identidad de billete hace que cada oportunidad ganadora sea **una sola** (`IDV-01`,
`CANDIDATA.md` §3), el granjero que farmea doble **duplica necesariamente la misma oportunidad**,
y usar la misma solución en las dos ramas **es exactamente la infracción estrecha** que
`CANDIDATA.md` §5 castiga: repartir el espacio, no duplicarlo. Bajo esa identidad, `β_d` **no
aporta peso privado neto** y la frontera de deriva vuelve a `α* = 1/2`. Bajo `C-GD-07` vigente
(que incluye `chunk`) sí hay oportunidades distintas y `β_d` vuelve a ser libre. El informe trata
los dos regímenes por separado y **no** mezcla la conclusión de uno con las cifras del otro.

**O3 · La pérdida del §2 no incluye el coste de la censura del lado del atacante.** El prompt
incluye `q_inclusión` como un factor que reduce la pérdida del granjero (`b > κ·q·pérdida`), pero
la censura **también** le cuesta al atacante: si la evidencia no entra cuando gana, el castigo no
se ejecuta y el atacante no paga, pero el mecanismo tampoco disuade. La distinción
`q_gana` / `q_pierde` del §2.4 se conserva y se barre, pero se hace notar que con `q_pierde = 0`
**ninguna** `(ρ_ret, T_v)` disuade a un atacante que solo publique la rama ganadora.

**O4 · `c_r` y `M` tienen medición histórica y hay que etiquetarla.** `research/coste-ploteo-medido.md`
es evidencia histórica (`AGENTS.md`: «nunca cifras heredables»), y `P-PERMANENCIA` declara que
el coste del tramposo es **independiente del tamaño del lote**. Se usa `c_r` como **símbolo
barrido**, no como constante, y la maduración `M` como símbolo.

**O5 · El puente espacio → tasa no existe (ADENDA-1 §A, `DEFECTOS.md` C1).** Todo resultado de
ventana de este trabajo está **condicionado a H-PUENTE**: `μ_a/μ_p = (α+β_d+β_x)·η_a /
((1−α−β_x)·η_h)`. Se declara en la primera página y en cada tabla de F2, como exige la adenda.

**O6 · [DEFECTO PROPIO, CORREGIDO] La «cota exacta» del barrido F2 no era una cota.**

La primera versión de `run.jl` etiquetaba las celdas de F2 con `(1−p_adv)^F` y las descartaba
cuando esa cantidad quedaba por debajo de `10^-30`, publicándola además como el valor de la celda.
**El razonamiento era falso:** «hacen falta todos los pasos del adversario» sólo vale si el déficit
inicial iguala al horizonte, y no lo iguala — el adversario necesita `d+1` pasos, no `F`.

Consecuencia, medida en la celda que el propio informe cita (`F=1.019`, `α=0,33`, `β_d=0`):

| cantidad | valor |
|---|---|
| `(1−p_adv)^F` publicada como «cota» | `10^-177,23` |
| **DP exacta `P_first_passage`** | **`9,752·10^-108` = `10^-107,01`** |
| ruina eventual `(q/p)^(d+1)` | `10^-106,72` |

**No es una cota floja: es una cota inválida.** `10^-177 < 9,75·10^-108`, así que **no acota**; se
equivoca en 70 órdenes de magnitud. El defecto lo encontró el validador, no el instrumento.

**Qué se cambió.** (1) `run.jl` calcula la **DP exacta en todas las celdas** y publica
`P_primera`, `log10(P_primera)` y una etiqueta por celda: `exacto` (DP dentro de rango),
`limite_ruina` (la DP subdesborda `Float64`, el valor real es `< 10^-308`, y se publica el
**límite exacto** `(q/(1−q))^(d+1)` —cota superior de `P_first_passage`— en vez de un cero falso)
o `recurrente` (`q ≥ 1/2`, el adversario no es minoría y el límite es 1). `P = 0` **exacto** sólo
se publica como 0 cuando la DP lo devuelve con masa interior distinta de 1, y eso no ocurre en
ninguna celda de la rejilla publicada. (2) Se añadió a `primera_dp` una **poda
exacta**: el mínimo de los prefijos nunca supera la posición actual, así que `m > z` es
inalcanzable y se salta; no cambia ningún resultado (los 125 controles siguen en verde, 60 de
ellos contra la enumeración exhaustiva en el mismo testset). (3) El fichero
`resultados/F2-ventana.tsv` se regeneró y la tabla del informe §2.3 se sustituyó.

**Qué NO cambia.** La conclusión de F2: el valor correcto (`10^-107`) sigue estando **muy por
debajo de `10^-30`**, el umbral declarado para «despreciable». Ninguna otra tabla (F1, F3–F6)
usaba esa cantidad. La cota `(1−p_adv)^F` **sí es válida como desigualdad** (cada paso tiene
probabilidad `1−p_adv` como mínimo, y hacen falta `F` pasos favorables encadenados), pero **no se
usó para nada** en la versión publicada y se retira de las tablas para no confundirla con el valor.

**Lección de método:** una cota sólo se publica al lado del valor que acota, con la etiqueta
`cota`, y nunca en la columna del valor. Un número que «suena a probabilidad» pero es una
desigualdad floja es peor que no publicar nada.

**Ninguna de las cinco objeciones impide ejecutar el encargo.** El modelo del §2 se implementa tal
cual (superficie de deriva, tres eventos, juego), añadiendo O2 como escenario separado.

---

## 1 · Presupuesto declarado antes de ejecutar (LINEO §7, PROMPT bloque §8.11)

| Recurso | Presupuesto | Uso real |
|---|---|---|
| Hilos | **8** (tope del encargo; tope conjunto de la máquina: 24) | 8 |
| RAM | 8 GiB | < 1 GiB (la DP es un vector de `Float64` de tamaño `(d+1)·(d+T)`; el mayor caso de F2 fue `1019×1319 ≈ 1,3 M` celdas ≈ 10 MB) |
| Disco | 256 MiB | < 2 MiB (`resultados/*.tsv`) |
| Tiempo de pared | minutos por tarea; **se declara inconcluso** si una corrida lo supera | F2 con `F = 7.200` se acota por coste (véase §4) |

**No se agotó el presupuesto.** Cada celda de la DP es `O(F·(d+F))` con `d ≈ 0,34·F` en la
configuración adversa: `F = 1.019` tarda 0,5 s y `F = 3.547` con `d = 1.200` tarda 26,6 s
(medido). Por eso el barrido publicado reduce `F` y declara la rejilla completa como
**inconclusa por coste**, con la entrada mínima reproducible en `correr-f2.sh`.

---

## 2 · Comprobaciones de ENTRADA

Ejecutadas desde la raíz `/home/katana/zeo/ZEROX` al empezar:

```bash
$ LC_ALL=C sha256sum -c P-ZRX/P-PRESTAMO/ENTRADA.sha256
P-ZRX/P-PRESTAMO/PROMPT.md: OK
P-ZRX/P-PRESTAMO/CANDIDATA.md: OK
P-ZRX/P-PRESTAMO/ADENDA-1.md: OK
$ cd P-ZRX/P-PRESTAMO && LC_ALL=C sha256sum -c ADENDAS.sha256
ADENDA-1.md: OK
$ git -C /home/katana/zeo/ZEROX status --short
 D ZEROX-EN-NUMEROS.md
?? .trash/
?? P-ZRX/
?? veritas/consenso/poda-post-v1/
?? veritas/consenso/prueba-recursiva-v1/
?? veritas/seguridad/
$ date
lun 21 sep 2026 20:45:52 CEST
$ uptime
 20:45:52  up 13 days 17:15,  0 users,  carga promedio: 0,79, 0,94, 0,98
```

**Lectura de la carga:** `0,79` con 8 hilos declarados ⇒ «medido con carga ajena» **no aplica**
al arranque (la carga es inferior al presupuesto). Se anota `uptime` antes de cada benchmark en
`resultados/BENCH.txt`.

**Nota sobre `ADENDAS.sha256`:** el fichero lista `ADENDA-1.md` con ruta **relativa**, así que su
comprobación sólo funciona desde `P-ZRX/P-PRESTAMO/`. No es un defecto del encargo: es cómo está
escrito el fichero, y se documenta para que el validador no lo lea como fallo.

---

## 3 · Bitácora de construcción del instrumento

Instrumento en `investigacion/veritas/seguridad/espacio-prestado-v1/` (categoría `seguridad`;
secundarias `consenso` y `economía`), a partir de `veritas/plantilla/`, con
`JULIA_DEPOT_PATH` propio (`investigacion/.julia-depot`) para no compartir entorno.

**Defectos propios detectados y corregidos durante la validación** (cada uno queda como vector de
regresión en `test/runtests.jl` y en la cabecera de `src/referencia.jl`):

| # | Defecto | Cómo se detectó | Corrección |
|---|---|---|---|
| D1 | Una DP con `−1` **absorbente** calcula `P(Z_T = −1)`, no la primera pasada (el paseo revisita `−1`) | El valor no cuadraba con la enumeración en `p=2/5, d=3, T=5` | Se abandonó ese camino; la primera pasada se calcula con la DP sobre el estado `(mínimo, posición)` |
| D2 | Escribir en `v` mientras se lee `v` cuenta dos veces las transiciones | Residuo de conservación distinto de 0 | Doble buffer `v`/`vn` con intercambio al final |
| D3 | Truncar la cuadrícula en `d+T` pierde masa que sube | Residuo `−40/27` con `p=1/3, d=0, T=5` | Cota explícita `H = d+T+2` y residuo comprobado en cada llamada |
| D4 | El **enumerador** cortaba la recursión al tocar `−1` y contaba de más | `p=1/3, d=0, T=3` daba `5/9` frente a `11/27` (calculado a mano) | Bandera `tocado`: la primera visita se cuenta una vez y la trayectoria sigue |
| D5 | El mínimo del estado DP arrancaba en `Z_0` en vez de «aún desconocido» | `p=1/2, d=0, T=15` daba `>1` | El mínimo arranca en `d` y sólo baja; el estado `−1` absorbe |
| D6 | Una fórmula de reflexión publicada con el tope de suma mal puesto | Discrepancia con la enumeración en `p=1/3, d=2, T=3` | Se **retiró**: la primera pasada se calcula por DP, verificada en 714 celdas contra la enumeración |
| D7 | `Random123.Philox4x64` no existe (el paquete exporta `Philox4x`) | `UndefVarError` con la receta literal de `DEFECTOS.md` A2 | `Philox4x((semilla, semilla ⊻ φ), …)` + `set_counter!(r, (0,0,0,id))` |

**Estado de la validación:** 125 controles en `test/runtests.jl` con `--check-bounds=yes`,
**todos en verde**. La primera pasada de la DP coincide con la enumeración exhaustiva en 714
celdas exactas (`Rational{BigInt}`) y con `(q/p)^(d+1)` en horizonte largo; el `Float64` coincide
con el exacto a `< 1e-12` relativo; el Monte Carlo contracorriente cae dentro del IC de Wilson.

---

## 4 · Lo que quedó inconcluso por coste, y su entrada mínima

- **F2 con `F = 7.200` y `α = 0,40`**: una sola celda con `d ≈ 0,34·7200 ≈ 2.450` cuesta del orden
  de minutos (la celda `d=1.200, T=3.547` tarda 26,6 s), y la rejilla completa excede el
  presupuesto de minutos del encargo. **No se publica como frontera**: se publica como rejilla
  reducida y la rejilla completa queda **inconcluso**, con `correr-f2.sh` como entrada mínima
  reproducible.
- **`F` no está fijada en el SPEC** (es símbolo): todos los valores usados son **de ejemplo**,
  como manda el PROMPT §3 F2.

---

## 5 · Comprobaciones de SALIDA

Ejecutadas desde la raíz `/home/katana/zeo/ZEROX` al terminar:

```bash
$ LC_ALL=C sha256sum -c P-ZRX/P-PRESTAMO/ENTRADA.sha256
P-ZRX/P-PRESTAMO/PROMPT.md: OK
P-ZRX/P-PRESTAMO/CANDIDATA.md: OK
P-ZRX/P-PRESTAMO/ADENDA-1.md: OK
$ cd P-ZRX/P-PRESTAMO && LC_ALL=C sha256sum -c ADENDAS.sha256
ADENDA-1.md: OK
$ git -C /home/katana/zeo/ZEROX status --short
 D ZEROX-EN-NUMEROS.md
?? .trash/
?? P-ZRX/
?? veritas/consenso/poda-post-v1/
?? veritas/consenso/prueba-recursiva-v1/
?? veritas/seguridad/
$ date
lun 21 sep 2026 21:02:45 CEST
$ uptime
 21:02:45  up 13 days 17:32,  0 users,  carga promedio: 0,42, 0,97, 1,07
```

**Las tres comprobaciones de entrada son idénticas a las de salida:** los ficheros de solo lectura
no se tocaron (`sha256sum -c` exit 0) y el árbol de trabajo de git no cambió respecto del inicio
(las mismas cinco líneas: `ZEROX-EN-NUMEROS.md` borrado y cuatro directorios sin seguimiento,
todos **ajenos a este encargo**). Todo lo escrito vive bajo
`P-ZRX/P-PRESTAMO/investigacion/`.

**Estado de la validación al cerrar:** 125/125 controles en verde con `--check-bounds=yes`
(perfil de referencia, 1 hilo).

## 6 · Cierre

**Entregado** (todo bajo `P-ZRX/P-PRESTAMO/investigacion/`):

| ruta | qué es |
|---|---|
| `INFORME.md` | el informe; su primera línea es la respuesta |
| `DECISIONES-PENDIENTES.md` | las 10 bifurcaciones para Katana (D1–D10) |
| `PROGRESO.md` | este fichero |
| `veritas/seguridad/espacio-prestado-v1/INFORME.md` | informe del instrumento |
| `…/HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md` | 8 hipótesis falsables |
| `…/src/`, `…/test/`, `…/bench/`, `…/run.jl`, `…/correr-f2.sh` | instrumento |
| `…/resultados/*.tsv`, `…/resultados/BENCH.txt` | artefactos |

**Las tres respuestas del encargo, en corto:**

1. **Cuánto baja el umbral con espacio prestado:** exactamente
   `α* = (1 − β_d − 2β_x)/2` con `η=1`; cada unidad de alquiler exclusivo vale el doble que cada
   unidad de doble farmeo. Pero **dentro de `F` el umbral no se alcanza**: donde el adversario no
   gana la deriva, `P` decrece con `F` y el mínimo medido es `8,53·10^-277`
   (`F=3.600, α=0,20, β_d=0,34`); con `F=1.019, α=0,33, β_d=0` es `9,75·10^-108`.
2. **Si el consenso base aguanta el doble farmeo barato:** **la ventana sí; el umbral no.** Sin
   castigo, `β_d` es gratis y `α*` cae a `α/2`; el castigo es **imprescindible** en el régimen
   `C-GD-07`. En el régimen con identidad de pieza (`IDV-01`/`CANDIDATA`), el doble uso de una
   oportunidad **deja evidencia** y `β_d` no aporta peso neto: el umbral vuelve a `1/2` sin
   depender del castigo.
3. **Cuánta recompensa retener y por cuánto tiempo:** la región `κ·q·(ρ_ret·ingreso·T_v +
   c_r + ingreso·M) > V/N` **y** `T_v > F + margen`. Con `V/N = 400`, `c_r + ingreso·M = 30` y
   `κ·q = 1`: `ρ_ret = 0,10` exige `T_v > 3.700` (y el requisito temporal `T_v > F` manda desde
   `F ≈ 3.700`). Frente a **`κ = 0`** (sólo publicar la rama ganadora), **censura total** o **`V`
   sin cota**, **no hay `(ρ_ret, T_v)` que valga**.

**Longitud del encargo.** El modelo del §2 se implementó completo; el único punto donde no se
pudo llegar a la rejilla completa es F2 con `F = 7.200` y `α` alto (minutos por celda), declarado
**inconcluso por coste** en §4 con su entrada mínima reproducible.
