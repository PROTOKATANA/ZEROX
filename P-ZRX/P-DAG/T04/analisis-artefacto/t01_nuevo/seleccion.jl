# Selección transversal (FC-3, FC-1, FC-2) y Corte.
#
# `seleccionar` es pura: valida contextualmente todo el conjunto (un bloque es
# válido solo si su padre lo es y su aplicación sobre el estado del padre no
# da error), descarta inválidos y descendientes y aplica la interfaz elegida.
# Los huérfanos (padre ausente) no son válidos (AMBIGUEDAD-13).

struct ResultadoSeleccion
    punta::Int
    estado::Estado
    validos::Dict{Int,Estado}
end

function construir_validos(bloques::Vector{Bloque}, P::Params)
    memo = Dict{Int,Estado}()
    por_id = Dict{Int,Bloque}()
    for b in bloques
        por_id[b.id] = b
    end
    gen = nothing
    for b in bloques
        if b.familia == Genesis
            gen = b
            break
        end
    end
    gen === nothing && return memo, por_id
    E0 = estado_inicial(P)
    r = aplicar(E0, gen, P)
    r isa Err && return memo, por_id
    memo[gen.id] = r
    cola = Int[gen.id]
    while !isempty(cola)
        pid = popfirst!(cola)
        Ep = memo[pid]
        for b in bloques
            b.padre == pid || continue
            haskey(memo, b.id) && continue
            r2 = aplicar(Ep, b, P)
            if !(r2 isa Err)
                memo[b.id] = r2
                push!(cola, b.id)
            end
        end
    end
    return memo, por_id
end

function puntas_validas(memo::Dict{Int,Estado}, por_id::Dict{Int,Bloque})
    padres = Set{Int}()
    for id in keys(memo)
        b = por_id[id]
        b.padre != 0 && push!(padres, b.padre)
    end
    return [id for id in keys(memo) if !(id in padres)]
end

function seleccionar_fc3(bloques::Vector{Bloque}, P::Params)
    memo, por_id = construir_validos(bloques, P)
    isempty(memo) && return ResultadoSeleccion(-1, estado_inicial(P), memo)
    tips = puntas_validas(memo, por_id)
    hay_post = false
    for id in keys(memo)
        if por_id[id].familia == PoST
            hay_post = true
            break
        end
    end
    mejor = -1
    mejor_clave = nothing
    for id in tips
        E = memo[id]
        clave = hay_post ? (E.peso_sufijo, -E.terminal, -id) :
                           (E.trabajo_acum, -id)
        if mejor_clave === nothing || clave > mejor_clave
            mejor_clave = clave
            mejor = id
        end
    end
    return ResultadoSeleccion(mejor, memo[mejor], memo)
end

function seleccionar_fc1(bloques::Vector{Bloque}, P::Params)
    memo, por_id = construir_validos(bloques, P)
    isempty(memo) && return ResultadoSeleccion(-1, estado_inicial(P), memo)
    tips = puntas_validas(memo, por_id)
    mejor = -1
    mejor_clave = nothing
    for id in tips
        E = memo[id]
        clave = (E.trabajo_acum, E.peso_sufijo, -E.terminal, -id)
        if mejor_clave === nothing || clave > mejor_clave
            mejor_clave = clave
            mejor = id
        end
    end
    return ResultadoSeleccion(mejor, memo[mejor], memo)
end

function seleccionar(bloques::Vector{Bloque}, P::Params)
    if P.seleccion == FC2
        return seleccionar_fc3(bloques, conWmin(P, 0))
    elseif P.seleccion == FC1
        return seleccionar_fc1(bloques, P)
    end
    return seleccionar_fc3(bloques, P)
end

# Utilidad para comparar las tres interfaces sobre el mismo conjunto (datos de
# X-17/X-18, sin juicio).
function seleccionar_con(P::Params, modo::SeleccionModo, bloques::Vector{Bloque})
    return seleccionar(bloques, conseleccion(P, modo))
end
