#!/usr/bin/env bash
# ORDEN-W06d5, V5: el 4.o nodo D (clave nueva, sin garantia) sincroniza y convive sin tirar a los
# demás (decisiones 1 y 2). Éxito: D alcanza el mismo par (punta,resumen_estado) que A en su último
# cambio_punta, y 0 "error fatal" en A/B/C/D durante una ventana sostenida tras alcanzarlo.
set -uo pipefail
RUN="$1"
TIMEOUT="${2:-300}"
VENTANA="${3:-30}"
fin=$(( $(date +%s) + TIMEOUT ))
ultimo_par() {
  grep '"tipo":"cambio_punta"' "$1" 2>/dev/null | tail -1 | grep -o '"punta":"[^"]*"'
}
while [ "$(date +%s)" -lt "$fin" ]; do
  if grep -q "error fatal" "$RUN"/{A,B,C,D}/stderr.log 2>/dev/null; then
    echo "FALLO_FATAL"
    grep -l "error fatal" "$RUN"/{A,B,C,D}/stderr.log 2>/dev/null
    exit 1
  fi
  pa=$(ultimo_par "$RUN/A/registro.jsonl")
  pd=$(ultimo_par "$RUN/D/registro.jsonl")
  if [ -n "$pa" ] && [ "$pa" = "$pd" ]; then
    echo "D_SINCRONIZADO punta=$pd; esperando ${VENTANA}s sostenidos sin fatal..."
    sleep "$VENTANA"
    if grep -q "error fatal" "$RUN"/{A,B,C,D}/stderr.log 2>/dev/null; then
      echo "FALLO_FATAL_TRAS_SINCRONIZAR"
      grep -l "error fatal" "$RUN"/{A,B,C,D}/stderr.log 2>/dev/null
      exit 1
    fi
    echo "EXITO_V5 punta=$pd"
    exit 0
  fi
  sleep 5
done
echo "TIMEOUT pa=$pa pd=$pd"
exit 2
