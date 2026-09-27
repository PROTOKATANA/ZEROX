#!/usr/bin/env bash
# verificar_e3_aislado.sh — método nuevo de E-3 (corrección del director, 2026-09-27), para usar
# tras el reposo en cualquier escenario que compare "mismo estado" entre nodos.
#
# Diagnóstico que motiva esto: `resumen_estado` solo se escribe en el evento `cambio_punta`. Un
# bloque lateral admitido DESPUÉS del último `cambio_punta` (antes de un SIGKILL) puede cambiar el
# estado virtual sin que quede un resumen nuevo escrito. No es una divergencia de consenso real, es
# un artefacto de CUÁNDO se escribió el último resumen.
#
# Método (sin tocar el nodo): tras el reposo, SIGKILL a los tres (ya hecho por el llamador). Cada
# nodo se relanza POR SEPARADO Y AISLADO (sin --red-marcar, su propio puerto, MISMO --datos, pero
# un `--registro` NUEVO -- corrección de arnés: reutilizar el registro.jsonl original hacía que
# `reinicio_completo`/el conteo de líneas reflejaran el E-4 de mitad de partida, no esta repetición,
# dando un falso "ya está quieto" casi instantáneo) y con `--dejar-de-producir-en-slot` MENOR que su
# slot actual (para que no produzca nada nuevo): así repite entero su almacén. Se espera
# `reinicio_completo` en el registro NUEVO (confirma que la repetición terminó) y se toma el ÚLTIMO
# `cambio_punta` del registro completo — comprobado empíricamente (run/R1-rep1/A/registro-e3aislado.jsonl)
# que `reinicio_completo` se escribe SIEMPRE al final, después de todos los cambio_punta de la
# repetición, nunca antes; buscar uno "posterior" (como se planteó al principio) no encuentra nada.
# Se compara el `resumen_estado` de esa última línea entre los tres.
#
# Uso: verificar_e3_aislado.sh <RUN_dir> <SRDEV> <SEMILLA> "<nombre>:<claves>:<puerto>" ...
set -uo pipefail
Z=/home/katana/zeo/ZEROX/deepseek/W07b
CLON="$Z/clon-26312ff"; BIN="$CLON/target/release"
VF="$Z/scripts/verif.sh"

RUN="${1:?uso: verificar_e3_aislado.sh <RUN_dir> <SRDEV> <SEMILLA> \"nombre:claves:puerto\" ...}"
SRDEV="${2:?falta SRDEV}"
SEMILLA="${3:?falta SEMILLA}"
shift 3
ESPECS=("$@")
[ "${#ESPECS[@]}" -ge 1 ] || { echo "FALLO: no se dieron especificaciones de nodo"; exit 2; }

OUT="$RUN/E3-AISLADO.txt"
: > "$OUT"   # limpio en cada invocación (por si se repite): no es un registro crudo, es mi informe.
echo "$(date -Is) === verificación E-3 aislada (método nuevo, registro separado) ===" >> "$OUT"

lanzar_aislado() {
  local nombre="$1" claves="$2" puerto="$3" dejar="$4"
  local reg="$RUN/$nombre/registro-e3aislado.jsonl"
  : > "$reg"
  nohup "$BIN/zx-node" \
    --datos "$RUN/$nombre/datos" \
    --registro "$reg" \
    --claves "$claves" \
    --n-dev 138873760 \
    --semilla "$SEMILLA" \
    --sr-dev "$SRDEV" \
    --red-escuchar "/ip4/127.0.0.1/tcp/$puerto" \
    --dejar-de-producir-en-slot "$dejar" \
    >> "$RUN/$nombre/stdout-e3aislado.log" 2>> "$RUN/$nombre/stderr-e3aislado.log" &
  echo $! > "$RUN/$nombre/pid-e3aislado"
  disown
  echo "$(date -Is) lanzado $nombre (aislado, registro nuevo) pid=$(cat "$RUN/$nombre/pid-e3aislado")" >> "$OUT"
}

matar_aislado() {
  local nombre="$1" puerto="$2"
  local f="$RUN/$nombre/pid-e3aislado"
  [ -f "$f" ] || return 0
  local pid; pid=$(cat "$f")
  kill -9 "$pid" 2>/dev/null || true
  for _ in $(seq 1 100); do kill -0 "$pid" 2>/dev/null || break; sleep 0.1; done
  for _ in $(seq 1 100); do ss -ltn 2>/dev/null | grep -q ":$puerto " || break; sleep 0.1; done
}

# 0. confirmar que no queda ningún zx-node vivo de la ejecución ORIGINAL (pid normal, no el
#    -e3aislado) antes de tocar nada.
for espec in "${ESPECS[@]}"; do
  IFS=':' read -r nombre claves puerto <<< "$espec"
  if [ -f "$RUN/$nombre/pid" ]; then
    pid=$(cat "$RUN/$nombre/pid")
    if kill -0 "$pid" 2>/dev/null; then
      echo "FALLO: $nombre (pid $pid, ejecución original) sigue vivo; el llamador debía haberlo matado antes" >> "$OUT"
      echo "FALLO: $nombre sigue vivo"
      exit 2
    fi
  fi
