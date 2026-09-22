# CRP-v0.3 · Progreso

## 2026-09-18 — correcciones del encargo v0.3

| # | Corrección | Dónde | Verificación |
|---|---|---|---|
| 1 | `P_terminal` / `P_first_passage` / `P_eventual` separados; `α_prob` por evento | `src/eventos.jl` | tests de orden + `EVENTOS.txt` |
| 2 | `DescriptorFlujo`/`PotOrigin`/`N(s)` por bloque; R-FIN-5 sobre todo `past(B)` | `src/flujo.jl`, `src/dag_sim.jl` | `_anadir_bloque!`, tests |
| 3 | Presentación, validación, fusión y decisión del observador | `src/dag_sim.jl` (`Decision`) | `SWEEP-DAG.txt`, tests |
| 4 | `S` flujos desde oportunidades compartidas (perfecta/iid/derivada) | `oportunidades_compartidas` | `CORRELACION.txt`, tests |
| 5 | Autor-inmediato, `Δ=0` real, drenaje terminal simétrico | `dag_sim.jl` | tests |
| 6 | Único productor sin rojos por latencia | `dag_sim.jl` | test Δ∈{0,1,5} |
| 7 | Déficits en `blue_work`; semilla independiente de `d` | `run.jl` | `SWEEP-DAG.txt` |
| 8 | Barrido `S={1,2,4,8,16,24}`, `T/d/Δ/k`, `α` a ambos lados | `run.jl` | `SWEEP-DAG.txt`, `VARIOS.txt` |
| 9 | Intervalos `α_prob` con cobertura simultánea; 0/n no es frontera | `alpha_prob_simultaneo` | tests + `SWEEP-DAG.txt` |
| 10 | `η_h` y `η_a` separados; rojos inconclusos | `dag_sim.jl`, `ETA.txt` | `ETA.txt` |
| 11 | Fixtures U2/U3 y fusión compatible/incompatible | `flujo.jl` | tests + `U2U3.txt` |
| 12 | Repetición de las tres revisiones | `REVISION-MATEMATICA/RUST/JULIA.md` | hechas; defectos corregidos en `REVISION-RESPUESTA.md` |

## Hallazgo central

- Aditivo (contrafactual): la frontera media sigue `1/(S+1)`.
- R-FIN-5 (máximo de ramas): no suma; con `α<1/2` la rama individual no supera a la pública.
- La fusión público+rama con prefijos divergentes es **rechazada por R-FIN-5 antes de colorear**.

## Blancos honestos

Controlador del SPEC (ventana), PoT AES, C-GD-11, finalidad `F`/`Δ`, `S_adversario`, y
curva de rojos asimétricos (0 rojos observados a k=30 ⇒ inconclusa). No se rellenan.
