#!/usr/bin/env bash
# CORRECCIÓN (2026-09-27, hallazgo del director): una sola clave por nodo (A=0,B=1,C=2,D=3),
# no 0,1,2/3,4,5/6,7,8. Con varias claves por nodo, K_min=3 (PERFIL-DEV-v0.md §3, "una clave por
# nodo de la red de prueba") puede cumplirse con las 3 claves de UN solo nodo si ese nodo mina la
# mayoría de bloques PoW; los demás nodos cruzan el corte sin garantía y, sin relevo de
# transacciones en 0.0.1, ya no pueden depositar ni producir nunca (límite real del producto, no
# del arnés). Verificado en run/E2a-calibracion-intento2-timeout/: B minó 26/31 bloques PoW propios,
# A y C nunca produjeron PoST tras el corte.
# R2 de ORDEN-W07b: E-5, llegada tardía. A,B,C juntos desde el génesis; tras >=500 bloques PoST
# combinados, D arranca en frío (sin --datos previo) marcando a los tres, y debe sincronizar desde
# el génesis al mismo resumen_estado.
# Uso: r2.sh <rep> <puerto_base> <semilla> <sr_dev>
set -uo pipefail
Z=/home/katana/zeo/ZEROX/deepseek/W07b
CLON="$Z/clon-26312ff"
BIN="$CLON/target/release"
source "$Z/scripts/lib_red.sh"

REP="${1:?uso: r2.sh <rep> <puerto_base> <semilla> <sr_dev>}"
PORT_BASE="${2:?falta puerto_base}"
SEMILLA="${3:?falta semilla}"
SRDEV="${4:?falta sr_dev}"
PA="$PORT_BASE"; PB=$((PORT_BASE + 1)); PC=$((PORT_BASE + 2)); PD=$((PORT_BASE + 3))
RUN="$Z/run/R2-$REP"
mkdir -p "$RUN"
VF="$Z/scripts/verif.sh"

sin_zx_node_o_falla
puertos_libres_o_falla "$PA" "$PB" "$PC" "$PD"
escribir_ejecucion_txt
{ echo "semilla=$SEMILLA"; echo "puertos: A=$PA B=$PB C=$PC D=$PD"; } >> "$RUN/EJECUCION.txt"

matar_todo() { matar A "$PA"; matar B "$PB"; matar C "$PC"; matar D "$PD"; }
trap matar_todo EXIT

echo "$(date -Is) === R2 $REP: A,B,C desde el génesis ===" | tee -a "$RUN/EJECUCION.txt"
lanzar_nodo A "0" "$PA" "" "/ip4/127.0.0.1/tcp/$PB" "/ip4/127.0.0.1/tcp/$PC"
lanzar_nodo B "1" "$PB" "" "/ip4/127.0.0.1/tcp/$PA" "/ip4/127.0.0.1/tcp/$PC"
lanzar_nodo C "2" "$PC" "" "/ip4/127.0.0.1/tcp/$PA" "/ip4/127.0.0.1/tcp/$PB"

echo "=== esperando >=500 bloques PoST combinados, plazo 2h ===" | tee -a "$RUN/EJECUCION.txt"
resultado=$("$VF" espera_suma_bloques 500 7200 "$RUN/A/registro.jsonl" "$RUN/B/registro.jsonl" "$RUN/C/registro.jsonl" -- "$RUN/A/stderr.log" "$RUN/B/stderr.log" "$RUN/C/stderr.log")
echo "$resultado" | tee -a "$RUN/EJECUCION.txt"
if ! echo "$resultado" | grep -q "^EXITO"; then
  echo "FALLO: no se alcanzaron 500 bloques combinados" | tee -a "$RUN/EJECUCION.txt"
  echo "PARCIAL" > "$RUN/RESULTADO.txt"
  cerrar_ejecucion_txt; matar_todo; trap - EXIT; touch "$RUN/.done"; exit 2
fi

echo "=== lanzando D tardío en frío (clave 3, --datos nuevo), marcando a los tres ===" | tee -a "$RUN/EJECUCION.txt"
t_ibd_inicio=$(date +%s%N)
lanzar_nodo D "3" "$PD" "" "/ip4/127.0.0.1/tcp/$PA" "/ip4/127.0.0.1/tcp/$PB" "/ip4/127.0.0.1/tcp/$PC"

