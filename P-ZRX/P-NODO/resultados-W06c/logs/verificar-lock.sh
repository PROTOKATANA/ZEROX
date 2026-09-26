#!/usr/bin/env bash
# Demuestra que TODAS las dependencias (transitivas) de `zx-p2p` usan exactamente las versiones
# del `Cargo.lock` de `9681061`. Sin Python: jq + awk + git.
set -euo pipefail
cd "$(dirname "$0")/.."          # raíz de la zona W06c
zona=$(pwd)
repo="/home/katana/zeo/ZEROX"

export CARGO_HOME="$zona/.cargo-home"
( cd ws && cargo metadata --locked --offline --format-version 1 ) > logs/metadata.json

# 1. Cierre transitivo de `zx-p2p` desde el grafo resuelto.
jq -r '.packages[] | .id + "\t" + .name + "\t" + .version' logs/metadata.json > logs/pkg.tsv
jq -r '.resolve.nodes[] | .id + "\t" + ([.deps[].pkg] | join(","))' logs/metadata.json > logs/edges.tsv
awk -F'\t' '
NR==FNR { name[$1]=$2; ver[$1]=$3; next }
{ edges[$1]=$2 }
END {
  start="";
  for (id in name) if (name[id]=="zx-p2p") start=id;
  if (start=="") { print "no zx-p2p en el grafo" > "/dev/stderr"; exit 1 }
  n=0; q[++n]=start; seen[start]=1; head=0;
  while (head < n) {
    cur=q[++head];
    m=split(edges[cur], deps, ",");
    for (i=1;i<=m;i++) { d=deps[i]; if (d!="" && !(d in seen)) { seen[d]=1; q[++n]=d } }
  }
  for (i=1;i<=n;i++) print name[q[i]] "\t" ver[q[i]];
}' logs/pkg.tsv logs/edges.tsv | sort -u > logs/closure.tsv

# 2. Versiones del lock antiguo.
git -C "$repo" show 9681061:Cargo.lock > logs/lock-9681061.txt
awk '
/^name = / { n=$3 }
/^version = / { v=$3; gsub(/"/,"",n); gsub(/"/,"",v); print n"\t"v }
' logs/lock-9681061.txt | sort -u > logs/lock-9681061.tsv

# 3. Cotejo paquete a paquete.
awk -F'\t' '
NR==FNR { viejo[$1"\t"$2]=1; nombres_viejos[$1]=1; total_viejo++; next }
{
  total_nuevo++;
  if (($1"\t"$2) in viejo) { coinciden++ }
  else if ($1 in nombres_viejos) { print "DIFERENTE\t"$1"\t"$2 > "/dev/stderr"; discrepan++ }
  else { print "AUSENTE-EN-9681061\t"$1"\t"$2 > "/dev/stderr"; discrepan++ }
}
END {
  printf "paquetes en el cierre de zx-p2p: %d\n", total_nuevo;
  printf "con version identica al lock de 9681061: %d\n", coinciden;
  printf "discrepancias: %d\n", discrepan;
  if (discrepan > 0) exit 1;
}' logs/lock-9681061.tsv logs/closure.tsv > logs/lock-subconjunto.txt 2> logs/lock-subconjunto.discrepancias.txt

cat logs/lock-subconjunto.txt
{ echo; echo "── cierre transitivo de zx-p2p (nombre<TAB>version) ──"; cat logs/closure.tsv; } >> logs/lock-subconjunto.txt
