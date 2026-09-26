#!/usr/bin/env bash
# CORRECCION-A10-M1-B — repetir la escala CPU en reposo.
# Mismo binario ya compilado y mismo metodo que correr_cpu_bench.sh:
#   hilos 1,2,4,8,16,32, taskset, 5 repeticiones de 10 s.
# Antes de cada serie espera a que la carga de 1 minuto de /proc/loadavg baje de 1,0
# (pasos de 30 s, maximo 20 min por serie); si no baja, marca la serie "con carga" y sigue.
# Sin Python. Nada fuera de la zona. Sin git.
set -uo pipefail
cd /home/katana/zeo/ZEROX/deepseek/A10M1

BIN=cargo-target/release/examples/bench_pow
OUT=cpu_bench_reposo.log
DUR=10
REPS=5
THREADS=(1 2 4 8 16 32)
UMBRAL=1.0
PASO=30            # segundos por espera
MAX_ESPERA=1200    # 20 min por serie

snapshot() {
  echo "--- $1 $(date -Is) ---"
  uptime
  echo "loadavg: $(cat /proc/loadavg)"
  nproc
  ps -eo pid,pcpu,pmem,comm --sort=-pcpu | head -11
}

carga_1min() { cut -d' ' -f1 /proc/loadavg; }

carga_ge_umbral() { awk -v c="$1" -v u="$UMBRAL" 'BEGIN { exit !(c >= u) }'; }

{
  echo "== CORRECCION-A10-M1-B: banco CPU en reposo (binario y metodo de ORDEN-A10-M1) =="
  echo "== umbral carga 1-min = $UMBRAL ; espera en pasos de ${PASO}s ; maximo ${MAX_ESPERA}s (20 min) por serie =="
  snapshot "ANTES-DE-TODO"
  for t in "${THREADS[@]}"; do
    cpuset="0-$((t-1))"
    snapshot "ANTES-t$t"

    esperado=0
    con_carga=0
    c=$(carga_1min)
    while carga_ge_umbral "$c"; do
      if [ "$esperado" -ge "$MAX_ESPERA" ]; then
        con_carga=1
        echo "t=$t ESPERA: carga_1min=$c >= $UMBRAL tras ${esperado}s; se agota el maximo de ${MAX_ESPERA}s -> serie CON CARGA"
        break
      fi
      echo "t=$t ESPERA: carga_1min=$c >= $UMBRAL; duerme ${PASO}s (acumulado ${esperado}s)"
      sleep "$PASO"
      esperado=$((esperado + PASO))
      c=$(carga_1min)
    done
    if [ "$con_carga" -eq 0 ]; then
      echo "t=$t REPOSO: carga_1min=$c < $UMBRAL (espera acumulada ${esperado}s)"
    fi

    echo "t=$t INICIO-MEDIDA: $(date -Is) carga_1min=$(carga_1min) cpuset=$cpuset"
    for r in $(seq 1 "$REPS"); do
      if linea=$(taskset -c "$cpuset" "$BIN" cpu-bench-mt "$t" "$DUR" 2>&1); then
        echo "t=$t rep=$r cpuset=$cpuset $linea"
      else
        echo "t=$t rep=$r cpuset=$cpuset ERROR status=$? $linea"
      fi
    done
    echo "t=$t FIN-MEDIDA: $(date -Is) carga_1min=$(carga_1min)"
    if [ "$con_carga" -eq 1 ]; then
      echo "t=$t ESTADO=CON_CARGA espera_s=$esperado"
    else
      echo "t=$t ESTADO=EN_REPOSO espera_s=$esperado"
    fi
    snapshot "DESPUES-t$t"
  done
  snapshot "DESPUES-DE-TODO"
} > "$OUT" 2>&1

echo "hecho"
