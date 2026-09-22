# CRP-v0.3 · Método

## 1 · Algoritmos

| Componente | Algoritmo | Artefacto |
|---|---|---|
| `P_first_passage` | DP con absorción en `z≤−1`, soporte `lo=−1` | `dp.jl`, `eventos.jl` |
| `P_terminal` | DP **sin** absorción; masa en `z≤−1` al final | `eventos.jl` |
| `P_eventual` | forma cerrada `(q/p)^(z0+1)` | `eventos.jl` |
| `α_prob` simultáneo | Clopper–Pearson con Bonferroni `γ/m` | `eventos.jl` |
| RCE rev2 | entero `BigInt` + agenda | `controlador_rce.jl` |
| Flujo/R-FIN-5 | prefijo por slot sobre todo `past(B)` | `flujo.jl` |
| DAG | GDR-v0.2 + eventos por slot + observadores | `dag_sim.jl` |

## 2 · Error numérico

Igual que v0.2: masa cruda, cotas `[P_L,P_U]` por fuga acumulada, sin renormalizar. Para
`P_terminal` la cota es `[p, p+fuga]`. Conservación comprobada en los tests.

## 3 · Validación

- Tres eventos ordenados `terminal ≤ paso ≤ eventual`.
- MC de terminal coincide en orden con la DP.
- `α_prob` simultáneo: celda `0/n` ⇒ `:solo_cota_superior`, nunca frontera.
- Autor-inmediato y `Δ=0`; único productor sin rojos (Δ∈{0,1,5}).
- Controles de correlación: perfecta ⇒ ramas idénticas; iid ⇒ identidad `1−E[F^S]`.
- R-FIN-5: prefijo compatible antes de la divergencia, incompatible después; fusión
  público+rama rechazada por R-FIN-5.
- U2 dentro de rama rechaza; U3″ entre ramas disjuntas colorea una copia.
- η en `[0,1]`.

## 4 · Comandos

```bash
env -u LD_LIBRARY_PATH julia --check-bounds=yes --project=. test/runtests.jl
env -u LD_LIBRARY_PATH julia --project=. run.jl --seed 0x5a5a --replicas 24
env -u LD_LIBRARY_PATH julia --project=. bench/benchmarks.jl
env -u LD_LIBRARY_PATH julia --project=. bench/io_lectura.jl
```

## 5 · Presupuesto

Máximo 64 GiB RAM, 24 hilos. Sin benchmarks destructivos. `S_adversario` pendiente.
