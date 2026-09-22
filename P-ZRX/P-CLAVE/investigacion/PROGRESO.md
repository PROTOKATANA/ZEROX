# PROGRESO — P-CLAVE · retención-clave-v1

Bitácora del encargo `P-ZRX/P-CLAVE/PROMPT.md`. Rutas completas desde `/home/katana/zeo/ZEROX`.
Etiquetas: `demostrado`, `verificado en fuente`, `medido`, `derivado`, `estimado`, `propuesto`,
`no determinado`.

---

## 0 · Huellas de entrada y salida

### 0.1 · Al empezar (2026-09-22)

```text
$ LC_ALL=C sha256sum -c P-ZRX/P-CLAVE/ENTRADA.sha256
P-ZRX/P-CLAVE/PROMPT.md: OK
P-ZRX/P-CLAVE/CANDIDATA.md: OK
```

```text
$ git -C /home/katana/zeo/ZEROX status --short
 D ZEROX-EN-NUMEROS.md
?? .trash/
?? P-ZRX/
?? veritas/consenso/poda-post-v1/
?? veritas/consenso/prueba-recursiva-v1/
?? veritas/seguridad/
```

```text
$ date
mar 22 sep 2026 17:14:18 CEST
```

```text
$ uptime
17:14:18  up 14 days 13:43,  0 users,  carga promedio: 1,71, 1,26, 1,15
```

### 0.2 · Al terminar (2026-09-22)

```text
$ LC_ALL=C sha256sum -c P-ZRX/P-CLAVE/ENTRADA.sha256
P-ZRX/P-CLAVE/PROMPT.md: OK
P-ZRX/P-CLAVE/CANDIDATA.md: OK
```

```text
$ git -C /home/katana/zeo/ZEROX status --short
 D ZEROX-EN-NUMEROS.md
?? .trash/
?? P-ZRX/
?? veritas/consenso/poda-post-v1/
?? veritas/consenso/prueba-recursiva-v1/
?? veritas/seguridad/
```

```text
$ date
mar 22 sep 2026 20:22:57 CEST
```

```text
$ uptime
20:22:57  up 14 days 16:52,  0 usuarios,  carga promedio: 2,20, 2,19, 2,60
```

**Las tres comprobaciones son idénticas a las de entrada** (los dos ficheros de `P-CLAVE/` siguen
intactos y `git status` no gana ninguna ruta nueva fuera de `P-ZRX/`, que ya estaba sin seguimiento).

**Zona de escritura respetada.** Sólo se escribió bajo `P-ZRX/P-CLAVE/investigacion/`. `PROMPT.md`,
`CANDIDATA.md` y `ENTRADA.sha256` no se tocaron (el `sha256sum -c` final lo comprueba). No se tocó
`SPEC.md`, `TAREAS.md`, `ci/`, `crates/`, `prototipos/`, `research/`, `veritas/`, `PDF/` ni el resto
de `P-ZRX/`. No se hizo `git add`, `commit` ni `push`.

**Presupuesto declarado antes de ejecutar** (PROMPT §4 y LINEO §8.11): **8 hilos**, **8 GiB de RAM**,
**512 MiB de disco**, corridas de minutos por tarea. El tope de la máquina es 24 hilos / 64 GiB, así
que el presupuesto es un techo holgado. **No se agotó.** Las corridas de `run.jl` duran segundos o
pocos minutos, salvo `v1` (discretización × 3 valores de `K` × MC de 100 000 réplicas), que es la
más larga.

**Advertencia de método.** Todas las cifras de **distribución de tamaños** dependen de H3 (ley de
Pareto con exponente declarado y elección declarada); todas las de **ventana** dependerían de
H-PUENTE, y en este encargo **no se usa H-PUENTE en ninguna cifra**: el saldo se modela en unidades
de emisión, no en tasa de bloques por unidad de tiempo derivada del espacio.

---

## 1 · Lo que se leyó, entero, antes de escribir código

