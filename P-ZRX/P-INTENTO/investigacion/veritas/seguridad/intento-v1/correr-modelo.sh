#!/usr/bin/env bash
# Barridos publicados del modelo intento-v1.
#
# Los parametros de red (N_h, lambda, alpha, tau, pi_DAG) son ENTRADAS: no los fija el instrumento.
# `R_s` se deriva de la calibracion del controlador `p = lambda/N_h` documentada en
# P-SEMBRADOR/investigacion/INFORME.md, y se pasa EXPLICITA para que quede en la linea de comandos.
#
# tau = 1 s. Fuente: `SLOT_DURATION = 1000` ms en
# `crates/subspace-runtime/src/lib.rs:145` del clon fijado.
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$RAIZ"
export JULIA_DEPOT_PATH="$RAIZ/../../../.julia-depot:/home/katana/.julia"
JULIA=/home/katana/zeo/ZEROX/veritas/julia.sh
MEDICIONES="$RAIZ/../../../mediciones/modelo-entrada.tsv"
mkdir -p resultados

# R_s tal que d(R_s) = 2*lambda/N_h  =>  2*floor(R_s/2)+1 = 2*lambda/N_h * 2^64
rango_para() {
  python3 -c "import sys; lam=float(sys.argv[1]); Nh=float(sys.argv[2]); print(repr(2.0*lam/Nh*2.0**64))" "$1" "$2"
}

correr() {
  local etiqueta="$1" Nh="$2" lam="$3" alpha="$4" pi="$5"
  local Rs
  Rs="$(rango_para "$lam" "$Nh")"
  echo "### $etiqueta  N_h=$Nh  lambda=$lam  alpha=$alpha  pi_DAG=$pi  R_s=$Rs"
  JULIA_NUM_THREADS=1 "$JULIA" --project=. run.jl \
    --mediciones "$MEDICIONES" \
    --rango-solucion "$Rs" \
    --N-h "$Nh" --alpha "$alpha" --tau-s 1.0 --pi-DAG "$pi" \
    --w-fijos 100,1000,10000,100000 \
    --w-min 100 --w-max 1000000 --pasos 96 \
    --salida "resultados/BARRIDO-$etiqueta.tsv"
  echo
}

# Escenarios: la red honesta se expresa en PIEZAS. 1 PiB ~= 1.07e9 piezas de 1.048.672 B.
correr "Nh-1e6"  1.0e6 1.0 0.1 1.0
correr "Nh-1e8"  1.0e8 1.0 0.1 1.0
correr "Nh-1e9"  1.0e9 1.0 0.1 1.0
correr "Nh-1e9-piDAG-0.5" 1.0e9 1.0 0.1 0.5

date
