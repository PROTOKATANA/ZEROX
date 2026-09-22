# PPP-v0.1 — kernel: Monte Carlo del proceso de solución con réplicas independientes.
# Restricciones LINEO: funciones tipoestables, sin asignaciones en el bucle, RNG por
# réplica derivado de (semilla, id), reducción determinista en orden de id.

using StableRNGs
using Base.Threads

"""
Un sorteo de bloque: mínimo de `C` distancias uniformes en {0,…,2^63−1}. El bloque usa el
chunk ganador de menor distancia (`map_winning_chunks`, auditing.rs:236-270).
"""
@inline function distancia_min(rng::StableRNG, C::Int)
    d = typemax(UInt64)
    @inbounds for _ in 1:C
        v = rand(rng, UInt64) >> 1
        v < d && (d = v)
    end
    return d
end

"""
Cuenta bloques por nivel simulando `n_slots` sorteos de un sector. Devuelve
`(conteo[1..Lmax], validos)`. Sin asignaciones dentro del bucle.
"""
function contar_niveles!(conteo::Vector{Int}, rng::StableRNG, C::Int, SR::UInt64,
                         n_slots::Int, Lmax::Int)
    validos = 0
    T1 = SR >> 1
    @inbounds for _ in 1:n_slots
        d = distancia_min(rng, C)
        d <= T1 || continue
        validos += 1
        L = 1
        while L < Lmax && L < 64 && d <= (SR >> (L + 1))
            L += 1
        end
        conteo[L] += 1
    end
    return validos
end

struct ResultadoMC
    C::Int
    SR::UInt64
    Lmax::Int
    replicas::Int
    slots_por_replica::Int
    semilla::UInt64
    conteo::Vector{Int}   # suma sobre réplicas, por nivel
    validos::Int
end

"""
Monte Carlo con réplicas independientes, una tarea por réplica, salida por réplica y
reducción final ordenada. `openblas` no interviene; los hilos Julia son la capa dueña.
"""
function monte_carlo_niveles(semilla::UInt64, C::Int, SR::UInt64, slots_por_replica::Int,
                             replicas::Int; Lmax::Int=48)
    conteo_por = [zeros(Int, Lmax) for _ in 1:replicas]
    validos_por = zeros(Int, replicas)
    @threads for r in 1:replicas
        rng = StableRNG(semilla + UInt64(r))
        validos_por[r] = contar_niveles!(conteo_por[r], rng, C, SR, slots_por_replica, Lmax)
    end
    conteo = zeros(Int, Lmax)
    for r in 1:replicas
        @inbounds for L in 1:Lmax
            conteo[L] += conteo_por[r][L]
        end
    end
    return ResultadoMC(C, SR, Lmax, replicas, slots_por_replica, semilla,
                       conteo, sum(validos_por))
end

"""
Probabilidad Monte Carlo de `nivel ≥ L` condicionada a válida. Es la magnitud que
describe `solution_distance ≤ SR/2^L` y la comparable con `p_nivel_exacta`.
"""
function p_mc(res::ResultadoMC, L::Integer)
    res.validos == 0 && return NaN
    (1 <= L <= res.Lmax) || return NaN
    return sum(@view res.conteo[L:end]) / res.validos
end

"""
Comprueba que el Monte Carlo es compatible con la probabilidad exacta dentro de ~4
desviaciones típicas de una proporción binomial. Los niveles más raros que la resolución
de la corrida devuelven `missing` (no se declaran falsos ni verdaderos).
"""
function equivalencia_niveles(res::ResultadoMC; Lmax::Union{Nothing,Int}=nothing)
    Ltop = something(Lmax, res.Lmax)
    filas = NamedTuple[]
    for L in 1:Ltop
        pe = Float64(p_nivel_exacta(L, res.SR, res.C))
        pm = p_mc(res, L)
        if isnan(pm) || pe * res.validos < 25
            push!(filas, (L=L, exacta=pe, mc=pm, sigma=NaN, cubre=missing))
            continue
        end
        sigma = sqrt(pe * (1 - pe) / res.validos)
        ok = abs(pm - pe) <= 4 * sigma + 1e-12
        push!(filas, (L=L, exacta=pe, mc=pm, sigma=sigma, cubre=ok))
    end
    return filas
end

"""¿Cae `obs` dentro de `media ± k·sigma`? (sin `missing`)."""
cubre_intervalo(obs::Real, media::Real, sigma::Real; k::Real=4) = abs(obs - media) <= k * sigma
