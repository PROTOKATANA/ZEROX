#!/usr/bin/env bash
# Instrumentación de observación de W07b (arnés de medición, no código del producto). Fusiona y
# amplía, por lectura permitida, los patrones de deepseek/W06d6/scripts_verif.sh,
# deepseek/W06d7/scripts_verif.sh y deepseek/SL4b2/scripts_verif.sh; todo el código de este archivo
# es nuevo (escrito para W07b).
set -uo pipefail

contar_evento() {
  local c
  c=$(grep -c "\"tipo\":\"$2\"" "$1" 2>/dev/null)
  echo "${c:-0}"
}

hay_fatal() {
  grep -lE "error fatal|no se pudo arrancar la red|panicked at" "$@" 2>/dev/null
}

# espera_suma_bloques <minimo> <plazo_s> <registros...> -- <stderr...>
espera_suma_bloques() {
  local minimo="$1" plazo="$2"; shift 2
  local regs=()
  while [ "$1" != "--" ]; do regs+=("$1"); shift; done
  shift
  local errs=("$@")
  local fin=$(( $(date +%s) + plazo )) total=0
  while [ "$(date +%s)" -lt "$fin" ]; do
    total=0
    for r in "${regs[@]}"; do
      c=$(contar_evento "$r" bloque_producido)
      total=$((total + c))
    done
    if [ -n "$(hay_fatal "${errs[@]}")" ]; then
      echo "FALLO_FATAL $(hay_fatal "${errs[@]}")"
      return 1
    fi
    if [ "$total" -ge "$minimo" ]; then
      echo "EXITO total=$total"
      return 0
    fi
    sleep 2
  done
  echo "TIMEOUT total=$total"
  return 2
}

ultimo_slot_conocido() {
  local propio ajeno
  propio=$(grep '"tipo":"bloque_producido"' "$1" 2>/dev/null \
    | tail -1 | grep -o '"slot":[0-9]*' | grep -o '[0-9]*')
  ajeno=$(grep '"tipo":"bloque_red_admitido"' "$1" 2>/dev/null \
    | grep '"familia":"post"' | tail -1 | grep -o '"slot":[0-9]*' | grep -o '[0-9]*')
  propio=${propio:-0}
  ajeno=${ajeno:-0}
  if [ "$propio" -ge "$ajeno" ]; then echo "$propio"; else echo "$ajeno"; fi
}

huerfanos_actuales() {
  local h r
  h=$(contar_evento "$1" bloque_red_huerfano)
  r=$(contar_evento "$1" huerfano_resuelto)
  echo $((h - r))
}

terminal_actual() {
  grep '"tipo":"cambio_punta"' "$1" 2>/dev/null | tail -1 | grep -o '"terminal":"[^"]*"'
}

# blue_score_actual <registro> : blue_score del último cambio_punta (proxy exacto de blue_work de
# FC-3 en esta red dev, porque SR_dev es constante: w(B) = floor(2^128/(SR_dev+1)) es el mismo para
# todo bloque PoST, luego blue_work = blue_score * w y comparar blue_score basta para decidir FC-3).
blue_score_actual() {
  grep '"tipo":"cambio_punta"' "$1" 2>/dev/null | tail -1 | grep -o '"blue_score":[0-9]*' | grep -o '[0-9]*'
}

resumen_actual() {
  grep '"tipo":"cambio_punta"' "$1" 2>/dev/null | tail -1 | grep -o '"resumen_estado":"[^"]*"'
}

todos_los_resumenes_iguales() {
  local primero="" primero_punta=""
  for r in "$@"; do
    local linea resumen punta
    linea=$(grep '"tipo":"cambio_punta"' "$r" 2>/dev/null | tail -1)
    resumen=$(echo "$linea" | grep -o '"resumen_estado":"[^"]*"')
    punta=$(echo "$linea" | grep -o '"punta":"[^"]*"')
    if [ -z "$resumen" ]; then
      echo "SIN_RESUMEN $r"
      return 1
    fi
    if [ -z "$primero" ]; then
      primero="$resumen"; primero_punta="$punta"
    elif [ "$resumen" != "$primero" ] || [ "$punta" != "$primero_punta" ]; then
      echo "DIVERGEN $r: punta=$punta resumen=$resumen (esperado punta=$primero_punta resumen=$primero)"
      return 1
    fi
  done
  echo "CONVERGEN punta=$primero_punta resumen=$primero"
  return 0
}

# reposo_alcanzado <registros...> : cuenta cuántos tienen >=1 "dejar_de_producir"
reposo_listos() {
  local n=0
  for r in "$@"; do
    local c
    c=$(contar_evento "$r" dejar_de_producir)
    [ "${c:-0}" -ge 1 ] && n=$((n + 1))
  done
  echo "$n"
}

# sin_cambio_punta_en <segundos> <registro> : true (echo 1) si no hay cambio_punta con
# reloj_pared_ns dentro de la ventana [ahora-segundos, ahora]. Aproximado: usa el reloj de pared
# real del sistema al invocar (no el del proceso), válido porque estamos comparando el ULTIMO
# cambio_punta contra "ahora" en el mismo host.
ultimo_cambio_punta_hace_ns() {
  local ahora_ns linea t
  ahora_ns=$(date +%s%N)
  linea=$(grep '"tipo":"cambio_punta"' "$1" 2>/dev/null | tail -1)
  t=$(echo "$linea" | grep -o '"reloj_pared_ns":[0-9]*' | grep -o '[0-9]*')
  [ -z "$t" ] && { echo "-1"; return; }
  echo $(( ahora_ns - t ))
}

