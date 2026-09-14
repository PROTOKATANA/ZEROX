# GDR-v0.1 — validación: helpers de construcción, generador de DAGs aleatorios,
# órdenes de entrega y comparación exacta oráculo/kernel.

"""
Especificación de un bloque para los fixtures: id textual, padres por índice 1-based
(génesis = 1), slot, solution_distance, SR y billete (0 = sin billete).
"""
struct BloqueEspec
    id::String
    padres::Vector{Int}
    slot::UInt64
    sd::UInt64
    sr::UInt64
    ident::UInt64
end

BloqueEspec(id::String; padres::Vector{Int}, slot::Integer=0, sd::Integer=0,
            sr::Integer=0, ident::Integer=0) =
    BloqueEspec(id, padres, UInt64(slot), UInt64(sd), UInt64(sr), UInt64(ident))

"Construye el estado con génesis y añade los bloques en orden; devuelve (est, motivos)."
function construir(est, params::Params, especs::Vector{BloqueEspec})
    motivos = Vector{Symbol}(undef, length(especs))
    for (i, e) in enumerate(especs)
        ok = anadir!(est, params, e.id, e.padres, e.slot, e.sd, e.sr, e.ident)
        motivos[i] = ok ? :ok : est.motivo[end]
    end
    return est, motivos
end

# ---------------------------------------------------------------------------
# Generador de DAGs aleatorios (StableRNGs, semilla explícita).
# - i-ésimo bloque (i ≥ 2): de 1 a 4 padres tomados entre los anteriores, con sesgo
#   hacia los recientes (para crear anticonos); todos válidos estructuralmente.
# - slot no estricto: slot(B) = max(slot(padres)) + δ, δ ∈ {0,1,2}.
# - cada 8 bloques, un grupo de 2 hermanos con los mismos padres y el MISMO billete
#   (copias en anticono mutuo: nunca en ancestría, así que U2 no las invalida;
#   ejercita U3″ dinámica).
# - SR del conjunto {0, 1, 2^64−2, 2^64−1, aleatorio u64}: fronteras de peso.
# ---------------------------------------------------------------------------
function generar_dag(rng, n::Int, idbase::String="B"; ventana::Int=typemax(Int))
    # posición 1 = bloque 1 (génesis, no usado); especs[i] corresponde al bloque i
    especs = [BloqueEspec("G", Int[], UInt64(0), UInt64(0), UInt64(0), UInt64(0))]
    for i in 2:n
        ident = UInt64(0)
        padres_fijados = Int[]
        if i % 8 == 0 && i + 1 <= n
            ident = UInt64(i)            # billete nuevo para el grupo de hermanos
        elseif i % 8 == 1 && especs[end].ident != 0
            # hermano de la copia anterior: misma identidad y mismos padres
            # (anticono mutuo garantizado ⇒ U2 no la invalida; ejercita U3″)
            ident = especs[end].ident
            padres_fijados = especs[end].padres
        end
        if isempty(padres_fijados)
            lo = max(1, i - ventana)
            # acotado también por i - lo (candidatos distintos disponibles en la ventana);
            # para ventana >= 4 esto nunca reduce el mínimo, así que no cambia la secuencia
            # de resultados de v0.1 (mismas llamadas a rand en el mismo orden).
            npadres = min(i - 1, i - lo, 1 + rand(rng, 0:3))
            padres = Int[]
            while length(padres) < npadres
                p = lo + rand(rng, 0:(i - 1 - lo))
                p in padres && continue
                push!(padres, p)
            end
        else
            padres = padres_fijados
        end
        slot = maximum([especs[p].slot for p in padres]) + UInt64(rand(rng, 0:2))
        if !isempty(padres_fijados)
            slot = max(slot, especs[end].slot)
        end
        sr = rand(rng, (UInt64(0), UInt64(1), typemax(UInt64) - 1, typemax(UInt64),
                        UInt64(rand(rng, 0:typemax(Int64)))))
        if isempty(padres_fijados)
            sd = UInt64(rand(rng, 0:(2^20)))
        else
            # hermano: MISMO sd que su pareja ⇒ empate exacto de (bw, sd) entre copias;
            # solo el id del rank rompe el empate (alimenta el test de P1)
            sd = especs[end].sd
        end
        push!(especs, BloqueEspec("$idbase$i", padres, slot, sd, sr, ident))
    end
    return especs
end

"Órdenes de entrega topológicos aleatorios de los bloques 2:n (índices sobre especs)."
function ordenes_topologicos(rng, especs::Vector{BloqueEspec}, cuantas::Int)
    n = length(especs)
    entregados = falses(n)
    ordenes = Vector{Vector{Int}}(undef, cuantas)
    for t in 1:cuantas
        fill!(entregados, false)
        orden = Vector{Int}(undef, n)
        orden[1] = 1
        for pos in 2:n
            disponibles = Int[]
            for i in 2:n
                entregados[i] && continue
                todos_padres = all(p -> p == 1 || entregados[p], especs[i].padres)
                todos_padres && push!(disponibles, i)
            end
            isempty(disponibles) && error("el DAG no es acíclico o faltan entregas")
            elegido = disponibles[rand(rng, 1:length(disponibles))]
            orden[pos] = elegido
            entregados[elegido] = true
        end
        ordenes[t] = orden
    end
    return ordenes
end

