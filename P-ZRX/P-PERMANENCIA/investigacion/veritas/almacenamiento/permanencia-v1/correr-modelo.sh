#!/usr/bin/env bash
# correr-modelo.sh — barridos publicados de permanencia-v1.
#
# TODOS los símbolos son ENTRADAS y quedan escritos en la línea de comandos:
#   w        ventana de adelanto, en slots        (P-REVELACION mide 7.175 y 4.830,6)
#   D_a      plazo de una auditoría, en segundos  (entrada de diseño)
#   c        aperturas por auditoría               (entrada de diseño)
#   qP       parciales por pieza y periodo         (símbolo; fija λ = N·qP)
#   periodo  slots por periodo de auditoría        (entrada de diseño)
#   a        disponibilidad del honesto            (entrada)
#   beta/gamma  error de falsos fallos / de detección (entrada)
#   s        fracción almacenada por el tramposo   (entrada)
#   N_h, lambda_red, sigma  red honesta y granjero (entradas)
# Ninguno es un parámetro de consenso fijado por el instrumento.
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$RAIZ"
export JULIA_DEPOT_PATH="$RAIZ/../../.julia-depot:/home/katana/.julia"
export JULIA_NUM_THREADS=4          # tope del encargo: 4 hilos
export OPENBLAS_NUM_THREADS=1
JULIA=/home/katana/zeo/ZEROX/veritas/julia.sh
mkdir -p resultados

"$JULIA" --project=. run.jl \
  --hardware mediciones/hardware.tsv \
  --w 7175 --D-a 60 --c 1000 --qP 1e-5 --periodo 100 --a 0.99 \
  --beta 1e-3 --gamma 1e-2 --s 0.5 \
  --N-h 1000000000 --lambda-red 1.0 --sigma 0.01 \
  --F-slots 7200 --t-read-hdd 0.010 --t-read-ssd 0.0001 --gpu-factor 17 \
  --b-apertura 112 --b-compromiso 32 --b-parcial 200 --k-aperturas 10 \
  --salida-dir resultados

echo
echo "--- validación ---"
cat resultados/VALIDACION.txt
