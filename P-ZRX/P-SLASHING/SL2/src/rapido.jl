#= SL-2 · rapido.jl
   KERNEL del modelo: DP de primera pasada certificada, DP absorbente rápida, inversión
   coste↔probabilidad, y Monte Carlo independiente con `StableRNGs` (semillas no consecutivas):
     · paseo de la ventana (valida la DP);
     · `B(ε)` empírico por bootstrap (valida el cálculo directo de DS-6);
     · `B(ε)` de la Pareto truncada por muestreo (valida la fórmula cerrada);
     · pérdida anual del honesto por Poisson (valida la condición de honestidad).
   Diseño numérico (LINEO §5.3): sin `@fastmath`, sin `@simd`, sin `Float32`, sin asignaciones en el
   bucle interior; `BigFloat` en el oráculo.
=#

# ─────────────────────────────────────── DP certificada `(mínimo, posición)`

"""
    primera_dp(q_adv, d, T; H = d + T + 2) -> (paso, interior)

Primera pasada por DP exacta en estructura sobre `(m, z)`: `m` = mínimo de los prefijos,
`z` = posición. Absorción la primera vez que `m` toca `−1`. `paso + interior = 1` es invariante.
"""
function primera_dp(q_adv::T, d::Integer, Tsteps::Integer;
                    H::Integer = d + Tsteps + 2) where {T<:Real}
    d >= 0 || throw(ArgumentError("d ≥ 0"))
    Tsteps >= 0 || throw(ArgumentError("T ≥ 0"))
    q = one(q_adv) - q_adv
    mmin, mmax = -1, d
    zmin, zmax = -1, H
    nz = zmax - zmin + 1
    nm = mmax - mmin + 1
    h = zeros(T, nm * nz)
    hn = zeros(T, nm * nz)
    @inline idx(m, z) = (m - mmin) * nz + (z - zmin) + 1
    h[idx(d, d)] = one(q_adv)
    acc = zero(q_adv)
    interior = one(q_adv)
    @inbounds for _ in 1:Tsteps
        fill!(hn, zero(q_adv))
        for m in mmin:mmax, z in zmin:zmax
            m > z && continue
            v = h[idx(m, z)]
            iszero(v) && continue
            zz = z - 1
            mm = min(m, zz)
            if mm <= -1
                acc += v * q_adv
            else
                hn[idx(mm, zz)] += v * q_adv
            end
            zz2 = z + 1
            if zz2 <= zmax
                mm2 = min(m, zz2)
                if mm2 <= -1
                    acc += v * q
                else
                    hn[idx(mm2, zz2)] += v * q
                end
            end
        end
        interior = zero(q_adv)
        for i in eachindex(hn)
            interior += hn[i]
        end
        h, hn = hn, h
    end
    return (paso = acc, interior = interior)
end

"""
    primera_dp_absorbente(q_adv, d, T) -> P_primera

DP absorbente sobre la POSICIÓN: `u[z+1]` = masa que no ha tocado `−1` y está en `z ≥ 0`.
O(T·(d+T)); vía independiente del DP `(mínimo, posición)`.
"""
function primera_dp_absorbente(q_adv::T, d::Integer, Tsteps::Integer) where {T<:Real}
    d >= 0 || throw(ArgumentError("d ≥ 0"))
    Tsteps >= 0 || throw(ArgumentError("T ≥ 0"))
    p_hon = one(q_adv) - q_adv
    zmax = d + Tsteps + 1
    u = zeros(T, zmax + 1)
    un = zeros(T, zmax + 1)
    u[d + 1] = one(q_adv)
    acc = zero(q_adv)
    @inbounds for _ in 1:Tsteps
        fill!(un, zero(q_adv))
        for z in 0:zmax
            v = u[z + 1]
            iszero(v) && continue
            if z == 0
                acc += v * q_adv
            else
                un[z] += v * q_adv
            end
            z + 1 <= zmax && (un[z + 2] += v * p_hon)
        end
        u, un = un, u
    end
    return acc
end

