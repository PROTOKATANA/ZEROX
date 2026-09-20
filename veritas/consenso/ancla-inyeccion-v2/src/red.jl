# ANCLA-v0.2 — red: grafo G(n,p) con latencias lognormales por enlace dirigido
# (modelo DMS-v0.1: mediana 80 ms, p99 500 ms, una muestra fija por corrida) y
# muestreo lognormal por Box–Muller. Portado del modelo de DMS-v0.1; sin
# dependencias externas (sin Distributions).

struct Grafo
    n::Int
    offsets::Vector{Int32}
    vecinos::Vector{Int32}
    lat::Vector{Float64}
end

function red_erdos_renyi(rng, n::Int, grado::Int, mu_lat::Float64, sigma_lat::Float64;
                         max_intentos::Int=200)
    p = grado / (n - 1)
    for _ in 1:max_intentos
        lista = [Int[] for _ in 1:n]
        for u in 1:n, v in (u+1):n
            rand(rng) < p && (push!(lista[u], v); push!(lista[v], u))
        end
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
