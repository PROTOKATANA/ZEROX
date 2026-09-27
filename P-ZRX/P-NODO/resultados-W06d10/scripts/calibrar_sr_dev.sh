#!/usr/bin/env bash
# CORRECCIÓN (2026-09-27, hallazgo del director): una sola clave por nodo (A=0,B=1,C=2,D=3),
# no 0,1,2/3,4,5/6,7,8. Con varias claves por nodo, K_min=3 (PERFIL-DEV-v0.md §3, "una clave por
# nodo de la red de prueba") puede cumplirse con las 3 claves de UN solo nodo si ese nodo mina la
# mayoría de bloques PoW; los demás nodos cruzan el corte sin garantía y, sin relevo de
# transacciones en 0.0.1, ya no pueden depositar ni producir nunca (límite real del producto, no
# del arnés). Verificado en run/E2a-calibracion-intento2-timeout/: B minó 26/31 bloques PoW propios,
# A y C nunca produjeron PoST tras el corte.
# E-2a de ORDEN-W07b: calibración de SR_dev. Tres nodos cruzan el corte UNA vez (con SR_dev por
# defecto de la CLI, u64::MAX, el más fácil posible); durante esa misma fase se MIDE (no se asume)
# la duración real del slot τ en esta máquina/carga, con varias muestras de (slot, reloj_pared_ns)
# del propio registro. A partir de ahí, sin volver a cruzar el corte (mismo --datos persistido), se
# reinicia la red con cada candidato --sr-dev y se miden 200 slots por punto (ventana de pared =
# 200·τ_medido): bloques PoST distintos admitidos (vistos por A) / slots transcurridos. Bisección en
# escala logarítmica sobre el exponente de SR_dev, hasta 6 puntos, buscando [0.8, 1.2] bloques/slot.
#
# CORRECCIONES DE ARNÉS (2026-09-27, tras el primer intento real; ver `run/E2a-calibracion-intento1-buggy/`,
# conservado sin borrar):
#
# 1. (hallada por el ejecutor) `bxs=$(medir_punto ...)` capturaba TODO el stdout de la función, no
#    solo la última línea: con `echo ... | tee -a ...` dentro de la función y con `lanzar_nodo`
#    (lib_red.sh) escribiendo "lanzado <nombre> pid=..." a stdout, `$bxs` quedaba con las líneas de
#    log delante del número. `awk -v x="$bxs"` tomaba el prefijo numérico de la PRIMERA línea (un
#    `date -Is` como "2026-09-27T11:31:...") como el número **2026**, invirtiendo la comparación
#    bajo/alto y corrompiendo la bisección (se vio en vivo: exponente 32 -> 16 en vez de 32 -> 48).
#    Corregido: dentro de `medir_punto`, todo el log va a `$RUN/EJECUCION.txt` directamente (nunca a
#    stdout); el único stdout de la función es el `echo "$bxs"` final.
# 2. (diagnóstico y corrección del director) Con SR_dev muy bajo (p. ej. 2^32) nadie produce en 200
#    "slots", y `ultimo_slot_conocido` (que solo lee el slot del último bloque VISTO) nunca avanza
#    aunque el reloj PoT del nodo sí lo haga: no hay evento periódico de "slot actual" en el ESQUEMA.
#    Corregido: se MIDE τ (duración real del slot) una vez, en la fase SR=u64::MAX (donde sí hay
#    bloques en casi todos los slots), a partir de pares (slot, reloj_pared_ns) reales de A; cada
#    punto siguiente usa una ventana de PARED de `200·τ_medido` segundos, y los "slots transcurridos"
#    se calculan como `segundos_reales/τ_medido`, nunca del conteo de bloques. Un punto con 0 bloques
#    es un resultado válido (SR_dev demasiado bajo), no un error: el guion sigue con el siguiente punto.
# 3. (corrección del director) La bisección no empieza en [0,64]: con SR=u64::MAX ya se observan
#    varios bloques por slot combinados (los 3 nodos producen casi cada slot), así que el punto
#    buscado está algo por debajo de 64, no en el centro del rango completo. Se acota a exponentes
#    [56, 64].
set -uo pipefail
Z=/home/katana/zeo/ZEROX/deepseek/W06d10
CLON="$Z/ws"; BIN="$CLON/target/release"
source "$Z/scripts/lib_red.sh"

