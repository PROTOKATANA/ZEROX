# CONTRATO de lectura — SDV-v1.1

**Pregunta:** si una segunda cadena AES de revelación reduce la ventana de frontera `V` con adversario causal y recursos finitos. Categoría dominante: seguridad; secundarias: consenso y rendimiento. Ningún resultado fija parámetros ni cambia el SPEC. `V` no es finalidad económica.

## Entradas y unidades

`L,I,S_max,Lrev,D` son slots PoT; `W_dec` se introduce en segundos físicos y se convierte con `τ_nom=1 s/slot` solo en el escenario. `ρ` es tasa AES secuencial adversaria / tasa de referencia. `α` es probabilidad Bernoulli **elegida para simulación**, no cuota validada de anclas DAG. `J,R,seed` fijan épocas, réplicas y aleatoriedad. `con_h` activa la segunda cadena; `revelacion_paralela` inicia al conocer la semilla en `lineas_revelacion` finitas; `revelacion_instantanea` es control contrafáctico; `espera` retarda la decisión ajena `W_dec`; `semilla_futura` distingue C-FLU-12 de h.1.

El kernel calcula `r=max(t_PoT,t_chunk,t_flujo_previo,t_recepción)` y permite introducir por vector cada uno de esos tiempos y `c` de decisión; registra los componentes, inicio/fin y línea. Sin vectores externos toma la hipótesis optimista del escenario. Mantiene PoT principal separado. Solo agenda **una semilla seleccionada por época**. La disponibilidad y decisión reales y los candidatos especulados no se derivan de DAG; `TRAZA-CAUSAL.txt` es agenda abstracta, no bloque válido.

## Verificación y salidas

`src/referencia.jl` es oráculo max-plus racional independiente de la transición rápida; `src/validacion.jl` compara 384 casos y añade controles que prohíben omitir `Lrev/ρ`. Ambos programas comparten las premisas del modelo, que se evalúan aparte en `INFORME.md`. `ESCENARIOS.txt` separa `V_max` determinista (ajenas, offset cero) de q99 aleatorio (mixtas, offset geométrico); `REGIMENES.txt` compara espera, línea causal e ideal instantáneo; `SEMILLA.txt` usa `--seed` para la parte mixta; `BENCH-CORREGIDO.txt` mide procesos con hilos reales. Resultados y documentos originales: `resultados/historico-deepseek-2026-09-23/`; salidas corregidas anteriores al traslado: `resultados/pre-reubicacion-2026-09-23/`.

## Reproducción

Desde este directorio, con el proyecto aislado y `veritas/julia.sh` (ubicación en `P-ZRX/` solicitada expresamente por el usuario):

```bash
env JULIA_DEPOT_PATH=/tmp/segundo-vdf-julia-depot:$HOME/.julia JULIA_NUM_THREADS=4 OPENBLAS_NUM_THREADS=1 JULIA_PKG_PRECOMPILE_AUTO=0 ../../../veritas/julia.sh --project=. --threads=4,0 test/runtests.jl
env JULIA_DEPOT_PATH=/tmp/segundo-vdf-julia-depot:$HOME/.julia JULIA_NUM_THREADS=4 OPENBLAS_NUM_THREADS=1 JULIA_PKG_PRECOMPILE_AUTO=0 ../../../veritas/julia.sh --project=. --threads=4,0 run.jl --modo todo --replicas 64 --seed 0x5a5a
```

Para escalado, ejecutar `bench/benchmarks.jl` en **procesos separados** con `--threads=N,0`, `N=1,2,4,8,16`, y `JULIA_NUM_THREADS=N`. Hardware de esta corrida: Ryzen 9 9950X3D; Julia y semilla en `resultados/ENTORNO.txt`. Presupuesto máximo: 24 hilos, 64 GiB RAM, 8 GiB disco temporal. El oráculo y la simulación usan CPU, nunca Python.

**Estados:** calibración racional y agenda de una cadena por época, derivados; salida Julia y benchmarks, medidos en el instrumento; costes de segundo AES y números de candidatos, pendientes; seguridad de finalidad con hardware sofisticado, inconclusa.
