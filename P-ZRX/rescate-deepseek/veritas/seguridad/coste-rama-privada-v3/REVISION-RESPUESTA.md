# CRP-v0.3 · Respuesta a las revisiones (contexto independiente)

Los dictámenes `REVISION-MATEMATICA.md`, `REVISION-RUST.md` y `REVISION-JULIA.md` se
escribieron sobre el estado previo a esta respuesta. Se registran los defectos y su
corrección; los dictámenes originales no se reescriben.

| Hallazgo | Revisor | Corrección | Verificación |
|---|---|---|---|
| H1 aditivo contaba el prefijo común S veces | matemática | `W_pub` y `W_priv` ahora son **post-fork** respecto de `raiz_comun` | `SWEEP-DAG.txt`: S=4 α=0.20 17/24→13/24 |
| H2 `alpha_prob_simultaneo` concluía al revés con 0/n | matemática | tipos `:solo_inferior` / `:solo_superior` / `:indefinida`; nunca cruce sin celdas decisivas | test + `SWEEP-DAG.txt` |
| H3 se mezclaban S en un `alpha_prob` | matemática | `alpha_prob` por S | `SWEEP-DAG.txt` |
| H4/H5 “R-FIN-5 ~0 para α<1/2” sobre-enunciado; rejilla gruesa | matemática, Julia | texto corregido; no se llama frontera a 0/24 | `INFORME.md` §6 |
| H6 atajo por `flujo_id` relajaba R-FIN-5 | matemática, Rust | atajo reemplazado por identidad de objeto **y** autenticación mutua | `src/flujo.jl`, tests |
| H7 `η_a=1.0` tautológico | matemática | declarado inconcluso sin rojos | `ETA.txt`, `INFORME` §8 |
| H8 test del punto 7 no tocaba el simulador | matemática | la semilla no depende de `d` en `run.jl`; se conserva test escalar | `run.jl` |
| H1 `s_max=150` trunca ramas a α bajo sin registrarlo | Julia | contador `rechazos[:gdr]` expuesto (`rgdr`); celdas marcadas inconclusas | `SWEEP-DAG.txt` |
| H3 horizonte de justificación era código muerto | Julia | `horizonte_justificacion_ok` se aplica en `_anadir_bloque!` | `src/flujo.jl`, `dag_sim.jl` |
| H1 `C-NET-31/32` citadas como §2.7 | Rust | corregido a `SPEC §16` | `MATRIZ-AUTORIDAD.md` |
| H2 matriz idéntica a v0.2 pese a declarar correcciones | Rust | cabecera y filas corregidas en v3 | `MATRIZ-AUTORIDAD.md` |
| H3 `R-FIN-13′` como candidata | Rust | reclasificada `SPEC vigente (acoplamiento)` | `MATRIZ-AUTORIDAD.md` |
| H4 atajo semántico R-FIN-5 | Rust | ver fila H6 de matemática | `src/flujo.jl` |
| H5 “autenticado” no es cripto | Rust | aviso explícito en `INFORME.md` §2 y `CONTRATO.md` | — |
| H6 escenario 3 `Válida` con C-GD-11 ausente | Rust | reclasificado `Pendiente por C-GD-11` | `MATRIZ-VALIDEZ.md` |

## Límites conservados (no se corrigen, se declaran)

- **Rejilla y réplicas:** con `24` réplicas y rejilla `0.05`, una celda `0/24` solo acota
  `P≲0.25` simultáneo; **no** se publica como frontera.
- **`η_a=1.0`** con 0 rojos: la curva con rojos queda **inconclusa**.
- **`drenaje terminal`**: implementado y ejercitado por la construcción (Δ=0 y final), sin
  efecto observable separado en la métrica plana; declarado.
- **`s_max`**: las celdas con `rgdr>0` son inconclusas, no evidencia.
- **Posible `BoundsError`/rendimiento:** el simulador es serial; no se optimizó.
- **Revisión criptográfica PoT real:** fuera de alcance; el descriptor es estructural.
