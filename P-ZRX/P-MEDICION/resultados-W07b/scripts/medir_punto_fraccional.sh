#!/usr/bin/env bash
# medir_punto_fraccional.sh — E-2a, continuación manual de la bisección con exponentes
# FRACCIONARIOS (corrección del director: entre exponentes enteros consecutivos puede no caer
# ningún valor en [0.8,1.2], así que hace falta refinar en el propio exponente, no solo en enteros).
# Reutiliza lib_red.sh y el MISMO --datos ya con el corte cruzado (no se vuelve a cruzar el corte).
#
# Uso: medir_punto_fraccional.sh <RUN_dir> <PA> <PB> <PC> <SEMILLA> <tau_medido> <punto_num> <exponente>
# <exponente> puede llevar decimales (p. ej. 62.5). sr_dev = floor(2^exponente), calculado en
# awk (aritmética de coma flotante de doble precisión; con exponente > ~53 hay redondeo de los
# bits menos significativos de sr_dev, irrelevante para el objetivo de bloques/slot buscado —
# declarado, no oculto).
set -uo pipefail
Z=/home/katana/zeo/ZEROX/deepseek/W07b
CLON="$Z/clon-26312ff"; BIN="$CLON/target/release"
source "$Z/scripts/lib_red.sh"

RUN="${1:?uso: medir_punto_fraccional.sh <RUN_dir> <PA> <PB> <PC> <SEMILLA> <tau_medido> <punto_num> <exponente>}"
PA="${2:?}"; PB="${3:?}"; PC="${4:?}"; SEMILLA="${5:?}"; tau_medido="${6:?}"; punto="${7:?}"; exp="${8:?}"
VF="$Z/scripts/verif.sh"
TABLA="$RUN/TABLA.tsv"

sr=$(awk -v e="$exp" 'BEGIN{v=2^e; printf "%.0f", v}')
sr=$(awk -v s="$sr" 'BEGIN{maxv=18446744073709551615; if (s+0 > maxv) print maxv; else print s}')
SRDEV="$sr"

echo "$(date -Is) === E-2a punto $punto (fraccionario): exponente=$exp sr_dev=$sr ===" >> "$RUN/EJECUCION.txt"
lanzar_nodo A "0" "$PA" "" "/ip4/127.0.0.1/tcp/$PB" "/ip4/127.0.0.1/tcp/$PC" >> "$RUN/EJECUCION.txt"
lanzar_nodo B "1" "$PB" "" "/ip4/127.0.0.1/tcp/$PA" "/ip4/127.0.0.1/tcp/$PC" >> "$RUN/EJECUCION.txt"
lanzar_nodo C "2" "$PC" "" "/ip4/127.0.0.1/tcp/$PA" "/ip4/127.0.0.1/tcp/$PB" >> "$RUN/EJECUCION.txt"
sleep 3
slot0=$("$VF" ultimo_slot_conocido "$RUN/A/registro.jsonl")
bloques0=$("$VF" total_post_dag "$RUN/A/registro.jsonl")
t0=$(date +%s)
ventana_s=$(awk -v tau="$tau_medido" 'BEGIN{v=200*tau; printf "%d", (v==int(v))?v:int(v)+1}')
fin_s=$((t0 + ventana_s))
while [ "$(date +%s)" -lt "$fin_s" ]; do
  if [ -n "$("$VF" hay_fatal "$RUN"/*/stderr.log)" ]; then echo "FALLO_FATAL en punto $punto" >> "$RUN/EJECUCION.txt"; break; fi
  sleep 3
done
slot1=$("$VF" ultimo_slot_conocido "$RUN/A/registro.jsonl")
bloques1=$("$VF" total_post_dag "$RUN/A/registro.jsonl")
t1=$(date +%s)
segundos_reales=$(( t1 - t0 ))
bloques_delta=$(( bloques1 - bloques0 ))
bxs=$(awk -v b="$bloques_delta" -v s="$segundos_reales" -v tau="$tau_medido" 'BEGIN{ slots=s/tau; if (slots>0) printf "%.4f", b/slots; else print "0.0000" }')
slots_transcurridos=$(awk -v s="$segundos_reales" -v tau="$tau_medido" 'BEGIN{printf "%.4f", s/tau}')
echo -e "${punto}\t${exp}\t${sr}\t${segundos_reales}\t${tau_medido}\t${slots_transcurridos}\t${bloques_delta}\t${bxs}\t${slot0}\t${slot1}" >> "$TABLA"
echo "punto $punto (fraccionario): exponente=$exp bloques/slot=$bxs" >> "$RUN/EJECUCION.txt"
matar A "$PA" >> "$RUN/EJECUCION.txt"; matar B "$PB" >> "$RUN/EJECUCION.txt"; matar C "$PC" >> "$RUN/EJECUCION.txt"
echo "$bxs"
