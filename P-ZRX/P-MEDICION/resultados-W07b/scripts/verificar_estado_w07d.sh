#!/usr/bin/env bash
# verificar_estado_w07d.sh — verificación REAL de "mismo estado" con el binario de W07d
# (22940aa...), que añade a `reinicio_completo` (y a `parada`) la punta, el resumen_estado del
# estado virtual FINAL, n_bloques_dag y compendio_bloques (SHA3-256 de los hashes de todos los
# bloques persistidos). Ya no hace falta adivinar "el último cambio_punta": se lee directamente de
# `reinicio_completo`.
#
# CORRECCIÓN DEL DIRECTOR (2026-09-27): se opera sobre COPIAS de `datos/`, nunca sobre el original
# (reabrir un nodo escribe en su directorio de datos: RocksDB puede compactar y el registro del
# firmante se reabre; los `datos` de cada repetición son evidencia cruda que no se toca). Cada nodo
# se copia con `cp -a` a `verif/<rep>/<nodo>/datos` antes de reabrirlo.
#
# Procedimiento, UN NODO A LA VEZ (nunca dos en paralelo):
#   1. slot_actual = ultimo_slot_conocido de su registro.jsonl ORIGINAL (sin tocarlo).
#   2. cp -a el `datos/` original a `verif/<rep>/<nodo>/datos`.
#   3. se relanza AISLADO sobre la COPIA: puerto NUEVO, sin --red-marcar,
#      --dejar-de-producir-en-slot = slot_actual-1 (no produce nada nuevo), --registro NUEVO
#      (dentro de verif/), con nice -n 10.
#   4. se espera el evento `reinicio_completo` en el registro nuevo; se leen `resumen_estado`,
#      `compendio_bloques`, `punta`, `n_bloques_dag` de esa misma línea.
#   5. se manda SIGTERM (parada ordenada, W07d) y se espera a que el proceso termine (con SIGKILL
#      de emergencia si no termina en el plazo). Se anota el sha256 del registro de verificación.
#   6. se pasa al siguiente nodo.
# Al final se comparan resumen_estado Y compendio_bloques entre todos los nodos de la repetición.
#
# Uso: verificar_estado_w07d.sh <RUN_dir> <BIN_dir> <SRDEV> <SEMILLA> <PUERTO_BASE_AISLADO> "<nombre>:<claves>" ...
set -uo pipefail
Z=/home/katana/zeo/ZEROX/deepseek/W07b
VF="$Z/scripts/verif.sh"

RUN="${1:?uso: verificar_estado_w07d.sh <RUN_dir> <BIN_dir> <SRDEV> <SEMILLA> <PUERTO_BASE_AISLADO> \"nombre:claves\" ...}"
BIN="${2:?falta BIN_dir}"
SRDEV="${3:?falta SRDEV}"
SEMILLA="${4:?falta SEMILLA}"
PUERTO_BASE_AISLADO="${5:?falta puerto_base_aislado}"
shift 5
ESPECS=("$@")
[ "${#ESPECS[@]}" -ge 1 ] || { echo "FALLO: no se dieron especificaciones de nodo"; exit 2; }

REPNOM="$(basename "$RUN")"
VERIF="$Z/verif/$REPNOM"
mkdir -p "$VERIF"
OUT="$RUN/W07D-VERIFICACION.txt"
: > "$OUT"
echo "$(date -Is) === verificación de estado con binario W07d (secuencial, un nodo a la vez, sobre copias) ===" >> "$OUT"
echo "copias en: $VERIF" >> "$OUT"

