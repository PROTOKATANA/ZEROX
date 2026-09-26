#!/usr/bin/env bash
# Muestrea nvidia-smi cada 1 s a un CSV. Uso: muestreo_nvidia_smi.sh <fichero_salida> &
# Se detiene con SIGTERM (kill %job).
set -u
salida="$1"
echo "timestamp,power_draw_w,clocks_sm_mhz,clocks_mem_mhz,temp_c,util_gpu_pct,util_mem_pct" > "$salida"
while true; do
  linea=$(nvidia-smi --query-gpu=timestamp,power.draw.instant,clocks.sm,clocks.mem,temperature.gpu,utilization.gpu,utilization.memory --format=csv,noheader,nounits 2>/dev/null)
  if [ -n "$linea" ]; then
    echo "$linea" >> "$salida"
  fi
  sleep 1
done
