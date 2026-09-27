#!/usr/bin/env bash
# run_v4.sh — V4 de ORDEN-W06d10: E-7 × 3 repeticiones (semillas 101/202/303), SR_dev real.
# Uso: run_v4.sh
set -uo pipefail
Z=/home/katana/zeo/ZEROX/deepseek/W06d10
SRDEV=13043817825332783104
LOG="$Z/run/v4-driver.log"
mkdir -p "$Z/run"; : > "$LOG"

i=1
for SEMILLA in 101 202 303; do
  base=$((51000 + i * 10))
  echo "$(date -Is) === V4 E-7 rep$i semilla=$SEMILLA puerto_base=$base ===" | tee -a "$LOG"
  bash "$Z/scripts/r4_e7_rep.sh" "$i" "$base" "$SEMILLA" "$SRDEV" >> "$LOG" 2>&1
  echo "$(date -Is) V4 rep$i terminada" | tee -a "$LOG"
  i=$((i + 1))
done

echo "$(date -Is) === RESUMEN V4 ===" | tee -a "$LOG"
for d in "$Z"/run/R4-E7-*; do
  [ -d "$d" ] || continue
  echo "$(basename "$d"): $(head -1 "$d/RESULTADO.txt" 2>/dev/null)" | tee -a "$LOG"
done
echo "$(date -Is) === V4 TERMINADO ===" | tee -a "$LOG"
