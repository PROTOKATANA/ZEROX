#!/usr/bin/env bash
# Comprueba que cada name+version del Cargo.lock recortado (ws/) existe con la MISMA
# version en el Cargo.lock antiguo (9681061). Solo shell/awk/sort/comm: sin Python.
set -euo pipefail
Z=/home/katana/zeo/ZEROX/deepseek/W01
ANT="$Z"/extract/Cargo.lock
NUE="$Z"/ws/Cargo.lock
LOG="$Z"/logs/lock-subconjunto.txt
TMP="$Z"/logs/.tmp-lock
rm -rf "$TMP"; mkdir -p "$TMP"

extrae() {
  awk '
    /^\[\[package\]\]/ { if (n != "" && v != "") print n " " v; n=""; v=""; next }
    /^\[/             { if (n != "" && v != "") print n " " v; n=""; v=""; next }
    $1 == "name"    && $2 == "=" { n = $3; gsub(/"/, "", n) }
    $1 == "version" && $2 == "=" { v = $3; gsub(/"/, "", v) }
    END               { if (n != "" && v != "") print n " " v }
  ' "$1" | LC_ALL=C sort -u
}

extrae "$ANT" > "$TMP"/antiguo.txt
extrae "$NUE" > "$TMP"/nuevo.txt
LC_ALL=C comm -13 "$TMP"/antiguo.txt "$TMP"/nuevo.txt > "$TMP"/solo-nuevo.txt
LC_ALL=C comm -23 "$TMP"/antiguo.txt "$TMP"/nuevo.txt > "$TMP"/recortados.txt

{
  echo "# Comparación de subconjunto entre el Cargo.lock antiguo (9681061) y el recortado (ws/)"
  echo "# Antiguo: $(wc -l < "$TMP"/antiguo.txt) paquetes name+version"
  echo "# Nuevo:   $(wc -l < "$TMP"/nuevo.txt) paquetes name+version"
  echo "# Recortados (en antiguo, no en nuevo): $(wc -l < "$TMP"/recortados.txt)"
  echo "# Paquetes del nuevo AUSENTES en el antiguo: $(wc -l < "$TMP"/solo-nuevo.txt)"
  echo
  echo "## V-lock: nuevo es subconjunto del antiguo con la misma version. Ausentes:"
  if [ -s "$TMP"/solo-nuevo.txt ]; then
    cat "$TMP"/solo-nuevo.txt
    echo "RESULTADO: FALLA"
  else
    echo "(vacio)"
    echo "RESULTADO: OK - todo name+version del lock nuevo existe con la misma version en el antiguo"
  fi
  echo
  echo "## Paquetes recortados (solo los usaban crates no portados):"
  cat "$TMP"/recortados.txt
} > "$LOG"

cat "$LOG"
if [ -s "$TMP"/solo-nuevo.txt ]; then
  echo "VERIFICACION_LOCK=FALLA"
  exit 1
fi
echo "VERIFICACION_LOCK=OK"
rm -rf "$TMP"
