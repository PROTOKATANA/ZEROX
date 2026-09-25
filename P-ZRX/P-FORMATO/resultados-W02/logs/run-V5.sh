#!/usr/bin/env bash
# V5: ningún test antiguo desaparece ni cambia de nombre.
set -uo pipefail
Z=/home/katana/zeo/ZEROX/deepseek/W02
W1=/home/katana/zeo/ZEROX/deepseek/W01
grep -E "^test [A-Za-z0-9_:]+" "$W1/logs/V3-test.log" | sed -E 's/^test ([^ ]+) .*/\1/' | sort -u > "$Z/logs/V5-old-names.txt"
grep -E "^test [A-Za-z0-9_:]+" "$Z/logs/V3-test.log" | sed -E 's/^test ([^ ]+) .*/\1/' | sort -u > "$Z/logs/V5-new-names.txt"
comm -23 "$Z/logs/V5-old-names.txt" "$Z/logs/V5-new-names.txt" > "$Z/logs/V5-faltantes.txt"
echo "antiguos=$(wc -l < "$Z/logs/V5-old-names.txt") nuevos=$(wc -l < "$Z/logs/V5-new-names.txt") faltantes=$(wc -l < "$Z/logs/V5-faltantes.txt")"
if [ -s "$Z/logs/V5-faltantes.txt" ]; then echo "V5 FALLA"; exit 1; fi
echo "V5 OK: todos los nombres antiguos siguen presentes"