done

# 1-2. relanzar cada nodo aislado, sin producir, con registro NUEVO.
for espec in "${ESPECS[@]}"; do
  IFS=':' read -r nombre claves puerto <<< "$espec"
  slot_actual=$("$VF" ultimo_slot_conocido "$RUN/$nombre/registro.jsonl")
  slot_actual=${slot_actual:-0}
  dejar=$(( slot_actual > 0 ? slot_actual - 1 : 0 ))
  echo "$nombre: slot_actual_previo=$slot_actual, dejar-de-producir-en-slot=$dejar" >> "$OUT"
  lanzar_aislado "$nombre" "$claves" "$puerto" "$dejar"
done

echo "$(date -Is) esperando reinicio_completo en los registros NUEVOS (plazo 10 min) ..." >> "$OUT"
FIN=$(( $(date +%s) + 600 ))
while :; do
  fatal=$("$VF" hay_fatal "$RUN"/*/stderr-e3aislado.log)
  if [ -n "$fatal" ]; then echo "FALLO_FATAL en la repetición aislada: $fatal" >> "$OUT"; echo "FALLO_FATAL"; exit 1; fi
  todos_listos=1
  for espec in "${ESPECS[@]}"; do
    IFS=':' read -r nombre claves puerto <<< "$espec"
    rc=$("$VF" contar_evento "$RUN/$nombre/registro-e3aislado.jsonl" reinicio_completo)
    if [ "${rc:-0}" -lt 1 ]; then todos_listos=0; fi
  done
  if [ "$todos_listos" -eq 1 ]; then echo "$(date -Is) reinicio_completo visto en todos (registro nuevo)" >> "$OUT"; break; fi
  if [ "$(date +%s)" -ge "$FIN" ]; then echo "TIMEOUT esperando reinicio_completo" >> "$OUT"; echo "TIMEOUT"; exit 2; fi
  sleep 3
done

# Esperar a que cada registro NUEVO deje de crecer (repetición terminada).
for espec in "${ESPECS[@]}"; do
  IFS=':' read -r nombre claves puerto <<< "$espec"
  reg="$RUN/$nombre/registro-e3aislado.jsonl"
  prev=-1
  quieto=0
  FIN2=$(( $(date +%s) + 300 ))
  cur=0
  while [ "$(date +%s)" -lt "$FIN2" ]; do
    cur=$(wc -l < "$reg" 2>/dev/null)
    cur=${cur:-0}
    if [ "$cur" = "$prev" ]; then
      quieto=$((quieto + 1))
      if [ "$quieto" -ge 3 ]; then break; fi
    else
      quieto=0
    fi
    prev="$cur"
    sleep 2
  done
  echo "$(date -Is) $nombre: registro-e3aislado quieto en $cur líneas" >> "$OUT"
done

# 3 (cont.). comprobar EMPÍRICAMENTE que existe un cambio_punta posterior a reinicio_completo.
declare -A RESUMEN
fallo_sin_evento=0
for espec in "${ESPECS[@]}"; do
  IFS=':' read -r nombre claves puerto <<< "$espec"
  reg="$RUN/$nombre/registro-e3aislado.jsonl"
  linea=$("$VF" resumen_tras_reinicio "$reg")
  if [ -z "$linea" ]; then
    echo "FALLO: $nombre no tiene ningún cambio_punta posterior a reinicio_completo (repetición sin efecto observable)" >> "$OUT"
    fallo_sin_evento=1
    continue
  fi
  r=$(echo "$linea" | grep -o '"resumen_estado":"[^"]*"')
  p=$(echo "$linea" | grep -o '"punta":"[^"]*"')
  RESUMEN[$nombre]="$r"
  echo "$nombre: punta=$p resumen=$r" >> "$OUT"
done

for espec in "${ESPECS[@]}"; do
  IFS=':' read -r nombre claves puerto <<< "$espec"
  matar_aislado "$nombre" "$puerto"
done

if [ "$fallo_sin_evento" -eq 1 ]; then
  echo "FALLO: al menos un nodo no tiene cambio_punta posterior a reinicio_completo; ver $OUT" | tee -a "$OUT"
  echo "NO_CONCLUYENTE_SIN_EVENTO"
  exit 3
fi

primero=""; iguales=1
for espec in "${ESPECS[@]}"; do
  IFS=':' read -r nombre claves puerto <<< "$espec"
  if [ -z "$primero" ]; then primero="${RESUMEN[$nombre]}"
  elif [ "${RESUMEN[$nombre]}" != "$primero" ]; then iguales=0; fi
done

if [ "$iguales" -eq 1 ]; then
  echo "CONVERGEN (aislado) resumen=$primero" | tee -a "$OUT"
else
  echo "DIVERGEN (aislado, tras repetir el almacén completo -- esto SÍ sería un fallo real):" | tee -a "$OUT"
  for espec in "${ESPECS[@]}"; do
    IFS=':' read -r nombre claves puerto <<< "$espec"
    echo "  $nombre: ${RESUMEN[$nombre]}" | tee -a "$OUT"
  done
fi
