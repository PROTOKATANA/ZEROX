# PRV-v0.1 — kernel: conteo rápido de operaciones leyendo el estado del oráculo GDR-v0.2,
# y construcción de las dos historias válidas de la demostración de selección.
using StableRNGs

"""
Conteo rápido: lee los campos ya calculados por el oráculo GDR-v0.2. NO reimplementa
GHOSTDAG; cuenta lo que un circuito tendría que probar.
"""
function contar_rapido(est)
    n = est.n
    ms = zeros(Int, n); ctx = zeros(Int, n); tam = zeros(Int, n); ident = zeros(Int, n)
    padres = zeros(Int, n); blues = zeros(Int, n); orden = zeros(Int, n)
    for i in 1:n
        gd = est.gd[i]
        ms[i] = length(gd.ms_ordenado)
        sp = gd.sp
        ctx[i] = sp == 0 ? 0 : length(est.gd[sp].blueset)
        tam[i] = sum(values(gd.tam); init=0)
        idc = !iszero(est.idents[i]) ? 1 : 0
        for x in gd.ms_ordenado
            !iszero(est.idents[x]) && (idc += 1)
        end
        ident[i] = idc
        padres[i] = length(est.padres[i])
        blues[i] = length(gd.blues)
        m = ms[i]
        orden[i] = m <= 1 ? 0 : ceil(Int, m * log2(Float64(m)))
    end
    return ConteoOperaciones(n, ms, ctx, tam, ident, padres, blues, orden)
end

# ---------------------------------------------------------------------------
# Construcción de DAGs válidos con el oráculo. `GDR` es el módulo cargado.
# ---------------------------------------------------------------------------

function construir_especs(GDR, padres::Vector{Vector{Int}}, slots::Vector{UInt64},
                          sds::Vector{UInt64}, srs::Vector{UInt64},
                          idents::Vector{UInt64}, ids::Vector{String})
    E = GDR.BloqueEspec
    especs = E[E(ids[1]; padres=Int[], slot=slots[1], sd=sds[1], sr=srs[1],
                 ident=idents[1])]
    for i in 2:length(padres)
        push!(especs, E(ids[i]; padres=padres[i], slot=slots[i], sd=sds[i], sr=srs[i],
                        ident=idents[i]))
    end
    return especs
end

"Construye el estado GDR validando cada bloque; lanza si alguno es inválido."
function construir_estado(GDR, especs)
    params = GDR.P_DEFECTO
    est = GDR.EstadoReferencia(params, "G")
    for i in 2:length(especs)
        e = especs[i]
        ok = GDR.anadir!(est, params, e.id, e.padres, e.slot, e.sd, e.sr, e.ident)
        ok || error("bloque inválido $(e.id) → $(est.motivo[end])")
    end
    return est
end

"Historia (DAG + punta canónica + blue_work) a partir de un estado GDR."
function historia_desde_estado(GDR, nombre::String, est)
    v = GDR.virtual_sp(est, GDR.P_DEFECTO)
    return Historia(nombre, est.n, deepcopy(est.padres), v, est.gd[v].bw)
end

"Puntas del estado con su `blue_work` y su `blue_score` (para mostrar que la canónica es global)."
function puntas_con_peso(est)
    con_hijo = falses(est.n)
    for i in 1:est.n, p in est.padres[i]
        con_hijo[p] = true
    end
    out = NamedTuple[]
    for i in 1:est.n
        con_hijo[i] && continue
        push!(out, (tip=i, blue_work=est.gd[i].bw, blue_score=est.gd[i].blue_score))
    end
    return sort(out; by=x -> (-x.blue_work, x.tip))
end

# ---------------------------------------------------------------------------
# SELECCIÓN: dos historias válidas con la misma prueba de validez aceptada y distinta
# punta canónica. El adversario retiene la segunda.
# ---------------------------------------------------------------------------

"""
`H1` = DAG válido de `n` bloques. `H2` = `H1` más un bloque válido `Y` que fusiona las
puntas de `H1`. Ambas son válidas; sus puntas canónicas difieren. Una prueba de validez
de cada una verifica correctamente, lo que demuestra que «probar la transición» no decide
«cuál es la canónica».
"""
function dos_historias(GDR, n::Int, seed::UInt64)
    rng = StableRNG(seed)
    especs1 = GDR.generar_dag(rng, n, "A"; ventana=6)
    est1 = construir_estado(GDR, especs1)
    h1 = historia_desde_estado(GDR, "H1", est1)

    # Y fusiona todas las puntas de H1. padres de Y = puntas (índices de estado = de especs).
    con_hijo = falses(est1.n)
    for i in 1:est1.n, p in est1.padres[i]
        con_hijo[p] = true
    end
    puntas = [i for i in 1:est1.n if !con_hijo[i]]
    slot_y = maximum(especs1[p].slot for p in puntas) + UInt64(1)
    especs2 = copy(especs1)
    push!(especs2, GDR.BloqueEspec("Y"; padres=puntas, slot=slot_y,
                                   sd=UInt64(1), sr=typemax(UInt64) >> 1, ident=UInt64(0)))
    est2 = construir_estado(GDR, especs2)
    h2 = historia_desde_estado(GDR, "H2", est2)

    return (h1=h1, h2=h2, puntas1=puntas_con_peso(est1), puntas2=puntas_con_peso(est2))
end

"""
Verificador de una prueba de validez. Sólo puede mirar la historia probada: comprueba
que es internamente consistente y que su punta declarada es la canónica de ESA historia.
No tiene, ni puede tener, información sobre otras historias.
"""
function verifica_prueba_validez(p::PruebaValidez)
    h = p.historia
    h.n >= 1 || return false
    1 <= h.canonica <= h.n || return false
    for i in 1:h.n, par in h.padres[i]
        1 <= par < i || return false
    end
    h.blue_work > 0 || return false
    return true
end
