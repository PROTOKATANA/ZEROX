#!/usr/bin/env bash
# CORRECCIÓN (2026-09-27, hallazgo del director): una sola clave por nodo (A=0,B=1,C=2,D=3),
# no 0,1,2/3,4,5/6,7,8. Con varias claves por nodo, K_min=3 (PERFIL-DEV-v0.md §3, "una clave por
# nodo de la red de prueba") puede cumplirse con las 3 claves de UN solo nodo si ese nodo mina la
# mayoría de bloques PoW; los demás nodos cruzan el corte sin garantía y, sin relevo de
# transacciones en 0.0.1, ya no pueden depositar ni producir nunca (límite real del producto, no
# del arnés). Verificado en run/E2a-calibracion-intento2-timeout/: B minó 26/31 bloques PoW propios,
# A y C nunca produjeron PoST tras el corte.
# R1 de ORDEN-W07b: E-1 (arranque y corte) -> E-2 (30 min de régimen) -> E-4 (SIGKILL a A y
# rearranque) -> E-3 (convergencia medida tras cada suceso), en una sola repetición continua.
# Uso: r1.sh <rep> <puerto_base> <semilla> <sr_dev>
# (el slot de reposo NO se fija de antemano: se calcula en el momento, como
# max(slot_conocido_A,B,C) + margen, para no forzar una espera larga hasta un slot futuro lejano.)
set -uo pipefail
Z=/home/katana/zeo/ZEROX/deepseek/W07b
CLON="$Z/clon-26312ff"
BIN="$CLON/target/release"
source "$Z/scripts/lib_red.sh"

REP="${1:?uso: r1.sh <rep> <puerto_base> <semilla> <sr_dev>}"
PORT_BASE="${2:?falta puerto_base}"
SEMILLA="${3:?falta semilla}"
SRDEV="${4:?falta sr_dev}"
PA="$PORT_BASE"; PB=$((PORT_BASE + 1)); PC=$((PORT_BASE + 2))
RUN="$Z/run/R1-$REP"
mkdir -p "$RUN"
VF="$Z/scripts/verif.sh"

sin_zx_node_o_falla
puertos_libres_o_falla "$PA" "$PB" "$PC"
escribir_ejecucion_txt
{
  echo "semilla=$SEMILLA"
  echo "puertos: A=$PA B=$PB C=$PC"
} >> "$RUN/EJECUCION.txt"

matar_todo() { matar A "$PA"; matar B "$PB"; matar C "$PC"; }
trap matar_todo EXIT

echo "$(date -Is) === R1 $REP: E-1, arrancando A,B,C desde el génesis (semilla $SEMILLA) ===" | tee -a "$RUN/EJECUCION.txt"
lanzar_nodo A "0" "$PA" "" "/ip4/127.0.0.1/tcp/$PB" "/ip4/127.0.0.1/tcp/$PC"
lanzar_nodo B "1" "$PB" "" "/ip4/127.0.0.1/tcp/$PA" "/ip4/127.0.0.1/tcp/$PC"
lanzar_nodo C "2" "$PC" "" "/ip4/127.0.0.1/tcp/$PA" "/ip4/127.0.0.1/tcp/$PB"

