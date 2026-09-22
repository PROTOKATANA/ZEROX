# CRP-v0.3 · Matriz de validez

| # | Escenario | Reglas | Observador | Clasificación |
|---|---|---|---|---|
| 1 | Baseline ±1 (terminal/paso/eventual) | aritmética + DP | — | **demostrado** |
| 2 | SPEC actualmente escrito | C-HDR-06 pendiente | veterano/nuevo | **Pendiente** (ventana) |
| 3 | DAG con red (GDR-v0.2, R-FIN-5 estructural) | C-GD-01…09, C-ORD-01…03, R-FIN-5; **C-GD-11 ausente** | nuevo | **Pendiente por C-GD-11 y PoT no criptográfico** (la estructura de color es válida, la validez de fusión no está cerrada) |
| 4 | Escenario candidato R-FIN-5 (máximo de ramas) | R-FIN-5 | nuevo/veterano | **Válida estructural** |
| 5 | Contrafactual aditivo | suma | — | **Contrafactual, no regla** |
| 6 | Observador veterano | R-FIN-7/`F` | veterano | **Pendiente** (`F` provisional) |
| 7 | Observador eclipsado | — | eclipsado | **Pendiente** |
| 8 | Sync sucinto | — | nuevo | **Pendiente** |
| 9 | RCE/ARM | contrato RCE rev2 | — | **instrumento / Pendiente consenso** |

## Trazas

| Traza | Resultado | Estado |
|---|---|---|
| `P_terminal ≤ P_paso ≤ P_eventual` | orden verificado | demostrado (test) |
| `α_prob` por evento (d=4,T=100) | terminal 0.443; paso 0.355; eventual 0.355 | derivado |
| Celda 0/n en `α_prob` | `:solo_cota_superior` | demostrado (test) |
| R-FIN-5 prefijo en `slot(X)` | compatible ≤ fork, incompatible > | demostrado |
| Fusión público+rama divergente | `:rechazada_rfin5` | medido |
| Único productor, Δ∈{0,1,5} | 0 rojos | medido (test) |
| Δ=0, 8 productores, k=2 | rojos > 0 | medido |
| Correlación perfecta S=4 | ramas idénticas | medido |
| iid S=3 | identidad `1−E[F^S]` vs MC | medido (test) |
| Aditivo S=4 | cruce entre α=0.15 y 0.20 (≈1/5) | medido |
| η_h, η_a | η_h≈0.99, η_a=1.0; **0 rojos** | curva con rojos **inconclusa** |
| U2 misma rama | `:u2` | medido (test) |
| U3″ ramas disjuntas | una `rojo_U3` | medido (test) |
