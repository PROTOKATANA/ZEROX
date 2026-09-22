# CRP-v0.2 · Método

## 1 · Algoritmos y complejidad

| Componente | Algoritmo | Complejidad | Artefacto |
|---|---|---|---|
| Referencia ±1 eventual | forma cerrada `(q/p)^d`, `(q/p)^(d+1)` | `O(1)` | `referencia.jl` |
| Referencia exacta finita | DP `Rational{BigInt}` sobre `Dict{Int}` | `O(T·ancho)` | `referencia.jl` |
| DP acotada | vector sobre `[lo,hi]`, absorbida/fuga/interior | `O(T·ancho)` | `dp.jl` |
| DP adaptativa | duplica semianchura hasta fuga ≤ tol | `O(T·ancho_final)` | `dp.jl` |
| RCE rev2 | aritmética `BigInt` + agenda ordenada | `O(propuestas log)` | `controlador_rce.jl` |
| DAG | GDR-v0.2 + simulación por slots | `O(bloques · mergeset)` | `dag_sim.jl` |
| MC | por réplica, RNG por semilla | `O(reps · T)` | `validacion.jl` |

## 2 · Error numérico (encargo D2)

- La **masa cruda** se publica antes de cualquier operación. **Nunca** se renormaliza.
- Se separan `masa_kernel` (interior), `masa_exito` (absorbida) y `masa_fuga` (frontera).
- Cota por todo el horizonte: la probabilidad verdadera satisface
  `[p_exito, p_exito + fuga_acumulada]`. La cola por paso no acredita el error final.
- `error total ≤ 10⁻¹²` solo se exige cuando la probabilidad está **por encima** de la cota
  numérica; por debajo se publica únicamente una cota.
- La conservación se comprueba en cada corrida (`conserva`, tolerancia declarada). En
  `resultados/CORTO.txt` el diagnóstico es ≤ `1.2e-14`.
- Para horizonte infinito, el error de truncación se demuestra **aparte** mediante la forma cerrada;
  el DP solo se usa en horizonte finito con soporte adaptativo.
- La aritmética de consenso es entera (`BigInt`/`UInt64` en el peso); **sin `@fastmath`**.

## 3 · Separación empate / superación

Dos DPs separadas: absorción en `z=0` (empate) y en `z≤−1` (superación estricta). Con saltos
compuestos que puedan saltar sobre 0, no se deriva una de la otra. `d=0`: el empate incluye
`n=0`; superar exige un evento posterior. Se fija el orden de sucesos simultáneos por índice de
creación.

## 4 · Validación

1. Referencia exacta vs DP en `n` pequeño y vs MC con IC.
2. Conservación de masa y validez de las cotas `[P_L,P_U]`.
3. Unidad: `d` de trabajo y `d·g` de retícula dan la misma probabilidad.
4. Fixtures de color deterministas (rojo_k y cero rojos).
5. Mutación: el test detecta `>` vs `≥` y máximo vs suma.
6. Escenario estadístico calibrado que **no falla** por observar cero rojos a baja carga.

## 5 · Presupuesto declarado

Máximo 64 GiB de RAM, 24 hilos, disco temporal acotado (el dataset I/O vive en `/tmp/opencode`,
64 MiB). Si se agota: checkpoint e **inconcluso**. Ningún timeout es evidencia de seguridad.

## 6 · Comandos reproducibles

```bash
# desde deepseek/veritas/seguridad/coste-rama-privada-v2/
env -u LD_LIBRARY_PATH julia --check-bounds=yes --project=. test/runtests.jl
env -u LD_LIBRARY_PATH julia --project=. run.jl --seed 0x5a5a --replicas 64
env -u LD_LIBRARY_PATH julia --project=. bench/benchmarks.jl
env -u LD_LIBRARY_PATH julia --project=. bench/io_lectura.jl
```

Julia 1.13.0; `Manifest.toml` versionado. Semilla 0x5a5a.

## 7 · Benchmarks (formato LINEO §6)

Ver `resultados/BENCH.txt`. Los benchmarks de I/O (`resultados/IO.txt`) son de solo lectura y de
**page cache caliente**; no se usó `drop_caches` ni se distinguió page cache de almacenamiento.
Por eso `S_adversario` queda **Pendiente**: no se fabrica una capacidad a partir de `100k IOPS`.
