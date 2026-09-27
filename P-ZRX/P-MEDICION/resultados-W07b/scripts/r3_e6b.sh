#!/usr/bin/env bash
# CORRECCIÓN (2026-09-27, hallazgo del director): una sola clave por nodo (A=0,B=1,C=2,D=3),
# no 0,1,2/3,4,5/6,7,8. Con varias claves por nodo, K_min=3 (PERFIL-DEV-v0.md §3, "una clave por
# nodo de la red de prueba") puede cumplirse con las 3 claves de UN solo nodo si ese nodo mina la
# mayoría de bloques PoW; los demás nodos cruzan el corte sin garantía y, sin relevo de
# transacciones en 0.0.1, ya no pueden depositar ni producir nunca (límite real del producto, no
# del arnés). Verificado en run/E2a-calibracion-intento2-timeout/: B minó 26/31 bloques PoW propios,
# A y C nunca produjeron PoST tras el corte.
# R3/E-6b de ORDEN-W07b: partición durante la fase PoW cerca del corte. A aislado desde el arranque;
# B+C juntos. Ambos lados cruzan el corte por separado (terminales distintos) y producen PoST; se
# reúne A (reinicio con --red-marcar hacia B y C; B y C NO se reinician: decisión 0 de SL-4b2,
# "el productor sigue al terminal seleccionado en caliente") con producción en marcha en los tres
# (decisión 7 de la orden). Único T final según FC-3: TRN-09/D-T03 decide **solo por el peso PoST**
# del sufijo tras el corte (blue_work de GHOSTDAG), nunca por el trabajo PoW del prefijo. En esta red
# dev, SR_dev es constante para todo bloque ⇒ w(B)=floor(2^128/(SR_dev+1)) es el mismo para todos, y
# blue_work = blue_score·w: comparar `blue_score` (evento cambio_punta, ESQUEMA §1) basta y es exacto.
# Corrección del director (2026-09-27): el defecto de ServicioPot de W06d6/DEFINICIONES-FALTANTES.md
# está corregido desde W06d7 (FC-3 real: un DAG por terminal + servicio PoT por terminal) y SL-4b2
# (decisión 0: el productor sigue al terminal en caliente, sin reiniciar el proceso). E-6b se corre
# tal cual está escrito, SIN técnica de evitación; si algún nodo se atasca es un fallo del producto:
# se para ese escenario, se conservan los registros y se sigue con los demás (no se oculta ni se
# esquiva cambiando de escenario). Adaptado, por lectura permitida, de
# deepseek/SL4b2/ejecutar_e6b.sh (validado allí con procesos reales, decisión 0).
# Uso: r3_e6b.sh <rep> <puerto_base> <semilla> <sr_dev>
set -uo pipefail
Z=/home/katana/zeo/ZEROX/deepseek/W07b
CLON="$Z/clon-3d21b1f"; BIN="$CLON/target/release"
source "$Z/scripts/lib_red.sh"

REP="${1:?uso: r3_e6b.sh <rep> <puerto_base> <semilla> <sr_dev>}"
PORT_BASE="${2:?falta puerto_base}"
SEMILLA="${3:?falta semilla}"
SRDEV="${4:?falta sr_dev}"
PA="$PORT_BASE"; PB=$((PORT_BASE + 1)); PC=$((PORT_BASE + 2))
RUN="$Z/run/R3-E6b-$REP"
mkdir -p "$RUN"
VF="$Z/scripts/verif.sh"

sin_zx_node_o_falla
puertos_libres_o_falla "$PA" "$PB" "$PC"
escribir_ejecucion_txt
{ echo "semilla=$SEMILLA"; echo "puertos: A=$PA B=$PB C=$PC"; echo "tecnica=SL4b2-e6b (A aislado desde el arranque; reunion con produccion en marcha)"; } >> "$RUN/EJECUCION.txt"

matar_todo() { matar A "$PA"; matar B "$PB"; matar C "$PC"; }
trap matar_todo EXIT

# HALLAZGO Y CORRECCIÓN (2026-09-27, en la primera ejecución real con una clave por nodo):
# con A=0 (1 clave) y B=1,C=2 (1 clave cada uno), NINGÚN lado puede cruzar el corte jamás: K_min=3
# (PERFIL-DEV-v0.md §3) exige garantía de 3 claves DISTINTAS, y en 0.0.1 no hay relevo de
# transacciones entre particiones (ESCENARIOS-0.0.1.md §4) — el lado de A (1 clave) y el lado de
# B+C (2 claves) se quedan cada uno por debajo de K_min para siempre, por diseño del escenario, no
# por un defecto del nodo. Confirmado en vivo: A minó 206 bloques PoW sin cruzar nunca
# (run/R3-E6b-3d21b1f-rep1-kmin-imposible/, conservado). A diferencia de R1/R2/E-6/E-7/E-8/E-9 (los
# 3 nodos están conectados desde el principio y juntos SÍ suman las 3 claves distintas exigidas),
# E-6b parte la red en dos ANTES del corte: cada lado necesita sus PROPIAS 3 claves para poder
# cruzar por separado, que es justamente lo que este escenario pone a prueba (dos lados
# independientes que cruzan y luego se reconcilian). Se da a cada lado 3 claves (A: 0,1,2 — es el
# único nodo de su lado, igual que en la red real un lado de una partición puede tener varios
# operadores; B+C: 3,4,5 repartidas entre los dos) — el mismo patrón, ya validado con procesos
# reales, de `deepseek/SL4b2/ejecutar_e6b.sh` (lectura permitida).
echo "$(date -Is) === E-6b $REP: A aislado desde el arranque, B+C juntos ===" | tee -a "$RUN/EJECUCION.txt"
t_particion_inicio=$(date +%s%N)
lanzar_nodo A "0,1,2" "$PA" ""
lanzar_nodo B "3,4" "$PB" ""
lanzar_nodo C "5" "$PC" "" "/ip4/127.0.0.1/tcp/$PB"