PORT_BASE="${1:?uso: calibrar_sr_dev.sh <puerto_base> <semilla>}"
SEMILLA="${2:?falta semilla}"
PA="$PORT_BASE"; PB=$((PORT_BASE + 1)); PC=$((PORT_BASE + 2))
RUN="$Z/run/E2a-calibracion"
mkdir -p "$RUN"
VF="$Z/scripts/verif.sh"
TABLA="$RUN/TABLA.tsv"
echo -e "punto\texponente\tsr_dev\tsegundos_reales\ttau_medido_s\tslots_transcurridos\tbloques_delta\tbloques_por_slot\tslot0_proxy\tslot1_proxy" > "$TABLA"

sin_zx_node_o_falla
puertos_libres_o_falla "$PA" "$PB" "$PC"
escribir_ejecucion_txt
{ echo "semilla=$SEMILLA"; echo "puertos: A=$PA B=$PB C=$PC"; echo "objetivo=[0.8,1.2] bloques/slot; max 6 puntos; bisección en exponentes [56,64]"; } >> "$RUN/EJECUCION.txt"

matar_todo() { matar A "$PA"; matar B "$PB"; matar C "$PC"; }
trap matar_todo EXIT

echo "$(date -Is) === E-2a: cruzando el corte con SR_dev por defecto (u64::MAX, sin --sr-dev) ===" >> "$RUN/EJECUCION.txt"
unset SRDEV
lanzar_nodo A "0" "$PA" "" "/ip4/127.0.0.1/tcp/$PB" "/ip4/127.0.0.1/tcp/$PC" >> "$RUN/EJECUCION.txt"
lanzar_nodo B "1" "$PB" "" "/ip4/127.0.0.1/tcp/$PA" "/ip4/127.0.0.1/tcp/$PC" >> "$RUN/EJECUCION.txt"
lanzar_nodo C "2" "$PC" "" "/ip4/127.0.0.1/tcp/$PA" "/ip4/127.0.0.1/tcp/$PB" >> "$RUN/EJECUCION.txt"

