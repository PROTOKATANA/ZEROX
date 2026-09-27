#!/usr/bin/env bash
# CORRECCIÓN (2026-09-27, hallazgo del director): una sola clave por nodo (A=0,B=1,C=2,D=3),
# no 0,1,2/3,4,5/6,7,8. Con varias claves por nodo, K_min=3 (PERFIL-DEV-v0.md §3, "una clave por
# nodo de la red de prueba") puede cumplirse con las 3 claves de UN solo nodo si ese nodo mina la
# mayoría de bloques PoW; los demás nodos cruzan el corte sin garantía y, sin relevo de
# transacciones en 0.0.1, ya no pueden depositar ni producir nunca (límite real del producto, no
# del arnés). Verificado en run/E2a-calibracion-intento2-timeout/: B minó 26/31 bloques PoW propios,
# A y C nunca produjeron PoST tras el corte.
# R4 de ORDEN-W07b: E-7 (zx-adversario, ráfaga completa), E-8 (zx-adversario doble-firma, con
# castigo activo, patrón validado en SL-4b2 V4) y E-9 (retención del terminal, descriptivo).
# Uso: r4.sh <rep> <puerto_base> <semilla> <sr_dev>
set -uo pipefail
Z=/home/katana/zeo/ZEROX/deepseek/W07b
CLON="$Z/clon-3d21b1f"; BIN="$CLON/target/release"
source "$Z/scripts/lib_red.sh"

REP="${1:?uso: r4.sh <rep> <puerto_base> <semilla> <sr_dev>}"
PORT_BASE="${2:?falta puerto_base}"
SEMILLA="${3:?falta semilla}"
SRDEV="${4:?falta sr_dev}"
PA="$PORT_BASE"; PB=$((PORT_BASE + 1)); PC=$((PORT_BASE + 2))
RUN_TOP="$Z/run/R4-$REP"
mkdir -p "$RUN_TOP"
VF="$Z/scripts/verif.sh"

sin_zx_node_o_falla
puertos_libres_o_falla "$PA" "$PB" "$PC"
RUN="$RUN_TOP"
escribir_ejecucion_txt
{ echo "semilla=$SEMILLA"; echo "puertos: A=$PA B=$PB C=$PC"; } >> "$RUN/EJECUCION.txt"

# ------------------------------------------------------------------
# Parte 1: E-7 (ráfaga adversarial) + E-8 (doble firma con castigo activo)
# ------------------------------------------------------------------
RUN1="$RUN_TOP/e7e8"; mkdir -p "$RUN1"
matar_todo_1() { RUN="$RUN1" matar A "$PA"; RUN="$RUN1" matar B "$PB"; RUN="$RUN1" matar C "$PC"; }
RUN="$RUN1"
trap matar_todo_1 EXIT

echo "$(date -Is) === E-7/E-8 $REP: A,B,C desde el génesis ===" | tee -a "$RUN/EJECUCION.txt"
lanzar_nodo A "0" "$PA" "" "/ip4/127.0.0.1/tcp/$PB" "/ip4/127.0.0.1/tcp/$PC"
lanzar_nodo B "1" "$PB" "" "/ip4/127.0.0.1/tcp/$PA" "/ip4/127.0.0.1/tcp/$PC"
lanzar_nodo C "2" "$PC" "" "/ip4/127.0.0.1/tcp/$PA" "/ip4/127.0.0.1/tcp/$PB"

resultado=$("$VF" espera_suma_bloques 20 900 "$RUN/A/registro.jsonl" "$RUN/B/registro.jsonl" "$RUN/C/registro.jsonl" -- "$RUN/A/stderr.log" "$RUN/B/stderr.log" "$RUN/C/stderr.log")
echo "$resultado" | tee -a "$RUN/EJECUCION.txt"

echo "=== E-7: zx-adversario (ráfaga completa) contra A ===" | tee -a "$RUN/EJECUCION.txt"
estado_a_antes=$("$VF" resumen_actual "$RUN/A/registro.jsonl")
"$BIN/zx-adversario" --objetivo "/ip4/127.0.0.1/tcp/$PA" > "$RUN/e7-adversario.log" 2>&1
echo "salida de zx-adversario (E-7) en $RUN/e7-adversario.log" | tee -a "$RUN/EJECUCION.txt"
sleep 5
estado_a_despues=$("$VF" resumen_actual "$RUN/A/registro.jsonl")
echo "estado_a_antes=$estado_a_antes estado_a_despues=$estado_a_despues (deben coincidir: E-7 no cambia estado)" | tee -a "$RUN/EJECUCION.txt"
for n in A B C; do
  echo "--- $n: bloque_red_rechazado ---" >> "$RUN/e7-rechazos.txt"
  grep '"tipo":"bloque_red_rechazado"' "$RUN/$n/registro.jsonl" 2>/dev/null >> "$RUN/e7-rechazos.txt"
  echo "--- $n: par_penalizado ---" >> "$RUN/e7-rechazos.txt"
  grep '"tipo":"par_penalizado"' "$RUN/$n/registro.jsonl" 2>/dev/null >> "$RUN/e7-rechazos.txt"
  echo "--- $n: limite_alcanzado ---" >> "$RUN/e7-rechazos.txt"
  grep '"tipo":"limite_alcanzado"' "$RUN/$n/registro.jsonl" 2>/dev/null >> "$RUN/e7-rechazos.txt"
  echo "--- $n: bloque_red_huerfano ---" >> "$RUN/e7-rechazos.txt"
  grep '"tipo":"bloque_red_huerfano"' "$RUN/$n/registro.jsonl" 2>/dev/null | wc -l >> "$RUN/e7-rechazos.txt"
