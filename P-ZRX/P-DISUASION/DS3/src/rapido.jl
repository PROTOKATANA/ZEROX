#= DS-3 · rapido.jl
   KERNEL del modelo: DP de primera pasada, DP absorbente rápida, Monte Carlo con
   StableRNGs (semillas no consecutivas), cola hipergeométrica rápida y barridos.

   Diseño numérico (LINEO §5.3):
     · DP de tiempo de parada sobre `(mínimo, posición)` — la vía certificada de P-PRESTAMO;
     · DP absorbente sobre la posición — vía independiente, O(T·(d+T));
     · `BigFloat` a precisión declarada para certificar puntos de frontera;
     · sin `@fastmath`, sin `@simd`, sin `Float32`, sin asignaciones en el bucle interior.
=#

# ─────────────────────────────────────────────── DP certificada `(mínimo, posición)`

"""
    primera_dp(q_adv, d, T; H = d + T + 2) -> (paso, interior)

Primera pasada por DP exacta en estructura sobre `(m, z)`: `m` = mínimo de los prefijos,
`z` = posición. Absorción la primera vez que `m` toca `−1`. `q_adv` = tasa del adversario.
Devuelve `(P_primera, masa_interior)`; `paso + interior = 1` es un invariante comprobable.
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
            m > z && continue          # poda exacta: el mínimo nunca supera la posición
            v = h[idx(m, z)]
            iszero(v) && continue
            # paso del adversario: z−1
            zz = z - 1
            mm = min(m, zz)
            if mm <= -1
                acc += v * q_adv
            else
                hn[idx(mm, zz)] += v * q_adv
            end
            # paso del honesto: z+1
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

"La misma DP con `BigFloat` a `prec` bits: certifica numéricamente el kernel `Float64`."
function primera_bigfloat_dp(q_adv::Real, d::Integer, Tsteps::Integer, prec::Integer = 256)
    return setprecision(BigFloat, prec) do
        r = primera_dp(BigFloat(q_adv), d, Tsteps)
        return (r.paso, r.interior)
    end
end

# ────────────────────────────────────────── DP absorbente sobre la posición (rápida)

"""
    primera_dp_absorbente(q_adv, d, T) -> P_primera

DP absorbente sobre la POSICIÓN: `u[z+1]` = masa que NO ha tocado `−1` y está en `z ≥ 0`.
Cada paso del adversario desde `z = 0` se acumula como absorción. O(T·(d+T)).
Es una vía independiente del DP `(mínimo, posición)`; coinciden en el dominio del oráculo.
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
                acc += v * q_adv            # cae a −1: absorbido
            else
                un[z] += v * q_adv          # z−1 ≥ 0
            end
            z + 1 <= zmax && (un[z + 2] += v * p_hon)
        end
        u, un = un, u
    end
    return acc
end

# ────────────────────────────────────────── Monte Carlo de la ventana

"RNG independiente por réplica: `StableRNG(hash64(semilla ⊻ etiqueta, id))` (no consecutivo)."
@inline rng_replica(semilla::UInt64, id::Integer, etiqueta::UInt64 = UInt64(0)) =
    StableRNG(hash64(semilla ⊻ etiqueta, UInt64(id)))

"""
    mc_ventana(q_adv, d, T, nrep, semilla; etiqueta = 0) -> (p_paso, ic_paso)

Monte Carlo del paseo con `StableRNGs`, una semilla derivada por réplica (no consecutiva).
`q_adv` = tasa del adversario. Devuelve la proporción de réplicas que tocan `−1` y su IC de
Wilson al 95 %.
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

"Intervalo de Wilson al 95 % para `k` éxitos de `n` (P-PRESTAMO `referencia.jl`)."
function wilson(k::Integer, n::Integer)
    n == 0 && return (0.0, 1.0)
    z = 1.959963984540054
    ph = k / n
    den = 1 + z^2 / n
    centro = (ph + z^2 / (2n)) / den
    medio = z * sqrt(ph * (1 - ph) / n + z^2 / (4n^2)) / den
    return (max(0.0, centro - medio), min(1.0, centro + medio))
end

"Monte Carlo de `P(B = 0)` para la retención: muestra `N ~ Poisson(θ)` y cuenta `N = 0`."
function mc_saldo_cero(θ::Float64, nrep::Integer, semilla::UInt64;
                       etiqueta::UInt64 = UInt64(0), hilos::Bool = true)
    exitos = Threads.Atomic{Int}(0)
    if hilos && nrep >= 4096
        Threads.@threads for id in 1:nrep
            r = rng_replica(semilla, id, etiqueta)
            s, _ = muestra_saldo_espaciado!(r, θ, 1.0)
            s == 0.0 && Threads.atomic_add!(exitos, 1)
        end
    else
        for id in 1:nrep
            r = rng_replica(semilla, id, etiqueta)
            s, _ = muestra_saldo_espaciado!(r, θ, 1.0)
            s == 0.0 && (exitos[] += 1)
        end
    end
    return (p = exitos[] / nrep, ic = wilson(exitos[], nrep))
end

# ────────────────────────────────────────── cobertura: cola hipergeométrica rápida

"Tabla de log-factoriales `logfact[n+1] = log(n!)`."
struct TablaLogFact
    logfact::Vector{Float64}
    function TablaLogFact(nmax::Integer)
        nmax >= 1 || throw(ArgumentError("nmax ≥ 1"))
        v = Vector{Float64}(undef, nmax + 1)
        v[1] = 0.0
        @inbounds for i in 1:nmax
            v[i + 1] = v[i] + log(Float64(i))
        end
        return new(v)
    end
end

"`log C(n,k)`; `−Inf` fuera de rango."
@inline function log_binomial(t::TablaLogFact, n::Int, k::Int)
    (k < 0 || k > n) && return -Inf
    @inbounds return t.logfact[n + 1] - t.logfact[k + 1] - t.logfact[n - k + 1]
end

"`P(X > B)`, `X ~ Hipergeométrica(N, M, k)`, en `Float64` con log-factoriales."
function cola_hiper_rapida(t::TablaLogFact, N::Int, M::Int, k::Int, B::Int)
    jmax = min(k, M)
    j0 = max(0, k - (N - M))
    lo = max(B + 1, j0)
    lo > jmax && return 0.0
    logden = log_binomial(t, N, k)
    acc = 0.0
    @inbounds for j in lo:jmax
        lp = log_binomial(t, M, j) + log_binomial(t, N - M, k - j) - logden
        acc += exp(lp)
    end
    return acc > 1.0 ? 1.0 : acc
end

# ────────────────────────────────────────── inversión: β_d mínimo para P*

"""
    beta_minimo_para_p(α, F, P_obj; βx = 0, ηh = 1, ηa = 1, tolerancia = 1e-12, maxit = 200,
                       via = :rapida)

