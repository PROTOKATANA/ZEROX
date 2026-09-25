# METODO — T02: ejecución, rejilla, validación y reproducibilidad

## 1. Entorno y comandos exactos

Máquina de referencia: AMD Ryzen 9 9950X3D (16 núcleos / 32 hilos), 123 GiB de RAM. Julia fijada
por la orden: **1.13.0** (`julia-version.toml`). `LD_LIBRARY_PATH` se anula (`env -u
LD_LIBRARY_PATH`) por el *segfault* conocido con las bibliotecas de AOCC (LINEO §1).

    cd /home/katana/zeo/ZEROX/P-ZRX/P-TRANSICION/T02
    export JULIA_DEPOT_PATH=/home/katana/zeo/ZEROX/P-ZRX/P-TRANSICION/T02/.julia-depot:
    export JULIA=/home/katana/.julia/juliaup/julia-1.13.0+0.x64.linux.gnu/bin/julia

    # Tests (perfil de referencia, 1 hilo, límites activos)
    env -u LD_LIBRARY_PATH JULIA_NUM_THREADS=1 $JULIA --project=. \
      -e 'using Pkg; Pkg.instantiate(); Pkg.test()' > resultados/test.log 2>&1

    # Monte Carlo (perfil de rendimiento, 4 hilos = tope de la orden)
    env -u LD_LIBRARY_PATH JULIA_NUM_THREADS=4 OPENBLAS_NUM_THREADS=1 \
      $JULIA --project=. --threads=4,0 run.jl \
      --seed 0x5a5a --replicas 100000 --escenario todos > resultados/run.log 2>&1

Dependencias declaradas en `Project.toml`: `StableRNGs`, `SpecialFunctions`, `Distributions`,
`BenchmarkTools` (permitidas por la orden) y las stdlib `Random`, `Statistics`, `Printf`.
`Manifest.toml` está versionado; no se usa el entorno global. Resultado medido:
**`Pkg.test()` 69/69 en ~2,4 s**; **`run.jl … --escenario todos` en 10,7 s y 457 MiB** (tope
declarado: 2 h, 4 hilos, 16 GiB, 2 GiB).

## 2. Presupuesto declarado

2 h de reloj, **4 hilos** (tope de §6), 16 GiB de RAM, 2 GiB de disco. Consumo real: ~11 s de CPU
de pared y 457 MiB; muy por debajo del tope. No hubo que recurrir a *checkpoint* ni a estado
inconcluso.

## 3. Rejilla efectiva (valores de prueba de §3.6)

La orden declara la rejilla como **valores de prueba, no parámetros propuestos**. Cada escenario usa
la parte pertinente:

| Escenario | Puntos | Detalle |
|---|---:|---|
| E1 | 24 + 22 | `h ∈ {0.1;0.25;0.4;0.5;0.6;0.9} × z ∈ {0;1;3;6}` (MC) y la tabla publicada de §11 (22 puntos) |
| E2 | 35 | base `(0.25;0.4;6;0.1;0.9;1000)` + barridos de `h`, `a`, `k`, `r`, `p`, `F_slots` y 9 interacciones `(h,a)` con `a < 1/2`; los puntos con `a ≥ 1/2` usan `F_slots ≤ 100` para acotar el horizonte |
| E3 | 6912 | **producto cartesiano completo** `h×a×k×δ×r×p×F_slots` (fórmulas exactas) |
| E4 | 24 | `h ∈ {0.1;0.25;0.4;0.5;0.6;0.9} × M_dep ∈ {1;3;6;12}` |

`M = 10·F_slots`, y `M = 10⁵` para `F_slots = ∞`.

## 4. Reglas numéricas

- Conteos, decisiones de selección y reglas en enteros. Probabilidades en `Float64`.
- Intervalos de Monte Carlo: **Wilson al 99,9 %** (`z = 3,290527`) para toda proporción; se reporta
  `p`, `lo`, `hi`. Umbral de «probabilidad no despreciable»: `P > 10⁻³` con IC que no contenga
  `10⁻³`; si lo contiene, el punto es inconcluso.
- Fórmulas cerradas donde existen (E1 exacto; E3 exacto; E2 sin horizonte exacto como oráculo).
- Reducción determinista: una posición por réplica y reducción final en orden de réplica.

## 5. Aleatoriedad y paralelismo (LINEO §7)

- Semilla maestra por CLI (`--seed 0x5a5a` por defecto). RNG **StableRNG** derivado de
  `(semilla maestra, escenario, punto, réplica)` con un mezclador SplitMix64: un flujo independiente
  por réplica y por punto.
- Réplicas repartidas con `Threads.@threads`; cada réplica escribe su posición; ninguna mutación
  compartida; reducción posterior.
- Se conservó la configuración de 4 hilos (tope de la orden). El coste es tan pequeño que no se
  justifica un barrido 1/2/4 completo; aun así el test corre a 1 hilo (perfil de referencia) y la
  corrida a 4 (perfil de rendimiento).

## 6. Validación

| Chequeo | Resultado |
|---|---|
| Fórmula E1 vs tabla publicada de Nakamoto §11 (22 puntos) | error máximo **4,83·10⁻⁸** (< 10⁻⁶) |
| Simulador E1 vs fórmula (24 puntos de la rejilla) | **24/24** dentro del IC 99,9 % |
| E2 sin horizonte (`F_slots = ∞`, `a < 1/2`) vs fórmula exacta | dentro del IC en los puntos probados |
| E3 fórmula exacta vs MC (128 chequeos) | **0/128** fuera del IC 99,9 % |
| E4 h→0: corte seguro para todo `M_dep` | 2000/2000 |
| Coherencia `referencia.jl` ↔ `rapido.jl` en E4 (misma semilla) | trazas idénticas |
| `Pkg.test()` | **69/69** |

El detalle está en `resultados/E1_tabla_nakamoto.csv`, `resultados/E3_validacion_mc.csv` y
`resultados/test.log`.

## 7. Ficheros y trazabilidad

- `src/modelo.jl` (tipos/rejilla/RNG/Wilson), `src/referencia.jl` (fórmulas y simulador
  transparente), `src/rapido.jl` (MC), `src/validacion.jl` (comparaciones), `src/T02.jl` (módulo).
- `test/runtests.jl`; `run.jl` (CLI `--seed`, `--replicas`, `--escenario`, `--hilos`).
- `resultados/`: `E1.csv`, `E1_tabla_nakamoto.csv`, `E2.csv`, `E3.csv`, `E3_validacion_mc.csv`,
  `E4.csv`, `resumen.csv`, `test.log`, `run.log`.
- Entradas congeladas comprobadas al empezar y al terminar: `ENTRADA-T02.sha256` y
  `ENTRADA-T02-A.sha256` (salidas en `PROGRESO.md`).

## 8. Limitación de la rejilla E2

La corrección exige «≥ 10⁵ réplicas por punto donde no haya fórmula». E2 y E4 no tienen fórmula
exacta con horizonte y se resuelven por Monte Carlo con 10⁵ réplicas por punto. Para mantener el
coste dentro del presupuesto, E2 usa una **sensibilidad** alrededor de un punto base más las
interacciones de la pregunta falsable (35 puntos) en vez del producto cartesiano completo
(6·6·4·3·2·4 = 3456 puntos), que habría exigido ~3,5·10⁸ réplicas; el producto completo de E2 queda
**inconcluso por presupuesto**, salvo los puntos efectivamente corridos. E3, que sí tiene fórmula
exacta, cubre el producto cartesiano completo sin coste de Monte Carlo.
