#!/usr/bin/env bash
# Orquestación V4/V5/V6/V7 de ORDEN-W06d4: procesos reales de zx-node en 127.0.0.1.
# Uso: scripts_v4.sh <subcomando> ...
set -uo pipefail
Z=/home/katana/zeo/ZEROX/deepseek/W06d5
BIN="$Z/target/release/zx-node"
ADV="$Z/target/release/zx-adversario"
RUN="$Z/run"
mkdir -p "$RUN"

puerto_base=41300

lanzar_nodo() {
  # lanzar_nodo <nombre> <claves> <puerto_escuchar_o_-> <marcar...>
  local nombre="$1" claves="$2" puerto="$3"; shift 3
  local marcar_args=()
  for m in "$@"; do marcar_args+=(--red-marcar "$m"); done
  local escuchar_args=()
  if [ "$puerto" != "-" ]; then
    escuchar_args=(--red-escuchar "/ip4/127.0.0.1/tcp/$puerto")
  fi
  mkdir -p "$RUN/$nombre"
  nohup "$BIN" \
    --datos "$RUN/$nombre/datos" \
    --registro "$RUN/$nombre/registro.jsonl" \
    --claves "$claves" \
    --n-dev "${N_DEV:-2000}" \
    --sr-dev "${SR_DEV:-18446744073709551615}" \
    ${PARADA:+--parada-tras-slots "$PARADA"} \
    "${escuchar_args[@]}" \
    "${marcar_args[@]}" \
    > "$RUN/$nombre/stdout.log" 2> "$RUN/$nombre/stderr.log" &
  echo $! > "$RUN/$nombre/pid"
  disown
  echo "lanzado $nombre pid=$(cat "$RUN/$nombre/pid")"
}

matar_todo() {
  for f in "$RUN"/*/pid; do
    [ -f "$f" ] || continue
    pid=$(cat "$f")
    if kill -0 "$pid" 2>/dev/null; then
      kill "$pid" 2>/dev/null
    fi
  done
  sleep 1
  for f in "$RUN"/*/pid; do
    [ -f "$f" ] || continue
    pid=$(cat "$f")
    kill -9 "$pid" 2>/dev/null
  done
}

esperar_evento() {
  # esperar_evento <archivo_registro> <tipo_evento> <timeout_s>
  local archivo="$1" tipo="$2" plazo="$3"
  local fin=$(( $(date +%s) + plazo ))
  while [ "$(date +%s)" -lt "$fin" ]; do
    if grep -q "\"tipo\":\"$tipo\"" "$archivo" 2>/dev/null; then
      return 0
    fi
    sleep 1
  done
  return 1
}

resumen_final() {
  # último resumen_estado de cambio_punta en un registro.
  grep '"tipo":"cambio_punta"' "$1" 2>/dev/null | tail -1
}

terminal_final() {
  grep '"tipo":"cambio_punta"' "$1" 2>/dev/null | tail -1 | grep -o '"punta":"[^"]*"'
}

cmd="${1:-}"; shift || true
case "$cmd" in
  lanzar_nodo) lanzar_nodo "$@" ;;
  matar_todo) matar_todo ;;
  esperar_evento) esperar_evento "$@" ;;
  resumen_final) resumen_final "$@" ;;
  terminal_final) terminal_final "$@" ;;
  *) echo "subcomando desconocido: $cmd" >&2; exit 2 ;;
esac
