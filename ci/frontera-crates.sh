#!/usr/bin/env bash
# Frontera de dependencias del crate de consenso (adaptado de `9681061` a la orden W04).
#
# Regla: `zx-consensus` puede ver `zx-core` y **solo** `zx-core` dentro del workspace: una primitiva
# de cálculo, no red, estado ni mempool. No se porta la regla de `zx-p2p`/`zx-mempool` porque esos
# crates todavía no existen en el workspace nuevo; se reintroducirán con sus órdenes.
#
# Se usa `jq` (disponible en la máquina del proyecto y en los runners ubuntu de CI). Si no estuviera,
# el script falla con un mensaje explícito en vez de dar un OK falso.
set -euo pipefail
cd "$(dirname "$0")/.."

if ! command -v jq >/dev/null 2>&1; then
    echo "jq no está instalado: no se puede comprobar la frontera de crates" >&2
    exit 1
fi

cargo metadata --locked --no-deps --format-version 1 | jq -e '
    [.packages[] | select(.name == "zx-consensus")] as $p |
    if ($p | length) != 1 then
        error("zx-consensus no aparece en cargo metadata")
    else
        [$p[0].dependencies[]
         | select(.kind != "dev")
         | select(.name | startswith("zx-"))
         | .name as $d
         | select($d != "zx-core")
         | "zx-consensus depende de \($d)"] as $fallos |
        if ($fallos | length) > 0 then
            error($fallos | join("; "))
        else
            "OK — frontera zx-consensus → {zx-core}"
        end
    end'
