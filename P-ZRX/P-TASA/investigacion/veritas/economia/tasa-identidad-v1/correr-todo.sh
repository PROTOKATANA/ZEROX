#!/usr/bin/env bash
# P-TASA · tasa-identidad-v1 · reproducción completa.
# Presupuesto declarado (PROMPT §8.11, LINEO §7): 4 hilos, 4 GiB de RAM,
# 256 MiB de disco de artefactos (el depósito de Julia se declara aparte),
# minutos por tarea y techo de 2 h de pared para el conjunto.
# Uso:  ./correr-todo.sh          (desde este directorio)
set -euo pipefail
cd "$(dirname "$0")"

export JULIA_DEPOT_PATH="${JULIA_DEPOT_PATH:-/home/katana/zeo/ZEROX/P-ZRX/P-TASA/.julia-depot:/home/katana/.julia}"
J=/home/katana/zeo/ZEROX/veritas/julia.sh
SEMILLA="${SEMILLA:-0x54415341}"      # "TASA"

echo "== uptime antes de empezar =="; uptime
echo "== reloj =="; date

echo "== 1/4 · perfil de referencia (1 hilo, límites activos) =="
JULIA_NUM_THREADS=1 OPENBLAS_NUM_THREADS=1 \
  "$J" --project=. --check-bounds=yes test/runtests.jl | tee resultados/TEST.log

echo "== 2/4 · artefactos (F1..F6, V1..V3) =="
JULIA_NUM_THREADS=4 OPENBLAS_NUM_THREADS=1 \
  "$J" --project=. run.jl --seed "$SEMILLA" | tee resultados/CORRIDA.log

echo "== 3/4 · benchmarks =="
JULIA_NUM_THREADS=4 OPENBLAS_NUM_THREADS=1 \
  "$J" --project=. bench/benchmarks.jl | tee resultados/BENCH.txt

echo "== 4/4 · escalado del MC (1, 2, 4 hilos) =="
rm -f resultados/ESCALADO-raw.tsv
for h in 1 2 4; do
  JULIA_NUM_THREADS="$h" OPENBLAS_NUM_THREADS=1 \
    "$J" --project=. bench/escalado.jl "$h" | tee -a resultados/ESCALADO.log
done
{
  printf 'hilos\ttiempo_s\tmedia\tdesv\tidentico_a_serial\n'
  cat resultados/ESCALADO-raw.tsv
} > resultados/ESCALADO.tsv

echo "== uptime al terminar =="; uptime
echo "== reloj al terminar =="; date