done

echo "=== E-8: zx-adversario doble-firma --clave-indice 0 --semilla $SEMILLA --repetir contra A ===" | tee -a "$RUN/EJECUCION.txt"
"$BIN/zx-adversario" --objetivo "/ip4/127.0.0.1/tcp/$PA" doble-firma \
  --clave-indice 0 --semilla "$SEMILLA" --plazo-espera-s 120 --repetir \
  > "$RUN/e8-adversario.log" 2>&1
cat "$RUN/e8-adversario.log" >> "$RUN/EJECUCION.txt"

echo "=== esperando evidencia_detectada en B y C, plazo 120s ===" | tee -a "$RUN/EJECUCION.txt"
FIN=$(( $(date +%s) + 120 ))
while :; do
  db=$("$VF" contar_evento "$RUN/B/registro.jsonl" evidencia_detectada)
  dc=$("$VF" contar_evento "$RUN/C/registro.jsonl" evidencia_detectada)
  if [ "${db:-0}" -ge 1 ] && [ "${dc:-0}" -ge 1 ]; then echo "EXITO: evidencia_detectada B=$db C=$dc" | tee -a "$RUN/EJECUCION.txt"; break; fi
  if [ "$(date +%s)" -ge "$FIN" ]; then echo "TIMEOUT evidencia_detectada: B=$db C=$dc" | tee -a "$RUN/EJECUCION.txt"; break; fi
  sleep 2
done
echo "=== esperando evidencia_incluida, plazo 120s ===" | tee -a "$RUN/EJECUCION.txt"
FIN=$(( $(date +%s) + 120 ))
while :; do
  ia=$("$VF" contar_evento "$RUN/A/registro.jsonl" evidencia_incluida)
  ib=$("$VF" contar_evento "$RUN/B/registro.jsonl" evidencia_incluida)
  ic=$("$VF" contar_evento "$RUN/C/registro.jsonl" evidencia_incluida)
  if [ "${ia:-0}" -ge 1 ] || [ "${ib:-0}" -ge 1 ] || [ "${ic:-0}" -ge 1 ]; then echo "EXITO: evidencia_incluida A=$ia B=$ib C=$ic" | tee -a "$RUN/EJECUCION.txt"; break; fi
  if [ "$(date +%s)" -ge "$FIN" ]; then echo "TIMEOUT evidencia_incluida" | tee -a "$RUN/EJECUCION.txt"; break; fi
  sleep 2
done
echo "=== 30s más de producción para que la confiscación se refleje y propague ===" | tee -a "$RUN/EJECUCION.txt"
sleep 30
for n in A B C; do
  echo "--- $n: evidencia_* / garantia_clave_tras_evidencia / firmante_abstenido ---" >> "$RUN/e8-evidencia.txt"
  grep -E '"tipo":"(evidencia_detectada|evidencia_incluida|garantia_clave_tras_evidencia|firmante_abstenido)"' "$RUN/$n/registro.jsonl" 2>/dev/null >> "$RUN/e8-evidencia.txt"
done
echo "=== resumen_estado final (E-7/E-8), método antiguo, informativo ===" | tee -a "$RUN/EJECUCION.txt"
"$VF" todos_los_resumenes_iguales "$RUN/A/registro.jsonl" "$RUN/B/registro.jsonl" "$RUN/C/registro.jsonl" | tee "$RUN/RESULTADO-e7e8-metodo-viejo.txt"
echo "=== reposo (decisión 6) y verificación aislada (método nuevo, decisivo) ===" | tee -a "$RUN/EJECUCION.txt"
bash "$Z/scripts/reposo_y_verificar.sh" "$RUN" "$SRDEV" "$SEMILLA" "A:0:$PA" "B:1:$PB" "C:2:$PC" | tee "$RUN/RESULTADO-e7e8.txt"
cerrar_ejecucion_txt
matar_todo_1
trap - EXIT

echo "=== esperando liberación completa de puertos antes de E-9 ==="
for p in "$PA" "$PB" "$PC"; do
  for _ in $(seq 1 50); do ss -ltn 2>/dev/null | grep -q ":$p " || break; sleep 0.2; done
done

