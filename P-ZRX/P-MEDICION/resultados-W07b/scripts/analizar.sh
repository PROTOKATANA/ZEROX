#!/usr/bin/env bash
# analizar.sh <ejecucion_dir> <nodos,separados,por,coma> [salida_dir]
# Invoca el instrumento de W07c (decisión 8 de ORDEN-W07b) sobre una ejecución concreta.
set -uo pipefail
Z=/home/katana/zeo/ZEROX/deepseek/W07b
INST="$Z/analisis-instrumento"
EJ="${1:?uso: analizar.sh <ejecucion_dir> <nodos> [salida_dir]}"
NODOS="${2:?falta nodos}"
# CORRECCIÓN DE ARNÉS (2026-09-27, hallada al analizar R1-rep1): `run.jl` hace `abspath()` de
# `--ejecucion` en el directorio de trabajo DE JULIA (que es `$INST` tras el `cd` de abajo), no en
# el directorio desde el que se invocó este guion; una ruta relativa como "run/R1-rep1" se
# resolvía entonces contra `$INST/run/R1-rep1` (inexistente) en vez de `$Z/run/R1-rep1`. Corregido
# resolviendo `EJ` a ruta absoluta ANTES del `cd`.
EJ="$(cd "$(dirname "$EJ")" && pwd)/$(basename "$EJ")"
# CORRECCIÓN DE ARNÉS (2026-09-27, hallada al analizar R4-rep1/e7e8): el mismo problema de
# `abspath()` en el cwd de Julia afecta a `--salida` cuando se pasa una ruta relativa como 3er
# argumento: el resultado real terminaba en `$INST/analisis/...` en vez de `$Z/analisis/...`.
# Corregido resolviendo también `SALIDA` a ruta absoluta ANTES del `cd`.
SALIDA="${3:-$Z/analisis/$(basename "$EJ")}"
mkdir -p "$SALIDA"
SALIDA="$(cd "$SALIDA" && pwd)"
cd "$INST"
env -u LD_LIBRARY_PATH JULIA_DEPOT_PATH="$Z/.julia-depot:/home/katana/.julia" \
  /home/katana/.julia/juliaup/julia-1.13.0+0.x64.linux.gnu/bin/julia --project=. run.jl \
  --ejecucion "$EJ" --nodos "$NODOS" --salida "$SALIDA"
