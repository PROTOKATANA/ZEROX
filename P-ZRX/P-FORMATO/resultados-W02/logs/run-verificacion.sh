#!/usr/bin/env bash
# V1–V3 y V7 de ORDEN-W02, desde ws/, entorno §4.
set -uo pipefail
Z=/home/katana/zeo/ZEROX/deepseek/W02
cd "$Z/ws"
export CARGO_HOME="$Z/.cargo-home"
export CARGO_TARGET_DIR="$Z/target"
export CARGO_BUILD_JOBS=8 RUST_TEST_THREADS=8 RUSTFLAGS=
echo "INICIO $(date -Is)"

cargo fmt --all -- --check > "$Z/logs/V1-fmt.log" 2>&1
ec1=$?; echo "V1 exit=$ec1" >> "$Z/logs/V1-fmt.log"

cargo clippy --workspace --all-targets --all-features --locked -- -D warnings \
  > "$Z/logs/V2-clippy.log" 2>&1
ec2=$?; echo "V2 exit=$ec2" >> "$Z/logs/V2-clippy.log"

cargo test --workspace --all-features --locked > "$Z/logs/V3-test.log" 2>&1
ec3=$?; echo "V3 exit=$ec3" >> "$Z/logs/V3-test.log"

bash ci/dependencias-exactas.sh > "$Z/logs/V7-deps.log" 2>&1
ec7=$?; echo "V7 exit=$ec7" >> "$Z/logs/V7-deps.log"

echo "FIN $(date -Is)"
echo "RESUMEN V1=$ec1 V2=$ec2 V3=$ec3 V7=$ec7"
exit 0
