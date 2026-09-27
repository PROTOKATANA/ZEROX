#!/usr/bin/env bash
# CORRECCIÓN (2026-09-27, hallazgo del director): una sola clave por nodo (A=0,B=1,C=2,D=3),
# no 0,1,2/3,4,5/6,7,8. Con varias claves por nodo, K_min=3 (PERFIL-DEV-v0.md §3, "una clave por
# nodo de la red de prueba") puede cumplirse con las 3 claves de UN solo nodo si ese nodo mina la
# mayoría de bloques PoW; los demás nodos cruzan el corte sin garantía y, sin relevo de
# transacciones en 0.0.1, ya no pueden depositar ni producir nunca (límite real del producto, no
# del arnés). Verificado en run/E2a-calibracion-intento2-timeout/: B minó 26/31 bloques PoW propios,
# A y C nunca produjeron PoST tras el corte.
# R3/E-6 de ORDEN-W07b: partición en fase PoST ({A} / {B,C}) durante 60 slots y reunión, **con el
# mismo terminal** (los 3 cruzan el corte JUNTOS antes de aislar) — así es E-6 por definición
# (ESCENARIOS-0.0.1.md §3, corrección del director 2026-09-27: distinto de E-6b, que sí es de
# terminales distintos). Técnica de W06d7 V5 (permitida por la orden, ya validada allí con procesos
# reales): se aísla A reiniciándolo sin pares (mismo terminal, solo deja de ver la red); tras >=60
# slots de aislamiento medido en el propio flujo de A, se reúne.
# Uso: r3_e6.sh <rep> <puerto_base> <semilla> <sr_dev>
set -uo pipefail
Z=/home/katana/zeo/ZEROX/deepseek/W07b
CLON="$Z/clon-3d21b1f"; BIN="$CLON/target/release"
source "$Z/scripts/lib_red.sh"

REP="${1:?uso: r3_e6.sh <rep> <puerto_base> <semilla> <sr_dev>}"
PORT_BASE="${2:?falta puerto_base}"
SEMILLA="${3:?falta semilla}"
SRDEV="${4:?falta sr_dev}"
PA="$PORT_BASE"; PB=$((PORT_BASE + 1)); PC=$((PORT_BASE + 2))
PA_AISLADO=$((PORT_BASE + 500))   # puerto nuevo, que B/C nunca conocieron (corrección de aislamiento)
RUN="$Z/run/R3-E6-$REP"
mkdir -p "$RUN"
VF="$Z/scripts/verif.sh"

sin_zx_node_o_falla
puertos_libres_o_falla "$PA" "$PB" "$PC" "$PA_AISLADO"
escribir_ejecucion_txt
{ echo "semilla=$SEMILLA"; echo "puertos: A=$PA B=$PB C=$PC (aislado en $PA_AISLADO)"; echo "tecnica=W06d7-V5 (aislar A en puerto NUEVO sin pares, mismo terminal; corrección de aislamiento verificable 2026-09-27)"; } >> "$RUN/EJECUCION.txt"

matar_todo() { matar A "$PA"; matar B "$PB"; matar C "$PC"; }
trap matar_todo EXIT

echo "$(date -Is) === E-6 $REP: A,B,C juntos desde el génesis (mismo terminal) ===" | tee -a "$RUN/EJECUCION.txt"
lanzar_nodo A "0" "$PA" "" "/ip4/127.0.0.1/tcp/$PB" "/ip4/127.0.0.1/tcp/$PC"
lanzar_nodo B "1" "$PB" "" "/ip4/127.0.0.1/tcp/$PA" "/ip4/127.0.0.1/tcp/$PC"
lanzar_nodo C "2" "$PC" "" "/ip4/127.0.0.1/tcp/$PA" "/ip4/127.0.0.1/tcp/$PB"