echo "=== E-1: esperando que los 3 crucen el corte (>=1 bloque_producido cada uno), plazo 20 min ===" | tee -a "$RUN/EJECUCION.txt"
FIN=$(( $(date +%s) + 1200 ))
while :; do
  fatal=$("$VF" hay_fatal "$RUN"/*/stderr.log)
  if [ -n "$fatal" ]; then echo "FALLO_FATAL E-1: $fatal" | tee -a "$RUN/EJECUCION.txt"; exit 1; fi
  pa=$("$VF" contar_evento "$RUN/A/registro.jsonl" bloque_producido)
  pb=$("$VF" contar_evento "$RUN/B/registro.jsonl" bloque_producido)
  pc=$("$VF" contar_evento "$RUN/C/registro.jsonl" bloque_producido)
  if [ "${pa:-0}" -ge 1 ] && [ "${pb:-0}" -ge 1 ] && [ "${pc:-0}" -ge 1 ]; then
    echo "E-1 EXITO: los 3 cruzaron el corte (A=$pa B=$pb C=$pc bloques PoST)" | tee -a "$RUN/EJECUCION.txt"
    break
  fi
  if [ "$(date +%s)" -ge "$FIN" ]; then
    echo "E-1 TIMEOUT: A=$pa B=$pb C=$pc" | tee -a "$RUN/EJECUCION.txt"
    echo "PARCIAL" > "$RUN/E1-RESULTADO.txt"
    break
  fi
  sleep 3
done
t_corte_ns=$(date +%s%N)
echo "t_e1_cruzado_ns=$t_corte_ns" >> "$RUN/EJECUCION.txt"

# Terminal fijado por los 3 (mismo T): comparado con cambio_punta más próximo a este instante.
"$VF" todos_los_resumenes_iguales "$RUN/A/registro.jsonl" "$RUN/B/registro.jsonl" "$RUN/C/registro.jsonl" | tee "$RUN/E1-terminal.txt"

echo "=== E-2: 30 minutos de régimen PoST (sr_dev=$SRDEV) ===" | tee -a "$RUN/EJECUCION.txt"
t_e2_inicio=$(date +%s)
sleep 1800
t_e2_fin=$(date +%s)
echo "E-2: régimen de $((t_e2_fin - t_e2_inicio))s completado" | tee -a "$RUN/EJECUCION.txt"
for n in A B C; do
  rechazos=$("$VF" contar_evento "$RUN/$n/registro.jsonl" bloque_red_rechazado)
  echo "E-2 $n: bloque_red_rechazado=$rechazos" | tee -a "$RUN/E2-rechazos.txt"
done
fatal=$("$VF" hay_fatal "$RUN"/*/stderr.log)
[ -n "$fatal" ] && echo "FALLO_FATAL E-2: $fatal" | tee -a "$RUN/EJECUCION.txt"

echo "=== E-4: SIGKILL a A, rearranque (mismo --datos, mismos pares) ===" | tee -a "$RUN/EJECUCION.txt"
t_muerte=$(date +%s%N)
matar A "$PA"
t_muerte_confirmada=$(date +%s%N)
echo "t_muerte_ns=$t_muerte t_puerto_libre_ns=$t_muerte_confirmada" >> "$RUN/EJECUCION.txt"
lanzar_nodo A "0" "$PA" "" "/ip4/127.0.0.1/tcp/$PB" "/ip4/127.0.0.1/tcp/$PC"
echo "=== E-4: esperando reinicio_completo y que A se ponga al día con B/C, plazo 10 min ===" | tee -a "$RUN/EJECUCION.txt"
FIN=$(( $(date +%s) + 600 ))
while :; do
  if [ -n "$("$VF" hay_fatal "$RUN/A/stderr.log")" ]; then
    echo "FALLO_FATAL E-4: reinicio de A" | tee -a "$RUN/EJECUCION.txt"; break
  fi
  rc=$("$VF" contar_evento "$RUN/A/registro.jsonl" reinicio_completo)
  slot_a=$("$VF" ultimo_slot_conocido "$RUN/A/registro.jsonl")
  slot_b=$("$VF" ultimo_slot_conocido "$RUN/B/registro.jsonl")
  diff=$(( ${slot_b:-0} - ${slot_a:-0} ))
  if [ "${rc:-0}" -ge 1 ] && [ "$diff" -le 2 ]; then
    t_puesta_al_dia=$(date +%s%N)
    echo "E-4 EXITO: reinicio_completo=$rc, A alcanzó a B (slot_a=$slot_a slot_b=$slot_b)" | tee -a "$RUN/EJECUCION.txt"
    echo "t_puesta_al_dia_ns=$t_puesta_al_dia" >> "$RUN/EJECUCION.txt"
    break
  fi
  if [ "$(date +%s)" -ge "$FIN" ]; then
    echo "E-4 TIMEOUT: reinicio_completo=$rc slot_a=$slot_a slot_b=$slot_b" | tee -a "$RUN/EJECUCION.txt"
    break
  fi
  sleep 3
done

