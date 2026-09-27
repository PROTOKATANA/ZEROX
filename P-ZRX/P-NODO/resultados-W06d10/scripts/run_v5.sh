#!/usr/bin/env bash
# run_v5.sh — V5 de ORDEN-W06d10 (sin falsos positivos): 3 repeticiones de tres nodos honestos que
# cruzan el corte hasta el slot 150 + 1 partición E-6 con aislamiento real (r3_e6.sh). Criterio:
# 0 `par_penalizado` entre nodos honestos. SR_dev real, semilla 101.
# Uso: run_v5.sh
set -uo pipefail
Z=/home/katana/zeo/ZEROX/deepseek/W06d10
SEMILLA=101
SRDEV=13043817825332783104
LOG="$Z/run/v5-driver.log"
mkdir -p "$Z/run"; : > "$LOG"

echo "$(date -Is) === V5: 3 repeticiones R150 (tres nodos, slot 150) ===" | tee -a "$LOG"
for i in 1 2 3; do
  base=$((52000 + i * 10))
  bash "$Z/scripts/r150.sh" "$i" "$base" "$SEMILLA" "$SRDEV" >> "$LOG" 2>&1
  echo "$(date -Is) R150 rep$i terminada: $(head -1 "$Z/run/R150-$i/RESULTADO.txt" 2>/dev/null)" | tee -a "$LOG"
done

echo "$(date -Is) === V5: partición E-6 (aislamiento real) ===" | tee -a "$LOG"
bash "$Z/scripts/r3_e6.sh" "v5" 52300 "$SEMILLA" "$SRDEV" >> "$LOG" 2>&1
echo "$(date -Is) E-6 v5 terminada" | tee -a "$LOG"

echo "$(date -Is) === RESUMEN V5 ===" | tee -a "$LOG"
for d in "$Z"/run/R150-* "$Z"/run/R3-E6-*; do
  [ -d "$d" ] || continue
  pen=0
  for reg in "$d"/*/registro.jsonl; do
    [ -f "$reg" ] || continue
    c=$(grep -c '"tipo":"par_penalizado"' "$reg" 2>/dev/null)
    pen=$((pen + ${c:-0}))
  done
  echo "$(basename "$d"): resultado=$(head -1 "$d/RESULTADO.txt" 2>/dev/null) par_penalizado=$pen" | tee -a "$LOG"
done
echo "$(date -Is) === V5 TERMINADO ===" | tee -a "$LOG"
