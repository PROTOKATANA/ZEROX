# ANCLA-v0.1 — red honesta, producción de bloques y propagación.
#
# Modelo de red tomado de veritas/finalidad/delta-medido-v1/ (DMS-v0.1):
#   G(n, p) con p = grado/(n-1) re-muestreado hasta conexión; latencia por enlace
#   lognormal (mediana 80 ms, p99 500 ms), una muestra fija por corrida; inundación
#   hop-by-hop; cola de transmisión serial por nodo; Poisson λ = 1 bloque/s; creador
#   uniforme. Producción y propagación comparten el mismo reloj de eventos.
#
# Lo que este archivo AÑADE a DMS-v0.1 es la construcción del DAG: cada creador elige
# hasta `max_padres` puntas de su propia vista como padres del bloque nuevo. GHOSTDAG
# (sp, mergeset, color, cadena) NO se calcula aquí: lo calcula GDR-v0.2 sobre cada
# vista. Este archivo no reimplementa ninguna regla de consenso.

# --- cola de prioridad mínima sobre eventos isbits -------------------------

struct Evento
    t::Float64
    b::Int32
    desde::Int32
    hasta::Int32
end

function heap_push!(H::Vector{Evento}, e::Evento)
    push!(H, e)
    i = length(H)
    @inbounds while i > 1
        p = i >> 1
        H[p].t <= H[i].t && break
        H[p], H[i] = H[i], H[p]
        i = p
    end
    return H
end

function heap_pop!(H::Vector{Evento})
    n = length(H)
    @assert n >= 1
    top = H[1]
    ult = H[n]
    pop!(H)
    n -= 1
    if n > 0
        H[1] = ult
        i = 1
        @inbounds while true
            l = 2i
            r = l + 1
            m = i
            if l <= n && H[l].t < H[m].t
                m = l
            end
            if r <= n && H[r].t < H[m].t
                m = r
            end
            m == i && break
            H[m], H[i] = H[i], H[m]
            i = m
        end
    end
    return top
end

# --- grafo y latencias ------------------------------------------------------

struct Grafo
    n::Int
    offsets::Vector{Int32}
    vecinos::Vector{Int32}
    lat::Vector{Float64}    # paralelo a vecinos: latencia del enlace u→vecinos[k]
end

"""
G(n, p) con p = grado/(n-1), re-muestreado hasta conexión (mismo modelo que DMS-v0.1).
Devuelve CSR con latencias lognormales por enlace dirigido.
"""
function red_erdos_renyi(rng, n::Int, grado::Int, mu_lat::Float64, sigma_lat::Float64;
                         max_intentos::Int = 200)
    p = grado / (n - 1)
    for _ in 1:max_intentos
        lista = [Int[] for _ in 1:n]
        for u in 1:n, v in (u + 1):n
            if rand(rng) < p
                push!(lista[u], v)
                push!(lista[v], u)
            end
        end
        # conexidad (BFS)
        visto = falses(n)
        cola = [1]
        visto[1] = true
        c = 1
        while !isempty(cola)
            u = pop!(cola)
            for v in lista[u]
                if !visto[v]
                    visto[v] = true
                    c += 1
                    push!(cola, v)
                end
            end
        end
        c == n || continue
        offsets = Vector{Int32}(undef, n + 1)
        vecinos = Int32[]
        lat = Float64[]
        offsets[1] = 1
        for u in 1:n
            for v in lista[u]
                push!(vecinos, Int32(v))
                push!(lat, exp(mu_lat + sigma_lat * randn(rng)))
            end
            offsets[u + 1] = Int32(length(vecinos) + 1)
        end
        return Grafo(n, offsets, vecinos, lat)
    end
    error("red_erdos_renyi: sin grafo conexo tras $max_intentos intentos (n=$n)")
end

# --- parámetros y DAG global ------------------------------------------------

struct ParametrosRed
    n::Int
    grado::Int
    lambda::Float64
    T::Float64
    t_tx::Float64
    mu_lat::Float64
    sigma_lat::Float64
    max_padres::Int
    sr_const::UInt64
    seed::UInt64
end

"""
DAG global de la corrida. `llega[b, u]` es el instante en que el nodo `u` recibió el
bloque `b` (Inf si nunca dentro de la ventana simulada). `padres` son índices globales
1-based; el bloque 1 es el génesis.
"""
struct DAGGlobal
    n::Int
    nblo::Int
    ids::Vector{String}
    padres::Vector{Vector{Int}}
    creador::Vector{Int32}
    t_crea::Vector{Float64}
    slot::Vector{UInt64}
    sd::Vector{UInt64}
    sr::Vector{UInt64}
    llega::Matrix{Float64}
    grafo::Grafo
end