resultado=$("$VF" espera_suma_bloques 20 900 "$RUN/A/registro.jsonl" "$RUN/B/registro.jsonl" "$RUN/C/registro.jsonl" -- "$RUN/A/stderr.log" "$RUN/B/stderr.log" "$RUN/C/stderr.log")
echo "$resultado" | tee -a "$RUN/EJECUCION.txt"
if ! echo "$resultado" | grep -q "^EXITO"; then
  echo "FALLO E-6: no se alcanzaron 20 bloques combinados antes de aislar" | tee -a "$RUN/EJECUCION.txt"
  echo "NO_SUPERADO" > "$RUN/RESULTADO.txt"
  cerrar_ejecucion_txt; matar_todo; trap - EXIT; touch "$RUN/.done"; exit 2
fi
"$VF" todos_los_resumenes_iguales "$RUN/A/registro.jsonl" "$RUN/B/registro.jsonl" "$RUN/C/registro.jsonl" | tee -a "$RUN/EJECUCION.txt"

slot_pre=$("$VF" ultimo_slot_conocido "$RUN/A/registro.jsonl")
echo "slot_pre(aislamiento)=$slot_pre" | tee -a "$RUN/EJECUCION.txt"

echo "=== aislando A (puerto NUEVO $PA_AISLADO, sin pares); B,C siguen produciendo en el suyo ===" | tee -a "$RUN/EJECUCION.txt"
peer_b=$("$VF" peer_id_de "$RUN/B/registro.jsonl")
peer_c=$("$VF" peer_id_de "$RUN/C/registro.jsonl")
echo "peer_id B=$peer_b C=$peer_c (para comprobar 0 contacto durante la partición)" >> "$RUN/EJECUCION.txt"
t_particion_inicio=$(date +%s%N)
matar A "$PA"
lanzar_nodo A "0" "$PA_AISLADO" ""   # puerto nuevo, sin marcar: aislado de verdad

