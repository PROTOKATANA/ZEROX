#!/usr/bin/env bash
# Mediciones P-INTENTO — comandos exactos, reproducibles y en secuencia.
#
# Reglas:
#   - Una sola carga a la vez: nada de lanzar dos bancos en paralelo (invalidaria la medida).
#   - Tope de hilos del proyecto: 24. Nunca `--threads=auto` ni `RAYON_NUM_THREADS` sin fijar.
#   - `CARGO_TARGET_DIR` SIEMPRE dentro de la zona de trabajo: el clon es de solo lectura.
#   - Salidas crudas de Criterion -> investigacion/mediciones/
#
# Uso:  ./ejecutar-mediciones.sh [fase]
#   fase = suite | control | todo
set -euo pipefail

RAIZ="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CLON=/home/katana/zeo/fuentes/subspace
export PATH="$HOME/.cargo/bin:$PATH"
export CARGO_TARGET_DIR="$RAIZ/target"
export RAYON_NUM_THREADS=24
export OPENBLAS_NUM_THREADS=1
export BASE_PATH="$RAIZ/tmp-mediciones"
mkdir -p "$BASE_PATH"
cd "$RAIZ"
mkdir -p mediciones

# Criterion guarda estado entre corridas y luego imprime "change: ...". Se borra para que cada
# numero publicado venga de una corrida limpia.
rm -rf "$CARGO_TARGET_DIR/criterion"

# `cargo bench --bench X -- <args>` resuelve el ejecutable RECIEN construido. Buscar en deps/ a
# mano es fragil: quedan binarios de versiones anteriores y `head -1` puede coger el viejo.
banco() { (cd "$RAIZ/banco-rust" && cargo bench --bench "$1" --locked -- "${@:2}"); }

fase="${1:-todo}"

if [[ "$fase" == "suite" || "$fase" == "todo" ]]; then
  echo "=== M1 · t_tabla (Criterion) ==="
  banco m1_tabla --sample-size 10 --warm-up-time 2 --measurement-time 20 --noplot \
    2>&1 | tee mediciones/m1_tabla.txt

  echo "=== M2 · t_reto (Criterion) ==="
  banco m2_reto --sample-size 20 --warm-up-time 1 --measurement-time 5 --noplot \
    2>&1 | tee mediciones/m2_reto.txt

  echo "=== M3 · t_ganador (Criterion) ==="
  banco m3_ganador --sample-size 10 --warm-up-time 1 --measurement-time 10 --noplot \
    2>&1 | tee mediciones/m3_ganador.txt

  echo "=== M4 · cono, respuesta por bucket (Criterion) ==="
  banco m4_cono --sample-size 10 --warm-up-time 2 --measurement-time 5 --noplot \
    2>&1 | tee mediciones/m4_cono.txt

  echo "=== M4 · cono, coste de las tablas (Instant, n=3) ==="
  "$CARGO_TARGET_DIR/release/cono" 24 3 2>&1 | tee mediciones/m4_cono_tablas.txt

  echo "=== M1 · RAM por tabla viva ==="
  "$CARGO_TARGET_DIR/release/escalado" --ram 8 2>&1 | tee mediciones/m1_ram.txt

  echo "=== M1 · rendimiento agregado por hilos ==="
  : > mediciones/m1_escalado.txt
  for h in 1 2 4 8 16 24; do
    "$CARGO_TARGET_DIR/release/escalado" --modo single   --hilos "$h" --segundos 12 --reps 3 \
      2>&1 | tee -a mediciones/m1_escalado.txt
    "$CARGO_TARGET_DIR/release/escalado" --modo parallel --hilos "$h" --segundos 12 --reps 3 \
      2>&1 | tee -a mediciones/m1_escalado.txt
  done

  echo "=== M6 · energia (RAPL) — incluida en escalado ==="
  grep -c "no_leible" mediciones/m1_escalado.txt || true
fi

if [[ "$fase" == "control" || "$fase" == "todo" ]]; then
  echo "=== CONTROL · plotting/in-memory del clon (83,6 s historicos) ==="
  (cd "$CLON" && cargo bench -p subspace-farmer-components --bench plotting --locked \
      -- --sample-size 10 2>&1) | tee mediciones/clon_plotting.txt

  echo "=== CONTROL · proving del clon (camino ganador extremo a extremo) ==="
  (cd "$CLON" && cargo bench -p subspace-farmer-components --bench proving --locked \
      -- --sample-size 10 2>&1) | tee mediciones/clon_proving.txt

  echo "=== CONTROL · auditing del clon ==="
  (cd "$CLON" && SECTORS_COUNT=1 cargo bench -p subspace-farmer-components --bench auditing \
      --locked -- --sample-size 10 2>&1) | tee mediciones/clon_auditing.txt

  echo "=== CONTROL · kzg del clon ==="
  (cd "$CLON" && cargo bench -p subspace-kzg --bench kzg --locked \
      -- --sample-size 20 2>&1) | tee mediciones/clon_kzg.txt

  echo "=== CONTROL · pos del clon (banco original completo) ==="
  (cd "$CLON" && cargo bench -p subspace-proof-of-space --features alloc,parallel --bench pos \
      --locked -- --sample-size 10 2>&1) | tee mediciones/clon_pos.txt
fi

echo "=== fin ==="
date
