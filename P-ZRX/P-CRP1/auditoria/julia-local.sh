#!/usr/bin/env bash
# P-CRP1 · envoltorio local de Julia. NO modifica CRP-v0.1.
#
# Motivo: bajo el sandbox de escritura de DSH, `$HOME/.julia` es de solo lectura
# (EROFS al crear `~/.julia/logs/manifest_usage.toml.pid`). Se usa un depot
# escribible dentro de la zona de trabajo y se añade el depot del sistema como
# reserva de solo lectura (JULIA_DEPOT_PATH admite una pila de depots).
#
# Uso: ./julia-local.sh --project=<dir> [args de julia]
set -euo pipefail

AUD="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export JULIA_DEPOT_PATH="$AUD/.julia_depot:$HOME/.julia"
export JULIA_NUM_THREADS="${JULIA_NUM_THREADS:-4}"
export OPENBLAS_NUM_THREADS="${OPENBLAS_NUM_THREADS:-1}"
export PATH="$HOME/torio/.juliaup/bin:$PATH"

exec env -u LD_LIBRARY_PATH julia "$@"
