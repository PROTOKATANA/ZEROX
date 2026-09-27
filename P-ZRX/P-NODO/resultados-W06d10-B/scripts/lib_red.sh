#!/usr/bin/env bash
# lib_red.sh — funciones comunes para lanzar/matar zx-node y su muestreo de recursos (arnés de
# W07b, bash, sin Python). Se importa con `source` desde cada guion de escenario.
#
# Variables que cada guion debe fijar antes de `source lib_red.sh`:
#   BIN   -> directorio con zx-node/zx-adversario (release)
#   RUN   -> directorio de esta ejecución/repetición (se crea)
#   SRDEV -> valor de --sr-dev a usar (si no se fija, se omite y el nodo usa su default)
set -uo pipefail
SCRIPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MUESTREADOR="$SCRIPTS_DIR/muestrear_recursos.sh"

declare -A PIDS_SAMPLER

puertos_libres_o_falla() {
  for p in "$@"; do
    if ss -ltn 2>/dev/null | grep -q ":$p "; then
      echo "FALLO: el puerto $p ya está en uso"
      exit 3
    fi
  done
}

sin_zx_node_o_falla() {
  if pgrep -x zx-node >/dev/null 2>&1 || pgrep -x zx-adversario >/dev/null 2>&1; then
    echo "FALLO: ya hay un zx-node/zx-adversario vivo (una red a la vez); ver: $(pgrep -la 'zx-node|zx-adversario' 2>/dev/null)"
    exit 3
  fi
}

# lanzar <nombre> <claves> <puerto|-> [--dejar-de-producir-en-slot N] -- <marcar...>
# Uso simplificado: lanzar_nodo NOMBRE CLAVES PUERTO_O_GUION DEJAR_SLOT_O_VACIO MARCAR...
lanzar_nodo() {
  local nombre="$1" claves="$2" puerto="$3" dejar="$4"; shift 4
  local marcar_args=() escuchar_args=() dejar_args=() srdev_args=() semilla_args=()
  for m in "$@"; do marcar_args+=(--red-marcar "$m"); done
  if [ "$puerto" != "-" ]; then escuchar_args=(--red-escuchar "/ip4/127.0.0.1/tcp/$puerto"); fi
  if [ -n "$dejar" ]; then dejar_args=(--dejar-de-producir-en-slot "$dejar"); fi
  if [ -n "${SRDEV:-}" ]; then srdev_args=(--sr-dev "$SRDEV"); fi
  if [ -n "${SEMILLA:-}" ]; then semilla_args=(--semilla "$SEMILLA"); fi
  mkdir -p "$RUN/$nombre/datos"
  nohup "$BIN/zx-node" \
    --datos "$RUN/$nombre/datos" \
    --registro "$RUN/$nombre/registro.jsonl" \
    --claves "$claves" \
    --n-dev 138873760 \
    "${semilla_args[@]}" \
    "${srdev_args[@]}" \
    "${escuchar_args[@]}" \
    "${dejar_args[@]}" \
    "${marcar_args[@]}" \
    >> "$RUN/$nombre/stdout.log" 2>> "$RUN/$nombre/stderr.log" &
  echo $! > "$RUN/$nombre/pid"
  disown
  echo "lanzado $nombre pid=$(cat "$RUN/$nombre/pid")"
  iniciar_muestreo "$nombre"
}

iniciar_muestreo() {
  local nombre="$1"
  local pid; pid=$(cat "$RUN/$nombre/pid")
  nohup bash "$MUESTREADOR" "$pid" "$RUN/$nombre/datos" "$RUN/recursos-$nombre.csv" \
    > "$RUN/$nombre/muestreador.log" 2>&1 &
  PIDS_SAMPLER[$nombre]=$!
  disown
}

detener_muestreo() {
  local nombre="$1"
  local spid="${PIDS_SAMPLER[$nombre]:-}"
  [ -n "$spid" ] && kill "$spid" 2>/dev/null
}

# matar <nombre> [puerto]  — SIGKILL directo (usado también para el E-4 "muerte")
matar() {
  local nombre="$1" puerto="${2:-}"
  detener_muestreo "$nombre"
  local f="$RUN/$nombre/pid"
  [ -f "$f" ] || return 0
  local pid; pid=$(cat "$f")
  kill -9 "$pid" 2>/dev/null || true
  for _ in $(seq 1 100); do kill -0 "$pid" 2>/dev/null || break; sleep 0.1; done
  if [ -n "$puerto" ]; then
    for _ in $(seq 1 100); do ss -ltn 2>/dev/null | grep -q ":$puerto " || break; sleep 0.1; done
  fi
}

# parar_ordenado <nombre> [puerto] — SIGTERM (salida ordenada, para "parada")
parar_ordenado() {
  local nombre="$1" puerto="${2:-}"
  detener_muestreo "$nombre"
  local f="$RUN/$nombre/pid"
  [ -f "$f" ] || return 0
  local pid; pid=$(cat "$f")
  kill -TERM "$pid" 2>/dev/null || true
  for _ in $(seq 1 100); do kill -0 "$pid" 2>/dev/null || break; sleep 0.1; done
  kill -9 "$pid" 2>/dev/null || true
  if [ -n "$puerto" ]; then
    for _ in $(seq 1 100); do ss -ltn 2>/dev/null | grep -q ":$puerto " || break; sleep 0.1; done
  fi
}

escribir_ejecucion_txt() {
  local out="$RUN/EJECUCION.txt"
  {
    echo "commit=$(git -C "$CLON" rev-parse HEAD 2>/dev/null)"
    echo "sha256_zx-node=$(sha256sum "$BIN/zx-node" 2>/dev/null | awk '{print $1}')"
    echo "sha256_zx-adversario=$(sha256sum "$BIN/zx-adversario" 2>/dev/null | awk '{print $1}')"
    echo "n_dev=138873760"
    echo "sr_dev=${SRDEV:-default_u64_max}"
    echo "CLK_TCK=$(getconf CLK_TCK)"
    echo "PAGE_SIZE=$(getconf PAGESIZE)"
    echo "uname=$(uname -a)"
    echo "nproc=$(nproc)"
    echo "loadavg_inicio=$(cat /proc/loadavg 2>/dev/null)"
    echo "fecha_inicio=$(date -Is)"
    echo "ps_inicio_top_cpu:"
    ps -eo pid,pcpu,pcomm --sort=-pcpu 2>/dev/null | head -8
  } > "$out"
}

cerrar_ejecucion_txt() {
  {
    echo "loadavg_fin=$(cat /proc/loadavg 2>/dev/null)"
    echo "fecha_fin=$(date -Is)"
  } >> "$RUN/EJECUCION.txt"
}
