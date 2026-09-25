#!/usr/bin/env bash
set -uo pipefail
Z=/home/katana/zeo/ZEROX/deepseek/W02
cd "$Z/ws"
export CARGO_HOME="$Z/.cargo-home"
export CARGO_TARGET_DIR="$Z/target"
export CARGO_BUILD_JOBS=8 RUST_TEST_THREADS=8 RUSTFLAGS=
cargo fmt --all
echo "fmt exit=$?"
cargo test -p zx-core --test formato_v0 2>&1 | tee "$Z/logs/dev-formato-v0.log"
echo "EXIT=${PIPESTATUS[0]}" | tee -a "$Z/logs/dev-formato-v0.log"
