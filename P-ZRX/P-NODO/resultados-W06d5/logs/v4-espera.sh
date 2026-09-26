#!/usr/bin/env bash
# V4 (regresión): suma de bloque_producido de A+B+C >= 60, 0 "error fatal". Poll 10s, timeout 15 min.
set -uo pipefail
RUN="$1"
MIN="${2:-60}"
TIMEOUT="${3:-900}"
fin=$(( $(date +%s) + TIMEOUT ))
while [ "$(date +%s)" -lt "$fin" ]; do
  if grep -q "error fatal" "$RUN"/{A,B,C}/stderr.log 2>/dev/null; then
    echo "FALLO_FATAL"
    exit 1
  fi
  total=0
  for n in A B C; do
    c=$(grep -c '"tipo":"bloque_producido"' "$RUN/$n/registro.jsonl" 2>/dev/null)
    c=${c:-0}
    total=$((total + c))
  done
  if [ "$total" -ge "$MIN" ]; then
    echo "EXITO_V4 total=$total"
    exit 0
  fi
  sleep 10
done
echo "TIMEOUT_15MIN total=$total"
exit 2