echo "=== esperando que A y (B o C) crucen el corte por separado, plazo 30 min ===" | tee -a "$RUN/EJECUCION.txt"
FIN=$(( $(date +%s) + 1800 ))
while :; do
  fatal=$("$VF" hay_fatal "$RUN"/*/stderr.log)
  if [ -n "$fatal" ]; then echo "FALLO_FATAL: $fatal" | tee -a "$RUN/EJECUCION.txt"; exit 1; fi
  pa=$("$VF" contar_evento "$RUN/A/registro.jsonl" bloque_producido)
  pb=$("$VF" contar_evento "$RUN/B/registro.jsonl" bloque_producido)
  pc=$("$VF" contar_evento "$RUN/C/registro.jsonl" bloque_producido)
  if [ "${pa:-0}" -ge 3 ] && { [ "${pb:-0}" -ge 3 ] || [ "${pc:-0}" -ge 3 ]; }; then
    echo "listo: A=$pa B=$pb C=$pc" | tee -a "$RUN/EJECUCION.txt"
    break
  fi
  if [ "$(date +%s)" -ge "$FIN" ]; then
    echo "TIMEOUT: A=$pa B=$pb C=$pc" | tee -a "$RUN/EJECUCION.txt"
    echo "NO_SUPERADO" > "$RUN/RESULTADO.txt"
    cerrar_ejecucion_txt; matar_todo; trap - EXIT; touch "$RUN/.done"; exit 2
  fi
  sleep 3
done

# Dejar un instante para que el cambio_punta más reciente de cada lado quede escrito.
sleep 2
prod_a=$("$VF" contar_evento "$RUN/A/registro.jsonl" bloque_producido)
prod_b=$("$VF" contar_evento "$RUN/B/registro.jsonl" bloque_producido)
prod_c=$("$VF" contar_evento "$RUN/C/registro.jsonl" bloque_producido)
bs_a=$("$VF" blue_score_actual "$RUN/A/registro.jsonl"); bs_a=${bs_a:-0}
bs_b=$("$VF" blue_score_actual "$RUN/B/registro.jsonl"); bs_b=${bs_b:-0}
bs_c=$("$VF" blue_score_actual "$RUN/C/registro.jsonl"); bs_c=${bs_c:-0}
# B y C comparten terminal (lado "BC"); su blue_score debería coincidir salvo desfase de escritura
# reciente: se toma el máximo de los dos como el del lado BC.
bs_bc=$bs_b; [ "$bs_c" -gt "$bs_bc" ] && bs_bc=$bs_c
echo "pesos FC-3 antes de reunir: A: bloques_producidos=$prod_a blue_score=$bs_a | BC: bloques_producidos(B+C)=$((prod_b+prod_c)) blue_score(max B,C)=$bs_bc (B=$bs_b C=$bs_c)" | tee -a "$RUN/EJECUCION.txt"
if [ "$bs_a" -gt "$bs_bc" ]; then
  prediccion="A"
elif [ "$bs_bc" -gt "$bs_a" ]; then
  prediccion="BC"
else
  prediccion="EMPATE(bs_a=bs_bc=$bs_a; desempate del motor: menor solution_distance, luego menor id — no observable desde el registro)"
fi
echo "prediccion FC-3 (mayor blue_score, proxy exacto de blue_work con SR_dev constante): $prediccion" | tee -a "$RUN/EJECUCION.txt"
{
  echo ""
  echo "## E-6b $REP ($(date -Is)): pesos FC-3 leídos ANTES de reunir"
  echo "- A: bloques_producidos=$prod_a blue_score=$bs_a"
  echo "- BC: bloques_producidos(B+C)=$((prod_b+prod_c)) blue_score(max B,C)=$bs_bc (B=$bs_b C=$bs_c)"
  echo "- predicción FC-3 (mayor blue_score gana el terminal T): $prediccion"
  echo "- ver detalle en run/R3-E6b-$REP/EJECUCION.txt"
} >> "$Z/PROGRESO.md"

t_particion_fin=$(date +%s%N)
peer_a=$("$VF" peer_id_de "$RUN/A/registro.jsonl")
peer_b=$("$VF" peer_id_de "$RUN/B/registro.jsonl")
peer_c=$("$VF" peer_id_de "$RUN/C/registro.jsonl")
# CRITERIO OBLIGATORIO DE TODA PARTICIÓN (corrección del director, 2026-09-27): 0 contacto real
# entre A y B/C durante toda la ventana de partición. En E-6b, A nunca tuvo --red-marcar hacia B/C
# ni viceversa desde el arranque, así que no debería haber contacto salvo fallo real del producto.
contactos_a=$("$VF" contactos_en_ventana "$RUN/A/registro.jsonl" "$t_particion_inicio" "$t_particion_fin" "$peer_b" "$peer_c")
contactos_b=$("$VF" contactos_en_ventana "$RUN/B/registro.jsonl" "$t_particion_inicio" "$t_particion_fin" "$peer_a")
contactos_c=$("$VF" contactos_en_ventana "$RUN/C/registro.jsonl" "$t_particion_inicio" "$t_particion_fin" "$peer_a")
echo "verificación de aislamiento: contactos_A_con_BC=$contactos_a contactos_B_con_A=$contactos_b contactos_C_con_A=$contactos_c" | tee -a "$RUN/EJECUCION.txt"
if [ "${contactos_a:-1}" -gt 0 ] || [ "${contactos_b:-1}" -gt 0 ] || [ "${contactos_c:-1}" -gt 0 ]; then
  echo "NO_VALIDA: SIN AISLAMIENTO (hubo contacto real durante la ventana de partición)" | tee -a "$RUN/EJECUCION.txt"
  echo "NO_VALIDA: SIN AISLAMIENTO" > "$RUN/RESULTADO.txt"
  cerrar_ejecucion_txt; matar_todo; trap - EXIT; touch "$RUN/.done"
  echo "=== R3/E-6b $REP: NO VÁLIDA (sin aislamiento) ==="
  exit 4
fi

echo "=== reuniendo: matando y relanzando A con --red-marcar hacia B y C (B,C NO se reinician) ===" | tee -a "$RUN/EJECUCION.txt"
t_reunion_inicio=$(date +%s%N)
matar A "$PA"
lanzar_nodo A "0,1,2" "$PA" "" "/ip4/127.0.0.1/tcp/$PB" "/ip4/127.0.0.1/tcp/$PC"

echo "=== esperando convergencia (mismo resumen_estado en los 3), plazo 20 min ===" | tee -a "$RUN/EJECUCION.txt"
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

echo "=== ¿A produjo sobre el terminal ganador tras la reunión? (últimos bloque_producido de A) ===" | tee -a "$RUN/EJECUCION.txt"
tail -5 "$RUN/A/registro.jsonl" | grep '"tipo":"bloque_producido"' >> "$RUN/EJECUCION.txt" || true
grep '"tipo":"reorganizacion_pow"' "$RUN"/*/registro.jsonl 2>/dev/null >> "$RUN/EJECUCION.txt" || true
grep '"tipo":"cambio_punta"' "$RUN/A/registro.jsonl" 2>/dev/null | tail -3 >> "$RUN/EJECUCION.txt"

echo "=== resultado final (método antiguo, informativo) ===" | tee -a "$RUN/EJECUCION.txt"
"$VF" todos_los_resumenes_iguales "$RUN/A/registro.jsonl" "$RUN/B/registro.jsonl" "$RUN/C/registro.jsonl" | tee "$RUN/RESULTADO-metodo-viejo.txt"
bs_a_final=$("$VF" blue_score_actual "$RUN/A/registro.jsonl"); bs_a_final=${bs_a_final:-0}
bs_b_final=$("$VF" blue_score_actual "$RUN/B/registro.jsonl"); bs_b_final=${bs_b_final:-0}
bs_c_final=$("$VF" blue_score_actual "$RUN/C/registro.jsonl"); bs_c_final=${bs_c_final:-0}
punta_a_final=$("$VF" terminal_actual "$RUN/A/registro.jsonl" 2>/dev/null)
echo "blue_score final: A=$bs_a_final B=$bs_b_final C=$bs_c_final" | tee -a "$RUN/EJECUCION.txt"

echo "=== reposo (decisión 6) y verificación aislada (método nuevo, decisivo) ===" | tee -a "$RUN/EJECUCION.txt"
bash "$Z/scripts/reposo_y_verificar.sh" "$RUN" "$SRDEV" "$SEMILLA" "A:0,1,2:$PA" "B:3,4:$PB" "C:5:$PC" | tee "$RUN/RESULTADO.txt"

{
  echo "- resultado tras reunir (aislado): $(cat "$RUN/RESULTADO.txt")"
  echo "- blue_score final: A=$bs_a_final B=$bs_b_final C=$bs_c_final (predicción era: $prediccion)"
} >> "$Z/PROGRESO.md"
cerrar_ejecucion_txt
matar_todo
trap - EXIT
touch "$RUN/.done"
echo "=== R3/E-6b $REP TERMINADO ==="
