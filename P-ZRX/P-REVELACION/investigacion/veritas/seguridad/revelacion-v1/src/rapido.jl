# ─────────────────────────────────────────────────────────────────────────────
# rapido.jl — kernel rápido y barridos
#
# Misma recursión que `modelo.jl` (no hay una segunda transcripción de la regla), pero:
#   · buffers preasignados por réplica, sin asignaciones en el bucle de ρ;
#   · números aleatorios comunes a toda la rejilla de ρ (mismo `off_j` y mismas `propia_j`),
#     que reduce la varianza al localizar umbrales y es reproducible;
#   · paralelización por réplica con reducción determinista en orden de id;
#   · histograma temporal exacto por tramos lineales.
# ─────────────────────────────────────────────────────────────────────────────

"Sortea `off_j` y `propia_j` de una réplica. `:cero`, `:geom` (tasa `lambda`) y `:unif`."
function sortear_offsets!(
    rng::AbstractRNG, off::Vector{T}, propia::Vector{Bool},
    cfg::Config{T}, J::Int, alpha::T; modo::Symbol = :geom, lambda::T = T(0.2),
) where {T<:Real}
    for j in 1:J
        if modo === :cero
            off[j] = zero(T)
        elseif modo === :unif
            off[j] = T(rand(rng)) * cfg.S_max
        elseif modo === :geom
            e = -log(rand(rng)) / lambda
            off[j] = e < cfg.S_max ? T(e) : cfg.S_max
        else
            error("modo de offset desconocido: $modo")
        end
        propia[j] = rand(rng) < alpha
    end
    return nothing
end

"Simula una réplica (una realización de `off`/`propia`) para un `ρ`. Usa y reinicia `b`."
function simular_replica!(
    b::Buffers{T}, cfg::Config{T}, off::Vector{T}, propia::Vector{Bool},
    rho::T, J::Int, bin::T, v_lo::T, boot_ref::T, con_hist::Bool = true,
) where {T<:Real}
    reiniciar!(b)
    (nA, nH, nsp, nsh, nep, nst, vbar) =
        construir_trayectorias!(b.tA, b.pA, b.tH, b.pH, cfg, off, propia, rho, J)
    t_ini = T(cfg.j_ini) * cfg.I
    (vmax, vmin, area, vfin, boot, tfin) =
        acumular!(b, cfg, nA, nH, bin, v_lo, t_ini, boot_ref, b.tA[nA], con_hist)
    dt = b.t_total
    vmed = dt > 0 ? area / T(dt) : zero(T)
    m = MetricasReplica{T}(vmax, vmin, vmed, vfin, t_ini, tfin, boot, vbar, nsp, nsh, nep, nst, nA, nH)
    return m
end

"Rejilla de `ρ` de `rho_min` a `rho_max` con `n` puntos (geométrica si `log`)."
function rejilla_rho(rho_min::T, rho_max::T, n::Int; log::Bool = false) where {T<:Real}
    n == 1 && return T[rho_min]
    if log
        lo = log(rho_min); hi = log(rho_max)
        return T[exp(lo + (hi - lo) * (i - 1) / (n - 1)) for i in 1:n]
    end
    return T[rho_min + (rho_max - rho_min) * (i - 1) / (n - 1) for i in 1:n]
end

"Resultado de un barrido. Matrices `(nρ, n_rep)`; histograma `(nb, n_rep)`."
struct ResultadoBarrido{T<:Real}
    rhos::Vector{T}
    n_rep::Int
    vmax::Matrix{T}
    vmin::Matrix{T}
    vmed::Matrix{T}
    boot::Matrix{T}
    vbar::Matrix{T}
    n_pro::Matrix{Int}
    n_hon::Matrix{Int}
    n_ep::Matrix{Int}
    n_stall::Matrix{Int}
    hist::Matrix{Float64}
    bajo::Vector{Float64}
    sobre::Vector{Float64}
    bin::T
    v_lo::T
    J::Int
    t_pared::Float64
end

"""
Barrido principal: `n_rep` réplicas × la rejilla de `ρ`, con números aleatorios comunes.

`cfg` aporta `L, I, W_dec, D, S_max, Lrev, con_h, espera, cruce, lead_h, j_ini`; el campo
`alpha_draw` de `cfg` **no** se usa (el `α` del sorteo va en `alpha`). Escribe una columna de
histograma por réplica y reduce en orden de id ⇒ reproducible bit a bit con el mismo número de
réplicas, sea cual sea el reparto por hilos.
"""
function barrer!(
    cfg::Config{T}; rhos::Vector{T}, n_rep::Int, J::Int, alpha::T,
    seed::UInt64, nb::Int, bin::T, v_lo::T, boot_ref::T,
    modo_off::Symbol = :geom, lambda::T = T(0.2), nthreads::Int = 1, con_hist::Bool = true,
) where {T<:Real}
    nρ = length(rhos)
    vmax = Matrix{T}(undef, nρ, n_rep)
    vmin = Matrix{T}(undef, nρ, n_rep)
    vmed = Matrix{T}(undef, nρ, n_rep)
    boot = Matrix{T}(undef, nρ, n_rep)
    vbar = Matrix{T}(undef, nρ, n_rep)
    n_pro = Matrix{Int}(undef, nρ, n_rep)
    n_hon = Matrix{Int}(undef, nρ, n_rep)
    n_ep = Matrix{Int}(undef, nρ, n_rep)
    n_stall = Matrix{Int}(undef, nρ, n_rep)
    hist = zeros(Float64, nb, n_rep)
    bajo = zeros(Float64, n_rep)
    sobre = zeros(Float64, n_rep)

    t0 = time()
    if nthreads > 1
        Threads.@threads :static for r in 1:n_rep
            _replica!(cfg, rhos, vmax, vmin, vmed, boot, vbar,
                      n_pro, n_hon, n_ep, n_stall, hist, bajo, sobre, r, J, nb, bin, v_lo,
                      boot_ref, seed, modo_off, lambda, alpha, con_hist)
        end
    else
        for r in 1:n_rep
            _replica!(cfg, rhos, vmax, vmin, vmed, boot, vbar,
                      n_pro, n_hon, n_ep, n_stall, hist, bajo, sobre, r, J, nb, bin, v_lo,
                      boot_ref, seed, modo_off, lambda, alpha, con_hist)
        end
    end
    tp = time() - t0
    return ResultadoBarrido{T}(rhos, n_rep, vmax, vmin, vmed, boot, vbar, n_pro, n_hon,
                               n_ep, n_stall, hist, bajo, sobre, bin, v_lo, J, tp)
