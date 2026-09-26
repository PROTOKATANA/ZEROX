#!/usr/bin/env bash
# Fronteras de dependencias de los crates de consenso (adaptado de `9681061`; W04 + W05a).
#
# Regla: `zx-consensus` y `zx-dag` pueden ver `zx-core` y **solo** `zx-core` dentro del workspace:
# una primitiva de cálculo, no red, estado ni mempool. En particular, `zx-dag` (D-P13) **no** puede
# depender de `zx-consensus` ni de `zx-storage`. No se porta la regla de `zx-p2p`/`zx-mempool`
# porque esos crates todavía no existen en el workspace nuevo; se reintroducirán con sus órdenes.
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
    def frontera($crate; $permitidos):
        [.packages[] | select(.name == $crate)] as $p |
        if ($p | length) != 1 then
            error($crate + " no aparece en cargo metadata")
        else
            [$p[0].dependencies[]
             | select(.kind != "dev")
             | select(.name | startswith("zx-"))
             | .name as $d
             | select($permitidos | index($d) | not)
             | ($crate + " depende de " + $d)] as $fallos |
            if ($fallos | length) > 0 then
                error($fallos | join("; "))
            else
                "OK — frontera " + $crate + " → {" + ($permitidos | join(",")) + "}"
            end
        end;

    frontera("zx-consensus"; ["zx-core"]),
    frontera("zx-dag"; ["zx-core"])'
