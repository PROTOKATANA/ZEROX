#!/usr/bin/env bash
# correr-modelo.sh — barridos publicados de cobertura-parcela-v1.
#
# TODOS los símbolos son ENTRADAS y quedan en la línea de comandos:
#   N, k, w, D_a, R (r_maquina), maquinas, phi, gamma, beta.
# Ninguno es un parámetro de consenso fijado por el instrumento.
#
# Presupuesto declarado: 4 hilos (tope del encargo), 8 GiB de RAM, 256 MiB de disco,
# 2 h de pared. Si se agota: checkpoint y estado INCONCLUSO.
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$RAIZ"
export JULIA_DEPOT_PATH="$RAIZ/../../../.julia-depot:/home/katana/.julia"
export JULIA_NUM_THREADS=4
export OPENBLAS_NUM_THREADS=1
JULIA=/home/katana/zeo/ZEROX/veritas/julia.sh
mkdir -p resultados

echo "=== uptime antes de medir ==="
uptime
echo "=== nproc=$(nproc) · hilos Julia=4 ==="

echo
echo "--- 1/4 · tests (perfil de referencia: check-bounds activo, 4 hilos) ---"
"$JULIA" --project=. --check-bounds=yes test/runtests.jl 2>&1 | tee resultados/TEST.txt

echo
echo "--- 2/4 · barridos publicados ---"
"$JULIA" --project=. run.jl \
  --hardware mediciones/hardware.tsv \
  --w 7175 --D-a 60 --k 1000 --maquinas 1 \
  --gamma 1e-2 --beta 1e-3 --replicas 20000 \
  --salida-dir resultados 2>&1 | tee resultados/RUN.txt

echo
echo "--- 3/4 · benchmarks ---"
"$JULIA" --project=. bench/benchmarks.jl > resultados/BENCH.txt 2>&1 || true
tail -25 resultados/BENCH.txt

echo
echo "--- 4/4 · JET ---"
"$JULIA" --project=. -e 'using JET, CoberturaParcela; JET.report_package(CoberturaParcela; target_modules = (CoberturaParcela,))' \
  > resultados/JET.txt 2>&1 || true
grep -c "═\|possible error\|MethodError" resultados/JET.txt >/dev/null 2>&1 || true
echo "JET: $(grep -c 'possible error' resultados/JET.txt || true) posibles errores; salida en resultados/JET.txt"

echo
echo "--- resumen de validación ---"
{
  echo "cobertura-parcela-v1 · VALIDACION"
  echo "fecha: $(date -Is)"
  echo "julia: $("$JULIA" --version)"
  echo "hilos: 4 (tope del encargo)"
  echo "uptime: $(uptime)"
  echo
  grep -E "^Test Summary|^cobertura-parcela-v1 +\|" resultados/TEST.txt || true
  echo
  echo "artefactos: $(ls resultados/*.tsv 2>/dev/null | tr '\n' ' ')"
} | tee resultados/VALIDACION.txt
