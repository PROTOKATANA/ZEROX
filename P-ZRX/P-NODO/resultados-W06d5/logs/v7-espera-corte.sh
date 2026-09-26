#!/usr/bin/env bash
# V7: espera a que A cruce el corte (>=3 cambio_punta) antes de lanzar zx-adversario.
set -uo pipefail
RUN="$1"
TIMEOUT="${2:-120}"
fin=$(( $(date +%s) + TIMEOUT ))
while [ "$(date +%s)" -lt "$fin" ]; do
  if grep -q "error fatal" "$RUN"/{A,B,C}/stderr.log 2>/dev/null; then
    echo "FALLO_FATAL"
    exit 1
  fi
  c=$(grep -c '"tipo":"cambio_punta"' "$RUN/A/registro.jsonl" 2>/dev/null)
  c=${c:-0}; a=${a:-0}; b=${b:-0}; c2=${c2:-0}; base_a=${base_a:-0}; base_b=${base_b:-0}
  if [ "$c" -ge 3 ]; then
    echo "CORTE_CRUZADO cambios=$c"
    exit 0
  fi
  sleep 3
done
echo "TIMEOUT cambios=$c"
exit 2
