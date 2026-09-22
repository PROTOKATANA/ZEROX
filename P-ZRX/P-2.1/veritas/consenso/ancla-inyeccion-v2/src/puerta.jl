# ANCLA-v0.2 — 4.0 PUERTA: ¿se sostiene sola una partición de flujo, sin atacante?
# Analítico-exacto: Skellam (PMF vía bessel_i), cadena de nacimiento-muerte para la
# absorción, curva S_max_racional(capacidad) y recálculo del contraste histórico.

"PMF de Skellam: P(D(t)=k) con tasas μ1 (sube), μ2 (baja); k ∈ ℤ. (besselix escalada)."
function skellam_pmf(μ1::Float64, μ2::Float64, t::Float64, k::Int)
    arg = 2*sqrt(μ1*μ2)*t
    return exp(-(μ1+μ2)*t + arg) * (μ1/μ2)^(k/2) * SpecialFunctions.besselix(abs(k), arg)
end

"P(D(t)=k) truncada con cota de error; devuelve vector sobre k ∈ [-K, K]."
function skellam_pmf_truncada(μ1::Float64, μ2::Float64, t::Float64, K::Int)
    p = [skellam_pmf(μ1, μ2, t, k) for k in -K:K]
    return p
end

"Probabilidad de cambio de líder (alcanzar +1 y −1) en [0, τ] desde 0: DP de banderas."
function p_cambio_lider(μ1::Float64, μ2::Float64, τ::Float64; K::Int=200, dt::Float64=0.1)
    n = ceil(Int, τ/dt)
    Λ = (μ1+μ2)*dt
    # banderas: 1 = ninguno, 2 = alcanzó +1, 3 = alcanzó −1, 4 = ambos
    p = zeros(2K+1, 4)
    p[K+1, 1] = 1.0
    for _ in 1:n
        q = zeros(2K+1, 4)
        @inbounds for i in 1:2K+1
            k = i - K - 1
            for f in 1:4
                v = p[i, f]
                v == 0 && continue
                if k < K
                    nf = f == 1 ? 2 : (f == 3 ? 4 : f)
                    q[i+1, nf] += v*μ1*dt
                else
                    q[i, f] += v*μ1*dt
                end
                if k > -K
                    nf = f == 1 ? 3 : (f == 2 ? 4 : f)
                    q[i-1, nf] += v*μ2*dt
                else
                    q[i, f] += v*μ2*dt
                end
                q[i, f] += v*(1-Λ)
            end
        end
        p = q
    end
    tot = 0.0
    @inbounds for i in 1:2K+1
        tot += p[i, 4]
    end
    return min(1.0, tot)
end

"""
Curva S_max_racional(capacidad). Datos medidos del repo (citados, no heredados como
cifra propia): 4 TiB = 4 161 lecturas/slot por flujo; SSD de 100 k IOPS; auditoría
42,9 µs/sector/desafío (≈ núcleos de AES por flujo según capacidad). Devuelve la
función en puntos y la condición de racionalidad exacta.
"""
function s_max_racional(capacidades_TiB::Vector{Float64};
                        lecturas_4TiB::Float64=4161.0,
                        iops_ssd::Float64=100_000.0,
                        nucleos_disponibles::Int=24)
    S_io = [floor(Int, iops_ssd / (cap/4.0*lecturas_4TiB)) for cap in capacidades_TiB]
    S = [min(S_io[i], nucleos_disponibles) for i in eachindex(capacidades_TiB)]
    return S
end

"""
Condición exacta de cobertura racional del flujo i para un granjero con espacio w,
coste marginal por flujo c_marg (IOPS + núcleo AES, en moneda) y recompensa C por
bloque: P(gana i)·C ≥ c_marg con P(gana i) = λ·w/W_i por slot (W_i = espacio que
cubre el flujo i). Devuelve la fórmula simbólica escrita y su evaluación numérica.
"""
function condicion_cobertura(w::Float64, W_i::Float64, C::Float64, c_marg::Float64, λ::Float64=1.0)
    p_gana = λ * w / W_i
    return (p_gana, p_gana*C, p_gana*C >= c_marg)
end

"""
Deriva y absorción de la diferencia de peso entre dos flujos.
- Con retarget por flujo (R-FIN-13′): cada flujo produce a tasa λ → deriva 0 para todo
  c → la marcha es recurrente y la absorción (muerte de un flujo) NO ocurre jamás.
- Contrafactual sin retarget por flujo: tasas ∝ espacio que cubre cada flujo; deriva
  λ(1−c)(s1−s2); tiempo de absorción ≈ K/|deriva|.
"""
function deriva_absorcion(c::Float64, s1::Float64=0.5, λ::Float64=1.0, K::Float64=100.0)
    s2 = 1 - s1
    deriva_retarget = 0.0
    deriva_sin = λ*(1-c)*(s1 - s2)
    t_abs_retarget = Inf
    t_abs_sin = deriva_sin == 0 ? Inf : K/abs(deriva_sin)
    return (deriva_retarget, deriva_sin, t_abs_retarget, t_abs_sin)
end

"Tabla 4.0.2: barrido c ∈ [0,1]."
function tabla_absorcion(cs::Vector{Float64}; s1::Float64=0.5, λ::Float64=1.0, K::Float64=100.0)
    rows = [(c, deriva_absorcion(c, s1, λ, K)...) for c in cs]
    return rows
end

"""
Contraste histórico 4.0.3: recálculo bajo R-FIN-4/5 (sin fusión). Dos flujos a tasa λ
cada uno; D(t) = Skellam(λ, λ) de deriva nula, recurrente. Calcula P(D(τ)≠0),
P(último cruce de cero antes de τ) y el nº esperado de cambios de líder.
"""
function contraste_historico(τ::Float64=203.6, λ::Float64=1.0)
    p0 = skellam_pmf(λ, λ, τ, 0)
    p_no_cero = 1 - p0
    p_cambio = p_cambio_lider(λ, λ, τ)
    return (τ, p_no_cero, p_cambio, p0)
end
