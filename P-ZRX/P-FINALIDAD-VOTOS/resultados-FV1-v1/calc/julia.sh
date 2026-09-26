#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/torio/.juliaup/bin:$PATH"
export JULIA_DEPOT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/.julia-depot"
mkdir -p "$JULIA_DEPOT_PATH"
exec env -u LD_LIBRARY_PATH julia "$@"
