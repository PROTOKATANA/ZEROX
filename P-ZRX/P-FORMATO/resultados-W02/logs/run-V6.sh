#!/usr/bin/env bash
# V6: los tests antiguos y el testdata antiguo frente a 29b6bd6.
set -uo pipefail
R=/home/katana/zeo/ZEROX
Z=/home/katana/zeo/ZEROX/deepseek/W02
cd "$Z/ws"
out="$Z/logs/V6-diff.txt"
: > "$out"
n=0; d=0
for f in $(git -C "$R" ls-tree -r --name-only 29b6bd6 -- crates/zx-core/tests testdata); do
  n=$((n+1))
  if git -C "$R" show "29b6bd6:$f" 2>/dev/null | cmp -s - "$f"; then
    echo "IDENTICO $f" >> "$out"
  else
    d=$((d+1))
    echo "DIFIERE  $f" >> "$out"
    git -C "$R" show "29b6bd6:$f" > "$Z/logs/.v6-tmp"
    diff -u "$Z/logs/.v6-tmp" "$f" >> "$out" 2>&1 || true
  fi
done
rm -f "$Z/logs/.v6-tmp"
echo "comparados=$n identicos=$((n-d)) difieren=$d"
grep '^DIFIERE' "$out" || true
