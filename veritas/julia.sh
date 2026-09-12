#!/usr/bin/env bash
set -euo pipefail

export PATH="$HOME/torio/.juliaup/bin:$PATH"
exec env -u LD_LIBRARY_PATH julia "$@"
