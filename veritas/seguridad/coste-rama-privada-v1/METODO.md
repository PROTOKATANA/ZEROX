# METODO — CRP-v0.1

## Entorno

- Julia 1.13.0 (fijado en `Manifest.toml`).
- Envoltorio obligatorio (LD_LIBRARY_PATH puede segar Julia): `veritas/julia.sh`.
- Proyecto aislado y recortado: `Project.toml` con **9** dependencias/stdlib usadas
  (`BenchmarkTools`, `StableRNGs`, `Dates`, `InteractiveUtils`, `Pkg`, `Printf`, `Profile`,
  `Random`, `Test`). No se usa Python.
- Oráculo GHOSTDAG: **GDR-v0.2**, `veritas/consenso/ghostdag-rank-v1/src/GhostdagRank.jl`, cargado
  por `incluir_ghostdag()` (se reutiliza; no se reimplementa).

## Comandos exactos

```bash
# desde la raíz del repositorio
cd veritas/seguridad/coste-rama-privada-v1

# suite (perfil de referencia, un hilo, con comprobación de límites)
/home/katana/zeo/ZEROX/veritas/julia.sh --project=. --threads=1 --check-bounds=yes test/runtests.jl

# resultados por modo (semilla por defecto 0xC057E07)
/home/katana/zeo/ZEROX/veritas/julia.sh --project=. --threads=8 run.jl --entorno      --out ENTORNO.txt
/home/katana/zeo/ZEROX/veritas/julia.sh --project=. --threads=8 run.jl --fuentes
/home/katana/zeo/ZEROX/veritas/julia.sh --project=. --threads=8 run.jl --teoria       --out run-teoria.txt
/home/katana/zeo/ZEROX/veritas/julia.sh --project=. --threads=8 run.jl --corto        --out run-corto.txt
/home/katana/zeo/ZEROX/veritas/julia.sh --project=. --threads=8 run.jl --controladores --out run-controladores.txt
/home/katana/zeo/ZEROX/veritas/julia.sh --project=. --threads=8 run.jl --referencias  --out run-referencias.txt
/home/katana/zeo/ZEROX/veritas/julia.sh --project=. --threads=8 run.jl --gdr          --out run-gdr.txt
/home/katana/zeo/ZEROX/veritas/julia.sh --project=. --threads=8 run.jl --resumen      --out run-resumen.txt

# benchmark y escalado
/home/katana/zeo/ZEROX/veritas/julia.sh --project=. --threads=8 bench/benchmarks.jl > resultados/BENCH.txt
for n in 1 2 4 8 16 24; do
  /home/katana/zeo/ZEROX/veritas/julia.sh --project=. --threads=$n bench/escalado.jl
done > resultados/ESCALADO.txt
```

Comando de la corrida publicada (perfil que gana en tiempo): `--threads=24`. La reproducibilidad de
los contadores es independiente del número de hilos (resultado idéntico en `ESCALADO.txt`).

## Semilla

`0xC057E07` (por defecto en `run.jl`). Las semillas por réplica se derivan del índice de réplica
(`StableRNG(semilla + 0x9E3779B9·i + r)`), no de `threadid()`; la reducción es entera y ordenada.

## Artefactos

Cada `resultados/run-*.txt` lleva cabecera de entorno (git, fecha, Julia, CPU, hilos, semilla,
`Pkg.status`). `resultados/` no es fuente de verdad: la verdad son las comprobaciones reproducibles.
