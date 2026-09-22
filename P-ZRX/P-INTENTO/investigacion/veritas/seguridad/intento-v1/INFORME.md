# Instrumento intento-v1

Modelo de coste del intento dirigido del sembrador y de espacio honesto equivalente.
Categoría dominante: **seguridad**. Secundarias: economía (sin precios) y rendimiento.

**El informe completo está en [`../../../../INFORME.md`](../../../../INFORME.md)** (respuesta en la
primera línea, control contra los 83,6 s, M1–M6 y el barrido). Aquí solo se documenta el
instrumento.

## Qué hace

Convierte las medidas del banco Rust —**leídas de `mediciones/modelo-entrada.tsv`, nunca
tecleadas**— en dos magnitudes **sin precios**:

```text
N_eq(máquina, w)   = r · w · τ         piezas de espacio honesto equivalente que emula una máquina
máquinas(α,N_h,w)  = (α/(1−α)) · N_h / N_eq(w)
```

y en los umbrales que deciden si el ataque es viable:

```text
w_min_latencia = 1/(r·τ·p)      mínimo para cubrir una solución por slot
w_equilibrio   = N_h/(r·τ)      donde UNA máquina emula la red entera
```

Con la calibración `p = λ/N_h` los dos coinciden cuando `λ = 1`. **Eso es un resultado del modelo,
no un supuesto**, y el barrido lo reproduce.

## Estructura

```
intento-v1/
├── Project.toml / Manifest.toml      entorno aislado (BenchmarkTools, JET)
├── julia-version.toml                Julia 1.13.0
├── src/IntentoV1.jl                  módulo
├── src/modelo.jl                     tipos, validación, lectura de medidas
├── src/referencia.jl                 oráculo exacto Rational{BigInt} + BigFloat 256 bits
├── src/rapido.jl                     kernel tipoestable, O(1) por fila, 0 asignaciones
├── src/validacion.jl                 equivalencia e invariantes
├── test/runtests.jl                  58 comprobaciones
├── bench/benchmarks.jl               BenchmarkTools, @code_warntype, JET, Profile
├── run.jl                            CLI reproducible
├── correr-modelo.sh                  barridos publicados
├── resultados/                       artefactos; no son fuente de verdad
└── HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md
```

## Cómo se ejecuta

```bash
cd P-ZRX/P-INTENTO/investigacion/veritas/seguridad/intento-v1
export JULIA_DEPOT_PATH="$PWD/../../../.julia-depot:/home/katana/.julia"
JULIA=/home/katana/zeo/ZEROX/veritas/julia.sh
JULIA_NUM_THREADS=1 $JULIA --project=. test/runtests.jl
JULIA_NUM_THREADS=1 $JULIA --project=. bench/benchmarks.jl
./correr-modelo.sh
```

El depósito en capas hace falta porque el registro de Julia (`~/.julia/registries`) está fuera de
la zona de escritura de esta sesión. La segunda capa es el depósito normal de la máquina.

## Resultado medido del propio instrumento

**[Medido]** Julia 1.13.0, `znver5`, 1 hilo, 100.000 filas:

| | |
|---|---:|
| Kernel `barrer!` mediana | **581,6 µs** |
| Asignaciones | **0 bytes, 0 allocs** |
| Error relativo máximo frente al oráculo de 256 bits (200 casos) | **2,74·10⁻¹⁶** |
| Comprobaciones en `test/runtests.jl` | 58, todas en verde |
| JET | sin errores |

## Entradas que el instrumento NO fija

`w`, `α`, `N_h`, `τ`, `π_DAG` y `R_s` son entradas. `w` es un **símbolo**: su valor real lo dará
`P-ZRX/P-REVELACION/`. La sensibilidad a `π_DAG` se muestra en el informe y **fijarla a 1 favorece
al atacante**.

## Límites declarados

- Todo lo que entra es una **cota superior** del coste del atacante.
- No hay ninguna cifra monetaria en el modelo ni en sus salidas.
- El coste de derivar los retos (salida del PoT) queda fuera: se supone conocida y compartida.
- No se modela actividad de red, reintentos, latencia de propagación ni competencia por el pago.
