# MÉTODO — ANCLA-v0.2 (comandos reproducibles desde la raíz del repo)

Entorno: `veritas/julia.sh` (fija juliaup y limpia LD_LIBRARY_PATH), Julia 1.13.0 (fijada en
`julia-version.toml`), Ryzen 9 9950X3D, 24 hilos de cómputo (`--threads=24`,
`JULIA_NUM_THREADS=24`), `OPENBLAS_NUM_THREADS=1` (sin BLAS en el camino caliente).

```bash
# 1. Suite de validación (obligatoria antes de usar resultados)
JULIA_NUM_THREADS=1 ./veritas/julia.sh --project=P-2.1/veritas/consenso/ancla-inyeccion-v2 \
  --check-bounds=yes P-2.1/veritas/consenso/ancla-inyeccion-v2/test/runtests.jl

# 2. Puerta 4.0 (analítica)
./veritas/julia.sh --project=P-2.1/veritas/consenso/ancla-inyeccion-v2 \
  P-2.1/veritas/consenso/ancla-inyeccion-v2/run.jl puerta

# 3. Celdas 4.A (semilla maestra 0x5A5A; checkpoint por chunk, resume con --offset)
#    honestas: hon-dms | hon-4 | hon-10L | hon-16L (ventana 2000)
#    adversario: v1-a{10,25,33,40,45} | a3-{...} | v2-a{25,40} | v3-a40
JULIA_NUM_THREADS=24 OPENBLAS_NUM_THREADS=1 \
  ./veritas/julia.sh --project=P-2.1/veritas/consenso/ancla-inyeccion-v2 --threads=24 \
  P-2.1/veritas/consenso/ancla-inyeccion-v2/run.jl 4a --celda hon-10L --replicas 2000 --chunk 100

# 4. Controles positivos
for a in 0.0 0.10 0.25 0.33 0.40; do
  JULIA_NUM_THREADS=24 ./veritas/julia.sh --project=P-2.1/veritas/consenso/ancla-inyeccion-v2 \
    --threads=24 P-2.1/veritas/consenso/ancla-inyeccion-v2/run.jl ctrl9c --alpha $a --smax 150 --semillas 12
done
for a in 0.0 0.25 0.40; do
  JULIA_NUM_THREADS=24 ./veritas/julia.sh --project=P-2.1/veritas/consenso/ancla-inyeccion-v2 \
    --threads=24 P-2.1/veritas/consenso/ancla-inyeccion-v2/run.jl ctrl11c --alpha $a --semillas 12
done

# 5. Benchmark de escalado
./veritas/julia.sh --project=P-2.1/veritas/consenso/ancla-inyeccion-v2 \
  P-2.1/veritas/consenso/ancla-inyeccion-v2/bench/benchmarks.jl
```

Salidas: `P-2.1/veritas/consenso/ancla-inyeccion-v2/resultados/` — por celda: `w.csv` (por
réplica: W_obs, W_def, W_par, W_vacío), `g.csv` (G(d) con IC bootstrap de clúster),
`resumen.csv` (L_mín y ajuste). `resultados/puerta/`, `resultados/ctrl9c/`, `resultados/ctrl11c/`.

Semilla maestra: `0x5A5A`; RNG por réplica `StableRNG(semilla ⊻ id·0x9E3779B97F4A7C15)`;
shuffle de candidatos determinista por (réplica, slot, creador). GDR-v0.2 se incluye SIN
MODIFICAR desde `veritas/consenso/ghostdag-rank-v1/src/GhostdagRank.jl`.
