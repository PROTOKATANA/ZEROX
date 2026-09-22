#!/usr/bin/env bash
# Retención por clave · reproducción completa. Presupuesto declarado: 8 hilos, 8 GiB, 512 MiB.
# Uso:  ./correr-todo.sh          (desde este directorio)
set -euo pipefail
cd "$(dirname "$0")"
export JULIA_DEPOT_PATH="$PWD/../../../../.julia-depot:/home/katana/.julia"
J=/home/katana/zeo/ZEROX/veritas/julia.sh
SEMILLA="${SEMILLA:-0x434c415645}"       # "CLAVE"

echo "== uptime antes de empezar =="; uptime

echo "== 1/3 · perfil de referencia (1 hilo, límites activos) =="
JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 \
  "$J" --project=. --check-bounds=yes test/runtests.jl | tee resultados/TEST.log

echo "== 2/3 · artefactos (F1..F6, V1..V4) =="
JULIA_NUM_THREADS=8 OPENBLAS_NUM_THREADS=1 \
  "$J" --project=. run.jl --seed "$SEMILLA" \
    --tarea f1 --tarea f1b --tarea f2 --tarea f2b --tarea f2c --tarea f3 \
    --tarea f4 --tarea f5 --tarea f6 \
    --tarea v1 --tarea v2 --tarea v3 --tarea v4 | tee resultados/CORRIDA.log

echo "== 3/3 · benchmarks =="
JULIA_NUM_THREADS=4 OPENBLAS_NUM_THREADS=1 \
  "$J" --project=. bench/benchmarks.jl | tee resultados/BENCH.txt

echo "== uptime al terminar =="; uptime
