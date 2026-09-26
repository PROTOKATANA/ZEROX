# Nodo en línea con huérfanos y C-FIN-01 (TRN-09).

slot_de(b::Bloque) = b.familia == PoST ? b.slot : 0

function cadena_hasta(id::Int, por_id::Dict{Int,Bloque})
    cadena = Int[]
    while id != 0
        push!(cadena, id)
        b = get(por_id, id, nothing)
        b === nothing && break
        id = b.padre
    end
    reverse!(cadena)
    return cadena
end

function ancestro_comun(a::Int, b::Int, por_id::Dict{Int,Bloque})
    ca = cadena_hasta(a, por_id)
    cb = cadena_hasta(b, por_id)
    i = 1
    while i <= min(length(ca), length(cb)) && ca[i] == cb[i]
        i += 1
    end
    return i == 1 ? 0 : ca[i-1]
end

# Procesa `secuencia` en orden arbitrario; los huérfanos esperan a su padre
# porque la selección se recalcula sobre el conjunto recibido. Devuelve
# (punta, estado) manteniendo la punta si `d ≥ F_slots` (C-FIN-01).
function nodo_en_linea(secuencia::Vector{Bloque}, P::Params)
    buf = Bloque[]
    tip = -1
    estado_tip = estado_inicial(P)
    for b in secuencia
        push!(buf, b)
        res = seleccionar(buf, P)
        res.punta == -1 && continue
        if tip == -1
            tip = res.punta
            estado_tip = res.estado
        else
            por_id = Dict{Int,Bloque}()
            for x in buf
                por_id[x.id] = x
            end
            ca = ancestro_comun(tip, res.punta, por_id)
            d = slot_de(por_id[tip]) - (ca == 0 ? 0 : slot_de(por_id[ca]))
            if d < P.F_slots
                tip = res.punta
                estado_tip = res.estado
            end
        end
    end
    return tip, estado_tip
end
