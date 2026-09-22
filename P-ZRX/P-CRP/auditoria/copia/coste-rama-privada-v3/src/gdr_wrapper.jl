# gdr_wrapper.jl — capa de reutilización de GDR-v0.2 (no se reimplementa GHOSTDAG).
#
# GDR-v0.2 vive en `veritas/consenso/ghostdag-rank-v1/` y se incluye aquí como módulo
# anidado, tal como lo creó su instrumento. Lo que este wrapper añade:
#  - acceso tipado a color **contextual** `(punta/fusionador, bloque) → color`;
#  - `blue_work` real por bloque, recomputado desde los conjuntos azules de GDR;
#  - separación explícita entre el peso propio de una punta y el acumulador C-GD-08.

const _RUTA_GDR = "/home/katana/zeo/ZEROX/veritas/consenso/ghostdag-rank-v1/src/GhostdagRank.jl"

if !isdefined(@__MODULE__, :GhostdagRank)
    include(_RUTA_GDR)
end

"""
Estado DAG sobre GDR. `est` es un `EstadoReferencia` (oráculo claro). Se usa el kernel
lento a propósito: es la referencia de la validez de color, no el optimizado.
"""
mutable struct SimboloDAG
    est::GhostdagRank.EstadoReferencia
    params::GhostdagRank.Params
    ids::Dict{Int,String}
end

function SimboloDAG(; k::Integer=30, s_max::Integer=150, id_genesis::String="G")
    params = GhostdagRank.Params(; k=k, s_max=s_max)
    est = GhostdagRank.EstadoReferencia(params, id_genesis)
    return SimboloDAG(est, params, Dict{Int,String}(1 => id_genesis))
end

"Añade un bloque. Devuelve `true` si GDR lo aceptó estructuralmente."
function agregar!(sim::SimboloDAG, id::String, padres::Vector{Int}, slot::Integer,
                  sd::Integer, sr::Integer, ident::Integer=0)
    ok = GhostdagRank.anadir!(sim.est, sim.params, id, padres, UInt64(slot),
                              UInt64(sd), UInt64(sr), UInt64(ident))
    ok && (sim.ids[sim.est.n] = id)
    return ok
end

"Motivo del último rechazo (`:ok` si el último bloque se aceptó)."
ultimo_motivo(sim::SimboloDAG) = sim.est.motivo[end]

"""
Color **contextual** de `x` en la fusión por `fusionador`. No es propiedad global:
el mismo bloque puede ser azul en una punta y `rojo_k` en otra (C-GD-09).
"""
function color_contextual(sim::SimboloDAG, fusionador::Integer, x::Integer)
    gd = sim.est.gd[fusionador]
    x in gd.blues && return :azul
    t = get(gd.tipos, Int(x), 0x00)
    t == 0x02 && return :rojo_U3
    t == 0x01 && return :rojo_k
    return :fuera
end

"Conjunto azul del bloque/punta `i`, incluyendo su `sp` (C-GD-06)."
blues_de(sim::SimboloDAG, i::Integer) = sim.est.gd[i].blues

"`blue_work` acumulado del bloque/punta `i` (post-fork, sin restar nada)."
blue_work_de(sim::SimboloDAG, i::Integer) = GhostdagRank.bw_de(sim.est, Int(i))

"`blue_work` aportado por el mergeset azul del bloque `i` (excluye el `sp`)."
function blue_work_mergeset(sim::SimboloDAG, i::Integer)
    gd = sim.est.gd[i]
    total = big(0)
    for x in gd.blues
        x == gd.sp && continue
        total += GhostdagRank.peso_big(sim.est.srs[x])
    end
    return total
end

"Peso propio del bloque `i` según su `SR` (no se suma a su propio `blue_work`)."
peso_de(sim::SimboloDAG, i::Integer) = GhostdagRank.peso_big(sim.est.srs[i])

"Puntas del DAG (esquema de bloques sin hijo)."
puntas(sim::SimboloDAG) = GhostdagRank.tips(sim.est)

"Entero exacto (BigInt) del `blue_work`; evita comparar `BW256` en contextos mixtos."
function blue_work_bigint(sim::SimboloDAG, i::Integer)
    return BigInt(blue_work_de(sim, i))
end