| Documento | Qué se tomó |
|---|---|
| `veritas/LINEO.md` (627 líneas) | reglas de cálculo, estructura, presupuesto, §8 |
| `P-ZRX/P-CLAVE/CANDIDATA.md` (268 líneas) | diseño candidato, anexo de Claude, condiciones C1–C4 |
| `P-ZRX/P-PRESTAMO/investigacion/INFORME.md` (587) | superficie `α*`, ventana `F`, juego, coste absoluto, F5/F6. **Se detectó una inconsistencia: §O7** |
| `P-ZRX/P-PRESTAMO/investigacion/DECISIONES-PENDIENTES.md` (166) | D1–D10 |
| `P-ZRX/P-RNG/investigacion/INFORME.md` | §1 (`C_irr`) y **ficha D** (fianza de recompensas propias, «lock asociado a la clave o, mejor, al compromiso de parcela») |
| `P-ZRX/P-EQUIVOCACION/investigacion/INFORME.md` | alcance de `κ` («mide doble farmeo PUBLICADO, no posible») |
| `P-ZRX/P-EQUIVOCACION/investigacion/FALSOS-POSITIVOS.md` | §3 firmante seguro; **FP7** («el billete de la historia abandonada vuelve a estar disponible»); tabla de decisión |
| `SPEC.md` §7.2 (1883–2021) y `C-EMIT-05` (2222–2223) | unicidad pagable por billete, liberación del billete en reorg, madurez que **sólo retrasa el gasto** |
| `research/dag-poas-balizas-auditoria.md` (281) | teorema de identidad: ploteo lineal en bytes + identidades gratis ⇒ ninguna exclusividad por identidad es derrotable… **por partición** |
| `research/README.md` | estado de la evidencia histórica |
| **SpaceMint** (fuente externa) | §3.3, §4 y apéndices. Citas literales en `evidencia/spacemint/`; ver §O13 |

**Cómo se verificó SpaceMint.** No hay `pdftotext` en la máquina. Se descargó el PDF
(`https://eprint.iacr.org/2015/528.pdf`, 29 pp., revisión 2018-03-01,
`sha256 cb2411469608c0d734fa0f1aa5347b57efe49e56d855b8a80761ea4eac2d769a`) y se extrajo el texto. El
extracto completo y su mapa de páginas están en
`P-ZRX/P-CLAVE/investigacion/evidencia/spacemint/spacemint.txt`; las citas se comprobaron **leyendo el
fichero extraído** (`grep` sobre `spacemint.txt`), no una cita de segunda mano.

> **Anotación de método honesta.** La extracción del PDF se hizo con una herramienta Python
> (`pypdf`) para **verificar una fuente**, no para calcular. El cálculo de esta auditoría es
> **Julia en CPU**, y no se creó ni ejecutó ninguna auditoría Python. La herramienta Python se usó
> como sustituto de `pdftotext`, que no existe en la máquina.

---

## 2 · Resumen de lo ejecutado

| Paso | Comando | Resultado |
|---|---|---|
| Proyecto | plantilla `veritas/plantilla` copiada a `investigacion/veritas/economia/retencion-clave-v1/` | `Project.toml` y `Manifest.toml` propios |
| Tests | `JULIA_NUM_THREADS=1 veritas/julia.sh --project=. --check-bounds=yes test/runtests.jl` | **1096 controles, 0 fallos** (`resultados/TEST.log`) |
| Artefactos | `run.jl --tarea f1 … --tarea v4` | `resultados/F1…F6`, `V1…V4` |
| Benchmarks | `bench/benchmarks.jl` (4 hilos) | `resultados/BENCH.txt` |
| Escalado | `bench/escalado.jl` con `JULIA_NUM_THREADS=1,2,4,8` | `resultados/ESCALADO.tsv`: gana **4 hilos** (×1,96); se conserva 4 |

---

## 3 · Defectos propios detectados y corregidos (con su vector de regresión)

Cada uno tiene su comentario en el código y, donde procede, un test que lo fija.

