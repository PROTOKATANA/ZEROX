#!/usr/bin/env bash
# Barrido F2 declarado. TODAS las celdas con DP EXACTA (una versión anterior publicaba
# (1−q_adv)^F como si fuera la probabilidad de la celda: no era una cota; PROGRESO.md O6).
# Rejilla acotada por presupuesto de cómputo a la región que decide: el cruce de deriva está
# en β_d = (1−2α)/(1−α).
#   F = 1.019 : β_d rel. ∈ {0, 0.20, 0.34, 0.40, 0.45, 0.50, 0.55, 0.60, 0.70, 0.80, 0.90, 1.0}
#   F = 3.600 : β_d rel. ∈ {0, 0.34, 0.45, 0.50, 0.55, 0.70, 1.0}
# F son símbolos con valores de ejemplo (PROMPT §3 F2). Presupuesto: ≤ 6 hilos, minutos por corrida.
set -euo pipefail
cd "$(dirname "$0")"
export JULIA_DEPOT_PATH="$PWD/../../../.julia-depot:/home/katana/.julia"
export JULIA_NUM_THREADS=6 OPENBLAS_NUM_THREADS=1
J=/home/katana/zeo/ZEROX/veritas/julia.sh

$J --project=. run.jl --tarea f2 --F 1019 \
  --alpha 0.20,0.33,0.40 \
  --betad 0.0,0.20,0.34,0.40,0.45,0.50,0.55,0.60,0.70,0.80,0.90,1.0 \
  --betax 0.0

$J --project=. run.jl --tarea f2 --F 3600 --sufijo -F3600 \
  --alpha 0.20,0.33,0.40 \
  --betad 0.0,0.34,0.45,0.50,0.55,0.70,1.0 \
  --betax 0.0