echo "=== E-3: reposo (mismo --dejar-de-producir-en-slot en los 3) y comparación ===" | tee -a "$RUN/EJECUCION.txt"
slot_a_r=$("$VF" ultimo_slot_conocido "$RUN/A/registro.jsonl")
slot_b_r=$("$VF" ultimo_slot_conocido "$RUN/B/registro.jsonl")
slot_c_r=$("$VF" ultimo_slot_conocido "$RUN/C/registro.jsonl")
SLOT_REPOSO=$(( slot_a_r > slot_b_r ? slot_a_r : slot_b_r ))
SLOT_REPOSO=$(( SLOT_REPOSO > slot_c_r ? SLOT_REPOSO : slot_c_r ))
SLOT_REPOSO=$(( SLOT_REPOSO + 5 ))
echo "slot_reposo calculado=$SLOT_REPOSO (max(A=$slot_a_r,B=$slot_b_r,C=$slot_c_r)+5)" | tee -a "$RUN/EJECUCION.txt"
# Reposo real (decisión 6): matar y relanzar los 3 con el mismo slot de parada de producción.
t_reposo_inicio=$(date +%s%N)
matar A "$PA"; matar B "$PB"; matar C "$PC"
lanzar_nodo A "0" "$PA" "$SLOT_REPOSO" "/ip4/127.0.0.1/tcp/$PB" "/ip4/127.0.0.1/tcp/$PC"
lanzar_nodo B "1" "$PB" "$SLOT_REPOSO" "/ip4/127.0.0.1/tcp/$PA" "/ip4/127.0.0.1/tcp/$PC"
lanzar_nodo C "2" "$PC" "$SLOT_REPOSO" "/ip4/127.0.0.1/tcp/$PA" "/ip4/127.0.0.1/tcp/$PB"

echo "=== esperando dejar_de_producir en los 3, plazo 30 min ===" | tee -a "$RUN/EJECUCION.txt"
FIN=$(( $(date +%s) + 1800 ))
while :; do
  fatal=$("$VF" hay_fatal "$RUN"/*/stderr.log)
  if [ -n "$fatal" ]; then echo "FALLO_FATAL E-3 (reposo): $fatal" | tee -a "$RUN/EJECUCION.txt"; break; fi
  listos=$("$VF" reposo_listos "$RUN/A/registro.jsonl" "$RUN/B/registro.jsonl" "$RUN/C/registro.jsonl")
  if [ "${listos:-0}" -eq 3 ]; then
    echo "reposo alcanzado en los 3" | tee -a "$RUN/EJECUCION.txt"
    break
  fi
  if [ "$(date +%s)" -ge "$FIN" ]; then
    echo "TIMEOUT esperando reposo: listos=$listos" | tee -a "$RUN/EJECUCION.txt"
    break
  fi
  sleep 3
done

echo "=== esperando 30s sin cambio_punta en ninguno (decisión 6) ===" | tee -a "$RUN/EJECUCION.txt"
FIN=$(( $(date +%s) + 300 ))
while :; do
  quieto=1
  for n in A B C; do
    hace=$("$VF" ultimo_cambio_punta_hace_ns "$RUN/$n/registro.jsonl")
    if [ "${hace:-0}" -lt 30000000000 ]; then quieto=0; fi
  done
  if [ "$quieto" -eq 1 ]; then echo "30s sin cambio_punta en los 3" | tee -a "$RUN/EJECUCION.txt"; break; fi
  if [ "$(date +%s)" -ge "$FIN" ]; then echo "TIMEOUT esperando 30s de silencio" | tee -a "$RUN/EJECUCION.txt"; break; fi
  sleep 3
done
t_reposo_fin=$(date +%s%N)
echo "t_reposo_inicio_ns=$t_reposo_inicio t_reposo_fin_ns=$t_reposo_fin tiempo_convergencia_ns=$((t_reposo_fin - t_reposo_inicio))" >> "$RUN/EJECUCION.txt"

echo "=== E-3: resultado final (método antiguo, informativo/no concluyente por sí solo) ===" | tee -a "$RUN/EJECUCION.txt"
"$VF" todos_los_resumenes_iguales "$RUN/A/registro.jsonl" "$RUN/B/registro.jsonl" "$RUN/C/registro.jsonl" | tee "$RUN/RESULTADO-metodo-viejo.txt"

# CORRECCIÓN DEL DIRECTOR (2026-09-27): ni el método antiguo ni el "aislado" (arriba) son
# decisivos hasta W07d (reinicio_completo aún no lleva resumen_estado propio; nodo.rs:1241
# registrar_cambio_de_punta no escribe si la punta no cambia). E-3 queda pendiente; se conservan
# los `datos` de los 3 nodos para repetir la verificación aislada con el binario de W07d.
matar A "$PA"; matar B "$PB"; matar C "$PC"
echo "E-3: PENDIENTE DE VERIFICACIÓN CON EL BINARIO DE W07D (datos conservados en $RUN/{A,B,C}/datos; ver RESULTADO-metodo-viejo.txt como informativo, no decisivo)" | tee "$RUN/RESULTADO.txt"

cerrar_ejecucion_txt
echo "R1 $REP: FIN $(date -Is)" >> "$RUN/EJECUCION.txt"
matar_todo
trap - EXIT
touch "$RUN/.done"
echo "=== R1 $REP TERMINADO ==="
