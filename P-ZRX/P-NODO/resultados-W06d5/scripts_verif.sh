#!/usr/bin/env bash
# Instrumentación de observación de V4-V7 de ORDEN-W06d5 (no es código del encargo, solo scripts de
# esta sesión, en la línea de deepseek/W06d4/logs/v*.sh). Usa scripts_v4.sh para lanzar/matar nodos.
set -uo pipefail
Z=/home/katana/zeo/ZEROX/deepseek/W06d5
RUN="$Z/run"

contar_evento() {
  # contar_evento <registro.jsonl> <tipo>
  grep -c "\"tipo\":\"$2\"" "$1" 2>/dev/null || echo 0
}

hay_fatal() {
  # hay_fatal <stderr.log...>
  grep -l "error fatal" "$@" 2>/dev/null
}

# espera_v4 <archivos_registro...> <minimo_total> <timeout_s> <stderr_globs...>
# Usa un separador "--" entre la lista de registros y la de stderr.
espera_suma_bloques() {
  local minimo="$1" plazo="$2"; shift 2
  local regs=()
  while [ "$1" != "--" ]; do regs+=("$1"); shift; done
  shift
  local errs=("$@")
  local fin=$(( $(date +%s) + plazo ))
  while [ "$(date +%s)" -lt "$fin" ]; do
    local total=0
    for r in "${regs[@]}"; do
      c=$(contar_evento "$r" bloque_producido)
      total=$((total + c))
    done
    if [ -n "$(hay_fatal "${errs[@]}")" ]; then
      echo "FALLO_FATAL $(hay_fatal "${errs[@]}")"
      return 1
    fi
    if [ "$total" -ge "$minimo" ]; then
      echo "EXITO total=$total"
      return 0
    fi
    sleep 3
  done
  echo "TIMEOUT total=$total"
  return 2
}

cmd="${1:-}"; shift || true
case "$cmd" in
  espera_suma_bloques) espera_suma_bloques "$@" ;;
  contar_evento) contar_evento "$@" ;;
  hay_fatal) hay_fatal "$@" ;;
  *) echo "subcomando desconocido: $cmd" >&2; exit 2 ;;
esac