# peer_id_de <registro> : el peer_id del primer evento "arranque" del registro.
peer_id_de() {
  grep '"tipo":"arranque"' "$1" 2>/dev/null | head -1 | grep -o '"peer_id":"[^"]*"' | sed -E 's/.*:"([^"]*)"/\1/'
}

# contactos_en_ventana <registro> <t0_pared_ns> <t1_pared_ns> <peer_id> [peer_id2 ...]
# Cuenta líneas "par_conectado" o "bloque_recibido" con reloj_pared_ns en [t0,t1] cuyo campo "par"
# coincide con alguno de los peer_id dados. Corrección del director 2026-09-27 (E-6/E-6b: el primer
# intento de "aislar" A reutilizaba su mismo puerto, y B/C lo redescubrían solos por reintento de
# dial): esto comprueba EMPÍRICAMENTE que no hubo contacto real durante la ventana de partición,
# usando reloj_pared_ns (reloj de pared, comparable entre procesos distintos), no reloj_ns (que se
# reinicia en cada arranque de proceso).
contactos_en_ventana() {
  local reg="$1" t0="$2" t1="$3"; shift 3
  local ids="$*"
  awk -v t0="$t0" -v t1="$t1" -v ids="$ids" '
    BEGIN { n = split(ids, arr, " "); }
    (index($0, "\"tipo\":\"par_conectado\"") > 0 || index($0, "\"tipo\":\"bloque_recibido\"") > 0) {
      if (!match($0, /"reloj_pared_ns":[0-9]+/)) next
      rp = substr($0, RSTART+17, RLENGTH-17) + 0
      if (rp < t0+0 || rp > t1+0) next
      if (!match($0, /"par":"[^"]*"/)) next
      par = substr($0, RSTART+6, RLENGTH-7)
      for (i = 1; i <= n; i++) if (par == arr[i]) { c++; break }
    }
    END { print c+0 }
  ' "$reg"
}

# total_post_dag <registro> : bloques PoST distintos conocidos por este nodo (propios + ajenos
# admitidos por red), acumulado desde el inicio del registro. Usado para E-2a (bloques por slot).
total_post_dag() {
  local propios ajenos
  propios=$(contar_evento "$1" bloque_producido)
  ajenos=$(grep -c '"tipo":"bloque_red_admitido".*"familia":"post"' "$1" 2>/dev/null)
  echo $(( ${propios:-0} + ${ajenos:-0} ))
}

# resumen_tras_reinicio <registro> : el ÚLTIMO "cambio_punta" del registro, con la comprobación
# empírica de que existe "reinicio_completo" (repetición del almacén terminada). Corrección del
# director 2026-09-27 (método nuevo de E-3): la primera versión de esta función buscaba un
# cambio_punta con reloj_ns POSTERIOR a reinicio_completo — comprobado empíricamente en
# run/R1-rep1/A/registro-e3aislado.jsonl que NO EXISTE tal evento: `reinicio_completo` se escribe
# SIEMPRE al final, después de todos los cambio_punta que produce la repetición del almacén (orden
# real observado, no supuesto). El estado final correcto tras repetir el almacén es, por tanto, el
# ÚLTIMO cambio_punta del registro completo (que ya refleja todos los bloques, incluidos los
# laterales, porque el nodo los reprocesó todos antes de declarar reinicio_completo). Se conserva la
# comprobación de que `reinicio_completo` existe (evidencia de que la repetición realmente terminó);
# vacío (y exit 1) si falta cualquiera de los dos.
resumen_tras_reinicio() {
  local reg="$1"
  local t_reinicio
  t_reinicio=$(grep -c '"tipo":"reinicio_completo"' "$reg" 2>/dev/null)
  if [ -z "$t_reinicio" ] || [ "$t_reinicio" -lt 1 ]; then return 1; fi
  local linea
  linea=$(grep '"tipo":"cambio_punta"' "$reg" 2>/dev/null | tail -1)
  if [ -z "$linea" ]; then return 1; fi
  echo "$linea"
  return 0
}

# resumen_y_punta_de_linea <linea_cambio_punta> : extrae "punta":"..." y "resumen_estado":"..."
resumen_y_punta_de_linea() {
  local linea="$1"
  local punta resumen
  punta=$(echo "$linea" | grep -o '"punta":"[^"]*"')
  resumen=$(echo "$linea" | grep -o '"resumen_estado":"[^"]*"')
  echo "${punta} ${resumen}"
}

ultima_linea() {
  grep "\"tipo\":\"$2\"" "$1" 2>/dev/null | tail -1
}

cmd="${1:-}"; shift || true
case "$cmd" in
  contar_evento) contar_evento "$@" ;;
  hay_fatal) hay_fatal "$@" ;;
  espera_suma_bloques) espera_suma_bloques "$@" ;;
  ultimo_slot_conocido) ultimo_slot_conocido "$@" ;;
  huerfanos_actuales) huerfanos_actuales "$@" ;;
  terminal_actual) terminal_actual "$@" ;;
  resumen_actual) resumen_actual "$@" ;;
  blue_score_actual) blue_score_actual "$@" ;;
  todos_los_resumenes_iguales) todos_los_resumenes_iguales "$@" ;;
  reposo_listos) reposo_listos "$@" ;;
  ultimo_cambio_punta_hace_ns) ultimo_cambio_punta_hace_ns "$@" ;;
  ultima_linea) ultima_linea "$@" ;;
  total_post_dag) total_post_dag "$@" ;;
  resumen_tras_reinicio) resumen_tras_reinicio "$@" ;;
  peer_id_de) peer_id_de "$@" ;;
  contactos_en_ventana) contactos_en_ventana "$@" ;;
  *) echo "subcomando desconocido: $cmd" >&2; exit 2 ;;
esac
