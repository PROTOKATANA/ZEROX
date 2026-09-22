# METODO — PPP-v0.1

Todos los comandos se ejecutan desde la raíz del repositorio (`/home/katana/zeo/ZEROX`), usando
siempre `veritas/julia.sh` (fija `juliaup` y quita `LD_LIBRARY_PATH`, LINEO §1) y
`--project=veritas/consenso/poda-post-v1`.

Entorno de la corrida publicada: **julia 1.13.0**, `znver5`, 32 hilos lógicos / 123,4 GB RAM.
Tests y fórmulas exactas: 1 hilo. Monte Carlo y escalado: hasta 24 hilos.

**Dependencias recortadas al migrar** (Claude, 2026-09-17, `PROCEDENCIA.md` §2). El ejecutor
entregó el `Project.toml` de `veritas/plantilla/` sin recortar: 28 dependencias declaradas de las
que el instrumento usa **dos** (`BenchmarkTools`, `StableRNGs`) más stdlib. El proyecto migrado
declara solo esas, con las mismas versiones, y `Manifest.toml` baja de 54 845 a 8 118 bytes. Toda
la suite y los ocho `resultados/run-*.txt` se reejecutaron tras el recorte: **85/85** y contenido
sustantivo **idéntico**.

## Suite de tests

```bash
veritas/julia.sh --check-bounds=yes \
  --project=veritas/consenso/poda-post-v1 \
  veritas/consenso/poda-post-v1/test/runtests.jl
```

## Modos de `run.jl`

```bash
PPP=veritas/consenso/poda-post-v1

# cabecera de entorno (git HEAD, fecha, VERSION, hilos, CPU, Pkg.status)
veritas/julia.sh --project=$PPP $PPP/run.jl --entorno

# D1/D2: niveles exactos vs hipótesis; D6: multiplicidad de chunks
veritas/julia.sh --project=$PPP $PPP/run.jl --niveles --out run-niveles.txt
veritas/julia.sh --project=$PPP $PPP/run.jl --multiples --out run-multiples.txt

# D3: anclaje de SR (bloque vs referencia)
veritas/julia.sh --project=$PPP $PPP/run.jl --sranclaje --out run-sranclaje.txt

# D9: crecimiento sin poda
veritas/julia.sh --project=$PPP $PPP/run.jl --cabeceras --out run-cabeceras.txt

# D4/D5: exhaustiva vs fórmula, independencia de padres, coste de molienda
veritas/julia.sh --project=$PPP $PPP/run.jl --anclaje --seed 0x5A5A --out run-anclaje.txt

# D7: retención
veritas/julia.sh --project=$PPP $PPP/run.jl --retencion --out run-retencion.txt

# D8: rama privada con certificado de niveles
veritas/julia.sh --project=$PPP $PPP/run.jl --certificado --out run-certificado.txt

# D9: blue_work no se recomputa (reutiliza GDR-v0.2)
veritas/julia.sh --project=$PPP $PPP/run.jl --bluework --out run-bluework.txt

# Monte Carlo con 24 hilos (validación del kernel)
JULIA_NUM_THREADS=24 OPENBLAS_NUM_THREADS=1 veritas/julia.sh --threads=24,0 \
  --project=$PPP $PPP/run.jl --mc --seed 0xC0FFEE --out run-mc.txt

# todo junto
veritas/julia.sh --project=$PPP $PPP/run.jl --resumen --seed 0x5A5A --out run-resumen.txt
```

## Benchmarks y escalado

```bash
# microbench del kernel (1 hilo)
veritas/julia.sh --project=$PPP $PPP/bench/benchmarks.jl

# escalado: repetir con --threads=N,0 para N ∈ {1,2,4,8,16,24}
for n in 1 2 4 8 16 24; do
  JULIA_NUM_THREADS=$n OPENBLAS_NUM_THREADS=1 veritas/julia.sh --threads=$n,0 \
    --project=$PPP $PPP/bench/escalado.jl
done
```

Resultados en `resultados/BENCH.txt`: microbench sin asignaciones (0 B) y escalado 1→24 hilos de
5,24·10⁷ a 9,61·10⁸ sorteos/s (×18,3; sublineal en 16–24 por hyperthreading, como LINEO espera).

## Reutilización de GDR-v0.2

`--bluework` carga `veritas/consenso/ghostdag-rank-v1/src/GhostdagRank.jl` (oráculo ya auditado)
subiendo por los ancestros del directorio; no reimplementa GHOSTDAG. Migrado el instrumento,
`poda-post-v1/` y `ghostdag-rank-v1/` son hermanos y la carga resuelve al oráculo del repositorio.

## Reproducir una cifra suelta

Cada archivo de `resultados/` generado por `run.jl` lleva cabecera con hash Git, fecha, `julia`,
CPU, hilos, comando y semilla. `resultados/BENCH.txt` lleva fecha y hash al inicio.