"""
    beta_minimo_para_p(α, F, P_obj; βx, ηh, ηa, tolerancia, maxit, via) -> (βd, P, iteraciones)

Mínimo `β_d ∈ [0, 1−α−βx]` con `P_first_passage ≥ P_obj` por bisección. `P` es monótona creciente
en `β_d`. `via = :rapida` (DP absorbente) o `:certificada` (DP `(mínimo, posición)`).
"""
function beta_minimo_para_p(α, F, P_obj; βx = 0.0, ηh = 1.0, ηa = 1.0,
                            tolerancia = 1e-12, maxit = 200, via::Symbol = :rapida)
    lo = 0.0
    hi = max(0.0, 1 - α - βx)
    Fi = round(Int, F)
    prob(βd) = begin
        r = Reparto(α, βd; βx = βx, ηh = ηh, ηa = ηa)
        d = deficit_entero(r, F)
        via === :certificada ? primera_dp(p_de_alpha(r), d, Fi).paso :
                               primera_dp_absorbente(p_de_alpha(r), d, Fi)
    end
    prob(hi) < P_obj && return (βd = NaN, P = prob(hi), iteraciones = 0)
    prob(lo) >= P_obj && return (βd = 0.0, P = prob(lo), iteraciones = 0)
    it = 0
    for _ in 1:maxit
        it += 1
        med = (lo + hi) / 2
        if prob(med) >= P_obj
            hi = med
        else
            lo = med
        end
        hi - lo <= tolerancia && break
    end
    return (βd = hi, P = prob(hi), iteraciones = it)
end

# ────────────────────────────────────────── Monte Carlo de la ventana

"""
    mc_ventana(q_adv, d, T, nrep, semilla; etiqueta, hilos) -> (p_paso, ic_paso)

Monte Carlo del paseo con `StableRNGs`, una semilla derivada por réplica (no consecutiva).
"""
function mc_ventana(q_adv::Float64, d::Integer, T::Integer, nrep::Integer, semilla::UInt64;
                    etiqueta::UInt64 = UInt64(0), hilos::Bool = true)
    exitos = Threads.Atomic{Int}(0)
    if hilos && nrep >= 4096
        Threads.@threads for id in 1:nrep
            r = rng_replica(semilla, id, etiqueta)
            z = d
            tocado = false
            for _ in 1:T
                z += rand(r) < q_adv ? -1 : 1
                if z == -1
                    tocado = true
                    break
                end
            end
            tocado && Threads.atomic_add!(exitos, 1)
        end
    else
        for id in 1:nrep
            r = rng_replica(semilla, id, etiqueta)
            z = d
            tocado = false
            for _ in 1:T
                z += rand(r) < q_adv ? -1 : 1
                if z == -1
                    tocado = true
                    break
                end
            end
            tocado && (exitos[] += 1)
        end
    end
    return (p_paso = exitos[] / nrep, ic_paso = wilson(exitos[], nrep))
end

"Monte Carlo de `P(B = 0)` para la retención: `N ~ Poisson(θ)`, cuenta `N = 0`."
function mc_saldo_cero(θ::Float64, nrep::Integer, semilla::UInt64;
                       etiqueta::UInt64 = UInt64(0), hilos::Bool = true)
    exitos = Threads.Atomic{Int}(0)
    if hilos && nrep >= 4096
        Threads.@threads for id in 1:nrep
            r = rng_replica(semilla, id, etiqueta)
            _poisson(r, θ) == 0 && Threads.atomic_add!(exitos, 1)
        end
    else
        for id in 1:nrep
            r = rng_replica(semilla, id, etiqueta)
            _poisson(r, θ) == 0 && (exitos[] += 1)
        end
    end
    return (p = exitos[] / nrep, ic = wilson(exitos[], nrep))
end

# ─────────────────────────── Monte Carlo de B(ε): bootstrap empírico y Pareto

"""
    bootstrap_Bemp(d::Empirica, x, nrep, semilla) -> Vector{Float64}

Bootstrap por granjero (remuestreo con reemplazo, mismo tamaño de muestra) del `B` empírico.
Denominador fijo = el de la muestra original. Vía independiente del cálculo directo.
"""
function bootstrap_Bemp(d::Empirica, x::Float64, nrep::Integer, semilla::UInt64;
                        etiqueta::UInt64 = UInt64(3))
    n = length(d.tibs)
    reps = Vector{Float64}(undef, nrep)
    for r in 1:nrep
        rng = rng_replica(semilla, r, etiqueta)
        umbral = x * d.denom
        suma = 0.0
        @inbounds for i in 1:n
            t = d.tibs[rand(rng, 1:n)]
            t < umbral && (suma += t)
        end
        reps[r] = suma / d.denom
    end
    return reps
