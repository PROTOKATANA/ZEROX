# INFORME — almacenamiento/permanencia-v1

**Categoría dominante:** `almacenamiento`. Secundarias: `seguridad` (la trampa y la regeneración) y
`economía` de hardware (coste por TiB simulado, sin precios). Motivo: la pregunta es qué prueba
que una parcela sigue existiendo, y el objeto medido es espacio/regeneración. Se declara por
exigencia de `veritas/LINEO.md` §1.

**Pregunta que responde:** ¿cuánto cuesta, en hardware, aparentar que se almacena un lote de `N`
piezas cuando no se almacena? El modelo compara E2 (aperturas por muestreo), E3 (pruebas
parciales), E4 (sellado secuencial) y E5 (farmear y nada más) como funciones de los símbolos del
encargo. **No** decide el veredicto del paquete: eso está en
`P-ZRX/P-PERMANENCIA/investigacion/INFORME.md`.

**Hipótesis que codifica:** `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md` (H1–H8), escritas antes de
mirar los números.

## Presupuesto declarado antes de ejecutar (LINEO §7, §8.11)

- Hilos: **máximo 4** (tope del encargo; el tope LINEO es 24 y hay otros encargos).
- RAM: 8 GiB. Disco: 256 MiB. Tiempo: 4 h. **No se agotó.**
- Línea de ejecución publicada: `./correr-modelo.sh`
  (`JULIA_NUM_THREADS=4 OPENBLAS_NUM_THREADS=1`).

## Estructura (LINEO §1)

```text
permanencia-v1/
├── Project.toml · Manifest.toml · julia-version.toml
├── mediciones/hardware.tsv      # entradas de hardware medidas, con fuente y etiqueta
├── src/{PermanenciaV1,modelo,referencia,rapido,validacion}.jl
├── test/runtests.jl
├── bench/benchmarks.jl
├── run.jl · correr-modelo.sh
├── resultados/                  # artefactos generados
├── HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md
└── INFORME.md                   # este fichero
```

## Diseño de la representación (LINEO §2)

- **Operación dominante:** evaluar colas de Poisson y búsquedas de umbral/potencia sobre rejillas
  pequeñas (decenas de filas), no Monte Carlo masivo. No se materializa ninguna combinación.
- **Referencia exacta:** `Rational{BigInt}` para el término `Σ λ^j/j!` y para la cola binomial. Es
  el oráculo contra el que se valida todo.
- **Kernel riguroso:** intervalo `[lo,hi]` con **redondeo dirigido de MPFR** (`setrounding`) en cada
  operación y `setprecision(256)`. Se usan cotas conservadoras: **cota superior** para el falso
  fallo y **cota inferior** para la potencia. Si el intervalo cruzara un umbral, el resultado se
  declararía inconcluso (no ocurrió en ninguna fila publicada).
- **Kernel rápido:** `Float64` con suma relativa a la moda (evita el subdesbordamiento de
  `exp(-λ)`), solo para barridos; validado contra la referencia (`max_dK = 0`, `max_dP = 3,9·10⁻¹²`).
- **Sin Monte Carlo:** el encargo pide referencia exacta antes de aproximar; no se necesitó RNG, así
  que no hay semilla que registrar ni riesgo de intervalos de confianza. `StableRNGs` queda en el
  `Project.toml` sin uso en los resultados publicados.

## Validación (LINEO §5, §10)

`test/runtests.jl`: **51 comprobaciones**, todas en verde. Resultados en `resultados/VALIDACION.txt`:

| Comprobación | Resultado |
|---|---|
| Intervalo de Poisson vs oráculo exacto `Rational{BigInt}` | contención **sí**; error relativo máximo **7,08·10⁻⁷⁶** |
| Poisson vs binomial exacta (lotes pequeños) | discrepancia **1,52·10⁻³** ≤ cota de Le Cam **4,0·10⁻²** |
| Kernel rápido vs referencia | `max_dK = 0`; `max_dP = 3,9·10⁻¹²` |
| Potencia monótona en `T` | **sí** (con tolerancia `10⁻⁹`) |
| Bordes (`λ=0`, `k=−1`, `s=1`, `w=0`, monotonías) | **OK** |
| `periodos_deteccion` vs búsqueda directa independiente | **coincide** |

**JET** (`resultados/JET-concreto.txt`): sobre envoltorios de tipos concretos (`BigInt`, `Int`,
`Float64`), las únicas marcas son **3 por función**, todas dentro de `Base.ScopedValues`/MPFR
(`setprecision`/`setrounding`): despacho dinámico **de Base**, no del kernel. La primera versión
tenía inestabilidad real (`Any` por capturar variables mutables en un `do`); se corrigió moviendo la
aritmética a funciones propias (`_add_rd`, `_mul_ru`, …).

## Rendimiento medido (LINEO §6; Julia 1.13.0, CPU `znver5`, 4 hilos)

| Rutina | Mediana (mín.) | Asignaciones | Memoria | Hilos |
|---|---:|---:|---:|---:|
| `barrer_e3!` (1.000 puntos) | **0,184 µs** | **0** | **0 B** | 1 |
| `umbral_rechazo(λ=100, β=10⁻³)` | **80,2 µs** | 5.708 | 194 kB | 1 |
| `poisson_cdf_intervalo(λ=100, k=120)` | **112,9 µs** | 8.269 | 282 kB | 1 |
| `periodos_deteccion(λ=100, s=½)` | **304,3 µs** | 21.184 | 722 kB | 1 |
| `barrer_paralelo` (1.000 puntos, 4 hilos) | 1,77 µs | 31 | 26 kB | 4 |

**Interpretación.** El kernel de barrido E3 no asigna nada. Las rutinas de cola exacta asignan
(del orden de 10²–10³ kB por llamada) por el `BigInt`/`BigFloat` y por los cierres de
`setprecision`; no se optimizaron más porque el caso real (decenas de filas) tarda **menos de 1 s**
en total y el cuello no está ahí. No se usó `@fastmath`; `@inbounds` solo en `barrer_e3!` (índices
de la propia rejilla) y `@threads` solo sobre puntos disjuntos de la rejilla. La configuración
conservada es **4 hilos**, el tope del encargo; el barrido es tan corto que el escalado no cambia
el resultado.

## Comando exacto

```bash
cd P-ZRX/P-PERMANENCIA/investigacion/veritas/almacenamiento/permanencia-v1
export JULIA_DEPOT_PATH="$PWD/../../.julia-depot:/home/katana/.julia"
JULIA_NUM_THREADS=4 OPENBLAS_NUM_THREADS=1 \
  /home/katana/zeo/ZEROX/veritas/julia.sh --project=. test/runtests.jl
JULIA_NUM_THREADS=4 OPENBLAS_NUM_THREADS=1 \
  /home/katana/zeo/ZEROX/veritas/julia.sh --project=. bench/benchmarks.jl
./correr-modelo.sh
```

## Lo que este instrumento NO resuelve

- No mide hardware nuevo; usa las cifras de P-INTENTO/P-REVELACION y las etiqueta.
- No fija ningún parámetro de consenso ni ningún precio.
- No modela `π_DAG`, ni la selección del DAG, ni la varianza de la red honesta.
- No demuestra nada criptográfico: sus salidas son cotas económicas condicionadas a `w` y al
  hardware del atacante.
