# REV-v1.0 — instrumento

Instrumento de `P-ZRX/P-REVELACION/investigacion/`. **El informe es
[`../../INFORME.md`](../../INFORME.md)** (tres niveles arriba); este fichero sólo fija el contrato
del directorio, como pide `veritas/LINEO.md` §1.

- **Categoría:** `seguridad` (dominantes secundarias: `consenso` y `rendimiento`). Motivo: la
  pregunta es cuánta ventana de retos futuros conoce el atacante y qué le hace la revelación
  retardada `R-FIN-14(h)`; las reglas que la restringen son de consenso y su precio se mide en
  núcleos por nodo.
- **Modelo:** `MODELO.md` no existe como fichero aparte: el modelo matemático, las reglas citadas y
  las variantes están en el docstring del módulo `src/RevelacionV1.jl` y en
  `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`.
- **Ejecución:**
  ```bash
  export JULIA_DEPOT_PATH="/tmp/dsh-julia-depot:$HOME/.julia"
  J=/home/katana/torio/.juliaup/bin/julia
  $J --project=. --threads=16,0 run.jl --modo todo      # 81 s, salidas en resultados/
  JULIA_NUM_THREADS=4 $J --project=. --threads=4,0 test/runtests.jl   # 143/143
  JULIA_NUM_THREADS=16 $J --project=. --threads=16,0 bench/benchmarks.jl 64
  ```
- **Semilla maestra:** `0x5a5a`; derivación por réplica `StableRNG(semilla + id)`.
- **Estado:** conclusivo en el alcance declarado; lo no resuelto, en `INFORME.md` §6 y en
  `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`.

## Resultados publicados

| Fichero | Contenido |
|---|---|
| `resultados/CONTROLES.txt` | C1, C2, C3, `ρ*`, `Lrev`, rachas |
| `resultados/ADL.txt` | `A_frontera` de ADL-v1.0 frente a `V_max`, fila a fila |
| `resultados/F1.txt` | sin (h): `V_max`, `V_min`, `A_core`, ronda 7, ADL, *bootstrap* |
| `resultados/F2.txt` | con (h): `V`, `+D`, distribución con rachas, `ρ*` |
| `resultados/F3.txt` | `C-FLU-01` con `I` recalibrado por (h.6) |
| `resultados/F4.txt` | cotas de edad `M` y sellado como cuantiles |
| `resultados/F5.txt` | coste para el honesto (líneas, núcleos, puntualidad) |
| `resultados/TESTS.txt` | 143/143 |
| `resultados/BENCH-h{1,2,4,8,16}.txt` | escalado con *checksum* determinista |
| `resultados/OPTIMIZACION.txt` | 2,58× por el perfil (`con_hist = false`) |
| `resultados/PERFIL.txt`, `WARNTYPE.txt`, `JET.txt` | perfil y diagnósticos |
| `resultados/ENTORNO.txt`, `TIEMPOS.txt` | entorno y tiempos de pared |
