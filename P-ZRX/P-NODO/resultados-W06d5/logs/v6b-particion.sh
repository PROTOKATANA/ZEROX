#!/usr/bin/env bash
# ORDEN-W06d5 decisión 4: espera a que A y B (partidos, sin C) produzcan >=20 bloques cada uno tras
# la partición, y PARA en cuanto se alcanza (no "dejar corriendo de más", causa de V6(b) en
# REVISION-W06d4.md: con miles de slots de sobra se superaba F_SLOTS=600). Poll cada 2 s, timeout 3 min.
set -uo pipefail
RUN="$1"  # deepseek/W06d5/run
MIN="${2:-20}"
TIMEOUT="${3:-180}"
fin=$(( $(date +%s) + TIMEOUT ))
base_a=$(grep -c '"tipo":"bloque_producido"' "$RUN/A/registro.jsonl" 2>/dev/null)
  c=${c:-0}; a=${a:-0}; b=${b:-0}; c2=${c2:-0}; base_a=${base_a:-0}; base_b=${base_b:-0}
base_b=$(grep -c '"tipo":"bloque_producido"' "$RUN/B/registro.jsonl" 2>/dev/null)
  c=${c:-0}; a=${a:-0}; b=${b:-0}; c2=${c2:-0}; base_a=${base_a:-0}; base_b=${base_b:-0}
while [ "$(date +%s)" -lt "$fin" ]; do
  a=$(grep -c '"tipo":"bloque_producido"' "$RUN/A/registro.jsonl" 2>/dev/null)
  c=${c:-0}; a=${a:-0}; b=${b:-0}; c2=${c2:-0}; base_a=${base_a:-0}; base_b=${base_b:-0}
  b=$(grep -c '"tipo":"bloque_producido"' "$RUN/B/registro.jsonl" 2>/dev/null)
  c=${c:-0}; a=${a:-0}; b=${b:-0}; c2=${c2:-0}; base_a=${base_a:-0}; base_b=${base_b:-0}
  da=$((a - base_a)); db=$((b - base_b))
  if grep -q "error fatal" "$RUN/A/stderr.log" "$RUN/B/stderr.log" 2>/dev/null; then
    echo "FATAL_DETECTADO da=$da db=$db"
    exit 1
  fi
  if [ "$da" -ge "$MIN" ] && [ "$db" -ge "$MIN" ]; then
    echo "PARTICION_OK da=$da db=$db"
    exit 0
  fi
  sleep 2
done
echo "TIMEOUT da=$da db=$db"
exit 2