"Entrega un DAG (mismos especs) en un orden topológico dado; devuelve el estado."
function entregar(::Type{T}, params::Params, especs::Vector{BloqueEspec},
                  orden::Vector{Int}, id_genesis::String) where {T}
    est = T(params, id_genesis)
    mapa = zeros(Int, length(especs))   # índice de bloque → índice de estado
    mapa[1] = 1
    for i in 2:length(orden)
        e = especs[orden[i]]
        padres_estado = [mapa[p] for p in e.padres]
        ok = anadir!(est, params, e.id, padres_estado, e.slot, e.sd, e.sr, e.ident)
        ok || error("bloque inválido en la entrega determinista: $(e.id) → $(est.motivo[end])")
        mapa[orden[i]] = est.n
    end
    return est
end

# ---------------------------------------------------------------------------
# Accesores tipados de los datos GHOSTDAG (duck typing para cadena/orden).
# ---------------------------------------------------------------------------
sp_de(est::EstadoReferencia, i::Int) = est.gd[i].sp
sp_de(est::EstadoRapido, i::Int) = est.gd[i].sp
ms_blues_de(est::EstadoReferencia, i::Int) = est.gd[i].blues
ms_blues_de(est::EstadoRapido, i::Int) = est.gd[i].ms_blues
ms_reds_de(est::EstadoReferencia, i::Int) = est.gd[i].reds
ms_reds_de(est::EstadoRapido, i::Int) = est.gd[i].ms_reds
es_rojo_u3(est::EstadoReferencia, i::Int, x::Int) = get(est.gd[i].tipos, x, 0x00) == 0x02
es_rojo_u3(est::EstadoRapido, i::Int, x::Int) = get(est.gd[i].tipos, x, 0x00) == 0x02

# ---------------------------------------------------------------------------
# Proyecciones comparables de los datos GHOSTDAG de un estado (oráculo o kernel).
# ---------------------------------------------------------------------------
function proyeccion_gd(est)
    out = Vector{Any}(undef, est.n)
    for i in 1:est.n
        gd = est.gd[i]
        out[i] = (
            sp = gd.sp,
            ms_ordenado = sort(gd.ms_ordenado),
            blues = copy(ms_blues_de(est, i)),
            reds = copy(ms_reds_de(est, i)),
            tipos = sort!(collect(gd.tipos)),
            blue_idents = sort!(collect(gd.blue_idents)),
            blue_score = gd.blue_score,
            bw = BigInt(gd.bw),
        )
    end
    return out
end

proyeccion_orden(est, params::Params, tip::Int) =
    (cadena = cadena_seleccionada(est, tip), orden = orden_aplicacion(est, params, tip))

"Proyección indexada por ID de bloque (para comparar entregas en órdenes distintos)."
function proyeccion_gd_por_id(est)
    d = Dict{String,Any}()
    for i in 1:est.n
        d[id_a_texto(est.ids[i])] = proyeccion_gd(est)[i]
    end
    return d
end

"Proyección abstracta: índices de estado traducidos a IDs de bloque."
function gd_por_id_abstracto(est)
    d = Dict{String,Any}()
    for i in 1:est.n
        gd = est.gd[i]
        d[id_a_texto(est.ids[i])] = (
            sp = gd.sp == 0 ? "∅" : id_a_texto(est.ids[gd.sp]),
            ms_ordenado = sort!([id_a_texto(est.ids[x]) for x in gd.ms_ordenado]),
            blues = [id_a_texto(est.ids[x]) for x in ms_blues_de(est, i)],
            reds = [id_a_texto(est.ids[x]) for x in ms_reds_de(est, i)],
            tipos = sort!([id_a_texto(est.ids[k]) => v for (k, v) in gd.tipos]),
            blue_idents = sort!(collect(gd.blue_idents)),
            blue_score = gd.blue_score,
            bw = BigInt(gd.bw),
        )
    end
    return d
end

proyeccion_orden_por_id(est, params::Params, tip::Int) = (
    tip_id = id_a_texto(est.ids[tip]),
    cadena = [id_a_texto(est.ids[i]) for i in cadena_seleccionada(est, tip)],
    orden = [id_a_texto(est.ids[i]) for i in orden_aplicacion(est, params, tip)])

"""
Compara oráculo (`EstadoReferencia`) contra kernel (`EstadoRapido`). Desde
Corrección 1 (3.2c), el lado del oráculo usa `virtual_sp_ref`/`orden_aplicacion_ref`
(claves propias, sin compartir código con el kernel) en vez de `virtual_sp`/
`proyeccion_orden` genéricos — así una diferencia de DIRECCIÓN entre ambas
implementaciones queda expuesta, en vez de que ambas compartan el mismo posible
error.
"""
function equivalencia(est_ref::EstadoReferencia, est_rap::EstadoRapido, params::Params)
    est_ref.n == est_rap.n || return false
    p_ref = proyeccion_gd(est_ref)
    p_rap = proyeccion_gd(est_rap)
    for i in 1:est_ref.n
        a, b = p_ref[i], p_rap[i]
        (a.sp == b.sp && a.ms_ordenado == b.ms_ordenado && a.blues == b.blues &&
         a.reds == b.reds && a.tipos == b.tipos && a.blue_idents == b.blue_idents &&
         a.blue_score == b.blue_score && a.bw == b.bw) || return false
    end
    tip = virtual_sp_ref(est_ref, params)
    tip_rap = virtual_sp(est_rap, params)
    (tip == tip_rap) || return false
    orden_ref = (cadena=cadena_seleccionada(est_ref, tip),
                 orden=orden_aplicacion_ref(est_ref, params, tip))
    return orden_ref == proyeccion_orden(est_rap, params, tip_rap)
end

"Id textual inverso (solo para ids creados con hash_de_id de cadenas ASCII)."
function id_a_texto(id::ID32)
    i = findfirst(==(0x00), id)
    return String(collect(id[1:(i === nothing ? 32 : i - 1)]))
end
