#!/usr/bin/env bash
set -uo pipefail
Z=/home/katana/zeo/ZEROX/deepseek/W02
cd "$Z/ws"
export CARGO_HOME="$Z/.cargo-home"
export CARGO_TARGET_DIR="$Z/target"
export CARGO_BUILD_JOBS=8 RUST_TEST_THREADS=8 RUSTFLAGS=
cargo test -p zx-core --test zz_ancla_tmp -- --nocapture 2>&1 | tee "$Z/logs/ancla-tmp.log"
echo "EXIT=${PIPESTATUS[0]}" | tee -a "$Z/logs/ancla-tmp.log"