FIN=$(( $(date +%s) + 900 ))
while :; do
  fatal=$("$VF" hay_fatal "$RUN"/*/stderr.log)
  if [ -n "$fatal" ]; then echo "FALLO_FATAL cruzando el corte: $fatal" >> "$RUN/EJECUCION.txt"; exit 1; fi
  pa=$("$VF" contar_evento "$RUN/A/registro.jsonl" bloque_producido)
  pb=$("$VF" contar_evento "$RUN/B/registro.jsonl" bloque_producido)
  pc=$("$VF" contar_evento "$RUN/C/registro.jsonl" bloque_producido)
  # CORRECCIÓN DE ARNÉS (2026-09-27, intento2-timeout): exigir que CADA nodo produzca >=1 bloque
  # propio es innecesariamente estricto para esta calibración auxiliar (no es E-1 en sí, solo
  # necesita que la red haya cruzado el corte y produzca PoST para poder medir tau y bisecar). Se
  # observó en vivo (`run/E2a-calibracion-intento2-timeout/`) que, tras un breve parpadeo de
  # conexión inicial entre A y B (par_conectado seguido de par_desconectado a los pocos µs, ambos
  # reconectados después), B produjo 413 bloques en ~440s mientras A y C se quedaron en 0 —
  # probablemente por quedarse rezagados sincronizando el ritmo de B en vez de producir el suyo
  # propio (hipótesis, no confirmada; se anota como riesgo a vigilar en R1/E-1, donde el criterio SÍ
  # exige que los 3 produzcan). Para la calibración basta con producción combinada.
  if [ $(( ${pa:-0} + ${pb:-0} + ${pc:-0} )) -ge 3 ]; then
    echo "corte cruzado (producción combinada, A=$pa B=$pb C=$pc)" >> "$RUN/EJECUCION.txt"
    break
  fi
  if [ "$(date +%s)" -ge "$FIN" ]; then echo "TIMEOUT cruzando el corte" >> "$RUN/EJECUCION.txt"; exit 2; fi
  sleep 3
done

echo "=== midiendo tau (duración real del slot) durante 60s más de producción a SR=u64::MAX ===" >> "$RUN/EJECUCION.txt"
sleep 60

# tau_medido = (t_max - t_min) / (slot_max - slot_min) sobre los pares (slot, reloj_pared_ns) de A
# (bloque_producido propio o bloque_red_admitido familia post ajeno), en bash puro (sin Python).
medir_tau() {
  local reg="$1"
  local pares
  pares=$(grep -E '"tipo":"(bloque_producido|bloque_red_admitido)"' "$reg" 2>/dev/null | grep '"slot"' \
    | awk '{
        match($0, /"slot":[0-9]+/); s=substr($0, RSTART+7, RLENGTH-7);
        match($0, /"reloj_pared_ns":[0-9]+/); t=substr($0, RSTART+17, RLENGTH-17);
        print s, t
      }')
  echo "$pares" | awk '
    { if ($1+0==$1) { if (mins=="" || $1<mins) {mins=$1; tmin=$2}; if (maxs=="" || $1>maxs) {maxs=$1; tmax=$2} } }
    END {
      if (maxs=="" || maxs==mins) { print "0"; exit }
      dslot = maxs - mins
      dt = tmax - tmin
      printf "%.6f", (dt/1000000000.0) / dslot
    }'
}
tau_medido=$(medir_tau "$RUN/A/registro.jsonl")
if [ -z "$tau_medido" ] || [ "$tau_medido" = "0" ]; then
  echo "AVISO: no se pudo medir tau desde A (pocas muestras); probando con B" >> "$RUN/EJECUCION.txt"
  tau_medido=$(medir_tau "$RUN/B/registro.jsonl")
fi
if [ -z "$tau_medido" ] || [ "$tau_medido" = "0" ]; then
  echo "FALLO: no se pudo medir tau (ni A ni B tienen suficientes muestras de slot). Abortando E-2a." >> "$RUN/EJECUCION.txt"
  cerrar_ejecucion_txt; matar_todo; trap - EXIT; touch "$RUN/.done"
  echo "FALLO: no se pudo medir tau"
  exit 3
fi
echo "tau_medido=${tau_medido}s (medido en la fase SR=u64::MAX, $(date -Is))" >> "$RUN/EJECUCION.txt"
echo "tau_medido=$tau_medido" >> "$RUN/EJECUCION.txt"

matar A "$PA" >> "$RUN/EJECUCION.txt"; matar B "$PB" >> "$RUN/EJECUCION.txt"; matar C "$PC" >> "$RUN/EJECUCION.txt"

medir_punto() {
  local punto="$1" exp="$2"
  local sr
  if [ "$exp" -ge 64 ]; then sr=18446744073709551615; else sr=$(printf '%u' "$((1 << exp))"); fi
  SRDEV="$sr"
  echo "$(date -Is) === E-2a punto $punto: exponente=$exp sr_dev=$sr ===" >> "$RUN/EJECUCION.txt"
  lanzar_nodo A "0" "$PA" "" "/ip4/127.0.0.1/tcp/$PB" "/ip4/127.0.0.1/tcp/$PC" >> "$RUN/EJECUCION.txt"
  lanzar_nodo B "1" "$PB" "" "/ip4/127.0.0.1/tcp/$PA" "/ip4/127.0.0.1/tcp/$PC" >> "$RUN/EJECUCION.txt"
  lanzar_nodo C "2" "$PC" "" "/ip4/127.0.0.1/tcp/$PA" "/ip4/127.0.0.1/tcp/$PB" >> "$RUN/EJECUCION.txt"
  sleep 3
  local slot0 bloques0 t0
  slot0=$("$VF" ultimo_slot_conocido "$RUN/A/registro.jsonl")
  bloques0=$("$VF" total_post_dag "$RUN/A/registro.jsonl")
  t0=$(date +%s)
  local ventana_s
  ventana_s=$(awk -v tau="$tau_medido" 'BEGIN{v=200*tau; printf "%d", (v==int(v))?v:int(v)+1}')
  local fin_s=$(( t0 + ventana_s ))
  while [ "$(date +%s)" -lt "$fin_s" ]; do
    if [ -n "$("$VF" hay_fatal "$RUN"/*/stderr.log)" ]; then echo "FALLO_FATAL en punto $punto" >> "$RUN/EJECUCION.txt"; break; fi
    sleep 3
  done
  local slot1 bloques1 t1
  slot1=$("$VF" ultimo_slot_conocido "$RUN/A/registro.jsonl")
  bloques1=$("$VF" total_post_dag "$RUN/A/registro.jsonl")
  t1=$(date +%s)
  local segundos_reales=$(( t1 - t0 ))
  local bloques_delta=$(( bloques1 - bloques0 ))
  local slots_transcurridos bxs
  slots_transcurridos=$(awk -v s="$segundos_reales" -v tau="$tau_medido" 'BEGIN{printf "%.4f", s/tau}')
  bxs=$(awk -v b="$bloques_delta" -v s="$segundos_reales" -v tau="$tau_medido" 'BEGIN{ slots=s/tau; if (slots>0) printf "%.4f", b/slots; else print "0.0000" }')
  echo -e "${punto}\t${exp}\t${sr}\t${segundos_reales}\t${tau_medido}\t${slots_transcurridos}\t${bloques_delta}\t${bxs}\t${slot0}\t${slot1}" >> "$TABLA"
  echo "punto $punto: segundos_reales=$segundos_reales (ventana pedida=${ventana_s}s) slots=$slots_transcurridos bloques=$bloques_delta bloques/slot=$bxs (slot_proxy 0=$slot0 1=$slot1, informativo)" >> "$RUN/EJECUCION.txt"
  matar A "$PA" >> "$RUN/EJECUCION.txt"; matar B "$PB" >> "$RUN/EJECUCION.txt"; matar C "$PC" >> "$RUN/EJECUCION.txt"
  echo "$bxs"
}

