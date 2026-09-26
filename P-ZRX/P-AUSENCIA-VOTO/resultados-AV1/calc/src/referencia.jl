"""
Oráculo de referencia para el modelo AV-1: enumeración exacta para K pequeño
y Monte Carlo independiente (StableRNGs, semillas fijas no consecutivas) para
K realista. Sirve de comprobación cruzada de `src/modelo.jl`, nunca de fuente
de verdad publicada (esa es la fórmula cerrada, verificada aquí).
"""
module Referencia

using StableRNGs
include("modelo.jl")
using .Modelo

export enumerar_binomial_exacto, mc_incidentes_por_instancia, mc_prob_al_menos_una_plaza

"""
Enumeración exacta de la distribución Binomial(K, s) por recursión de Pascal
(sin `loggamma`, para contrastar `prob_elegido_binom`). Solo para K ≤ 30
(cómputo ligero, oráculo de bordes).
"""
function enumerar_binomial_exacto(s::Float64, K::Int)
    @assert K <= 30 "oráculo de enumeración exacta solo para K pequeño"
    # Triángulo de Pascal en BigInt para exactitud combinatoria.
    C = zeros(BigInt, K + 1)
    C[1] = BigInt(1)
    for n in 1:K
        for k in min(n, K):-1:1
            C[k+1] += C[k]
        end
    end
    probs = Vector{Float64}(undef, K + 1)
    for j in 0:K
        probs[j+1] = Float64(C[j+1]) * s^j * (1 - s)^(K - j)
    end
    return probs
end

"""
Monte Carlo de `prob_al_menos_una_plaza(s,K)`: `reps` réplicas de K ensayos
Bernoulli(s) independientes, cuenta la fracción de réplicas con ≥1 éxito.
"""
function mc_prob_al_menos_una_plaza(s::Float64, K::Int, reps::Int, semilla::UInt64)
    rng = StableRNG(semilla)
    exitos = 0
    for _ in 1:reps
        gano = false
        for _ in 1:K
            if rand(rng) < s
                gano = true
                break
            end
        end
        exitos += gano ? 1 : 0
    end
    return exitos / reps
end

"""
Monte Carlo de `incidentes_por_instancia(a_eff, K, m_split)`: simula
`m_split` claves de peso igual `a_eff/m_split`, K plazas con reemplazo
repartidas entre TODAS las claves (incluida la masa honesta 1−a_eff),
cuenta cuántas de las `m_split` claves del atacante ganan ≥1 plaza.
"""
function mc_incidentes_por_instancia(a_eff::Float64, K::Int, m_split::Int, reps::Int, semilla::UInt64)
    rng = StableRNG(semilla)
    s = a_eff / m_split
    total = 0.0
    for _ in 1:reps
        ganos = zeros(Bool, m_split)
        for _ in 1:K
            u = rand(rng)
            # Asignar la plaza: primero decidir si cae en el atacante (masa a_eff)
            if u < a_eff
                # dentro del bloque atacante, uniforme entre sus m_split claves
                idx = clamp(Int(floor((u / a_eff) * m_split)) + 1, 1, m_split)
                ganos[idx] = true
            end
            # si no, cae en la masa honesta: no cuenta como incidente del atacante
        end
        total += count(ganos)
    end
    return total / reps
end

end # module
