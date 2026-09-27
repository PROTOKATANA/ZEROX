#!/usr/bin/env bash
# r150.sh — V5 de ORDEN-W06d10: tres nodos honestos (A=0, B=1, C=2, una clave por nodo) cruzan el
# corte y la cadena PoST llega al slot 150. Criterio: 0 `par_penalizado` entre honestos, 0
# `fallo_productor`, 0 pánicos; al final, mismo resumen_estado y compendio_bloques (método W07d).
# Uso: r150.sh <rep> <puerto_base> <semilla> [sr_dev]
set -uo pipefail
Z=/home/katana/zeo/ZEROX/deepseek/W06d10-B
CLON="$Z/ws"; BIN="$CLON/target/release"
source "$Z/scripts/lib_red.sh"

REP="${1:?uso: r150.sh <rep> <puerto_base> <semilla> [sr_dev]}"
PORT_BASE="${2:?falta puerto_base}"
SEMILLA="${3:?falta semilla}"
SRDEV="${4:-13043817825332783104}"
PA="$PORT_BASE"; PB=$((PORT_BASE + 1)); PC=$((PORT_BASE + 2))
RUN="$Z/run/R150-$REP"
mkdir -p "$RUN"
VF="$Z/scripts/verif.sh"

sin_zx_node_o_falla
puertos_libres_o_falla "$PA" "$PB" "$PC"
escribir_ejecucion_txt
{ echo "semilla=$SEMILLA"; echo "puertos: A=$PA B=$PB C=$PC"; } >> "$RUN/EJECUCION.txt"

matar_todo() { matar A "$PA"; matar B "$PB"; matar C "$PC"; }
trap matar_todo EXIT

echo "$(date -Is) === R150 rep$REP: A,B,C desde el génesis, objetivo slot 150 ===" | tee -a "$RUN/EJECUCION.txt"
lanzar_nodo A "0" "$PA" "" "/ip4/127.0.0.1/tcp/$PB" "/ip4/127.0.0.1/tcp/$PC" >> "$RUN/EJECUCION.txt"
lanzar_nodo B "1" "$PB" "" "/ip4/127.0.0.1/tcp/$PA" "/ip4/127.0.0.1/tcp/$PC" >> "$RUN/EJECUCION.txt"
lanzar_nodo C "2" "$PC" "" "/ip4/127.0.0.1/tcp/$PA" "/ip4/127.0.0.1/tcp/$PB" >> "$RUN/EJECUCION.txt"

echo "=== esperando slot >= 150 en A, B y C, plazo 30 min ===" | tee -a "$RUN/EJECUCION.txt"
FIN=$(( $(date +%s) + 1800 ))
alcanzado=0
while :; do
  fatal=$("$VF" hay_fatal "$RUN"/*/stderr.log)
  if [ -n "$fatal" ]; then echo "FALLO_FATAL: $fatal" | tee -a "$RUN/EJECUCION.txt"; break; fi
  sa=$("$VF" ultimo_slot_conocido "$RUN/A/registro.jsonl")
  sb=$("$VF" ultimo_slot_conocido "$RUN/B/registro.jsonl")
  sc=$("$VF" ultimo_slot_conocido "$RUN/C/registro.jsonl")
  if [ "${sa:-0}" -ge 150 ] && [ "${sb:-0}" -ge 150 ] && [ "${sc:-0}" -ge 150 ]; then
    echo "SLOT_150 alcanzado: slot_a=$sa slot_b=$sb slot_c=$sc" | tee -a "$RUN/EJECUCION.txt"
    alcanzado=1
    break
  fi
  if [ "$(date +%s)" -ge "$FIN" ]; then
    echo "TIMEOUT esperando slot 150: slot_a=$sa slot_b=$sb slot_c=$sc" | tee -a "$RUN/EJECUCION.txt"
    break
  fi
  sleep 3
done

fatal=$("$VF" hay_fatal "$RUN"/*/stderr.log)
pen_total=0
for n in A B C; do
  prod=$("$VF" contar_evento "$RUN/$n/registro.jsonl" bloque_producido)
  fallo=$("$VF" contar_evento "$RUN/$n/registro.jsonl" fallo_productor)
  omit=$("$VF" contar_evento "$RUN/$n/registro.jsonl" produccion_omitida)
  pen=$(grep -c '"tipo":"par_penalizado"' "$RUN/$n/registro.jsonl" 2>/dev/null)
  pen=${pen:-0}
  pen_total=$((pen_total + pen))
  pan=$(grep -c "panicked at" "$RUN/$n/stderr.log" 2>/dev/null || true)
  echo "NODO $n: bloque_producido=$prod fallo_productor=$fallo produccion_omitida=$omit par_penalizado=$pen panicos=${pan:-0}" | tee -a "$RUN/EJECUCION.txt"
done
echo "par_penalizado_total_entre_honestos=$pen_total (debe ser 0)" | tee -a "$RUN/EJECUCION.txt"

matar_todo
sleep 2
echo "=== verificación aislada de estado (método W07d, sobre copias) ===" | tee -a "$RUN/EJECUCION.txt"
bash "$Z/scripts/verificar_estado_w07d.sh" "$RUN" "$BIN" "$SRDEV" "$SEMILLA" "$((PORT_BASE + 700))" "A:0" "B:1" "C:2" | tee "$RUN/RESULTADO-convergencia.txt"

converge=0
grep -q '^CONVERGEN' "$RUN/RESULTADO-convergencia.txt" && converge=1
if [ -n "$fatal" ]; then
  echo "NO_SUPERADO ($fatal)" > "$RUN/RESULTADO.txt"
elif [ "$alcanzado" -eq 1 ] && [ "$pen_total" -eq 0 ] && [ "$converge" -eq 1 ]; then
  echo "SUPERADO" > "$RUN/RESULTADO.txt"
else
  echo "PARCIAL" > "$RUN/RESULTADO.txt"
fi
echo "RESULTADO=$(cat "$RUN/RESULTADO.txt")" | tee -a "$RUN/EJECUCION.txt"
cerrar_ejecucion_txt
trap - EXIT
touch "$RUN/.done"
echo "=== R150 rep$REP TERMINADO ==="
