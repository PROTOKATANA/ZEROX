#!/usr/bin/env bash
# run-medicion.sh — reproduce TODAS las mediciones de latencia de este encargo.
#
# DESVIACIÓN DE veritas/LINEO.md, argumentada en el CONTRATO.md y el METODO.md del instrumento:
# medir latencia de INSTRUCCIÓN exige intrínsecos y ensamblador en línea, que Julia sólo expresaría
# con `llvmcall`. Aquí van los tres programas de C y sus comandos exactos.
#
# Uso:  bash run-medicion.sh          (desde este directorio)
# Salidas: las mismas que se publicaron, en este mismo directorio.
set -euo pipefail

cd "$(dirname "$0")"
CORE="${CORE:-8}"          # el mismo core lógico que usó todo el encargo
echo "# reproducción $(date -Is)  uptime: $(uptime)" | tee REPRODUCCION.log

echo "== 1. ancla de medicion-previa (fuente intacta, solo lectura) =="
gcc -O2 -maes -msse4.1 -o aeslat ../../medicion-previa/aeslat.c
{ uptime; for i in 1 2 3; do echo "=== corrida $i ==="; taskset -c "$CORE" ./aeslat; done; } \
  | tee aeslat-corridas.txt

echo "== 2. latencia y rendimiento de instrucciones =="
gcc -O2 -march=native -maes -msse4.1 -mavx2 -mavx512f -mavx512vl -mvaes -Wall -Wextra -o aesinst aesinst.c
uptime | tee -a salida-aesinst-core8-n2e6.txt
taskset -c "$CORE" ./aesinst --n-iter 2000000 | tee -a salida-aesinst-core8-n2e6.txt

echo "== 3. latencia bajo carga conocida =="
gcc -O2 -march=native -pthread -Wall -Wextra -o carga carga.c
: > salida-carga.txt
for k in 0 1 4 8 16; do uptime | tee -a salida-carga.txt; taskset -c "$CORE" ./carga "$k" 20000000 | tee -a salida-carga.txt; done

echo "== 4. asimetria producir/verificar =="
gcc -O2 -march=native -mavx512f -mavx512vl -mvaes -maes -Wall -Wextra -o verif8 verif8.c
taskset -c "$CORE" ./verif8 300000 3 | tee salida-verif8.txt

echo "== 5. carriles y techo de la verificacion =="
gcc -O2 -march=native -mavx512f -mavx512vl -mvaes -maes -Wall -Wextra -o verif16 verif16.c
taskset -c "$CORE" ./verif16 400000 3 | tee salida-verif16.txt

echo "hecho. Compare con PROCEDENCIA.md; las cifras deben coincidir dentro del ruido de máquina."