**O1 · La convolución de la distribución perdía la masa de `N = 0`.** Primer intento de
`dist_exacta` con acumulación de desplazamientos sobre el vector acumulado: al añadir `m`
desplazamientos sin estado intermedio, la masa de «cero bloques» se perdía y aparecía
`P(B = 0) = 0,6065` en vez de `e^{−1} = 0,3679`. **Corregido** al sustituir la convolución por la
representación por espacios exponenciales (que es exacta) más una DP explícita para la CDF.

**O2 · La DP de la CDF no llevaba la cuenta de los bloques ya colocados.** La primera DP
distribuía `m` bloques por bin sin encadenar el estado entre bins, y la masa total no sumaba 1
(0,6658 en vez de 1 con `K = 4, m = 2`). **Corregido** con estado `(s, i)` y transición binomial
condicional por bin.

**O3 · `nuevo[fila, :]` COPIA en Julia.** `A[i, :]` devuelve una copia, no una vista (comprobado en
el propio instrumento: `A[2,:]` no escribe en `A`, `view(A,2,:)` sí). Acumular en esa copia dejaba
el estado a cero. **Corregido** indexando la matriz directamente y anotado en el código.

**O4 · Recurrencia de la binomial reutilizada entre bins con `p` distinto.** La recurrencia de
`C(m−r,k)p^k(1−p)^{m−r−k}` en `k` sólo vale para un `p` fijo; al cambiar `j` cambia `p` y la
recurrencia deja de ser válida. **Corregido** con una tabla de coeficientes binomiales explícita y
potencias directas.

**O5 · La masa final de la DP no está en la fila `m+1`.** Tras el último bin `S_{K+1} = 0`: toda la
masa queda en la **fila 1**. Extraer de `estado[m+1, :]` devolvía 0. **Corregido** y comprobado con
la masa total (que ahora suma 1 en todas las celdas).

**O6 · Cancelación catastrófica al normalizar la Pareto.** El primer cálculo del coste de
reclutamiento normalizaba por `E[f] = f_min^α(f_min^{1−α} − F_max^{1−α})/(α−1)`, que con
`f_min = 1e-8` y `α ≈ 2` resta dos números de orden `10^8` y da `3,8e-6` en vez de `18`.
**Corregido** con la forma cerrada estable `coste(β) = coef·β` (o `coef·k + b(β−k)`), deducida de
`E[min(f,x)]/E[f] = 1 − (f_min/x)^{α−2}`.

**O7 · La superficie de deriva heredada es inconsistente consigo misma.** `P-PRESTAMO` escribe en el
texto `g = η_a(α+β_d+β_x) − η_h(1−α−β_x)` (**la pública sólo pierde `β_x`**) pero su fórmula de `α*`
y su tabla de umbrales corresponden al reparto alternativo (**la pública pierde también `β_d`**).
Con `η = 1`: el texto da `β_d > 1 − 2α` (que es lo que dice `PROMPT.md` §2.2 y lo que anula `g`),
mientras que la tabla publica `β_d > (1−2α)/(1−α)` (con `α = 0,33`: `0,5075` frente a `0,34`), valor
en el que `g` **no** se anula (`g = 0,167` con `α = 0,33`). El instrumento implementa el reparto del
texto —el del encargo—, publica la frontera correcta y conserva la heredada como columna aparte.
También se corrigió `alpha_estrella`, que no anulaba `deriva` (test `momentos exactos y frontera de
deriva`). **Cifras afectadas del trabajo anterior:** las tablas de `β_d` mínimo de `P-PRESTAMO` §2.3
y su columna de cruce. **No se toca ningún fichero de `P-PRESTAMO`**: la discrepancia se declara
aquí y en `INFORME.md` §3.

**O8 · El greedy por ratio NO es óptimo para el reclutamiento.** El primer `modelo.jl` afirmaba que
«mínimo coste con `Σf_i ≥ β`» se resuelve con un greedy por ratio y lo «demostraba» por intercambio.
Es falso: es una **cobertura por mochila** (NP-dura) y hay contraejemplo medido
(`n = 9`, greedy `0,4425` frente al óptimo `0,4301`). **Corregido**: el greedy queda como **cota
superior** y se añadió `reclutamiento_exacto` (DP sobre rejilla) como óptimo, con test que compara
las dos con fuerza bruta en 200 instancias.

