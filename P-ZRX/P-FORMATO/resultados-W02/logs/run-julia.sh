#!/usr/bin/env bash
# V4 — oráculo Julia (ORDEN-W02 §4). Depot aislado, sin LD_LIBRARY_PATH, 1 hilo.
set -uo pipefail
Z=/home/katana/zeo/ZEROX/deepseek/W02
J=/home/katana/.julia/juliaup/julia-1.13.0+0.x64.linux.gnu/bin/julia
export JULIA_DEPOT_PATH="$Z/.julia-depot:"
export JULIA_NUM_THREADS=1
export OPENBLAS_NUM_THREADS=1
cd "$Z/oraculo-formato-v0"
echo "INICIO $(date -Is) julia=$("$J" --version)"
env -u LD_LIBRARY_PATH "$J" --project=. -e 'using Pkg; Pkg.instantiate()' > "$Z/logs/julia-instantiate.log" 2>&1
echo "instantiate exit=$?"
env -u LD_LIBRARY_PATH "$J" --project=. -e 'using Pkg; Pkg.test()' > "$Z/logs/V4-julia-test.log" 2>&1
echo "Pkg.test exit=$?"
env -u LD_LIBRARY_PATH "$J" --project=. run.jl --seed 0x5a5a > "$Z/logs/V4-julia-run.log" 2>&1
echo "run exit=$?"
echo "FIN $(date -Is)"