Mínimo `β_d ∈ [0, 1−α−βx]` con `P_first_passage ≥ P_obj`, por bisección. `P` es monótona
creciente en `β_d` (el déficit baja y `p` sube). Devuelve `(βd, P, iteraciones)`.

`via = :rapida` usa la DP absorbente (equivalente, validada en `validar_primera_pasada` y
≈1.250× más rápida); `via = :certificada` usa la DP `(mínimo, posición)` de P-PRESTAMO. Las
dos dan el mismo `β_d` dentro de la tolerancia (test de regresión).
"""
function beta_minimo_para_p(α, F, P_obj; βx = 0.0, ηh = 1.0, ηa = 1.0,
                            tolerancia = 1e-12, maxit = 200, via::Symbol = :rapida)
    lo = 0.0
    hi = max(0.0, 1 - α - βx)
    prob(βd) = begin
        r = Reparto(α, βd; βx = βx, ηh = ηh, ηa = ηa)
        d = deficit_entero(r, F)
        via === :certificada ? primera_dp(p_de_alpha(r), d, F).paso :
                               primera_dp_absorbente(p_de_alpha(r), d, F)
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

# ────────────────────────────────────────── barridos declarados

"""
    barrido_ventana(αs, βds, F) -> Vector{NamedTuple}

Barrido de la probabilidad de primera pasada sobre la rejilla `(α, β_d)` del MODELO §3.
Cada fila lleva `p`, `d`, `P`, `log10(P)` y la etiqueta de subdesborde `limite_ruina`.
"""
function barrido_ventana(αs, βds, F)
    out = NamedTuple{(:α, :βd, :p, :d, :P, :log10P, :etiqueta),
                     Tuple{Float64,Float64,Float64,Int,Float64,Float64,String}}[]
    for α in αs, βd in βds
        r = Reparto(α, βd)
        p = p_de_alpha(r)
        d = deficit_entero(r, F)
        res = primera_dp(p, d, F)
        et = res.paso > 0 ? "exacto" : "limite_ruina"
        push!(out, (α = Float64(α), βd = Float64(βd), p = p, d = d, P = res.paso,
                    log10P = res.paso > 0 ? log10(res.paso) : eventual_log10(p, d),
                    etiqueta = et))
    end
    return out
end

"""
    barrido_cobertura(ws, N, k; r_maquina, τ, D_a) -> Vector{NamedTuple}

Barrido de la frontera de cobertura: `B(w)`, `almacenamiento_forzado`, detección posible y
núcleos/TiB continuos. `M` omitido para la detección se elige como `(1−φ)·N` con `φ` barrrido
en `phis`.
"""
function barrido_cobertura(ws, N, k, phis; r_maquina = R_MAQUINA_S, τ = TAU_S, D_a = D_A_S,
                           t_unidad = T_UNIDAD_S)
    t = TablaLogFact(N)
    out = NamedTuple{(:w, :B, :almacenado, :nucleos_TiB, :phi, :M, :deteccion),
                     Tuple{Float64,Int,Float64,Float64,Float64,Int,Float64}}[]
    for w in ws
        B = floor(Int, B_unidades(r_maquina, 1.0, w, τ, D_a))
        af = almacenamiento_forzado(N, B, k)
        nuc = nucleos_por_TiB(w, t_unidad, τ, D_a)
        for phi in phis
            M = max(0, min(N, round(Int, (1 - phi) * N)))
            det = cola_hiper_rapida(t, N, M, k, B)
            push!(out, (w = Float64(w), B = B, almacenado = af, nucleos_TiB = nuc,
                        phi = Float64(phi), M = M, deteccion = det))
        end
    end
    return out
end
