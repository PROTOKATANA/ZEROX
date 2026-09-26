# Entorno de compilación de S02a: todo dentro de la zona (ruta absoluta, no $PWD).
export S02A_ROOT="/home/katana/zeo/ZEROX/deepseek/S02a"
export CARGO_HOME="$S02A_ROOT/.cargo-home"
export CARGO_TARGET_DIR="$S02A_ROOT/target"
export CARGO_BUILD_JOBS=16
export PATH="/home/katana/.cargo/bin:$PATH"
