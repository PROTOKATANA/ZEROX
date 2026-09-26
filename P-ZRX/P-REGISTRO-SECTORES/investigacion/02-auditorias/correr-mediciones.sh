#!/usr/bin/env bash
# Series de medición de S02a.
# Presupuesto GLOBAL de espera por carga: 20 min. Antes de cada serie se mira la carga de 1 min;
# si supera 4 y queda presupuesto, se espera; si no, se mide igual y se registra la carga.
set -u
cd /home/katana/zeo/ZEROX/deepseek/S02a/prototipo
source /home/katana/zeo/ZEROX/deepseek/S02a/entorno.sh
BIN=./../target/release/s02a
LOGDIR=../logs
RES=../resultados
mkdir -p "$LOGDIR" "$RES"

T0_GLOBAL=$(date +%s)
PRESUPUESTO_ESPERA=1200   # segundos en total

carga() { awk '{print $1}' /proc/loadavg; }

esperar_global() {
  while :; do
    local l1 ahora usado
    l1=$(carga)
    ahora=$(date +%s)
    usado=$((ahora - T0_GLOBAL))
    if awk -v l="$l1" 'BEGIN{exit !(l<=4)}'; then return 0; fi
    if [ "$usado" -ge "$PRESUPUESTO_ESPERA" ]; then
      echo "$(date -Is) PRESUPUESTO DE ESPERA AGOTADO carga_1min=$l1" >> "$LOGDIR/esperas.log"
      return 1
    fi
    echo "$(date -Is) espera carga_1min=$l1 usado_s=$usado" >> "$LOGDIR/esperas.log"
    sleep 30
  done
}

serie() {
  local T=$1 P=$2 N=$3 L=$4
  esperar_global
  local marca="P${P}-T${T}"
  echo "$(date -Is) SERIE $marca N=$N L=$L carga_antes=$(carga)" >> "$LOGDIR/series.log"
  RAYON_NUM_THREADS=$T /usr/bin/time -f "real=%e user=%U sys=%S" "$BIN" medir "$P" "$N" "$L" \
    > "$RES/medir-${marca}.tsv" 2> "$LOGDIR/medir-${marca}.time"
  echo "$(date -Is) SERIE $marca fin $(cat "$LOGDIR/medir-${marca}.time") carga_despues=$(carga)" >> "$LOGDIR/series.log"
}

# Prioridad: los tres tamaños de S01 a 16 hilos.
serie 16 2 30 0,1,2,4,8
serie 16 3 30 0,1,2,4,8
serie 16 4 30 0,1,2,4,8
# Escalado de hilos (malla reducida).
serie 1 2 10 0,1,2,4
serie 1 4 10 0,1,2,4
serie 4 4 10 0,1,2,4
serie 8 4 10 0,1,2,4
# Tamaño mayor, si el presupuesto alcanza.
serie 16 16 30 0,1,2,4,8
echo "$(date -Is) FIN series" >> "$LOGDIR/series.log"
