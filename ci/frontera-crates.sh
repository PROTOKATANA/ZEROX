#!/usr/bin/env bash
# Cargo interpreta TOML: incluye aliases y dependencias condicionales, excluye las de desarrollo.
# jq está disponible en la máquina del proyecto y en los runners ubuntu de CI.
#
# `zx-consensus` puede ver `zx-core` y `zx-pot`. `zx-pot` es una primitiva pura (PoT AES, encargo
# 03a): no depende de nada del workspace, así que no reintroduce ninguna frontera que este guardián
# proteja. Lo que sigue prohibido es que consenso vea red, estado o mempool.
set -euo pipefail
cd "$(dirname "$0")/.."

cargo metadata --locked --no-deps --format-version 1 | jq -e '
    {"zx-p2p": ["zx-core"],
     "zx-consensus": ["zx-core", "zx-pot"],
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
