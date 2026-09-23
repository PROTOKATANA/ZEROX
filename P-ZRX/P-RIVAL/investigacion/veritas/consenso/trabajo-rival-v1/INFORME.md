# INFORME del instrumento — trabajo-rival-v1 (TR-v0.1)

Ficha técnica del proyecto Julia. El **resultado** está en `../../INFORME.md`; aquí va **qué es el
aparato, cómo se comprueba y cuánto cuesta**.

**Categoría** (`veritas/LINEO.md` §1): `consenso` (dominante) — el objeto es una regla de peso de
consenso; `seguridad` y `economía` (secundarias). **Ruta:**
`P-ZRX/P-RIVAL/investigacion/veritas/consenso/trabajo-rival-v1/`.

**Pregunta.** ¿Cuánta fracción `θ` del peso en trabajo rival hace falta para que el doble farmeo
deje de dar ventaja, y queda ZEROX en pie con esa cantidad?

**Método.** Modelo exacto de umbrales de deriva sobre espacio normalizado a 1, con `Rational{BigInt}`
en toda frontera. Tres composiciones de peso (aditiva, multiplicativa, de umbral). Controles
independientes por bisección exacta, diferencia finita exacta y enumeración entera.

**Entorno.** Julia 1.13.0 (`veritas/julia.sh`), CPU AMD Ryzen 9 9950X3D (`znver5`), 32 hilos lógicos,
123 GiB. Sin Python. Depósito local `.julia-depot` encadenado a `/home/katana/.julia` para no escribir
fuera del espacio de trabajo.

**Presupuesto declarado.** 4 hilos, 4 GiB de RAM, 256 MiB de artefactos, minutos por tarea, techo de
2 h. **No se agotó.** `uptime` en `PROGRESO.md` y en `resultados/BENCH.txt`.

**Dependencias.** `BenchmarkTools`, `JET`, `StableRNGs`, `Random123`, `Aqua` y las stdlib `Test`,
`Random`, `Printf`, `Dates`. `Manifest.toml` versionado.

**Estructura.**

```text
trabajo-rival-v1/
├── Project.toml / Manifest.toml
├── src/modelo.jl        tipos, deriva, fronteras exactas, θ* de las tres lecturas
├── src/referencia.jl    oráculos independientes (bisección, diferencia finita, enumeración)
├── src/rapido.jl        kernels Float64 de rejilla y modelo de coste
├── src/validacion.jl    invariantes y bordes (9 controles, 1.121 asserts)
├── test/runtests.jl     perfil de referencia, 1 hilo, --check-bounds=yes
├── bench/benchmarks.jl  tabla LINEO §6
├── run.jl               CLI; artefactos F1…F6
└── resultados/          artefactos generados (no fuente de verdad)
```

**Complejidad.** El modelo es **afín/racional**: cada frontera es `O(1)` en aritmética exacta. Los
oráculos de bisección son `O(it)` con `it = 512` sobre racionales de denominador acotado. La
enumeración de la compuerta es `O(s_max²·h_max)`. No hay Monte Carlo: el modelo no lo necesita, y por
eso no hay semilla que fije un resultado (la semilla sólo etiqueta la corrida).

**Elección de estructuras** (LINEO §4). Todo escalar y exacto; no hay arrays en el camino caliente de
las fronteras. El único kernel de rejilla (`rejilla_alpha!`) es un `Vector{Float64}` de destino
preasignado, escritura contigua en orden de columnas, `@inline`, sin asignaciones. No se justifica
SoA, CSR, `StaticArrays` ni `Dict` en un problema de dimensión 5.

**Verificación (LINEO §10).** `resultados/TEST.log`: **1.121 controles, 0 fallos**, 1 hilo,
`--check-bounds=yes`. Rutas independientes, ninguna fórmula contra sí misma:

| vía | contra qué se contrasta |
|---|---|
| deriva desde las tasas `W_pub`, `W_priv` | la expresión factorizada de `g` |
| bisección exacta de `g` en `[0,1]` | la forma cerrada de `α*` |
| diferencia finita exacta de `g` en `β` | la derivada simbólica `(1−θ)+θc` |
| enumeración entera de la compuerta (`h÷D`) | el criterio de tasas `min(s,h/D)` |
| bisección multiplicativa (elevando a `q`) | el control `θ = 0` |
| `θ_imp`: `α*(θ_imp) = 1` | la definición de cierre por imposibilidad |

**Defectos propios corregidos** (con vector de regresión cada uno): bucle roto en el primitivo de
compuerta; borde `σ_priv = 0` en la multiplicativa; bisección aditiva con `g(0) ≥ 0`; y la confusión
**trabajo comprado / reasignado** en la marginal de `β_x`, de la que nació el hallazgo de F4.

**Rendimiento.** `resultados/BENCH.txt` (formato LINEO §6). El instrumento es de **minutos**; la
mayor parte del tiempo es compilación de JIT la primera vez. No se paraleliza el núcleo: el problema
es `O(1)` y el barrido de artefactos tarda menos de un segundo con 4 hilos.

**Reproducción.** Ver `../../INFORME.md` §8. La línea exacta:

```bash
JULIA_NUM_THREADS=4 OPENBLAS_NUM_THREADS=1 \
  /home/katana/zeo/ZEROX/veritas/julia.sh --project=. run.jl --control --seed 0x524956414c
```

**Límites del aparato.** Es un modelo de umbrales de **medias**, no una simulación de DAG; no modela
red, retardo, mergesets ni `blue_work` ejecutándose. `ρ` (trabajo rival del atacante) es una **entrada
exógena**: el instrumento no deriva de dónde sale ni a qué precio. Las cifras de coste (F5) usan
supuestos declarados (`e_hash`, `P_plot`, `T_vida`, potencias de disco).