**O9 · La normal usaba la desviación del NÚMERO de bloques, no la del SALDO.** `masa_cero_aprox`
usaba `σ = √θ` (desviación de `N ~ Poisson(θ)`) en vez de `σ = √(γθ)` con `γ = 1/2` (lineal), la del
saldo. Con `ρ = 0,5`, `I = 1`: la correcta es `σ² = θ/3`. **Corregido** y unificado en una sola
función que usan `referencia.jl` y `rapido.jl`.

**O10 · Con `ρ = 0` la rejilla degeneraba.** El paso de la rejilla incluía `ρ`, así que con `ρ = 0`
el paso era 0 y la CDF se rompía. **Corregido**: `ρ` sale del paso de la rejilla y se aplica al
evaluar `B`; además `dist_enumerada` y `cdf_exacta` devuelven la delta en 0 cuando `ρ = 0` o
`T_v = 0`.

**O11 · La cuadratura de la cola de los pequeños no converge en `f_min`.** La densidad Pareto tiene
una singularidad en `f_min` y `xmax/f_min` llega a `10^8`: una rejilla uniforme en `y` o en `log y`
pierde la masa (daba `2,5e-6` donde vale `0,88`). **Corregido** retirando la cuadratura: la integral
es analítica, y el control independiente es la **CDF truncada estándar** con otra expresión
algebraica (test `E[min(f,x)]/E[f] == CDF truncada`).

**O12 · `enumerar_saldos` con pesos nulos parecía repartir la masa.** No era un defecto del código
sino de la expectativa: con `ρ = 0` el índice discreto **sí** es 0 para toda composición, y el único
camino con masa es `N = 0`; el test esperaba `masas[1] = 1` y lo correcto es la delta en 0. Se
corrigió el test y se añadió el corte explícito de O10.

**O13 · Los resultados negativos también se declaran.** El intento de `P-PRESTAMO` de «corregir» la
fórmula de `BASELINE.md` era un error de lectura (ya retirado allí). Aquí, en cambio, la
discrepancia de O7 **sí** es un defecto real del fichero heredado, y se documenta con la
comprobación numérica (`deriva(α, 1−2α, 0, 1, 1) = 0` frente a `deriva(α, (1−2α)/(1−α), 0, 1, 1) > 0`).
No se afirma que «todo lo anterior está mal»: se acota a esas dos columnas.

---

## 4 · Fuentes externas

| Fuente | Estado | Cita literal | Dónde |
|---|---|---|---|
| SpaceMint, §3.3 | `verificado en fuente` | «A penalty transaction `ctx = (penalty, txId, pk, prf)` consists of `pk`, the public key of the transaction creator, and `prf`, a proof of penalty-worthy behavior by another miner.» | p. 8 |
| SpaceMint, §4 | `verificado en fuente` | «…half of the reward (block reward and transaction fees) that should go to the miner who announced β_{j+1}, is now going to pk (the "accuser") instead, and the other half of the reward is destroyed…» | p. 10 |
| SpaceMint, §4 nota 7 | `verificado en fuente` | «Unlike previous penalty-based proposals, we do not need the miners to make a deposit up-front; instead, they will simply lose their mining reward if they cheat.» | p. 10 |
| SpaceMint, §4 «Case 2» | `verificado en fuente` | «In this case, even with our penalty scheme in place, a rational miner can still get an advantage by deviating…» (retos distintos ⇒ pruebas distintas) | p. 10 |
| SpaceMint, §4-III | `verificado en fuente` | «But penalizing does not protect against double-spending attacks in which the adversary never actually published two proofs for the same slot. And even he would, a double-spending attack can be profitable even if one loses some mining rewards due to the penalizing scheme.» | p. 11 |
| SpaceMint, Ap. D | `verificado en fuente` | «…we assume that with high probability this penalizing is sufficient to ensure that one branch will "die" within at most ∆ blocks.» (supuesto, no teorema) | p. 26 |
| SpaceMint, §4 | **NO EXISTE** la conexión penalización ↔ varianza / mineros pequeños | No se ha encontrado ninguna frase que ligue la penalización a la varianza o a los mineros pequeños en §3.1, §3.3, §4, §7 ni los apéndices. **No se cita como si existiera.** | — |

