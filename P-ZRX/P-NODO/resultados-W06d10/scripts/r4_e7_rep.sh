#!/usr/bin/env bash
# r4_e7_rep.sh — V4 de ORDEN-W06d10: una repetición de la parte E-7 de r4.sh de W07b (sin E-8 de
# doble-firma ni E-9). Tres nodos reales (A=0, B=1, C=2, una clave por nodo) desde el génesis;
# zx-adversario lanza la ráfaga E-7/E-8 básica contra A; se comprueba:
#   - los cuatro vectores rechazados con su motivo (bloque_red_rechazado),
#   - par_penalizado en A para **cada** PeerId del adversario (identidad nueva por vector),
#   - A sigue conectado a B y C (0 par_desconectado de sus peer_id),
#   - tras la parada, los tres con el mismo resumen_estado y compendio_bloques (método W07d).
# Uso: r4_e7_rep.sh <rep> <puerto_base> <semilla> <sr_dev>
set -uo pipefail
Z=/home/katana/zeo/ZEROX/deepseek/W06d10
CLON="$Z/ws"; BIN="$CLON/target/release"
source "$Z/scripts/lib_red.sh"

REP="${1:?uso: r4_e7_rep.sh <rep> <puerto_base> <semilla> <sr_dev>}"
PORT_BASE="${2:?falta puerto_base}"
SEMILLA="${3:?falta semilla}"
SRDEV="${4:?falta sr_dev}"
PA="$PORT_BASE"; PB=$((PORT_BASE + 1)); PC=$((PORT_BASE + 2))
RUN="$Z/run/R4-E7-$REP"
mkdir -p "$RUN"
VF="$Z/scripts/verif.sh"

sin_zx_node_o_falla
puertos_libres_o_falla "$PA" "$PB" "$PC"
escribir_ejecucion_txt
{ echo "semilla=$SEMILLA"; echo "puertos: A=$PA B=$PB C=$PC"; } >> "$RUN/EJECUCION.txt"

matar_todo() { matar A "$PA"; matar B "$PB"; matar C "$PC"; }
trap matar_todo EXIT

echo "$(date -Is) === E-7 rep$REP: A,B,C desde el génesis ===" | tee -a "$RUN/EJECUCION.txt"
lanzar_nodo A "0" "$PA" "" "/ip4/127.0.0.1/tcp/$PB" "/ip4/127.0.0.1/tcp/$PC"
lanzar_nodo B "1" "$PB" "" "/ip4/127.0.0.1/tcp/$PA" "/ip4/127.0.0.1/tcp/$PC"
lanzar_nodo C "2" "$PC" "" "/ip4/127.0.0.1/tcp/$PA" "/ip4/127.0.0.1/tcp/$PB"

resultado=$("$VF" espera_suma_bloques 20 900 "$RUN/A/registro.jsonl" "$RUN/B/registro.jsonl" "$RUN/C/registro.jsonl" -- "$RUN/A/stderr.log" "$RUN/B/stderr.log" "$RUN/C/stderr.log")
echo "$resultado" | tee -a "$RUN/EJECUCION.txt"
if ! echo "$resultado" | grep -q "^EXITO"; then
  echo "FALLO E-7: no se alcanzaron 20 bloques combinados antes del adversario" | tee -a "$RUN/EJECUCION.txt"
  echo "NO_SUPERADO" > "$RUN/RESULTADO.txt"
  cerrar_ejecucion_txt; matar_todo; trap - EXIT; touch "$RUN/.done"; exit 2
fi

peer_b=$("$VF" peer_id_de "$RUN/B/registro.jsonl")
peer_c=$("$VF" peer_id_de "$RUN/C/registro.jsonl")
echo "peer_id B=$peer_b C=$peer_c" >> "$RUN/EJECUCION.txt"

echo "=== E-7: zx-adversario (ráfaga, identidad nueva por vector) contra A ===" | tee -a "$RUN/EJECUCION.txt"
estado_a_antes=$("$VF" resumen_actual "$RUN/A/registro.jsonl")
"$BIN/zx-adversario" --objetivo "/ip4/127.0.0.1/tcp/$PA" --pausa-ms 2000 > "$RUN/e7-adversario.log" 2>&1
sleep 8
estado_a_despues=$("$VF" resumen_actual "$RUN/A/registro.jsonl")
echo "estado_a_antes=$estado_a_antes estado_a_despues=$estado_a_despues (informativo; el estado se decide al final por W07d)" | tee -a "$RUN/EJECUCION.txt"

