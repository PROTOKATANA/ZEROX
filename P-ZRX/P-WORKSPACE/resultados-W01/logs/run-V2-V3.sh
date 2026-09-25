#!/usr/bin/env bash
# V2 (clippy), build de CI y V3 (tests), con el entorno de §4 de ORDEN-W01.
set -uo pipefail
Z=/home/katana/zeo/ZEROX/deepseek/W01
cd "$Z"/ws
export CARGO_HOME="$Z"/.cargo-home
export CARGO_TARGET_DIR="$Z"/target
export CARGO_BUILD_JOBS=8 RUST_TEST_THREADS=8 RUSTFLAGS=
echo "INICIO $(date -Is)"

cargo clippy --workspace --all-targets --all-features --locked -- -D warnings \
  > "$Z"/logs/V2-clippy.log 2>&1
ec2=$?
echo "V2-clippy exit=$ec2" >> "$Z"/logs/V2-clippy.log

cargo build --workspace --all-features --locked \
  > "$Z"/logs/V2b-build.log 2>&1
ecb=$?
echo "V2b-build exit=$ecb" >> "$Z"/logs/V2b-build.log

cargo test --workspace --all-features --locked \
  > "$Z"/logs/V3-test.log 2>&1
ec3=$?
echo "V3-test exit=$ec3" >> "$Z"/logs/V3-test.log

echo "FIN $(date -Is)"
echo "RESUMEN V2-clippy=$ec2 V2b-build=$ecb V3-test=$ec3"
exit 0
