#!/usr/bin/env bash
# reposo_y_verificar.sh — decisión 6 de la orden ("todos los nodos con el mismo
# --dejar-de-producir-en-slot; se espera... y a que no haya cambio_punta durante 30s; entonces se
# compara") + el método nuevo de comparación de estado (verificar_e3_aislado.sh, corrección del
# director 2026-09-27). Uso general para "mismo estado" en cualquier escenario (E-3, E-6, E-6b,
# E-7/E-8, E-9), no solo R1.
#
# Procedimiento:
#   1. slot_reposo = max(ultimo_slot_conocido de cada nodo) + 5.
#   2. mata y relanza cada nodo CONECTADO a los demás (sigue validando/propagando/sincronizando,
#      decisión 6) con --dejar-de-producir-en-slot=slot_reposo.
#   3. espera dejar_de_producir en todos, luego 30s sin cambio_punta en ninguno.
#   4. SIGKILL a todos; llama a verificar_e3_aislado.sh (repite el almacén aislado, registro nuevo,
#      compara el resumen_estado del último cambio_punta posterior a reinicio_completo).
#
# Uso: reposo_y_verificar.sh <RUN_dir> <SRDEV> <SEMILLA> "<nombre>:<claves>:<puerto>" ...
# Requiere que los nodos ESTÉN VIVOS y conectados entre sí en el momento de invocar (con --datos ya
# en marcha); los relanza él mismo para el reposo.
set -uo pipefail
Z=/home/katana/zeo/ZEROX/deepseek/W07b
CLON="$Z/clon-26312ff"; BIN="$CLON/target/release"
source "$Z/scripts/lib_red.sh"
VF="$Z/scripts/verif.sh"

RUN="${1:?uso: reposo_y_verificar.sh <RUN_dir> <SRDEV> <SEMILLA> \"nombre:claves:puerto\" ...}"
SRDEV="${2:?falta SRDEV}"
SEMILLA="${3:?falta SEMILLA}"
shift 3
ESPECS=("$@")
[ "${#ESPECS[@]}" -ge 1 ] || { echo "FALLO: no se dieron especificaciones de nodo"; exit 2; }

echo "$(date -Is) === reposo_y_verificar: calculando slot_reposo ===" >> "$RUN/EJECUCION.txt"
slot_reposo=0
for espec in "${ESPECS[@]}"; do
  IFS=':' read -r nombre claves puerto <<< "$espec"
  s=$("$VF" ultimo_slot_conocido "$RUN/$nombre/registro.jsonl")
  s=${s:-0}
  [ "$s" -gt "$slot_reposo" ] && slot_reposo="$s"
done
slot_reposo=$((slot_reposo + 5))
echo "slot_reposo=$slot_reposo" >> "$RUN/EJECUCION.txt"

# matar y relanzar todos conectados entre sí, con dejar-de-producir=slot_reposo.
for espec in "${ESPECS[@]}"; do
  IFS=':' read -r nombre claves puerto <<< "$espec"
  matar "$nombre" "$puerto"
done
for espec in "${ESPECS[@]}"; do
  IFS=':' read -r nombre claves puerto <<< "$espec"
  marcar_args=()
  for otro in "${ESPECS[@]}"; do
    IFS=':' read -r otro_nombre otro_claves otro_puerto <<< "$otro"
    [ "$otro_nombre" != "$nombre" ] && marcar_args+=("/ip4/127.0.0.1/tcp/$otro_puerto")
  done
  lanzar_nodo "$nombre" "$claves" "$puerto" "$slot_reposo" "${marcar_args[@]}" >> "$RUN/EJECUCION.txt"
done

echo "=== esperando dejar_de_producir en todos, plazo 30 min ===" >> "$RUN/EJECUCION.txt"
FIN=$(( $(date +%s) + 1800 ))
regs=()
for espec in "${ESPECS[@]}"; do
  IFS=':' read -r nombre claves puerto <<< "$espec"
  regs+=("$RUN/$nombre/registro.jsonl")
done
while :; do
  fatal=$("$VF" hay_fatal "$RUN"/*/stderr.log)
  if [ -n "$fatal" ]; then echo "FALLO_FATAL en el reposo: $fatal" >> "$RUN/EJECUCION.txt"; echo "FALLO_FATAL"; exit 1; fi
  listos=$("$VF" reposo_listos "${regs[@]}")
  if [ "${listos:-0}" -eq "${#ESPECS[@]}" ]; then echo "reposo alcanzado en todos" >> "$RUN/EJECUCION.txt"; break; fi
  if [ "$(date +%s)" -ge "$FIN" ]; then echo "TIMEOUT esperando reposo: listos=$listos" >> "$RUN/EJECUCION.txt"; break; fi
  sleep 3
done

echo "=== esperando 30s sin cambio_punta en ninguno ===" >> "$RUN/EJECUCION.txt"
FIN=$(( $(date +%s) + 300 ))
while :; do
  quieto=1
  for espec in "${ESPECS[@]}"; do
    IFS=':' read -r nombre claves puerto <<< "$espec"
    hace=$("$VF" ultimo_cambio_punta_hace_ns "$RUN/$nombre/registro.jsonl")
    if [ "${hace:-0}" -lt 30000000000 ]; then quieto=0; fi
  done
  if [ "$quieto" -eq 1 ]; then echo "30s sin cambio_punta en todos" >> "$RUN/EJECUCION.txt"; break; fi
  if [ "$(date +%s)" -ge "$FIN" ]; then echo "TIMEOUT esperando silencio" >> "$RUN/EJECUCION.txt"; break; fi
  sleep 3
done

# CORRECCIÓN DEL DIRECTOR (2026-09-27, tras verificar en el código `nodo.rs:1241`
# `registrar_cambio_de_punta`): el propio método "aislado" (último cambio_punta tras repetir el
# almacén) TAMBIÉN puede estar desfasado — esa función sale sin escribir si la punta seleccionada no
# cambia, y `reinicio_completo` no lleva resumen; si los últimos bloques repetidos son laterales, el
# último resumen registrado sigue siendo anterior a ellos. No es un fallo del arnés: lo corrige la
# orden W07d (registro nuevo, en marcha), añadiendo el resumen del estado virtual tras la repetición.
# Mientras tanto NINGÚN método de comparación de estado es decisivo. Se conserva la lectura EN VIVO
# (informativa) y se para aquí: el veredicto de "mismo estado" queda pendiente hasta W07d, que
# repetirá esta misma verificación aislada con el binario nuevo sobre los `datos` conservados.
for espec in "${ESPECS[@]}"; do
  IFS=':' read -r nombre claves puerto <<< "$espec"
  matar "$nombre" "$puerto"
done

echo "PENDIENTE_DE_VERIFICACION_CON_W07D (ningún método de comparación de estado es decisivo hasta que reinicio_completo lleve resumen_estado; datos conservados en $RUN/*/datos)"
