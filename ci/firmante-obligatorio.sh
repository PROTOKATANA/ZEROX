#!/usr/bin/env bash
# Firmante obligatorio en el nodo (ORDEN-SL4b2 decisión 2; ORDEN-SL4b3 decisión 2).
#
# El nodo produce **solo** con las funciones `_con_firmante` de `zx-post`: la variante
# `_sin_firmante` sella sin registrar la oportunidad y no protege contra la doble firma, así que
# solo la usan tests y arneses. Este guardián falla si `crates/zx-node/src/` menciona la ruta sin
# firmante; así una recaída en `producir_bloque_transicion` (el defecto 1 de `REVISION-SL4b2.md`) se
# detecta en CI.
#
# Sin Python: solo `bash` + `grep`. Si `grep` falla por un motivo distinto de «sin coincidencias»,
# el script falla cerrado en vez de dar un OK falso.
set -euo pipefail
cd "$(dirname "$0")/.."

objetivo="crates/zx-node/src"
if [[ ! -d "$objetivo" ]]; then
    echo "firmante obligatorio: no existe $objetivo" >&2
    exit 1
fi

set +e
coincidencias=$(grep -rn -- "_sin_firmante" "$objetivo")
estado=$?
set -e

case "$estado" in
    0)
        echo "firmante obligatorio: $objetivo invoca un productor sin firmante:" >&2
        echo "$coincidencias" >&2
        echo "Usa las funciones _con_firmante de zx-post (C-EVP-06, FIR-01…FIR-15)." >&2
        exit 1
        ;;
    1)
        echo "OK — $objetivo no invoca ningún productor _sin_firmante"
        ;;
    *)
        echo "firmante obligatorio: grep falló con estado $estado" >&2
        exit 1
        ;;
esac
