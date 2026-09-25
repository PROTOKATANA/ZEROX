# RESUMEN FINAL — T02 (≤ 40 líneas)

**Veredicto:** la pregunta falsable se **REFUTA dentro del modelo**. Con `FC-3` y `a<1/2`, un
adversario con `h` alta sí consigue que un nodo en línea abandone la historia honesta.

**Puntos que la refutan (seed `0x5a5a`, 10⁵ réplicas, IC 99,9 %):**
- `h=0,9, a=0,4, k=6, r=0,1, p=0,9, F_slots=1000`: éxito nodo nuevo **0,99982** [0,99962; 0,99992];
  nodo en línea **0,99982**. Mecanismo: el terminal adversario existe antes (`t_A≤t_H`), el empate
  `W_A=W_H=0` favorece al adversario y `d=0`, luego `C-FIN-01` no protege.
- `h=0,6, a=0,4`: 0,770; `h=0,5, a=0,4`: 0,520. En total **32/35** puntos de E2 con `a<1/2`
  superan `10⁻³`.

**Controles y otros escenarios:**
- **E1:** fórmula vs tabla publicada de Nakamoto §11, error máximo `4,83·10⁻⁸` (<10⁻⁶);
  simulador 24/24 dentro del IC 99,9 %.
- **E3:** `FC-1` gana siempre para el nodo nuevo (coste `k(1+δ)=1,01…13,2`); `FC-3` máximo
  **0,8647** (con `a=0,45<1/2`, 0,8394, slots largos); `FC-3` peor que `FC-1` en línea en
  6832/6912 puntos.
- **E4:** retraso finito salvo `h=0,9` con `M_dep=6` (81 % censurado) y `M_dep=12` (99,98 %);
  `h=0,9, M_dep=3`: retraso medio 1097,7 `T_pow` y 92,4 % de emisión capturada.

**Inconcluso por presupuesto:** producto cartesiano completo de E2 (se corrió una sensibilidad de
35 puntos). **Discrepancia declarada:** para `h>1/2` la corrección esperaba censura ~1 en E4; con la
estrategia literal el retraso es finito y solo censura a `h=0,9, M_dep≥6` (cota: `(1−h)^{−(M_dep+1)}`).

**Comprobación de entrada:** `ENTRADA-T02.sha256` y `ENTRADA-T02-A.sha256` → `OK` en los 4 ficheros
al empezar y al terminar (salidas en `PROGRESO.md`).

**Archivos:** `Project.toml`, `Manifest.toml`, `julia-version.toml`, `src/*.jl`, `test/runtests.jl`,
`run.jl`, `resultados/*.csv` (+`resumen.csv`, `test.log`, `run.log`), `INFORME.md`, `METODO.md`,
`MODELO.md`, `HIPOTESIS-QUE-CODIFICAN-LA-CONCLUSION.md`, `PROGRESO.md`, `HORAS.log`.

**Comandos:**
    export JULIA_DEPOT_PATH=$PWD/.julia-depot:
    env -u LD_LIBRARY_PATH JULIA_NUM_THREADS=1 $JULIA --project=. -e 'using Pkg; Pkg.instantiate(); Pkg.test()'
    env -u LD_LIBRARY_PATH JULIA_NUM_THREADS=4 OPENBLAS_NUM_THREADS=1 $JULIA --project=. --threads=4,0 run.jl --seed 0x5a5a --replicas 100000 --escenario todos

**Tests:** 69/69. **Coste:** 10,7 s y 457 MiB (presupuesto 2 h / 4 hilos / 16 GiB).
