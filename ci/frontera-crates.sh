#!/usr/bin/env bash
# Cargo interpreta TOML: incluye aliases y dependencias condicionales, excluye las de desarrollo.
# jq está disponible en la máquina del proyecto y en los runners ubuntu de CI.
set -euo pipefail
cd "$(dirname "$0")/.."

cargo metadata --locked --no-deps --format-version 1 | jq -e '
    {"zx-p2p": ["zx-core"],
     "zx-consensus": ["zx-core"],
     "zx-mempool": ["zx-core", "zx-consensus"]} as $reglas |
    [.packages[] | select(.name as $n | $reglas | has($n))] as $paquetes |
    if ($paquetes | length) != ($reglas | length) then
        error("Falta un crate vigilado en cargo metadata")
    else
        [$paquetes[] | .name as $crate |
         .dependencies[] | select(.kind != "dev") |
         select(.name | startswith("zx-")) |
         .name as $dependencia |
         select(($reglas[$crate] | index($dependencia)) == null) |
         "\($crate) depende de \($dependencia)"] as $fallos |
        if ($fallos | length) > 0 then error($fallos | join("; "))
        else "OK — frontera de red, consenso y mempool" end
    end'
