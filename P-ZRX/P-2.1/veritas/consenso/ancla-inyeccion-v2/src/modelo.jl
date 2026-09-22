# ANCLA-v0.2 — modelo: parámetros, tipos y utilidades. Sin kernel caliente aquí.

# Parámetros de célula 4.A (todo como argumento, nada global dinámico).
struct Params4A
    α::Float64              # cuota de espacio del atacante
    Δ::Float64              # retardo uniforme por bloque (Δ > 0) o 0.0 = modelo DMS (flood)
    via::Symbol             # :honesta | :v1 | :v2 | :v3 | :a3 | :ctrl9c | :ctrl11c | :criterio
    n_obs::Int              # observadores honestos (12 nominal; 2 para ctrl11c)
    n_red::Int              # nodos de la red DMS (100)
    grado::Int              # grado del grafo DMS (8)
    λ::Float64              # 1 bloque/s
    W0::Int                 # calentamiento (slots)
    H::Int                  # horizonte (slots)
    paso_T::Int             # separación entre umbrales T_j (slots)
    L_def::Int              # ventana de cortes y de restricción del ancla definitiva
    d_calma::Int            # slots de calma para la parada temprana (declarado)
    k::Int                  # 30
    max_parents::Int        # 15
    mergeset_limit::Int     # 180
    s_max::UInt64           # 150
    sr::UInt64              # rango fijo por réplica (sin retarget en 4.A)
    μ_lat::Float64          # lognormal: ln(mediana)
    σ_lat::Float64          # lognormal: sigma
    t_tx::Float64           # tiempo de transmisión por salto (DMS)
    n_T::Int                # nº de umbrales por réplica (9 nominal; 11 en ctrl11c)
end

"Constructor nominal del perfil A″ + red DMS-v0.1."
function Params4A(; α::Float64=0.0, Δ::Float64=4.0, via::Symbol=:honesta,
                  n_obs::Int=12, n_red::Int=100, grado::Int=8, λ::Float64=1.0,
                  W0::Int=300, H::Int=2700, paso_T::Int=200, L_def::Int=600,
                  d_calma::Int=40, k::Int=30, max_parents::Int=15,
                  mergeset_limit::Int=180, s_max::Integer=150,
                  sr::Integer=UInt64(2)^50,
                  μ_lat::Float64=log(0.08), σ_lat::Float64=(log(0.5)-log(0.08))/2.3263,
                  t_tx::Float64=8*812/12.5e6, n_T::Int=9)
    return Params4A(α, Δ, via, n_obs, n_red, grado, λ, W0, H, paso_T, L_def, d_calma,
                    k, max_parents, mergeset_limit, UInt64(s_max), UInt64(sr),
                    μ_lat, σ_lat, t_tx, n_T)
end

"Umbrales T_j medidos en la réplica: W0 : paso_T : W0 + (n-1)*paso_T."
function umbrales(pr::Params4A)
    return collect(pr.W0:pr.paso_T:(pr.W0 + pr.L_def + 8*pr.paso_T - pr.paso_T))
end

n_umbrales(pr::Params4A) = length(umbrales(pr))

# Parámetros GDR (reutilizado sin modificar).
function params_gdr(pr::Params4A)
    return GhostdagRank.Params(k=pr.k, max_parents=pr.max_parents,
                               mergeset_limit=pr.mergeset_limit, s_max=pr.s_max)
end

# --- RNG ---------------------------------------------------------------

"Deriva un RNG estable por (semilla maestra, id) — flujo independiente por réplica."
rng_replica(semilla::Integer, id::Integer) = StableRNGs.StableRNG(UInt64(semilla) ⊻ (UInt64(id) * 0x9E3779B97F4A7C15))

"RNG determinista por bloque para el shuffle de candidatos (no consume el flujo de réplica)."
rng_shuffle(semilla::UInt64, replica::Int, slot::Int, creador::Int) =
    StableRNGs.StableRNG(semilla ⊻ UInt64(replica) ⊻ (UInt64(slot) * 0x9E3779B97F4A7C15) ⊻ (UInt64(creador) * 0xBF58476D1CE4E5B9))

# --- Estadística (Clopper–Pearson exacto) ------------------------------

"IC de Clopper–Pearson bilateral al nivel 1−β con beta_inc regularizada (SpecialFunctions)."
function cp_intervalo(k::Int, n::Int; β::Float64=0.05)
    n == 0 && return (0.0, 1.0)
    lo = k == 0 ? 0.0 : SpecialFunctions.beta_inc_inv(k, n-k+1, β/2)
    hi = k == n ? 1.0 : SpecialFunctions.beta_inc_inv(k+1, n-k, 1-β/2)
    return (lo, hi)
end

"Bootstrap por clúster de réplica: IC 95 % de la media agrupada por (réplica, umbral)."
function bootstrap_cluster(x::Vector{Float64}, rng::StableRNGs.StableRNG; reps::Int=2000)
    R = length(x)
    R == 0 && return (NaN, NaN, NaN)
    m = sum(x) / R
    s = zeros(reps)
    for r in 1:reps
        s[r] = sum(x[rand(rng, 1:R, R)]) / R
    end
    sort!(s)
    lo = s[max(1, floor(Int, 0.025*reps))]
    hi = s[min(reps, ceil(Int, 0.975*reps))]
    return (m, lo, hi)
end
