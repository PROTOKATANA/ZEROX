#!/usr/bin/env bash
set -uo pipefail
cd /home/katana/zeo/ZEROX/deepseek/W07b/clon-c107163
export CARGO_BUILD_JOBS=8
echo "$(date -Is) === fmt ==="
cargo fmt --all -- --check
echo "fmt_exit=$?"
echo "$(date -Is) === clippy ==="
cargo clippy --workspace --all-targets --all-features --locked --jobs 8 -- -D warnings
echo "clippy_exit=$?"
echo "$(date -Is) === build ==="
cargo build --workspace --all-features --locked --jobs 8
echo "build_exit=$?"
echo "$(date -Is) === test ==="
cargo test --workspace --all-features --locked --jobs 8
echo "test_exit=$?"
echo "$(date -Is) === deps: dependencias-exactas ==="
bash ci/dependencias-exactas.sh
echo "dep1_exit=$?"
echo "$(date -Is) === deps: frontera-crates ==="
bash ci/frontera-crates.sh
echo "dep2_exit=$?"
echo "$(date -Is) === deps: firmante-obligatorio ==="
bash ci/firmante-obligatorio.sh
echo "dep3_exit=$?"
echo "$(date -Is) === release build ==="
cargo build --release --locked -p zx-node --jobs 8
echo "release_exit=$?"
echo "$(date -Is) === TODO TERMINADO ==="