**Matiz que importa.** SpaceMint **destruye la recompensa aún no transferible del bloque infractor**
(mitad al acusador, mitad destruida); **no retiene de antemano una fracción de las recompensas del
granjero**. La diferencia es exactamente la que estudia este encargo: SpaceMint no tenía un «saldo
retenido acumulado por clave», así que no podía tener la grieta distributiva que aquí se mide.

---

## 5 · Desviaciones del encargo, declaradas

1. **`c_r` y `M` en unidades de emisión.** El PROMPT deja `c_r` y `M` como símbolos sin unidad. Aquí
   se usan en **unidades de emisión por evento** (`c_r = 10`, `M = 20`, `ingreso = 1`), lo que
   reproduce el `c_r + ingreso·M = 30` de `P-PRESTAMO` §5.1 y por tanto su `T_v > 3.700`. `M` se
   interpreta como el **valor de emisión perdido** por la maduración repetida, no como un número de
   slots; el número de slots entra aparte por `T_v > F`.
2. **`V` por reclutado, no `V/N`.** Se tomó `V = 400` **por reclutado** (que es el `V/N = 400` de
   `P-PRESTAMO` §5.1). El primer intento usó `V = 400` como valor total con `N = 100` reclutados y
   dio una región vacía por un factor 100; **se corrigió** (O14, abajo).
3. **Umbral de «saldo cero» explícito.** El PROMPT pide «claves con saldo confiscable cero». El
   modelo da `P(B = 0) = e^{−θ} > 0` pero el saldo es nulo sólo si no hay bloques en la ventana; para
   poder hablar de «casi cero» se introduce `ε` (u.e.) y se publica **cada fila con su `ε`**. La
   distinción entre `P(B = 0)` exacta y «saldo < ε» está en el informe.
4. **Ningún Monte Carlo decide una cifra.** Toda cifra de F1–F6 sale de forma cerrada o de la DP
   exacta. El Monte Carlo sólo se usa como **control** (y su comparación está en los tests).

**O14 · Región vacía por un factor 100 en `V`.** Primer cálculo de F5 con `soborno_max = V/N` y
`V = 400, N = 100`: la condición quedaba `κq(ρT_v + 30) > 4`, que se cumple para todo `T_v ≥ 0` y
daba `T_v_min` negativo. **Corregido**: `soborno_max = V` (V es por reclutado).

---

## 6 · Rendimiento y reproducibilidad

- **Entorno:** Julia 1.13.0, `veritas/julia.sh` (`env -u LD_LIBRARY_PATH`), depot
  `P-ZRX/P-CLAVE/investigacion/.julia-depot` + `~/.julia`, `Manifest.toml` propio versionado.
- **Hardware:** AMD Ryzen 9 9950X3D (`Sys.CPU_NAME = znver5`), 32 hilos lógicos, 123 GiB.
- **Comandos exactos y tabla de rendimiento:** `resultados/BENCH.txt` y `INFORME.md` §7.
- **`uptime`** anotado en cada bloque de benchmark.
- Ningún benchmark se publica sin haber calentado el JIT; las asignaciones del kernel están medidas
  con `@allocated`.

---

## 7 · Lo que quedó abierto

- La **distribución real de tamaños de clave** no existe medida en ZEROX ni en Autonomys: H3.
- El **puente espacio → tasa** (H-PUENTE) no se usa aquí, pero sigue sin existir.
- `F`, `M`, `ρ_ret`, `T_v`, `κ`, `q`, `ν`, `V`, `c_r` siguen siendo **símbolos**.
- La **capacidad real de reclutamiento** (`q_gana`) y la **censura de la prueba** no se miden: el
  informe las trata como adversarios aparte.
