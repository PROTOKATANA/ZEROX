#!/usr/bin/env bash
# V6(a) (regresión, igual que W06d4): corte cruzado y régimen en marcha tras la reunión de A/B/C.
# Éxito: suma de cambio_punta de A+B+C >= 20; fallo si "error fatal"; si no, TIMEOUT_5MIN.
set -uo pipefail
RUN="$1"
TIMEOUT="${2:-300}"
fin=$(( $(date +%s) + TIMEOUT ))
while [ "$(date +%s)" -lt "$fin" ]; do
  if grep -q "error fatal" "$RUN"/{A,B,C}/stderr.log 2>/dev/null; then
    echo "FALLO_FATAL"
    exit 1
  fi
  total=0
  for n in A B C; do
    c=$(grep -c '"tipo":"cambio_punta"' "$RUN/$n/registro.jsonl" 2>/dev/null)
  c=${c:-0}; a=${a:-0}; b=${b:-0}; c2=${c2:-0}; base_a=${base_a:-0}; base_b=${base_b:-0}
    total=$((total + c))
  done
  if [ "$total" -ge 20 ]; then
    echo "CORTE_CRUZADO_Y_20_SLOTS cambios=$total"
    exit 0
  fi
  sleep 8
done
echo "TIMEOUT_5MIN cambios=$total"
exit 2