echo "=== midiendo alcance de D, plazo 30 min ===" | tee -a "$RUN/EJECUCION.txt"
FIN=$(( $(date +%s) + 1800 ))
while :; do
  fatal=$("$VF" hay_fatal "$RUN"/*/stderr.log)
  if [ -n "$fatal" ]; then echo "FALLO_FATAL: $fatal" | tee -a "$RUN/EJECUCION.txt"; break; fi
  slot_a=$("$VF" ultimo_slot_conocido "$RUN/A/registro.jsonl")
  slot_d=$("$VF" ultimo_slot_conocido "$RUN/D/registro.jsonl")
  huerfanos_d=$("$VF" huerfanos_actuales "$RUN/D/registro.jsonl")
  diff=$(( ${slot_a:-0} - ${slot_d:-0} ))
  if [ "$diff" -le 2 ]; then
    t_ibd_fin=$(date +%s%N)
    echo "D alcanzó a A: slot_a=$slot_a slot_d=$slot_d huerfanos_d=$huerfanos_d" | tee -a "$RUN/EJECUCION.txt"
    echo "t_ibd_inicio_ns=$t_ibd_inicio t_ibd_fin_ns=$t_ibd_fin duracion_ibd_ns=$((t_ibd_fin - t_ibd_inicio))" >> "$RUN/EJECUCION.txt"
    break
  fi
  if [ "$(date +%s)" -ge "$FIN" ]; then
    echo "TIMEOUT: slot_a=$slot_a slot_d=$slot_d diff=$diff" | tee -a "$RUN/EJECUCION.txt"
    break
  fi
  sleep 3
done

# Bytes transferidos por D: aproximado con read_bytes/write_bytes de /proc (recursos-D.csv), ya
# que el esquema no expone bytes de red por evento agregados; se declara la aproximación.
if [ -f "$RUN/recursos-D.csv" ]; then
  primera=$(head -1 "$RUN/recursos-D.csv")
  ultima=$(tail -1 "$RUN/recursos-D.csv")
  echo "recursos-D primera_muestra=$primera ultima_muestra=$ultima" >> "$RUN/EJECUCION.txt"
fi

echo "=== reposo (mismo --dejar-de-producir-en-slot en los 4) ===" | tee -a "$RUN/EJECUCION.txt"
slot_a_r=$("$VF" ultimo_slot_conocido "$RUN/A/registro.jsonl")
slot_b_r=$("$VF" ultimo_slot_conocido "$RUN/B/registro.jsonl")
slot_c_r=$("$VF" ultimo_slot_conocido "$RUN/C/registro.jsonl")
slot_d_r=$("$VF" ultimo_slot_conocido "$RUN/D/registro.jsonl")
SLOT_REPOSO=$slot_a_r
for s in "$slot_b_r" "$slot_c_r" "$slot_d_r"; do [ "$s" -gt "$SLOT_REPOSO" ] && SLOT_REPOSO="$s"; done
SLOT_REPOSO=$((SLOT_REPOSO + 5))
echo "slot_reposo calculado=$SLOT_REPOSO (max(A=$slot_a_r,B=$slot_b_r,C=$slot_c_r,D=$slot_d_r)+5)" | tee -a "$RUN/EJECUCION.txt"
matar A "$PA"; matar B "$PB"; matar C "$PC"; matar D "$PD"
lanzar_nodo A "0" "$PA" "$SLOT_REPOSO" "/ip4/127.0.0.1/tcp/$PB" "/ip4/127.0.0.1/tcp/$PC" "/ip4/127.0.0.1/tcp/$PD"
lanzar_nodo B "1" "$PB" "$SLOT_REPOSO" "/ip4/127.0.0.1/tcp/$PA" "/ip4/127.0.0.1/tcp/$PC" "/ip4/127.0.0.1/tcp/$PD"
lanzar_nodo C "2" "$PC" "$SLOT_REPOSO" "/ip4/127.0.0.1/tcp/$PA" "/ip4/127.0.0.1/tcp/$PB" "/ip4/127.0.0.1/tcp/$PD"
lanzar_nodo D "3" "$PD" "$SLOT_REPOSO" "/ip4/127.0.0.1/tcp/$PA" "/ip4/127.0.0.1/tcp/$PB" "/ip4/127.0.0.1/tcp/$PC"

FIN=$(( $(date +%s) + 1800 ))
while :; do
  fatal=$("$VF" hay_fatal "$RUN"/*/stderr.log)
  if [ -n "$fatal" ]; then echo "FALLO_FATAL (reposo): $fatal" | tee -a "$RUN/EJECUCION.txt"; break; fi
  listos=$("$VF" reposo_listos "$RUN/A/registro.jsonl" "$RUN/B/registro.jsonl" "$RUN/C/registro.jsonl" "$RUN/D/registro.jsonl")
  if [ "${listos:-0}" -eq 4 ]; then echo "reposo alcanzado en los 4" | tee -a "$RUN/EJECUCION.txt"; break; fi
  if [ "$(date +%s)" -ge "$FIN" ]; then echo "TIMEOUT reposo: listos=$listos" | tee -a "$RUN/EJECUCION.txt"; break; fi
  sleep 3
done
FIN=$(( $(date +%s) + 300 ))
while :; do
  quieto=1
  for n in A B C D; do
    hace=$("$VF" ultimo_cambio_punta_hace_ns "$RUN/$n/registro.jsonl")
    if [ "${hace:-0}" -lt 30000000000 ]; then quieto=0; fi
  done
  if [ "$quieto" -eq 1 ]; then break; fi
  if [ "$(date +%s)" -ge "$FIN" ]; then break; fi
  sleep 3
done

echo "=== resultado final (los 4, método antiguo, informativo) ===" | tee -a "$RUN/EJECUCION.txt"
"$VF" todos_los_resumenes_iguales "$RUN/A/registro.jsonl" "$RUN/B/registro.jsonl" "$RUN/C/registro.jsonl" "$RUN/D/registro.jsonl" | tee "$RUN/RESULTADO-metodo-viejo.txt"
# CORRECCIÓN DEL DIRECTOR (2026-09-27): E-3/"mismo estado" no es decisivo hasta W07d. Se paran los
# nodos y se conservan sus `datos` para repetir la verificación con el binario nuevo.
matar A "$PA"; matar B "$PB"; matar C "$PC"; matar D "$PD"
echo "E-5 (mismo estado): PENDIENTE DE VERIFICACIÓN CON EL BINARIO DE W07D (datos conservados; ver RESULTADO-metodo-viejo.txt como informativo, no decisivo)" | tee "$RUN/RESULTADO.txt"
cerrar_ejecucion_txt
matar_todo
trap - EXIT
touch "$RUN/.done"
echo "=== R2 $REP TERMINADO ==="
