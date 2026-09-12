#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"

categoria="${1:?uso: nueva-auditoria.sh <categoria> <nombre-auditoria>}"
nombre="${2:?uso: nueva-auditoria.sh <categoria> <nombre-auditoria>}"

case "$categoria" in
  *[!a-z0-9-]*|"")
    echo "categoria invalida: usa minusculas, digitos y guiones (ej. rendimiento)" >&2
    exit 1
    ;;
esac

destino="$(pwd)/$categoria/$nombre"

if [ -e "$destino" ]; then
  echo "ya existe: $destino" >&2
  exit 1
fi

mkdir -p "$(dirname "$destino")"
cp -r plantilla "$destino"

./julia.sh --project="$destino" -e 'using Pkg; Pkg.instantiate()'

echo "creada: $destino"