"""
Simula `T` segundos de una red honesta. Cada bloque nuevo elige hasta `max_padres`
puntas de la vista de su creador. Devuelve el DAG global y las llegadas por nodo.
"""
function simular_red(pr::ParametrosRed)
    rng = StableRNG(pr.seed)
    g = red_erdos_renyi(rng, pr.n, pr.grado, pr.mu_lat, pr.sigma_lat)

    # tiempos de creación (Poisson) y creador uniforme
    ctimes = Float64[]
    ccreate = Int32[]
    t = randexp(rng) / pr.lambda
    while t <= pr.T
        push!(ctimes, t)
        push!(ccreate, Int32(rand(rng, 1:pr.n)))
        t += randexp(rng) / pr.lambda
    end

    maxB = length(ctimes) + 2          # génesis + bloques creados
    llega = fill(Inf, maxB, pr.n)
    ids = sizehint!(String[], maxB)
    padres = sizehint!(Vector{Int}[], maxB)
    creador = sizehint!(Int32[], maxB)
    t_crea = sizehint!(Float64[], maxB)
    slot = sizehint!(UInt64[], maxB)
    sd = sizehint!(UInt64[], maxB)
    sr = sizehint!(UInt64[], maxB)

    # estado de puntas por nodo (para elegir padres)
    es_tip = falses(maxB, pr.n)
    pos_tip = zeros(Int32, maxB, pr.n)
    tips_lista = [Int[] for _ in 1:pr.n]

    next_free = zeros(Float64, pr.n)
    H = Evento[]

    # --- génesis ---------------------------------------------------------
    push!(ids, "000000000001")
    push!(padres, Int[])
    push!(creador, Int32(1))
    push!(t_crea, 0.0)
    push!(slot, UInt64(0))
    push!(sd, UInt64(0))
    push!(sr, pr.sr_const)
    marcar_llegada!(llega, es_tip, pos_tip, tips_lista, 1, 1, 0.0, padres)
    difundir!(H, 1, 1, 0.0, g, llega, next_free, pr)

    ci = 1
    while ci <= length(ctimes) || !isempty(H)
        if ci <= length(ctimes) && (isempty(H) || ctimes[ci] <= H[1].t)
            tc = ctimes[ci]
            u = Int(ccreate[ci])
            ci += 1
            b = length(ids) + 1
            ps = elegir_padres(tips_lista[u], slot, ids, pr.max_padres)
            isempty(ps) && (ps = [1])
            push!(ids, lpad(string(b), 12, '0'))
            push!(padres, ps)
            push!(creador, Int32(u))
            push!(t_crea, tc)
            push!(slot, UInt64(floor(tc)))
            push!(sd, UInt64(rand(rng, typemin(UInt64):typemax(UInt64))))
            push!(sr, pr.sr_const)
            marcar_llegada!(llega, es_tip, pos_tip, tips_lista, b, u, tc, padres)
            difundir!(H, b, u, tc, g, llega, next_free, pr)
        else
            e = heap_pop!(H)
            b = Int(e.b)
            v = Int(e.hasta)
            llega[b, v] <= e.t && continue
            marcar_llegada!(llega, es_tip, pos_tip, tips_lista, b, v, e.t, padres)
            difundir!(H, b, v, e.t, g, llega, next_free, pr)
        end
    end

    nblo = length(ids)
    return DAGGlobal(pr.n, nblo, ids, padres, creador, t_crea, slot, sd, sr,
                     llega[1:nblo, :], g)
end

function marcar_llegada!(llega, es_tip, pos_tip, tips_lista, b::Int, u::Int, t::Float64,
                         padres)
    llega[b, u] = t
    for p in padres[b]
        if es_tip[p, u]
            es_tip[p, u] = false
            lst = tips_lista[u]
            i = Int(pos_tip[p, u])
            ultimo = lst[end]
            lst[i] = ultimo
            pos_tip[ultimo, u] = Int32(i)
            pop!(lst)
            pos_tip[p, u] = Int32(0)
        end
    end
    es_tip[b, u] = true
    pos_tip[b, u] = Int32(length(tips_lista[u]) + 1)
    push!(tips_lista[u], b)
    return nothing
end

"Envía `b` desde `u` a sus vecinos con cola serial (modelo DMS-v0.1)."
function difundir!(H, b::Int, u::Int, t::Float64, g::Grafo, llega, next_free, pr::ParametrosRed)
    nf = max(t, next_free[u])
    @inbounds for k in Int(g.offsets[u]):(Int(g.offsets[u + 1]) - 1)
        v = Int(g.vecinos[k])
        llega[b, v] <= t && continue
        nf += pr.t_tx
        heap_push!(H, Evento(nf + g.lat[k], Int32(b), Int32(u), Int32(v)))
    end
    next_free[u] = nf
    return nothing
end

"Elige hasta `max_padres` puntas: por slot descendente; empate, id descendente."
function elegir_padres(pl::Vector{Int}, slot::Vector{UInt64}, ids::Vector{String},
                       max_padres::Int)
    length(pl) <= max_padres && return copy(pl)
    idx = sortperm(pl; lt = (a, b) -> begin
        sa, sb = slot[a], slot[b]
        sa != sb && return sa > sb
        return ids[a] > ids[b]
    end)
    return pl[idx[1:max_padres]]
end
