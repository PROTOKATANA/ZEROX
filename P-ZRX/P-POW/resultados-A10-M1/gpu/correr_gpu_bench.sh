#!/usr/bin/env bash
set -euo pipefail
cd /home/katana/zeo/ZEROX/deepseek/A10M1/gpu
BENCH=/home/katana/zeo/ZEROX/deepseek/A10M1/cargo-target/release/examples/bench_pow
BLOCKS=120
THREADS=256
DUR=30
REPS=5

nvidia-smi --query-gpu=timestamp,power.draw,clocks.sm,temperature.gpu,utilization.gpu \
  --format=csv -lms 1000 > nvidia_smi_muestreo.csv &
SMI_PID=$!

./pow_gpu_nvrtc kernel_nvrtc.cu "$BENCH" bench "$DUR" "$BLOCKS" "$THREADS" "$REPS" > gpu_bench.log 2> gpu_bench.stderr

kill "$SMI_PID" 2>/dev/null || true
wait "$SMI_PID" 2>/dev/null || true
echo "hecho"
