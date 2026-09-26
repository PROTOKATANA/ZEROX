module ReferenciaFV1
# Oraculo lento/simple: simulacion Monte Carlo directa del sorteo con prima b,
# para contrastar contra la formula cerrada de modelo.jl (q_atacante,
# frac_honesto_firmable). No es la fuente de verdad (la formula cerrada lo
# es, verificada algebraicamente); es el cruce independiente que exige
# V-ZRX/LINEO.md antes de fiarse de un kernel optimizado (aqui el "kernel"
# es la formula cerrada, mas rapida que remuestrear).

using Random

export simular_sorteo, cobertura_sorteo

"""
    simular_sorteo(rng, a, b, p, K)

Sortea K asientos con reemplazo. Cada asiento cae en:
  - atacante, con peso a*b
  - honesto encendido, con peso (1-a)*p*b
  - honesto apagado, con peso (1-a)*(1-p)*1
Devuelve (fraccion_atacante, fraccion_honesto_firmable).
"""
function simular_sorteo(rng::AbstractRNG, a::Float64, b::Float64, p::Float64, K::Int)
    wa = a*b
    wh_on = (1-a)*p*b
    wh_off = (1-a)*(1-p)*1.0
    tot = wa + wh_on + wh_off
    ua = wa/tot
    uhon = (wa+wh_on)/tot
    n_a = 0
    n_hon = 0
    for _ in 1:K
        u = rand(rng)
        if u < ua
            n_a += 1
        elseif u < uhon
            n_hon += 1
        end
        # resto: honesto apagado, no firma
    end
    return n_a/K, n_hon/K
end

"""
    cobertura_sorteo(a,b,p,K, seeds)

Replica la simulacion con varias semillas (no consecutivas) y devuelve
(media_atacante, min_atacante, max_atacante, media_honesto, n_replicas),
como tabla de cobertura minima exigida por V-ZRX/LINEO.md.
"""
function cobertura_sorteo(a::Float64, b::Float64, p::Float64, K::Int, rngs::Vector{<:AbstractRNG})
    fas = Float64[]
    fhs = Float64[]
    for rng in rngs
        fa, fh = simular_sorteo(rng, a, b, p, K)
        push!(fas, fa)
        push!(fhs, fh)
    end
    return (mean_a=sum(fas)/length(fas), min_a=minimum(fas), max_a=maximum(fas),
            mean_h=sum(fhs)/length(fhs), n=length(rngs))
end

end # module