# PeerId de cada vector (identidad nueva), de la salida de zx-adversario.
grep 'desde identidad NUEVA' "$RUN/e7-adversario.log" | sed -E 's/.*\(PeerId ([A-Za-z0-9]+)\).*/\1/' | sort -u > "$RUN/peers-adversario.txt"
n_peers=$(wc -l < "$RUN/peers-adversario.txt")
echo "PeerId del adversario (uno por vector): $(tr '\n' ' ' < "$RUN/peers-adversario.txt")" | tee -a "$RUN/EJECUCION.txt"
echo "n_peers_adversario=$n_peers" | tee -a "$RUN/EJECUCION.txt"

for n in A B C; do
  echo "--- $n: bloque_red_rechazado ---" >> "$RUN/e7-rechazos.txt"
  grep '"tipo":"bloque_red_rechazado"' "$RUN/$n/registro.jsonl" 2>/dev/null >> "$RUN/e7-rechazos.txt"
  echo "--- $n: par_penalizado ---" >> "$RUN/e7-rechazos.txt"
  grep '"tipo":"par_penalizado"' "$RUN/$n/registro.jsonl" 2>/dev/null >> "$RUN/e7-rechazos.txt"
done

# PeerId realmente penalizados en A (los escribe `zx-p2p` en `par_penalizado`).
grep '"tipo":"par_penalizado"' "$RUN/A/registro.jsonl" 2>/dev/null \
  | grep -o '"par":"[^"]*"' | sed -E 's/.*:"([^"]*)"/\1/' | sort -u > "$RUN/penalizados-a.txt"
penalizados_a=$(wc -l < "$RUN/penalizados-a.txt")
rechazos_a=$(grep -c '"tipo":"bloque_red_rechazado"' "$RUN/A/registro.jsonl" 2>/dev/null)
echo "A: bloque_red_rechazado=$rechazos_a par_penalizado(distintos)=${penalizados_a:-0}" | tee -a "$RUN/EJECUCION.txt"
echo "PeerId penalizados en A: $(tr '\n' ' ' < "$RUN/penalizados-a.txt")" | tee -a "$RUN/EJECUCION.txt"

# Ningún PeerId penalizado puede ser ajeno al adversario (o sea: ningún honesto penalizado).
# El vector de huérfanos es `Ignorar` por diseño y no aparece aquí: el requisito de la orden es para
# los vectores **rechazados**.
ajenos=$(comm -23 "$RUN/penalizados-a.txt" "$RUN/peers-adversario.txt" | wc -l)
echo "PeerId penalizados que NO son del adversario: $ajenos (debe ser 0)" | tee -a "$RUN/EJECUCION.txt"

# A sigue conectado a B y C: ningún par_desconectado suyo tras el adversario.
desconexiones_bc=0
for p in "$peer_b" "$peer_c"; do
  [ -z "$p" ] && continue
  c=$(grep '"tipo":"par_desconectado"' "$RUN/A/registro.jsonl" 2>/dev/null | grep -c "\"par\":\"$p\"")
  desconexiones_bc=$((desconexiones_bc + ${c:-0}))
done
echo "A: par_desconectado de B/C = $desconexiones_bc (debe ser 0)" | tee -a "$RUN/EJECUCION.txt"

matar_todo
sleep 2
echo "=== verificación aislada de estado (método W07d, sobre copias) ===" | tee -a "$RUN/EJECUCION.txt"
bash "$Z/scripts/verificar_estado_w07d.sh" "$RUN" "$BIN" "$SRDEV" "$SEMILLA" "$((PORT_BASE + 700))" "A:0" "B:1" "C:2" | tee "$RUN/RESULTADO.txt"

converge=0
grep -q '^CONVERGEN' "$RUN/RESULTADO.txt" && converge=1
ok=1
[ "${rechazos_a:-0}" -ge 4 ] || ok=0
[ "${penalizados_a:-0}" -ge 4 ] || ok=0
[ "$ajenos" -eq 0 ] || ok=0
[ "$desconexiones_bc" -eq 0 ] || ok=0
[ "$converge" -eq 1 ] || ok=0
if [ "$ok" -eq 1 ]; then
  echo "SUPERADO (E-7 rep$REP): rechazos=$rechazos_a penalizados=$penalizados_a peers=${n_peers} ajenos=$ajenos desconexiones_BC=$desconexiones_bc convergen=si" | tee -a "$RUN/EJECUCION.txt"
  echo "SUPERADO" > "$RUN/RESULTADO.txt"
else
  echo "NO_SUPERADO (E-7 rep$REP): rechazos=$rechazos_a penalizados=$penalizados_a ajenos=$ajenos desconexiones_BC=$desconexiones_bc convergen=$converge" | tee -a "$RUN/EJECUCION.txt"
  echo "NO_SUPERADO" > "$RUN/RESULTADO.txt"
fi
cerrar_ejecucion_txt
trap - EXIT
touch "$RUN/.done"
echo "=== R4/E-7 rep$REP TERMINADO ==="
