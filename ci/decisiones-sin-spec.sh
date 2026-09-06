#!/usr/bin/env bash
# ¿Hay decisiones que se tomaron y nunca llegaron al contrato?
#
# El SPEC es lo único que leen los otros dos guardianes y `spec_numeros.rs`. Una constante o una
# regla que vive solo en DECISIONES.md está exactamente donde la defensa no mira.
#
# Ocurrió DOS VECES el 2026-09-05, y ninguna la cazó nada:
#   · §25 fijó UMBRAL_CHECKPOINT solo en el vault. Estaba mil veces bajo y pasó revisión.
#   · §19 decidió la recalibración del PoT y la atadura slot↔timestamp. El SPEC tiene CERO
#     reglas C-POT y cero menciones de TIEMPO_GENESIS. Se descubrió por casualidad, un día después.
#
# Este guardián exige que toda sección de DECISIONES.md marcada DECIDIDO/FIJADO/DERIVADO cite al
# menos una regla C-XXX-NN que EXISTA en SPEC.md. No comprueba que la regla diga lo correcto —eso
# es de los otros— sino que el puente exista.
set -uo pipefail
cd "$(dirname "$0")/.."

VAULT=/home/katana/zeo/NODOS/ZEROX/DECISIONES.md
LISTA=ci/decisiones-sin-regla.txt
[[ -r $VAULT ]] || { echo "No encuentro $VAULT — ¿cambió el árbol del vault?"; exit 2; }

# Reglas que el SPEC declara de verdad (con **) — mismo criterio que ci/citas-spec.sh
mapfile -t EN_SPEC < <(grep -oP '^\*\*\K[A-Z]+-[A-Z]+-[0-9]+[a-z]?' SPEC.md | sort -u)
declare -A HAY; for r in "${EN_SPEC[@]}"; do HAY[$r]=1; done

huerfanas=()
seccion=""; cita_ok=0
while IFS= read -r linea; do
  if [[ $linea =~ ^##[[:space:]]+§?([0-9]+)[[:space:]]*·[[:space:]]*(.*)$ ]]; then
    # OJO: guardar los grupos ANTES de cualquier otro =~, que pisa BASH_REMATCH.
    num="${BASH_REMATCH[1]}"; titulo="${BASH_REMATCH[2]}"
    [[ -n $seccion && $cita_ok -eq 0 ]] && huerfanas+=("$seccion")
    seccion=""; cita_ok=0
    if [[ $titulo =~ (DECIDIDO|FIJADO|DERIVADO) ]]; then
      seccion="§${num} · $(echo "$titulo" | cut -c1-58)"
    fi
    continue
  fi
  [[ -z $seccion ]] && continue
  while read -r r; do [[ -n ${HAY[$r]:-} ]] && cita_ok=1; done < <(grep -oE '[A-Z]+-[A-Z]+-[0-9]+[a-z]?' <<<"$linea")
done < "$VAULT"
[[ -n $seccion && $cita_ok -eq 0 ]] && huerfanas+=("$seccion")

pendientes=()
for h in "${huerfanas[@]}"; do
  grep -qxF "${h%% ·*}" "$LISTA" 2>/dev/null || pendientes+=("$h")
done

if ((${#pendientes[@]})); then
  echo "Decisiones que NO citan ninguna regla existente del SPEC:"
  printf '  %s\n' "${pendientes[@]}"
  echo
  echo "Una decisión que solo vive en el vault está donde los guardianes no miran."
  echo "Escribe su regla en SPEC.md, o declara la sección en $LISTA con el motivo."
  exit 1
fi
echo "Todas las decisiones tienen puente al SPEC."
