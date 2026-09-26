#!/usr/bin/env bash
set -euo pipefail
cd /home/katana/zeo/ZEROX/deepseek/A10M1
BIN=cargo-target/release/examples/bench_pow
OUT=cpu_bench.log
DUR=10
REPS=5
THREADS=(1 2 4 8 16 32)

snapshot() {
  echo "--- $1 $(date -Is) ---"
  uptime
  nproc
  ps -eo pid,pcpu,pmem,comm --sort=-pcpu | head -11
}

{
  echo "== ORDEN-A10-M1: banco CPU (zx_core::sha3_256_publico sobre preimagen del PoW) =="
  snapshot "ANTES-DE-TODO"
  for t in "${THREADS[@]}"; do
    cpuset="0-$((t-1))"
    snapshot "ANTES-t$t"
    for r in $(seq 1 $REPS); do
      linea=$(taskset -c "$cpuset" "$BIN" cpu-bench-mt "$t" "$DUR")
      echo "t=$t rep=$r cpuset=$cpuset $linea"
    done
    snapshot "DESPUES-t$t"
  done
  snapshot "DESPUES-DE-TODO"
} > "$OUT" 2>&1
echo "hecho"
