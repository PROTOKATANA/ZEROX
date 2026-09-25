#!/usr/bin/env bash
# V4: compara los nombres de test ejecutados (lineas "test <nombre> ... ok") de V3 con los de
# la linea base L01 (S1-zx-core.log + S2-zx-pot.log). Ordena y compara con diff.
set -uo pipefail
Z=/home/katana/zeo/ZEROX/deepseek/W01
L=/home/katana/zeo/ZEROX/deepseek/L01/logs
NUE="$Z"/logs/.v4-nuevo.txt
REF="$Z"/logs/.v4-ref.txt

grep -hE '^test .* \.\.\. ok$' "$Z"/logs/V3-test.log | LC_ALL=C sort > "$NUE"
grep -hE '^test .* \.\.\. ok$' "$L"/S1-zx-core.log "$L"/S2-zx-pot.log | LC_ALL=C sort > "$REF"

diff "$REF" "$NUE" > "$Z"/logs/V4-diff-raw.txt 2>&1
ec=$?

{
  echo "# V4 - Comparacion de nombres de test: salida de V3 frente a la linea base L01"
  echo "# Referencia (L01/logs/S1-zx-core.log + S2-zx-pot.log): $(wc -l < "$REF") tests"
  echo "# Nuevo (logs/V3-test.log):                            $(wc -l < "$NUE") tests"
  echo "# diff (referencia vs nuevo) exit=$ec"
  echo
  if [ "$ec" -eq 0 ]; then
    echo "RESULTADO: identicas (mismos nombres, misma cantidad)."
  else
    echo "RESULTADO: DIFERENCIAS (se muestran abajo)."
    cat "$Z"/logs/V4-diff-raw.txt
  fi
} > "$Z"/logs/V4-tests.txt

cat "$Z"/logs/V4-tests.txt
rm -f "$NUE" "$REF"
exit "$ec"