lo=56; hi=64; punto=0
mejor_exp=""; mejor_dist=""
while [ "$punto" -lt 6 ]; do
  punto=$((punto + 1))
  mid=$(( (lo + hi) / 2 ))
  bxs=$(medir_punto "$punto" "$mid")
  dentro=$(awk -v x="$bxs" 'BEGIN{print (x>=0.8 && x<=1.2) ? 1 : 0}')
  dist=$(awk -v x="$bxs" 'BEGIN{d=x-1.0; if (d<0) d=-d; printf "%.4f", d}')
  if [ -z "$mejor_dist" ] || awk -v d="$dist" -v m="$mejor_dist" 'BEGIN{exit !(d<m)}'; then
    mejor_dist="$dist"; mejor_exp="$mid"
  fi
  echo "E-2a punto $punto resultado: exponente=$mid bloques_por_slot=$bxs dentro_del_objetivo=$dentro" >> "$RUN/EJECUCION.txt"
  if [ "$dentro" -eq 1 ]; then
    echo "E-2a: exponente $mid dentro de [0.8,1.2] en el punto $punto (bxs=$bxs)" >> "$RUN/EJECUCION.txt"
    mejor_exp="$mid"
    break
  fi
  if [ "$mid" -eq "$lo" ] || [ "$mid" -eq "$hi" ]; then
    echo "E-2a: bisección degenerada (mid=$mid ya es un extremo de [$lo,$hi]); se detiene y se declara el más cercano" >> "$RUN/EJECUCION.txt"
    break
  fi
  cmp=$(awk -v x="$bxs" 'BEGIN{print (x<1.0) ? "bajo" : "alto"}')
  if [ "$cmp" = "bajo" ]; then lo="$mid"; else hi="$mid"; fi
done

if [ "$mejor_exp" -ge 64 ]; then sr_elegido=18446744073709551615; else sr_elegido=$(printf '%u' "$((1 << mejor_exp))"); fi
echo "=== E-2a: SR_dev elegido = $sr_elegido (exponente $mejor_exp), tau_medido=${tau_medido}s, tabla en $TABLA ===" >> "$RUN/EJECUCION.txt"
echo "$sr_elegido" > "$RUN/SR_DEV_ELEGIDO.txt"
echo "$tau_medido" > "$RUN/TAU_MEDIDO.txt"
cerrar_ejecucion_txt
matar_todo
trap - EXIT
touch "$RUN/.done"
cat "$TABLA"
echo "SR_dev elegido: $sr_elegido (tau_medido=${tau_medido}s)"
