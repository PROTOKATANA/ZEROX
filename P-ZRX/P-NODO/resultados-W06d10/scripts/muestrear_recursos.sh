#!/usr/bin/env bash
# muestrear_recursos.sh <pid> <dir_datos> <csv_salida>
#
# Arnés de W07b (ORDEN-W07b decisión 5, ESQUEMA-REGISTRO-v1.md §2): muestrea /proc/<pid>/{stat,io}
# cada 1 s y el tamaño de <dir_datos> cada 10 s (repetido entre muestras), en bash puro (sin
# Python). Columnas exactas del esquema:
#   reloj_pared_ns,pid,utime_ticks,stime_ticks,rss_kib,read_bytes,write_bytes,disco_datos_bytes
# Termina solo cuando el proceso <pid> deja de existir (o si recibe TERM/INT).
set -uo pipefail

PID="${1:?uso: muestrear_recursos.sh <pid> <dir_datos> <csv_salida>}"
DATOS="${2:?falta dir_datos}"
CSV="${3:?falta csv_salida}"

PAGESIZE=$(getconf PAGESIZE 2>/dev/null || echo 4096)

trap 'exit 0' TERM INT

disco_bytes=0
contador=0

while kill -0 "$PID" 2>/dev/null; do
  reloj_pared_ns=$(date +%s%N)
  if [ -r "/proc/$PID/stat" ]; then
    # Campos de /proc/pid/stat: el 2º (comm) puede contener espacios y paréntesis; se localiza por
    # el último ')' para no romper el conteo posicional (práctica estándar de /proc).
    linea=$(cat "/proc/$PID/stat" 2>/dev/null)
    resto="${linea#*) }"
    # tras el "pid (comm) ", el campo 3 es state; utime es el campo 14 del total, es decir el 12º
    # de "resto" (resto empieza en el campo 3 = state).
    utime=$(echo "$resto" | awk '{print $12}')
    stime=$(echo "$resto" | awk '{print $13}')
  else
    utime=""
    stime=""
  fi
  if [ -r "/proc/$PID/status" ]; then
    rss_kib=$(awk '/^VmRSS:/{print $2}' "/proc/$PID/status" 2>/dev/null)
  else
    rss_kib=""
  fi
  if [ -r "/proc/$PID/io" ]; then
    read_bytes=$(awk '/^read_bytes:/{print $2}' "/proc/$PID/io" 2>/dev/null)
    write_bytes=$(awk '/^write_bytes:/{print $2}' "/proc/$PID/io" 2>/dev/null)
  else
    read_bytes=""
    write_bytes=""
  fi
  if [ $((contador % 10)) -eq 0 ]; then
    if [ -d "$DATOS" ]; then
      disco_bytes=$(du -sb "$DATOS" 2>/dev/null | awk '{print $1}')
      [ -z "$disco_bytes" ] && disco_bytes=0
    else
      disco_bytes=0
    fi
  fi
  echo "${reloj_pared_ns},${PID},${utime:-0},${stime:-0},${rss_kib:-0},${read_bytes:-0},${write_bytes:-0},${disco_bytes}" >> "$CSV"
  contador=$((contador + 1))
  sleep 1
done
exit 0
