# BITACORA — `eclipse-red-v1`

Registro de construcción del instrumento. Los hitos, los fallos y las correcciones.

## 2026-09-24

**10:34 — Entrada.** `sha256sum -c` de `ENTRADA.sha256`: 6/6 OK. `git status` y `date` registrados
en `P-ZRX/P-ECLIPSE/investigacion/PROGRESO.md`. Reconocimiento del repositorio y de `veritas/`.

**10:36 — Lecturas.** `LINEO.md` entero; `AGUJEROS-Y-SOLUCIONES.md`; `LIBRO-DE-RESTRICCIONES.md`;
11b `informe.md` entero; `ENCARGO.md`; `salida_a3b.txt`; reglas del `SPEC.md` extraídas **por ID**.

**10:37 — Decisión de arquitectura.** El control positivo exige reproducir **los mismos números**
del oráculo Python, que siembra con cadenas. Conclusión: hay que **portar el RNG de CPython bit a
bit**; ningún otro generador sirve. Es la decisión que hace posible todo lo demás.

**10:38 — Entorno.** Julia 1.13.0 funciona con `veritas/julia.sh`. **Incidencia:** `$HOME/.julia` es
de sólo lectura → `Pkg` falla con *«The primary depot is not writable»*. Se resuelve con
`JULIA_DEPOT_PATH=<workspace>/.julia-depot:$HOME/.julia`.

**10:39 — `src/pyrng.jl`.** MT19937 + `init_by_array` + sembrado por cadena con SHA-512.
**Validado**: vector publicado del MT19937 (`init_genrand(5489)`, 10 valores) y
`random.Random(0/1/42).random()` con coincidencia exacta de 17 dígitos.

**10:40 — `src/mundo.jl`.** **FALLO REAL:** la primera corrida del control **segfaultó**. Causa:
los buffers `visible` y `marca` se inicializaban a longitud 1 y no crecían con el estado, mientras
`tips_vista!` los indexaba hasta `est.n` con `@inbounds` → escritura fuera de rango. Corregido
haciéndolos crecer en `agrega!`. **Comentado en el código** porque es exactamente el fallo que
`LINEO.md` §3.3 pide cubrir con un test de dimensiones.

**10:41 — CONTROL POSITIVO SUPERADO.** `0,8218 / 0,6513 / 0,5920 / 0,5460` con `n_C = 522`, y
`α = 0,25` → `0,8806 / 0,7687 / 0,7289 / 0,6816` con `n_C = 402`. Idénticos al oráculo en promedios
**y en conteos**. El puerto es fiel.

**10:43 — Variantes.** Las tres reproducen las tablas de 11b, incluidos los `n`: 215, 193, 190, 178,
175, 180, 143, y la variante (i) con 192 bloques antes / 0 después.

**10:45 — `run.jl`.** Modos `--entorno`, `--control`, `--variantes`, `--regimen`, `--sensores`,
`--captura`, `--flujo`. Barrido de régimen lanzado en segundo plano.

**10:47 — Módulos de análisis.** `sensores.jl` (Poisson exacto + frontera secuencial),
`captura.jl` (hipergeométrico exacto), `flujo.jl` (aritmética de slots + pinza de `PRESUP_NODO`).

**10:48 — FALLO 2, cazado por el test.** `erf` **no está en `Base` de Julia** → la CDF normal
abortaba. Primer arreglo: fracción continua de Lentz para `erfc`.

**10:49 — FALLO 3, cazado por un test de identidad.** La CDF de Lentz daba `Φ(1,96) = 0,98896` en
vez de `0,97500`, y `P(D>8) = 0,004516` cuando es **forzosamente** `0,0100` por construcción de la
lognormal. **El test lo cazó, no una revisión.** Sustituida por serie de Taylor (`y ≤ 10`) +
expansión asintótica con truncación óptima (`y > 10`), a 512 bits.

**10:52 — Sensores validados.** `P(D>8) = 0,0100000000`, `P(L>8) = 0,014760` (idéntico al
publicado), `n_min = 6/23/66/211` y `α = 0,9249` (idénticos), y `B` reproduce 11b §B.1 **celda a
celda** en lognormal.

**10:53 — FALLO 4.** El ajuste de la Pareto estaba mal (`ln 100` en vez de `ln 50` en el exponente).
Con el correcto, `76,40 / 138,92` y `1 422,41` salen **idénticos** a lo publicado. Queda **una**
celda sin reproducir (Pareto `p99=16` «por slot»: `20 048` frente a `50 692`), anotada en
`INFORME.md` §6.7 con la causa **no determinada**.

**10:53 — FALLO 5, de etiqueta.** El comentario de `s0_max_ventana_vacia` decía «el caso más
favorable al defensor» cuando tomar el ancla más temprana es lo que **minimiza** la duración, luego
`E_min = F_slots` es una **cota inferior**. Corregido en el código y anotado como H-13 del
autoexamen: es la clase de frase que se escribe por inercia y no se comprueba.

**10:54 — Tests.** `--check-bounds=yes`: **1006/1006 pasan** en 3,3 s.

**10:55 — Entregables.** `INFORME.md`, `DECISIONES-PENDIENTES.md`, `BORRADORES-C-NET.md`,
`PROGRESO.md`, `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md` y esta documentación.

**10:56 — Limpieza.** Un subagente dejó cinco `rn-*.md` de Bitcoin Core en `P-ZRX/P-ECLIPSE/`,
fuera de la zona autorizada. Eliminados. Comprobadas las huellas de salida: 6/6 **OK**.

## Balance de fallos

| Fallo | Cómo se detectó | Lección |
|---|---|---|
| Buffers de vista que no crecían → segfault | La corrida | `@inbounds` sin test de dimensiones es una bomba; `LINEO.md` §3.3 lo dice |
| `erf` no está en `Base` | La corrida | Verificar la stdlib antes de escribir |
| CDF de Lentz mal | **Test de identidad** (`P(D>8) = 0,01` forzoso) | Las identidades por construcción valen más que un valor «conocido» |
| Ajuste de la Pareto | Reproducción del oráculo | Dos ajustes «razonables» de la misma frase difieren en un factor >2 |
| Comentario con la dirección de la cota invertida | Autoexamen adversarial | Una etiqueta de conservadurismo escrita por inercia es un error |

**Cuatro de los cinco fallos los cazó un control, no una revisión.** Es el argumento del encargo
§4.5 sobre por qué el control positivo y los tests de identidad no son ceremonia.