end

"Cuántiles percentil `(lo,hi)` de una muestra."
function ic_percentil(reps::Vector{Float64}, p::Float64 = 0.025)
    q = sort(reps)
    return (quantile(q, p), quantile(q, 1 - p))
end

"Muestrea una Pareto `p(f) ∝ f^{−alpha}`: no truncada (`truncada=false`, exige α>1) o en `[f_min,1]`."
function _rand_pareto(rng, f_min::Float64, alpha::Float64, truncada::Bool)
    u = rand(rng)
    r = alpha - 1.0
    if !truncada
        return f_min / max(u, 1e-300)^(1.0 / r)
    end
    base = 1.0 - u * (1.0 - f_min^r)
    return f_min / base^(1.0 / r)
end

"""
    mc_Bpar(d::ParetoDist, x, nrep, semilla, m; etiqueta) -> Vector{Float64}

Estima la fracción de ESPACIO en claves con `f < x` por muestreo directo de la Pareto (vía
independiente de `masa_prob`). `alpha > 2` muestrea la no truncada (la rama que usa DS-3);
`alpha <= 2` la truncada `[f_min,1]`.
"""
function mc_Bpar(d::ParetoDist, x::Float64, nrep::Integer, semilla::UInt64, m::Integer;
                 etiqueta::UInt64 = UInt64(4))
    truncada = d.alpha <= 2
    reps = Vector{Float64}(undef, nrep)
    for r in 1:nrep
        rng = rng_replica(semilla, r, etiqueta)
        s_bajo = 0.0
        s_tot = 0.0
        @inbounds for _ in 1:m
            f = _rand_pareto(rng, d.f_min, d.alpha, truncada)
            s_tot += f
            f < x && (s_bajo += f)
        end
        reps[r] = s_tot > 0 ? s_bajo / s_tot : 0.0
    end
    return reps
end

"""
    mc_honesto(esc, ρ_ret, Tv; nrep, semilla) -> (media, ic, tope, cociente)

Monte Carlo de la pérdida anual del honesto: `N ~ Poisson(ε_h)` incidentes, cada uno `L`. Vía
independiente de `ε_h·L`. `ic` = Wilson sobre la fracción de años que superan el tope.
"""
function mc_honesto(esc::Escenario, ρ_ret, Tv; nrep::Integer, semilla::UInt64,
                    etiqueta::UInt64 = UInt64(5))
    L = perdida_castigo(esc; ρ_ret = ρ_ret, Tv = Tv)
    tope = max_perdida_honesta(esc; f_h = esc.f_h)
    exitos = Threads.Atomic{Int}(0)
    suma = Threads.Atomic{Float64}(0.0)
    if nrep >= 4096
        Threads.@threads for id in 1:nrep
            r = rng_replica(semilla, id, etiqueta)
            n = _poisson(r, esc.eps_h)
            perdida = n * L
            Threads.atomic_add!(suma, perdida)
            perdida > tope && Threads.atomic_add!(exitos, 1)
        end
    else
        for id in 1:nrep
            r = rng_replica(semilla, id, etiqueta)
            n = _poisson(r, esc.eps_h)
            perdida = n * L
            suma[] += perdida
            perdida > tope && (exitos[] += 1)
        end
    end
    return (media = suma[] / nrep, ic = wilson(exitos[], nrep), tope = tope,
            cociente = tope > 0 ? suma[] / nrep / tope : Inf,
            se = L * sqrt(max(esc.eps_h, 1e-300) / nrep))
end

"Muestrea `Poisson(λ)` por el método de Knuth para `λ` pequeño (aquí `ε_h ≤ 0.1`)."
function _poisson(rng, λ::Float64)
    λ <= 0 && return 0
    L = exp(-λ)
    k = 0
    p = 1.0
    while true
        k += 1
        p *= rand(rng)
        p <= L && break
        k > 1_000_000 && break
    end
    return k - 1
end