declare -A RESUMEN COMPENDIO PUNTA NDAG
idx=0
for espec in "${ESPECS[@]}"; do
  IFS=':' read -r nombre claves <<< "$espec"
  puerto_aislado=$((PUERTO_BASE_AISLADO + idx))
  idx=$((idx + 1))

  if ss -ltn 2>/dev/null | grep -q ":$puerto_aislado "; then
    echo "FALLO: puerto $puerto_aislado ya en uso, para $nombre" >> "$OUT"; echo "FALLO_PUERTO"; exit 3
  fi
  if pgrep -x zx-node >/dev/null 2>&1; then
    echo "FALLO: ya hay un zx-node vivo antes de procesar $nombre" >> "$OUT"; echo "FALLO_ZXNODE_VIVO"; exit 3
  fi

  slot_actual=$("$VF" ultimo_slot_conocido "$RUN/$nombre/registro.jsonl")
  slot_actual=${slot_actual:-0}
  dejar=$(( slot_actual > 0 ? slot_actual - 1 : 0 ))

  mkdir -p "$VERIF/$nombre"
  rm -rf "$VERIF/$nombre/datos"
  echo "$(date -Is) $nombre: copiando datos/ (cp -a) a $VERIF/$nombre/datos ..." >> "$OUT"
  cp -a "$RUN/$nombre/datos" "$VERIF/$nombre/datos"
  reg_nuevo="$VERIF/$nombre/registro-w07d.jsonl"
  : > "$reg_nuevo"
  echo "$(date -Is) $nombre: slot_actual_previo=$slot_actual dejar=$dejar puerto_aislado=$puerto_aislado (sobre copia)" >> "$OUT"

  nice -n 10 nohup "$BIN/zx-node" \
    --datos "$VERIF/$nombre/datos" \
    --registro "$reg_nuevo" \
    --claves "$claves" \
    --n-dev 138873760 \
    --semilla "$SEMILLA" \
    --sr-dev "$SRDEV" \
    --red-escuchar "/ip4/127.0.0.1/tcp/$puerto_aislado" \
    --dejar-de-producir-en-slot "$dejar" \
    >> "$VERIF/$nombre/stdout-w07d.log" 2>> "$VERIF/$nombre/stderr-w07d.log" &
  pid=$!
  disown

  FIN=$(( $(date +%s) + 600 ))
  encontrado=0
  while [ "$(date +%s)" -lt "$FIN" ]; do
    if ! kill -0 "$pid" 2>/dev/null; then
      echo "FALLO: $nombre terminó antes de reinicio_completo (¿panic?); ver stderr-w07d.log" >> "$OUT"
      break
    fi
    if grep -q '"tipo":"reinicio_completo"' "$reg_nuevo" 2>/dev/null; then
      encontrado=1
      break
    fi
    if [ -s "$VERIF/$nombre/stderr-w07d.log" ] && grep -qE "error fatal|panicked at" "$VERIF/$nombre/stderr-w07d.log" 2>/dev/null; then
      echo "FALLO_FATAL en $nombre: $(cat "$VERIF/$nombre/stderr-w07d.log")" >> "$OUT"
      break
    fi
    sleep 2
  done

  if [ "$encontrado" -eq 0 ]; then
    echo "FALLO: $nombre no llegó a reinicio_completo en el plazo" >> "$OUT"
    kill -9 "$pid" 2>/dev/null || true
    for _ in $(seq 1 50); do kill -0 "$pid" 2>/dev/null || break; sleep 0.1; done
    continue
  fi

  linea=$(grep '"tipo":"reinicio_completo"' "$reg_nuevo" | tail -1)
  echo "$nombre reinicio_completo: $linea" >> "$OUT"
  r=$(echo "$linea" | grep -o '"resumen_estado":"[^"]*"')
  c=$(echo "$linea" | grep -o '"compendio_bloques":"[^"]*"')
  p=$(echo "$linea" | grep -o '"punta":"[^"]*"')
  n=$(echo "$linea" | grep -o '"n_bloques_dag":[0-9]*')
  RESUMEN[$nombre]="$r"; COMPENDIO[$nombre]="$c"; PUNTA[$nombre]="$p"; NDAG[$nombre]="$n"
  echo "$nombre: punta=$p resumen=$r compendio=$c n_bloques_dag=$n" >> "$OUT"

  kill -TERM "$pid" 2>/dev/null || true
  for _ in $(seq 1 100); do kill -0 "$pid" 2>/dev/null || break; sleep 0.2; done
  if kill -0 "$pid" 2>/dev/null; then
    echo "$nombre no terminó con SIGTERM en 20s; SIGKILL de emergencia" >> "$OUT"
    kill -9 "$pid" 2>/dev/null || true
    for _ in $(seq 1 50); do kill -0 "$pid" 2>/dev/null || break; sleep 0.1; done
  fi
  for _ in $(seq 1 50); do ss -ltn 2>/dev/null | grep -q ":$puerto_aislado " || break; sleep 0.1; done

  sha=$(sha256sum "$reg_nuevo" | awk '{print $1}')
  echo "$nombre: sha256(registro-w07d.jsonl)=$sha" >> "$OUT"
done

primero=""; iguales=1; algun_fallo=0
for espec in "${ESPECS[@]}"; do
  IFS=':' read -r nombre claves <<< "$espec"
  if [ -z "${RESUMEN[$nombre]:-}" ]; then algun_fallo=1; continue; fi
  clave_cmp="${RESUMEN[$nombre]}|${COMPENDIO[$nombre]}"
  if [ -z "$primero" ]; then primero="$clave_cmp"
  elif [ "$clave_cmp" != "$primero" ]; then iguales=0; fi
done

if [ "$algun_fallo" -eq 1 ]; then
  echo "NO_CONCLUYENTE: al menos un nodo no completó la repetición (ver $OUT)" | tee -a "$OUT"
elif [ "$iguales" -eq 1 ]; then
  echo "CONVERGEN (W07d): resumen_estado y compendio_bloques iguales en todos ($primero)" | tee -a "$OUT"
else
  echo "DIVERGEN (W07d, FALLO REAL): resumen_estado/compendio_bloques distintos:" | tee -a "$OUT"
  for espec in "${ESPECS[@]}"; do
    IFS=':' read -r nombre claves <<< "$espec"
    echo "  $nombre: resumen=${RESUMEN[$nombre]:-(fallo)} compendio=${COMPENDIO[$nombre]:-(fallo)}" | tee -a "$OUT"
  done
fi
