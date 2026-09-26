#!/usr/bin/env bash
# ORDEN-W06d5 decisión 4: tras la reunión, espera a que C2 produzca >=5 bloques propios (prueba de
# que se reincorporó de verdad) o detecta "error fatal" en A/B/C2. Poll cada 3 s, timeout 3 min.
set -uo pipefail
RUN="$1"
TIMEOUT="${2:-180}"
fin=$(( $(date +%s) + TIMEOUT ))
while [ "$(date +%s)" -lt "$fin" ]; do
  if grep -q "error fatal" "$RUN/A/stderr.log" "$RUN/B/stderr.log" "$RUN/C2/stderr.log" 2>/dev/null; then
    echo "FATAL_DETECTADO"
    grep -l "error fatal" "$RUN/A/stderr.log" "$RUN/B/stderr.log" "$RUN/C2/stderr.log" 2>/dev/null
    exit 1
  fi
  c2=$(grep -c '"tipo":"bloque_producido"' "$RUN/C2/registro.jsonl" 2>/dev/null)
  c=${c:-0}; a=${a:-0}; b=${b:-0}; c2=${c2:-0}; base_a=${base_a:-0}; base_b=${base_b:-0}
  if [ "$c2" -ge 5 ]; then
    echo "REUNION_OK c2=$c2"
    exit 0
  fi
  sleep 3
done
echo "TIMEOUT c2=$c2"
exit 2
