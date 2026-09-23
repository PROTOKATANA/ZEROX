#!/usr/bin/env bash
# correr-modelo.sh — barridos publicados de sellado-rama-v1.
#
# TODOS los símbolos son ENTRADAS y quedan en la línea de comandos:
#   λ, τ, Δ, Δ̄, ramas, réplicas, H, semilla, η.
# Ninguno es un parámetro de consenso fijado por el instrumento.
#
# Presupuesto declarado: 4 hilos (tope del encargo), 8 GiB de RAM, 2 GiB de disco,
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
echo "--- 1/5 · tests (perfil de referencia: check-bounds activo, 1 hilo) ---"
JULIA_NUM_THREADS=1 "$JULIA" --project=. --check-bounds=yes test/runtests.jl 2>&1 | tee resultados/TEST.txt

echo
echo "--- 2/5 · barridos publicados (F2, F4, F5, certificado) ---"
"$JULIA" --project=. run.jl --tarea f2 --tarea f4 --tarea f5 --tarea cert \
  --lambda 1.0 --tau 1.0 \
  --delta 0.26,0.35,0.45,0.60 \
  --delta-medio 0.138,0.20,0.30,0.387 \
  --ramas 1.0,1.14,1.26,1.39,2.0 \
  --seed 0x5E110A1A --salida-dir resultados 2>&1 | tee resultados/RUN.txt

echo
echo "--- 3/5 · Monte Carlo del modelo de punta (dos RNG) ---"
"$JULIA" --project=. run.jl --tarea mc --lambda 1.0 \
  --delta-medio 0.138,0.20,0.30,0.387 --replicas 48 --mc-h 3000 \
  --seed 0x5E110A1A --salida-dir resultados 2>&1 | tee -a resultados/RUN.txt

echo
echo "--- 4/5 · benchmarks ---"
"$JULIA" --project=. bench/benchmarks.jl > resultados/BENCH.txt 2>&1 || true
tail -20 resultados/BENCH.txt

echo
echo "--- 5/5 · JET ---"
"$JULIA" --project=. -e 'using JET, SelladoRama; JET.report_package(SelladoRama; target_modules = (SelladoRama,))' \
  > resultados/JET.txt 2>&1 || true
echo "JET: $(grep -c 'possible error' resultados/JET.txt || true) posibles errores; salida en resultados/JET.txt"

echo
echo "--- resumen de validación ---"
{
  echo "sellado-rama-v1 · VALIDACION"
  echo "fecha: $(date -Is)"
  echo "julia: $("$JULIA" --version)"
  echo "hilos de cálculo: 4 (tope del encargo) · tests a 1 hilo"
  echo "uptime: $(uptime)"
  echo
  grep -E "^Test Summary|^sellado-rama-v1 +\|" resultados/TEST.txt || true
  echo
  echo "artefactos: $(ls resultados/*.tsv 2>/dev/null | tr '\n' ' ')"
  echo
  echo "--- cabeceras de los TSV publicados ---"
  for f in resultados/*.tsv; do
    echo "### $f"
    grep -c -v '^#' "$f" | sed 's/^/filas_datos=/'
  done
} | tee resultados/VALIDACION.txt