end

function _replica!(
    cfg::Config{T},
    rhos::Vector{T}, vmax::Matrix{T}, vmin::Matrix{T}, vmed::Matrix{T}, boot::Matrix{T},
    vbar::Matrix{T}, n_pro::Matrix{Int}, n_hon::Matrix{Int}, n_ep::Matrix{Int},
    n_stall::Matrix{Int}, hist::Matrix{Float64}, bajo::Vector{Float64},
    sobre::Vector{Float64}, r::Int, J::Int, nb::Int, bin::T, v_lo::T, boot_ref::T,
    seed::UInt64, modo_off::Symbol, lambda::T, alpha::T, con_hist::Bool,
) where {T<:Real}
    rng = StableRNG(seed + UInt64(r))
    off = Vector{T}(undef, J + 1)        # por réplica: ningún buffer compartido entre hilos
    propia = Vector{Bool}(undef, J + 1)
    sortear_offsets!(rng, off, propia, cfg, J, alpha; modo = modo_off, lambda = lambda)
    b = Buffers{T}(J, nb)
    for (i, rho) in enumerate(rhos)
        m = simular_replica!(b, cfg, off, propia, rho, J, bin, v_lo, boot_ref, con_hist)
        vmax[i, r] = m.vmax
        vmin[i, r] = m.vmin
        vmed[i, r] = m.vmed
        boot[i, r] = m.boot
        vbar[i, r] = m.v_barrera
        n_pro[i, r] = m.n_steer_pro
        n_hon[i, r] = m.n_steer_hon
        n_ep[i, r] = m.n_ep
        n_stall[i, r] = m.n_stall_h
        @inbounds for k in 1:nb
            hist[k, r] += b.hist[k]
        end
        bajo[r] += b.bajo
        sobre[r] += b.sobre
    end
    return nothing
end

# ── resúmenes deterministas ─────────────────────────────────────────────────

"Media y desviación de una fila `(nρ, n_rep)` sobre réplicas, en orden de id."
function fila_media(x::Matrix{T}, i::Int) where {T<:Real}
    n = size(x, 2)
    s = zero(T)
    for r in 1:n
        s += x[i, r]
    end
    return s / n
end

"Percentil `q ∈ [0,1]` de una fila, con reducción determinista (ordenación de la fila)."
function fila_cuantil(x::Matrix{T}, i::Int, q::Float64) where {T<:Real}
    v = sort(vec(x[i, :]))
    n = length(v)
    idx = clamp(Int(ceil(q * n)), 1, n)
    return v[idx]
end

"Histograma agregado del barrido (suma en orden de réplica)."
function hist_agregado(res::ResultadoBarrido)
    n = size(res.hist, 2)
    h = zeros(Float64, size(res.hist, 1))
    for r in 1:n, k in eachindex(h)
        h[k] += res.hist[k, r]
    end
    return h, sum(res.bajo), sum(res.sobre)
end

"""
Cuantil temporal de `V` a partir del histograma: `q ∈ [0,1]` de la masa de tiempo.
Devuelve el extremo inferior del bin que contiene el cuantil.
"""
function cuantil_hist(h::Vector{Float64}, bajo::Float64, sobre::Float64, bin::T, v_lo::T, q::Float64) where {T<:Real}
    total = bajo + sobre + sum(h)
    total <= 0 && return T(NaN)
    objetivo = q * total
    acc = 0.0
    if objetivo <= bajo
        return v_lo - T(1)          # por debajo del origen: cota inferior declarada
    end
    acc = bajo
    for k in eachindex(h)
        acc += h[k]
        if acc >= objetivo
            return v_lo + T(k - 1) * bin
        end
    end
    # la cola por encima del techo del histograma se declara: el cuantil es una COTA INFERIOR
    return v_lo + T(length(h)) * bin
end

"Fracción del tiempo con `V ≥ umbral`, desde el histograma (el bin que contiene el umbral se reparte linealmente)."
function fraccion_excedencia(h::Vector{Float64}, bajo::Float64, sobre::Float64, bin::T, v_lo::T, umbral::T) where {T<:Real}
    total = bajo + sobre + sum(h)
    total <= 0 && return NaN
    if umbral <= v_lo
        return (total - bajo) / total
    end
    ku = floor(Int, (umbral - v_lo) / bin)
    acc = bajo                                  # tiempo con V por debajo del origen
    for k in 0:(ku - 1)                         # bins estrictamente por debajo del umbral
        if k >= 0 && k < length(h)
            acc += h[k+1]
        end
    end
    if ku >= 0 && ku < length(h)
        f = (umbral - (v_lo + T(ku) * bin)) / bin     # fracción del bin por debajo del umbral
        f = clamp(f, zero(T), one(T))
        acc += h[ku+1] * Float64(f)
    end
    return (total - acc) / total
end
