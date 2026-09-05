#!/usr/bin/env bash
# ¿Hay reglas del SPEC que ningún código cita?
#
# Es la otra mitad de ci/alcance-consenso.sh. Aquella pregunta si hay código que nadie ejecuta;
# esta, si hay reglas que nadie implementa. Las dos han dado positivos graves en este proyecto.
#
# Una regla sin cita puede ser tres cosas, y solo la primera es un fallo:
#   - un hueco: la regla existe, el código debería cumplirla, y nadie la escribió
#   - una prohibición: la regla dice qué NO hacer, y no hay nada que citar
#   - trabajo futuro: la fase que la implementa no ha llegado
#
# Las dos últimas van en ci/reglas-sin-codigo.txt con su motivo. Las primeras fallan aquí.
#
# ⚠️ Citar en rango NO cuenta. `C-BLK-01..03` no lo encuentra ninguna búsqueda por número, y esa
# búsqueda es cómo se comprueba la trazabilidad. Se escriben los tres números.
set -uo pipefail
cd "$(dirname "$0")/.."

LISTA=ci/reglas-sin-codigo.txt
sin_cita=()

while read -r r; do
  grep -rq --include=*.rs -e "$r" crates/ || sin_cita+=("$r")
done < <(grep -oP '^\*\*\K[A-Z]+-[A-Z]+-[0-9]+[a-z]?' SPEC.md | sort -u)

no_declaradas=()
for r in "${sin_cita[@]:-}"; do
  [ -z "$r" ] && continue
  grep -qxF "$r" "$LISTA" 2>/dev/null || no_declaradas+=("$r")
done

if [ "${#no_declaradas[@]}" -gt 0 ]; then
  echo "Reglas del SPEC que ningún código cita y que no están declaradas:"
  printf '  %s\n' "${no_declaradas[@]}"
  echo
  echo "Si la regla debería estar implementada, impleméntala o añade la cita donde ya lo esté."
  echo "Si es una prohibición o trabajo futuro, añádela a $LISTA con el motivo."
  echo "Ojo: citar en rango (C-XXX-01..03) NO cuenta. Escribe los números."
  exit 1
fi

obsoletas=()
while read -r linea; do
  case "$linea" in ''|'#'*) continue;; esac
  encontrada=0
  for r in "${sin_cita[@]:-}"; do [ "$r" = "$linea" ] && encontrada=1 && break; done
  [ "$encontrada" -eq 0 ] && obsoletas+=("$linea")
done < "$LISTA"

if [ "${#obsoletas[@]}" -gt 0 ]; then
  echo "Estas ya se citan en el código: quítalas de $LISTA."
  printf '  %s\n' "${obsoletas[@]}"
  exit 1
fi

total=$(grep -cP '^\*\*[A-Z]+-[A-Z]+-[0-9]+' SPEC.md)
echo "Citas del SPEC: $total reglas, todas implementadas o declaradas. OK"
