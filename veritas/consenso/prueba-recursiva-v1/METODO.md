# METODO — PRV-v0.1

Todos los comandos desde la raíz del repositorio (`/home/katana/zeo/ZEROX`), con `veritas/julia.sh`
y `--project=veritas/consenso/prueba-recursiva-v1`. Entorno publicado: **julia 1.13.0**,
`znver5`, 32 hilos lógicos / 123,4 GB RAM; tests y conteo a 1 hilo; escalado hasta 24.
`Manifest.toml` propio (9 dependencias).

## Suite

```bash
veritas/julia.sh --check-bounds=yes \
  --project=veritas/consenso/prueba-recursiva-v1 \
  veritas/consenso/prueba-recursiva-v1/test/runtests.jl
```

## Modos de `run.jl`

```bash
PPP=veritas/consenso/prueba-recursiva-v1

veritas/julia.sh --project=$PPP $PPP/run.jl --entorno
veritas/julia.sh --project=$PPP $PPP/run.jl --seleccion  --seed 0x5E1EC7 --out run-seleccion.txt
veritas/julia.sh --project=$PPP $PPP/run.jl --coste --n 512 --W 1000 --out run-coste.txt
veritas/julia.sh --project=$PPP $PPP/run.jl --barrido --n 512          --out run-barrido.txt
veritas/julia.sh --project=$PPP $PPP/run.jl --lineal --n 512 --W 1000  --out run-lineal.txt
veritas/julia.sh --project=$PPP $PPP/run.jl --orchard                  --out run-orchard.txt
veritas/julia.sh --project=$PPP $PPP/run.jl --fuentes                  --out run-fuentes.txt
veritas/julia.sh --project=$PPP $PPP/run.jl --resumen --n 512 --W 1000 --seed 0x5E1EC7 \
  --out run-resumen.txt
```

## Benchmarks

```bash
veritas/julia.sh --project=$PPP $PPP/bench/benchmarks.jl

for n in 1 2 4 8 16 24; do
  JULIA_NUM_THREADS=$n OPENBLAS_NUM_THREADS=1 veritas/julia.sh --threads=$n,0 \
    --project=$PPP $PPP/bench/escalado.jl
done
```

Resultados en `resultados/BENCH.txt`.

## Oráculo

GDR-v0.2 se localiza subiendo por los ancestros (`ruta_gdr`), así que funciona igual en `deepseek/`
que tras migrar, donde `prueba-recursiva-v1/` y `ghostdag-rank-v1/` son hermanos bajo
`veritas/consenso/`. No se reimplementa GHOSTDAG.