echo "=== esperando >=60 slots de aislamiento real en A y en B/C, plazo 30 min ===" | tee -a "$RUN/EJECUCION.txt"
FIN=$(( $(date +%s) + 1800 ))
while :; do
  fatal=$("$VF" hay_fatal "$RUN"/*/stderr.log)
  if [ -n "$fatal" ]; then echo "FALLO_FATAL durante la partición: $fatal" | tee -a "$RUN/EJECUCION.txt"; break; fi
  slot_a=$("$VF" ultimo_slot_conocido "$RUN/A/registro.jsonl")
  slot_b=$("$VF" ultimo_slot_conocido "$RUN/B/registro.jsonl")
  if [ $(( ${slot_a:-0} - slot_pre )) -ge 60 ] && [ $(( ${slot_b:-0} - slot_pre )) -ge 60 ]; then
    echo "60 slots de aislamiento alcanzados: slot_a=$slot_a slot_b=$slot_b" | tee -a "$RUN/EJECUCION.txt"
    break
  fi
  if [ "$(date +%s)" -ge "$FIN" ]; then
    echo "TIMEOUT esperando 60 slots de aislamiento: slot_a=$slot_a slot_b=$slot_b" | tee -a "$RUN/EJECUCION.txt"
    break
  fi
  sleep 3
done
t_particion_fin=$(date +%s%N)
echo "t_particion_inicio_ns=$t_particion_inicio t_particion_fin_ns=$t_particion_fin" >> "$RUN/EJECUCION.txt"

peer_a_aislado=$("$VF" peer_id_de "$RUN/A/registro.jsonl")
# CRITERIO OBLIGATORIO DE TODA PARTICIÓN (corrección del director): 0 par_conectado y 0
# bloque_recibido de A con B/C, y de B/C con A, dentro de la ventana de partición (reloj_pared_ns,
# comparable entre procesos). Si no se cumple, la repetición es "no válida: sin aislamiento", no
# superada ni fallida.
contactos_a=$("$VF" contactos_en_ventana "$RUN/A/registro.jsonl" "$t_particion_inicio" "$t_particion_fin" "$peer_b" "$peer_c")
contactos_b=$("$VF" contactos_en_ventana "$RUN/B/registro.jsonl" "$t_particion_inicio" "$t_particion_fin" "$peer_a_aislado")
contactos_c=$("$VF" contactos_en_ventana "$RUN/C/registro.jsonl" "$t_particion_inicio" "$t_particion_fin" "$peer_a_aislado")
echo "verificación de aislamiento: contactos_A_con_BC=$contactos_a contactos_B_con_A=$contactos_b contactos_C_con_A=$contactos_c (peer_a_aislado=$peer_a_aislado)" | tee -a "$RUN/EJECUCION.txt"
if [ "${contactos_a:-1}" -gt 0 ] || [ "${contactos_b:-1}" -gt 0 ] || [ "${contactos_c:-1}" -gt 0 ]; then
  echo "NO_VALIDA: SIN AISLAMIENTO (hubo contacto real durante la ventana de partición)" | tee -a "$RUN/EJECUCION.txt"
  echo "NO_VALIDA: SIN AISLAMIENTO" > "$RUN/RESULTADO.txt"
  cerrar_ejecucion_txt; matar_todo; trap - EXIT; touch "$RUN/.done"
  echo "=== R3/E-6 $REP: NO VÁLIDA (sin aislamiento) ==="
  exit 4
fi

punta_a_aislada=$("$VF" ultima_linea "$RUN/A/registro.jsonl" cambio_punta)
punta_bc=$("$VF" ultima_linea "$RUN/B/registro.jsonl" cambio_punta)
{ echo "punta_a_aislada: $punta_a_aislada"; echo "punta_bc: $punta_bc"; } >> "$RUN/EJECUCION.txt"

echo "=== reuniendo: matando y relanzando A (puerto original $PA) con --red-marcar hacia B y C (B,C NO se reinician) ===" | tee -a "$RUN/EJECUCION.txt"
t_reunion_inicio=$(date +%s%N)
matar A "$PA_AISLADO"
lanzar_nodo A "0" "$PA" "" "/ip4/127.0.0.1/tcp/$PB" "/ip4/127.0.0.1/tcp/$PC"

echo "=== esperando convergencia, plazo 20 min ===" | tee -a "$RUN/EJECUCION.txt"
FIN=$(( $(date +%s) + 1200 ))
while :; do
  fatal=$("$VF" hay_fatal "$RUN"/*/stderr.log)
  if [ -n "$fatal" ]; then echo "FALLO_FATAL en la reunión: $fatal" | tee -a "$RUN/EJECUCION.txt"; break; fi
  resultado=$("$VF" todos_los_resumenes_iguales "$RUN/A/registro.jsonl" "$RUN/B/registro.jsonl" "$RUN/C/registro.jsonl")
  if echo "$resultado" | grep -q "^CONVERGEN"; then
    t_reunion_fin=$(date +%s%N)
    echo "CONVERGEN: $resultado" | tee -a "$RUN/EJECUCION.txt"
    echo "t_reunion_inicio_ns=$t_reunion_inicio t_reunion_fin_ns=$t_reunion_fin tiempo_convergencia_ns=$((t_reunion_fin - t_reunion_inicio))" >> "$RUN/EJECUCION.txt"
    break
  fi
  if [ "$(date +%s)" -ge "$FIN" ]; then
    echo "TIMEOUT esperando convergencia: $resultado" | tee -a "$RUN/EJECUCION.txt"
    break
  fi
  sleep 3
done

# profundidad_reorg y transacciones descartadas: última línea cambio_punta de A tras reunir.
grep '"tipo":"cambio_punta"' "$RUN/A/registro.jsonl" 2>/dev/null | tail -3 >> "$RUN/EJECUCION.txt"

echo "=== resultado final (método antiguo, informativo) ===" | tee -a "$RUN/EJECUCION.txt"
"$VF" todos_los_resumenes_iguales "$RUN/A/registro.jsonl" "$RUN/B/registro.jsonl" "$RUN/C/registro.jsonl" | tee "$RUN/RESULTADO-metodo-viejo.txt"

echo "=== reposo (decisión 6) y verificación aislada (método nuevo, decisivo) ===" | tee -a "$RUN/EJECUCION.txt"
bash "$Z/scripts/reposo_y_verificar.sh" "$RUN" "$SRDEV" "$SEMILLA" "A:0:$PA" "B:1:$PB" "C:2:$PC" | tee "$RUN/RESULTADO.txt"
cerrar_ejecucion_txt
matar_todo
trap - EXIT
touch "$RUN/.done"
echo "=== R3/E-6 $REP TERMINADO ==="