# ------------------------------------------------------------------
# Parte 2: E-9 (retención del terminal), descriptivo. A aislado desde el arranque (su bloque de
# corte no llega a la red hasta que se reúne: equivalente observacional a "retener y publicar
# tarde", sin modificar el nodo); B+C juntos, cruzan por su cuenta. Se registra qué T fija cada
# lado y cuándo, y qué T queda fijado tras reunir (A-07 abierto: sin criterio de éxito/fracaso).
#
# CORRECCIÓN (2026-09-27, mismo hallazgo que en E-6b): esta topología parte la red en dos ANTES
# del corte, igual que E-6b — con una clave por nodo, K_min=3 (PERFIL-DEV-v0.md §3) es imposible de
# alcanzar en cualquiera de los dos lados (A solo tiene 1 clave; B+C juntos solo 2), así que NINGÚN
# lado cruzaría nunca y no habría nada que describir. Igual que en E-6b, se da a cada lado sus
# propias 3 claves: A=0,1,2; B=3,4; C=5.
# ------------------------------------------------------------------
RUN2="$RUN_TOP/e9"; mkdir -p "$RUN2"
matar_todo_2() { RUN="$RUN2" matar A "$PA"; RUN="$RUN2" matar B "$PB"; RUN="$RUN2" matar C "$PC"; }
RUN="$RUN2"
trap matar_todo_2 EXIT

echo "$(date -Is) === E-9 $REP: A aislado (retiene su corte), B+C juntos ===" | tee -a "$RUN/EJECUCION.txt"
t0_ns=$(date +%s%N)
lanzar_nodo A "0,1,2" "$PA" ""
lanzar_nodo B "3,4" "$PB" ""
lanzar_nodo C "5" "$PC" "" "/ip4/127.0.0.1/tcp/$PB"

echo "=== esperando que A y (B o C) fijen su propio T (>=1 bloque_producido), plazo 20 min ===" | tee -a "$RUN/EJECUCION.txt"
FIN=$(( $(date +%s) + 1200 ))
t_a=""; t_bc=""
while :; do
  fatal=$("$VF" hay_fatal "$RUN"/*/stderr.log)
  if [ -n "$fatal" ]; then echo "FALLO_FATAL E-9: $fatal" | tee -a "$RUN/EJECUCION.txt"; break; fi
  pa=$("$VF" contar_evento "$RUN/A/registro.jsonl" bloque_producido)
  pb=$("$VF" contar_evento "$RUN/B/registro.jsonl" bloque_producido)
  pc=$("$VF" contar_evento "$RUN/C/registro.jsonl" bloque_producido)
  if [ -z "$t_a" ] && [ "${pa:-0}" -ge 1 ]; then t_a=$(date +%s%N); echo "A fija su T en t=$((t_a - t0_ns))ns (retenido, aislado)" | tee -a "$RUN/EJECUCION.txt"; fi
  if [ -z "$t_bc" ] && { [ "${pb:-0}" -ge 1 ] || [ "${pc:-0}" -ge 1 ]; }; then t_bc=$(date +%s%N); echo "B/C fijan su T en t=$((t_bc - t0_ns))ns" | tee -a "$RUN/EJECUCION.txt"; fi
  if [ -n "$t_a" ] && [ -n "$t_bc" ]; then break; fi
  if [ "$(date +%s)" -ge "$FIN" ]; then echo "TIMEOUT E-9 fijando T: A=$pa B=$pb C=$pc" | tee -a "$RUN/EJECUCION.txt"; break; fi
  sleep 3
done

echo "=== dejando que B/C produzcan 60s más antes de que A publique tarde (reunión) ===" | tee -a "$RUN/EJECUCION.txt"
sleep 60
echo "=== A publica tarde: reunión (reinicio con --red-marcar hacia B y C) ===" | tee -a "$RUN/EJECUCION.txt"
t_publicacion_tardia=$(date +%s%N)
matar A "$PA"
lanzar_nodo A "0,1,2" "$PA" "" "/ip4/127.0.0.1/tcp/$PB" "/ip4/127.0.0.1/tcp/$PC"
sleep 120
echo "=== qué T queda fijado en cada nodo tras la publicación tardía (descriptivo, sin criterio de éxito) ===" | tee -a "$RUN/EJECUCION.txt"
for n in A B C; do
  echo "--- $n: último cambio_punta ---" >> "$RUN/EJECUCION.txt"
  grep '"tipo":"cambio_punta"' "$RUN/$n/registro.jsonl" 2>/dev/null | tail -1 >> "$RUN/EJECUCION.txt"
  echo "--- $n: reorganizacion_pow ---" >> "$RUN/EJECUCION.txt"
  grep '"tipo":"reorganizacion_pow"' "$RUN/$n/registro.jsonl" 2>/dev/null >> "$RUN/EJECUCION.txt"
done
echo "t_publicacion_tardia_ns=$t_publicacion_tardia" >> "$RUN/EJECUCION.txt"
"$VF" todos_los_resumenes_iguales "$RUN/A/registro.jsonl" "$RUN/B/registro.jsonl" "$RUN/C/registro.jsonl" | tee "$RUN/RESULTADO-e9-descriptivo.txt"
cerrar_ejecucion_txt
matar_todo_2
trap - EXIT

echo "ver RESULTADO-e7e8.txt y RESULTADO-e9-descriptivo.txt" > "$RUN_TOP/RESULTADO.txt"
touch "$RUN_TOP/.done"
echo "=== R4 $REP TERMINADO ==="
